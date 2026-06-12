# Deployment

Three ways to run the app. Option 1 needs only Docker; options 2–3 need Azure.

## Option 1 — Local Docker

```bash
cd app
docker build -t weather-api .
docker run --rm -p 8000:8000 weather-api
# open http://localhost:8000/  (no API key required)
```

## Option 2 — Azure Container Apps (preferred cloud path)

Build once, push to the shared ACR, deploy the same image per environment.

1. Bootstrap state and deploy the shared ACR — see
   [terraform-terragrunt.md](terraform-terragrunt.md).
2. Deploy the environment's Container App infra (`infra/live/<env>/container-app`).
3. Build & push the image, then point the Container App at the new tag:

```bash
ACR=$(cd infra/live/shared/acr && terragrunt output -raw acr_login_server)
ACR_NAME=$(cd infra/live/shared/acr && terragrunt output -raw acr_name)
TAG=$(git rev-parse --short HEAD)

az acr login --name "$ACR_NAME"
docker build -t "$ACR/weather-api:$TAG" app
docker push "$ACR/weather-api:$TAG"

az containerapp update \
  --name ca-weather-dev \
  --resource-group rg-weather-dev \
  --image "$ACR/weather-api:$TAG"

cd infra/live/dev/container-app && terragrunt output app_url
```

In CI this is done by the pipeline (see [CI/CD](#cicd)).

## Option 3 — VM / on-prem simulation (Ansible)

The same image, run with plain Docker on an Azure VM.

1. Deploy the VM (`infra/live/<env>/vm-onprem-sim`) and get its IP.
2. Put the IP and image into `ansible/inventories/<env>.ini`.
3. Run the playbook:

```bash
ansible-galaxy collection install -r ansible/requirements.yml

ACR=$(cd infra/live/shared/acr && terragrunt output -raw acr_login_server)
ansible-playbook -i ansible/inventories/dev.ini \
  ansible/playbooks/deploy-weather-app.yml \
  -e app_image="$ACR/weather-api:$(git rev-parse --short HEAD)"
# open http://<VM_PUBLIC_IP>:8000/
```

For a private image, also pass ACR credentials (e.g. a short-lived token):

```bash
TOKEN=$(az acr login --name "$ACR_NAME" --expose-token --query accessToken -o tsv)
ansible-playbook ... \
  -e acr_login_server="$ACR" \
  -e acr_username=00000000-0000-0000-0000-000000000000 \
  -e acr_password="$TOKEN"
```

See [onprem-simulation.md](onprem-simulation.md) for details.

## CI/CD

`azure-pipelines.yml` (Microsoft-hosted `ubuntu-latest`):

1. **Validate** — lint (ruff), tests (pytest), Docker build. Runs on every PR
   and push.
2. **BuildPush** — build the image once, push to ACR tagged with the build id
   **and** the commit SHA (never deploy `latest`).
3. **Deploy** — deploy the pushed image to the selected environment and target.

Parameters (selectable on manual run):

| Parameter | Values | Meaning |
|---|---|---|
| `deployTarget` | `aca`, `vm` | Cloud (Container Apps) or VM (Ansible) |
| `environmentName` | `auto`, `dev`, `staging`, `prod` | `auto` derives from branch |

Branch defaults when `environmentName = auto`:

| Branch | Environment |
|---|---|
| `develop` | dev |
| `release/*` | staging |
| `main` | prod (manual approval) |
| `hotfix/*` | prod (urgent; manual approval) |

The two deploy paths are small templates: `.azure/deploy-aca.yml` and
`.azure/deploy-vm.yml`. Prod approval is configured on the `weather-prod`
environment in the Azure DevOps UI. Secrets (SSH key) come from an Azure DevOps
**secure file**; ACR pulls use managed identity (ACA) or a short-lived token
(VM) — nothing is hardcoded.
