{{/*
Temporal Parse Component Settings.
*/}}
{{ define "llamacloud.component.temporal.llamaParse" }}
{{- $component := ($.Values.temporalWorkloads).llamaParse }}
{{- $component = set $component "prefix" "llamacloud.component.temporal.llamaParse" }}
{{- $component = set $component "name" "llamacloud-temporal-parse" }}
{{- $component = set $component "image" ( (($.Values.temporalWorkloads).llamaParse).image | default ( print "docker.io/llamaindex/llamacloud-llamaparse:" .Chart.AppVersion ) ) }}
{{- $component = set $component "imagePullPolicy" ( (($.Values.temporalWorkloads).llamaParse).imagePullPolicy | default "IfNotPresent" ) }}
{{- $component = set $component "port" 8003 }}
{{/* LD_PRELOAD is scoped to the node process (not a container ENV) so
     jemalloc isn't inherited by Puppeteer's Chromium children, which SIGSEGV
     when a foreign
     allocator is preloaded into their address space. */}}
{{/* Use /bin/sh, not /bin/bash: the Chainguard-based worker image is busybox-only
     (no bash). Hardcoding /bin/bash crashlooped these workers with
     `exec: "/bin/bash": stat /bin/bash: no such file or directory`. The command body
     is POSIX-sh compatible; sh + jemalloc preload + node were verified on the image. */}}
{{- $component = set $component "command" (list "/bin/sh" "-c" "node dist/worker/bootPrewarm.js & LD_PRELOAD=$JEMALLOC_PATH exec node --max-old-space-size=$MAX_OLD_SPACE_SIZE dist/worker/temporal/bundle-worker.mjs") }}
{{- $component = set $component "usesS3" "true" }}
{{- $component | toYaml }}
{{- end }}

{{/*
Temporal Parse Quarantine Component Settings.

The isolated poison-document lane. Deliberately NOT its own template family:
`prefix` stays on llamacloud.component.temporal.llamaParse so every
resources/probe/env/envFrom/volumes sub-template below is shared rather than
copied — only the Deployment name, image, pull policy, command and worker role
differ.

`workerRole` is set HERE rather than left to per-install extraEnvVariables: the
worker runs the same entrypoint as the normal one, and PARSE_WORKER_ROLE is the
only thing that makes it poll parse-quarantine-queue. Leaving it to the caller
means flipping quarantineWorkerEnabled alone boots a second worker on the
NORMAL queue — a silent loss of the isolation this lane exists for. The shared
env define below reads the key; extraEnvVariables stay additive on top.

Activated only when config.parse.quarantineWorkerEnabled is true — see
llamacloud.components in _common.tpl.
*/}}
{{ define "llamacloud.component.temporal.llamaParseQuarantine" }}
{{- $component := ($.Values.temporalWorkloads).llamaParseQuarantine }}
{{- $component = set $component "prefix" "llamacloud.component.temporal.llamaParse" }}
{{- $component = set $component "name" "llamacloud-temporal-parse-quarantine" }}
{{- $component = set $component "workerRole" "quarantine" }}
{{- $component = set $component "image" ( (($.Values.temporalWorkloads).llamaParseQuarantine).image | default ( print "docker.io/llamaindex/llamacloud-llamaparse:" .Chart.AppVersion ) ) }}
{{- $component = set $component "imagePullPolicy" ( (($.Values.temporalWorkloads).llamaParseQuarantine).imagePullPolicy | default "IfNotPresent" ) }}
{{- $component = set $component "port" 8003 }}
{{/* Same entrypoint as llamaParse above; see that block for why /bin/sh and
     why LD_PRELOAD is scoped to the node process rather than a container ENV. */}}
{{- $component = set $component "command" (list "/bin/sh" "-c" "node dist/worker/bootPrewarm.js & LD_PRELOAD=$JEMALLOC_PATH exec node --max-old-space-size=$MAX_OLD_SPACE_SIZE dist/worker/temporal/bundle-worker.mjs") }}
{{- $component = set $component "usesS3" "true" }}
{{- $component | toYaml }}
{{- end }}

{{/*
Temporal Parse Resources.

Shared by the llamaParse and llamaParseQuarantine components (both carry
prefix llamacloud.component.temporal.llamaParse), as are every probe, env,
envFrom, configMap, secret, volumeMounts and volumes define below.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.resources" }}
requests:
  cpu: {{ (((.component).resources).requests).cpu | default "3" }}
  memory: {{ (((.component).resources).requests).memory | default "6Gi" }}
  {{- with ((((.component).resources).requests)) }}{{- with (index . "ephemeral-storage") }}
  ephemeral-storage: {{ . }}
  {{- end }}{{- end }}
limits:
  cpu: {{ (((.component).resources).limits).cpu | default "7" }}
  memory: {{ (((.component).resources).limits).memory | default "13Gi" }}
  {{- with ((((.component).resources).limits)) }}{{- with (index . "ephemeral-storage") }}
  ephemeral-storage: {{ . }}
  {{- end }}{{- end }}
{{- end }}

{{/*
Temporal Parse Liveness Probe.
*/}}
{{ define "llamacloud.component.temporal.llamaParse.livenessProbe" }}
httpGet:
  path: /healthcheck
  port: http
