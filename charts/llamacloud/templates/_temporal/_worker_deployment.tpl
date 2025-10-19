{{/*
Temporal Worker Deployment Template
Generates a Deployment for a temporal worker.

Usage:
{{- include "temporalWorker.deployment" (dict "worker" .Values.temporalParse.parseDelegate "serviceAccountHelper" "temporalParse.parseDelegate.serviceAccountName" "root" .) -}}

Parameters:
- worker: The worker configuration from values.yaml
- serviceAccountHelper: Name of the service account helper to use
- root: The root context (.)
*/}}
{{- define "temporalWorker.deployment" -}}
{{- $worker := .worker -}}
{{- $serviceAccountHelper := .serviceAccountHelper -}}
{{- $root := .root -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  labels:
    {{- include "llamacloud.labels" $root | nindent 4 }}
    {{- with $worker.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  annotations:
    {{- include "llamacloud.annotations" $root | nindent 4 }}
    {{- with $worker.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if and (not $worker.autoscaling.enabled) (not $worker.keda.enabled) }}
  replicas: {{ $worker.replicas }}
  {{- end }}
  strategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  selector:
    matchLabels:
      {{- include "llamacloud.selectorLabels" $root | nindent 6 }}
      app.kubernetes.io/component: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include "temporalWorker.configmap" (dict "worker" $worker "root" $root) | sha256sum }}
        checksum/secret: {{ include "temporalWorker.secret" (dict "worker" $worker "root" $root) | sha256sum }}
        {{- with $worker.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        app.kubernetes.io/component: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}
        temporal_worker: "true"
        {{- include "llamacloud.labels" $root | nindent 8 }}
        {{- with $worker.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with $root.Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include $serviceAccountHelper $root }}
      securityContext:
        {{- toYaml $worker.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ $worker.name }}
          securityContext:
            {{- toYaml $worker.securityContext | nindent 12 }}
          image: "{{ $worker.image.registry }}/{{ $worker.image.repository }}:{{ $worker.image.tag | default $root.Chart.AppVersion }}"
          imagePullPolicy: {{ $worker.image.pullPolicy }}
          command: {{ toYaml $worker.command | nindent 12 }}
          ports:
            - name: worker-http
              containerPort: {{ $worker.containerPort }}
              protocol: TCP
            - name: metrics
              containerPort: 9000
              protocol: TCP
          livenessProbe:
            {{- toYaml $worker.livenessProbe | nindent 12 }}
          resources:
            {{- toYaml $worker.resources | nindent 12 }}
          env:
          - name: LLAMACLOUD_LICENSE_KEY
            valueFrom:
              secretKeyRef:
                {{- if $root.Values.global.config.existingLicenseKeySecret }}
                name: {{ $root.Values.global.config.existingLicenseKeySecret }}
                {{- else }}
                name: {{ include "llamacloud.fullname" $root }}-license-key
                {{- end }}
                key: llamacloud-license-key
          - name: WORKER_PORT
            value: {{ $worker.containerPort | quote }}
          - name: POD_NAME
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.name
          {{- include "common.postgresql.envVars" $root | nindent 10 -}}
          {{- with $worker.extraEnvVariables }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
          envFrom:
          - configMapRef:
              name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}-config
          {{- if $root.Values.global.config.existingAwsSecretName }}
          - secretRef:
              name: {{ $root.Values.global.config.existingAwsSecretName }}
          {{- end }}
          {{- if $root.Values.llms.enabled }}
          {{- include "common.llmModels.secretRefs" $root | nindent 10 }}
          {{- else }}
          {{- if $root.Values.backend.config.existingOpenAiApiKeySecretName }}
          - secretRef:
              name: {{ $root.Values.backend.config.existingOpenAiApiKeySecretName }}
          {{- end }}
          {{- if and $root.Values.backend.config.azureOpenAi.enabled $root.Values.backend.config.azureOpenAi.existingSecret }}
          - secretRef:
              name: {{ $root.Values.backend.config.azureOpenAi.existingSecret }}
          {{- end }}
          {{- end }}
          {{- if and (not $root.Values.postgresql.enabled) $root.Values.global.config.postgresql.external.enabled $root.Values.global.config.postgresql.external.existingSecretName }}
          - secretRef:
              name: {{ $root.Values.global.config.postgresql.external.existingSecretName }}
          {{- end }}
          {{- if not $worker.externalSecrets.enabled }}
          - secretRef:
              name: {{ include "llamacloud.fullname" $root }}-{{ $worker.name }}-secret
          {{- else }}
          {{- range $worker.externalSecrets.secrets }}
          - secretRef:
              name: {{ . }}
          {{- end }}
          {{- end }}
          {{- with $worker.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with $worker.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $worker.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $worker.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $worker.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end -}}
