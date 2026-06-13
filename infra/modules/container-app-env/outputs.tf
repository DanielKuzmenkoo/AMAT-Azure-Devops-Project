output "container_app_environment_id" {
  description = "Resource ID of the shared Container Apps environment."
  value       = azurerm_container_app_environment.cae.id
}

output "location" {
  description = "Region of the shared environment; apps must match it."
  value       = azurerm_container_app_environment.cae.location
}

output "resource_group_name" {
  description = "Resource group holding the shared environment."
  value       = azurerm_resource_group.cae.name
}

output "log_analytics_workspace_id" {
  description = "Workspace ID, reused by Application Insights (workspace-based)."
  value       = azurerm_log_analytics_workspace.law.id
}
