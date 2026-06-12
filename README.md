# Weather Azure DevOps Demo

A small, interview-focused weather application that demonstrates a clean backend
API, Docker packaging, automated tests, and an Azure DevOps CI/CD pipeline built
around a GitFlow branching model.

The app is intentionally minimal. The point is not the weather — it's showing
professional DevOps habits (containerization, testing, quality gates, release
discipline) without over-engineering.

## Project purpose

- Resolve a city name to a multi-day weather forecast.
- Hide third-party API details behind a clean backend contract.
- Run lint, tests, and a Docker build as CI quality gates.
- Build the image **once** and promote it across dev / staging / prod.
- Deploy the same image to either **Azure Container Apps** (cloud) or an
  **Azure VM via Ansible** (on-prem simulation).
- Provision infrastructure with **Terraform**, kept DRY with **Terragrunt**.
- Demonstrate GitFlow-driven deployments in Azure DevOps.
- Use **Open-Meteo** (no API key) so there are no secrets to manage in a demo.

> Deep-dive docs: [architecture](docs/architecture.md) ·
> [Terraform & Terragrunt](docs/terraform-terragrunt.md) ·
> [deployment](docs/deployment.md) ·
> [on-prem simulation](docs/onprem-simulation.md)

## Architecture

```text
            ┌──────────────┐        ┌─────────────────────────────┐
 Browser ──▶│  Frontend    │ ──────▶│        Backend (FastAPI)    │
 (city)     │ static HTML  │  /api  │  /api/health                │
            └──────────────┘        │  /api/locations?city=...    │
                                    │  /api/weather?city=...      │
                                    └───────────┬─────────────────┘
                                                │  (server-side only)
                            ┌───────────────────┴───────────────────┐
                            ▼                                        ▼
                 Open-Meteo Geocoding API                Open-Meteo Forecast API
                 (city → lat/lon/country/tz)             (forecast by coordinates)
```

- The frontend calls **only** the backend — never Open-Meteo directly.
- The backend resolves the city to coordinates, fetches the forecast, and
  returns a **normalized** response, so the frontend never sees raw upstream
  JSON.
- No database: the data is read-through from Open-Meteo and is not persisted.

The same Docker image is built once, pushed to a **shared** Azure Container
Registry, and promoted across environments to either Azure Container Apps or a
VM. See [docs/architecture.md](docs/architecture.md) for the full diagram.

### Layout

```text
app/                      # FastAPI app, tests, Dockerfile
azure-pipelines.yml       # CI/CD pipeline (validate → build/push → deploy)
.azure/                   # reusable deploy job templates (ACA, VM)
infra/
├── modules/              # Terraform: acr, container-app, vm-onprem-sim
└── live/                 # Terragrunt: root.hcl, shared/acr, dev|staging|prod
ansible/
├── playbooks/            # deploy-weather-app.yml (VM / on-prem sim)
└── inventories/          # dev|staging|prod.ini templates
docs/                     # architecture, terraform-terragrunt, deployment, onprem
CLAUDE.md                 # project spec / design notes
```

## API contract

| Method & path | Description |
|---|---|
| `GET /api/health` | Liveness check. Returns `{"status": "ok"}`. |
| `GET /api/locations?city=<city>` | Candidate locations (name, country, lat, lon, timezone). |
| `GET /api/weather?city=<city>` | Normalized 7–14 day forecast for the best-matched city. |

Errors share a single shape: `{"error": "<message>"}`.

| Situation | Status |
|---|---|
| Missing / empty `city` | `400` |
| City not found (no geocoding match) | `404` |
| Upstream timeout | `504` |
| Upstream unavailable / bad response | `502` |
| Unexpected error | `500` (no stack traces leaked) |

### Examples

```bash
# Health
curl http://localhost:8000/api/health
# {"status":"ok"}

# Locations
curl "http://localhost:8000/api/locations?city=Berlin"

# Weather (normalized forecast)
curl "http://localhost:8000/api/weather?city=Berlin"
```

Example weather response (truncated):

```json
{
  "location": {
    "name": "Berlin", "country": "Germany",
    "latitude": 52.52, "longitude": 13.41, "timezone": "Europe/Berlin"
  },
  "forecast_days": 14,
  "forecast": [
    {
      "date": "2026-06-12",
      "weather_code": 80,
      "condition": "Slight rain showers",
      "temperature_max_c": 17.1,
      "temperature_min_c": 11.4,
      "humidity_pct": 71.5,
      "precipitation_probability_pct": 63.0,
      "wind_speed_max_kmh": 15.1
    }
  ]
}
```

## Configuration

All configuration is via environment variables (no secrets required):

| Variable | Default | Purpose |
|---|---|---|
| `FORECAST_DAYS` | `14` | Forecast length (clamped to 7–14). |
| `GEOCODING_API_BASE_URL` | `https://geocoding-api.open-meteo.com/v1` | Geocoding base URL. |
| `WEATHER_API_BASE_URL` | `https://api.open-meteo.com/v1` | Forecast base URL. |
| `HTTP_TIMEOUT_SECONDS` | `5` | Upstream HTTP timeout. |

