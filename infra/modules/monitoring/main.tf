# Application Insights for the weather app (Azure-native observability).
#
# One workspace-based Application Insights, backed by the shared Log Analytics
# workspace that the Container Apps environment already uses. The Container Apps
# send OpenTelemetry traces/metrics/logs here (request rate, latency, failures,
# exceptions, and the Open-Meteo dependency calls). Environments are separated by
# OpenTelemetry cloud role name (OTEL_SERVICE_NAME = weather-<env>), so a single
# resource serves dev/staging/prod. The pipeline also writes deployment events
# here for DORA-style metrics.
#
# No VMs and nothing to run: collection is serverless and reuses existing infra.

resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_application_insights" "ai" {
  name                = var.name
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = azurerm_resource_group.monitoring.location
  application_type    = "web"
  # Workspace-based AI: telemetry lands in the shared CAE workspace (cross-RG ref).
  workspace_id = var.log_analytics_workspace_id
  # NOTE: for workspace-based AI, data retention is governed by the Log Analytics
  # workspace, not this field. Kept for clarity; the effective retention is the
  # workspace's (log_analytics_retention_days on the shared CAE).
  retention_in_days = var.retention_in_days
  tags              = var.tags
}

# --- Optional alerting -------------------------------------------------------
# Only created when an alert_email is provided, so the demo provisions cleanly
# with no email and you can opt into notifications by setting one value.

resource "azurerm_monitor_action_group" "email" {
  count               = var.alert_email == "" ? 0 : 1
  name                = "ag-weather-email"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "weather"

  email_receiver {
    name          = "ops"
    email_address = var.alert_email
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "failed_requests" {
  count               = var.alert_email == "" ? 0 : 1
  name                = "alert-weather-failed-requests"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_application_insights.ai.id]
  description         = "Server-side failed requests over threshold."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "requests/failed"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.email[0].id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "server_exceptions" {
  count               = var.alert_email == "" ? 0 : 1
  name                = "alert-weather-server-exceptions"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_application_insights.ai.id]
  description         = "Unhandled server exceptions over threshold."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "microsoft.insights/components"
    metric_name      = "exceptions/server"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = azurerm_monitor_action_group.email[0].id
  }

  tags = var.tags
}
