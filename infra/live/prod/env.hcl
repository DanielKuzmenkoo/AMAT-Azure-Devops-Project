# Environment-specific values for prod.
locals {
  environment  = "prod"
  location     = "northeurope" # only used by the optional VM sim; Container Apps inherit the shared CAE's region (see infra/live/shared/cae)
  min_replicas = 2
  max_replicas = 5
}
