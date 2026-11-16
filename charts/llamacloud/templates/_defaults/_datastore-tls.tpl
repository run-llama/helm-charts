{{/*
Opt-in TLS verification for the connections LlamaCloud opens to PostgreSQL, Redis and
an external Temporal frontend. See docs/datastore-tls.md.

Every helper here renders nothing until one of postgresql.sslMode / sslRootCert,
redis.sslCheckHostname / sslCaCert or temporal.tls.* is set, so an install that sets
none of them renders exactly what it rendered before these values existed.

The settings reach the pods as env entries in the pod spec rather than ConfigMap keys,
so changing one rolls the pods that use it.
*/}}

{{- define "llamacloud.tls.mountRoot" -}}/etc/llamacloud/tls{{- end }}

{{/*
"true" when a CA source ({secretName, configMapName, key}) names a Secret or ConfigMap.
Fails when it names both.

Parameters:
- source: the CA source values
- path: the values path, for the error message
*/}}
{{- define "llamacloud.tls.hasCa" -}}
{{- $source := .source | default dict }}
{{- if and $source.secretName $source.configMapName }}
{{- fail (printf "%s: set secretName or configMapName, not both" .path) }}
{{- end }}
{{- if or $source.secretName $source.configMapName }}true{{ end }}
{{- end }}

{{/*
A volume projecting a CA source's key as ca.crt.

Parameters:
- name: the volume name
- source: the CA source values
*/}}
{{- define "llamacloud.tls.caVolume" }}
- name: {{ .name }}
  {{- if .source.secretName }}
  secret:
    secretName: {{ .source.secretName | quote }}
  {{- else }}
  configMap:
    name: {{ .source.configMapName | quote }}
  {{- end }}
    items:
    - key: {{ .source.key | default "ca.crt" | quote }}
      path: ca.crt
{{- end }}

{{/* Which settings are on. Each returns "true" or "". */}}
{{- define "llamacloud.tls.postgresql.rootCert" -}}
{{- include "llamacloud.tls.hasCa" (dict "source" (.Values.postgresql).sslRootCert "path" "postgresql.sslRootCert") }}
{{- end }}
{{- define "llamacloud.tls.redis.ca" -}}
{{- include "llamacloud.tls.hasCa" (dict "source" (.Values.redis).sslCaCert "path" "redis.sslCaCert") }}
{{- end }}
{{- define "llamacloud.tls.temporal.enabled" -}}
{{- if (((.Values.temporal).tls).enabled) }}true{{ end }}
{{- end }}
{{- define "llamacloud.tls.temporal.ca" -}}
{{- include "llamacloud.tls.hasCa" (dict "source" (((.Values.temporal).tls).caCert) "path" "temporal.tls.caCert") }}
{{- end }}
{{- define "llamacloud.tls.temporal.clientCert" -}}
{{- if ((((.Values.temporal).tls).clientCert).secretName) }}true{{ end }}
{{- end }}

{{/*
Render-time checks. Each one fires only when a TLS value is set.
*/}}
{{- define "llamacloud.tls.validate" -}}
{{- $pg := .Values.postgresql | default dict }}
{{- $pgMode := $pg.sslMode | default "" }}
{{- if and (include "llamacloud.tls.postgresql.rootCert" .) (not (has $pgMode (list "require" "verify-ca" "verify-full"))) }}
{{- fail "postgresql.sslRootCert needs postgresql.sslMode require, verify-ca or verify-full; the other modes never verify the certificate" }}
{{- end }}
{{- $redis := .Values.redis | default dict }}
{{- if and (or $redis.sslCheckHostname (include "llamacloud.tls.redis.ca" .)) (not $redis.secret) (ne ($redis.scheme | default "redis") "rediss") }}
{{- fail "redis.sslCheckHostname and redis.sslCaCert need redis.scheme: rediss" }}
{{- end }}
{{- $ttls := (.Values.temporal).tls | default dict }}
{{- if not $ttls.enabled }}
{{- if or $ttls.serverName (include "llamacloud.tls.temporal.ca" .) (include "llamacloud.tls.temporal.clientCert" .) }}
{{- fail "temporal.tls.serverName, caCert and clientCert need temporal.tls.enabled: true" }}
{{- end }}
{{- else if .Values.temporal.deploy }}
{{- fail "temporal.tls.enabled is for an external Temporal; the bundled Temporal (temporal.deploy: true) serves plaintext gRPC" }}
{{- end }}
{{- if .Values.temporal.deploy }}
{{- include "llamacloud.tls.validateTemporalPersistence" . }}
{{- end }}
{{- end }}

