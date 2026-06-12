# Infrastructure

Terraform modules wrapped by Terragrunt to provision Azure for the weather app.

```text
infra/
├── modules/                # Reusable Terraform modules
│   ├── acr/                # Shared Azure Container Registry
│   ├── container-app-env/  # Shared Container Apps environment (one per sub)
│   ├── container-app/      # Per-env app + identity + AcrPull (joins the CAE)
│   └── vm-onprem-sim/      # Optional Linux VM (on-prem simulation)
└── live/                   # Terragrunt environments (DRY)
    ├── root.hcl            # provider + remote-state backend (included everywhere)
    ├── shared/acr/         # the one shared registry (deploy FIRST)
    ├── shared/cae/         # the one shared Container Apps env (deploy SECOND)
    ├── dev/                # env.hcl + container-app/ + vm-onprem-sim/
    ├── staging/            # env.hcl + container-app/ + vm-onprem-sim/
    └── prod/               # env.hcl + container-app/ + vm-onprem-sim/
```

The same image is built once, stored in the shared ACR, and promoted across
dev → staging → prod to either Azure Container Apps (cloud) or a VM (on-prem
sim). dev/staging/prod run as three separate Container Apps inside **one shared
Container Apps environment** — the subscription is capped at a single CAE on the
free/trial tier — each with its own resource group, managed identity, URL, and
scaling. See [../docs/terraform-terragrunt.md](../docs/terraform-terragrunt.md) for
the state bootstrap and apply order, and
[../docs/deployment.md](../docs/deployment.md) for the deployment flow.

Intentionally excluded: AKS, Kubernetes, service mesh, database, Key Vault —
there is no secret to store and no state to persist.
