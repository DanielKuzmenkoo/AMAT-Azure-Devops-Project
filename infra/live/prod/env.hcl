# Environment-specific values for prod.
locals {
  environment  = "prod"
  location     = "northeurope"
  min_replicas = 2
  max_replicas = 5
}
