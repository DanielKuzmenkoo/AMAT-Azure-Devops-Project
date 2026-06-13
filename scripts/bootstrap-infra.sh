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
#      something to pull on first create. Built locally with Docker: ACR Tasks
#      (`az acr build`) is not permitted on this subscription
#      (TasksOperationsNotAllowed — common on free/trial subscriptions).
#   4. Deploy the ONE shared Container Apps environment (the subscription is
#      capped at a single CAE: MaxNumberOfGlobalEnvironmentsInSubExceeded on
#      free/trial tiers). It lives in North Europe.
#   5. Deploy a Container App per environment. Each app gets its own resource
#      group and managed identity but joins the shared CAE, so all apps run in
#      its region (North Europe). The ACR stays in West Europe (pulls are
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

echo "==> [1/5] Deploying shared ACR"
apply_unit "$LIVE/shared/acr"
ACR_NAME="$(output_raw "$LIVE/shared/acr" acr_name)"
ACR_LOGIN="$(output_raw "$LIVE/shared/acr" acr_login_server)"
echo "    ACR: $ACR_LOGIN"

echo "==> [2/5] Building & pushing bootstrap image ($IMAGE_REPO:latest)"
az acr login --name "$ACR_NAME"
docker build -t "$ACR_LOGIN/$IMAGE_REPO:latest" "$REPO_ROOT/app"
docker push "$ACR_LOGIN/$IMAGE_REPO:latest"

echo "==> [3/5] Deploying shared Container Apps environment (one CAE for all envs)"
apply_unit "$LIVE/shared/cae"
echo "    CAE: $(output_raw "$LIVE/shared/cae" container_app_environment_id)"

echo "==> [4/5] Deploying shared Application Insights (reuses the CAE workspace)"
apply_unit "$LIVE/shared/monitoring"
echo "    App Insights: $(output_raw "$LIVE/shared/monitoring" app_insights_name)"

echo "==> [5/5] Deploying Container Apps: ${ENVIRONMENTS[*]}"
for env in "${ENVIRONMENTS[@]}"; do
  echo "    -> $env"
  apply_unit "$LIVE/$env/container-app"
  echo "    $env app URL: $(output_raw "$LIVE/$env/container-app" app_url)"
done

echo "==> Bootstrap complete."
echo "    The Azure DevOps pipeline now builds new tags into this ACR and"
echo "    rolls each environment's Container App to them."
echo
echo "    For pipeline deployment events (DORA), set the pipeline secret variable"
echo "    APPLICATIONINSIGHTS_CONNECTION_STRING to:"
echo "      cd infra/live/shared/monitoring && terragrunt output -raw connection_string"
