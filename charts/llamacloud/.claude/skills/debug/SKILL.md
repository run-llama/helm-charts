---
name: debug
description: Diagnose problems with an installed LlamaCloud release — pods crashing, services not reachable, login broken, parses failing, OCR queue stuck, etc. Use when the user says "something's wrong", "pods are stuck", "X is failing", "the install came up but something is broken", or pastes a kubectl error. Performs a structured symptom-to-cause walk using read-only kubectl and cloud CLI commands, then matches against the LlamaCloud-specific pattern library in `patterns.md`. Produces a `debug-report.md` safe to share with LlamaIndex support.
---

# Debug a running LlamaCloud release

Goal: take "something is broken" and produce a structured diagnosis: which pod, what symptom, which `values.yaml` field (or external dependency) is the root cause, and what to change. Read-only against the cluster.

For known error signatures, the catalog is in `patterns.md` next to this file. **Read it lazily** — only when you've narrowed down to a candidate symptom — to keep this skill's context budget small.

## Step 0 — Confirm context

```bash
kubectl config current-context
helm list -A | grep -i llama
```

Read the context back to the user and confirm. Identify the release(s). If multiple, ask which one.

## Step 1 — Health snapshot

```bash
helm status <release> -n <ns>
helm history <release> -n <ns> | tail -10
kubectl get pods -n <ns> -o wide
kubectl get events -n <ns> --sort-by=.lastTimestamp | tail -50
kubectl get pdb,hpa,ingress,svc,pvc -n <ns>
```

Tabulate the pod list. Note the **deployment naming convention**: the LlamaCloud components have *fixed* deployment names (the chart does not prefix them with the release name), while subchart components *do* use the `<release>-` prefix.

| Group | Deployment / pod prefix | What's normal |
|---|---|---|
| Backend | `llamacloud-*` (yes — bare release-named, not `llamacloud-backend`) | 1+ Ready |
| Frontend | `llamacloud-web-*` | 1+ Ready |
| Jobs service | `llamacloud-operator-*` | 1+ Ready |
| Jobs worker | `llamacloud-worker-*` | 1+ Ready |
| Usage / telemetry | `llamacloud-telemetry-*` | 1 Ready |
| Parse | `llamacloud-parse-*` | 1+ Ready |
| Parse OCR (GPU) | `llamacloud-ocr-*` | 0+ Ready depending on `config.parseOcr.enabled` |
| Layout detection (GPU) | `llamacloud-layout-*` | 0+ depending on `config.parseLayoutDetection.enabled` |
| Layout V3 (GPU) | `llamacloud-layout-v3-*` | 0+ depending on `config.parseLayoutDetectionV3.enabled` |
| Parse Temporal worker | `llamacloud-temporal-parse-*` | 1+ Ready when temporal workloads enabled |
| Jobs Temporal worker | `temporal-jobs-worker-*` | 1+ Ready when temporal workloads enabled |
| Temporal subchart | `<release>-temporal-subchart-*` | frontend / history / matching / worker / web / admintools all Ready |
| llama-agents subchart | varies | optional |

When the user gives a pod name, treat the bare `llamacloud-<hash>-<random>` as the **backend** unambiguously. This trips up newcomers because the obvious guess is "frontend".

To unambiguously isolate one component, use label selectors instead of name globs:

```bash
kubectl get pods -n <ns> -l app.kubernetes.io/name=llamacloud           # backend only
kubectl get pods -n <ns> -l app.kubernetes.io/name=llamacloud-web        # frontend
kubectl get pods -n <ns> -l app.kubernetes.io/name=llamacloud-worker     # jobs worker
kubectl get pods -n <ns> -l app.kubernetes.io/name=llamacloud-parse      # parse
# ...etc — every component has matching app.kubernetes.io/name
```

When `<component>.horizontalPodAutoscalerSpec` is set on a component (default: empty, no HPA), the chart creates a standard `HorizontalPodAutoscaler` named after the Deployment (e.g. `llamacloud`, `llamacloud-web`). If you see HPAs with different naming (e.g. `keda-hpa-*-scaledobject`), that's the customer's KEDA / external autoscaler managing the same Deployments — the `Deployment/<name>` reference is authoritative regardless of how the HPA was named.

