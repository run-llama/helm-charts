{{/*
MCP Server Component Settings.

Serves the LlamaCloud MCP endpoints to agent clients. Off by default: it is only
useful to a deployment that wants agents talking to its own LlamaCloud, and it
is the one component whose image a customer may not have mirrored.
*/}}
{{ define "llamacloud.component.mcp" }}
{{- $component := .Values.mcp }}
{{- $component = set $component "prefix" "llamacloud.component.mcp" }}
{{- $component = set $component "name" "llamacloud-mcp" }}
{{- /* No appVersion fallback: the MCP server is released from its own repo, so a
       tag derived from this chart's version has never been published. Falling back
       to one would render a reference whose only possible outcome is
       ImagePullBackOff, discovered by whoever enabled MCP. values.yaml pins a real
       tag; emptying it is a mistake worth failing the render for. */}}
{{- $component = set $component "image" ( ($.Values.mcp).image | required "mcp.image must name a tag published to docker.io/llamaindex/llamacloud-mcp. The chart pins a working default -- clear it only to substitute a mirrored image, never to fall back to one." ) }}
{{- $component = set $component "imagePullPolicy" ( ($.Values.mcp).imagePullPolicy | default "IfNotPresent" ) }}
{{- $component = set $component "port" 3000 }}
{{- $component | toYaml }}
{{- end }}

{{/*
Hostname the chart routes to the MCP Service, or empty when it adds no route.

Derived from config.mcp.publicUrl -- the URL already advertised to MCP clients --
so the route and that URL cannot drift apart. Empty when MCP is off, when
publicUrl is unset, when there is no Ingress, or when publicUrl names the main
ingress host, which means the operator routes MCP themselves.

Lowercased, and compared lowercased: hostnames are case-insensitive, but urlParse
preserves case, so "https://MCP.Example.com" would otherwise both slip past the
main-host comparison and render an Ingress host the API server rejects as a
non-RFC-1123 subdomain. The port is stripped by regex rather than by splitting on
":" so that a bracketed IPv6 literal survives intact to be rejected whole instead
of being silently truncated to "[fd00".

Fails on a publicUrl with no scheme, which parses to an empty host and would
silently drop the route -- but only where a route is actually being derived, so
that a deployment with no Ingress is not blocked from upgrading by a value that
would change nothing for it.

Parameters:
- root: $
*/}}
{{- define "llamacloud.mcp.ingressHost" -}}
{{- $mcpUrl := (((.root.Values.config).mcp).publicUrl) | default "" -}}
{{- if and (((.root.Values.config).mcp).enabled) $mcpUrl ((.root.Values.ingress).enabled) -}}
  {{- $parsed := urlParse $mcpUrl -}}
  {{- if not $parsed.host -}}
    {{- fail (printf "config.mcp.publicUrl must be an absolute URL including a scheme, e.g. \"https://mcp.%s\" (got %q)" (((.root.Values.ingress).host) | default "your-llamacloud-host") $mcpUrl) -}}
  {{- end -}}
  {{- $h := lower (regexReplaceAll ":[0-9]+$" $parsed.host "") -}}
  {{- if ne $h (lower ((((.root.Values.ingress).host)) | default "")) -}}
    {{- $h -}}
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
MCP Resources.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.resources" }}
requests:
  cpu: {{ (((.component).resources).requests).cpu | default "100m" }}
  memory: {{ (((.component).resources).requests).memory | default "256Mi" }}
  {{- with ((((.component).resources).requests)) }}{{- with (index . "ephemeral-storage") }}
  ephemeral-storage: {{ . }}
  {{- end }}{{- end }}
limits:
  cpu: {{ (((.component).resources).limits).cpu | default "1" }}
  memory: {{ (((.component).resources).limits).memory | default "1Gi" }}
  {{- with ((((.component).resources).limits)) }}{{- with (index . "ephemeral-storage") }}
  ephemeral-storage: {{ . }}
  {{- end }}{{- end }}
{{- end }}

{{/*
MCP Liveness Probe.

/api/healthz deliberately checks nothing downstream: Redis and LlamaCloud are
reached per request, so failing here on a dependency blip would restart a pod
that can still serve everything not touching it.
*/}}
{{ define "llamacloud.component.mcp.livenessProbe" }}
httpGet:
  path: /api/healthz
  port: http
initialDelaySeconds: 30
periodSeconds: 10
timeoutSeconds: 5
failureThreshold: 30
{{- end }}

{{/*
MCP Readiness Probe.
*/}}
{{ define "llamacloud.component.mcp.readinessProbe" }}
httpGet:
  path: /api/healthz
  port: http
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 5
failureThreshold: 3
{{- end }}

{{/*
MCP Startup Probe.
*/}}
{{ define "llamacloud.component.mcp.startupProbe" }}
httpGet:
  path: /api/healthz
  port: http
initialDelaySeconds: 10
periodSeconds: 15
timeoutSeconds: 5
failureThreshold: 30
{{- end }}

{{/*
MCP Environment Variables.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.env" }}
{{- if (.component).extraEnvVariables }}
{{ toYaml (.component).extraEnvVariables }}
{{- end }}
{{- end }}

{{/*
MCP Environment Variables from Secrets and ConfigMaps.

The Redis secret carries REDIS_HOST and friends as discrete keys; the server
composes its connection from those when REDIS_URI is unset.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.envFrom" }}
{{- include "llamacloud.secrets.license" .root }}
{{- include "llamacloud.secrets.redis" .root }}
{{- if (include "llamacloud.component.mcp.configMap" $) }}
- configMapRef:
    name: {{ .component.name }}
{{- end }}
{{- if (include "llamacloud.component.mcp.secret" $) }}
- secretRef:
    name: {{ .component.name }}
{{- end }}
{{- end }}

{{/*
MCP Secret.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.secret" }}
{{- end }}

{{/*
MCP ConfigMap.

api_key is the only mode a self-hosted deployment can serve: OAuth would need
the tenant's users to exist in our WorkOS directory, which they do not.

LLAMA_CLOUD_BASE_URL defaults to the in-cluster backend Service, the same
address every other component uses. The server accepts cleartext only for
cluster-internal hosts, so an override pointing anywhere public must be https.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.configMap" }}
HOSTNAME: 0.0.0.0
MCP_AUTH_MODE: api_key
LLAMA_CLOUD_REGION: {{ (((.root.Values.config).mcp).region) | default "na" | quote }}
LLAMA_CLOUD_BASE_URL: {{ (((.root.Values.config).mcp).llamaCloudBaseUrl) | default (printf "http://%s:%d" (include "llamacloud.component.backend" .root | fromYaml).name (80 | int)) | quote }}
{{- if (((.root.Values.config).mcp).allowPrivateUploadHosts) }}
ALLOW_PRIVATE_UPLOAD_HOSTS: "true"
{{- end }}
{{- end }}

{{/*
MCP Volume Mounts.

The default securityContext sets readOnlyRootFilesystem, and a Next.js
standalone server writes to both of these.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.volumeMounts" }}
- mountPath: /tmp
  name: tmp
- mountPath: /app/.next/cache
  name: nextjs-cache
{{- if (.component).volumeMounts }}
{{ toYaml (.component).volumeMounts }}
{{- end }}
{{- end }}

{{/*
MCP Volumes.

Parameters:
- component: The component configuration in values.yaml
- root: $
*/}}
{{ define "llamacloud.component.mcp.volumes" }}
- emptyDir: {}
  name: tmp
- emptyDir: {}
  name: nextjs-cache
{{- if (.component).volumes }}
{{ toYaml (.component).volumes }}
{{- end }}
{{- end }}
