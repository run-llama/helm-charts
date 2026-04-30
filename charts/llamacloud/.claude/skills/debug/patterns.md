# LlamaCloud failure pattern catalog

Catalog of common error signatures observed during LlamaCloud installs and operation, mapped to likely root cause, the `values.yaml` field to change, and a pointer to a relevant `examples/*.yaml` file when applicable.

Organized by component so you can read only the section you need. **Do not read the whole file unless triaging a multi-component failure.**

When matching: search for substrings, not exact lines. Log timestamps and pod-name suffixes will differ; the diagnostic text in `**Signature:**` is the stable part.

---

## Backend (`llamacloud-*` — note the deployment is named `llamacloud`, not `llamacloud-backend`)

### Postgres unreachable
**Signature:** `connection to server at "..." failed: Connection refused` / `could not translate host name` / `timeout expired` in backend startup logs, before any "Application startup complete" line.

**Likely cause:** Routing — the cluster's security group / NSG / firewall rule is not allowed inbound on the DB. DNS resolution failure means the hostname is wrong in `postgresql.host` or the DB is in a private VPC the cluster can't resolve.

**Fix:**
- Re-run `preinstall-check` Phase 4 to confirm routing.
- For AWS: `aws ec2 authorize-security-group-ingress --group-id <db-sg> --protocol tcp --port 5432 --source-group <cluster-sg>`.
- For Azure: add the AKS node subnet to the Postgres flexible server's firewall rules.
- For GCP: ensure Cloud SQL is on a VPC peered with the cluster, or enable the public IP with authorized networks.

**Field:** `postgresql.host` and the customer's cloud-side network config (not a chart values change in most cases).

---

### Postgres auth failure
**Signature:** `FATAL: password authentication failed for user "..."` or `FATAL: role "..." does not exist`.

**Likely cause:** `postgresql.username` / `postgresql.password` wrong, or the user exists but has no privileges on the configured database.

**Fix:**
- Confirm credentials with the user (do not echo them).
- Confirm the user has `CONNECT` on the database, `CREATE` on the schema (for migrations), and ideally is the owner of the database.

**Field:** `postgresql.username`, `postgresql.password` (or the secret keyed in `postgresql.secret`).

---

### License error at startup
**Signature:** Backend pod CrashLoops at startup with a log line mentioning the license. Surface the verbatim log line to the user — do not paraphrase.

**Likely cause:** `license.key` is empty, contains a placeholder, or the Secret reference points at an empty / wrong-keyed Secret. Expired licenses also surface here.

**Fix:**
- Confirm the user has a current license key from LlamaIndex.
- If using `license.secret`, the chart expects the Secret to expose key `LLAMACLOUD_LICENSE_KEY`.
- If both look correct and the pod is still crashing, escalate to LlamaIndex support with the verbatim log line — do not attempt to diagnose further.

**Field:** `license.key` or `license.secret`.

---

### Schema migrations stuck or failed
**Signature:** Backend log contains migration progress lines for several minutes; or a migration error like `Can't locate revision identified by '<hash>'`; or `permission denied for schema public`.

**Likely causes:**
- **Stuck (no error)** — large database, migrations running normally. Wait 5–10 minutes before suspecting a problem.
- **`Can't locate revision`** — Postgres is at a schema version newer than what the chart knows about. This happens when downgrading. Stop and route to `runbooks/downgrade.md`.
- **`permission denied for schema public`** — the DB user lacks DDL privileges. Grant them.

**Fix:** depends on which sub-cause; see above.

**Field:** none directly — this is a DB privilege or schema version issue.

---

### Backend can't reach Temporal frontend
**Signature:** Backend pod fails at startup with a transport error talking to the configured Temporal host. The log line will mention failing to connect to the Temporal frontend, with one of these inner causes:
- `failed to lookup address information` / `Name or service not known` → hostname wrong or unreachable
- `Connection refused` → host reachable but no Temporal frontend on the port
- `deadline exceeded` / `connect timeout` → routing / firewall block

**Likely causes:**
- `temporal.deploy: false` but `temporal.host` / `temporal.port` not set.
- `temporal.deploy: true` but the temporal subchart pods are themselves unhealthy — check those first.
- Temporal frontend Service exists but pods aren't Ready (Service has no endpoints).