Standard Secrets the chart creates (look for these when debugging missing-secret errors). Each is generated only when the corresponding values block is configured inline; if the user sets the matching `*.secret:` reference instead, the chart skips generating its own Secret and reads from the user-provided one.

**Always created (when the corresponding values block is set inline):**

| Secret | Triggered by | Purpose |
|---|---|---|
| `llamacloud-license-key` | `license.key` | License |
| `postgresql-secret` | `postgresql.password` | Postgres credentials |
| `mongodb-secret` | `mongodb.password` or `mongodb.mongodb_url` | MongoDB credentials / connection URL |
| `rabbitmq-secret` | `rabbitmq.password` or `rabbitmq.connectionString` | RabbitMQ credentials |
| `redis-secret` | `redis.password` | Redis credentials |
| `bucket-secret` | `config.storageBuckets.*` credentials | Object storage credentials (for non-IRSA setups, e.g. static AWS keys, GCS HMAC, Azure SAS) |

**Conditional — only when the matching feature is enabled:**

| Secret | Triggered by | Purpose |
|---|---|---|
| `oidc-secret` | `config.authentication.oidc.enabled: true` | OIDC client credentials |
| `basic-auth-secret` | basic auth enabled (mutually exclusive with OIDC) | Basic auth credentials |
| `temporal-postgresql-secret` | `temporal.deploy: true` | Separate Postgres credential copy for the Temporal subchart |
| `qdrant-secret` | `qdrant.enabled: true` | Qdrant API key |
| `s3proxy-secret` | `config.storageBuckets.s3proxy.enabled: true` | s3proxy upstream credentials (e.g. GCS HMAC, Azure storage key) |

**LLM provider Secrets — one per configured provider:**

| Secret | Triggered by | Purpose |
|---|---|---|
| `openai-api-key-secret` | `config.llms.openAi.apiKey` set | OpenAI API key |
| `anthropic-api-key-secret` | `config.llms.anthropic.apiKey` set | Anthropic API key |
| `gemini-api-key-secret` | `config.llms.gemini.apiKey` set | Google Gemini API key |
| `azure-open-ai-api-key-secret` | `config.llms.azureOpenAi.deployments[]` configured | Azure OpenAI deployment keys (one Secret holding keys for all configured deployments) |
| `aws-bedrock-api-key-secret` | `config.llms.awsBedrock` block present | AWS Bedrock config (model versions; auth via IRSA, not a static key, but the Secret still carries config values) |
| `google-vertex-ai-api-key-secret` | `config.llms.googleVertexAi.credentialsJson` set | Vertex AI service-account JSON |
| `llm-provider-configs-secret` | always (when any LLM provider configured) | Aggregated provider config — base URLs, model names, deployment names, etc. — referenced by backend env vars |

**Ingress TLS (NOT created by the chart):**

| Secret | Triggered by | Purpose |
|---|---|---|
| `<ingress.tlsSecretName>` | `ingress.enabled: true` references it | Ingress TLS. The chart does not create this Secret; the user provides it (cert-manager, externally-managed cert, or `kubectl create secret tls`). |

ConfigMaps the chart creates:

**Centralized config (always present when chart deployed):**

| ConfigMap | Purpose |
|---|---|
| `common-config` | Shared env shared across most deployments |
| `urls-config` | Intra-cluster Service URLs each component talks to |
| `bucket-config` | Object storage bucket names and provider |
| `feature-config` | Feature flags |
| `extract-config` | Extract-specific tuning |
| `concurrency-config` | Concurrency limits per workload |
| `rate-limits-config` | Rate limits per LLM / API |
| `temporal-connection-config` | Temporal frontend host/port |

**Conditional:**

| ConfigMap | Triggered by | Purpose |
|---|---|---|
| `llama-agents-config` | `llamaAgents.deploy: true` or `llamaAgents.controlPlaneUrl` set | llama-agents wiring |
| `s3proxy-config` | `config.storageBuckets.s3proxy.enabled: true` | s3proxy JCLOUDS configuration (provider, region, endpoint) |

