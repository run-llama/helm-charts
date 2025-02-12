#! /bin/bash

# Define colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting LlamaCloud services...${NC}"

if [[ ! -f ".env.llamaparse" || ! -f ".env.llamacloud" || ! -f ".env.secrets" ]]; then
    echo -e "${RED}.env.llamaparse, .env.llamacloud, and .env.secrets files do not exist. Please run ./setup.sh first.${NC}"
    exit 1
fi

CHART_VERSION=${CHART_VERSION:-}
if [[ -z "$CHART_VERSION" ]]; then
    echo -e "${RED}CHART_VERSION is not set. Please refer to https://github.com/run-llama/helm-charts/releases for available versions.${NC}"
    exit 1
fi

docker compose up -d && echo -e "${BLUE}Starting docker services in detached mode...${NC}"

llamacloud_services=(
    "frontend"
    "backend"
    "jobs-service"
    "jobs-worker" 
    "llamaparse"
    "llamaparse-ocr"
    "usage"
)

while true; do
    all_healthy=true
    unhealthy_services=()
    
    for service in "${llamacloud_services[@]}"; do
        if [[ $(docker inspect "$service" --format='{{.State.Health.Status}}') != "healthy" ]]; then
            all_healthy=false
            unhealthy_services+=("$service")
        fi
    done

    if [[ "$all_healthy" == "true" ]]; then
        echo -e "${GREEN}All services are running!${NC}"
        break
    fi

    echo -e "${YELLOW}Waiting for services to be ready: $(IFS=,; echo "${unhealthy_services[*]}")${NC}"
    sleep 5
done

./setup-keycloak.sh
./setup-filestore.sh

echo -e "${GREEN}Please visit ${BLUE}http://localhost:3000${GREEN} to access the LlamaCloud UI${NC}"
echo -e "${GREEN}Login with the default credentials: ${YELLOW}local / local_password${NC}"
echo -e "${GREEN}Enjoy :)${NC}"
