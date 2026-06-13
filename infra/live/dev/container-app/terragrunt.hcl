include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../modules//container-app"
}

# Pull ACR details from the shared registry unit. Mock values let
# `plan`/`validate`/`destroy` run before the ACR actually exists.
dependency "acr" {
  config_path = "../../shared/acr"

  mock_outputs = {
    acr_login_server = "acrweathershared.azurecr.io"
    acr_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-weather-shared/providers/Microsoft.ContainerRegistry/registries/acrweathershared"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
}

# Join the single shared Container Apps environment (one CAE per subscription on
# the free tier). The app's region must match the environment's region, so
# location comes from here rather than env.hcl. Mocks also cover `destroy` so the
# app can be torn down before the shared CAE unit exists.
dependency "cae" {
  config_path = "../../shared/cae"

  mock_outputs = {
    container_app_environment_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-weather-cae/providers/Microsoft.App/managedEnvironments/cae-weather"
    location                     = "northeurope"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
}

# Application Insights connection string for app telemetry. Mock lets
# plan/validate/destroy run before monitoring exists; an empty/real string both
# work (empty disables telemetry in the app).
dependency "monitoring" {
  config_path = "../../shared/monitoring"

  mock_outputs = {
    connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=https://example.invalid/"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
}

inputs = {
  environment         = local.env.locals.environment
  location            = dependency.cae.outputs.location
  resource_group_name = "rg-weather-${local.env.locals.environment}"
  container_app_name  = "ca-weather-${local.env.locals.environment}"

  container_app_environment_id = dependency.cae.outputs.container_app_environment_id

  acr_login_server = dependency.acr.outputs.acr_login_server
  acr_id           = dependency.acr.outputs.acr_id
  # Baseline image; the pipeline promotes a specific tag via `az containerapp update`.
  image = "${dependency.acr.outputs.acr_login_server}/weather-api:latest"

  app_insights_connection_string = dependency.monitoring.outputs.connection_string

  min_replicas = local.env.locals.min_replicas
  max_replicas = local.env.locals.max_replicas
}