{{/*
The bundled Temporal server connects to the same PostgreSQL host, but the parent chart
cannot write subchart values, so the operator sets its TLS under
temporal-subchart.server.config.persistence.datastores.<store>.sql. This refuses to render
when that connection would be weaker than postgresql.sslMode.

The effective mode follows Temporal 1.31's postgres plugin (buildDSNAttr): a
connectAttributes.sslmode wins; otherwise tls.enabled gives verify-full with
enableHostVerification and require without; otherwise disable.
*/}}
{{- define "llamacloud.tls.validateTemporalPersistence" -}}
{{- $rank := dict "" 0 "disable" 0 "allow" 1 "prefer" 2 "require" 3 "verify-ca" 4 "verify-full" 5 }}
{{- $want := (.Values.postgresql).sslMode | default "" }}
{{- if ge (int (get $rank $want)) 3 }}
{{- $datastores := ((((index .Values "temporal-subchart") | default dict).server | default dict).config | default dict).persistence | default dict }}
{{- $datastores = $datastores.datastores | default dict }}
{{- range $store := list "default" "visibility" }}
{{- $sql := (get $datastores $store | default dict).sql | default dict }}
{{- $tls := $sql.tls | default dict }}
{{- $mode := (get ($sql.connectAttributes | default dict) "sslmode") | default "" }}
{{- if not $mode }}
{{- if $tls.enabled }}
{{- $mode = ternary "verify-full" "require" (eq ($tls.enableHostVerification | toString) "true") }}
{{- else }}
{{- $mode = "disable" }}
{{- end }}
{{- end }}
{{- if lt (int (get $rank $mode | default 0)) (int (get $rank $want)) }}
{{- fail (printf "postgresql.sslMode is %s but the bundled Temporal's %s store connects with sslmode=%s. Set temporal-subchart.server.config.persistence.datastores.%s.sql.tls (enabled: true, enableHostVerification: true for verify-full, caFile for a private CA), or connectAttributes.sslmode for verify-ca. See docs/datastore-tls.md." $want $store $mode $store) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Env entries for a component.

Parameters:
- root: $
- postgresql: true for components that connect to PostgreSQL (Python)
- redisPython: true for Python components that connect to Redis
- redisNode: true for Node components that connect to Redis
- temporal: true for components that connect to Temporal
*/}}
{{- define "llamacloud.tls.env" }}
{{- $root := .root }}
{{- $mount := include "llamacloud.tls.mountRoot" $root }}
{{- if .postgresql }}
{{- with ($root.Values.postgresql).sslMode }}
- name: DATABASE_SSL_MODE
  value: {{ . | quote }}
{{- end }}
{{- if include "llamacloud.tls.postgresql.rootCert" $root }}
- name: DATABASE_SSL_ROOT_CERT
  value: {{ printf "%s/postgresql/ca.crt" $mount | quote }}
{{- end }}
{{- end }}
{{- if .redisPython }}
{{- if ($root.Values.redis).sslCheckHostname }}
- name: REDIS_SSL_CHECK_HOSTNAME
  value: "true"
{{- end }}
{{- if include "llamacloud.tls.redis.ca" $root }}
- name: REDIS_SSL_CA_CERTS
  value: {{ printf "%s/redis/ca.crt" $mount | quote }}
{{- end }}
{{- end }}
{{- if and .redisNode (include "llamacloud.tls.redis.ca" $root) }}
{{- /* Adds to Node's built-in roots, for every TLS connection the process makes. */}}
- name: NODE_EXTRA_CA_CERTS
  value: {{ printf "%s/redis/ca.crt" $mount | quote }}
{{- end }}
{{- if and .temporal (include "llamacloud.tls.temporal.enabled" $root) }}
- name: TEMPORAL_TLS
  value: "true"
{{- if include "llamacloud.tls.temporal.ca" $root }}
- name: TEMPORAL_TLS_CA_CERT
  value: {{ printf "%s/temporal/ca.crt" $mount | quote }}
{{- end }}
{{- if include "llamacloud.tls.temporal.clientCert" $root }}
- name: TEMPORAL_TLS_CLIENT_CERT
  value: {{ printf "%s/temporal-client/tls.crt" $mount | quote }}
