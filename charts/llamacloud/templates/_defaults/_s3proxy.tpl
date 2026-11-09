{{/*
S3Proxy Sidecar Container Definition.
*/}}
{{ define "llamacloud.s3proxy.container" }}
{{- if ((($.Values.config).storageBuckets).s3proxy.enabled | default false) }}
- name: s3proxy
  {{- with ((($.Values.config).storageBuckets).s3proxy).securityContext }}
  securityContext: {{ toYaml . | nindent 4 }}
  {{- end }}
  image: "{{ ((($.Values.config).storageBuckets).s3proxy).image | default "docker.io/andrewgaul/s3proxy:sha-001d042" }}"
  imagePullPolicy: {{ ((($.Values.config).storageBuckets).s3proxy).imagePullPolicy | default "IfNotPresent" }}
  ports:
  - name: s3proxy
    containerPort: {{ print (int ((($.Values.config).storageBuckets).s3proxy.containerPort | default 80))}}
    protocol: TCP
  resources:
    requests:
      cpu: {{ ((((($.Values.config).storageBuckets).s3proxy).resources).requests).cpu | default "500m" }}
      memory: {{ ((((($.Values.config).storageBuckets).s3proxy).resources).requests).memory | default "512Mi" }}
    limits:
      cpu: {{ ((((($.Values.config).storageBuckets).s3proxy).resources).limits).cpu | default "1" }}
      memory: {{ ((((($.Values.config).storageBuckets).s3proxy).resources).limits).memory | default "1Gi" }}
  env:
  - name: LOG_LEVEL
    value: {{ ((($.Values.config).storageBuckets).s3proxy).logLevel | default ($.Values.config).logLevel | default "info" }}
  - name: S3PROXY_LOG_LEVEL
    value: {{ ((($.Values.config).storageBuckets).s3proxy).logLevel | default ($.Values.config).logLevel | default "info" }}
  envFrom:
  - configMapRef:
      name: s3proxy-config
  - secretRef:
      name: s3proxy-secret
  volumeMounts:
  - name: s3proxy-tmp
    mountPath: /tmp
    subPath: tmp-dir
{{- end }}
{{- end }}

{{/*
S3Proxy Azure Workload Identity.

Renders "true" when the S3Proxy sidecar runs and authenticates to Azure Blob Storage with
Microsoft Entra Workload ID, and nothing otherwise. With no account key, the `azureblob-sdk`
provider falls back to DefaultAzureCredential, which reads the federated token the AKS
workload identity webhook injects into labeled pods. Rendering fails on settings that would
send S3Proxy down the account-key path or at the wrong storage account.

Parameters:
- $ (root)
*/}}
{{- define "llamacloud.s3proxy.azureWorkloadIdentity" -}}
{{- $s3proxy := (($.Values.config).storageBuckets).s3proxy | default dict }}
{{- $workloadIdentity := $s3proxy.azureWorkloadIdentity | default dict }}
{{- if and $s3proxy.enabled $workloadIdentity.enabled }}
{{- $s3proxyConfig := $s3proxy.config | default dict }}
{{- if not $workloadIdentity.clientId }}
{{- fail "config.storageBuckets.s3proxy.azureWorkloadIdentity.clientId is required when azureWorkloadIdentity.enabled is true" }}
{{- end }}
{{- if ne ($s3proxyConfig.JCLOUDS_PROVIDER | default "") "azureblob-sdk" }}
{{- fail "config.storageBuckets.s3proxy.config.JCLOUDS_PROVIDER must be \"azureblob-sdk\" when azureWorkloadIdentity.enabled is true; it is the only S3Proxy Azure provider that can use workload identity" }}
{{- end }}
{{- if $s3proxyConfig.JCLOUDS_CREDENTIAL }}
{{- fail "config.storageBuckets.s3proxy.config.JCLOUDS_CREDENTIAL must be empty when azureWorkloadIdentity.enabled is true; S3Proxy uses an account key whenever one is set" }}
{{- end }}
{{- if not $s3proxyConfig.JCLOUDS_ENDPOINT }}
{{- fail "config.storageBuckets.s3proxy.config.JCLOUDS_ENDPOINT is required when azureWorkloadIdentity.enabled is true, e.g. https://<storage-account>.blob.core.windows.net" }}
{{- end }}
true
{{- end }}
{{- end }}

{{/*
S3Proxy Secret.
*/}}
{{ define "llamacloud.s3proxy.secret" }}
{{- range $key, $value := $.Values.config.storageBuckets.s3proxy.config }}
{{ $key }}: {{ $value | b64enc | quote }}
{{- end }}
{{- end }}

{{/*
S3Proxy ConfigMap Data.
*/}}
{{ define "llamacloud.s3proxy.configMap" }}
S3PROXY_AUTHORIZATION: "none"
S3PROXY_CORS_ALLOW_ORIGINS: "*"
S3PROXY_ENDPOINT: {{ printf "http://0.0.0.0:%d" (int ((($.Values.config).storageBuckets).s3proxy.containerPort | default 80)) | quote }}
S3PROXY_IGNORE_UNKNOWN_HEADERS: "true"
{{- if include "llamacloud.s3proxy.azureWorkloadIdentity" $ }}
{{- /* The S3Proxy image defaults JCLOUDS_CREDENTIAL to a placeholder, which
       S3Proxy would send as an account key. Empty selects DefaultAzureCredential. */}}
JCLOUDS_CREDENTIAL: ""
{{- end }}
{{- end }}