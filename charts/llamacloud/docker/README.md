# LlamaCloud Docker Compose

## Prerequisites

- Docker: **27.0.0** or higher
    - **Important**: LlamaCloud is quite resource intensive. We recommend allocating ~4 cores and ~12-16GB of RAM for the services to run smoothly.
- Docker Compose **v2.31.0** or higher
- Git: Any version is good

## Setup

1. Clone this git repository
    - `git clone https://github.com/llamacloud/llamacloud.git`
2. Navigate to the `charts/llamacloud/docker` folder
3. Run `./setup.sh` to validate that the prerequisites have been met and to create the `.env.secrets`, `.env.llamacloud`, `.env.llamaparse` files.
    - **Modify these files with your desired values.**
4. Run `CHART_VERSION=<helm-chart-version> ./run.sh` to start the services. This will perform the following steps:
    - Start the services in detached mode and wait for all services to be healthy
    - Setup Keycloak resources (realm, client, etc.)
    - Setup Filestore (buckets in s3proxy)
    - You can find the available versions in the [releases page](https://github.com/llamacloud/llamacloud/releases).
5. Navigate to http://localhost:3000 to access the LlamaCloud UI
    - Login with the default credentials: `local / local_password`. You can find these and other credentials in the `setup-keycloak.sh` script.
