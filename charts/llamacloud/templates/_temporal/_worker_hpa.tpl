{{/*
Temporal Worker HorizontalPodAutoscaler Template
Generates an HPA for a temporal worker.

Usage:
{{- include "temporalWorker.hpa" (dict "worker" .Values.temporalParse.parseDelegate "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- root: The root context (.)
*/}}
{{- define "temporalWorker.hpa" -}}
{{- $worker := .worker -}}
{{- $root := .root -}}
{{- if $worker.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  labels:
    {{- include "llamacloud.labels" $root | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  minReplicas: {{ $worker.autoscaling.minReplicas }}
  maxReplicas: {{ $worker.autoscaling.maxReplicas }}
  metrics:
    {{- if $worker.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ $worker.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if $worker.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ $worker.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
{{- end -}}
