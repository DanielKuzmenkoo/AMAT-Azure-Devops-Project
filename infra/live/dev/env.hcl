# Environment-specific values for dev. Read by units in this folder so
# environment differences live in one place.
locals {
  environment  = "dev"
  location     = "northeurope"
  min_replicas = 1
  max_replicas = 2
}
