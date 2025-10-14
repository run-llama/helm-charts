{{/*
Temporal Worker ServiceAccount Template
Generates a ServiceAccount for a temporal worker.

Usage:
{{- include "temporalWorker.serviceaccount" (dict "worker" .Values.temporalParse.parseDelegate "serviceAccountHelper" "temporalParse.parseDelegate.serviceAccountName" "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- serviceAccountHelper: Name of the service account helper to use
- root: The root context (.)
*/}}
{{- define "temporalWorker.serviceaccount" -}}
{{- $worker := .worker -}}
{{- $serviceAccountHelper := .serviceAccountHelper -}}
{{- $root := .root -}}
{{- if $worker.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include $serviceAccountHelper $root }}
  labels:
    {{- include "llamacloud.labels" $root | nindent 4 }}
    {{- with $worker.serviceAccount.labels }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "llamacloud.annotations" $root | nindent 4 }}
    {{- with $worker.serviceAccount.annotations }}
      {{- toYaml . | nindent 4 }}
    {{- end }}
automountServiceAccountToken: {{ $worker.serviceAccount.automountServiceAccountToken | default true }}
{{- end }}
{{- end -}}
