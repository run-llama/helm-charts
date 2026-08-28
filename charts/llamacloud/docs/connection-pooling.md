# PostgreSQL connection pooling

The chart does not deploy a connection pooler. It gives you the settings to size
LlamaCloud's own connection pools and to run safely behind a pooler you operate,
such as PgBouncer. This page covers when you need one, how to size pools without
one, and the one setting that is mandatory if you add one.

## Who holds connections

Up to five components run the backend image and each pod holds its own
PostgreSQL connection pool: `backend`, `jobsService`, `jobsWorker` (only when
`rabbitmq.enabled` is true), `usage`, and the Temporal workers under
`temporalWorkloads.workers`. Their rendered Deployment names are `llamacloud`,
`llamacloud-operator`, `llamacloud-worker`, `llamacloud-telemetry`, and the
worker names themselves.

A pool keeps `poolSize` connections open whether the pod is busy or idle, and
may open `poolMaxOverflow` more under load. The application defaults are 10
and 10. The deployment's worst case is therefore roughly:

```
sum over components of ( replicas x (poolSize + poolMaxOverflow) )
```

That total has to fit inside the server's `max_connections` alongside every
other client. If you deploy the bundled Temporal (`temporal.deploy: true`) and
point its `connectAddr` at the same PostgreSQL host, each of its services holds
up to 20 connections per datastore
(`temporal-subchart.server.config.persistence.datastores.*.sql.maxConns` in
`values.yaml`) — count them too.

## Sizing without a pooler

Set the pool values once and they reach every pooled component:

```yaml
postgresql:
  poolSize: 8
  poolMaxOverflow: 12
```

Both default to null, which keeps the application defaults; an upgrade never
resizes a running release. `poolMaxOverflow: 0` is meaningful: it hard-caps each
pod at `poolSize`. Full parameter reference: the `@param` annotations on the
`postgresql` block in `values.yaml`.

The values are delivered by ConfigMap, so changing them on a running release
takes effect when the affected pods next restart, not at `helm upgrade`.

To see what is actually held open, run this on your PostgreSQL server — with no
database filter, because `max_connections` is server-wide:

```sql
SELECT datname, usename, client_addr, state, count(*)
FROM pg_stat_activity
GROUP BY 1, 2, 3, 4 ORDER BY 5 DESC;
```

Idle rows held around the clock are pool floors, not leaks. Take the reading
during a rolling upgrade rather than at rest: old and new pods hold their pools
simultaneously, and that overlap is your real peak.

## Running behind a transaction-mode pooler

A pooler multiplexes many application connections onto a small set of server
connections; in transaction mode it reassigns a server connection after every
transaction. If pool sizing cannot fit your `max_connections` ceiling, put one
in front. One setting is mandatory:

```yaml
postgresql:
  host: <your pooler service>
  disablePreparedStatements: true
```

Without it the first sustained load fails with `DuplicatePreparedStatementError`:
the database driver uses server-side prepared statements whose names are unique
only within one process, and a transaction-mode pooler reuses server connections
across clients. With the flag on, the driver issues unnamed statements — the
pooler-safe path — at the cost of no statement reuse (expect somewhat higher
per-query latency; it is a correctness setting, not a tuning knob).

PgBouncer specifics that matter:

- `pool_mode = transaction` is the mode this flag exists for. Session mode also
  works but holds one server connection per client for its lifetime, which gives
  up most of the multiplexing.
- Add `ignore_startup_parameters = extra_float_digits,options,application_name`;
  the driver sends these at session start and transaction pooling cannot honour
  per-session state.
- Database schema migrations run inside the `backend` pods at startup, so they
  go through the pooler like everything else. No separate handling is needed.

Verify after cutover, in order of strength:

- `SHOW POOLS;` and `SHOW SERVERS;` on the PgBouncer admin console show the
  server pool multiplexing and any client wait time.
- Application logs should show no `DuplicatePreparedStatement` or
  `InvalidSQLStatementName` errors.
- `SELECT count(*) FROM pg_prepared_statements;` — run it **through the
  pooler**, several times, so it samples the pooled server sessions; it should
  read 0. (Run directly against the server it is always 0, because the view is
  session-scoped — that reading proves nothing.)

## What to monitor

- Server side: total `pg_stat_activity` count against `max_connections`
  (alerting above ~70% sustained). This is the only view that sees every
  consumer, including Temporal and your pooler's own server pool.
- Application side: the per-pod Prometheus gauges on `/metrics`
  (`llamacloud_pg_pool_size`, `llamacloud_pg_pool_checked_out`,
  `llamacloud_pg_pool_checked_in`, `llamacloud_pg_pool_overflow`) cover each
  pod's own pool. Treat them as a per-pod floor rather than an exact total.
- Pooler side: your pooler's own stats. Watch client wait time — sustained
  waiting means the server pool is undersized, and clients that time out
  reconnect, which adds load exactly when you least want it.

## Documentation

- [Chart README](../README.md)
- Parameter reference: `@param` annotations in [values.yaml](../values.yaml)