**Per-deployment ConfigMaps (one per component, named after the Deployment):**

`llamacloud-web`, `llamacloud-worker`, `llamacloud-parse`, `llamacloud-temporal-parse`, `temporal-jobs-worker`, etc. — these hold component-specific env. When debugging a single component's environment, this is the ConfigMap to read.

**Temporal subchart ConfigMaps (when `temporal.deploy: true`):**

`<release>-temporal-subchart-dockerize-config`, `<release>-temporal-subchart-dynamic-config` — Temporal server configuration.

For each pod that is not Ready or has restarted, capture the snapshot row.

## Step 2 — Symptom routing

For each unhealthy pod, classify by `status.phase` + `containerStatuses[].state` + last event:

| Symptom | First action | Then |
|---|---|---|
| `Pending`, `FailedScheduling` | `kubectl describe pod` → read `Events:` | check node capacity, taints, GPU availability |
| `Pending`, `Unschedulable` due to PVC | `kubectl get pvc -n <ns>` and `kubectl get pv` | StorageClass / PV provisioner issue |
| `Waiting: ImagePullBackOff` / `ErrImagePull` | `kubectl describe pod` → read pull error | imagePullSecrets, image tag existence, registry reachability |
| `Waiting: CreateContainerConfigError` | `kubectl describe pod` → secret/configmap reference | named secret or key missing; check `<release>-*-env` Secrets |
| `Waiting: CrashLoopBackOff` | `kubectl logs <pod> --previous` | match against `patterns.md` |
| `Running`, `0/1 Ready`, restartCount stable | readiness probe failing | `kubectl describe pod` → readiness probe + check Service endpoints |
| `Running`, `0/1 Ready`, restartCount climbing | liveness probe killing it | `kubectl describe pod` → liveness probe + recent logs |
| `Terminated: OOMKilled` | check `resources.limits.memory` vs `kubectl top pod` | bump limit or downsize work |
| `Terminated: Error`, exit code 137 | similar to OOM (signal 9) | check node memory pressure |
| `Terminated: Error`, exit code 143 | SIGTERM during graceful shutdown — usually rollout, not a bug | only worry if it's an active loop |

For pods in `CrashLoopBackOff`, always grab:

```bash
kubectl logs <pod> -n <ns> --all-containers --previous --tail=200
kubectl logs <pod> -n <ns> --all-containers --tail=100
kubectl describe pod <pod> -n <ns>
```

Then read the first 5–10 ERROR/FATAL lines and look them up in `patterns.md`.

## Step 3 — Cross-pod / network checks

Some failures aren't a single bad pod, they're a routing problem between pods. Common ones:

```bash
# Service endpoints — if empty, no Pods match the Service selector or none are Ready
kubectl get endpoints -n <ns>

# DNS from inside a healthy pod (if any exist)
# Pick a Running pod; nslookup of dependency hostnames and sibling Services.
# NOTE: the LlamaCloud backend Service is named `llamacloud` (not
# `<release>-backend`); see the deployment-naming table above. Subchart
# Services like temporal DO use the `<release>-` prefix.
kubectl exec -n <ns> <healthy-pod> -- nslookup llamacloud
kubectl exec -n <ns> <healthy-pod> -- nslookup llamacloud-web
kubectl exec -n <ns> <healthy-pod> -- nslookup <release>-temporal-subchart-frontend
# (kubectl exec is read-only-equivalent for diagnosis; ask user before running this)

# NetworkPolicy egress
kubectl get networkpolicy -A
# The chart itself ships only ONE NetworkPolicy (`<release>-agent-backend-egress`,
# in the namespace configured by `llama-agents-subchart.apps.namespace` (default
# `llama-agents`), only when llamaAgents.deploy is true and
# llamaAgents.allowBackendEgress is true). It allows egress from agent pods TO
# the backend, not the other way around. Any other NetworkPolicy you see is
# customer-managed and may be blocking pod-to-pod traffic.
```

