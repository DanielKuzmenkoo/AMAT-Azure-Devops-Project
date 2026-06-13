output "app_insights_id" {
  description = "Resource ID of the Application Insights component."
  value       = azurerm_application_insights.ai.id
}

output "app_insights_name" {
  description = "Name of the Application Insights component."
  value       = azurerm_application_insights.ai.name
}

output "connection_string" {
  description = "Connection string the app uses (APPLICATIONINSIGHTS_CONNECTION_STRING)."
  value       = azurerm_application_insights.ai.connection_string
  sensitive   = true
}

output "instrumentation_key" {
  description = "Instrumentation key (used by the pipeline to post deployment events)."
  value       = azurerm_application_insights.ai.instrumentation_key
  sensitive   = true
}

output "workbook_id" {
  description = "Resource ID of the app & pipeline health Workbook (dashboard)."
  value       = azurerm_application_insights_workbook.health.id
}
