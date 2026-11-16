# Verified TLS to PostgreSQL, Redis and Temporal

By default LlamaCloud connects to its datastores the way each client library
does out of the box. For PostgreSQL that is `sslmode=prefer`: the connection
is encrypted when the server offers TLS, but the server certificate is never
checked, and the client falls back to plaintext if TLS is not offered. The
bundled Temporal connects to PostgreSQL with `sslmode=disable`. Redis over
`rediss` verifies the CA but not the hostname in the Python components, and
LlamaCloud talks to Temporal in plaintext.

The values on this page turn on verified TLS for each of those connections.
All of them are off by default. An install that sets none of them renders
exactly the same manifests as before they existed, so upgrading changes
nothing until you opt in.

Each setting reaches the pods as environment variables and volumes in the pod
spec, so changing one rolls the affected Deployments on `helm upgrade`.

CA bundles are mounted read-only under `/etc/llamacloud/tls/`. Each one comes
from a Secret or a ConfigMap you create in the release namespace:

```bash
kubectl -n <namespace> create secret generic postgresql-ca \
  --from-file=ca.crt=./server-ca.pem
```

When you leave the CA source empty, the image's system CA store is used. That
works when the server certificate chains to a public root. Most managed
databases use a private CA, so supply the bundle your provider publishes.

## PostgreSQL

```yaml
postgresql:
  sslMode: verify-full
  sslRootCert:
    secretName: postgresql-ca   # or configMapName
    key: ca.crt
```

`sslMode` takes libpq's values: `disable`, `allow`, `prefer`, `require`,
`verify-ca`, `verify-full`. Use `verify-full` unless the certificate cannot
match the host name you connect to, in which case use `verify-ca`.

`sslRootCert` is mounted at `/etc/llamacloud/tls/postgresql/ca.crt`. It is used
by `verify-ca` and `verify-full`, and by `require`, which then verifies the CA
(as libpq does). Setting it with a non-verifying mode fails the render.

### Where it takes effect

The setting goes to the three Deployments that connect to PostgreSQL: the API
(`llamacloud`), usage (`llamacloud-telemetry`) and the Python Temporal workers
(`temporalWorkloads.workers`). They receive `DATABASE_SSL_MODE` and
`DATABASE_SSL_ROOT_CERT`, which apply to every connection they open to the
platform database:

| Client | How the setting is applied |
|---|---|
| SQLAlchemy over asyncpg (API, workers, the read replica pool, pgvector stores) | `connect_args["ssl"]`: a verifying `SSLContext` for `verify-ca` and `verify-full` (and for `require` with a CA), otherwise the mode string. asyncpg then refuses to fall back to plaintext. |
| Startup migrations (alembic) | The same `ssl` argument, so migrations do not bypass it. |
| psycopg2 (the sync engine the legacy pgvector store opens) | libpq `sslmode` and `sslrootcert`. Without a CA, the verify modes use `sslrootcert=system`. |
| Rust parse store (`PARSE_JOB_STORE_BACKEND=rust`, off by default) | SQLx `ssl_mode` and `ssl_root_cert`. `require` with a CA becomes `verify-ca`, to match libpq. Without a CA, SQLx trusts the bundled Mozilla roots. |

The default index database (`config.defaultIndex.postgres`) is reached through
the same shared engine, so it uses the same settings. If you point it at a
different host, that host's certificate must chain to the same CA bundle.

LlamaCloud reads the CA bundle when it opens its connection pool. After you
rotate the CA, restart the pods. During a rotation, put both the old and the
new CA in the bundle.

### The bundled Temporal

With `temporal.deploy: true`, Temporal's own services and its schema job
connect to the same PostgreSQL host. A parent chart cannot set its subchart's
values, so set these yourself. The chart refuses to render when Temporal's
connection would be weaker than `postgresql.sslMode`.

The Temporal server picks the mode like this:

- `tls.enabled: true` with `enableHostVerification: true` gives `verify-full`.
- `tls.enabled: true` alone gives `require`.
- `connectAttributes.sslmode` overrides both, for example `verify-ca`.

Without a `caFile`, the server trusts the system CA store. To use your own CA,
mount it into the server pods and the schema job, then point `caFile` at it:

```yaml
temporal-subchart:
  server:
    config:
      persistence:
        datastores:
          default:
            sql:
              tls:
                enabled: true
                enableHostVerification: true
                caFile: /etc/llamacloud/tls/postgresql/ca.crt
          visibility:
            sql:
              tls:
                enabled: true
                enableHostVerification: true
                caFile: /etc/llamacloud/tls/postgresql/ca.crt
    additionalVolumes:
      - name: postgresql-ca
        secret:
          secretName: postgresql-ca
    additionalVolumeMounts:
      - name: postgresql-ca
        mountPath: /etc/llamacloud/tls/postgresql
        readOnly: true
  # The schema job (temporal-sql-tool) runs from the admin-tools image.
  admintools:
    additionalVolumes:
      - name: postgresql-ca
        secret:
          secretName: postgresql-ca
    additionalVolumeMounts:
      - name: postgresql-ca
        mountPath: /etc/llamacloud/tls/postgresql
        readOnly: true
```

