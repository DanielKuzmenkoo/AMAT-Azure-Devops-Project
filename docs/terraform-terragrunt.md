# Terraform & Terragrunt

## Layout

```text
infra/
├── modules/                      # Reusable Terraform modules
│   ├── acr/                      # Shared Azure Container Registry
│   ├── container-app-env/        # Shared Container Apps environment (CAE + logs)
│   ├── container-app/            # Per-env app + managed identity + AcrPull
│   └── vm-onprem-sim/            # Optional Linux VM (on-prem simulation)
└── live/                         # Terragrunt environments (DRY wrappers)
    ├── root.hcl                  # Backend + provider, included everywhere
    ├── shared/acr/               # The one shared registry (deploy FIRST)
    ├── shared/cae/               # The one shared Container Apps env (deploy SECOND)
    ├── dev/      { env.hcl, container-app/, vm-onprem-sim/ }
    ├── staging/  { env.hcl, container-app/, vm-onprem-sim/ }
    └── prod/     { env.hcl, container-app/, vm-onprem-sim/ }
```

- **`root.hcl`** generates the `azurerm` provider and wires the remote state
  backend, so each unit only declares its own `inputs`.
- **`env.hcl`** (per environment) holds environment-specific values
  (`environment`, `location`, replica counts) read by that environment's units.
- **`dependency "acr"` / `dependency "cae"`** let `container-app` consume the
  shared registry and the shared Container Apps environment outputs;
  `mock_outputs` allow `plan`/`validate`/`destroy` before they exist.
- **One CAE per subscription.** The free/trial tier caps the subscription at a
  single Container Apps environment, so it lives in `shared/cae` and all three
  environments' apps join it. They stay isolated by resource group and managed
  identity, and every app runs in the CAE's region.

> Note: each environment uses `rg-weather-<env>` for the Container App and a
> separate `rg-weather-<env>-onprem` for the optional VM, so the two units never
> fight over the same resource group state.

## One-time bootstrap (remote state)

Terragrunt stores state in an Azure Storage Account. Create it once. **Storage
account names are globally unique — edit the name first** (also update
`state_storage_account` in `infra/live/root.hcl`):

```bash
az group create --name rg-weather-tfstate --location westeurope

az storage account create \
  --name stweathertfstate \
  --resource-group rg-weather-tfstate \
  --sku Standard_LRS --encryption-services blob

az storage container create \
  --name tfstate \
  --account-name stweathertfstate
```

Authentication for local runs is just Azure CLI:

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
```

## Deploy order

Deploy the shared ACR first (other units depend on it):

```bash
cd infra/live/shared/acr
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output            # acr_name, acr_login_server, resource_group_name
```

Then the shared Container Apps environment (all apps join this one CAE):

```bash
cd infra/live/shared/cae
terragrunt apply
terragrunt output container_app_environment_id
```

Then an environment's Container App (repeat for staging/prod):

```bash
cd infra/live/dev/container-app
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output app_url
```

Optionally the VM (on-prem sim). Provide your SSH public key first:

```bash
export WEATHER_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)"
export WEATHER_SSH_CIDR="$(curl -s ifconfig.me)/32"   # restrict SSH to your IP

cd infra/live/dev/vm-onprem-sim
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output vm_public_ip
```

## Outputs the pipeline / Ansible need

| Output | From | Used by |
|---|---|---|
| `acr_name`, `acr_login_server` | `shared/acr` | pipeline build/push & deploy |
| `app_url` | `*/container-app` | smoke-testing the cloud deploy |
| `vm_public_ip` | `*/vm-onprem-sim` | Ansible inventory host |

## Conventions / guardrails

- Provider pinned to `azurerm ~> 3.116`; `required_providers` lives in each
  module's `versions.tf` (the generated provider block only configures it).
- Image promotion: the module's `image` input is a baseline; the pipeline
  promotes a specific tag via `az containerapp update` rather than re-applying
  Terraform on every release.
- No AKS, no Key Vault, no service mesh — there are no secrets and no cluster.
