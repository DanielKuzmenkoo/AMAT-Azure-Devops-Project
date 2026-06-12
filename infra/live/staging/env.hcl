# Environment-specific values for staging.
locals {
  environment  = "staging"
  location     = "northeurope" # only used by the optional VM sim; Container Apps inherit the shared CAE's region (see infra/live/shared/cae)
  min_replicas = 1
  max_replicas = 3
}
