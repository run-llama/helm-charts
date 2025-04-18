# CHANGELOG

## [0.3.1] - 2025-04-17

- Improved Index feature stability
- Improved Sharepoint data source ingestion scalability and configuration options
- Added ability to configure concurrency settings
    - JobsWorker concurrency settings can be found at `.Values.jobsWorker.config`
    - Global LlamaParse worker throughput can be configured with `.Values.llamaParse.config.maxQueueConcurrency`
        - The higher this value, the more resources each LlamaParse worker will require
        - The default value is the same as previous versions. We will lower the default in future releases.
- New Metrics
    - Added Promtheus metrics for LlamaExtract
    - Added new metrics for LlamaParse
- Fixed HorizontalPodAutoscaler definition for frontend and backend services
- Fixed `.Values.llamaParse.config.extistingOpenAiApiKeySecretName` usage in LlamaParse deployment

## [0.3.0] - 2025-04-03

- LlamaExtract is now available in BYOC deployments!
    - For instructions on how to upgrade to this version and enable LlamaExtract, please refer to this [guide](docs/llamaextract.md)
    - For more information, please visit our [LlamaExtract docs](https://docs.cloud.llamaindex.ai/llamaextract/getting_started)

## [0.2.0] - 2025-04-02

- Add monitoring support for LlamaCloud
    - Added ServiceMonitor support
        - Metrics can be scraped for `backend`, `jobsService`, `jobsWorker`, `llamaParse`, and `llamaParseOcr` services
            - `.Values.<service>.metrics.serviceMonitor.enabled`
    - Added PrometheusRules support
        - PrometheusRules can be created for `backend` and `llamaParse` services
            - `.Values.<service>.metrics.rules.enabled`
    - Basic Grafana dashboards are available at [./charts/llamacloud/docs/monitoring](docs/monitoring)
    - Docs availabe at [./charts/llamacloud/docs/monitoring](docs/monitoring)
- Add `.Values.ingress.create` to control the creation of an ingress resource

## [0.1.58] - 2025-03-27

- Confluence improvements:
    - Fix bad caching for Permissions
    - Upsert should create v2 readers
    - Page restricted shouldn’t be indexes
- Reranker Configurability for Composite Retrieval
- Retries on requests to Cohere reranker

## [0.1.57] - 2025-03-25

- Added a new disposable composite retrieval endpoint.
- Introduced `AZURE_OPENAI_GPT_4O_DEPLOYMENT_NAME` (for playground) and `AZURE_OPENAI_GPT_4O_MINI_DEPLOYMENT_NAME` (for llamaparse) environment variables.
- Made Confluence requests per minute configurable via `DEFAULT_CONFLUENCE_REQUESTS_PER_MINUTE`, defaulting to 60.

## [0.1.56] - 2025-03-18

- Azure OpenAI Composite Retrieval support

## [0.1.55] - 2025-03-14

- Azure OpenAI environment variable fixes

## [0.1.54] - 2025-03-13

- Connector UI fixes

## [0.1.53] - 2025-03-12

- Parse logs cleanup
- Frontend fix for Copy Pipeline button

## [0.1.52] - 2025-03-11

- Minor connector bug fix

## [0.1.51] - 2025-03-11

- Connector bug fixes

## [0.1.50] - 2025-03-11

- Improved connector support for API data sources
- Parsing related fonts fixes

## [0.1.49] - 2025-03-08

- Minor bug fixes

## [0.1.48] - 2025-03-07

- Enable more API data sources
- Minor UI fixes

## [0.1.47] - 2025-03-06

- Scalability improvements for specific API based data-sources
- Bug fixes

## [0.1.41] - 2025-01-02

- Allow configurability of Mongo Connection limits via `MONGODB_CONNECTION_MAX_POOL_SIZE` environment variable.

## [0.1.40] - 2024-12-19

- One more frontend login bug fix

## [0.1.39] - 2024-12-18

- One more frontend login bug fix

## [0.1.38] - 2024-12-17

- Frontend bug fix for BYOC login

## [0.1.37] - 2024-12-10

- Add perform_setup flag for postgres data sinks
- Enable integrations management by defualt for helm chart deployments
