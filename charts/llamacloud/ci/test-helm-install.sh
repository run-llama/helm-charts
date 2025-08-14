#!/bin/bash

set -eou pipefail

# Check required environment variables
required_vars=(
    "LLAMACLOUD_LICENSE_KEY"
    "OIDC_DISCOVERY_URL"
    "OIDC_CLIENT_ID"
    "OIDC_CLIENT_SECRET"
    "OPENAI_API_KEY"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "Error: Missing required environment variables:"
    printf "  %s\n" "${missing_vars[@]}"
    exit 1
fi



# Ensure required kind cluster exists
if ! kind get clusters | grep -qx "chart-testing"; then
    echo "Error: kind cluster 'chart-testing' not found."
    echo "Create it with:"
    echo "  kind create cluster --name chart-testing"
    exit 1
fi

# Ensure chart dependencies are present (to render subcharts)
helm dependency update charts/llamacloud

# Build the same extra set args used during install
EXTRA_SET_ARGS=(
    "--set=global.config.licenseKey=$LLAMACLOUD_LICENSE_KEY"
    "--set=backend.config.oidc.discoveryUrl=$OIDC_DISCOVERY_URL"
    "--set=backend.config.oidc.clientId=$OIDC_CLIENT_ID"
    "--set=backend.config.oidc.clientSecret=$OIDC_CLIENT_SECRET"
    "--set=backend.config.openAiApiKey=$OPENAI_API_KEY"
    "--set=llamaParse.config.openAiApiKey=$OPENAI_API_KEY"
)

# Render manifests with CI values to capture ALL images (including subcharts)
echo "Rendering chart to collect images to pre-pull..."
IMAGES=$(helm template charts/llamacloud \
    "${EXTRA_SET_ARGS[@]}" \
    | grep -E '^\s*image:\s*' \
    | awk '{print $2}' \
    | tr -d '"' \
    | sort -u)

if [[ -z "${IMAGES}" ]]; then
    echo "No images found to pre-pull from rendered manifests."
else
    echo "Pre-pulling images into kind nodes (parallel):"
    printf "  %s\n" ${IMAGES}

    # Determine reasonable default concurrency for background jobs
    # Prefer MAX_JOBS if provided by caller; fallback to CPU count or 8
    if [[ -z "${MAX_JOBS:-}" ]]; then
        MAX_JOBS=16
    fi
    echo "Using concurrency: ${MAX_JOBS}"

    job_count=0
    for node in $(kind get nodes); do
        echo "Pre-pulling into node: ${node}"
        for img in ${IMAGES}; do
            echo "  scheduling pull ${img} on ${node}"
            {
                docker exec "${node}" ctr -n k8s.io images pull "${img}" || {
                    echo "  warning: failed to pre-pull ${img} on ${node}"
                }
            } &
            job_count=$((job_count + 1))
            # Batch wait to cap parallelism without relying on 'wait -n'
            if (( job_count % MAX_JOBS == 0 )); then
                wait
            fi
        done
    done
    # Wait for any remaining background pulls to finish
    wait
fi
ct install --target-branch ${{ github.event.repository.default_branch }} \
    --helm-extra-set-args \
    "--set=global.config.progressDeadlineSeconds=900 \
    --set=global.config.licenseKey=$LLAMACLOUD_LICENSE_KEY \
    --set=backend.config.oidc.discoveryUrl=$OIDC_DISCOVERY_URL \
    --set=backend.config.oidc.clientId=$OIDC_CLIENT_ID \
    --set=backend.config.oidc.clientSecret=$OIDC_CLIENT_SECRET \
    --set=backend.config.openAiApiKey=$OPENAI_API_KEY \
    --set=llamaParse.config.openAiApiKey=$OPENAI_API_KEY \
    --timeout 900s"