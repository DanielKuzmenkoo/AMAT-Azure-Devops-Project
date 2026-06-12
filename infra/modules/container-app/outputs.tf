output "app_url" {
  description = "Public HTTPS URL of the Container App."
  value       = "https://${azurerm_container_app.app.ingress[0].fqdn}"
}

output "app_fqdn" {
  description = "Ingress FQDN of the Container App."
  value       = azurerm_container_app.app.ingress[0].fqdn
}

output "container_app_name" {
  description = "Name of the Container App (used by the pipeline to update the image)."
  value       = azurerm_container_app.app.name
}

output "resource_group_name" {
  description = "Environment resource group name."
  value       = azurerm_resource_group.env.name
}

output "identity_principal_id" {
  description = "Principal ID of the app's managed identity."
  value       = azurerm_user_assigned_identity.aca.principal_id
}
