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

Here is a very basic example of how to deploy the kube-prometheus-stack Helm chart using the `kube-prometheus-stack-example-values.yaml` file located in this directory.

```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack -f kube-prometheus-stack-example-values.yaml
```

For more information about the kube-prometheus-stack Helm chart, please refer to the [kube-prometheus-stack README](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack).

## Metrics

The following services expose metrics:

- `backend`
- `jobsService`
- `jobsWorker`
- `llamaParse`
- `llamaParseOcr`

Metrics are scraped at the `/metrics` endpoint of each service.

To enable metrics for a service, you need to set the `metrics.enabled` parameter to `true` in the service's values.yaml file.

```yaml
# example
backend:
  metrics:
    enabled: true
```

### ServiceMonitors

If using the Prometheus Operator, you can create a ServiceMontior to scrape the metrics from the service. This can be done by creating a `ServiceMonitor` object.

First, make sure you enable metrics for the service you want to monitor, e.g. backend (aka llamacloud).

```yaml
# example
backend:
  metrics:
    enabled: true
```

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  # 👇 Could be anything but by convention just give it the name of the service you want to monitor.
  name: llamacloud
  # 👇 Namespace where the ServiceMonitor object itself lives. For kube-prometheus-stack this is usually 
  # the same namespace where you installed the chart (e.g. "monitoring").
  namespace: <kube-prometheus-stack-namespace>
  labels:
    # 👇 MUST match kube-prometheus-stack's .Values.prometheus.prometheusSpec.serviceMonitorSelector
    # Typically this is the same namespace as above
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - <namespace-where-llamacloud-service-lives>
  selector:
    matchLabels:
      app.kubernetes.io/instance: llamacloud
      app.kubernetes.io/name: llamacloud
      app.kubernetes.io/managed-by: Helm
  endpoints:
    - port: http          # matches .spec.ports[].name in your Service
      path: /metrics      # change if your app exposes metrics elsewhere
      interval: 30s
      scrapeTimeout: 10s
```

Refer to the sample `ServiceMonitor` objects which you can `kubectl apply`:
- [LlamaCloud Service Monitor](./llamacloud-service-monitor.yaml)
- [LlamaCloud Parse Service Monitor](./llamacloud-parse-service-monitor.yaml)

The main services to monitor are:
- `backend`
- `jobsService`
- `jobsWorker`
- `llamaParse`
- `llamaParseOcr`

You can simply copy-paste the above samples to create monitors these other services. Only the names change.

## Dashboards

We have a couple of dashboards that are useful for monitoring LlamaCloud. These dashboards are starting points for monitoring your services. For production enviroments, we recommend extending these dashboards to better suit your needs.

- [LlamaCloud Dashboard](./llamacloud-dashboard.json)
- [LlamaParse Dashboard](./llamaparse-dashboard.json)

The above json files can be imported into a Grafana instance. Feel free to refer to the [Grafana documentation](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/import-dashboards/) for more information.

## Prometheus Alerts

Alerting is a crucial part of monitoring your LlamaCloud deployment, especially in production environments. These helm charts support the ability to directly define Prometheus rules in the `values.yaml` file.

```yaml
# example
backend:
  metrics:
    enabled: true
    rules:
      enabled: true
      spec:
        - alert: "Backend is down"
          expr: absent(up{job='backend'})
          for: 1m
          labels:
            severity: "critical"
```
