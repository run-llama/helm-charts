{{/*
Expand the name of the chart.
*/}}
{{- define "llamacloud.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "llamacloud.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "llamacloud.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "llamacloud.labels" -}}
helm.sh/chart: {{ include "llamacloud.chart" . }}
{{ include "llamacloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "llamacloud.annotations" -}}
{{- if .Values.commonAnnotations }}
{{ toYaml .Values.commonAnnotations }}
{{- end -}}
helm.sh/chart: {{ include "llamacloud.chart" . }}
{{ include "llamacloud.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "llamacloud.selectorLabels" -}}
app.kubernetes.io/name: {{ include "llamacloud.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service Accounts Names
*/}}

{{- define "frontend.serviceAccountName" -}}
{{- if .Values.frontend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.frontend.name) .Values.frontend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.frontend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "backend.serviceAccountName" -}}
{{- if .Values.backend.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.backend.name) .Values.backend.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.backend.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "jobsService.serviceAccountName" -}}
{{- if .Values.jobsService.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.jobsService.name) .Values.jobsService.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.jobsService.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "jobsWorker.serviceAccountName" -}}
{{- if .Values.jobsWorker.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.jobsWorker.name) .Values.jobsWorker.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.jobsWorker.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "llamaParse.serviceAccountName" -}}
{{- if .Values.llamaParse.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.llamaParse.name) .Values.llamaParse.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.llamaParse.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "llamaParseOcr.serviceAccountName" -}}
{{- if .Values.llamaParseOcr.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.llamaParseOcr.name) .Values.llamaParseOcr.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.llamaParseOcr.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "llamaParseLayoutDetectionApi.serviceAccountName" -}}
{{- if .Values.llamaParseLayoutDetectionApi.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.llamaParseLayoutDetectionApi.name) .Values.llamaParseLayoutDetectionApi.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.llamaParseLayoutDetectionApi.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "usage.serviceAccountName" -}}
{{- if .Values.usage.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.usage.name) .Values.usage.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.usage.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "s3proxy.serviceAccountName" -}}
{{- if .Values.s3proxy.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.s3proxy.name) .Values.s3proxy.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.s3proxy.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "temporalParse.llamaParse.serviceAccountName" -}}
{{- if .Values.temporalParse.llamaParse.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.temporalParse.llamaParse.name) .Values.temporalParse.llamaParse.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.temporalParse.llamaParse.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "temporalJobsService.api.serviceAccountName" -}}
{{- if .Values.temporalJobsService.api.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.temporalJobsService.api.name) .Values.temporalJobsService.api.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.temporalJobsService.api.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "temporalWorkers.pythonWorker.serviceAccountName" -}}
{{- if .Values.temporalWorkers.pythonWorker.serviceAccount.create -}}
    {{ default (printf "%s-%s" (include "llamacloud.fullname" .) .Values.temporalWorkers.pythonWorker.name) .Values.temporalWorkers.pythonWorker.serviceAccount.name | trunc 63 | trimSuffix "-" }}
{{- else -}}
    {{ default "default" .Values.temporalWorkers.pythonWorker.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{- define "common.postgresql.envVars" -}}
{{- if .Values.postgresql.enabled -}}
- name: DATABASE_HOST
  value: {{ printf "%s-%s" .Release.Name "postgresql" | quote}}
- name: DATABASE_PORT
  value: "5432"
- name: DATABASE_NAME
  value: {{ .Values.postgresql.auth.database | quote }}
- name: DATABASE_USER
  value: {{ .Values.postgresql.auth.username | quote }}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name "postgresql" }}
      key: password
{{- end -}}
{{- if and (.Values.global.config.postgresql.external.enabled) (not .Values.global.config.postgresql.external.existingSecretName) -}}
- name: DATABASE_HOST
  value: {{ .Values.global.config.postgresql.external.host | quote }}
- name: DATABASE_PORT
  value: {{ .Values.global.config.postgresql.external.port | quote }}
- name: DATABASE_NAME
  value: {{ .Values.global.config.postgresql.external.database | quote }}
- name: DATABASE_USER
  value: {{ .Values.global.config.postgresql.external.username | quote }}
- name: DATABASE_PASSWORD
  value: {{ .Values.global.config.postgresql.external.password | quote }}
{{- end -}}
{{- end -}}

