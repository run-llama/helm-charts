# LlamaIndex Helm Charts

LlamaIndex Helm Charts is a collection of charts for deploying [llamaindex.ai](https://llamaindex.ai) projects on Kubernetes.

## Important Links

- [Self-Hosting Installation Guide](https://docs.cloud.llamaindex.ai/self_hosting/installation)
- [Contact Information](https://www.llamaindex.ai/contact)
- [Community Discord](https://discord.com/invite/eN6D2HQ4aX)

## Usage

[Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

## Adding the helm repository:

```sh
# Add helm repository
helm repo add llamaindex https://run-llama.github.io/helm-charts

# (Optional) Update your helm local cache
helm repo update

# Find available charts in the llamaindex repo
helm search repo llamaindex
```

## Validate

There is a set of automated tests [here](https://github.com/run-llama/helm-charts/tree/main/charts/llamacloud/deployment_tests) that can be run to validate parts of the functionality of your deployment. It is recommended to run these tests after the initial installation of the helm chart and after every upgrade to the helm chart.

## Runbooks
A collection of runbooks for common scenarios can be found in the [runbooks directory](./runbooks/) of this repo.

## License

Copyright © 2024 LlamaIndex Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
