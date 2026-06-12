# Environment-specific values for prod.
locals {
  environment  = "prod"
  location     = "westeurope"
  min_replicas = 2
  max_replicas = 5
}
