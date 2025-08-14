#!/usr/bin/env bash
set -euo pipefail

# Loads secrets from 1Password and exports environment variables.
# Usage: source ./script.sh


read_secret() {
  local path="$1"
  op read "$path" | tr -d '\n'
}

# kubernetes-staging/byoc-oidc-secrets
export OIDC_CLIENT_ID="$(read_secret "op://kubernetes-staging/byoc-oidc-secrets/OIDC_CLIENT_ID")"
export OIDC_CLIENT_SECRET="$(read_secret "op://kubernetes-staging/byoc-oidc-secrets/OIDC_CLIENT_SECRET")"
export OIDC_DISCOVERY_URL="$(read_secret "op://kubernetes-staging/byoc-oidc-secrets/OIDC_DISCOVERY_URL")"

# kubernetes-staging/byoc-openai-secrets
export LC_OPENAI_API_KEY="$(read_secret "op://kubernetes-staging/byoc-openai-secrets/LC_OPENAI_API_KEY")"
export OPENAI_API_KEY="$LC_OPENAI_API_KEY"

# kubernetes-staging/byoc-license-secrets
export LLAMACLOUD_LICENSE_KEY="$(read_secret "op://kubernetes-staging/byoc-license-secrets/llamacloud-license-key")"


./charts/llamacloud/ci/test-helm-install.sh