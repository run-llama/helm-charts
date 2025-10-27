{{/*
Temporal Worker ConfigMap Template
Generates a ConfigMap for a temporal worker.

Usage:
{{- include "temporalWorker.configmap" (dict "worker" .Values.temporalParse.parseDelegate "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- root: The root context (.)
*/}}
{{- define "temporalWorker.configmap" -}}
{{- $worker := .worker -}}
{{- $root := .root -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}-config
  labels:
    {{- include "llamacloud.labels" $root | nindent 4 }}
  annotations:
    {{- include "llamacloud.annotations" $root | nindent 4 }}
data:
  IS_DEPLOYED: "true"
  IS_TEMPORAL_WORKER: "true"
  WORKER_HOST: "0.0.0.0"
  WORKER_PORT: "8765"
  TEMPORAL_HOST: {{ include "temporal.host" $root | quote }}
  TEMPORAL_PORT: {{ include "temporal.port" $root | quote }}
  TEMPORAL_NAMESPACE: "default"
  TEMPORAL_WORKER_REGISTRY_PROFILE: {{ $worker.config.temporalWorkerRegistryProfile | default "consolidated" | quote }}
  JOB_SERVICE_URL: {{ printf "http://%s-%s:%d" (include "llamacloud.fullname" $root) $root.Values.jobsService.name ($root.Values.jobsService.service.port | int) | quote }}
  TRACKING_SERVICE_URL: {{ printf "http://%s-%s:%d" (include "llamacloud.fullname" $root) $root.Values.usage.name ($root.Values.usage.service.port | int) | quote }}
  LOG_LEVEL: {{ $worker.config.logLevel | default "info" }}
  INCLUDE_HEALTH_CHECK_ENDPOINT_FILTER: "true"
  HEALTH_CHECK_ENDPOINT: "/healthcheck"
  S3_DOCUMENT_BUCKET_NAME: {{ $root.Values.global.config.parsedDocumentsCloudBucketName | default "llama-platform-parsed-documents" }}
  S3_ETL_BUCKET_NAME: {{ $root.Values.global.config.parsedEtlCloudBucketName | default "llama-platform-etl" }}
  S3_EXTERNAL_COMPONENTS_BUCKET_NAME: {{ $root.Values.global.config.parsedExternalComponentsCloudBucketName | default "llama-platform-external-components" }}
  S3_FILE_PARSING_BUCKET_NAME: {{ $root.Values.global.config.parsedFileParsingCloudBucketName | default "llama-platform-file-parsing" }}
  S3_RAW_FILE_BUCKET_NAME: {{ $root.Values.global.config.parsedRawFileCloudBucketName | default "llama-platform-raw-files" }}
  S3_LLAMA_CLOUD_PARSE_OUTPUT_BUCKET_NAME: {{ $root.Values.global.config.parsedLlamaCloudParseOutputCloudBucketName | default "llama-cloud-parse-output" }}
  S3_FILE_SCREENSHOT_BUCKET_NAME: {{ $root.Values.global.config.parsedFileScreenshotCloudBucketName | default "llama-platform-file-screenshots" }}
  S3_LLAMA_EXTRACT_OUTPUT_BUCKET_NAME: {{ $root.Values.global.config.llamaExtractOutputCloudBucketName | default "llama-platform-extract-output" }}
  {{- if $root.Values.llms.googleVertexAi.enabled }}
  GOOGLE_VERTEX_AI_ENABLED: {{ $root.Values.llms.googleVertexAi.enabled | quote }}
  GOOGLE_VERTEX_AI_PROJECT_ID: {{ $root.Values.llms.googleVertexAi.projectId | quote }}
  GOOGLE_VERTEX_AI_LOCATION: {{ $root.Values.llms.googleVertexAi.location | quote }}
  {{- end }}
  {{- include "common.postgresql.configMapData" $root | nindent 2 }}
{{- end -}}
