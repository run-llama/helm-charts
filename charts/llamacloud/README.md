# LlamaCloud Helm Chart

The Helm Chart for installing LlamaCloud in Kubernetes. Deplying Self-Hosted LlamaCloud on your own infrastructure enables you to build data-intensive AI applications in your own [virtual](https://aws.amazon.com/vpc/) [private](https://azure.microsoft.com/en-us/free/hybrid-cloud/search/) [cloud](https://cloud.google.com/vpc?hl=en) while meeting your data privacy and compliance requirements.

## Quick Start

```sh
# Add the LlamaIndex Helm Chart Repository
helm repo add llamaindex https://run-llama.github.io/helm-charts

# (Optional) Update repo information
helm repo update

# Install the basic version of the chart
helm install my-llamacloud-release llamaindex/llamacloud
```

## Prerequisites

- Kubernetes `>=1.28.0`
    - We are largely aligned with the versions supported in [EKS](https://endoflife.date/amazon-eks), [AKS](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions?tabs=azure-cli), and [GKE](https://cloud.google.com/kubernetes-engine/versioning).
- Helm v3.7.0+ [(Docs)](https://helm.sh/docs/)
- LlamaCloud Images - [(Docker Hub Repository)](https://hub.docker.com/u/llamaindex)
    - By default, this chart uses public images for all LlamaCloud specific services and its dependencies.
- LlamaCloud License Key

## Hardware Requirements

- **Linux Instances running x86 cpus**
    - As of August 12th, 2024, we build only linux/amd64 images. arm64 is not supported at this moment.
- **Ubuntu >=22.04**
- **>=12 vCPUs**
- **>=80Gbi Memory**

Warning #1: LlamaParse, LlamaIndex's proprietry document parser, can be a very resource intensive deployment to run, especially if you want to maximize performance.
Warning #2:The base cpu/memory requirements may increase if you are running containerized deployments of LlamaCloud dependencies. (More information in the following section)

## Configuring Dependencies

The LlamaCloud charts provide easy deployment options for the 3rd party dependencies that the platform requires. Each of the following dependencies can be enabled directly through the `values.yaml` file, or alternatively, you can supply your own `Secret` objects to provide the LlamaCloud deployments with the necessar credentials to those services.

- PostgreSQL (Helm Chart Dependency)
    - [Bitnami Helm Chart](https://github.com/bitnami/charts/blob/main/bitnami/postgresql/README.md)
- MongoDB (Helm Chart Dependency)
    - [Bitnami Helm Chart](https://github.com/bitnami/charts/blob/main/bitnami/mongodb/README.md)
- RabbitMQ (Helm Chart Dependency)
    - [Bitnami Helm Chart](https://github.com/bitnami/charts/blob/main/bitnami/rabbitmq/README.md)
- Redis (Helm Chart Dependency)
    - [Bitnami Helm Chart](https://github.com/bitnami/charts/blob/main/bitnami/redis/README.md)
- S3Proxy (Templates)
    - If enabled, we are deploying a containerized version of gaul's [s3proxy project](https://github.com/gaul/s3proxy).
    - If you wish to use a non-aws file store such as Azure Blob Storage or GCP Filestore, enable and configure the s3proxy deployment. For more information, please feel free refer to our docs!

## Documentation

For more information about using this chart, feel free to visit the [Official LlamaCloud Documentation](https://llamaindex.ai).

## Parameters

### Global Configuration

| Name                                                   | Description                                                   | Value                      |
| ------------------------------------------------------ | ------------------------------------------------------------- | -------------------------- |
| `global.cloudProvider`                                 | Cloud provider where the chart is deployed in.                | `aws`                      |
| `global.imagePullSecrets`                              | Global Docker registry secret names as an array               | `[]`                       |
| `global.storageClass`                                  | Storage class to use for dynamic provisioning                 | `""`                       |
| `global.config.licenseKey`                             | License key for all components                                | `<input-license-key-here>` |
| `global.config.existingLicenseKeySecret`               | Name of the secret to use for the license key                 | `""`                       |
| `global.config.awsAccessKeyId`                         | AWS Access Key ID                                             | `""`                       |
| `global.config.awsSecretAccessKey`                     | AWS Secret Access Key                                         | `""`                       |
| `global.config.existingAwsSecretName`                  | Name of the existing secret to use for AWS credentials        | `""`                       |
| `global.config.postgresql.external.enabled`            | Use an external PostgreSQL database                           | `false`                    |
| `global.config.postgresql.external.host`               | PostgreSQL host                                               | `""`                       |
| `global.config.postgresql.external.port`               | PostgreSQL port                                               | `5432`                     |
| `global.config.postgresql.external.database`           | PostgreSQL database                                           | `""`                       |
| `global.config.postgresql.external.username`           | PostgreSQL user                                               | `""`                       |
| `global.config.postgresql.external.password`           | PostgreSQL password                                           | `""`                       |
| `global.config.postgresql.external.existingSecretName` | Name of the existing secret to use for PostgreSQL credentials | `""`                       |
| `global.config.mongodb.external.enabled`               | Use an external MongoDB database                              | `false`                    |
| `global.config.mongodb.external.url`                   | MongoDB connection URL                                        | `""`                       |
| `global.config.mongodb.external.host`                  | MongoDB host                                                  | `""`                       |
| `global.config.mongodb.external.port`                  | MongoDB port                                                  | `27017`                    |
| `global.config.mongodb.external.username`              | MongoDB user                                                  | `""`                       |
| `global.config.mongodb.external.password`              | MongoDB password                                              | `""`                       |
| `global.config.mongodb.external.existingSecretName`    | Name of the existing secret to use for MongoDB credentials    | `""`                       |
| `global.config.rabbitmq.external.enabled`              | Use an external RabbitMQ instance                             | `false`                    |
| `global.config.rabbitmq.external.scheme`               | RabbitMQ scheme                                               | `amqp`                     |
| `global.config.rabbitmq.external.host`                 | RabbitMQ host                                                 | `""`                       |
| `global.config.rabbitmq.external.port`                 | RabbitMQ port                                                 | `5672`                     |
| `global.config.rabbitmq.external.username`             | RabbitMQ user                                                 | `""`                       |
| `global.config.rabbitmq.external.password`             | RabbitMQ password                                             | `""`                       |
| `global.config.rabbitmq.external.existingSecretName`   | Name of the existing secret to use for RabbitMQ credentials   | `""`                       |
| `global.config.redis.external.enabled`                 | Use an external Redis instance                                | `false`                    |
| `global.config.redis.external.host`                    | Redis host                                                    | `""`                       |
| `global.config.redis.external.port`                    | Redis port                                                    | `6379`                     |
| `global.config.redis.external.existingSecretName`      | Name of the existing secret to use for Redis credentials      | `""`                       |

### Overrides and Common Configuration

| Name                | Description                                    | Value |
| ------------------- | ---------------------------------------------- | ----- |
| `nameOverride`      | String to fully override llamacloud.name       | `""`  |
| `fullnameOverride`  | String to fully override llamaecloud.fullname  | `""`  |
| `namespaceOverride` | String to fully override llamaecloud.namespace | `""`  |
| `commonLabels`      | Labels to add to all deployed objects          | `{}`  |
| `commonAnnotations` | Annotations to add to all deployed objects     | `{}`  |

### Frontend Configuration

| Name                                                  | Description                                                                                                       | Value                            |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------------------- |
| `frontend.name`                                       | Name suffix of the Frontend related resources                                                                     | `frontend`                       |
| `frontend.replicas`                                   | Number of replicas of Frontend Deployment                                                                         | `1`                              |
| `frontend.image.registry`                             | Frontend Image registry                                                                                           | `docker.io`                      |
| `frontend.image.repository`                           | Frontend Image repository                                                                                         | `llamaindex/llamacloud-frontend` |
| `frontend.image.tag`                                  | Frontend Image tag                                                                                                | `0.1.39`                         |
| `frontend.image.pullPolicy`                           | Frontend Image pull policy                                                                                        | `IfNotPresent`                   |
| `frontend.service.type`                               | Frontend Service type                                                                                             | `ClusterIP`                      |
| `frontend.service.port`                               | Frontend Service port                                                                                             | `3000`                           |
| `frontend.serviceAccount.create`                      | Whether or not to create a new service account                                                                    | `true`                           |
| `frontend.serviceAccount.name`                        | Name of the service account                                                                                       | `""`                             |
| `frontend.serviceAccount.labels`                      | Labels to add to the service account                                                                              | `{}`                             |
| `frontend.serviceAccount.annotations`                 | Annotations to add to the service account                                                                         | `{}`                             |
| `frontend.labels`                                     | Labels added to the Frontend Deployment.                                                                          | `{}`                             |
| `frontend.annotations`                                | Annotations added to the Frontend Deployment.                                                                     | `{}`                             |
| `frontend.containerPort`                              | Port to expose on the Frontend container                                                                          | `3000`                           |
| `frontend.extraEnvVariables`                          | Extra environment variables to add to Frontend pods                                                               | `[]`                             |
| `frontend.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                             |
| `frontend.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                                            | `{}`                             |
| `frontend.podSecurityContext`                         | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                             |
| `frontend.securityContext`                            | Security context for the container                                                                                | `{}`                             |
| `frontend.resources`                                  | Set container requests and limits for different resources like CPU or memory (essential for production workloads) | `{}`                             |
| `frontend.livenessProbe.httpGet.path`                 | Path to hit for the liveness probe                                                                                | `/api/healthz`                   |
| `frontend.livenessProbe.httpGet.port`                 | Port to hit for the liveness probe                                                                                | `http`                           |
| `frontend.readinessProbe.httpGet.path`                | Path to hit for the liveness probe                                                                                | `/api/healthz`                   |
| `frontend.readinessProbe.httpGet.port`                | Port to hit for the liveness probe                                                                                | `http`                           |
| `frontend.autoscaling.enabled`                        | Enable autoscaling for the Frontend Deployment                                                                    | `false`                          |
| `frontend.autoscaling.minReplicas`                    | Minimum number of replicas for the Frontend Deployment                                                            | `1`                              |
| `frontend.autoscaling.maxReplicas`                    | Maximum number of replicas for the Frontend Deployment                                                            | `4`                              |
| `frontend.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the Frontend Deployment                                                     | `80`                             |
| `frontend.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod                                            | `[]`                             |
| `frontend.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod                                       | `[]`                             |
| `frontend.nodeSelector`                               | Node labels for pod assignment                                                                                    | `{}`                             |
| `frontend.tolerations`                                | Taints to tolerate on node assignment:                                                                            | `[]`                             |
| `frontend.affinity`                                   | Pod scheduling constraints                                                                                        | `{}`                             |

### Backend Configuration

| Name                                                 | Description                                                                                                       | Value                           |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `backend.name`                                       | Name suffix of the Backend related resources                                                                      | `backend`                       |
| `backend.config.logLevel`                            | Log level for the backend                                                                                         | `info`                          |
| `backend.config.openAiApiKey`                        | (Required) OpenAI API key                                                                                         | `""`                            |
| `backend.config.existingOpenAiApiKeySecret`          | Name of the existing secret to use for the OpenAI API key                                                         | `""`                            |
| `backend.config.azureOpenAi.enabled`                 | Enable Azure OpenAI for backend                                                                                   | `false`                         |
| `backend.config.azureOpenAi.existingSecret`          | Name of the existing secret to use for the Azure OpenAI API key                                                   | `""`                            |
| `backend.config.azureOpenAi.key`                     | Azure OpenAI API key                                                                                              | `""`                            |
| `backend.config.azureOpenAi.endpoint`                | Azure OpenAI endpoint                                                                                             | `""`                            |
| `backend.config.azureOpenAi.deploymentName`          | Azure OpenAI deployment                                                                                           | `""`                            |
| `backend.config.azureOpenAi.apiVersion`              | Azure OpenAI API version                                                                                          | `""`                            |
| `backend.config.oidc.existingSecretName`             | Name of the existing secret to use for OIDC configuration                                                         | `""`                            |
| `backend.config.oidc.discoveryUrl`                   | OIDC discovery URL                                                                                                | `""`                            |
| `backend.config.oidc.clientId`                       | OIDC client ID                                                                                                    | `""`                            |
| `backend.config.oidc.clientSecret`                   | OIDC client secret                                                                                                | `""`                            |
| `backend.config.qdrant.enabled`                      | Enable QDRANT Data-Sink for backend                                                                               | `false`                         |
| `backend.config.qdrant.existingSecret`               | Name of the existing secret to use for the QDRANT Data-Sink                                                       | `""`                            |
| `backend.config.qdrant.url`                          | QDRANT Data-Sink host                                                                                             | `""`                            |
| `backend.config.qdrant.apiKey`                       | QDRANT Data-Sink API key                                                                                          | `""`                            |
| `backend.replicas`                                   | Number of replicas of Backend Deployment                                                                          | `1`                             |
| `backend.image.registry`                             | Backend Image registry                                                                                            | `docker.io`                     |
| `backend.image.repository`                           | Backend Image repository                                                                                          | `llamaindex/llamacloud-backend` |
| `backend.image.tag`                                  | Backend Image tag                                                                                                 | `0.1.39`                        |
| `backend.image.pullPolicy`                           | Backend Image pull policy                                                                                         | `IfNotPresent`                  |
| `backend.service.type`                               | Backend Service type                                                                                              | `ClusterIP`                     |
| `backend.service.port`                               | Backend Service port                                                                                              | `8000`                          |
| `backend.serviceAccount.create`                      | Whether or not to create a new service account                                                                    | `true`                          |
| `backend.serviceAccount.name`                        | Name of the service account                                                                                       | `""`                            |
| `backend.serviceAccount.labels`                      | Labels to add to the service account                                                                              | `{}`                            |
| `backend.serviceAccount.annotations`                 | Annotations to add to the service account                                                                         | `{}`                            |
| `backend.labels`                                     | Labels added to the Backend Deployment.                                                                           | `{}`                            |
| `backend.annotations`                                | Annotations added to the Backend Deployment.                                                                      | `{}`                            |
| `backend.containerPort`                              | Port to expose on the Backend container                                                                           | `8000`                          |
| `backend.extraEnvVariables`                          | Extra environment variables to add to backend pods                                                                | `[]`                            |
| `backend.externalSecrets.enabled`                    | Enable external secrets for the Backend Deployment                                                                | `false`                         |
| `backend.externalSecrets.secrets`                    | List of external secrets to load environment variables from                                                       | `[]`                            |
| `backend.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                            |
| `backend.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                                            | `{}`                            |
| `backend.podSecurityContext`                         | Pod security context                                                                                              | `{}`                            |
| `backend.securityContext`                            | Security context for the container                                                                                | `{}`                            |
| `backend.resources`                                  | Set container requests and limits for different resources like CPU or memory (essential for production workloads) | `{}`                            |
| `backend.livenessProbe.httpGet.path`                 | Path to hit for the liveness probe                                                                                | `/api/health`                   |
| `backend.livenessProbe.httpGet.port`                 | Port to hit for the liveness probe                                                                                | `8000`                          |
| `backend.livenessProbe.initialDelaySeconds`          | Number of seconds after the container has started before liveness probes are initiated                            | `30`                            |
| `backend.livenessProbe.periodSeconds`                | How often (in seconds) to perform the probe                                                                       | `10`                            |
| `backend.livenessProbe.timeoutSeconds`               | Number of seconds after which the probe times out                                                                 | `30`                            |
| `backend.livenessProbe.failureThreshold`             | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `5`                             |
| `backend.readinessProbe.httpGet.path`                | Path to hit for the readiness probe                                                                               | `/api/health`                   |
| `backend.readinessProbe.httpGet.port`                | Port to hit for the readiness probe                                                                               | `8000`                          |
| `backend.readinessProbe.initialDelaySeconds`         | Number of seconds after the container has started before readiness probes are initiated                           | `30`                            |
| `backend.readinessProbe.periodSeconds`               | How often (in seconds) to perform the probe                                                                       | `10`                            |
| `backend.readinessProbe.timeoutSeconds`              | Number of seconds after which the probe times out                                                                 | `30`                            |
| `backend.readinessProbe.failureThreshold`            | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `5`                             |
| `backend.startupProbe.httpGet.path`                  | Path to hit for the startup probe                                                                                 | `/api/health`                   |
| `backend.startupProbe.httpGet.port`                  | Port to hit for the startup probe                                                                                 | `8000`                          |
| `backend.startupProbe.periodSeconds`                 | How often (in seconds) to perform the probe                                                                       | `10`                            |
| `backend.startupProbe.timeoutSeconds`                | Number of seconds after which the probe times out                                                                 | `5`                             |
| `backend.startupProbe.failureThreshold`              | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `15`                            |
| `backend.autoscaling.enabled`                        | Enable autoscaling for the Backend Deployment                                                                     | `false`                         |
| `backend.autoscaling.minReplicas`                    | Minimum number of replicas for the Backend Deployment                                                             | `1`                             |
| `backend.autoscaling.maxReplicas`                    | Maximum number of replicas for the Backend Deployment                                                             | `8`                             |
| `backend.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the Backend Deployment                                                      | `80`                            |
| `backend.podDisruptionBudget.enabled`                | Enable PodDisruptionBudget for the Backend Deployment                                                             | `false`                         |
| `backend.podDisruptionBudget.maxUnavailable`         | Maximum number of pods that can be unavailable during an update                                                   | `1`                             |
| `backend.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod                                            | `[]`                            |
| `backend.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod                                       | `[]`                            |
| `backend.nodeSelector`                               | Node labels for pod assignment                                                                                    | `{}`                            |
| `backend.tolerations`                                | Taints to tolerate on node assignment:                                                                            | `[]`                            |
| `backend.affinity`                                   | Pod scheduling constraints                                                                                        | `{}`                            |

### JobsService Configuration

| Name                                                     | Description                                                                                                       | Value                                |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| `jobsService.name`                                       | Name suffix of the JobsService related resources                                                                  | `jobs-service`                       |
| `jobsService.config.logLevel`                            | Log level for the JobsService                                                                                     | `info`                               |
| `jobsService.replicas`                                   | Number of replicas of JobsService Deployment                                                                      | `1`                                  |
| `jobsService.image.registry`                             | JobsService Image registry                                                                                        | `docker.io`                          |
| `jobsService.image.repository`                           | JobsService Image repository                                                                                      | `llamaindex/llamacloud-jobs-service` |
| `jobsService.image.tag`                                  | JobsService Image tag                                                                                             | `0.1.39`                             |
| `jobsService.image.pullPolicy`                           | JobsService Image pull policy                                                                                     | `IfNotPresent`                       |
| `jobsService.service.type`                               | JobsService Service type                                                                                          | `ClusterIP`                          |
| `jobsService.service.port`                               | JobsService Service port                                                                                          | `8002`                               |
| `jobsService.serviceAccount.create`                      | Whether or not to create a new service account                                                                    | `true`                               |
| `jobsService.serviceAccount.name`                        | Name of the service account                                                                                       | `""`                                 |
| `jobsService.serviceAccount.labels`                      | Labels to add to the service account                                                                              | `{}`                                 |
| `jobsService.serviceAccount.annotations`                 | Annotations to add to the service account                                                                         | `{}`                                 |
| `jobsService.containerPort`                              | Port to expose on the JobsService container                                                                       | `8002`                               |
| `jobsService.extraEnvVariables`                          | Extra environment variables to add to jobsService pods                                                            | `[]`                                 |
| `jobsService.externalSecrets.enabled`                    | Enable external secrets for the JobsService Deployment                                                            | `false`                              |
| `jobsService.externalSecrets.secrets`                    | List of external secrets to load environment variables from                                                       | `[]`                                 |
| `jobsService.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                                 |
| `jobsService.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                                            | `{}`                                 |
| `jobsService.podSecurityContext`                         | Pod security context                                                                                              | `{}`                                 |
| `jobsService.securityContext`                            | Security context for the container                                                                                | `{}`                                 |
| `jobsService.resources`                                  | Set container requests and limits for different resources like CPU or memory (essential for production workloads) | `{}`                                 |
| `jobsService.livenessProbe.httpGet.path`                 | Path to hit for the liveness probe                                                                                | `/api/health`                        |
| `jobsService.livenessProbe.httpGet.port`                 | Port to hit for the liveness probe                                                                                | `8002`                               |
| `jobsService.livenessProbe.initialDelaySeconds`          | Number of seconds after the container has started before liveness probes are initiated                            | `30`                                 |
| `jobsService.livenessProbe.periodSeconds`                | How often (in seconds) to perform the probe                                                                       | `5`                                  |
| `jobsService.livenessProbe.timeoutSeconds`               | Number of seconds after which the probe times out                                                                 | `30`                                 |
| `jobsService.livenessProbe.failureThreshold`             | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `5`                                  |
| `jobsService.readinessProbe.httpGet.path`                | Path to hit for the liveness probe                                                                                | `/api/health`                        |
| `jobsService.readinessProbe.httpGet.port`                | Port to hit for the liveness probe                                                                                | `8002`                               |
| `jobsService.readinessProbe.initialDelaySeconds`         | Number of seconds after the container has started before liveness probes are initiated                            | `30`                                 |
| `jobsService.readinessProbe.periodSeconds`               | How often (in seconds) to perform the probe                                                                       | `5`                                  |
| `jobsService.readinessProbe.timeoutSeconds`              | Number of seconds after which the probe times out                                                                 | `30`                                 |
| `jobsService.readinessProbe.failureThreshold`            | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `5`                                  |
| `jobsService.autoscaling.enabled`                        | Enable autoscaling for the JobsService Deployment                                                                 | `false`                              |
| `jobsService.autoscaling.minReplicas`                    | Minimum number of replicas for the JobsService Deployment                                                         | `1`                                  |
| `jobsService.autoscaling.maxReplicas`                    | Maximum number of replicas for the JobsService Deployment                                                         | `4`                                  |
| `jobsService.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the JobsService Deployment                                                  | `80`                                 |
| `jobsService.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod                                            | `[]`                                 |
| `jobsService.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod                                       | `[]`                                 |
| `jobsService.nodeSelector`                               | Node labels for pod assignment                                                                                    | `{}`                                 |
| `jobsService.tolerations`                                | Taints to tolerate on node assignment:                                                                            | `[]`                                 |
| `jobsService.affinity`                                   | Pod scheduling constraints                                                                                        | `{}`                                 |

### JobsWorker Configuration

| Name                                                    | Description                                                                                                       | Value                               |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| `jobsWorker.name`                                       | Name suffix of the JobsWorker related resources                                                                   | `jobs-worker`                       |
| `jobsWorker.config.logLevel`                            | Log level for the JobsWorker                                                                                      | `info`                              |
| `jobsWorker.replicas`                                   | Number of replicas of JobsWorker Deployment                                                                       | `1`                                 |
| `jobsWorker.image.registry`                             | JobsWorker Image registry                                                                                         | `docker.io`                         |
| `jobsWorker.image.repository`                           | JobsWorker Image repository                                                                                       | `llamaindex/llamacloud-jobs-worker` |
| `jobsWorker.image.tag`                                  | JobsWorker Image tag                                                                                              | `0.1.39`                            |
| `jobsWorker.image.pullPolicy`                           | JobsWorker Image pull policy                                                                                      | `IfNotPresent`                      |
| `jobsWorker.service.type`                               | JobsWorker Service type                                                                                           | `ClusterIP`                         |
| `jobsWorker.service.port`                               | JobsWorker Service port                                                                                           | `8001`                              |
| `jobsWorker.serviceAccount.create`                      | Whether or not to create a new service account                                                                    | `true`                              |
| `jobsWorker.serviceAccount.name`                        | Name of the service account                                                                                       | `""`                                |
| `jobsWorker.serviceAccount.labels`                      | Labels to add to the service account                                                                              | `{}`                                |
| `jobsWorker.serviceAccount.annotations`                 | Annotations to add to the service account                                                                         | `{}`                                |
| `jobsWorker.labels`                                     | Labels added to the JobsWorker Deployment.                                                                        | `{}`                                |
| `jobsWorker.annotations`                                | Annotations added to the JobsWorker Deployment.                                                                   | `{}`                                |
| `jobsWorker.containerPort`                              | Port to expose on the jobsWorker container                                                                        | `8001`                              |
| `jobsWorker.extraEnvVariables`                          | Extra environment variables to add to jobsWorker pods                                                             | `[]`                                |
| `jobsWorker.externalSecrets.enabled`                    | Enable external secrets for the JobsWorker Deployment                                                             | `false`                             |
| `jobsWorker.externalSecrets.secrets`                    | List of external secrets to load environment variables from                                                       | `[]`                                |
| `jobsWorker.externalSecrets.enabled`                    | Enable external secrets for the JobsWorker Deployment                                                             | `false`                             |
| `jobsWorker.externalSecrets.secrets`                    | List of external secrets to load environment variables from                                                       | `[]`                                |
| `jobsWorker.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                                |
| `jobsWorker.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                                            | `{}`                                |
| `jobsWorker.podSecurityContext`                         | Pod security context                                                                                              | `{}`                                |
| `jobsWorker.securityContext`                            | Security context for the container                                                                                | `{}`                                |
| `jobsWorker.resources`                                  | Set container requests and limits for different resources like CPU or memory (essential for production workloads) | `{}`                                |
| `jobsWorker.livenessProbe.httpGet.path`                 | Path to hit for the liveness probe                                                                                | `/api/health`                       |
| `jobsWorker.livenessProbe.httpGet.port`                 | Port to hit for the liveness probe                                                                                | `8001`                              |
| `jobsWorker.livenessProbe.initialDelaySeconds`          | Number of seconds after the container has started before liveness probes are initiated                            | `30`                                |
| `jobsWorker.livenessProbe.periodSeconds`                | How often (in seconds) to perform the probe                                                                       | `10`                                |
| `jobsWorker.livenessProbe.timeoutSeconds`               | Number of seconds after which the probe times out                                                                 | `30`                                |
| `jobsWorker.livenessProbe.failureThreshold`             | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `5`                                 |
| `jobsWorker.readinessProbe.httpGet.path`                | Path to hit for the liveness probe                                                                                | `/api/health`                       |
| `jobsWorker.readinessProbe.httpGet.port`                | Port to hit for the liveness probe                                                                                | `8001`                              |
| `jobsWorker.readinessProbe.initialDelaySeconds`         | Number of seconds after the container has started before liveness probes are initiated                            | `30`                                |
| `jobsWorker.readinessProbe.periodSeconds`               | How often (in seconds) to perform the probe                                                                       | `10`                                |
| `jobsWorker.readinessProbe.timeoutSeconds`              | Number of seconds after which the probe times out                                                                 | `30`                                |
| `jobsWorker.readinessProbe.failureThreshold`            | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `5`                                 |
| `jobsWorker.startupProbe.httpGet.path`                  | Path to hit for the liveness probe                                                                                | `/api/health`                       |
| `jobsWorker.startupProbe.httpGet.port`                  | Port to hit for the liveness probe                                                                                | `8001`                              |
| `jobsWorker.startupProbe.initialDelaySeconds`           | Number of seconds after the container has started before liveness probes are initiated                            | `30`                                |
| `jobsWorker.startupProbe.periodSeconds`                 | How often (in seconds) to perform the probe                                                                       | `10`                                |
| `jobsWorker.startupProbe.timeoutSeconds`                | Number of seconds after which the probe times out                                                                 | `5`                                 |
| `jobsWorker.startupProbe.failureThreshold`              | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `10`                                |
| `jobsWorker.autoscaling.enabled`                        | Enable autoscaling for the JobsWorker Deployment                                                                  | `false`                             |
| `jobsWorker.autoscaling.minReplicas`                    | Minimum number of replicas for the JobsWorker Deployment                                                          | `1`                                 |
| `jobsWorker.autoscaling.maxReplicas`                    | Maximum number of replicas for the JobsWorker Deployment                                                          | `4`                                 |
| `jobsWorker.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the JobsWorker Deployment                                                   | `80`                                |
| `jobsWorker.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod                                            | `[]`                                |
| `jobsWorker.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod                                       | `[]`                                |
| `jobsWorker.nodeSelector`                               | Node labels for pod assignment                                                                                    | `{}`                                |
| `jobsWorker.tolerations`                                | Taints to tolerate on node assignment:                                                                            | `[]`                                |
| `jobsWorker.affinity`                                   | Pod scheduling constraints                                                                                        | `{}`                                |

### LlamaParse Configuration

| Name                                                    | Description                                                                 | Value                              |
| ------------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------- |
| `llamaParse.name`                                       | Name suffix of the LlamaParse related resources                             | `llamaparse`                       |
| `llamaParse.config.maxPdfPages`                         | Maximum number of pages to parse in a PDF                                   | `1200`                             |
| `llamaParse.config.openAiApiKey`                        | OpenAI API key                                                              | `""`                               |
| `llamaParse.config.existingOpenAiApiKeySecret`          | Name of the existing secret to use for the OpenAI API key                   | `""`                               |
| `llamaParse.config.azureOpenAi.enabled`                 | Enable Azure OpenAI for LlamaParse                                          | `false`                            |
| `llamaParse.config.azureOpenAi.existingSecret`          | Name of the existing secret to use for the Azure OpenAI API key             | `""`                               |
| `llamaParse.config.azureOpenAi.key`                     | Azure OpenAI API key                                                        | `""`                               |
| `llamaParse.config.azureOpenAi.endpoint`                | Azure OpenAI endpoint                                                       | `""`                               |
| `llamaParse.config.azureOpenAi.deploymentName`          | Azure OpenAI deployment                                                     | `""`                               |
| `llamaParse.config.azureOpenAi.apiVersion`              | Azure OpenAI API version                                                    | `""`                               |
| `llamaParse.config.anthropicApiKey`                     | Anthropic API key                                                           | `""`                               |
| `llamaParse.config.existingAnthropicApiKeySecret`       | Name of the existing secret to use for the Anthropic API key                | `""`                               |
| `llamaParse.config.s3UploadBucket`                      | S3 bucket to upload files to                                                | `llama-platform-file-parsing`      |
| `llamaParse.config.s3OutputBucket`                      | S3 bucket to output files to                                                | `llama-platform-file-parsing`      |
| `llamaParse.config.s3OutputBucketTemp`                  | S3 bucket to output temporary files to                                      | `llama-platform-file-parsing`      |
| `llamaParse.replicas`                                   | Number of replicas of LlamaParse Deployment                                 | `2`                                |
| `llamaParse.image.registry`                             | LlamaParse Image registry                                                   | `docker.io`                        |
| `llamaParse.image.repository`                           | LlamaParse Image repository                                                 | `llamaindex/llamacloud-llamaparse` |
| `llamaParse.image.tag`                                  | LlamaParse Image tag                                                        | `0.1.39`                           |
| `llamaParse.image.pullPolicy`                           | LlamaParse Image pull policy                                                | `IfNotPresent`                     |
| `llamaParse.serviceAccount.create`                      | Whether or not to create a new service account                              | `true`                             |
| `llamaParse.serviceAccount.name`                        | Name of the service account                                                 | `""`                               |
| `llamaParse.serviceAccount.labels`                      | Labels to add to the service account                                        | `{}`                               |
| `llamaParse.serviceAccount.annotations`                 | Annotations to add to the service account                                   | `{}`                               |
| `llamaParse.labels`                                     | Labels added to the LlamaParse Deployment.                                  | `{}`                               |
| `llamaParse.annotations`                                | Annotations added to the LlamaParse Deployment.                             | `{}`                               |
| `llamaParse.containerPort`                              | Port to expose on the LlamaParse container                                  | `8000`                             |
| `llamaParse.extraEnvVariables`                          | Extra environment variables to add to llamaParse pods                       | `[]`                               |
| `llamaParse.externalSecrets.enabled`                    | Enable external secrets for the LlamaParse Deployment                       | `false`                            |
| `llamaParse.externalSecrets.secrets`                    | List of external secrets to load environment variables from                 | `[]`                               |
| `llamaParse.externalSecrets.enabled`                    | Enable external secrets for the LlamaParse Deployment                       | `false`                            |
| `llamaParse.externalSecrets.secrets`                    | List of external secrets to load environment variables from                 | `[]`                               |
| `llamaParse.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                 | `{}`                               |
| `llamaParse.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                      | `{}`                               |
| `llamaParse.podSecurityContext`                         | Pod security context                                                        | `{}`                               |
| `llamaParse.securityContext`                            | Security context for the container                                          | `{}`                               |
| `llamaParse.resources.requests.memory`                  | Memory request for the LlamaParse container                                 | `13Gi`                             |
| `llamaParse.resources.requests.cpu`                     | CPU request for the LlamaParse container                                    | `7`                                |
| `llamaParse.resources.limits.memory`                    | Memory limit for the LlamaParse container                                   | `13Gi`                             |
| `llamaParse.resources.limits.cpu`                       | CPU limit for the LlamaParse container                                      | `7`                                |
| `llamaParse.autoscaling.enabled`                        | Enable autoscaling for the LlamaParse Deployment                            | `true`                             |
| `llamaParse.autoscaling.minReplicas`                    | Minimum number of replicas for the LlamaParse Deployment                    | `2`                                |
| `llamaParse.autoscaling.maxReplicas`                    | Maximum number of replicas for the LlamaParse Deployment                    | `10`                               |
| `llamaParse.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the LlamaParse Deployment             | `80`                               |
| `llamaParse.podDisruptionBudget.enabled`                | Enable PodDisruptionBudget for the LlamaParse Deployment                    | `true`                             |
| `llamaParse.podDisruptionBudget.maxUnavailable`         | Maximum number of unavailable pods                                          | `1`                                |
| `llamaParse.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod      | `[]`                               |
| `llamaParse.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod | `[]`                               |
| `llamaParse.nodeSelector`                               | Node labels for pod assignment                                              | `{}`                               |
| `llamaParse.tolerations`                                | Taints to tolerate on node assignment:                                      | `[]`                               |
| `llamaParse.affinity`                                   | Pod scheduling constraints                                                  | `{}`                               |

### LlamaParseOcr Configuration

| Name                                                       | Description                                                                                 | Value                                  |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------- |
| `llamaParseOcr.name`                                       | Name suffix of the LlamaParseOcr related resources                                          | `llamaparse-ocr`                       |
| `llamaParseOcr.replicas`                                   | Number of replicas of LlamaParseOcr Deployment                                              | `2`                                    |
| `llamaParseOcr.image.registry`                             | LlamaParseOcr Image registry                                                                | `docker.io`                            |
| `llamaParseOcr.image.repository`                           | LlamaParseOcr Image repository                                                              | `llamaindex/llamacloud-llamaparse-ocr` |
| `llamaParseOcr.image.tag`                                  | LlamaParseOcr Image tag                                                                     | `0.1.39`                               |
| `llamaParseOcr.image.pullPolicy`                           | LlamaParseOcr Image pull policy                                                             | `IfNotPresent`                         |
| `llamaParseOcr.service.type`                               | LlamaParseOcr Service type                                                                  | `ClusterIP`                            |
| `llamaParseOcr.service.port`                               | LlamaParseOcr Service port                                                                  | `8080`                                 |
| `llamaParseOcr.serviceAccount.create`                      | Whether or not to create a new service account                                              | `true`                                 |
| `llamaParseOcr.serviceAccount.name`                        | Name of the service account                                                                 | `""`                                   |
| `llamaParseOcr.serviceAccount.labels`                      | Labels to add to the service account                                                        | `{}`                                   |
| `llamaParseOcr.serviceAccount.annotations`                 | Annotations to add to the service account                                                   | `{}`                                   |
| `llamaParseOcr.containerPort`                              | Port to expose on the LlamaParseOcr container                                               | `8080`                                 |
| `llamaParseOcr.labels`                                     | Labels added to the LlamaParseOcr Deployment.                                               | `{}`                                   |
| `llamaParseOcr.annotations`                                | Annotations added to the LlamaParseOcr Deployment.                                          | `{}`                                   |
| `llamaParseOcr.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                 | `{}`                                   |
| `llamaParseOcr.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                      | `{}`                                   |
| `llamaParseOcr.podSecurityContext`                         | Pod security context                                                                        | `{}`                                   |
| `llamaParseOcr.securityContext`                            | Security context for the container                                                          | `{}`                                   |
| `llamaParseOcr.extraEnvVariables`                          | Extra environment variables to add to llamaParseOcr pods                                    | `[]`                                   |
| `llamaParseOcr.resources.requests.memory`                  | Memory request for the LlamaParse container                                                 | `12Gi`                                 |
| `llamaParseOcr.resources.requests.cpu`                     | CPU request for the LlamaParse container                                                    | `2`                                    |
| `llamaParseOcr.resources.limits.memory`                    | Memory limit for the LlamaParse container                                                   | `16Gi`                                 |
| `llamaParseOcr.resources.limits.cpu`                       | CPU limit for the LlamaParse container                                                      | `4`                                    |
| `llamaParseOcr.livenessProbe.httpGet.path`                 | Path to hit for the liveness probe                                                          | `/health_check`                        |
| `llamaParseOcr.livenessProbe.httpGet.port`                 | Port to hit for the liveness probe                                                          | `8080`                                 |
| `llamaParseOcr.livenessProbe.httpGet.scheme`               | Scheme to use for the liveness probe                                                        | `HTTP`                                 |
| `llamaParseOcr.livenessProbe.initialDelaySeconds`          | Number of seconds after the container has started before liveness probes are initiated      | `30`                                   |
| `llamaParseOcr.livenessProbe.periodSeconds`                | How often (in seconds) to perform the probe                                                 | `15`                                   |
| `llamaParseOcr.livenessProbe.timeoutSeconds`               | Number of seconds after which the probe times out                                           | `120`                                  |
| `llamaParseOcr.livenessProbe.failureThreshold`             | Minimum consecutive failures for the probe to be considered failed after having succeeded   | `3`                                    |
| `llamaParseOcr.livenessProbe.successThreshold`             | Minimum consecutive successes for the probe to be considered successful after having failed | `1`                                    |
| `llamaParseOcr.readinessProbe.httpGet.path`                | Path to hit for the readiness probe                                                         | `/health_check`                        |
| `llamaParseOcr.readinessProbe.httpGet.port`                | Port to hit for the readiness probe                                                         | `8080`                                 |
| `llamaParseOcr.readinessProbe.httpGet.scheme`              | Scheme to use for the readiness probe                                                       | `HTTP`                                 |
| `llamaParseOcr.readinessProbe.initialDelaySeconds`         | Number of seconds after the container has started before readiness probes are initiated     | `30`                                   |
| `llamaParseOcr.readinessProbe.periodSeconds`               | How often (in seconds) to perform the probe                                                 | `15`                                   |
| `llamaParseOcr.readinessProbe.timeoutSeconds`              | Number of seconds after which the probe times out                                           | `120`                                  |
| `llamaParseOcr.readinessProbe.failureThreshold`            | Minimum consecutive failures for the probe to be considered failed after having succeeded   | `3`                                    |
| `llamaParseOcr.readinessProbe.successThreshold`            | Minimum consecutive successes for the probe to be considered successful after having failed | `1`                                    |
| `llamaParseOcr.autoscaling.enabled`                        | Enable autoscaling for the LlamaParseOcr Deployment                                         | `true`                                 |
| `llamaParseOcr.autoscaling.minReplicas`                    | Minimum number of replicas for the LlamaParseOcr Deployment                                 | `2`                                    |
| `llamaParseOcr.autoscaling.maxReplicas`                    | Maximum number of replicas for the LlamaParseOcr Deployment                                 | `10`                                   |
| `llamaParseOcr.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the LlamaParseOcr Deployment                          | `80`                                   |
| `llamaParseOcr.podDisruptionBudget.enabled`                | Enable PodDisruptionBudget for the LlamaParseOcr Deployment                                 | `true`                                 |
| `llamaParseOcr.podDisruptionBudget.maxUnavailable`         | Maximum number of unavailable pods                                                          | `1`                                    |
| `llamaParseOcr.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod                      | `[]`                                   |
| `llamaParseOcr.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod                 | `[]`                                   |
| `llamaParseOcr.nodeSelector`                               | Node labels for pod assignment                                                              | `{}`                                   |
| `llamaParseOcr.tolerations`                                | Taints to tolerate on node assignment:                                                      | `[]`                                   |
| `llamaParseOcr.affinity`                                   | Pod scheduling constraints                                                                  | `{}`                                   |

### LlamaParsePdf Configuration

| Name                                               | Description                                                                                                       | Value                         |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `usage.name`                                       | Name suffix of the usage related resources                                                                        | `usage`                       |
| `usage.replicas`                                   | Number of replicas of usage Deployment                                                                            | `1`                           |
| `usage.image.registry`                             | Usage Image registry                                                                                              | `docker.io`                   |
| `usage.image.repository`                           | Usage Image repository                                                                                            | `llamaindex/llamacloud-usage` |
| `usage.image.tag`                                  | Usage Image tag                                                                                                   | `0.1.39`                      |
| `usage.image.pullPolicy`                           | Usage Image pull policy                                                                                           | `IfNotPresent`                |
| `usage.service.type`                               | Usage Service type                                                                                                | `ClusterIP`                   |
| `usage.service.port`                               | Usage Service port                                                                                                | `8005`                        |
| `usage.serviceAccount.create`                      | Whether or not to create a new service account                                                                    | `true`                        |
| `usage.serviceAccount.name`                        | Name of the service account                                                                                       | `""`                          |
| `usage.serviceAccount.labels`                      | Labels to add to the service account                                                                              | `{}`                          |
| `usage.serviceAccount.annotations`                 | Annotations to add to the service account                                                                         | `{}`                          |
| `usage.containerPort`                              | Port to expose on the usage container                                                                             | `8005`                        |
| `usage.labels`                                     | Labels added to the usage Deployment.                                                                             | `{}`                          |
| `usage.annotations`                                | Annotations added to the usage Deployment.                                                                        | `{}`                          |
| `usage.extraEnvVariables`                          | Extra environment variables to add to usage pods                                                                  | `[]`                          |
| `usage.externalSecrets.enabled`                    | Enable external secrets for the Usage Deployment                                                                  | `false`                       |
| `usage.externalSecrets.secrets`                    | List of external secrets to load environment variables from                                                       | `[]`                          |
| `usage.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                          |
| `usage.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                                            | `{}`                          |
| `usage.podSecurityContext`                         | Pod security context                                                                                              | `{}`                          |
| `usage.securityContext`                            | Security context for the container                                                                                | `{}`                          |
| `usage.resources`                                  | Set container requests and limits for different resources like CPU or memory (essential for production workloads) | `{}`                          |
| `usage.livenessProbe.httpGet.path`                 | Path to hit for the liveness probe                                                                                | `/health_check`               |
| `usage.livenessProbe.httpGet.port`                 | Port to hit for the liveness probe                                                                                | `8005`                        |
| `usage.livenessProbe.httpGet.scheme`               | Scheme to use for the liveness probe                                                                              | `HTTP`                        |
| `usage.livenessProbe.initialDelaySeconds`          | Number of seconds after the container has started before liveness probes are initiated                            | `15`                          |
| `usage.livenessProbe.periodSeconds`                | How often (in seconds) to perform the probe                                                                       | `15`                          |
| `usage.livenessProbe.timeoutSeconds`               | Number of seconds after which the probe times out                                                                 | `60`                          |
| `usage.livenessProbe.failureThreshold`             | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `3`                           |
| `usage.livenessProbe.successThreshold`             | Minimum consecutive successes for the probe to be considered successful after having failed                       | `1`                           |
| `usage.readinessProbe.httpGet.path`                | Path to hit for the liveness probe                                                                                | `/health_check`               |
| `usage.readinessProbe.httpGet.port`                | Port to hit for the liveness probe                                                                                | `8005`                        |
| `usage.readinessProbe.httpGet.scheme`              | Scheme to use for the liveness probe                                                                              | `HTTP`                        |
| `usage.readinessProbe.initialDelaySeconds`         | Number of seconds after the container has started before liveness probes are initiated                            | `15`                          |
| `usage.readinessProbe.periodSeconds`               | How often (in seconds) to perform the probe                                                                       | `15`                          |
| `usage.readinessProbe.timeoutSeconds`              | Number of seconds after which the probe times out                                                                 | `60`                          |
| `usage.readinessProbe.failureThreshold`            | Minimum consecutive failures for the probe to be considered failed after having succeeded                         | `3`                           |
| `usage.readinessProbe.successThreshold`            | Minimum consecutive successes for the probe to be considered successful after having failed                       | `1`                           |
| `usage.autoscaling.enabled`                        | Enable autoscaling for the Usage Deployment                                                                       | `false`                       |
| `usage.autoscaling.minReplicas`                    | Minimum number of replicas for the Usage Deployment                                                               | `1`                           |
| `usage.autoscaling.maxReplicas`                    | Maximum number of replicas for the Usage Deployment                                                               | `4`                           |
| `usage.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the Usage Deployment                                                        | `80`                          |
| `usage.volumes`                                    | List of volumes that can be mounted by containers belonging to the pod                                            | `[]`                          |
| `usage.volumeMounts`                               | List of volumeMounts that can be mounted by containers belonging to the pod                                       | `[]`                          |
| `usage.nodeSelector`                               | Node labels for pod assignment                                                                                    | `{}`                          |
| `usage.tolerations`                                | Taints to tolerate on node assignment:                                                                            | `[]`                          |
| `usage.affinity`                                   | Pod scheduling constraints                                                                                        | `{}`                          |

### S3Proxy Configuration

| Name                                                 | Description                                                                                                       | Value                |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | -------------------- |
| `s3proxy.enabled`                                    | Enable s3proxy Deployment                                                                                         | `true`               |
| `s3proxy.name`                                       | Name suffix of the s3proxy related resources                                                                      | `s3proxy`            |
| `s3proxy.config`                                     | s3proxy configuration to enable s3proxy features                                                                  | `{}`                 |
| `s3proxy.replicas`                                   | Number of replicas of s3proxy Deployment                                                                          | `1`                  |
| `s3proxy.image.registry`                             | s3proxy Image registry                                                                                            | `docker.io`          |
| `s3proxy.image.repository`                           | s3proxy Image repository                                                                                          | `andrewgaul/s3proxy` |
| `s3proxy.image.tag`                                  | s3proxy Image tag                                                                                                 | `sha-82e50ee`        |
| `s3proxy.image.pullPolicy`                           | s3proxy Image pull policy                                                                                         | `IfNotPresent`       |
| `s3proxy.service.type`                               | s3proxy Service type                                                                                              | `ClusterIP`          |
| `s3proxy.service.port`                               | s3proxy Service port                                                                                              | `80`                 |
| `s3proxy.serviceAccount.create`                      | Whether or not to create a new service account                                                                    | `true`               |
| `s3proxy.serviceAccount.name`                        | Name of the service account                                                                                       | `""`                 |
| `s3proxy.serviceAccount.labels`                      | Labels to add to the service account                                                                              | `{}`                 |
| `s3proxy.serviceAccount.annotations`                 | Annotations to add to the service account                                                                         | `{}`                 |
| `s3proxy.containerPort`                              | Port to expose on the s3proxy container                                                                           | `80`                 |
| `s3proxy.labels`                                     | Labels added to the s3proxy Deployment.                                                                           | `{}`                 |
| `s3proxy.annotations`                                | Annotations added to the s3proxy Deployment.                                                                      | `{}`                 |
| `s3proxy.extraEnvVariables`                          | Extra environment variables to add to s3proxy pods                                                                | `[]`                 |
| `s3proxy.envFromSecretName`                          | Name of the secret to use for environment variables                                                               | `""`                 |
| `s3proxy.envFromConfigMapName`                       | Name of the config map to use for environment variables                                                           | `""`                 |
| `s3proxy.podAnnotations`                             | Annotations to add to the resulting Pods of the Deployment.                                                       | `{}`                 |
| `s3proxy.podLabels`                                  | Labels to add to the resulting Pods of the Deployment.                                                            | `{}`                 |
| `s3proxy.podSecurityContext`                         | Pod security context                                                                                              | `{}`                 |
| `s3proxy.securityContext`                            | Security context for the container                                                                                | `{}`                 |
| `s3proxy.resources`                                  | Set container requests and limits for different resources like CPU or memory (essential for production workloads) | `{}`                 |
| `s3proxy.autoscaling.enabled`                        | Enable autoscaling for the s3proxy Deployment                                                                     | `false`              |
| `s3proxy.autoscaling.minReplicas`                    | Minimum number of replicas for the s3proxy Deployment                                                             | `1`                  |
| `s3proxy.autoscaling.maxReplicas`                    | Maximum number of replicas for the s3proxy Deployment                                                             | `4`                  |
| `s3proxy.autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization percentage for the s3proxy Deployment                                                      | `80`                 |
| `s3proxy.nodeSelector`                               | Node labels for pod assignment                                                                                    | `{}`                 |
| `s3proxy.tolerations`                                | Taints to tolerate on node assignment:                                                                            | `[]`                 |
| `s3proxy.affinity`                                   | Pod scheduling constraints                                                                                        | `{}`                 |

### Dependencies Configuration

| Name                                           | Description                            | Value        |
| ---------------------------------------------- | -------------------------------------- | ------------ |
| `postgresql.enabled`                           | Enable PostgreSQL                      | `true`       |
| `postgresql.auth.enabled`                      | Enable PostgreSQL Auth                 | `true`       |
| `postgresql.auth.database`                     | Database name                          | `llamacloud` |
| `postgresql.auth.username`                     | Username                               | `llamacloud` |
| `postgresql.primary.resources.requests.cpu`    | CPU requests                           | `1`          |
| `postgresql.primary.resources.requests.memory` | Memory requests                        | `1Gi`        |
| `postgresql.primary.resources.limits.cpu`      | CPU limits                             | `2`          |
| `postgresql.primary.resources.limits.memory`   | Memory limits                          | `2Gi`        |
| `mongodb.enabled`                              | Enable MongoDB                         | `true`       |
| `mongodb.auth.enabled`                         | Enable MongoDB Auth                    | `true`       |
| `mongodb.auth.rootUser`                        | Root user name                         | `root`       |
| `redis.enabled`                                | Enable Redis                           | `true`       |
| `redis.auth.enabled`                           | Enable Redis Auth (DO NOT SET TO TRUE) | `false`      |
| `rabbitmq.enabled`                             | Enable RabbitMQ                        | `true`       |

