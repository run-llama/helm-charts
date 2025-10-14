{{/*
Temporal Worker Service Template
Generates a Service for a temporal worker.

Usage:
{{- include "temporalWorker.service" (dict "worker" .Values.temporalParse.parseDelegate "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- root: The root context (.)
*/}}
{{- define "temporalWorker.service" -}}
{{- $worker := .worker -}}
{{- $root := .root -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  labels:
    app.kubernetes.io/component: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
    {{- include "llamacloud.labels" $root | nindent 4 }}
    {{- with $worker.service.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "llamacloud.annotations" $root | nindent 4 }}
    {{- with $worker.service.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  type: {{ $worker.service.type }}
  ports:
    - name: http
      port: {{ $worker.service.port }}
      targetPort: worker-http
      protocol: TCP
    - name: metrics
      port: 9000
      targetPort: 9000
      protocol: TCP
  selector:
    {{- include "llamacloud.selectorLabels" $root | nindent 4 }}
    app.kubernetes.io/component: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
{{- end -}}