Helm replaces lists instead of merging them. If you already set
`additionalVolumes` or `additionalVolumeMounts`, add these entries to your
existing lists.

Even if you keep `postgresql.sslMode` empty, a server that enforces TLS needs
`tls.enabled: true` here, because Temporal's default is `sslmode=disable`.
Azure Database for PostgreSQL flexible server enforces TLS by default
(`require_secure_transport=ON`), so the bundled Temporal cannot connect to it
without this setting.

## Redis

```yaml
redis:
  scheme: rediss
  sslCheckHostname: true
  sslCaCert:
    secretName: redis-ca   # or configMapName
    key: ca.crt
```

| Value | API, usage, Python workers (redis-py) | Parse worker and MCP (Node) |
|---|---|---|
| `scheme: rediss` | TLS, CA verified against the system store, hostname **not** checked | TLS, CA and hostname verified |
| `sslCheckHostname: true` | Hostname checked (`REDIS_SSL_CHECK_HOSTNAME`) | No change; Node always checks the hostname |
| `sslCaCert` | Used as the trust store (`REDIS_SSL_CA_CERTS`) | Added to Node's roots (`NODE_EXTRA_CA_CERTS`) |

Hostname checks stay off by default in the Python components for two reasons:

- The Redis 5 client those components used before never made them, and
  existing installs depend on that.
- A Redis cluster that advertises its nodes by IP address fails the check on
  every node connection. Azure Managed Redis with the OSS cluster policy is one
  example. The Node parse worker works around this by pinning the TLS server
  name. redis-py has no equivalent, so leave `sslCheckHostname` off for such a
  cluster, or use a non-clustered or Enterprise-policy endpoint.

Both settings need `scheme: rediss`; the render fails otherwise. When you use
`redis.secret`, the chart cannot see the scheme, so make sure the secret
selects `rediss`.

## Temporal (external server)

```yaml
temporal:
  deploy: false
  host: temporal.example.internal
  port: 7233
  tls:
    enabled: true
    serverName: ""            # only if the certificate does not name `host`
    caCert:
      secretName: temporal-ca # or configMapName; empty uses the system store
      key: ca.crt
    clientCert:               # for mTLS; a kubernetes.io/tls Secret works as is
      secretName: temporal-client
      certKey: tls.crt
      keyKey: tls.key
```

This applies to every client of the Temporal frontend:

- The API, usage and Python workers (`TEMPORAL_TLS*`, read by the Python SDK).
- The parse worker (the same names, read by the TypeScript SDK).
- The search-attributes job, through the `temporal` CLI's own variables
  (`TEMPORAL_TLS_CA_PATH`, `TEMPORAL_TLS_CERT_PATH` and the others).

`temporal.tls` cannot be combined with `temporal.deploy: true`. The bundled
Temporal frontend serves plaintext gRPC, and its readiness probe uses plaintext
gRPC too.

The Temporal SDKs do their TLS in the Rust core with rustls, not OpenSSL. If
you need a FIPS-validated module for this connection, use a service mesh with
FIPS-validated mTLS.

## Checking it worked

PostgreSQL. Run this on the server; the LlamaCloud connections should show
`ssl = t`:

```sql
SELECT a.usename, a.application_name, s.ssl, s.version, s.cipher
FROM pg_stat_ssl s JOIN pg_stat_activity a USING (pid)
WHERE a.usename = '<llamacloud user>';
```

Also make the server reject plaintext: `rds.force_ssl=1` on RDS and Aurora,
`require_secure_transport=ON` on Azure, and SSL mode "Allow only SSL
connections" on Cloud SQL. A certificate problem shows up as a startup failure
in the API or worker logs (`certificate verify failed`), not as a silent
plaintext connection.

## Not covered here

- **MongoDB.** TLS comes from `mongodb.scheme: mongodb+srv` or a `mongodb_url`
  with `tls=true&tlsCAFile=...`. `mongodb.enabled: false` removes the
  connection entirely.
- **Object storage.** S3, GCS and Azure Blob are always HTTPS. The S3Proxy
  sidecar listens on plain HTTP inside the pod.
- **Traffic between LlamaCloud's own pods**, and to the bundled Temporal's
  frontend. This is plain HTTP or gRPC; use a service mesh for mTLS.
- **The Bifrost gateway's PostgreSQL connection.** It has its own
  `bifrost-subchart.postgresql.external.sslMode`.
