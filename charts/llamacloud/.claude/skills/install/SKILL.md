---
name: install
description: Run `helm install` (or `helm upgrade --install`) for the LlamaCloud chart, monitor the rollout in real time, surface failing pods immediately, and capture a diagnostic bundle if anything fails. Use when the user says "install the chart", "run helm install", "deploy llamacloud", "upgrade", or naturally follows a successful preinstall-check. Runs with `--wait --timeout` and intentionally **does not** pass `--atomic`, so failed pods remain in place for the `debug` skill to investigate. Read-only against the cluster except for the helm install itself.
---

# Install the LlamaCloud Helm chart

Goal: take the user from a validated `values.yaml` to a healthy release, surface failures within seconds (not at the helm timeout), and produce a diagnostic bundle if the install fails so the user can hand it to LlamaIndex support without further debugging.

## Pre-flight gate

Before touching anything, confirm:

1. A recent `preinstall-report.md` exists next to the values file and ends in `READY TO INSTALL`. If not, refuse and direct the user to run the `preinstall-check` skill first. Customer installs that skip preinstall checks fail roughly an order of magnitude more often.
2. Re-confirm `kubectl config current-context` and pause for explicit approval. Yes, this is the second time today — confirm anyway.
3. Confirm the release name, namespace, chart version, and values file paths.
4. Confirm the install mode:
   - **Fresh install** → `helm install <release> ...`
   - **Upgrade an existing release** → `helm upgrade --install <release> ...` and warn that an upgrade may run database schema migrations. If downgrading, point at `runbooks/downgrade.md` and stop — downgrades require an extra manual schema step before the helm command.

## Helm repo setup

If the user is installing from the published chart:

```bash
helm repo add llamaindex https://run-llama.github.io/helm-charts
helm repo update llamaindex
helm search repo llamaindex/llamacloud --versions | head -10
```

If installing from a local chart directory (e.g. testing a checkout), skip the repo dance and use the path directly. Confirm `Chart.yaml` is present and its `version` matches what the user expects.

## The install command

Strong defaults — do not relax any of these without an explicit reason from the user:

```bash
helm upgrade --install <release> llamaindex/llamacloud \
  --version <chart-version> \
  --namespace <namespace> \
  --create-namespace \
  -f <values-file> \
  [-f <additional-values>] \
  --wait \
  --timeout 20m \
  --debug
```

Why each flag matters:

| Flag | Why |
|---|---|
| `--wait` | Block until all Deployments / StatefulSets / Jobs report ready. Otherwise helm returns success the moment the API objects are created, before pods actually start. |
| `--timeout 20m` | LlamaCloud has 8+ Deployments plus optional Temporal + llama-agents subcharts. Database migrations can run for several minutes on a fresh install. 15m is too tight; 30m is fine if the user wants extra slack. |
| `--debug` | Streams template render details to stderr. Cheap insurance against silent template failures. |

**Do NOT use `--atomic`.** It is tempting because it gives a clean "success or rolled-back" outcome, but on failure it deletes all the pods immediately — which destroys the evidence needed to diagnose what went wrong. Failed pods must stay in place so the `debug` skill (or the user / LlamaIndex support) can read their logs and events. The downside of leaving a failed release in place is recoverable: see "On failure" below for the manual cleanup path. Loss of debugging evidence is not.

Similarly, **do NOT use `--cleanup-on-fail`** for upgrades — same reason.

Run the install **in the background** so monitoring can run concurrently:

```bash
helm upgrade --install ... > /tmp/llamacloud-helm-install-$(date +%s).log 2>&1 &
HELM_PID=$!
```

Capture the PID. Tail the log periodically and surface salient lines.

## Parallel monitoring loop

Goal: detect bad pods early so the user gets actionable feedback within seconds of a failure, not 20 minutes later when helm gives up. With `--atomic` removed, failing pods will remain in place after the timeout, but capturing logs continuously is still valuable — pods sometimes get evicted or restarted by the kubelet between failure and the user inspecting them, and `kubectl logs --previous` only goes back one container generation.

While the helm process is alive, every 10–15 seconds:

```bash
# Pod status table
kubectl get pods -n <ns> -o json | jq -r '
  .items[] | [
    .metadata.name,
    .status.phase,
    (.status.containerStatuses // [] | map(.ready) | all | tostring),
    (.status.containerStatuses // [] | map(.restartCount) | add // 0 | tostring),
    (.status.containerStatuses // [] | map(.state | keys[0]) | unique | join(","))
  ] | @tsv'

# Recent warning events
kubectl get events -n <ns> --field-selector type=Warning \
  --sort-by=.lastTimestamp -o json | jq -r '
  .items[-20:] | .[] | [.lastTimestamp, .involvedObject.kind, .involvedObject.name, .reason, .message] | @tsv'
```

Categorize each pod into:

- **healthy** — `Running` and all containers ready
- **starting** — `Pending` or container `Waiting` with reason `ContainerCreating`/`PodInitializing` and pod age `< 90s`
- **stuck** — `Pending` with reason `FailedScheduling`, or `Waiting` with reason in {`ImagePullBackOff`, `ErrImagePull`, `CrashLoopBackOff`, `CreateContainerConfigError`}, or `Terminated` with reason in {`Error`, `OOMKilled`, `ContainerCannotRun`}
- **migrating** — backend pod whose log lines indicate a schema migration is in progress (e.g. `Running upgrade`) — these can legitimately take minutes; do not flag as stuck on the basis of `0/1 Ready` alone

For each pod that flips from `starting` to `stuck`, immediately and synchronously capture:

```bash
kubectl describe pod <pod> -n <ns> > /tmp/llamacloud-install-bundle/<pod>-describe.txt
kubectl logs <pod> -n <ns> --all-containers --tail=500 > /tmp/llamacloud-install-bundle/<pod>-logs.txt 2>&1
kubectl logs <pod> -n <ns> --all-containers --previous --tail=500 > /tmp/llamacloud-install-bundle/<pod>-logs-previous.txt 2>&1 || true
```

Surface a one-line summary to the user immediately:

> ⚠️ Pod `llamacloud-7d8f-xyz` (backend) entered CrashLoopBackOff. Last log line: `ERROR: connection to server at "..." failed: Connection refused`. Captured to `/tmp/llamacloud-install-bundle/`.

Do not auto-abort on the user's behalf. The pods stay put (because the install command does not pass `--atomic`), so the user has time to review. Offer to abort if the failure mode is one that won't self-resolve (e.g. `ImagePullBackOff` on a wrong tag) but let them decide.

## Decision points during monitoring

While monitoring, you may need to surface options to the user:

1. **Image pull stuck for >60s** — capture diagnostics now and offer the user the option to abort (the failed pods will remain so the `debug` skill can investigate). Image pull issues will not self-resolve. Suggested abort sequence (only if the user agrees):
   - `kill $HELM_PID` to stop helm waiting
   - For a fresh install: `helm uninstall <release> -n <ns> --keep-history` (keeps history for inspection; pods are removed when the release is uninstalled, so capture logs first)
   - For an upgrade: leave the release in place; the previous revision is still active

2. **Backend pod restarting >3 times with schema-migration error lines** — migrations are failing. Capture, then advise the user to check whether their Postgres user has CREATE privileges on the database. Do not auto-abort; migrations on large databases can legitimately take time.

3. **All pods Ready before timeout** — wait for the helm process to exit with success. Do not declare success on pod readiness alone; helm's post-install Job hooks may still be running.

4. **Helm exits with `release "<name>" failed`** — pods remain in place. The `debug` skill takes over from here. Consolidate the diagnostic bundle and point the user at it.

## On success

When the helm process exits 0:

```bash
helm status <release> -n <ns>
kubectl get all -n <ns>
kubectl get ingress -n <ns>
```

Report to the user:

- The release status and revision number from `helm status`.
- Pod-by-Deployment summary (ready/desired counts).
- How to reach the frontend:
  - If `ingress.enabled: true`, the configured `ingress.host`.
  - Otherwise: `kubectl port-forward -n <ns> svc/llamacloud-web 3000:80` (Service is named `llamacloud-web`, port 80 → targetPort 3000; the user can then open `http://localhost:3000`).
- Suggest one smoke test: load the frontend URL in a browser, sign in via the configured OIDC provider, and confirm the dashboard renders. If anything breaks at this stage, route to the `debug` skill.
- Remind them to delete `/tmp/llamacloud-helm-install-*.log` if it contains anything sensitive (it should not, but check).

## On failure

When helm exits non-zero (timeout, dependency failure, etc.) — pods remain in place. The user is in a position to debug or hand off to the `debug` skill.

1. Consolidate the diagnostic bundle. Final structure:

   ```
   /tmp/llamacloud-install-bundle/
     SUMMARY.md                 ← top-level, human-readable
     helm-install.log           ← stderr/stdout of the helm process
     helm-history.txt           ← `helm history <release> -n <ns>`
     events.txt                 ← `kubectl get events -n <ns> --sort-by=.lastTimestamp`
     pods.txt                   ← `kubectl get pods -n <ns> -o wide`
     <pod>-describe.txt         ← per-pod describes captured during monitoring
     <pod>-logs.txt             ← per-pod logs captured during monitoring
     <pod>-logs-previous.txt    ← per-pod previous-container logs
     values-resolved.yaml       ← `helm get values <release> -n <ns>` if release exists, with secrets masked
   ```

2. Write `SUMMARY.md` with:
   - Release / namespace / chart version / values files
   - Helm exit message
   - Top 3 most likely root causes, ranked, with concrete remediations
   - Pointer to the relevant `examples/*.yaml` for each remediation

3. **Mask any secret in `values-resolved.yaml`**. Use `helm get values <release> -n <ns> -o yaml | yq` and run a final regex sweep before writing. If unsure, mask.

