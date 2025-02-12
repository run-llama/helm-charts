#!/bin/bash

set -eou pipefail

LLAMACLOUD_LICENSE_KEY=${LLAMACLOUD_LICENSE_KEY:-}
if [[ -z "$LLAMACLOUD_LICENSE_KEY" ]]; then
    echo "LLAMACLOUD_LICENSE_KEY is not set. Please set the LLAMACLOUD_LICENSE_KEY environment variable before running this script :)"
    exit 1
fi

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "Starting LlamaCloud setup..."

if ! command_exists docker; then
    echo "Docker is not installed. Please install Docker before running this script."
    echo "For more information, please refer to the following link: https://docs.docker.com/get-docker/"
    exit 1
fi

echo "Verifying Docker & Docker Compose installation..."
docker --version || { echo "Docker is not installed. Please install Docker before running this script." && exit 1; }
docker compose version || { echo "Docker Compose is not installed. Please install Docker Compose before running this script." && exit 1; }

echo "Setting up LlamaCloud Environment Variables..."

if [[ -f ".env.llamacloud" ]]; then
    echo ".env.llamacloud file already exists!"
    exit 0
else
    echo "Creating .env.llamacloud file..."
    cp .env.llamacloud.template .env.llamacloud
fi

if [[ -f ".env.llamaparse" ]]; then
    echo ".env.llamaparse file already exists!"
    exit 0
else
    echo "Creating .env.llamaparse file..."
    cp .env.llamaparse.template .env.llamaparse
fi

if [[ -f ".env.secrets" ]]; then
    echo ".env.secrets file already exists!"
    exit 0
else
    echo "Creating .env.secrets file..."
    cp .env.secrets.template .env.secrets
    echo "LLAMACLOUD_LICENSE_KEY=${LLAMACLOUD_LICENSE_KEY}" >> .env.secrets
fi

echo -e "Setup complete! Please fill in or modify the .env.llamacloud, .env.llamaparse, and .env.secrets files with your desired values."
echo -e "Afterwards, you can start the LlamaCloud services with CHART_VERSION="input-chart-version" ./run.sh!"
