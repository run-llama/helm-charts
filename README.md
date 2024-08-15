# LlamaIndex Helm Charts

LlamaIndex Helm Charts is a collection of charts for deploying [llamaindex.ai](https://llamaindex.ai) projects on Kubernetes.

## Important Links

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

## License

Copyright © 2024 LlamaIndex Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
