include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../../modules//vm-onprem-sim"
}

inputs = {
  environment         = local.env.locals.environment
  location            = local.env.locals.location
  resource_group_name = "rg-weather-${local.env.locals.environment}-onprem"
  vm_name             = "vm-weather-${local.env.locals.environment}"

  ssh_public_key   = get_env("WEATHER_SSH_PUBLIC_KEY", "")
  allowed_ssh_cidr = get_env("WEATHER_SSH_CIDR", "*")
}
