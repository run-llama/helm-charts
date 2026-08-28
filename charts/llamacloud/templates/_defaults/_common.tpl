{{/*
Labels

Parameters:
- name: The name of the component
- root: $
*/}}
{{ define "llamacloud.labels" }}
{{- if .root.Values.commonLabels }}
{{ .root.Values.commonLabels | toYaml }}
{{- end }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- if .name }}
app.kubernetes.io/name: {{ .name | quote }}
{{- end }}
{{- end }}

{{/*
Annotations

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.annotations" }}
{{- /* Merge commonAnnotations + per-component annotations with component taking
       precedence on collision. Emitting both in sequence without dedup (prior
       behavior) produced duplicate YAML mapping keys and broke downstream parsers. */}}
{{- $merged := dict }}
{{- range $key, $value := .root.Values.commonAnnotations }}
{{-   $merged = set $merged $key $value }}
{{- end }}
{{- if .component }}
{{-   range $key, $value := .component.annotations }}
{{-     $merged = set $merged $key $value }}
{{-   end }}
{{- end }}
{{- range $key, $value := $merged }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Pod Annotations

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.podAnnotations" }}
{{- /* See llamacloud.annotations above for dedup rationale. */}}
{{- $merged := dict }}
{{- range $key, $value := .root.Values.commonAnnotations }}
{{-   $merged = set $merged $key $value }}
{{- end }}
{{- if .component }}
{{-   range $key, $value := .component.podAnnotations }}
{{-     $merged = set $merged $key $value }}
{{-   end }}
{{- end }}
{{- range $key, $value := $merged }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Security Context

Parameters:
- component: The component configuration in values.yaml
*/}}
{{ define "llamacloud.podSecurityContext" }}
{{- if not .component.podSecurityContext }}
runAsUser: 1000
runAsGroup: 1000
fsGroup: 1000
seccompProfile:
  type: RuntimeDefault
{{- else }}
{{ toYaml .component.podSecurityContext }}
{{- end }}
{{- end }}

{{/*
Security Context

Parameters:
- component: The component configuration in values.yaml
*/}}
{{ define "llamacloud.securityContext" }}
{{- if not .component.securityContext }}
allowPrivilegeEscalation: false
capabilities:
  drop:
  - all
privileged: false
readOnlyRootFilesystem: true
runAsGroup: 1000
runAsNonRoot: true
runAsUser: 1000
{{- else }}
{{ toYaml .component.securityContext }}
{{- end }}
{{- end }}

{{/*
Activated Components
*/}}
{{- define "llamacloud.components" }}
{{- $activated := dict }}
{{- $activated = set $activated "backend" (include "llamacloud.component.backend" . | fromYaml) }}
{{- $activated = set $activated "jobsService" (include "llamacloud.component.jobsService" . | fromYaml) }}
{{- /* jobs-worker is the AMQP consumer; without RabbitMQ it has nothing to consume */}}
{{- if (.Values.rabbitmq).enabled }}
{{- $activated = set $activated "jobsWorker" (include "llamacloud.component.jobsWorker" . | fromYaml) }}
{{- end }}
{{- $activated = set $activated "llamaParse" (include "llamacloud.component.llamaParse" . | fromYaml) }}
{{- $activated = set $activated "usage" (include "llamacloud.component.usage" . | fromYaml) }}
{{- if (($.Values.config).frontend).enabled }}
{{- $activated = set $activated "frontend" (include "llamacloud.component.frontend" . | fromYaml) }}
{{- end }}
{{- if (($.Values.config).parseOcr).enabled }}
{{- $activated = set $activated "llamaParseOcr" (include "llamacloud.component.llamaParseOcr" . | fromYaml) }}
{{- end }}
{{- if (($.Values.config).parseLayoutDetectionV3).enabled }}
{{- $activated = set $activated "llamaParseLayoutDetectionApiV3" (include "llamacloud.component.llamaParseLayoutDetectionApiV3" . | fromYaml) }}
{{- else if (($.Values.config).parseLayoutDetection).enabled }}
{{- $activated = set $activated "llamaParseLayoutDetectionApi" (include "llamacloud.component.llamaParseLayoutDetectionApi" . | fromYaml) }}
{{- end }}
{{- /* Temporal workloads - skip when temporal is disabled */}}
{{- if not $.Values.temporal.disabled }}
{{- $activated = set $activated "temporalLlamaParse" (include "llamacloud.component.temporal.llamaParse" . | fromYaml) }}
{{- /* Quarantine parse worker: opt-in, so a BYOC/single-tenant install that
       does not set the flag renders exactly what it rendered before this key
       existed. Ungated activation would put an idle quarantine pod in every
       install, for a queue nothing dispatches to there. */}}
{{- if (($.Values.config).parse).quarantineWorkerEnabled }}
{{- $activated = set $activated "temporalLlamaParseQuarantine" (include "llamacloud.component.temporal.llamaParseQuarantine" . | fromYaml) }}
{{- end }}
{{- range $workerName, $workerConfig := .Values.temporalWorkloads.workers }}
{{- $activated = set $activated $workerName (include "llamacloud.component.temporal.worker" (dict "name" $workerName "component" $workerConfig "appVersion" $.Chart.AppVersion) | fromYaml) }}
{{- end }}
{{- end }}
{{- $activated | toYaml }}
{{- end }}

{{/*
Ingress Scheme
*/}}
{{- define "llamacloud.ingress.scheme" }}http{{ if .Values.ingress.tlsSecretName }}s{{ end }}{{- end }}

{{/*
Renders a complete tree, even values that contains template.
*/}}
{{- define "llamacloud.render" }}
  {{- if typeIs "string" .value }}
    {{- tpl .value .context }}
  {{ else }}
    {{- tpl (.value | toYaml) .context }}
  {{- end }}
{{- end }}

{{/*
Resolves the llama-agents control plane URL, or empty string when not configured.
Prefers deploy=true (in-cluster service) over controlPlaneUrl (external).
Usage: include "llamacloud.llamaAgents.url" .  (or .root when nested)
*/}}
{{- define "llamacloud.llamaAgents.url" -}}
{{- if .Values.llamaAgents.deploy -}}
http://llama-agents-service:80
{{- else if .Values.llamaAgents.controlPlaneUrl -}}
{{- .Values.llamaAgents.controlPlaneUrl -}}
{{- end -}}
{{- end }}

{{/*
Explicit llamaAgents.enabled override, else derived from a resolvable URL.
Emits "true" or "" so callers can use it as a plain truthiness test. Shared so the
override cannot be honored in one place and missed in another — it gates both
IS_AGENT_DEPLOYMENTS_ENABLED and the worker's control-plane access.
Usage: include "llamacloud.llamaAgents.enabled" .  (or .root when nested)
*/}}
{{- define "llamacloud.llamaAgents.enabled" -}}
{{- if kindIs "bool" .Values.llamaAgents.enabled -}}
{{- if .Values.llamaAgents.enabled }}true{{ end -}}
{{- else if ne (include "llamacloud.llamaAgents.url" .) "" -}}
true
{{- end -}}
{{- end }}
