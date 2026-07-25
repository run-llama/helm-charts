# LlamaExtract

LlamaExtract is a component of LlamaCloud that enables you to extract structured data from unstructured documents. It is available as a web UI, a Python SDK, and a REST API.

For in-depth information about how LlamaExtract, please refer to our [public docs](https://developers.llamaindex.ai/python/cloud/llamaextract/getting_started).

## Setup

To enable LlamaExtract in your BYOC deployment, you'll need to do a few things:

- **Create a new LlamaExtract file-storage bucket in your cloud provider**
    - By default LlamaCloud stores LlamaExtract-specific files in a bucket named `llama-platform-extract-output`. Override it by setting `config.storageBuckets.extractOutput` to your desired bucket name in your `values.yaml`.
- **Configure LLM access**
    - LLM credentials are configured once, globally, under `config.llms.*` and are shared across all LlamaCloud services (there is no longer a per-service `backend.config` / `llamaParse.config` block). If you already configured LLM access to enable other features, LlamaExtract will reuse it.
    - LlamaExtract runs OpenAI `openai-gpt-4-1`-family models by default (the schema-generation model is set via `config.extraction.schemaGenerationModel`, default `openai-gpt-4-1-mini`), so provide OpenAI (or Azure OpenAI) credentials:
        - **OpenAI**: set the key inline at `config.llms.openAi.apiKey`, or reference an existing secret with `config.llms.openAi.secret`.
        - **Azure OpenAI**: reference your secret with `config.llms.azureOpenAi.secret` and declare your model deployments under `config.llms.azureOpenAi.deployments` (a list of `{model, deploymentName, apiKey, baseUrl, apiVersion}` entries).
