# Root Terragrunt config. Every live unit includes this to stay DRY:
# it generates the azurerm provider and wires the remote state backend so
# individual units only declare their own inputs.
#
# Authentication is via `az login` (Azure CLI). For Azure DevOps, the pipeline
# uses an ARM service connection instead — no credentials live in this repo.

locals {
  default_location = "westeurope"
  project          = "weather"
}

# Local state — simplest path to get the demo running (no storage-account
# bootstrap). State lives next to each unit and is gitignored.
# For a shared/team or production setup, switch this to an Azure Storage
# (azurerm) backend — see docs/terraform-terragrunt.md.
remote_state {
  backend = "local"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    path = "${get_terragrunt_dir()}/terraform.tfstate"
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
