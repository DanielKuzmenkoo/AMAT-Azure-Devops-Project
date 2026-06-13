#!/usr/bin/env bash
#
# Tear down the weather-app infrastructure created by bootstrap-infra.sh.
#
# Order (reverse of bootstrap): destroy each environment's Container App (and VM
# unit, if it was ever applied), then the shared ACR. For any resource group
# Terragrunt can't fully remove — e.g. a failed/orphaned Container App managed
# environment left behind by a capacity error — fall back to deleting the whole
# resource group directly with `az group delete`.
#
# Prerequisites:
#   - az login   (with the target subscription selected)
#   - terraform, terragrunt installed
#
# Usage:
#   scripts/destroy-infra.sh                # full teardown: dev staging prod + shared ACR
#   scripts/destroy-infra.sh dev            # subset: only dev (shared ACR is KEPT,
#                                           # other environments still pull from it)
set -euo pipefail

if [[ $# -gt 0 ]]; then
  ENVIRONMENTS=("$@")
  DESTROY_SHARED=false # subset destroy: keep the shared ACR
else
  ENVIRONMENTS=(dev staging prod)
  DESTROY_SHARED=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIVE="$REPO_ROOT/infra/live"

# Destroy a unit only if it has local state (i.e. it was actually applied).
destroy_unit() {
  local dir="$1"
  if [[ -f "$dir/terraform.tfstate" ]]; then
    echo "    destroying $(basename "$(dirname "$dir")")/$(basename "$dir")"
    ( cd "$dir" && terragrunt destroy -auto-approve ) || echo "    (terragrunt destroy failed; the RG fallback below will clean up)"
  fi
}

echo "==> Checking Azure login"
az account show >/dev/null 2>&1 || { echo "ERROR: run 'az login' first."; exit 1; }

echo "==> Destroying environment units: ${ENVIRONMENTS[*]}"
for env in "${ENVIRONMENTS[@]}"; do
  destroy_unit "$LIVE/$env/vm-onprem-sim"
  destroy_unit "$LIVE/$env/container-app"
done

if [[ "$DESTROY_SHARED" == "true" ]]; then
  # Monitoring reuses the CAE's workspace, so tear it down before the CAE.
  echo "==> Destroying shared Application Insights"
  destroy_unit "$LIVE/shared/monitoring"
  echo "==> Destroying shared Container Apps environment"
  destroy_unit "$LIVE/shared/cae"
  echo "==> Destroying shared ACR"
  destroy_unit "$LIVE/shared/acr"
else
  echo "==> Keeping shared ACR + Container Apps environment + monitoring (subset destroy)"
fi

# Fallback: remove any resource groups that survived (orphans, partial applies),
# then drop the now-stale local state so the next apply starts clean.
echo "==> Cleaning up any leftover resource groups"
rgs=()
[[ "$DESTROY_SHARED" == "true" ]] && rgs+=("rg-weather-shared" "rg-weather-cae" "rg-weather-monitoring")
for env in "${ENVIRONMENTS[@]}"; do
  rgs+=("rg-weather-$env" "rg-weather-$env-onprem")
done
for rg in "${rgs[@]}"; do
  if [[ "$(az group exists --name "$rg")" == "true" ]]; then
    echo "    az group delete $rg"
    az group delete --name "$rg" --yes --no-wait || true
  fi
done

echo "==> Removing stale local Terraform state for destroyed units"
[[ "$DESTROY_SHARED" == "true" ]] && rm -f "$LIVE/shared/acr/terraform.tfstate"* "$LIVE/shared/cae/terraform.tfstate"* "$LIVE/shared/monitoring/terraform.tfstate"*
for env in "${ENVIRONMENTS[@]}"; do
  rm -f "$LIVE/$env/container-app/terraform.tfstate"* "$LIVE/$env/vm-onprem-sim/terraform.tfstate"*
done

echo "==> Teardown requested. RG deletions may still be finishing in the background."
echo "    Check with: az group list --query \"[?starts_with(name,'rg-weather')].name\" -o tsv"
