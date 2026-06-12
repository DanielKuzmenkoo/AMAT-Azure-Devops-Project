#!/usr/bin/env bash
#
# Provision the weather-app infrastructure with Terragrunt, in the correct order
# and handling every gotcha we hit during setup:
#
#   1. Register the Microsoft.App + Microsoft.OperationalInsights resource
#      providers (Container Apps fails with MissingSubscriptionRegistration
#      otherwise).
#   2. Deploy the shared Azure Container Registry FIRST (the env units depend on
#      its outputs).
#   3. Push a bootstrap image (weather-api:latest) so the Container Apps have
#      something to pull on first create. Uses `az acr build` — no local Docker,
#      no docker-credential-helper passphrase, no `az acr login` token issues.
#   4. Deploy the Container App per environment. Apps run in North Europe (set in
#      each env.hcl) because West Europe was capacity-constrained for Container
#      Apps managed environments; the ACR stays in West Europe (pulls are
#      cross-region).
#
# Prerequisites:
#   - az login   (with the target subscription selected)
#   - terraform, terragrunt installed
#   - run from anywhere inside the repo
#
# Usage:
#   scripts/bootstrap-infra.sh                # dev staging prod
#   scripts/bootstrap-infra.sh dev            # a subset
set -euo pipefail

if [[ $# -gt 0 ]]; then ENVIRONMENTS=("$@"); else ENVIRONMENTS=(dev staging prod); fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIVE="$REPO_ROOT/infra/live"
IMAGE_REPO="weather-api"

apply_unit()  { ( cd "$1" && terragrunt apply -auto-approve ); }
output_raw()  { ( cd "$1" && terragrunt output -raw "$2" ); }

echo "==> Checking Azure login"
az account show >/dev/null 2>&1 || { echo "ERROR: run 'az login' and select your subscription first."; exit 1; }

echo "==> Registering resource providers (one-time, subscription-wide)"
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait

echo "==> [1/3] Deploying shared ACR"
apply_unit "$LIVE/shared/acr"
ACR_NAME="$(output_raw "$LIVE/shared/acr" acr_name)"
ACR_LOGIN="$(output_raw "$LIVE/shared/acr" acr_login_server)"
echo "    ACR: $ACR_LOGIN"

echo "==> [2/3] Building & pushing bootstrap image ($IMAGE_REPO:latest)"
az acr build --registry "$ACR_NAME" --image "$IMAGE_REPO:latest" "$REPO_ROOT/app"

echo "==> [3/3] Deploying Container Apps: ${ENVIRONMENTS[*]}"
for env in "${ENVIRONMENTS[@]}"; do
  echo "    -> $env"
  apply_unit "$LIVE/$env/container-app"
  echo "    $env app URL: $(output_raw "$LIVE/$env/container-app" app_url)"
done

echo "==> Bootstrap complete."
echo "    The Azure DevOps pipeline now builds new tags into this ACR and"
echo "    rolls each environment's Container App to them."
