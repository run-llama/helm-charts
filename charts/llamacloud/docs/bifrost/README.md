# Bifrost (Optional LLM Gateway)

Bifrost is an LLM gateway that gives LlamaCloud a single endpoint for upstream LLM providers (OpenAI, Anthropic, Azure OpenAI, Google Vertex AI, AWS Bedrock, and any OpenAI-compatible API). When enabled, it sits between LlamaCloud and the providers and centralises key management, observability, and routing.

> [!NOTE]
> Bifrost is shipped as an **optional subchart** that is **disabled by default**. This chart bundles the upstream [`maximhq/bifrost`](https://github.com/maximhq/bifrost) chart unmodified — anything documented in the [upstream values](https://github.com/maximhq/bifrost/blob/main/helm-charts/bifrost/values.yaml) is configurable via the `bifrost-subchart` key.

## Use Cases

- **Single egress point**: Route all LlamaCloud provider traffic through one in-cluster endpoint
- **Key rotation**: Manage and rotate provider API keys in one place (and via Kubernetes Secrets, not in the LlamaCloud values file)
- **Multi-key load balancing**: Weighted distribution across multiple keys per provider; per-key model allowlists
- **Fallback routing**: Define fallback chains across keys / providers when upstream quotas trip
- **Observability**: Per-request logs and metrics across all providers (Prometheus / OTel exporters built in)
- **Custom endpoints**: Point providers at private or regional endpoints, including OpenAI-compatible APIs (Ollama, LiteLLM, etc.)

## Enabling Bifrost

In your `values.yaml`:

```yaml
bifrost:
  deploy: true

bifrost-subchart:
  # Image tag is pre-pinned in the chart defaults to a stable Bifrost release.
  # Override only when you want to track a different Bifrost version.
  image:
    tag: "v2.3.2"
```

That renders a runnable Bifrost with no providers configured. The sections below add the real configuration you'll need.

## Upgrading from Bifrost v1.x

See the [upstream v2 migration guide](https://docs.getbifrost.ai/migration-guides/v2.0.0).
For private provider endpoints, set `network_config.allow_private_network: true`
under `bifrost-subchart.bifrost.providers.<provider>` in your Helm values.

The new chart rejects legacy `<provider>_key_config.deployments` fields. Move those
maps to key-level `aliases`, as described in the [v1.5 migration guide](https://docs.getbifrost.ai/migration-guides/v1.5.0#breaking-change-10-provider-deployments-removed-migrate-to-aliases).

## Upgrading to Bifrost v2.3

This chart bundles Bifrost `v2.3.2` with upstream chart `2.1.45`, up from `v2.2.1` and chart `2.1.42`. These changes can affect an existing install.

### The management API is locked until you configure access

While dashboard auth is off, Bifrost refuses every `/api` call, the `/ws` socket and `/metrics`. `/health`, the login routes and the paths in `whitelistedRoutes` stay open, and inference routes are not affected. With no setup token configured the answer is `403`. With one configured, a request that does not carry it gets `401`. The dashboard and scripts that call `/api` stop working until you pick one of these:

- **Dashboard auth.** Set `bifrost-subchart.bifrost.authConfig` as in [Admin dashboard authentication](#admin-dashboard-authentication). Scripts can then send the admin credentials as HTTP basic auth.
- **A setup token.** Set `bifrost-subchart.bifrost.setupToken` (it accepts `env.VAR_NAME`) or the `BIFROST_SETUP_TOKEN` environment variable. Scripts send the token in the `X-Bifrost-Setup-Token` header. The dashboard asks for it once and keeps a 12-hour session cookie. Creating the first admin account from the dashboard also needs this token.
- **Whitelisted routes.** `bifrost-subchart.bifrost.client.whitelistedRoutes` lists paths that skip the lock and dashboard auth: an exact path, or a prefix ending in `*`. The chart default is `["/metrics"]`, which keeps the Bifrost `ServiceMonitor` scraping. Helm replaces a list instead of merging it, so keep `/metrics` in any list you set. `"/*"` opens the whole management API to anyone who can reach the service, even after you enable dashboard auth, so use it only where the network is the access boundary.

### Chat calls stay on Chat Completions

Bifrost 2.3 sends a chat call to the Responses API when its model datasheet says the model can reason but not together with tool calls. That conversion drops `seed` and `logprobs`, which LlamaCloud reads. This chart sets `bifrost-subchart.bifrost.client.compat.forceReasoningOnlyModelsToResponses: false`, so every chat call stays on Chat Completions.

### Other changes

- **Fallbacks after a rejected request.** When a request names a model without a provider, Bifrost can add fallbacks to the other providers that serve that model. Those fallbacks no longer run when the first provider rejects the request itself (`400`, `409`, `413`, `415` or `422` with a provider error body). The caller gets that error instead. Fallbacks named in the request or in a routing rule still run on any error.
- **Semantic cache.** The cache no longer stores responses that carry client-executed tool calls. Set `cache_tool_call_responses: true` under `bifrost-subchart.bifrost.plugins.semanticCache.config` to keep caching them.
- **Postgres stores.** On the first v2.3 boot against a Postgres logs store, a background job replaces the single-column owner indexes on `logs` with `(column, timestamp)` indexes, built concurrently. Expect extra index-build I/O after the upgrade. Bifrost now also sets a 120-second `statement_timeout` and `idle_in_transaction_session_timeout` on its Postgres connections. To keep the server defaults, set `statementTimeout` and `idleInTransactionSessionTimeout` to `"0"` under `bifrost-subchart.storage.configStore` and `bifrost-subchart.storage.logsStore`.
- **Startup probe.** When Bifrost runs as a Deployment (`storage.mode: postgres`, or SQLite without a chart-managed volume), the chart now adds a startup probe that waits up to 30 minutes for `/health`, so database migrations during an upgrade are not cut short by the liveness probe.

## Configuration Structure

Bifrost configuration lives under `bifrost-subchart.bifrost`. The two most important sub-keys are `providerSecrets` (Kubernetes Secret → env-var bindings) and `providers` (the gateway's per-provider routing config):

```yaml
bifrost-subchart:
  bifrost:
    # Bind existing Kubernetes Secrets to environment variables. The values
    # are then referenced from the providers block below as "env.VAR_NAME".
    providerSecrets:
      <provider-name>:
        existingSecret: "<k8s-secret-name>"   # Required
        key: "<key-in-secret>"                # Required
        envVar: "<ENV_VAR_NAME>"              # Required

    # Per-provider routing. The structure below is the same one Bifrost
    # expects in its own config.json — see https://getbifrost.ai/schema.
    providers:
      <provider-name>:
        keys:
          - name: "<unique-key-name>"         # Required, must be unique within the provider
            value: "env.<ENV_VAR_NAME>"       # Reference an env var, or a literal API key
            weight: 1                          # Load-balance weight across keys
            models: ["<model-name>", ...]      # Optional: restrict this key to specific models
```

> [!NOTE]
> Keep API keys out of your values file by referencing them as `env.VAR_NAME` and binding them via `providerSecrets`. Literal `value: "sk-..."` works but ships secrets in your release.

## Supported Providers

### OpenAI

```yaml
bifrost-subchart:
  bifrost:
    providerSecrets:
      openai:
        existingSecret: "bifrost-openai"
        key: "api-key"
        envVar: "OPENAI_API_KEY"
    providers:
      openai:
        keys:
          - name: "primary"
            value: "env.OPENAI_API_KEY"
            weight: 1
            models: ["gpt-4o", "gpt-4o-mini"]   # Optional model allowlist
```

### Anthropic

```yaml
bifrost-subchart:
  bifrost:
    providerSecrets:
      anthropic:
        existingSecret: "bifrost-anthropic"
        key: "api-key"
        envVar: "ANTHROPIC_API_KEY"
    providers:
      anthropic:
        keys:
          - name: "primary"
            value: "env.ANTHROPIC_API_KEY"
            weight: 1
```

### Azure OpenAI

Set the Azure endpoint in `azure_key_config` and map model names to deployment names with key-level `aliases`:

```yaml
bifrost-subchart:
  bifrost:
    providerSecrets:
      azure:
        existingSecret: "bifrost-azure"
        key: "api-key"
        envVar: "AZURE_OPENAI_API_KEY"
    providers:
      azure:
        keys:
          - name: "sweden"
            value: "env.AZURE_OPENAI_API_KEY"
            weight: 1
            models:
              - "gpt-4o"
              - "gpt-4o-mini"
            aliases:
              gpt-4o: "my-gpt4o-deployment"
              gpt-4o-mini: "my-gpt4o-mini-deployment"
            azure_key_config:
              endpoint: "https://your-resource.openai.azure.com"
```

### Google Vertex AI

Vertex serves both Gemini and Anthropic Claude models on Google Cloud. Authenticate with a service-account JSON key stored in a Secret:

```yaml
bifrost-subchart:
  bifrost:
    providerSecrets:
      vertex:
        existingSecret: "bifrost-vertex"
        key: "credentials.json"
        envVar: "GOOGLE_CREDENTIALS"
    providers:
      vertex:
        keys:
          - name: "primary"
            value: ""
            weight: 1
            vertex_key_config:
              project_id: "your-gcp-project"
              region: "us-central1"
              auth_credentials: "env.GOOGLE_CREDENTIALS"
```

> [!NOTE]
> Store the entire service-account JSON as the secret value: `kubectl create secret generic bifrost-vertex --from-file=credentials.json=./sa-key.json`. Bifrost reads the JSON string from `GOOGLE_CREDENTIALS` and parses it internally.

### AWS Bedrock

```yaml
bifrost-subchart:
  bifrost:
    providerSecrets:
      bedrock:
        existingSecret: "bifrost-bedrock"
        key: "credentials"
        envVar: "AWS_BEDROCK_CREDENTIALS"
    providers:
      bedrock:
        keys:
          - name: "primary"
            value: ""
            weight: 1
            bedrock_key_config:
              region: "us-east-1"
              access_key: "env.AWS_ACCESS_KEY_ID"
              secret_key: "env.AWS_SECRET_ACCESS_KEY"
```

For IRSA-based auth on EKS, attach an IAM role to the Bifrost ServiceAccount via `bifrost-subchart.serviceAccount.annotations` and leave the static credential fields unset.

### OpenAI-compatible APIs (Ollama, LiteLLM, custom proxies)

Any OpenAI-compatible endpoint can be reached by setting `network_config.base_url`:

```yaml
bifrost-subchart:
  bifrost:
    providers:
      openai:
        keys:
          - name: "ollama-local"
            value: "ollama"                 # Ignored by most OpenAI-compat servers
            weight: 1
        network_config:
          base_url: "http://ollama.ollama.svc.cluster.local:11434/v1"
```

## Common Use Cases

### Encryption key for sensitive data at rest

Bifrost encrypts API keys stored in its config store and any captured request/response payloads. Generate a key and reference it:

```bash
kubectl create secret generic bifrost-encryption \
  --from-literal=encryption-key="$(openssl rand -base64 32)" \
  -n <release-namespace>
```

```yaml
bifrost-subchart:
  bifrost:
    encryptionKeySecret:
      name: "bifrost-encryption"
      key: "encryption-key"
```

> [!IMPORTANT]
> Losing this key means losing access to anything encrypted with it (rotated provider keys still in the config store, archived request traces). Back it up.

### Persistence

**SQLite (default)** — a PVC is mounted at `/app/data`:

```yaml
bifrost-subchart:
  storage:
    mode: sqlite
    persistence:
      enabled: true
      size: 10Gi
      # storageClass: "gp3"  # uncomment to pin
```

**External PostgreSQL (recommended for production)**:

```yaml
bifrost-subchart:
  storage:
    mode: postgres
    persistence:
      enabled: false
  postgresql:
    enabled: false              # don't deploy the bundled Postgres
    external:
      host: "bifrost-pg.example.internal"
      port: 5432
      database: "bifrost"
      username: "bifrost"
      existingSecret: "bifrost-pg-credentials"
      passwordKey: "password"
```

### Admin dashboard authentication

Bifrost starts without an admin account. Until dashboard auth is enabled, it refuses calls to the management API the dashboard uses unless they carry the setup token (see [Upgrading to Bifrost v2.3](#upgrading-to-bifrost-v23)). Enable dashboard auth for any non-dev install:

```bash
kubectl create secret generic bifrost-admin \
  --from-literal=username=admin \
  --from-literal=password="$(openssl rand -base64 24)" \
  -n <release-namespace>
```

```yaml
bifrost-subchart:
  bifrost:
    authConfig:
      isEnabled: true
      existingSecret: "bifrost-admin"
      usernameKey: "username"
      passwordKey: "password"
```

### Ingress for the admin dashboard

```yaml
bifrost-subchart:
  ingress:
    enabled: true
    className: "nginx"
    hosts:
      - host: bifrost.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: bifrost-tls
        hosts:
          - bifrost.example.com
```

Lock this down with `authConfig.isEnabled: true` before exposing publicly.

## Pointing LlamaCloud at Bifrost

Once Bifrost is running, its in-cluster URL is:

```
http://<release-name>-bifrost-subchart:8080
```

Configure LlamaCloud to route through Bifrost using [centralised provider configuration](https://developers.llamaindex.ai/llamaparse/self_hosting/configuration/llm_integrations/centralized-config/) under `config.llms.providerConfigs`. Bifrost already holds the real upstream keys, so the `api_key` field here is just a non-empty placeholder:

```yaml
config:
  llms:
    providerConfigs:
      - id: "bifrost-openai-gpt-4o"
        provider: "openai"
        model_id: "openai-gpt-4o"
        provider_model_name: "gpt-4o"
        enabled: true
        credentials:
          api_key: "bifrost"
          base_url: "http://my-release-bifrost-subchart:8080/openai"

      - id: "bifrost-anthropic-sonnet-4.5"
        provider: "anthropic"
        model_id: "anthropic-sonnet-4.5"
        provider_model_name: "claude-sonnet-4-5"
        enabled: true
        credentials:
          api_key: "bifrost"
          base_url: "http://my-release-bifrost-subchart:8080/anthropic"
```

This chart pre-sets `bifrost-subchart.bifrost.client.enforceAuthOnInference: false` so the placeholder `api_key` works out of the box — Bifrost v1.5+ does **not** treat it as a direct upstream key, it falls through to the keys configured under `bifrost-subchart.bifrost.providers`.

### Optional: per-tenant virtual keys

If you want Bifrost to enforce auth at the gateway (one virtual key per tenant / project, revocable independently of the upstream provider keys), flip `enforceAuthOnInference: true` and pass the virtual key via the `x-bf-vk` header on every `providerConfigs` entry:

```yaml
bifrost-subchart:
  bifrost:
    client:
      enforceAuthOnInference: true

config:
  llms:
    providerConfigs:
      - id: "bifrost-openai-gpt-4o"
        provider: "openai"
        model_id: "openai-gpt-4o"
        provider_model_name: "gpt-4o"
        enabled: true
        credentials:
          api_key: "bifrost"
          base_url: "http://my-release-bifrost-subchart:8080/openai"
        headers:
          x-bf-vk: "sk-bf-..."
```

> [!NOTE]
> The virtual key must be pre-created in Bifrost (via the admin dashboard or API) before LlamaCloud requests will succeed. Bifrost accepts any string prefixed with `sk-bf-` as a virtual key identifier; one common convention is `sk-bf-{uuid4}`.

## Monitoring

If `monitoring.serviceMonitors.enabled` is true (either with the bundled `monitoring.deploy=true` stack or your own Prometheus Operator), a `ServiceMonitor` for Bifrost is rendered automatically — see [docs/monitoring/README.md](../monitoring/README.md). It scrapes Bifrost's `/metrics` endpoint on port 8080 without credentials, so `/metrics` must stay in `bifrost-subchart.bifrost.client.whitelistedRoutes`.

## Verification

After installing, verify the setup:

1. **Pod health**: `kubectl get pods -n <release-namespace> -l app.kubernetes.io/name=bifrost-subchart` — pod should be `Running`, all probes passing.
2. **Provider config loaded**: Port-forward the Bifrost service and check `/api/providers` — every configured provider should appear with its keys masked.
   ```bash
   kubectl port-forward -n <release-namespace> svc/<release>-bifrost-subchart 8080:8080
   curl -H "X-Bifrost-Setup-Token: <setup-token>" http://localhost:8080/api/providers
   ```
   With dashboard auth enabled, pass `-u <admin-username>:<admin-password>` instead of the header.
3. **End-to-end through LlamaCloud**: Upload a document to LlamaParse / run a chat completion. Bifrost's logs (or dashboard, if enabled) should show the request flowing through.

## Further reading

- [Bifrost product docs](https://getbifrost.ai/docs)
- [Configuration schema](https://getbifrost.ai/schema)
- [Upstream Helm chart values](https://github.com/maximhq/bifrost/blob/main/helm-charts/bifrost/values.yaml)
- [Source](https://github.com/maximhq/bifrost)