If `kubectl exec` is sensitive in the customer's environment (it usually is in production), ask before running and explain what you're checking. If declined, continue with describe/logs only.

## Step 4 — Cloud-side checks (only if relevant)

If the symptom points at a managed dependency (DB connection refused, S3 access denied, OIDC discovery failing), and the cluster is on AWS/Azure/GCP, run the same read-only cloud checks the `preinstall-check` skill uses (Phase 4). Specifically:

- DB unreachable → `aws ec2 describe-security-groups` cross-check between cluster SG and DB SG
- S3 access denied → `aws iam get-role --role-name <irsa-role>` and check the bucket policy / IRSA trust relationship
- OIDC failures → `curl <discoveryUrl>` from the user's laptop and from a debug pod (with consent)

Ask before each cloud CLI call. Read-only by definition.

## Step 5 — Match against `patterns.md`

`patterns.md` (next to this file) catalogs the highest-frequency LlamaCloud-specific failure signatures and maps each to:
- The error message you'll see in logs
- The likely root cause
- The values.yaml field to change (or external action to take)
- A pointer to the relevant `examples/*.yaml`

Read it now if any captured log line matches a pattern entry. Only read the relevant section, not the whole file — `patterns.md` is organized by component to make this efficient.

## Step 6 — Write `debug-report.md`

Always write the report. This is what the user sends to support if you can't fix it.

```
# LlamaCloud debug report — <ISO timestamp UTC>

## Summary
<one-sentence statement of what's wrong, e.g. "3 backend pods in CrashLoopBackOff, all failing on Postgres connection refused. Most likely cause: cluster SG missing from RDS inbound rules.">

## Inputs
- Release: <name>
- Namespace: <ns>
- Chart version: <`helm get metadata <release>` output>
- Cluster context: <ctx>
- Cluster cloud: <aws|azure|gcp|other>

## Pod state
<table of all pods with phase / ready / restarts / age>

## Failing pods — evidence
<for each failing pod>:
  ### <pod-name>
  Symptom: <one-line>
  Container state: <Waiting/CrashLoopBackOff/etc>
  Recent events: <bulleted, sorted by time>
  Last log lines (previous container): <fenced code block, redacted>
  Matched pattern: <patterns.md anchor or "no match">
  Suggested fix: <concrete>

## Recent helm history
<helm history output>

## Cluster events (last hour)
<filtered event list>

## Cloud routing checks
<if run; what was confirmed / what was off>

## Recommended next steps
1. <highest-priority action>
2. <second-priority action>
3. ...

## What to send to support
This report (after a final secret review). Specifically:
- The above
- The output of `kubectl logs <pod> --previous --tail=500` for each failing pod (already captured above; re-run if more context needed)
- `helm get values <release> -n <ns> --revision <rev>` with secrets masked
```

**Mask all secrets** before saving. Run a final regex sweep over the report content for known secret patterns: `password`, `apiKey`, `clientSecret`, `key`, `token`, `connectionString`, `credentialsJson`, JWT-shaped strings, AWS access key ids, RSA/EC PEM headers. If unsure, mask.

## Critical rules

- **Read-only.** No `kubectl edit`, `kubectl patch`, `kubectl delete`, `kubectl rollout restart`, `helm upgrade`, `helm rollback`. Diagnose and recommend; do not "just try restarting the pod."
- **Ask before `kubectl exec`.** It's technically read-only, but customers are sensitive about it. Explain what you'd check and let them say no.
- **Mask secrets in every file you write.** Run a regex sweep before declaring a report written.
- **Don't re-run preinstall checks aggressively.** If the install is up but unhealthy, the relevant subset of preinstall checks is fine — but full Phase 4 cloud surveys can flood the customer's CloudTrail with surprising activity.
- **One symptom at a time.** If multiple pods are unhealthy with different errors, work through them in priority order (backend > workers > optional services), not in parallel — they often have a shared root cause.
- **Stop on cancel.** If the user says "stop" or "that's enough", stop and write whatever is in the report so far.
