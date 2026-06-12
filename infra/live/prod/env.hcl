# Environment-specific values for prod.
locals {
  environment  = "prod"
  location     = "uksouth" # one CAE per region per subscription (free-tier quota); dev=northeurope, staging=swedencentral
  min_replicas = 2
  max_replicas = 5
}
