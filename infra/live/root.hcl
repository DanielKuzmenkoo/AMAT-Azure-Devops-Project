# Root Terragrunt config. Every live unit includes this to stay DRY:
# it generates the azurerm provider and wires the remote state backend so
# individual units only declare their own inputs.
#
# Authentication is via `az login` (Azure CLI). For Azure DevOps, the pipeline
# uses an ARM service connection instead — no credentials live in this repo.

locals {
  # ---- EDIT THESE before first use ----------------------------------------
  # Storage account names are GLOBALLY UNIQUE. Change `state_storage_account`
  # to something unique to you. See docs/terraform-terragrunt.md for the
  # one-time bootstrap that creates these resources.
  state_resource_group  = "rg-weather-tfstate"
  state_storage_account = "stweathertfstate" # <-- must be globally unique
  state_container       = "tfstate"
  default_location      = "westeurope"
  project               = "weather"
}

# Remote state in Azure Storage (one state file per unit, keyed by its path).
remote_state {
  backend = "azurerm"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    resource_group_name  = local.state_resource_group
    storage_account_name = local.state_storage_account
    container_name       = local.state_container
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Generate the provider in every unit. required_providers stays in each module's
# versions.tf, so we only configure the provider here (no duplicate blocks).
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
}
EOF
}

# Inputs shared by all units.
inputs = {
  location = local.default_location
  tags = {
    project   = local.project
    managedBy = "terragrunt"
  }
}
