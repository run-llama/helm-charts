---
name: preinstall-check
description: Validate a values.yaml and verify cluster + dependency reachability before running `helm install` for the LlamaCloud chart. Use when the user says "preinstall check", "validate my values", "check before install", "preflight", or before any first-time install or upgrade. Performs static schema validation, cluster capacity inspection, local network probes, and read-only routing checks against managed cloud services (AWS / Azure / GCP). Fully read-only by default; only one optional phase can create a short-lived Job, and only with explicit user consent.
---

# Pre-install check for the LlamaCloud Helm chart

Goal: catch the issues that cause `helm install` to hang or fail, before it runs. Output a markdown report next to the user's values file (`preinstall-report.md`) that they can attach to a support ticket if anything fails.

This skill MUST stay read-only by default. The customer's cluster is theirs; do not create resources without consent.

## Inputs you need from the user

Before running anything, gather:

1. **Values file path(s)** — what they intend to pass to `helm install -f ...`. Multiple `-f` files are common (`-f base.yaml -f override.yaml`); accept the same set the install command will use.
2. **Target namespace** — default `llamacloud`.
3. **Target release name** — default `llamacloud`.
4. **Chart version** — read from `Chart.yaml` if running from a chart checkout, otherwise ask.

Then, before the first cluster-touching command:

```bash
kubectl config current-context
```

Read the context name back to the user verbatim and wait for explicit confirmation. Mistargeting kubeconfig is the highest-blast-radius failure mode for this skill — never skip this step.

## Phase 1 — Static validation (no cluster contact)

Run from the chart directory (where `Chart.yaml` lives):

```bash
helm lint --strict . -f <values-file>
helm template <release> . -n <namespace> -f <values-file> --debug > /tmp/llamacloud-rendered.yaml
echo "template exit: $?"
```

⚠️ **`helm lint` is not enough.** This chart uses `fail` template functions to validate required combinations (e.g. "temporal.host and temporal.port are required when temporal.deploy is false"). `helm lint --strict` reports these as `[INFO] Fail:` messages but **still exits 0**. The real static validator is `helm template` — it exits non-zero on the same errors. Always check the `helm template` exit code, not just `helm lint`.

Assert each item; record pass/warn/fail in the report:

- [ ] `helm lint --strict` exits 0. This validates against `values.schema.json` and catches schema-level misconfigurations.
- [ ] `helm template ... --debug` exits 0. This catches template-level required-field errors that lint misses (the chart's `fail` template functions). If this fails, surface the rendering error verbatim — it points directly at the missing field.
- [ ] No unreplaced placeholders in the values file. Grep for `<REPLACE-WITH`, `<input-`, `<your-`, `<uncomment-`, `<insert-`. Report each occurrence with line number.
- [ ] Credential mutex: each of `license`, `postgresql`, `mongodb`, `rabbitmq`, `redis` has *either* inline credentials *or* a non-empty `secret:` ref — not both empty. (For mongodb, `mongodb_url` counts as inline credentials.)
- [ ] If `temporal.deploy: true`, the bundled deps in `temporal-subchart` must be disabled: `cassandra.enabled`, `mysql.enabled`, `postgresql.enabled`, `elasticsearch.enabled`, `prometheus.enabled`, `grafana.enabled` all `false`. Leaving these on is the most common temporal-subchart misconfig and causes pods to fail scheduling or consume unexpected resources.
- [ ] If `temporal.deploy: true`, `temporal-subchart.server.config.persistence.{default,visibility}.sql.{host,user}` are set (typically to the same values as the top-level `postgresql.host` and `postgresql.username`).
- [ ] If `llamaAgents.deploy: true`, the user has confirmed the llama-agents CRDs are pre-installed (the chart does not install them). If unsure, point them at the llama-agents subchart documentation.
- [ ] If `config.storageBuckets.provider` is `gcp` or `azure`, then `config.storageBuckets.s3proxy.enabled` must be `true`. The chart talks S3 protocol natively; non-AWS object stores need s3proxy as a translator.
- [ ] If any image reference in `frontend.image`, `backend.image`, `jobsService.image`, `jobsWorker.image`, `usage.image`, `llamaParse.image`, `llamaParseOcr.image`, `llamaParseLayoutDetectionApi.image`, `llamaParseLayoutDetectionApiV3.image`, `temporalWorkloads.*.image`, or any subchart image points to a private registry, then `imagePullSecrets` is set at the top level.
- [ ] If `imagePullPolicy: IfNotPresent` is set on any custom (non-public) image, warn that `IfNotPresent` only skips the pull when the image is *already cached on the node*; on a fresh node it still has to pull, so `imagePullSecrets` must be configured even with `IfNotPresent`.
- [ ] OIDC: if `config.authentication.oidc.enabled: true`, a `discoveryUrl` is set and looks like a URL (not a placeholder).
- [ ] `appVersion` consistency: any explicitly-pinned image tag should match `Chart.yaml`'s `appVersion` unless the user has a deliberate reason to drift (e.g. running a newer image while the chart catches up).

If any check is `fail`, surface it now and ask whether to continue with the cluster-side phases. Many users would rather fix the static issues first.

## Phase 2 — Cluster capacity (read-only kubectl)

```bash
kubectl version -o json
kubectl get nodes -o json
kubectl get storageclass -o json
kubectl get ns <namespace> -o json 2>/dev/null || kubectl auth can-i create namespace
kubectl auth can-i create deployment,service,ingress,secret,job,configmap,serviceaccount,horizontalpodautoscaler,poddisruptionbudget,networkpolicy,role,rolebinding -n <namespace>
```

Assertions:

- [ ] Server version `>= 1.28`. The chart's stated minimum.
- [ ] Sum of `.status.allocatable.cpu` across all nodes `>= 12`. Sum of `.status.allocatable.memory` `>= 80Gi`. These are the chart's documented hardware minimums; deployments below that will pack tightly and may fail to schedule the larger workloads.
- [ ] If `config.parseOcr.enabled: true` or `config.parseLayoutDetection.enabled: true` or `config.parseLayoutDetectionV3.enabled: true` → at least one node advertises `nvidia.com/gpu` in `.status.allocatable`. Without GPU nodes these pods stay `Pending` indefinitely.
- [ ] At least one StorageClass exists, and either it is annotated as the default (`storageclass.kubernetes.io/is-default-class: "true"`) or the user has configured `storageClassName` explicitly on PVC-using subcharts. Temporal subchart, if deployed, needs PVCs.
- [ ] `kubectl auth can-i` returns `yes` for each required resource type in the target namespace. Discovering RBAC gaps now beats discovering them 15 minutes into the install.

Detect cloud provider from any node's `.spec.providerID` prefix:

| Prefix | Cloud | Phase 4 path |
|---|---|---|
| `aws://` | AWS | run AWS routing checks |
| `azure://` | Azure | run Azure routing checks |
| `gce://` | GCP | run GCP routing checks |
| anything else | on-prem / unknown | skip Phase 4, note in report |

## Phase 3 — Local reachability (no cluster contact)

These are *signals*, not proof. Network paths from the user's laptop and from inside the cluster differ. State this caveat in every Phase 3 result line.

For each configured dependency host:

```bash
getent hosts <host>                                 # DNS resolution
nc -zv -w 5 <host> <port>                           # TCP reachability (skip if `nc` unavailable)
openssl s_client -servername <host> -connect <host>:<port> </dev/null 2>&1 | head -20
                                                    # only if scheme is amqps / rediss / mongodb+srv / TLS-implied port
```

For OIDC:

```bash
curl -fsSL --max-time 10 "<discoveryUrl>"
```

Then validate the JSON includes `issuer`, `authorization_endpoint`, `token_endpoint`, `jwks_uri`. If any are missing, the IDP is misconfigured for OIDC discovery — the chart will fail at backend startup.

For LLM providers (only run if API keys are inline; if behind `secret:` ref, skip with a note):

| Provider | Probe |
|---|---|
| OpenAI | `curl -fsS https://api.openai.com/v1/models -H "Authorization: Bearer $KEY" -o /dev/null -w '%{http_code}\n'` |
| Azure OpenAI | `curl -fsS "$baseUrl/openai/deployments?api-version=2024-12-01-preview" -H "api-key: $KEY" -o /dev/null -w '%{http_code}\n'` |
| Anthropic | `curl -fsS https://api.anthropic.com/v1/models -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" -o /dev/null -w '%{http_code}\n'` |
| Google Gemini | `curl -fsS "https://generativelanguage.googleapis.com/v1beta/models?key=$KEY" -o /dev/null -w '%{http_code}\n'` |
| Vertex AI | skip — uses GCP IAM, not a static key. Verified in Phase 4. |
| AWS Bedrock | skip — uses IRSA. Verified in Phase 4. |

For container images:

```bash
docker manifest inspect llamaindex/llamacloud-backend:<appVersion>
docker manifest inspect llamaindex/llamacloud-frontend:<appVersion>
docker manifest inspect llamaindex/llamacloud-llamaparse:<appVersion>
# and any others referenced in the values file
```

If `docker` is unavailable, fall back to `crane manifest <ref>` if installed, else skip with a note.

**Mask everything.** Do not echo any value that came from a `password`, `apiKey`, `clientSecret`, `key`, `connectionString`, or `credentialsJson` field. In the report write `<masked>` regardless of whether the probe succeeded.

## Phase 4 — Cloud-side routing checks (read-only cloud CLI, opt-in per call)

For the cloud detected in Phase 2. Before each command tell the user what you are about to run and which permission it needs. If the user declines or the call returns a permission error, skip and note it — failure to call != install failure.

This phase is the highest-value part of the skill: misconfigured security groups / NSGs / firewall rules between the cluster and the managed dependencies cause the majority of "DB unreachable" install failures, and they can be detected without ever touching the cluster.

### AWS

```bash
# Cluster networking
aws eks describe-cluster --name <cluster-name> --query 'cluster.{vpc:resourcesVpcConfig.vpcId,sgs:resourcesVpcConfig.securityGroupIds,clusterSg:resourcesVpcConfig.clusterSecurityGroupId}'

# Postgres on RDS — match by endpoint host
aws rds describe-db-clusters --query "DBClusters[?Endpoint=='<host>'].{state:Status,sg:VpcSecurityGroups[].VpcSecurityGroupId,vpc:DBSubnetGroup}"
# Or instance-style:
aws rds describe-db-instances --query "DBInstances[?Endpoint.Address=='<host>'].{state:DBInstanceStatus,sg:VpcSecurityGroups[].VpcSecurityGroupId}"

# MongoDB on DocumentDB — match host suffix .docdb.amazonaws.com
aws docdb describe-db-clusters --query "DBClusters[?contains(Endpoint, '<host>')].{state:Status,sg:VpcSecurityGroups[].VpcSecurityGroupId}"

# RabbitMQ on Amazon MQ — match host suffix .mq.<region>.amazonaws.com or .mq.<region>.on.aws
aws mq list-brokers
# then for the matching broker:
aws mq describe-broker --broker-id <id> --query '{state:BrokerState,sgs:SecurityGroups,subnets:SubnetIds}'

# Redis on ElastiCache — match host suffix .cache.amazonaws.com
aws elasticache describe-replication-groups --query "ReplicationGroups[?contains(NodeGroups[].PrimaryEndpoint.Address, '<host>')].{state:Status,sg:[].SecurityGroupIds}"
# Or for non-replication-group clusters:
aws elasticache describe-cache-clusters --show-cache-node-info --query "CacheClusters[?contains(CacheNodes[].Endpoint.Address, '<host>')].{state:CacheClusterStatus,sg:SecurityGroups[].SecurityGroupId}"

# THE critical cross-check: does the cluster SG appear in inbound rules of each service SG?
for sg in <db-sg> <redis-sg> <mq-sg> <docdb-sg>; do
  aws ec2 describe-security-groups --group-ids "$sg" \
    --query "SecurityGroups[].IpPermissions[].UserIdGroupPairs[?GroupId=='<cluster-sg>']"
done
```

For each service: assert state is the available/healthy value, the VPC matches the cluster VPC, and the cluster SG appears in inbound rules on the right port. Report any mismatch with a concrete remediation snippet (the AWS CLI command to add the SG rule).

S3 buckets (if `config.storageBuckets.provider: aws`):

```bash
for bucket in <each bucket name in config.storageBuckets>; do
  aws s3api head-bucket --bucket "$bucket"
  aws s3api get-bucket-location --bucket "$bucket"
done
```

If any bucket returns `404` or `403`, surface — buckets must exist and be reachable from the IRSA role configured in `backend.serviceAccountAnnotations`.

### Azure

```bash
az aks show -g <rg> -n <cluster> --query '{vnet:agentPoolProfiles[0].vnetSubnetId,nodeRg:nodeResourceGroup}'
az postgres flexible-server show --name <name> --query '{state:state,network:network}'
az cosmosdb show --name <name> --query '{state:provisioningState,vnetRules:virtualNetworkRules,publicAccess:publicNetworkAccess}'
az servicebus namespace show --name <name> --query '{state:status,network:networkRuleSets}'
az redis show --name <name> --query '{state:provisioningState,vnetId:subnetId}'
az storage account show --name <name> --query '{state:provisioningState,network:networkRuleSet}'
```

For each: assert state is `Succeeded`/`Active`, and either the AKS node subnet is in the network rules, or `publicNetworkAccess` is `Enabled` (with a warning that public access is not recommended for production).

### GCP

```bash
gcloud container clusters describe <cluster> --region <region> --format=json
gcloud sql instances describe <instance> --format=json
gcloud redis instances describe <instance> --region <region> --format=json
gcloud storage buckets describe gs://<bucket> --format=json
```

For each: assert running state, network/VPC alignment with the cluster, and IAM bindings include the workload identity service account.

## Phase 5 — Auth probe (opt-in only)

After Phases 1–4 complete, if no auth verification has happened, prompt:

> "Phases 1–4 verified that the cluster *can* reach your dependencies, but did not verify that the configured credentials work. May I run a one-shot `Job` named `llamacloud-preflight-<unix-ts>` in the `<namespace>` namespace?
>
> The job uses image `alpine:3.20`, installs `postgresql-client`, `redis`, `curl` on-the-fly, runs `pg_isready`/`PGPASSWORD=... psql -c 'SELECT 1'`, `redis-cli ping`, and an HTTP probe of the OIDC discovery URL. It exits within 60 seconds, has TTL 60 seconds, and resources `cpu: 100m, memory: 128Mi`. Credentials are passed via env from a one-shot `Secret` that is also TTL-deleted.
>
> Proceed? [y/N]"

Default is no. If the user says no, document that auth was not verified and remind them that the `install` skill will exercise the credentials when backend pods start — connection failures will show up in pod logs at that point.

If the user says yes:

1. Generate the Job and Secret manifests in memory. Do not write them to disk with credentials.
2. `kubectl apply -f -` from stdin.
3. Watch with `kubectl wait --for=condition=complete job/llamacloud-preflight-<ts> --timeout=90s`.
4. Capture stdout via `kubectl logs job/llamacloud-preflight-<ts>`.
5. `kubectl delete job/llamacloud-preflight-<ts>` (TTL would handle it, but delete explicitly anyway).
6. Mask all credentials in the report; only record success/failure per dependency.

## Output: preinstall-report.md

Write next to the values file. Structure:

```
# LlamaCloud preinstall report — <ISO timestamp UTC>

## Verdict
<READY TO INSTALL | BLOCKED — fix items below>

## Summary
- ✅ N checks passed
- ⚠️  N warnings (non-blocking, review recommended)
- ❌ N failures (blocking)

## Inputs
- Values files: <list>
- Namespace: <ns>
- Release: <name>
- Chart version: <ver>
- Cluster context: <ctx>
- Cluster cloud: <aws|azure|gcp|other>

## Phase 1 — Static validation
<bulleted pass/warn/fail with line numbers and references to examples/ when applicable>

## Phase 2 — Cluster capacity
<...>

## Phase 3 — Local reachability (best-effort)
<...>

## Phase 4 — Cloud routing
<...>

## Phase 5 — Auth probe
<skipped (user declined) | results>

## Failures and remediation
<for each failure: a short description, the values.yaml field involved,
 the example file under examples/ that demonstrates the correct shape,
 and the concrete fix>

## What this report did NOT verify
<be explicit: any phases skipped, any dependencies behind `secret:` refs that
 could not be probed, the laptop-vs-cluster path caveat, etc.>
```

The report is meant to be safe to share with LlamaIndex support. **Re-scan it for masked-vs-unmasked secrets before declaring it written.** If you see anything that looks like a credential, redo the masking and warn the user.

## Critical rules

- **Read-only by default.** Phase 5 is the only phase that may mutate the cluster, and only on explicit consent.
- **Never echo a secret.** Mask `password`, `apiKey`, `clientSecret`, `key`, `connectionString`, `credentialsJson`, `accessKey`, `secretKey`, `token`, `JCLOUDS_IDENTITY`, `JCLOUDS_CREDENTIAL`, and any field listed under a `secret:` ref. When in doubt, mask.
- **Confirm context before every cluster command sequence.** A re-confirmation is cheap; a wrong-cluster mutation is not.
- **Reference `examples/`, don't invent.** When recommending a fix, point to a file under `examples/` (`basic-config.yaml`, `basic-azure-openai.yaml`, `basic-ingress-config.yaml`, `private-registry-config.yaml`, `s3proxy-config.yaml`, etc.) that demonstrates the right shape.
- **State the laptop-vs-cluster caveat for every Phase 3 result.** A passing local probe does not prove the cluster can reach the same host.
- **Stop on cancel.** If the user says "stop" or declines a phase, stop. Do not run "just one more check."