**Fix:**
- If using external Temporal, set `temporal.host` and `temporal.port`.
- If deploying as subchart, debug the temporal pods (see `Temporal subchart` section below) and confirm `kubectl get endpoints -n <ns> <release>-temporal-subchart-frontend` is non-empty.

**Field:** `temporal.host`, `temporal.port`, or `temporal.deploy`.

---

### Object storage access denied
**Signature:** `AccessDenied` / `403 Forbidden` from the storage provider in backend or worker logs, often during file upload or parse output write.

**Likely causes (vary by storage backend):**
- **AWS S3 with IRSA**: the IAM role's trust relationship doesn't include the chart's ServiceAccount, or its permissions policy doesn't allow `s3:GetObject` / `s3:PutObject` on the configured buckets. Cross-account buckets need a matching bucket policy.
- **AWS S3 with static keys**: the access key / secret are wrong or have insufficient permissions.
- **GCS via s3proxy**: the GCS service account / HMAC key configured in `s3proxy-secret` lacks `storage.objects.*` on the bucket.
- **Azure Blob via s3proxy**: the storage account key / SAS configured in `s3proxy-secret` is wrong or scoped too narrowly.

**Fix:**
- For AWS IRSA: `aws iam get-role --role-name <role>` and confirm the trust relationship's `sub` condition matches `system:serviceaccount:<ns>:<sa-name>` for each ServiceAccount listed under the chart's components (`llamacloud`, `llamacloud-operator`, `llamacloud-worker`, `llamacloud-parse`, etc.).
- Confirm the buckets in `config.storageBuckets.*` exist and the role / static credentials have `Get`, `Put`, `List`, and `Delete` permissions on them.
- For s3proxy backends: render the `s3proxy-secret` with `helm template` (with secrets masked) and confirm the credentials match what the upstream provider expects.

**Field:** `backend.serviceAccountAnnotations.*`, `jobsService.serviceAccountAnnotations.*`, `jobsWorker.serviceAccountAnnotations.*` (annotation key is cloud-specific: `eks.amazonaws.com/role-arn` for AWS, `iam.gke.io/gcp-service-account` for GKE workload identity, etc.), plus the IAM role / IAM binding / static credentials.

---

### OIDC discovery fails
**Signature:** Backend logs a `Fetching OIDC discovery document` line (with the URL), then a sign-in or token-validation request fails with one of these inner causes in the traceback:
- `Name or service not known` → DNS failure (hostname wrong or IDP unreachable from cluster)
- `Connection refused` → wrong port or IDP down
- connect / read timeout → firewall / routing block
- `404 Not Found` on the discovery URL → URL is wrong (often missing `/.well-known/openid-configuration` suffix, or pointing at the token endpoint by mistake)
- `Missing some scopes_supported from OIDC provider: [...]` → discovery succeeded but the IDP doesn't advertise the OpenID scopes the chart needs (`openid`, `profile`, `email`)
- Validation error mentioning a missing field on the discovery response → the IDP's `/.well-known/openid-configuration` document is missing one of the required OIDC fields (`userinfo_endpoint`, `authorization_endpoint`, `token_endpoint`, `jwks_uri`, `id_token_signing_alg_values_supported`)

**Likely causes:**
- `discoveryUrl` is wrong (typo, missing `/.well-known/openid-configuration` suffix, points at a custom token endpoint).
- The IDP is not reachable from inside the cluster (firewall blocks egress to the IDP host).
- The IDP requires authentication for discovery (uncommon but happens with some private IDPs).

**Fix:**
- For Azure AD / Entra: discoveryUrl should look like `https://login.microsoftonline.com/<tenant-id>/v2.0/.well-known/openid-configuration`.
- For Auth0: `https://<tenant>.auth0.com/.well-known/openid-configuration`.
- For Google: `https://accounts.google.com/.well-known/openid-configuration`.
- For Okta: `https://<tenant>.okta.com/.well-known/openid-configuration`.
- Verify reachability from the cluster — with the user's consent, `kubectl exec` into a healthy pod and `curl <discoveryUrl>`.

**Field:** `config.authentication.oidc.discoveryUrl`.

---

## Frontend (`llamacloud-web-*`)

### Frontend pods Ready but login redirect loops
**Signature:** No pod errors. Browser redirects between frontend → IDP → frontend forever.

