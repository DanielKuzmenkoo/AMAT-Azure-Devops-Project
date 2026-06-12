# Environment-specific values for staging.
locals {
  environment  = "staging"
  location     = "swedencentral" # one CAE per region per subscription (free-tier quota); dev=northeurope, prod=uksouth
  min_replicas = 1
  max_replicas = 3
}
