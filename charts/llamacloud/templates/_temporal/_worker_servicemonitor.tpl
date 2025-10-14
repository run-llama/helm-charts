{{/*
Temporal Worker ServiceMonitor Template
Generates a ServiceMonitor for a temporal worker.

Usage:
{{- include "temporalWorker.servicemonitor" (dict "worker" .Values.temporalParse.parseDelegate "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- root: The root context (.)
*/}}
{{- define "temporalWorker.servicemonitor" -}}
{{- $worker := .worker -}}
{{- $root := .root -}}
{{- if and ($root.Capabilities.APIVersions.Has "monitoring.coreos.com/v1") $worker.metrics.enabled $worker.metrics.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}-monitor
  labels:
    app.kubernetes.io/component: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
    {{- include "llamacloud.labels" $root | nindent 4 }}
    {{- with $worker.metrics.serviceMonitor.selector }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- with $worker.metrics.serviceMonitor.additionalLabels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- with $worker.metrics.serviceMonitor.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  endpoints:
    - port: metrics
      interval: {{ $worker.metrics.serviceMonitor.interval }}
      scrapeTimeout: {{ $worker.metrics.serviceMonitor.scrapeTimeout }}
      path: /metrics
      scheme: {{ $worker.metrics.serviceMonitor.scheme }}
      {{- with $worker.metrics.serviceMonitor.relabelings }}
      relabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $worker.metrics.serviceMonitor.metricRelabelings }}
      metricRelabelings:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $worker.metrics.serviceMonitor.tlsConfig }}
      tlsConfig:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  namespaceSelector:
    matchNames:
      - {{ $root.Release.Namespace }}
  selector:
    matchLabels:
      {{- include "llamacloud.selectorLabels" $root | nindent 6 }}
      app.kubernetes.io/component: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
{{- end }}
{{- end -}}
