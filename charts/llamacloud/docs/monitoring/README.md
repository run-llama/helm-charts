# LlamaCloud Monitoring

LlamaCloud services expose metrics, which are collected by [Prometheus](https://prometheus.io) and visualized in [Grafana](https://grafana.com).

## Prerequisites

To monitor your LlamaCloud deployment, you'll need:

- [Prometheus](https://prometheus.io) - For metrics collection and storage
- [Grafana](https://grafana.com) - For metrics visualization
- [AlertManager](https://prometheus.io/docs/alerting/latest/alertmanager/) - For alert management

These services can be deployed using the [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) Helm chart.

The kube-prometheus-stack Helm chart provides a complete monitoring solution that includes:

- Prometheus server for metrics collection
- Grafana for visualization with pre-configured dashboards
- AlertManager for handling alerts
- Node exporter for hardware and OS metrics
- kube-state-metrics for Kubernetes object metrics
- Prometheus Operator for managing Prometheus instances

### Option A: Bundled subchart (recommended for greenfield BYOC)

This chart ships `kube-prometheus-stack` as an optional dependency. To install Prometheus + Grafana + AlertManager + Prometheus Operator alongside LlamaCloud, set in your values:

```yaml
monitoring:
  deploy: true
  serviceMonitors:
    enabled: true

# Required on a fresh cluster with no pre-existing Prometheus Operator CRDs.
# Leave false (default) if the CRDs are already installed.
kube-prometheus-stack-subchart:
  crds:
    enabled: true
```

`monitoring.serviceMonitors.enabled: true` makes this chart render a `ServiceMonitor` for every deployed component that exposes `/metrics`:

- `backend` (always)
- `jobsService` (always)
- `jobsWorker` (always)
- `llamaParse` (always)
- `usage` (always)
- `llamaParseOcr` (only when `config.parseOcr.enabled: true` — default `true`)

If `bifrost.deploy` is also `true`, a separate `ServiceMonitor` for the Bifrost gateway is rendered too (targets the Bifrost Service's `/metrics` endpoint on port `http`/8080).

The `llamaParseLayoutDetectionApi` / `llamaParseLayoutDetectionApiV3` and `frontend` components do not expose Prometheus metrics today and are intentionally excluded; same for the Temporal workers.

Override subchart settings under the `kube-prometheus-stack-subchart` key — see the [upstream README](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) for the full set of supported values.

### Option B: Bring your own Prometheus Operator

If your cluster already runs a Prometheus Operator, leave `monitoring.deploy: false` and just enable the ServiceMonitors:

```yaml
monitoring:
  deploy: false
  serviceMonitors:
    enabled: true
    # Must match your Prometheus instance's serviceMonitorSelector.
    release: kube-prometheus-stack
```

### Option C: Manual install (standalone)

Install kube-prometheus-stack as a separate release using the example values in this directory:

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -f kube-prometheus-example-values.yaml
```

You can then either enable `monitoring.serviceMonitors.enabled` to have this chart render the ServiceMonitor objects, or manually apply the sample YAMLs shown below.

For more information about the kube-prometheus-stack Helm chart, please refer to the [kube-prometheus-stack README](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

## Metrics

The following services expose Prometheus-format metrics at their `/metrics` endpoint:

- `backend`
- `jobsService`
- `jobsWorker`
- `llamaParse`
- `usage`
- `llamaParseOcr` (only when `config.parseOcr.enabled: true` — default `true`)
- the Bifrost gateway, when `bifrost.deploy: true`

Metrics collection is controlled by the single chart-wide `monitoring.serviceMonitors.enabled` toggle described in Options A/B above — enabling it renders a `ServiceMonitor` for every deployed component automatically, so you don't need to hand-write one per service.

### Manual ServiceMonitors (Option C only)

If you're running kube-prometheus-stack as a standalone release and aren't using `monitoring.serviceMonitors.enabled`, apply the sample `ServiceMonitor` objects in this directory instead:

- [LlamaCloud Service Monitor](./llamacloud-service-monitor.yaml)
- [LlamaCloud Parse Service Monitor](./llamacloud-parse-service-monitor.yaml)

Update the `namespace`, `namespaceSelector`, and `release` label to match your environment. The main services to monitor are:
- `backend`
- `jobsService`
- `jobsWorker`
- `llamaParse`
- `llamaParseOcr`
- `usage`

You can copy-paste the above samples to create monitors for the other services — only the names change. Bifrost is templated separately by the chart (see `templates/monitoring/servicemonitor-bifrost.yaml`) and isn't included as a standalone sample here.

## Dashboards

We have a couple of dashboards that are useful for monitoring LlamaCloud. These dashboards are starting points for monitoring your services. For production enviroments, we recommend extending these dashboards to better suit your needs.

- [LlamaCloud Dashboard](./llamacloud-dashboard.json)
- [LlamaCloud Indexing Dashboard](./llamacloud-indexing-dashboard.json)
- [LlamaParse Dashboard](./llamaparse-dashboard.json)

The above json files can be imported into a Grafana instance. Feel free to refer to the [Grafana documentation](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/) for more information.