- name: TEMPORAL_TLS_CLIENT_KEY
  value: {{ printf "%s/temporal-client/tls.key" $mount | quote }}
{{- end }}
{{- with $root.Values.temporal.tls.serverName }}
- name: TEMPORAL_TLS_SERVER_NAME
  value: {{ . | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Volume mounts and volumes for a component. Same parameters as llamacloud.tls.env, where
redis means either Redis flag.
*/}}
{{- define "llamacloud.tls.volumeMounts" }}
{{- $root := .root }}
{{- $mount := include "llamacloud.tls.mountRoot" $root }}
{{- if and .postgresql (include "llamacloud.tls.postgresql.rootCert" $root) }}
- name: tls-postgresql-ca
  mountPath: {{ printf "%s/postgresql" $mount }}
  readOnly: true
{{- end }}
{{- if and (or .redisPython .redisNode) (include "llamacloud.tls.redis.ca" $root) }}
- name: tls-redis-ca
  mountPath: {{ printf "%s/redis" $mount }}
  readOnly: true
{{- end }}
{{- if and .temporal (include "llamacloud.tls.temporal.enabled" $root) }}
{{- if include "llamacloud.tls.temporal.ca" $root }}
- name: tls-temporal-ca
  mountPath: {{ printf "%s/temporal" $mount }}
  readOnly: true
{{- end }}
{{- if include "llamacloud.tls.temporal.clientCert" $root }}
- name: tls-temporal-client
  mountPath: {{ printf "%s/temporal-client" $mount }}
  readOnly: true
{{- end }}
{{- end }}
{{- end }}

{{- define "llamacloud.tls.volumes" }}
{{- $root := .root }}
{{- if and .postgresql (include "llamacloud.tls.postgresql.rootCert" $root) }}
{{- include "llamacloud.tls.caVolume" (dict "name" "tls-postgresql-ca" "source" $root.Values.postgresql.sslRootCert) }}
{{- end }}
{{- if and (or .redisPython .redisNode) (include "llamacloud.tls.redis.ca" $root) }}
{{- include "llamacloud.tls.caVolume" (dict "name" "tls-redis-ca" "source" $root.Values.redis.sslCaCert) }}
{{- end }}
{{- if and .temporal (include "llamacloud.tls.temporal.enabled" $root) }}
{{- if include "llamacloud.tls.temporal.ca" $root }}
{{- include "llamacloud.tls.caVolume" (dict "name" "tls-temporal-ca" "source" $root.Values.temporal.tls.caCert) }}
{{- end }}
{{- if include "llamacloud.tls.temporal.clientCert" $root }}
{{- $client := $root.Values.temporal.tls.clientCert }}
- name: tls-temporal-client
  secret:
    secretName: {{ $client.secretName | quote }}
    items:
    - key: {{ $client.certKey | default "tls.crt" | quote }}
      path: tls.crt
    - key: {{ $client.keyKey | default "tls.key" | quote }}
      path: tls.key
{{- end }}
{{- end }}
{{- end }}
