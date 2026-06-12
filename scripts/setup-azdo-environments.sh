#!/usr/bin/env bash
#
# Create the Azure DevOps Environments the pipeline deploys to
# (weather-dev, weather-staging, weather-prod). Idempotent: existing
# environments are left untouched.
#
# These environments give the pipeline deployment history, per-environment
# authorization, and the prod manual-approval gate. They must exist before the
# deployment jobs in azure-pipelines.yml can run.
#
# Usage:
#   AZDO_ORG=myorg AZDO_PROJECT="My Project" AZDO_PAT=xxxxx \
#     scripts/setup-azdo-environments.sh
#
#   # or with flags:
#   scripts/setup-azdo-environments.sh --org myorg --project "My Project" --pat xxxxx
#
# The PAT needs the "Environment (Read & manage)" scope.
# Note: the prod approval check is added in the UI (see the reminder printed at
# the end) — the checks REST API is intentionally not automated here.
set -euo pipefail

API_VERSION="7.1-preview.1"
ENVIRONMENTS=("weather-dev" "weather-staging" "weather-prod")

ORG="${AZDO_ORG:-}"
PROJECT="${AZDO_PROJECT:-}"
PAT="${AZDO_PAT:-}"

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)     ORG="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --pat)     PAT="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown argument: $1" >&2; usage 1 ;;
  esac
done

missing=()
[[ -z "$ORG" ]]     && missing+=("AZDO_ORG/--org")
[[ -z "$PROJECT" ]] && missing+=("AZDO_PROJECT/--project")
[[ -z "$PAT" ]]     && missing+=("AZDO_PAT/--pat")
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing required values: ${missing[*]}" >&2
  usage 1
fi

# URL-encode the project name (it may contain spaces).
project_enc=$(printf '%s' "$PROJECT" | sed 's/ /%20/g')
base="https://dev.azure.com/${ORG}/${project_enc}/_apis/distributedtask/environments?api-version=${API_VERSION}"

echo "Org: $ORG   Project: $PROJECT"

# Fetch existing environment names once.
existing=$(curl -sS -u ":$PAT" "$base" | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/' || true)

for env in "${ENVIRONMENTS[@]}"; do
  if grep -qx "$env" <<<"$existing"; then
    echo "  = $env (already exists)"
    continue
  fi
  http_code=$(curl -sS -o /dev/null -w '%{http_code}' \
    -u ":$PAT" -H "Content-Type: application/json" \
    -d "{\"name\":\"$env\",\"description\":\"Weather app ${env#weather-} environment\"}" \
    "$base")
  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "  + $env (created)"
  else
    echo "  ! $env (failed, HTTP $http_code) — check the PAT scope and project name" >&2
    exit 1
  fi
done

cat <<'EOF'

Done. Next:
  - Add a manual-approval check on 'weather-prod':
      Azure DevOps -> Pipelines -> Environments -> weather-prod
        -> ... -> Approvals and checks -> + -> Approvals -> add approver(s)
  - Re-run the pipeline. If a stage prompts to "Permit" the environment on first
    use, approve it.
EOF