{{- define "common.postgresql.configMapData" -}}
{{- if .Values.postgresql.enabled -}}
DATABASE_HOST: {{ printf "%s-%s" .Release.Name "postgresql" | quote }}
DATABASE_PORT: "5432"
DATABASE_NAME: {{ .Values.postgresql.auth.database | quote }}
DATABASE_USER: {{ .Values.postgresql.auth.username | quote }}
{{- end -}}
{{- if and (.Values.global.config.postgresql.external.enabled) (not .Values.global.config.postgresql.external.existingSecretName) -}}
DATABASE_HOST: {{ .Values.global.config.postgresql.external.host | quote }}
DATABASE_PORT: {{ .Values.global.config.postgresql.external.port | quote }}
DATABASE_NAME: {{ .Values.global.config.postgresql.external.database | quote }}
DATABASE_USER: {{ .Values.global.config.postgresql.external.username | quote }}
{{- end -}}
{{- end -}}

{{- define "common.postgresql.secretData" -}}
{{- if and (.Values.global.config.postgresql.external.enabled) (not .Values.global.config.postgresql.external.existingSecretName) -}}
DATABASE_PASSWORD: {{ .Values.global.config.postgresql.external.password | b64enc | quote }}
{{- end -}}
{{- end -}}

{{- define "common.postgresql.secretEnvVars" -}}
{{- if .Values.postgresql.enabled -}}
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name "postgresql" }}
      key: password
{{- end -}}
{{- end -}}

{{- define "common.mongodb.envVars" -}}
{{- if .Values.mongodb.enabled -}}
- name: MONGODB_HOST
  value: {{ printf "%s-%s" .Release.Name (default "mongodb" .Values.mongodb.nameOverride) | quote }}
- name: MONGODB_PORT
  value: {{ .Values.mongodb.service.port | default "27017" | quote }}
- name: MONGODB_USER
  value: {{ .Values.mongodb.auth.rootUser | quote }}
- name: MONGODB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name (default "mongodb" .Values.mongodb.nameOverride) | quote }}
      key: mongodb-root-password
{{- end -}}
{{- if and (.Values.global.config.mongodb.external.enabled) (not .Values.global.config.mongodb.external.existingSecretName) -}}
- name: MONGODB_URL_SCHEME
  value: {{ .Values.global.config.mongodb.external.scheme | quote }}
- name: MONGODB_HOST
  value: {{ .Values.global.config.mongodb.external.host | quote }}
- name: MONGODB_PORT
  value: {{ .Values.global.config.mongodb.external.port | quote }}
- name: MONGODB_USER
  value: {{ .Values.global.config.mongodb.external.username | quote }}
- name: MONGODB_PASSWORD
  value: {{ .Values.global.config.mongodb.external.password | quote }}
{{- end -}}
{{- end -}}

{{- define "common.rabbitmq.envVars" -}}
{{- if .Values.rabbitmq.enabled -}}
- name: JOB_QUEUE_ENDPOINT
  value: {{ printf "amqp://%s-%s:5672" .Release.Name (default "rabbitmq" .Values.rabbitmq.nameOverride) | quote }}
- name: JOB_QUEUE_USERNAME
  value: {{ .Values.rabbitmq.auth.username | default "user" | quote }}
- name: JOB_QUEUE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-%s" .Release.Name (default "rabbitmq" .Values.rabbitmq.nameOverride) | quote }}
      key: rabbitmq-password
{{- end -}}
{{- if and (.Values.global.config.rabbitmq.external.enabled) (not .Values.global.config.rabbitmq.external.existingSecretName) -}}
{{- if .Values.global.config.rabbitmq.external.connectionString -}}
- name: JOB_QUEUE_CONNECTION_STRING
  value: {{ .Values.global.config.rabbitmq.external.connectionString | quote }}
{{- else -}}
- name: JOB_QUEUE_ENDPOINT
  value: {{ printf "%s://%s:%s" .Values.global.config.rabbitmq.external.scheme .Values.global.config.rabbitmq.external.host .Values.global.config.rabbitmq.external.port | quote }}
- name: JOB_QUEUE_USERNAME
  value: {{ .Values.global.config.rabbitmq.external.username | quote }}
- name: JOB_QUEUE_PASSWORD
  value: {{ .Values.global.config.rabbitmq.external.password | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "common.redis.envVars" -}}
{{- if .Values.redis.enabled -}}
- name: REDIS_HOST
  value: {{ printf "%s-%s-master" .Release.Name (default "redis" .Values.redis.nameOverride) | quote }}
