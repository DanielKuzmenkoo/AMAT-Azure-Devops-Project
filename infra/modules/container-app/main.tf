# Azure Container Apps deployment for one environment.
#
# Container Apps is used as the managed, serverless container runtime
# (the "ECS-equivalent") so we get HTTPS ingress, scaling, and health probes
# without running or patching any Kubernetes.

resource "azurerm_resource_group" "env" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-weather-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = azurerm_resource_group.env.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

# User-assigned identity created first, granted AcrPull, then attached to the
# app. This ordering avoids the chicken-and-egg of a system-assigned identity.
resource "azurerm_user_assigned_identity" "aca" {
  name                = "id-weather-${var.environment}"
  resource_group_name = azurerm_resource_group.env.name
  location            = azurerm_resource_group.env.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aca.principal_id
}

resource "azurerm_container_app_environment" "cae" {
  name                       = "cae-weather-${var.environment}"
  resource_group_name        = azurerm_resource_group.env.name
  location                   = azurerm_resource_group.env.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  tags                       = var.tags
}

resource "azurerm_container_app" "app" {
  name                         = var.container_app_name
  resource_group_name          = azurerm_resource_group.env.name
  container_app_environment_id = azurerm_container_app_environment.cae.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aca.id]
  }

  # Pull from the shared ACR using the managed identity (no stored secrets).
  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.aca.id
  }

  ingress {
    external_enabled = true
    target_port      = var.app_port
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "weather-api"
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      env {
        name  = "FORECAST_DAYS"
        value = tostring(var.forecast_days)
      }
      env {
        name  = "GEOCODING_API_BASE_URL"
        value = var.geocoding_api_base_url
      }
      env {
        name  = "WEATHER_API_BASE_URL"
        value = var.weather_api_base_url
      }
      env {
        name  = "HTTP_TIMEOUT_SECONDS"
        value = tostring(var.http_timeout_seconds)
      }

      liveness_probe {
        transport = "HTTP"
        port      = var.app_port
        path      = "/api/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.app_port
        path      = "/api/health"
      }
    }
  }

  # Ensure the identity can pull before the app tries its first image pull.
  depends_on = [azurerm_role_assignment.acr_pull]

  # The pipeline promotes new tags with `az containerapp update`; var.image is
  # only the bootstrap baseline. Ignore image drift so a later `terragrunt
  # apply` never rolls an environment back to that baseline.
  lifecycle {
    ignore_changes = [template[0].container[0].image]
  }
}
