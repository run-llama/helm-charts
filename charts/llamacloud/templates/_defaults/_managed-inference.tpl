{{/*
Managed inference gateway base URL without a trailing slash, or "" when unset.
*/}}
{{- define "llamacloud.managedInference.url" -}}
{{- trimSuffix "/" (((.Values.config).managedInference).url | default "") -}}
{{- end }}

{{/*
Name of the Secret holding MANAGED_INFERENCE_GATEWAY_API_KEY: config.managedInference.secret
when set, else the Secret this chart renders from config.managedInference.apiKey.
*/}}
{{- define "llamacloud.managedInference.secretName" -}}
{{- ((.Values.config).managedInference).secret | default "managed-inference-secret" -}}
{{- end }}

{{/*
Env entries for a component that calls the managed inference gateway: its URL, then
MANAGED_INFERENCE_GATEWAY_API_KEY and each name in `tokenNames`, all read from the gateway
key in its Secret. Renders nothing while the URL is unset.
Parameters: root ($), tokenNames (optional list of env names)
*/}}
{{- define "llamacloud.managedInference.env" }}
{{- if include "llamacloud.managedInference.url" .root }}
{{- $secretName := include "llamacloud.managedInference.secretName" .root }}
- name: MANAGED_INFERENCE_GATEWAY_URL
  value: {{ include "llamacloud.managedInference.url" .root | quote }}
{{- range prepend (.tokenNames | default list) "MANAGED_INFERENCE_GATEWAY_API_KEY" }}
- name: {{ . }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName | quote }}
      key: MANAGED_INFERENCE_GATEWAY_API_KEY
{{- end }}
{{- end }}
{{- end }}

{{/*
YAML list of the bearer env names the parse worker sends to the gateway's OCR, layout and
form-field detection routes. Each follows the setting that gates its route in urls-config.
*/}}
{{- define "llamacloud.managedInference.parseTokenNames" -}}
{{- $config := .Values.config }}
{{- $names := list }}
{{- if ($config.parseOcr).enabled }}
{{- $names = append $names "OCR_SERVICE_TOKEN" }}
{{- end }}
{{- if or ($config.parseLayoutDetectionV3).enabled ($config.parseLayoutDetection).enabled }}
{{- $names = append $names "LAYOUT_EXTRACTION_V3_MODAL_TOKEN" }}
{{- end }}
{{- if ($config.parseFormFieldDetection).enabled }}
{{- $names = append $names "FFDETR_MODAL_TOKEN" }}
{{- end }}
{{- $names | toYaml }}
{{- end }}

{{/*
Fails the render when config.managedInference.url is set but is not an http(s) URL, when
neither config.managedInference.apiKey nor config.managedInference.secret is set, or when
config.llms configures a model provider.
*/}}
{{- define "llamacloud.managedInference.validate" -}}
{{- $managed := .Values.config.managedInference }}
{{- if not (regexMatch "^https?://[^/]+" $managed.url) }}
{{- fail "config.managedInference.url must be an http(s) URL" }}
{{- end }}
{{- if not (or $managed.apiKey $managed.secret) }}
{{- fail "config.managedInference.apiKey or config.managedInference.secret is required when config.managedInference.url is set" }}
{{- end }}
{{- $llms := .Values.config.llms | default dict }}
{{- $providerSettings := dict
    "openAi" (list "apiKey" "secret" "baseUrl")
    "anthropic" (list "apiKey" "secret" "baseUrl")
    "gemini" (list "apiKey" "secret" "baseUrl")
    "azureOpenAi" (list "secret" "deployments")
    "awsBedrock" (list "region" "accessKeyId" "secretAccessKey" "secret")
    "googleVertexAi" (list "projectId" "location" "credentialsJson" "secret" "baseUrl") }}
{{- $conflicts := list }}
{{- range $provider, $keys := $providerSettings }}
{{- $settings := get $llms $provider | default dict }}
{{- range $keys }}
{{- if get $settings . }}
{{- $conflicts = append $conflicts (printf "config.llms.%s.%s" $provider .) }}
{{- end }}
{{- end }}
{{- end }}
{{- if $llms.providerConfigs }}
{{- $conflicts = append $conflicts "config.llms.providerConfigs" }}
{{- end }}
{{- with $conflicts }}
{{- fail (printf "config.managedInference.url cannot be combined with customer model provider settings; unset %s" (join ", " .)) }}
{{- end }}
{{- end }}
