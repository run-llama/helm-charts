{{/*
Canonical Layout component settings. The public Helm contract and Kubernetes
identity remain stable for BYOC upgrades while the component runs Layout V3.
*/}}
{{ define "llamacloud.component.llamaParseLayoutDetectionApi" }}
{{- $component := .Values.llamaParseLayoutDetectionApi }}
{{- $component = set $component "prefix" "llamacloud.component.llamaParseLayoutDetectionApiV3" }}
{{- $component = set $component "name" "llamacloud-layout" }}
{{- $component = set $component "gpuEnabled" ((.Values.config).parseLayoutDetection).gpu }}
{{- $defaultImage := printf "docker.io/llamaindex/llamacloud-layout-detection-api-v3:%s" .Chart.AppVersion }}
{{- /* CPU mode pulls the separately published -cpu build. The suffix applies only
     to the default tag. An explicit image is used unchanged. */}}
{{- if not (((.Values.config).parseLayoutDetection).gpu) }}
{{- $defaultImage = printf "%s-cpu" $defaultImage }}
{{- end }}
{{- $configuredImage := ($.Values.llamaParseLayoutDetectionApi).image }}
{{- if or (not $configuredImage) (hasPrefix "docker.io/llamaindex/llamacloud-layout-detection-api:" $configuredImage) }}
{{- $configuredImage = $defaultImage }}
{{- end }}
{{- $component = set $component "image" $configuredImage }}
{{- $component = set $component "imagePullPolicy" ( ($.Values.llamaParseLayoutDetectionApi).imagePullPolicy | default "IfNotPresent" ) }}
{{- $component = set $component "terminationGracePeriodSeconds" ( ($.Values.llamaParseLayoutDetectionApi).terminationGracePeriodSeconds | default 60 ) }}
{{- $component = set $component "port" 8000 }}
{{- $component = set $component "skipDefaultEnv" true }}
{{- $component | toYaml }}
{{- end }}