4. Tell the user where the bundle is and what to do next:
   - The release is still in place. They can inspect pods with `kubectl get pods`, `kubectl describe pod`, `kubectl logs --previous` directly.
   - For structured triage, suggest the `debug` skill — it handles symptom-routing automatically.
   - When ready to retry: fix the root cause in values.yaml, then re-run this skill. Helm will detect the existing release and run an upgrade. If the release is in a stuck `pending-install` state, run `helm uninstall <release> -n <ns>` first (this WILL delete pods — capture anything you need first).
   - The bundle is shareable with LlamaIndex support after a final secret review.

## Common install failures and what to look for

These are the highest-frequency failure signatures during a fresh install. When you see them, jump straight to the matching remediation.

### `ImagePullBackOff` / `ErrImagePull`
- For `docker.io/llamaindex/...` images: usually Docker Hub anonymous pull rate limits. Suggest configuring `imagePullSecrets` with a Docker Hub PAT, or mirroring images to the customer's own registry. The shape is shown in `examples/private-registry-config.yaml` (note: this is an overlay file, layer it on top of `basic-config.yaml` with `-f basic-config.yaml -f private-registry-config.yaml`).
- For private-registry images: `imagePullSecrets` missing, or the secret exists but does not have `auths.<registry>` matching the image's registry host.
- For tags that don't exist: typo in `appVersion` or one of the `<component>.image` overrides.

### `CrashLoopBackOff` on backend with `connection refused` / `could not translate host name`
- Postgres / MongoDB / RabbitMQ / Redis hostname doesn't resolve from inside the cluster, or the cluster security group is not in the inbound rules of the dependency. Re-run `preinstall-check` Phase 4 to verify routing. The fix is almost always a security group / NSG / firewall rule, not a values change.

### `CrashLoopBackOff` on backend with `License validation failed`
- `license.key` is wrong, expired, or being read from a Secret that is empty / wrong key name. Confirm the value with the user (without echoing it).

### `CrashLoopBackOff` on backend with `Can't locate revision` schema-migration error
- Postgres database state is ahead of the chart version (e.g. user attempted to install an older chart over a newer schema). Stop and route to `runbooks/downgrade.md` — this needs the manual schema-downgrade procedure before the install can proceed.

### Pods stuck `Pending` with `0/N nodes available: insufficient cpu/memory`
- Cluster is too small. Either scale up nodes, or reduce the chart's resource requests. Note that `llamaParse` and `jobsWorker` set `requests == limits` (Guaranteed QoS) so they can't be packed tightly.

### Pods stuck `Pending` with `0/N nodes available: 1 node(s) had untolerated taint {nvidia.com/gpu: true}`
- Inverted: the pod expects GPU but lacks the toleration, or vice versa. Check `llamaParseOcr.tolerations` and `llamaParseLayoutDetection*.tolerations` against the actual taints on the GPU nodes (`kubectl get nodes -o json | jq '.items[].spec.taints'`).

### Temporal subchart pods crashing
- Bundled deps left enabled. Confirm `temporal-subchart.{cassandra,mysql,postgresql,elasticsearch,prometheus,grafana}.enabled: false`.
- Postgres user lacks CREATE DATABASE privileges. Temporal's setup job creates `temporal` and `temporal_visibility` databases. Either grant the privilege or pre-create the databases and set `temporal-subchart.schema.createDatabase.enabled: false`.

### Pods stuck `Init:0/1` or `Init:0/N`
- An init container is waiting on an external dependency (DB, Temporal frontend, etc.) that's unreachable. `kubectl logs <pod> -c <init-container>` shows what it's waiting on; route to the matching connectivity pattern.
- If the customer runs a service mesh (Istio, Linkerd, Cilium, etc.) and the mesh's sidecar/init injection is broken, the pod's init can hang waiting for the mesh control plane. This is not a chart issue. The customer needs to fix their mesh, or remove mesh injection annotations from the affected component's `*.podAnnotations` until the mesh is healthy.

## Critical rules

- **Never use `--atomic` or `--cleanup-on-fail`.** They roll back on failure, which deletes the pods. The user (or the `debug` skill) needs the failed pods in place to diagnose root cause. Loss of evidence is much more painful than a release left in a `failed` state — the latter is recoverable with a single `helm uninstall` once the user has finished debugging.
- **Capture diagnostics during the install.** The kubelet may restart pods between failure and inspection; `kubectl logs --previous` only goes back one container generation. The monitoring loop's captured logs are the canonical record.
- **Mask secrets in the bundle.** `helm get values` prints them in plaintext by default; do not write that to disk untouched.
- **Stay read-only outside helm.** No `kubectl edit`, no `kubectl patch`, no `kubectl delete` of customer resources during the install. Helm is the only mutator.
- **One install at a time.** If helm reports `another operation (install/upgrade/rollback) is in progress`, do not pass `--force`. Stop and figure out what the previous operation was doing.
