{{/*
Chart-owned HPA for the parse worker (temporalWorkloads.llamaParse.autoscaling).
Sets horizontalPodAutoscalerSpec on the component so templates/llamacloud/hpa.yaml
renders it: ContainerResource cpu and memory metrics on the parse container at
autoscaling.targetCpuUtilization / targetMemoryUtilization. The worker reads
the same two numbers and sets its resource tuner to admit work past them.
`autoscalingOwnsHpa` marks the spec as chart-made, so a second include of the
component does not read it as a user-set spec.

Parameters:
- component: the llamaParse component dict, modified in place
- root: $
*/}}
{{- define "llamacloud.parseResourceTuner.autoscaling" }}
{{- $component := .component }}
{{- $autoscaling := ($component).autoscaling | default dict }}
{{- if and $autoscaling.enabled (not $component.autoscalingOwnsHpa) }}
{{- $parse := (.root.Values.config).parse | default dict }}
{{- if not (and $parse.multiActivityWorkflowEnabled ($parse.resourceTuner).enabled) }}
{{- fail "temporalWorkloads.llamaParse.autoscaling.enabled needs config.parse.multiActivityWorkflowEnabled and config.parse.resourceTuner.enabled" }}
{{- end }}
{{- if $component.horizontalPodAutoscalerSpec }}
{{- fail "temporalWorkloads.llamaParse: set autoscaling.enabled or horizontalPodAutoscalerSpec, not both" }}
{{- end }}
{{- if not (kindIs "invalid" $component.replicas) }}
{{- fail "temporalWorkloads.llamaParse: replicas must stay null when autoscaling.enabled is true" }}
{{- end }}
{{- $minReplicas := $autoscaling.minReplicas | default 1 | int }}
{{- $maxReplicas := $autoscaling.maxReplicas | default 10 | int }}
{{- if or (lt $minReplicas 1) (lt $maxReplicas $minReplicas) }}
{{- fail (printf "temporalWorkloads.llamaParse.autoscaling: need 1 <= minReplicas <= maxReplicas, got %d and %d" $minReplicas $maxReplicas) }}
{{- end }}
{{- $metrics := list }}
{{- range $resource, $target := dict "cpu" $autoscaling.targetCpuUtilization "memory" $autoscaling.targetMemoryUtilization }}
{{- $metrics = append $metrics (dict "type" "ContainerResource" "containerResource" (dict "name" $resource "container" "llamacloud-temporal-parse" "target" (dict "type" "Utilization" "averageUtilization" (int $target)))) }}
{{- end }}
{{- $_ := set $component "horizontalPodAutoscalerSpec" (dict "minReplicas" $minReplicas "maxReplicas" $maxReplicas "metrics" $metrics) }}
{{- $_ = set $component "autoscalingOwnsHpa" true }}
{{- end }}
{{- end }}

{{/*
Parse resource tuner env for the consolidated parse worker. Read by
llamaparse/worker/src/temporal/parseResourceTunerConfig.ts, which turns the
scale-at percents and this container's resources (downward API) into SDK targets.

Parameters: the root context ($)
*/}}
{{- define "llamacloud.parseResourceTuner.env" }}
{{- $tuner := ((.Values.config).parse).resourceTuner }}
{{- $autoscaling := ((.Values.temporalWorkloads).llamaParse).autoscaling | default dict }}
{{- if and ((.Values.config).parse).multiActivityWorkflowEnabled ($tuner).enabled }}
- name: PARSE_RESOURCE_TUNER_ENABLED
  value: "true"
- name: PARSE_RESOURCE_TUNER_SLOTS
  value: {{ $tuner.slots | quote }}
- name: PARSE_RESOURCE_TUNER_SCALE_AT_CPU_PERCENT
  value: {{ $autoscaling.targetCpuUtilization | int | quote }}
- name: PARSE_RESOURCE_TUNER_SCALE_AT_MEMORY_PERCENT
  value: {{ $autoscaling.targetMemoryUtilization | int | quote }}
{{- range $name, $field := dict "CPU_REQUEST_MILLICORES" (list "requests.cpu" "1m") "CPU_LIMIT_MILLICORES" (list "limits.cpu" "1m") "MEMORY_REQUEST_MIB" (list "requests.memory" "1Mi") "MEMORY_LIMIT_MIB" (list "limits.memory" "1Mi") }}
- name: PARSE_CONTAINER_{{ $name }}
  valueFrom:
    resourceFieldRef:
      containerName: llamacloud-temporal-parse
      resource: {{ index $field 0 }}
      divisor: {{ index $field 1 }}
{{- end }}
{{- end }}
{{- end }}