- name: REDIS_PORT
  value: {{ .Values.redis.master.service.ports.redis | default "6379" | quote }}
{{- end -}}
{{- if and (.Values.global.config.redis.external.enabled) (not .Values.global.config.redis.external.existingSecretName) -}}
- name: REDIS_HOST
  value: {{ .Values.global.config.redis.external.host | quote }}
- name: REDIS_PORT
  value: {{ .Values.global.config.redis.external.port | quote }}
- name: REDIS_DB
  value: {{ .Values.global.config.redis.external.db | default "0" | quote }}
{{- if .Values.global.config.redis.external.scheme }}
- name: REDIS_SCHEME
  value: {{ .Values.global.config.redis.external.scheme | quote }}
{{- end }}
{{- if .Values.global.config.redis.external.username }}
- name: REDIS_USERNAME
  value: {{ .Values.global.config.redis.external.username | quote }}
{{- end }}
{{- if .Values.global.config.redis.external.password }}
- name: REDIS_PASSWORD
  value: {{ .Values.global.config.redis.external.password | quote }}
{{- end }}
{{- end -}}
{{- end -}}

{{- define "common.llmModels.envVars" -}}
{{- if .Values.llms.enabled -}}
{{- if and .Values.llms.openAiApiKey (not .Values.llms.existingOpenAiApiKeySecretName) -}}
OPENAI_API_KEY: {{ .Values.llms.openAiApiKey | b64enc | quote }}
LC_OPENAI_API_KEY: {{ .Values.llms.openAiApiKey | b64enc | quote }}
{{ end }}
{{- if and .Values.llms.anthropicApiKey (not .Values.llms.existingAnthropicApiKeySecretName) -}}
ANTHROPIC_API_KEY: {{ .Values.llms.anthropicApiKey | b64enc | quote }}
{{ end }}
{{- if and .Values.llms.geminiApiKey (not .Values.llms.existingGeminiApiKeySecretName) -}}
GOOGLE_GEMINI_API_KEY: {{ .Values.llms.geminiApiKey | b64enc | quote }}
{{- end }}
{{- if and .Values.llms.azureOpenAi.enabled (not .Values.llms.azureOpenAi.existingSecretName) -}}
  {{- range $idx, $deployment := .Values.llms.azureOpenAi.deployments -}}
    {{- if not (and $deployment.model $deployment.apiKey $deployment.baseUrl $deployment.apiVersion) -}}
      {{- fail (printf "Azure OpenAI deployment %s at index %d is missing required fields: model, apiKey, baseUrl, or apiVersion" $deployment.model $idx) -}}
    {{- end -}}
{{ $MODEL_NAME_PREFIX := printf "AZURE_OPENAI_%s" ($deployment.model | replace "." "_" | replace "-" "_" | upper) | upper }}
{{ $MODEL_NAME_PREFIX }}_API_KEY: {{ $deployment.apiKey | b64enc | quote }}
{{ $MODEL_NAME_PREFIX }}_BASE_URL: {{ $deployment.baseUrl | b64enc | quote }}
{{ $MODEL_NAME_PREFIX }}_DEPLOYMENT_NAME: {{ $deployment.deploymentName | default $deployment.model | b64enc | quote }}
{{ $MODEL_NAME_PREFIX }}_API_VERSION: {{ $deployment.apiVersion | b64enc | quote }}
  {{- end }}
{{ end }}
{{- if and .Values.llms.awsBedrock.enabled (not .Values.llms.awsBedrock.existingSecretName) -}}
AWS_BEDROCK_ENABLED: {{ "true" | b64enc | quote }}
AWS_BEDROCK_REGION: {{ .Values.llms.awsBedrock.region | b64enc | quote }}
AWS_BEDROCK_ACCESS_KEY_ID: {{ .Values.llms.awsBedrock.accessKeyId | b64enc | quote }}
AWS_BEDROCK_SECRET_ACCESS_KEY: {{ .Values.llms.awsBedrock.secretAccessKey | b64enc | quote }}
AWS_BEDROCK_SONNET_3_5_MODEL_VERSION_NAME: {{ .Values.llms.awsBedrock.sonnet3_5ModelVersionName | b64enc | quote }}
AWS_BEDROCK_SONNET_3_7_MODEL_VERSION_NAME: {{ .Values.llms.awsBedrock.sonnet3_7ModelVersionName | b64enc | quote }}
AWS_BEDROCK_SONNET_4_0_MODEL_VERSION_NAME: {{ .Values.llms.awsBedrock.sonnet4_0ModelVersionName | b64enc | quote }}
AWS_BEDROCK_HAIKU_3_5_MODEL_VERSION_NAME: {{ .Values.llms.awsBedrock.haiku3_5ModelVersionName | b64enc | quote }}
AWS_BEDROCK_HAIKU_4_5_MODEL_VERSION_NAME: {{ .Values.llms.awsBedrock.haiku4_5ModelVersionName | b64enc | quote }}
{{ end }}
{{- if .Values.llamaParse.config.preferedPremiumModel -}}
PREFERED_PREMIUM_MODE_MODEL:  {{ .Values.llamaParse.config.preferedPremiumModel | b64enc | quote }}
{{end}}
{{- if and .Values.llms.googleVertexAi.enabled (not .Values.llms.googleVertexAi.existingSecretName) -}}
GOOGLE_VERTEX_AI_ENABLED: {{ "true" | b64enc | quote }}
GOOGLE_VERTEX_AI_PROJECT_ID: {{ .Values.llms.googleVertexAi.projectId | b64enc | quote }}
GOOGLE_VERTEX_AI_LOCATION: {{ .Values.llms.googleVertexAi.location | b64enc | quote }}
GOOGLE_VERTEX_AI_CREDENTIALS_JSON: {{ .Values.llms.googleVertexAi.credentialsJson | b64enc | quote }}
{{ end }}
{{- else -}}
{{- if and .Values.llamaParse.config.openAiApiKey (not .Values.llamaParse.existingOpenAiApiKeySecretName) -}}
OPENAI_API_KEY: {{ .Values.llamaParse.config.openAiApiKey | b64enc | quote }}
LC_OPENAI_API_KEY: {{ .Values.llamaParse.config.openAiApiKey | b64enc | quote }}
{{- end -}}
{{- if and .Values.llamaParse.config.azureOpenAi.enabled (not .Values.llamaParse.config.azureOpenAi.existingSecret) -}}
AZURE_OPENAI_API_KEY: {{ .Values.llamaParse.config.azureOpenAi.key | b64enc | quote }}
AZURE_OPENAI_BASE_URL: {{ .Values.llamaParse.config.azureOpenAi.endpoint | b64enc | quote }}
AZURE_OPENAI_GPT_4O_DEPLOYMENT_NAME: {{ .Values.llamaParse.config.azureOpenAi.deploymentName | b64enc | quote }}
AZURE_OPENAI_API_VERSION: {{ .Values.llamaParse.config.azureOpenAi.apiVersion | b64enc | quote }}
{{- end }}
{{- if and .Values.llamaParse.config.anthropicApiKey (not .Values.llamaParse.config.existingAnthropicApiKeySecret) }}
ANTHROPIC_API_KEY: {{ .Values.llamaParse.config.anthropicApiKey | b64enc | quote }}
{{- end }}
{{- if and .Values.llamaParse.config.geminiApiKey (not .Values.llamaParse.config.existingGeminiApiKeySecret) }}
GOOGLE_GEMINI_API_KEY: {{ .Values.llamaParse.config.geminiApiKey | b64enc | quote }}
{{- end }}
{{ if and .Values.llamaParse.config.awsBedrock.enabled (not .Values.llamaParse.config.awsBedrock.existingSecret) -}}
AWS_BEDROCK_ENABLED: {{ "true" | b64enc | quote }}
{{- end -}}
{{- if .Values.llamaParse.config.awsBedrock.region -}}
AWS_BEDROCK_REGION: {{ .Values.llamaParse.config.awsBedrock.region | b64enc | quote }}
{{- end -}}
{{- if .Values.llamaParse.config.awsBedrock.accessKeyId -}}
AWS_BEDROCK_ACCESS_KEY_ID: {{ .Values.llamaParse.config.awsBedrock.accessKeyId | b64enc | quote }}
{{- end -}}
{{- if .Values.llamaParse.config.awsBedrock.secretAccessKey -}}
AWS_BEDROCK_SECRET_ACCESS_KEY: {{ .Values.llamaParse.config.awsBedrock.secretAccessKey | b64enc | quote }}
{{- end -}}
{{- if and .Values.llamaParse.config.googleVertexAi.enabled (not .Values.llamaParse.config.googleVertexAi.existingSecret) -}}
GOOGLE_VERTEX_AI_ENABLED: {{ "true" | b64enc | quote }}
GOOGLE_VERTEX_AI_PROJECT_ID: {{ .Values.llamaParse.config.googleVertexAi.projectId | b64enc | quote }}
GOOGLE_VERTEX_AI_LOCATION: {{ .Values.llamaParse.config.googleVertexAi.location | b64enc | quote }}
GOOGLE_VERTEX_AI_CREDENTIALS_JSON: {{ .Values.llamaParse.config.googleVertexAi.credentialsJson | b64enc | quote }}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "common.llmModels.secretRefs" -}}
{{- if .Values.llms.enabled -}}
{{- if .Values.llms.existingOpenAiApiKeySecretName }}
- secretRef:
    name: {{ .Values.llms.existingOpenAiApiKeySecretName }}
{{- end }}
{{- if and .Values.llms.azureOpenAi.enabled .Values.llms.azureOpenAi.existingSecretName }}
- secretRef:
    name: {{ .Values.llms.azureOpenAi.existingSecretName }}
{{- end }}
{{- if .Values.llms.existingAnthropicApiKeySecretName }}
- secretRef:
    name: {{ .Values.llms.existingAnthropicApiKeySecretName }}
{{- end }}
{{- if .Values.llms.existingGeminiApiKeySecretName }}
- secretRef:
    name: {{ .Values.llms.existingGeminiApiKeySecretName }}
{{- end }}
{{- if and .Values.llms.awsBedrock.enabled .Values.llms.awsBedrock.existingSecretName }}
- secretRef:
    name: {{ .Values.llms.awsBedrock.existingSecretName }}
{{- end }}
{{- if and .Values.llms.googleVertexAi.enabled .Values.llms.googleVertexAi.existingSecretName }}
- secretRef:
    name: {{ .Values.llms.googleVertexAi.existingSecretName }}
{{- end }}
{{- else -}}
{{- if .Values.llamaParse.config.existingOpenAiApiKeySecretName }}
- secretRef:
    name: {{ .Values.llamaParse.config.existingOpenAiApiKeySecretName }}
{{- end }}
{{- if and .Values.llamaParse.config.azureOpenAi.enabled .Values.llamaParse.config.azureOpenAi.existingSecret }}
- secretRef:
    name: {{ .Values.llamaParse.config.azureOpenAi.existingSecret }}
{{- end }}
{{- if .Values.llamaParse.config.existingAnthropicApiKeySecret }}
- secretRef:
    name: {{ .Values.llamaParse.config.existingAnthropicApiKeySecret }}
{{- end }}
{{- if .Values.llamaParse.config.existingGeminiApiKeySecret }}
- secretRef:
    name: {{ .Values.llamaParse.config.existingGeminiApiKeySecret }}
{{- end }}
{{- if and .Values.llamaParse.config.awsBedrock.enabled .Values.llamaParse.config.awsBedrock.existingSecret }}
- secretRef:
    name: {{ .Values.llamaParse.config.awsBedrock.existingSecret }}
{{- end }}
{{- if and .Values.llamaParse.config.googleVertexAi.enabled .Values.llamaParse.config.googleVertexAi.existingSecret }}
- secretRef:
    name: {{ .Values.llamaParse.config.googleVertexAi.existingSecret }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Temporal Enabled
Returns true if temporal is available (either internal or external)
*/}}
{{- define "temporal.enabled" -}}
{{- if or .Values.temporal.enabled .Values.global.config.temporal.external.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Temporal Host
Returns the host for the temporal server based on whether external temporal is enabled
*/}}
{{- define "temporal.host" -}}
{{- if .Values.global.config.temporal.external.enabled -}}
{{- .Values.global.config.temporal.external.host -}}
{{- else -}}
{{- printf "%s-temporal-frontend.%s.svc.cluster.local" .Release.Name .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{/*
Temporal Port
Returns the port for the temporal server
*/}}
{{- define "temporal.port" -}}
{{- if .Values.global.config.temporal.external.enabled -}}
{{- .Values.global.config.temporal.external.port | default 7233 -}}
{{- else -}}
{{- 7233 -}}
{{- end -}}
{{- end -}}

