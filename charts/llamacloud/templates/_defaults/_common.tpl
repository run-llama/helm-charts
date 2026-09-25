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
{{- /* MCP serves agent clients against this deployment's own LlamaCloud. Off by
       default: it is optional, and its image is not part of the base install. */}}
{{- if (($.Values.config).mcp).enabled }}
{{- $activated = set $activated "mcp" (include "llamacloud.component.mcp" . | fromYaml) }}
{{- end }}
{{- if (($.Values.config).parseOcr).enabled }}
{{- $activated = set $activated "llamaParseOcr" (include "llamacloud.component.llamaParseOcr" . | fromYaml) }}
{{- end }}
{{- if (($.Values.config).parseLayoutDetectionV3).enabled }}
{{- $activated = set $activated "llamaParseLayoutDetectionApiV3" (include "llamacloud.component.llamaParseLayoutDetectionApiV3" . | fromYaml) }}
{{- else if (($.Values.config).parseLayoutDetection).enabled }}
{{- $activated = set $activated "llamaParseLayoutDetectionApi" (include "llamacloud.component.llamaParseLayoutDetectionApi" . | fromYaml) }}
{{- end }}
{{- /* Form-field detection runs the FFDetr detector in-cluster, for deployments
       with no Modal endpoint to call. Its own if, not another branch of the chain
       above: it is orthogonal to layout detection and the two run together. Opt-in
       because it is a GPU-class workload — an install that never sets the key
       renders exactly what it rendered before the key existed, rather than gaining
       a pod, a GPU request and a cost line on upgrade. */}}
{{- if (($.Values.config).parseFormFieldDetection).enabled }}
{{- $activated = set $activated "llamaParseFormFieldDetectionApi" (include "llamacloud.component.llamaParseFormFieldDetectionApi" . | fromYaml) }}
{{- end }}
{{- /* Temporal workloads. Temporal is required: v1 and v2 parse both dispatch
       as workflows, so these are activated unconditionally. */}}
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

{{/*
Temporal's address: the subchart's frontend Service when temporal.deploy=true,
otherwise the required temporal.host/port.

temporal.host is empty in subchart mode, so concatenating it with temporal.port
yields ":7233" — a well-formed address every client reads as localhost. Getting
this wrong therefore fails at runtime, not at render time.

qualifiedEndpoint adds namespace and cluster domain, for callers outside the
release namespace (KEDA evaluates scaler triggers from the keda-operator pod).
*/}}
{{- define "llamacloud.temporal.host" -}}
{{- if .Values.temporal.deploy -}}
{{- printf "%s-temporal-subchart-frontend" .Release.Name -}}
{{- else -}}
{{- if not (and .Values.temporal.host .Values.temporal.port) -}}
{{- fail "temporal.host and temporal.port are required when temporal.deploy is false" -}}
{{- end -}}
{{- .Values.temporal.host -}}
{{- end -}}
{{- end }}

{{- define "llamacloud.temporal.port" -}}
{{- if .Values.temporal.deploy -}}
7233
{{- else -}}
{{- if not (and .Values.temporal.host .Values.temporal.port) -}}
{{- fail "temporal.host and temporal.port are required when temporal.deploy is false" -}}
{{- end -}}
{{- .Values.temporal.port | toString -}}
{{- end -}}
{{- end }}

{{- define "llamacloud.temporal.endpoint" -}}
{{- printf "%s:%s" (include "llamacloud.temporal.host" .) (include "llamacloud.temporal.port" .) -}}
{{- end }}

{{- define "llamacloud.temporal.qualifiedEndpoint" -}}
{{- if .Values.temporal.deploy -}}
{{- printf "%s.%s.svc.cluster.local:%s" (include "llamacloud.temporal.host" .) .Release.Namespace (include "llamacloud.temporal.port" .) -}}
{{- else -}}
{{- include "llamacloud.temporal.endpoint" . -}}
{{- end -}}
{{- end }}