initialDelaySeconds: 30
periodSeconds: 30
timeoutSeconds: 5
failureThreshold: 10
{{- end }}

{{/*
Temporal Parse Readiness Probe.
*/}}
{{ define "llamacloud.component.temporal.llamaParse.readinessProbe" }}
httpGet:
  path: /healthcheck
  port: http
initialDelaySeconds: 30
periodSeconds: 30
timeoutSeconds: 5
failureThreshold: 10
{{- end }}

{{/*
Temporal Parse Startup Probe.
*/}}
{{ define "llamacloud.component.temporal.llamaParse.startupProbe" }}
httpGet:
  path: /healthcheck
  port: http
initialDelaySeconds: 30
periodSeconds: 30
timeoutSeconds: 5
failureThreshold: 10
{{- end }}

{{/*
Temporal Parse Environment Variables.

Shared by llamaParse and llamaParseQuarantine. `workerRole` is set by the
component define, not by values, so the quarantine component always ships the
role that binds it to parse-quarantine-queue. The normal component sets no
role and so emits none, keeping its rendered env byte-identical.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.env" }}
{{- if (.component).workerRole }}
- name: PARSE_WORKER_ROLE
  value: {{ (.component).workerRole | quote }}
{{- end }}
{{- if (.component).extraEnvVariables }}
{{ toYaml (.component).extraEnvVariables }}
{{- end }}
{{- end }}

{{/*
Temporal Parse Environment Variables from Secrets and ConfigMaps.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.envFrom" }}
{{- include "llamacloud.secrets.license" .root}}
- configMapRef:
    name: bucket-config
- configMapRef:
    name: urls-config
- configMapRef:
    name: concurrency-config
- configMapRef:
    name: temporal-connection-config
{{- if (include "llamacloud.component.temporal.llamaParse.configMap" $ ) }}
- configMapRef:
    name: {{ .component.name }}
{{- end }}
{{- if (include "llamacloud.component.temporal.llamaParse.secret" $) }}
- secretRef:
    name: {{ .component.name }}
{{- end }}
- secretRef:
    name: bucket-secret
{{- include "llamacloud.secrets.rabbitmq" .root }}
{{- include "llamacloud.secrets.openAi" .root }}
{{- include "llamacloud.secrets.anthropic" .root }}
{{- include "llamacloud.secrets.gemini" .root }}
{{- include "llamacloud.secrets.azureOpenAi" .root }}
{{- include "llamacloud.secrets.awsBedrock" .root }}
{{- include "llamacloud.secrets.googleVertexAi" .root }}
{{- end }}

{{/*
Temporal Parse Secret.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.secret" }}
{{- end }}

{{/*
Temporal Parse ConfigMap. 

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.configMap" }}
DEBUG_MODE: {{ ((.root.Values.config).parse).debugMode | default false | quote }}
MAX_QUEUE_CONCURRENCY: {{ ((.root.Values.config).parse).maxQueueConcurrency | default 1 | quote }}

{{- if ((.root.Values.config).parse).preferedPremiumModel }}
PREFERED_PREMIUM_MODE_MODEL: {{ ((.root.Values.config).parse).preferedPremiumModel | quote }}
{{- end }}
{{if ((.root.Values.config).parse).writeDirectory }}
LLAMAPARSE_WRITE_DIRECTORY: {{ ((.root.Values.config).parse).writeDirectory | quote }}
{{- end}}
{{- end }}

{{/*
Temporal Parse Volume Mounts.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.volumeMounts" }}
- mountPath: /tmp
  name: tmp
{{- if (.component).volumeMounts }}
{{ toYaml (.component).volumeMounts }}
{{- end }}
{{- end }}

{{/*
Temporal Parse Volumes.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.temporal.llamaParse.volumes" }}
- emptyDir: {}
  name: tmp
{{- if (((.root.Values.config).storageBuckets).s3proxy.enabled | default false) }}
- emptyDir: {}
  name: s3proxy-tmp
{{- end }}
{{- if (.component).volumes }}
{{ toYaml (.component).volumes }}
{{- end }}
{{- end }}
