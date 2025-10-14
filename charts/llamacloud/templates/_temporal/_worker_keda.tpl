{{/*
Temporal Worker KEDA ScaledObject Template
Generates a KEDA ScaledObject for a temporal worker.

Usage:
{{- include "temporalWorker.keda" (dict "worker" .Values.temporalParse.parseDelegate "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- root: The root context (.)
*/}}
{{- define "temporalWorker.keda" -}}
{{- $worker := .worker -}}
{{- $root := .root -}}
{{- if and ($root.Capabilities.APIVersions.Has "keda.sh/v1alpha1") $worker.keda.enabled }}
{{- if $worker.autoscaling.enabled }}
{{- fail (printf "Keda configuration (`.Values.temporalParse.%s.keda`) and HPA configurations (`.Values.temporalParse.%s.autoscaling`) cannot be both enabled at the same time!" $worker.name $worker.name) }}
{{- end }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "llamacloud.labels" $root | nindent 4 }}
    {{- with $worker.keda.additionalLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "llamacloud.annotations" $root | nindent 4 }}
    {{- with $worker.keda.additionalAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  pollingInterval: {{ $worker.keda.pollingInterval }}
  cooldownPeriod: {{ $worker.keda.cooldownPeriod }}
  initialCooldownPeriod: {{ $worker.keda.initialCooldownPeriod }}
  minReplicaCount: {{ $worker.keda.minReplicaCount }}
  maxReplicaCount: {{ $worker.keda.maxReplicaCount }}
  {{- with $worker.keda.fallback }}
  fallback:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $worker.keda.advanced }}
  advanced:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $worker.keda.triggers }}
  triggers:
    {{- tpl (toYaml .) $root | nindent 4 }}
  {{- else }}
    {{- fail (printf "At least one element in `.Values.temporalParse.%s.keda.triggers` is required!" $worker.name) }}
  {{- end }}
{{- end }}
{{- end -}}
