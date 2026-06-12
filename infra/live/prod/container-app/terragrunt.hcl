include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../modules//container-app"
}

dependency "acr" {
  config_path = "../../shared/acr"

  mock_outputs = {
    acr_login_server = "acrweathershared.azurecr.io"
    acr_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-weather-shared/providers/Microsoft.ContainerRegistry/registries/acrweathershared"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

inputs = {
  environment         = local.env.locals.environment
  location            = local.env.locals.location
  resource_group_name = "rg-weather-${local.env.locals.environment}"
  container_app_name  = "ca-weather-${local.env.locals.environment}"

  acr_login_server = dependency.acr.outputs.acr_login_server
  acr_id           = dependency.acr.outputs.acr_id
  image            = "${dependency.acr.outputs.acr_login_server}/weather-api:latest"

  min_replicas = local.env.locals.min_replicas
  max_replicas = local.env.locals.max_replicas
}
