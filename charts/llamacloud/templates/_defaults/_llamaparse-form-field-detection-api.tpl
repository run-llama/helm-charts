{{/*
Form-field detection API (FFDetr).

Runs the form-field detector inside the cluster, for deployments that have no
Modal endpoint to call. The worker picks between the two by WHICH ENDPOINT IS
CONFIGURED — see llamaparse/worker/src/pipeline/ai/forms/ffdetrRouting.ts — so
this component's only job is to exist and be reachable at a URL.

Cloned from the layout detection component. The one deliberate difference is the
image rule below: the -cpu suffix lands on the DEFAULT image's TAG only, never on
an image an operator pinned.
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi" }}
{{- $component := .Values.llamaParseFormFieldDetectionApi | deepCopy }}
{{- $component = set $component "prefix" "llamacloud.component.llamaParseFormFieldDetectionApi" }}
{{- $component = set $component "name" "llamacloud-form-field-detection" }}
{{- $component = set $component "gpuEnabled" ((.Values.config).parseFormFieldDetection).gpu }}
{{- /* A suffix rule that rewrites a user-supplied image reference is how an operator
       who pins an image silently gets a different one. So the -cpu suffix is applied
       to the DEFAULT image only, and it lands on the TAG, because the BYOC publish
       pipeline pushes one Docker Hub repo per service with -cpu as a tag. */}}
{{- $ffdImage := ($.Values.llamaParseFormFieldDetectionApi).image }}
{{- if not $ffdImage }}
{{-   $suffix := "" }}
{{-   if not (((.Values.config).parseFormFieldDetection).gpu) }}{{- $suffix = "-cpu" }}{{- end }}
{{-   $ffdImage = printf "docker.io/llamaindex/llamacloud-form-field-detection-api:%s%s" .Chart.AppVersion $suffix }}
{{- end }}
{{- $component = set $component "image" $ffdImage }}
{{- $component = set $component "imagePullPolicy" ( ($.Values.llamaParseFormFieldDetectionApi).imagePullPolicy | default "IfNotPresent" ) }}
{{- $component = set $component "port" 8000 }}
{{- $component | toYaml }}
{{- end }}

{{/*
Form Field Detection Resources.

The cpu/memory defaults here are what keeps the rendered container's
resources.requests non-empty: build/check_chart_resource_requests.py fails the
build for any rendered workload container whose effective requests is absent,
empty or all-null, and values.yaml deliberately ships `resources: {}`.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.resources" }}
{{- $gpuResourceName := (.component).gpuResourceName | default "nvidia.com/gpu" }}
{{- $gpuCount := (.component).gpuCount | default 1 }}
requests:
  cpu: {{ (((.component).resources).requests).cpu | default "1" }}
  memory: {{ (((.component).resources).requests).memory | default "8Gi" }}
  {{- with ((((.component).resources).requests)) }}{{- with (index . "ephemeral-storage") }}
  ephemeral-storage: {{ . }}
  {{- end }}{{- end }}
  {{- if (.component).gpuEnabled }}
  {{ $gpuResourceName }}: {{ $gpuCount }}
  {{- end }}
limits:
  cpu: {{ (((.component).resources).limits).cpu | default "2" }}
  memory: {{ (((.component).resources).limits).memory | default "16Gi" }}
  {{- with ((((.component).resources).limits)) }}{{- with (index . "ephemeral-storage") }}
  ephemeral-storage: {{ . }}
  {{- end }}{{- end }}
  {{- if (.component).gpuEnabled }}
  {{ $gpuResourceName }}: {{ $gpuCount }}
  {{- end }}
{{- end }}

{{/*
Form Field Detection Liveness Probe.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.livenessProbe" }}
{{/*
  Liveness alone uses /live. /health, which readiness and startup use below,
  reports 503 for as long as a timed-out request's inference still holds the
  service's single worker. That drain is recoverable and bounded by the
  service's WORKER_TIMEOUT (300s by default), which outlasts the budget here
  of periodSeconds x failureThreshold = 75s, so liveness on /health would
  restart a pod that was about to recover. /live answers 200 whenever the
  process is up; the unrecoverable case ends the process from inside the
  service at its drain deadline, and that is what fails this probe.
*/}}
httpGet:
  path: /live
  port: http
initialDelaySeconds: 30
periodSeconds: 15
successThreshold: 1
timeoutSeconds: 5
failureThreshold: 5
{{- end }}

{{/*
Form Field Detection Readiness Probe.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.readinessProbe" }}
httpGet:
  path: /health
  port: http
initialDelaySeconds: 15
periodSeconds: 15
successThreshold: 1
timeoutSeconds: 5
failureThreshold: 5
{{- end }}

{{/*
Form Field Detection Startup Probe.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.startupProbe" }}
httpGet:
  path: /health
  port: http
initialDelaySeconds: 30
periodSeconds: 15
successThreshold: 1
timeoutSeconds: 5
failureThreshold: 10
{{- end }}

{{/*
Form Field Detection Environment Variables.

The four detection floors are the knobs this service reads (app/labels.py): a
detection is kept only when its score clears the floor for its class, and
FFDETR_RESOLUTION is the square edge length, in pixels, that each page image is
resized to before inference. They are emitted here with the same values the
image bakes in, so the numbers a cluster runs with are visible in the rendered
manifest instead of hidden inside the container. Keep them in step with the
ENV lines in ffdetr/Dockerfile.*; a value set in extraEnvVariables is rendered
after these and wins, because a duplicate name later in a container's env list
is the one that takes effect.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.env" }}
- name: FFDETR_TEXTBOX_MIN_SCORE
  value: "0.35"
- name: FFDETR_SIGNATURE_MIN_SCORE
  value: "0.35"
- name: FFDETR_CHOICE_MIN_SCORE
  value: "0.45"
- name: FFDETR_RESOLUTION
  value: "1024"
{{- if (.component).extraEnvVariables }}
{{ toYaml (.component).extraEnvVariables }}
{{- end }}
{{- end }}

{{/*
Form Field Detection Environment Variables from Secrets and ConfigMaps.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.envFrom" }}
{{- include "llamacloud.secrets.license" .root}}
{{- if (include "llamacloud.component.llamaParseFormFieldDetectionApi.configMap" $) }}
- configMapRef:
    name: {{ .component.name }}
{{- end }}
{{- if (include "llamacloud.component.llamaParseFormFieldDetectionApi.secret" $) }}
- secretRef:
    name: {{ .component.name }}
{{- end }}
{{- end }}

{{/*
Form Field Detection Secret.

Empty, like layout's. It exists because .envFrom above asks whether it rendered
anything; a missing define is a template-not-defined error, not an empty block.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.secret" }}
{{- end }}

{{/*
Form Field Detection ConfigMap.

Empty, for the same reason as .secret above.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.configMap" }}
{{- end }}

{{/*
Form Field Detection Volume Mounts.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.volumeMounts" }}
- mountPath: /tmp
  name: tmp
{{- if (.component).volumeMounts }}
{{ toYaml (.component).volumeMounts }}
{{- end }}
{{- end }}

{{/*
Form Field Detection Volumes.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.llamaParseFormFieldDetectionApi.volumes" }}
- emptyDir: {}
  name: tmp
{{- if (.component).volumes }}
{{ toYaml (.component).volumes }}
{{- end }}
{{- end }}
