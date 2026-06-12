# Shared Azure Container Apps managed environment.
#
# The subscription is capped at ONE Container Apps environment
# (free/trial tier: MaxNumberOfGlobalEnvironmentsInSubExceeded), so
# dev/staging/prod run as separate Container Apps INSIDE this single shared
# environment rather than each owning its own. Deploy this once, after the ACR
# and before the per-environment apps. All apps that use it must run in this
# environment's region.

resource "azurerm_resource_group" "cae" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = var.log_analytics_name
  resource_group_name = azurerm_resource_group.cae.name
  location            = azurerm_resource_group.cae.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

resource "azurerm_container_app_environment" "cae" {
  name                       = var.name
  resource_group_name        = azurerm_resource_group.cae.name
  location                   = azurerm_resource_group.cae.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  tags                       = var.tags
}
