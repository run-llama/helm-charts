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
    --values charts/llamacloud/ci/test-small-values.yaml \
    "${EXTRA_SET_ARGS[@]}" \
    | grep -E '^\s*image:\s*' \
    | awk '{print $2}' \
    | tr -d '"' \
    | sort -u)

if [[ -z "${IMAGES}" ]]; then
    echo "No images found to pre-pull from rendered manifests."
else
    echo "Pre-pulling images into kind nodes (parallel via Python helper):"
    echo "Images: $(echo ${IMAGES} | tr '\n' ' ')"
    PY_HELPER="charts/llamacloud/ci/parallel_prepull.py"
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 not found on PATH" >&2
        exit 1
    fi
    # Use MAX_JOBS if provided, else default to 16
    MJ="${MAX_JOBS:-16}"
    printf '%s\n' "${IMAGES}" | python3 "${PY_HELPER}" --cluster-name chart-testing --max-jobs "${MJ}" --verify
fi
ct install --target-branch main \
    --helm-extra-set-args \
    "--set=global.config.progressDeadlineSeconds=900 \
    --set=global.config.licenseKey=$LLAMACLOUD_LICENSE_KEY \
    --set=backend.config.oidc.discoveryUrl=$OIDC_DISCOVERY_URL \
    --set=backend.config.oidc.clientId=$OIDC_CLIENT_ID \
    --set=backend.config.oidc.clientSecret=$OIDC_CLIENT_SECRET \
    --set=backend.config.openAiApiKey=$OPENAI_API_KEY \
    --set=llamaParse.config.openAiApiKey=$OPENAI_API_KEY \
    --timeout 900s"