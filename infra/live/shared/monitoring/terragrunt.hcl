# Shared Application Insights — deploy AFTER the shared CAE (it reuses the CAE's
# Log Analytics workspace) and BEFORE the per-environment apps (they consume its
# connection string). One AI serves dev/staging/prod; environments are separated
# by OpenTelemetry cloud role name (set on each Container App).

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules//monitoring"
}

# Reuse the shared CAE's Log Analytics workspace. Mock lets plan/validate/destroy
# run before the CAE exists.
dependency "cae" {
  config_path = "../cae"

  mock_outputs = {
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-weather-cae/providers/Microsoft.OperationalInsights/workspaces/log-weather-shared"
    location                   = "northeurope"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate", "destroy"]
}

inputs = {
  name                       = "appi-weather"
  resource_group_name        = "rg-weather-monitoring"
  location                   = dependency.cae.outputs.location
  log_analytics_workspace_id = dependency.cae.outputs.log_analytics_workspace_id
  # Set an email to enable the action group + metric alerts (optional).
  alert_email = ""
}