**Likely causes:**
- `clientId` mismatch between what's configured in the IDP app and `config.authentication.oidc.clientId`.
- Redirect URI in the IDP app doesn't include the frontend's URL.
- Cookie / session storage broken — sometimes happens behind certain ingress configs that strip cookies.

**Fix:**
- Confirm clientId matches.
- Add the frontend URL and its OAuth callback path to the IDP's allowed redirect URIs. (The exact callback path is what the browser sends in the failing redirect — read it off the browser's network tab during the failed login.)
- Test with a fresh browser session / incognito to rule out stale cookies.

**Field:** `config.authentication.oidc.clientId`, plus IDP-side configuration.

---

### Frontend serves but API calls 404 / 502
**Signature:** Browser shows the dashboard skeleton, but XHR requests to `/api/*` fail.

**Likely causes:**
- Ingress is routing only the root path to the frontend, not `/api/*` to the backend.
- Backend Service has no endpoints (backend pods exist but aren't Ready, so `kubectl get endpoints -n <ns> llamacloud` shows none).

**Fix:**
- Review ingress rules; the chart's default sets up paths correctly but custom ingress configs sometimes drop them. See `examples/basic-ingress-config.yaml`.
- Verify backend endpoints: `kubectl get endpoints -n <ns> llamacloud` (Service is named `llamacloud`, not `llamacloud-backend`).

**Field:** `ingress.*` or backend pod readiness.

---

## LlamaParse (`llamacloud-parse-*`)

### Parse pods can't reach OCR service
**Signature:** Parse worker logs contain `Connection refused` or `timeout` to an OCR endpoint.

**Likely causes:**
- `config.parseOcr.enabled: false` so no in-cluster OCR pod was deployed.
- `config.parseOcr.enabled: true` but OCR pods are not Ready (typically GPU node shortage — see `LlamaParse OCR` below).
- A cluster-wide NetworkPolicy installed by the customer that blocks pod-to-pod egress in the namespace. (The chart itself does not ship a NetworkPolicy on the parse → OCR path; the only chart-shipped NetworkPolicy is `<release>-agent-backend-egress`, deployed only when `llamaAgents.deploy: true` and `llamaAgents.allowBackendEgress: true`, and it lives in the `llama-agents-subchart.apps.namespace` namespace — default `llama-agents`.)

**Fix:**
- Set `config.parseOcr.enabled: true` and confirm OCR pods are Ready.
- `kubectl get networkpolicy -A` to find any cluster-wide policies that might be blocking pod-to-pod traffic in the namespace.

**Field:** `config.parseOcr.enabled`.

---

### Parse jobs queueing but never starting
**Signature:** RabbitMQ queue depth on parse-related queues climbs but parse pods are idle. Or in Temporal mode, workflows visible but no activities running.

**Likely causes:**
- Worker count too low for the load. Scale `llamaParse.replicas` up.
- Workers can't reach RabbitMQ / Temporal (auth or routing).
- Workers in `CrashLoopBackOff` — check pod state first.

**Fix:** scale workers, or fix connectivity, or fix the underlying pod crash.

**Field:** `llamaParse.replicas`, RabbitMQ config, Temporal config.

---

## LlamaParse OCR (`llamacloud-ocr-*`)

### OCR pods stuck Pending
**Signature:** `0/N nodes available: N node(s) didn't have free ports for the requested pod ports` — or more commonly, `0/N nodes available: untolerated taint {nvidia.com/gpu: ...}` or `Insufficient nvidia.com/gpu`.

**Likely causes:**
- No GPU nodes in the cluster.
- GPU nodes exist but have a taint the pod doesn't tolerate.
- GPU device plugin (nvidia-device-plugin daemonset) is not running on the node.

**Fix:**
- Add GPU nodes to the cluster — instance type / family depends on the cloud (e.g. `g5`/`g6` on AWS, `NCv3`/`NCa10` on Azure, `A2`/`A3` on GCP, or any other NVIDIA GPU machine type the customer has access to).
- Ensure `llamaParseOcr.tolerations` matches the actual taint on the GPU nodes (the exact taint depends on how the customer set up their GPU pool; common form is `nvidia.com/gpu=true:NoSchedule` or `nvidia.com/gpu=:NoSchedule`).
- Install / verify whatever GPU device plugin the customer's cluster uses (typically the upstream `k8s-device-plugin` DaemonSet or the NVIDIA GPU Operator).

**Field:** `llamaParseOcr.tolerations`, `llamaParseOcr.nodeSelector`, plus cluster-side GPU node setup (out of scope for the chart).

---

### OCR pod CrashLoopBackOff with CUDA error
**Signature:** Logs contain `CUDA error` or `no CUDA-capable device is detected`.

**Likely causes:**
- GPU node is missing the nvidia-container-runtime / nvidia-device-plugin.
- Pod was scheduled to a node without a real GPU (taint/toleration setup is wrong such that the pod can land on non-GPU nodes).
- Driver mismatch between host and container.

**Fix:** verify the device plugin DaemonSet is healthy on the node, and confirm `llamaParseOcr.nodeSelector` actually pins to GPU nodes.

**Field:** `llamaParseOcr.nodeSelector`, plus cluster-side GPU setup.

---

## Layout detection (`llamacloud-layout-*` / `llamacloud-layout-v3-*`)

### Layout pods stuck Pending
Same root causes as OCR pods Pending. Same fix.

### Layout V3 image won't pull
**Signature:** `pull access denied` or `manifest unknown` for the layout-v3 image, often when `imagePullPolicy: IfNotPresent` is set and the registry is private.

**Likely causes:**
- `imagePullSecrets` not configured (private registry without auth).
- The image tag in `llamaParseLayoutDetectionApiV3.image` doesn't exist at the configured registry.
- `imagePullPolicy: IfNotPresent` was set with the assumption that the image is pre-loaded onto the node (e.g. baked into a custom node image), but the node it landed on doesn't have it. `IfNotPresent` only avoids the pull if the image is *already on the node*; on a fresh node with no cached image, the pull still has to succeed.

**Fix:** either configure `imagePullSecrets` (`examples/private-registry-config.yaml` shows the shape, layered on top of a base values file) and let the kubelet pull on-demand, or ensure the image is reachable from every node the pod might land on.

**Field:** `llamaParseLayoutDetectionApiV3.image`, `llamaParseLayoutDetectionApiV3.imagePullPolicy`, `imagePullSecrets`.

---

## Temporal subchart (`<release>-temporal-subchart-*`)

### Temporal frontend / history / matching CrashLoopBackOff with `database not found`
**Signature:** Logs contain `database "temporal" does not exist` or `database "temporal_visibility" does not exist`.

**Likely cause:** `temporal-subchart.schema.createDatabase.enabled` is false, or the configured Postgres user lacks `CREATE DATABASE` privilege so the auto-create failed silently.

**Fix:**
- Set `temporal-subchart.schema.createDatabase.enabled: true` (default).
- Grant the Postgres user `CREATEDB`, or pre-create both `temporal` and `temporal_visibility` databases manually and set `createDatabase.enabled: false`.

**Field:** `temporal-subchart.schema.createDatabase.enabled`, plus DB privileges.

---

### Bundled Cassandra / MySQL / Postgres / ES / Prometheus / Grafana running unexpectedly
**Signature:** Pods named `<release>-temporal-subchart-cassandra-*` or `-postgresql-*` etc. exist, often Pending due to PVC issues or unschedulable.

**Likely cause:** Bundled deps not disabled in the values file. The chart's defaults match what most users want, but the temporal subchart defaults differ.

**Fix:** set all of these to `false` in the values file:
```yaml
temporal-subchart:
  cassandra:
    enabled: false
  mysql:
    enabled: false
  postgresql:
    enabled: false
  elasticsearch:
    enabled: false
  prometheus:
    enabled: false
  grafana:
    enabled: false
```

**Field:** `temporal-subchart.{cassandra,mysql,postgresql,elasticsearch,prometheus,grafana}.enabled`.

---

### Temporal admin-tools job failing
**Signature:** A Job named `<release>-temporal-subchart-schema-<n>` (e.g. `<release>-temporal-subchart-schema-1`) ends `Failed`.

**Likely cause:** Schema setup couldn't connect to Postgres, or the user lacks privileges.

**Fix:** find the Job's pod (`kubectl get pods -n <ns> -l job-name=<release>-temporal-subchart-schema-1`) and read its logs (`kubectl logs <pod> -n <ns>`). Look for Postgres connection or permission errors and route to the matching backend Postgres pattern above.

---

## Jobs worker (`llamacloud-worker-*`)

### Worker `OOMKilled`
**Signature:** Pod terminated with reason `OOMKilled`, typically during a large parse or extract job.

**Likely cause:** Default memory limit (10Gi guarantee, no burst by default) is too tight for the workload.

**Fix:** raise `jobsWorker.resources.limits.memory` (and matching `requests` if you want guaranteed QoS), or split work into smaller batches.

**Field:** `jobsWorker.resources.{requests,limits}.memory`.

---

### Worker can't reach RabbitMQ
**Signature:** `Connection refused` / `auth failed` / `Channel closed unexpectedly` to the RabbitMQ host.

**Likely causes:** Same shape as Postgres-unreachable but for AMQP. Routing or auth.

**Fix:**
- For Amazon MQ AMQPS (5671): confirm `rabbitmq.scheme: amqps` and the cluster SG is in the broker's inbound rules on TCP 5671.
- For Azure Service Bus: use `rabbitmq.connectionString` instead of host/port/username/password.
- For RabbitMQ on a public endpoint (uncommon): no firewall rule needed but auth and TLS still apply.

**Field:** `rabbitmq.scheme`, `rabbitmq.host`, `rabbitmq.port`, `rabbitmq.connectionString`, plus cloud-side networking.

---

## Ingress

### Ingress not reachable
**Signature:** `kubectl get ingress -n <ns>` shows the ingress but `ADDRESS` is empty, or DNS resolves but HTTPS times out.

**Likely causes:**
- No ingress controller installed in the cluster (the customer must run one — common choices include nginx-ingress, the AWS Load Balancer Controller, GKE/AKS-native ingress, or a third-party controller of their choice; the chart doesn't bundle one).
- Ingress controller installed but its `ingressClassName` doesn't match the chart's Ingress resource.
- TLS Secret named in `ingress.tlsSecretName` doesn't exist in the same namespace as the Ingress.
- For AWS ALB: certificate ARN annotation points at a cert in a different region, or the cert is not in `Issued` state.

**Fix:** install / fix the ingress controller, then debug whichever is the missing piece.

**Field:** `ingress.enabled`, `ingress.host`, `ingress.tlsSecretName`, `ingress.annotations`.

---

## Generic patterns

### Pod stuck in `Init` for >5 minutes
**Signature:** `Init:0/N` for a long time, no progress.

**Likely causes:**
- An init container is waiting on something external (DB, Temporal, etc.) that's unreachable. Route to the matching connectivity pattern.
- If the customer runs a service mesh (Istio, Linkerd, Cilium, etc.) the mesh's init/sidecar injection can hang waiting for the mesh control plane — this is a customer-side mesh problem, not a chart problem.

**Fix:**
- `kubectl logs <pod> -c <init-container>` to see what it's waiting on.
- For mesh issues: ask the customer to fix their mesh, or remove the mesh's injection annotations from the affected component's `*.podAnnotations` until the mesh is healthy.

---

### `helm install` says "another operation in progress"
**Signature:** `Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress`.

**Likely cause:** A previous install/upgrade was interrupted (helm killed mid-flight, network blip, etc.) and the release is locked.

**Fix:** **do not pass `--force`.** Either:
- Wait for the existing operation to time out (typically minutes), then retry.
- If you're sure no operation is actually running: `helm rollback <release> 0 -n <ns>` (which clears the lock by rolling forward to current). For a fresh install with no prior revisions, `helm uninstall <release> -n <ns> --keep-history` and retry.

---

### `Error: rendered manifests contain a resource that already exists`
**Signature:** During `helm install`, helm refuses because a resource with the same name exists outside helm's ownership.

**Likely cause:** The user manually created a resource (often a Secret or ConfigMap) that the chart now wants to manage.

**Fix:** either delete the conflicting resource (after confirming with the user that it's safe to do so), or annotate it for adoption: `kubectl annotate <kind> <name> meta.helm.sh/release-name=<release> meta.helm.sh/release-namespace=<ns>` and label `app.kubernetes.io/managed-by=Helm`.

---

## When nothing matches

If the captured log lines don't match any pattern here, write them verbatim into the `debug-report.md` (with secrets masked) and recommend the user share the report with LlamaIndex support. Do not invent a fix.
