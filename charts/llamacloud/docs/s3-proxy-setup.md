# Deploying LlamaCloud with S3Proxy

The LlamaCloud Helm Chart bundles [s3proxy](https://github.com/gaul/s3proxy) as an optional sidecar so LlamaCloud services can talk to non-AWS object stores (such as Azure Blob Storage or Google Cloud Storage) over an S3-compatible API. It runs whenever `config.storageBuckets.s3proxy.enabled` is `true`; `config.storageBuckets.provider` does not turn it on or off. Enable it for any non-AWS backend (Azure Blob, GCS, MinIO and other S3-compatible stores) and for AWS with access keys. Leave it off only on AWS with IRSA, where the platform talks to S3 directly.

## Enabling and configuring s3proxy

s3proxy is configured under `config.storageBuckets.s3proxy` in your `values.yaml`. Set `enabled: true` and supply the backend-specific settings under `config` as environment variables. The following example proxies S3 requests to Azure Blob Storage:

```yaml
config:
  storageBuckets:
    s3proxy:
      enabled: true

      config:
        JCLOUDS_PROVIDER: "azureblob"
        JCLOUDS_AZUREBLOB_AUTH: "azureKey"
        JCLOUDS_REGION: "<azure-region>"
        JCLOUDS_IDENTITY: "<azure-storage-account-name>"
        JCLOUDS_CREDENTIAL: "<azure-storage-account-key>"
        JCLOUDS_ENDPOINT: "<azure-storage-account-endpoint>"
```

Everything you place under `config.storageBuckets.s3proxy.config` is rendered into the chart-managed `s3proxy-secret` Secret and injected into the sidecar. Use it for backend provider/credential settings like the `JCLOUDS_*` values above.

### Endpoint settings are managed for you

You do **not** need to set `S3PROXY_ENDPOINT` or `S3PROXY_AUTHORIZATION` yourself. The chart generates them automatically from `config.storageBuckets.s3proxy.containerPort` (default `8080`), so the proxy always listens on `http://0.0.0.0:<containerPort>` with authorization disabled inside the pod. Setting these keys manually is unnecessary and can conflict with the generated values.

### Other s3proxy settings

Additional deployment knobs live alongside `config` under `config.storageBuckets.s3proxy`, including `image`, `imagePullPolicy`, `containerPort`, `logLevel`, `securityContext`, and `resources`. See the `@param` annotations in `values.yaml` for the full list and defaults.

## Azure Blob Storage with Workload Identity

Instead of a storage account key, S3Proxy can authenticate to Azure Blob Storage with [Microsoft Entra Workload ID](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview). Each S3Proxy sidecar exchanges its pod's Kubernetes service account token for an Entra token for a user-assigned managed identity. No account key is stored in the cluster, and the storage account can have shared key access disabled.

S3Proxy's `azureblob-sdk` provider does this. When no account key is set, it uses the Azure SDK's `DefaultAzureCredential`, which reads the token the AKS workload identity webhook mounts into the pod. The jclouds `azureblob` provider can't use workload identity.

### What the chart does

With `config.storageBuckets.s3proxy.azureWorkloadIdentity.enabled: true`, the chart changes only the components that run the S3Proxy sidecar:

- Their pod templates get the `azure.workload.identity/use: "true"` label, which tells the webhook to mutate the pod. Deployment selectors don't change, so upgrading an existing release works.
- Their service accounts get `azure.workload.identity/client-id`. A value you set in that component's `serviceAccountAnnotations` takes precedence.
- Their pods get `azure.workload.identity/skip-containers` naming the main container, so only the S3Proxy sidecar receives the Azure token.
- The S3Proxy ConfigMap sets `JCLOUDS_CREDENTIAL` to empty. The S3Proxy image otherwise defaults it to a placeholder that S3Proxy would send as an account key.

Rendering fails if `clientId` or `JCLOUDS_ENDPOINT` is empty, `JCLOUDS_PROVIDER` isn't `azureblob-sdk`, or `JCLOUDS_CREDENTIAL` is set.

### Azure setup

1. Enable the OIDC issuer and workload identity on the AKS cluster, and read the issuer URL:

   ```bash
   az aks update -g <resource-group> -n <cluster> --enable-oidc-issuer --enable-workload-identity
   az aks show -g <resource-group> -n <cluster> --query oidcIssuerProfile.issuerUrl -o tsv
   ```

2. Create a user-assigned managed identity and grant it **Storage Blob Data Contributor** on the storage account:

   ```bash
   az identity create -g <resource-group> -n llamacloud-storage
   az role assignment create --role "Storage Blob Data Contributor" \
     --assignee-object-id "$(az identity show -g <resource-group> -n llamacloud-storage --query principalId -o tsv)" \
     --assignee-principal-type ServicePrincipal \
     --scope "$(az storage account show -g <resource-group> -n <storage-account> --query id -o tsv)"
   ```

   The role includes the user delegation key permission S3Proxy needs for server-side copies.

3. Add a federated credential to the identity for each service account whose pods run S3Proxy. With default component names these are `llamacloud`, `llamacloud-operator`, `llamacloud-temporal-parse`, one per entry under `temporalWorkloads.workers` (default `temporal-jobs-worker`) and, when `config.parse.quarantineWorkerEnabled` is true, `llamacloud-temporal-parse-quarantine`:

   ```bash
   for sa in llamacloud llamacloud-operator llamacloud-temporal-parse temporal-jobs-worker; do
     az identity federated-credential create -g <resource-group> --identity-name llamacloud-storage \
       --name "llamacloud-${sa}" --issuer "<oidc-issuer-url>" \
       --subject "system:serviceaccount:<release-namespace>:${sa}" --audiences api://AzureADTokenExchange
   done
   ```

   To list the service accounts in a rendered release, run `helm template` and look for the `azure.workload.identity/client-id` annotation.

### Chart values

```yaml
config:
  storageBuckets:
    provider: "azure"
    s3proxy:
      enabled: true
      azureWorkloadIdentity:
        enabled: true
        clientId: "<managed-identity-client-id>"   # az identity show ... --query clientId
      config:
        JCLOUDS_PROVIDER: "azureblob-sdk"
        JCLOUDS_IDENTITY: "<azure-storage-account-name>"
        JCLOUDS_ENDPOINT: "https://<azure-storage-account-name>.blob.core.windows.net"
```

Leave `JCLOUDS_CREDENTIAL` and `JCLOUDS_AZUREBLOB_AUTH` out of `config`.

## Documentation

For more information, please refer to the following:

- [S3 Proxy Config Examples](https://github.com/gaul/s3proxy/wiki/Storage-backend-examples)
- [Dockerfile with Env Vars](https://github.com/gaul/s3proxy/blob/master/Dockerfile)
