# CHANGELOG

## [0.4.6] - 2025-07-21

### Deprecation Warning
- `.Values.global.config.mongodb.external.url` is now deprecated. Please use the available fields in `.Values.global.config.mongodb.external.*` to construct your MongoDB connection url.

### Infrastructure Changes
- This version introduces a new field in the values.yaml — `.Values.global.config.mongodb.external.scheme` — that gives users flexibility in which url scheme to configure.
    - Default: `mongodb`
    - Tip: To configure Azure CosmosDB, you can set this field to `mongodb+srv`
    - For more information, please refer to [the docs](https://docs.cloud.llamaindex.ai/self_hosting/configuration/dependencies#external-dependency-configuration-recommended)

### Jobs Worker
- **New BYOC Configuration Flags**: Added support for index controls
    - `defaultTransformDocumentTimeoutSeconds`: Default timeout for document transformation jobs (default: 240 seconds)
    - `transformEmbeddingCharLimit`: Character limit for transform embedding operations (default: 11,520,000 characters)
    - These flags are now configurable via Helm chart values and documented in self-hosting guides

## [0.4.5] - 2025-07-17

### LlamaParse
- **Enhanced Table Extraction**: `outline_table_extraction=True` now supports:
    - Table extraction from DOCX documents directly, even when not outlined
    - Table extraction from XLSX→PDF conversions without outlines
    - Better handling of side-by-side tables (recognized as separate tables instead of merged)
- **Improved Spatial Text Output**: Enhanced spatial text processing for better document understanding
- **Agent Parsing Improvements**:
    - `parse_with_agent_sonnet_4`: Better flow chart handling and added Bedrock support
    - `parse_with_agent_gemini_flash_2`: General performance improvements
- **Cross-Page Table Merging**: `merge_table_across_page=True` allows tables that continue across pages to be properly merged (works only when tables are extracted correctly)

### LlamaExtract
- **[Beta]** **Extraction Confidence Scores**: [Now available](https://docs.cloud.llamaindex.ai/llamaextract/features/options#advanced-optionsextensions) in Multimodal/Premium modes for short documents. Feature provides confidence metrics for extracted content.
    - Available in advanced options
    - Note: Currently in beta with slower performance; improvements incoming
- **[New]** **Page Range Support**: Extraction can now be limited to specific page ranges using formats like `1-8,11,13`

### LlamaCloud Platform
- **Improved SharePoint Processing**: V2 Data Source created by default for more robust and error-resistant SharePoint processing
- **[Retrieval]** **Unlimited File Retrieval**: Removed the 500 files limit for `files_via_metadata` retrieval - now supports limitless file operations
- **Enhanced Permissioning Model**: Internal table dependency changes for improved permission management (no external visibility impact)
    - Supports Create + Remove user permissions with Project/Org and Viewer/Admin scopes

## [0.4.4] - 2025-07-02

### LlamaParse
- Fix LlamaParse header/footer outputs
### LlamaCloud Platform
- [Index] Data-source security and reliability enhancements
- [Index] Improvements to job worker stability when ingesting large data-sources
- [Retrieval] Fix `files_via_content` retrieval for specific file types (e.g. `.txt` or `.md`)
### Helpful Notices
- The Azure OpenAI validations for the Admin UI are based on the new set of configurable enviornment variables.
    - Check out the [docs](https://docs.cloud.llamaindex.ai/self_hosting/configuration/azure-openai#connecting-to-azure-openai) for more information.
    - We will be deprecating the old set of [environment variables](https://docs.cloud.llamaindex.ai/self_hosting/configuration/azure-openai#helm-chart-configuration) in the near future.

## [0.4.3] - 2025-06-18

### LlamaParse
  - [Beta]: Layout Extraction API is available now for self-hosted LlamaParse!
    - This is run as a Kubernetes Deployment in your cluster. To enable this, you can set `.Values.llamaParseLayoutExtractionApi.enabled` to `true`.
    - Please refer to the [docs](https://docs.cloud.llamaindex.ai/llamaparse/features/layout_extraction) for more information
  - High-Res OCR is now available in the UI and API.
  - [Breaking Change]: The default LLM used in `parse_page_with_llm` is now `gpt-4.1`.
### LlamaCloud Platform
  - [Retrievals]: Page Figure Retrieval is now available. For more information, please refer to the [docs](https://docs.cloud.llamaindex.ai/llamacloud/retrieval/images#retrieving-page-figures)
  - [Platform]: Added RBAC capability for adding organization and project scoped roles
  - [Platform]: General usability improvements
### Infrastructure Changes
  - As mentioned above, we have updated the `values.yaml` to include the new `.Values.llamaParseLayoutExtractionApi` configuration.
  - Please reach out to support if you have any questions!

## [0.4.2] - 2025-06-04

- New `Admin` UI.
    - In an effort to make it easier to manage your LlamaCloud deployment, we've added a new `Admin` tab on the `Settings` page.
    - To start, we've added the ability to view your deployment's current LLM configurations and deployment feature availability matrices.
    - Note: The current implementation assumes that OpenAi and Azure OpenAi configs are the same in `.Values.backend.config.openAi*` and `.Values.llamaParse.config.openAi*`.
- Chat Playground
    - Added support for OpenAI 4.1, 4.1-nano, and 4.1-mini models
- LlamaParse
    - Added support for Google Vertex AI
        - `.Values.llamaParse.config.googleVertexAi.*`
    - General product improvements
- LlamaExtract
    - General product improvements
- Resolve a handful of package vulnerabilities

## [0.4.1] - 2025-05-28

- Minor UI bug fixes
- LlamaParse
    - Support for Anthropic Sonnet 4.0
    - General product improvements

## [0.4.0] - 2025-05-23

- LlamaParse
    - **New Parse UI v2 is now available!** We've make some updates to the ~look~ of our parse playground UI.
    - General improvements to parsing ux and performance
- LlamaExtract
    - General improvements to extraction performance
- Project level RBAC: You can now select assign member roles on a per project basis.

## [0.3.5] - 2025-05-16

- **Deprecation Warning**: In the near future, we will be deprecating the following in the `values.yaml` file:
    - `.Values.llamaParse.config.openAiApiKey.*`, `.Values.llamaParse.config.existingOpenAiApiKeySecretName`
    - `.Values.llamaParse.azureOpenAi.*`
    - `.Values.llamaParse.config.anthropicApiKey.*`, `.Values.llamaParse.config.existingAnthropicApiKeySecretName`
    - `.Values.llamaParse.config.geminiApiKey.*`, `.Values.llamaParse.config.existingGeminiApiKeySecretName`
    - `.Values.llamaParse.config.awsBedrock.*existingSecret*`
    - LLM configurations will be managed by the `jobsService` and configured at `.Values.llms.*`
- LlamaParse
    - Added support for specifying model version for AWS Bedrock
        - `.Values.llamaParse.config.awsBedrock.sonnet3_5ModelVersionName`
        - `.Values.llamaParse.config.awsBedrock.sonnet3_7ModelVersionName`
    - Added support for configuring multiple independency Azure OpenAI deployments. Please refer to the [docs](https://docs.cloud.llamaindex.ai/self_hosting/installation) for more information.
    - Better support of read-only (password-protected) documents
    - Improved table support for Anthropic Sonnet 3.7
- LlamaExtract
    - Premium mode is available for extraction from documents with complex tables/headers.
    - Schemas with large number of fields > 100 is supported.
    - **Note**: As mentioned previously, `.Values.backend.config.llamaExtractMultimodalModel` can be used to specify which multimodal model LlamaParse will use. LlamaExtract will pass the multimodal model name to Llamaparse's `parse_with_agent` (formerly Premium Mode).
- Fix index status resolution when using scheduled syncs
- Fix errors when processing screenshots during parsing
- Various UI bug fixes
- `autoscaling` is now enabled by default for `backend`, `jobsService`, `jobsWorker`, and `llamaParse` services

## [0.3.4] - 2025-05-13

- LlamaParse
    - Improved support for Japanese character encoding
    - Improved webhook error handling
    - Added Prometheus metrics (`llamaparse_ocr_done_total`, `llamaparse_ocr_pixels_total`, `llamaparse_pages_parsed_total`, `llamaparse_markdown_length_total`)
    - Improved spreadsheet parsing capabilities
- LlamaExtract
    - Citations! You can learn more about it in our docs [here](https://docs.cloud.llamaindex.ai/llamaextract/features/options)
    - New UI for extract JSON builer
    - New `invalidate_cache` option in Advanced Settings to purge the cache
    - New `.Values.backend.config.llamaExtractMultimodalModel` to configure which multimodal model to use (i.e. `gemini-2.0-flash-001`, `openai-gpt-4-1`, etc.)
- Improved error handling for high volume file ingestion syncs
- Improved Index status resolution
- New Integration UI for data source, data sink, and embedding model configuration
- (Beta): Batch mode API

## [0.3.3] - 2025-05-02

- LlamaParse:
    - Improved parsing support for CJK encoding across various file types
    - Added support for autoModeConfigurationJSON
    - Support for GPT 4.1
- Added default rate limits to file upload API
- Stability improvements for data ingestion jobs
- Pipeline status resolution improvements
- Fixes for API usage of Chat API
- Include all job error details on UI by default

## [0.3.2] - 2025-04-21

- Improved LlamaExtract product capabilities
- LlamaCloud Index
    - Improvements to Confluence Data Source
    - Postgres Data Sink now supports HNSW by default

## [0.3.1] - 2025-04-17

- Improved Index feature stability
- Improved Sharepoint data source ingestion scalability and configuration options
- Improved resource utilization for entire LlamaCloud deployment
- Fixed regression in sign-in flow when port-forwarding
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
