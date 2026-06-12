output "acr_name" {
  description = "Name of the container registry."
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "Login server (e.g. myregistry.azurecr.io) used to tag/push images."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_id" {
  description = "Resource ID of the registry (used for AcrPull role assignments)."
  value       = azurerm_container_registry.acr.id
}

output "resource_group_name" {
  description = "Shared resource group name."
  value       = azurerm_resource_group.shared.name
}
