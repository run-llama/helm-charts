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
{{- end }}
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

{{- define "common.postgresql.host" -}}
{{- printf "%s-%s" .Release.Name "postgresql" | quote }}
{{- end -}}

{{- define "common.mongodb.host" -}}
{{- printf "%s-%s" .Release.Name (default "mongodb" .Values.mongodb.nameOverride) | quote }}
{{- end -}}

{{- define  "common.mongodb.port" }}
{{ .Values.mongodb.service.port | default "27017" | quote }}
{{- end -}}

{{- define "common.redis.host" -}}
{{ printf "%s-%s-master" (include "llamacloud.fullname" .) (default "redis" .Values.redis.nameOverride) | quote }}
{{- end -}}

{{- define "common.dependencyInitContianer" -}}
command:
  - /bin/sh
  - -ce
  - |
    {{- if .Values.postgresql.enabled -}}
    # Wait for postgresql
    ./docker_scripts/wait-for-it.sh {{ include "common.postgresql.host" . }}:5432
    {{- end -}}
    {{- if .Values.redis.enabled -}}
    {{- end -}}
    # wait for redis
    until kubectl 
    {{- end -}}
{{- end -}}
