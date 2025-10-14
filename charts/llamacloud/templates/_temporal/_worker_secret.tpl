{{/*
Temporal Worker Secret Template
Generates a Secret for a temporal worker.

Usage:
{{- include "temporalWorker.secret" (dict "worker" .Values.temporalParse.parseDelegate "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- root: The root context (.)
*/}}
{{- define "temporalWorker.secret" -}}
{{- $worker := .worker -}}
{{- $root := .root -}}
{{- if not $worker.externalSecrets.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}-secret
  labels:
    {{- include "llamacloud.labels" $root | nindent 4 }}
  annotations:
    {{- include "llamacloud.annotations" $root | nindent 4 }}
type: Opaque
data:
  {{- include "common.postgresql.secretData" $root | nindent 2 }}
  {{- if and (eq $root.Values.global.cloudProvider "aws") $root.Values.global.config.awsAccessKeyId $root.Values.global.config.awsSecretAccessKey (not $root.Values.global.config.existingAwsSecretName) }}
  AWS_ACCESS_KEY_ID: {{ $root.Values.global.config.awsAccessKeyId | b64enc | quote }}
  AWS_SECRET_ACCESS_KEY: {{ $root.Values.global.config.awsSecretAccessKey | b64enc | quote }}
  {{- end }}
  {{- if and (not $root.Values.llms.enabled) $root.Values.backend.config.openAiApiKey (not $root.Values.backend.existingOpenAiApiKeySecretName) }}
  LC_OPENAI_API_KEY: {{ $root.Values.backend.config.openAiApiKey | b64enc | quote }}
  {{- end }}
  {{- if and (not $root.Values.llms.enabled) $root.Values.backend.config.azureOpenAi.enabled (not $root.Values.backend.config.azureOpenAi.existingSecret) }}
  AZURE_OPENAI_API_KEY: {{ $root.Values.backend.config.azureOpenAi.key | b64enc | quote }}
  AZURE_OPENAI_BASE_URL: {{ $root.Values.backend.config.azureOpenAi.endpoint | b64enc | quote }}
  AZURE_OPENAI_GPT_4O_DEPLOYMENT_NAME: {{ $root.Values.backend.config.azureOpenAi.deploymentName | b64enc | quote }}
  AZURE_OPENAI_API_VERSION: {{ $root.Values.backend.config.azureOpenAi.apiVersion | b64enc | quote }}
  {{- end }}
  {{- if $root.Values.s3proxy.enabled }}
  S3_ENDPOINT_URL: {{ printf "http://%s-%s:%d" (include "llamacloud.fullname" $root) $root.Values.s3proxy.name ($root.Values.s3proxy.service.port | int) | b64enc | quote }}
  {{- end }}
  {{- if $root.Values.backend.config.qdrant.enabled }}
  QDRANT_URL: {{ $root.Values.backend.config.qdrant.url | b64enc | quote }}
  QDRANT_API_KEY: {{ $root.Values.backend.config.qdrant.apiKey | b64enc | quote }}
  BYOC_HAS_MANAGED_QDRANT: {{ $root.Values.backend.config.qdrant.enabled | toString | lower | b64enc | quote }}
  {{- end }}
  {{- if $root.Values.llms.enabled }}
  {{- include "common.llmModels.envVars" $root | nindent 2 }}
  {{- else }}
  {{- if and $root.Values.llms.googleVertexAi.enabled (not $root.Values.llms.googleVertexAi.existingSecretName) }}
  GOOGLE_VERTEX_AI_CREDENTIALS_JSON: {{ $root.Values.llms.googleVertexAi.credentialsJson | b64enc | quote }}
  {{- end }}
  {{- end }}
{{- end }}
{{- end -}}
