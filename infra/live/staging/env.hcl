# Environment-specific values for staging.
locals {
  environment  = "staging"
  location     = "northeurope"
  min_replicas = 1
  max_replicas = 3
}
