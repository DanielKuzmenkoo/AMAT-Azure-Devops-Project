# Environment-specific values for dev. Read by units in this folder so
# environment differences live in one place.
locals {
  environment  = "dev"
  location     = "northeurope" # only used by the optional VM sim; Container Apps inherit the shared CAE's region (see infra/live/shared/cae)
  min_replicas = 1
  max_replicas = 2
}
