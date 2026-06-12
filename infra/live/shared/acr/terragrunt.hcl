# Shared Azure Container Registry — deploy this FIRST.
# Container App and VM units depend on its outputs.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules//acr"
}

inputs = {
  resource_group_name = "rg-weather-shared"
  # ACR name must be globally unique and alphanumeric. EDIT before applying.
  acr_name = "acrweathershared"
  sku      = "Standard"
}