## Run locally (Python, for development)

Requires Python 3.12+.

```bash
cd app
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
uvicorn src.main:app --reload      # serves the frontend at http://localhost:8000/

ruff check src tests               # lint
pytest -q                          # tests
```

## Running the App

Three ways to run/deploy. **Option 1 needs only Docker.** Options 2–3 need the
[Prerequisites](#prerequisites) below. Full detail in
[docs/deployment.md](docs/deployment.md).

### Option 1: Run locally with Docker

```bash
git clone <this-repo-url>
cd AMAT-Azure-Devops-Project/app

docker build -t weather-api .
docker run --rm -p 8000:8000 weather-api    # open http://localhost:8000/
```

The container listens on **port 8000**, runs as a non-root user, and has a
`HEALTHCHECK` on `/api/health`. **No Open-Meteo API key is required.**

```bash
curl "http://localhost:8000/api/health"
curl "http://localhost:8000/api/locations?city=Tel%20Aviv"
curl "http://localhost:8000/api/weather?city=Tel%20Aviv"
```

### Option 2: Deploy to Azure Container Apps (preferred cloud path)

Azure Container Apps is the managed, ECS-equivalent container runtime. Azure
Container Registry stores the image; **Terraform/Terragrunt** create the
infrastructure; **Azure DevOps** builds the image, pushes it to ACR, and deploys
the selected environment.

```text
Clone repo
  → install prerequisites
  → az login
  → select Azure subscription
  → bootstrap Terraform state if needed        (docs/terraform-terragrunt.md)
  → deploy shared ACR with Terragrunt
  → deploy dev/staging/prod Container Apps infrastructure
  → run the Azure DevOps pipeline (or deploy the image manually)
```

Deploy the shared registry first, then each environment:

```bash
cd infra/live/shared/acr
terragrunt init && terragrunt plan && terragrunt apply
terragrunt output        # acr_name, acr_login_server
```

```bash
cd infra/live/dev/container-app          # repeat for staging, prod
terragrunt init && terragrunt plan && terragrunt apply
terragrunt output app_url
```

The exact ACR name and app URLs come from Terraform/Terragrunt outputs
(`terragrunt output`) — do not hardcode them.

### Option 3: Deploy to VM / on-prem simulation with Ansible

Terraform can optionally create an Azure Linux VM that represents an
on-prem-compatible target. Ansible installs Docker and runs the **same** image,
proving the artifact is portable between managed cloud and a VM/on-prem host.

```text
Deploy VM infrastructure
  → get VM public IP (terragrunt output vm_public_ip)
  → update Ansible inventory with the IP/SSH user
  → run the Ansible playbook
  → access the app through the VM IP and exposed port
```

```bash
export WEATHER_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
cd infra/live/dev/vm-onprem-sim
terragrunt init && terragrunt plan && terragrunt apply
terragrunt output vm_public_ip
```

```bash
# Edit ansible/inventories/dev.ini: set the VM IP, SSH user, and app_image.
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook -i ansible/inventories/dev.ini \
  ansible/playbooks/deploy-weather-app.yml \
  -e app_image="<acr-login-server>/weather-api:<tag>"
# open http://<VM_PUBLIC_IP>:8000/
```

The inventory files (`ansible/inventories/{dev,staging,prod}.ini`) are templates:
you must set the VM IP/SSH user. See
[docs/onprem-simulation.md](docs/onprem-simulation.md).

## Prerequisites

Needed only for the Azure paths (options 2–3). Option 1 needs just Docker + Git.

### Local prerequisites

Git · Docker · Azure CLI · Terraform · Terragrunt · Ansible · SSH client.

```bash
sudo apt update
sudo apt install -y \
  curl wget unzip git gnupg lsb-release \
  ca-certificates apt-transport-https software-properties-common openssh-client
```

#### Install Azure CLI

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az version

az login
az account list --output table
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --output table

az extension add --name containerapp --upgrade
```

#### Install Terraform

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform
terraform version
```

#### Install Terragrunt

```bash
TERRAGRUNT_VERSION="v0.93.10"   # replace with the latest release if outdated
curl -L "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
  -o /tmp/terragrunt
sudo install -m 0755 /tmp/terragrunt /usr/local/bin/terragrunt
terragrunt --version
```

#### Install Ansible

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv sshpass
python3 -m pip install --user ansible
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
ansible --version
```

#### Docker permissions

```bash
docker version && docker ps
# If permission is denied:
sudo usermod -aG docker "$USER" && newgrp docker && docker ps
```

### Azure prerequisites

- An Azure subscription, and `az login` with the right subscription selected.
- Permission to create resource groups and resources, specifically: Azure
  Container Registry, Container Apps + Container Apps Environment, Log Analytics
  workspace, Linux VM resources (if using the VM path), and a Storage Account
  (for remote Terraform state).
- Permission for **role assignments** (the Container App uses a managed identity
  granted `AcrPull` on the registry).

For local Terraform/Terragrunt, Azure CLI login is enough — no service principal
is required:

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

### Azure DevOps prerequisites

- An Azure DevOps project with the GitHub repo connected to Azure Pipelines.
- An **Azure Resource Manager** service connection (referenced by
  `azureServiceConnection`).
- ACR access via that service connection / documented `az acr login` flow.
- Pipeline variables for: the Azure service connection name, ACR name / login
  server, image repository name, and (for the VM path) the SSH key as a secure
  file plus VM connection info.

The shared ACR must exist **before** the pipeline can push images:

```text
Deploy shared ACR with Terragrunt first
  → configure Azure DevOps variables / service connection
  → run the pipeline build & push
  → deploy to Azure Container Apps or the VM
```

## CI/CD flow (Azure DevOps)

One readable pipeline ([azure-pipelines.yml](azure-pipelines.yml)) on a
Microsoft-hosted agent (`ubuntu-latest`), plus two small deploy-job templates in
[.azure/](.azure/):

1. **Validate** (every PR and push): **lint** (ruff) → **tests** (pytest) →
   **Docker build validation**.
2. **BuildPush** (non-PR): build the image **once**, push to ACR tagged with the
   build id **and** commit SHA — production never deploys `latest`.
3. **Deploy**: deploy the pushed image to the selected environment and target.

Run-time parameters:

| Parameter | Values | Meaning |
|---|---|---|
| `deployTarget` | `aca`, `vm` | Container Apps (cloud) or VM (Ansible) |
| `environmentName` | `auto`, `dev`, `staging`, `prod` | `auto` derives from the branch |

Branch defaults when `environmentName = auto`:

| Branch | Environment |
|---|---|
| `develop` | dev |
| `release/*` | staging |
| `main` | prod (manual approval) |
| `hotfix/*` | prod (urgent; manual approval) |

PRs run **Validate only**. Prod approval is a check on the `weather-prod`
environment (Azure DevOps UI). ACR pulls use a managed identity (ACA) or a
short-lived token (VM); the VM SSH key is an Azure DevOps secure file — no
secrets are hardcoded.

## GitFlow

| Branch | Role |
|---|---|
| `main` | Production-ready. Tagged releases (`v1.0.0`). Deploys to **prod** (with approval). |
| `develop` | Active integration. Deploys to **dev**. |
| `feature/*` | New work, branched from `develop`, merged back via PR. |
| `release/*` | Stabilization before a release; deploys to **staging**; merged to `main` and back to `develop`. |
| `hotfix/*` | Urgent production fixes from `main`; deploys to **prod** (with approval); merged to `main` and `develop`. |

Rules: no direct commits to `main`/`develop`; all merges via PR; CI must pass
before merge; releases use semantic versioning.

```text
feature/* ──▶ develop ──▶ release/* ──▶ main
                  ▲                       │
                  └──────── hotfix/* ◀────┘
```

### Deploy-on-merge

Merging (i.e. pushing) to a long-lived branch triggers the matching environment
deploy automatically (`environmentName = auto`):

| Merge into | Deploys to |
|---|---|
| `develop` | **dev** |
| `release/*` | **staging** |
| `main` | **prod** (after manual approval) |

### Versioning & releases

Releases use semantic versioning, tagged on `main`. The current release is
**`v1.0.0`**; the next minor release will be **`v1.1.0`**.

A release goes: cut `release/v1.1.0` from `develop` → stabilize → merge to
`main` → **tag `v1.1.0`** → merge back to `develop`.

```bash
# on develop, when ready to release the next minor version
git switch -c release/v1.1.0 develop      # stabilize here (staging deploys)

# after the release PR is merged into main:
git switch main && git pull
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0                     # main deploy -> prod (with approval)

git switch develop && git merge --no-ff main && git push   # keep develop in sync
```

A patch release (e.g. from a `hotfix/*`) bumps the patch number: `v1.0.1`.

## Interview talking points

- **Small on purpose.** A tiny app keeps the focus on the DevOps flow, which is
  what the pipeline and branching model demonstrate.
- **Clean layering.** Routes → service → HTTP client → schemas. The client is
  the only thing that talks to Open-Meteo, which makes it trivial to mock in
  tests.
- **Contract isolation.** The backend normalizes upstream JSON, so the frontend
  depends on a stable shape, not on Open-Meteo's structure.
- **No secrets.** Open-Meteo needs no API key, so there's no secret management
  to distract from the demo — and CI/local dev stay identical.
- **Real quality gates.** Lint + tests + Docker build run on every PR; prod
  deploys require a manual approval — release discipline without complexity.
- **Build once, promote.** One image is built, pushed to a shared ACR, and
  promoted by tag across dev → staging → prod — what you tested is what ships.
- **Cloud or on-prem, same image.** Azure Container Apps is the managed cloud
  runtime; the VM + Ansible path runs the identical image to prove on-prem
  portability — no AKS/Kubernetes needed.
- **DRY infrastructure.** Terraform modules + Terragrunt keep dev/staging/prod
  readable with environment values in one place (`env.hcl`).
- **Honest scope.** No database, no Kubernetes, no service mesh, no Key Vault —
  there's no secret to store and no state to persist, so they'd be
  over-engineering.
