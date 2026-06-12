# Shared Container Apps managed environment — deploy AFTER the ACR and BEFORE
# the per-environment apps.
#
# The subscription allows only ONE Container Apps environment (free/trial cap),
# so dev/staging/prod each run as a separate Container App inside this single
# shared environment. Every app must run in this environment's region.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules//container-app-env"
}

inputs = {
  name                = "cae-weather"
  resource_group_name = "rg-weather-cae"
  location            = "northeurope"
}
