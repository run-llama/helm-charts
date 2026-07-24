# Deploying LlamaCloud with S3Proxy

The LlamaCloud Helm Chart bundles [s3proxy](https://github.com/gaul/s3proxy) as an optional sidecar so LlamaCloud services can talk to non-AWS object stores (such as Azure Blob Storage or Google Cloud Storage) over an S3-compatible API. It is only used when your storage provider is `gcp` or `azure` — it is ignored for `aws`.

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
        JCLOUD_REGION: "<azure-region>"
        JCLOUDS_IDENTITY: "<azure-storage-account-name>"
        JCLOUDS_CREDENTIAL: "<azure-storage-account-key>"
        JCLOUDS_ENDPOINT: "<azure-storage-account-endpoint>"
```

Everything you place under `config.storageBuckets.s3proxy.config` is rendered into the chart-managed `s3proxy-secret` Secret and injected into the sidecar. Use it for backend provider/credential settings like the `JCLOUDS_*` values above.

### Endpoint settings are managed for you

You do **not** need to set `S3PROXY_ENDPOINT` or `S3PROXY_AUTHORIZATION` yourself. The chart generates them automatically from `config.storageBuckets.s3proxy.containerPort` (default `8080`), so the proxy always listens on `http://0.0.0.0:<containerPort>` with authorization disabled inside the pod. Setting these keys manually is unnecessary and can conflict with the generated values.

### Other s3proxy settings

Additional deployment knobs live alongside `config` under `config.storageBuckets.s3proxy`, including `image`, `imagePullPolicy`, `containerPort`, `logLevel`, `securityContext`, and `resources`. See the `@param` annotations in `values.yaml` for the full list and defaults.

## Documentation

For more information, please refer to the following:

- [S3 Proxy Config Examples](https://github.com/gaul/s3proxy/wiki/Storage-backend-examples)
- [Dockerfile with Env Vars](https://github.com/gaul/s3proxy/blob/master/Dockerfile)
