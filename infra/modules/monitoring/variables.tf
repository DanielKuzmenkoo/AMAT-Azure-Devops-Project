variable "name" {
  type        = string
  description = "Name of the Application Insights resource."
  default     = "appi-weather"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the monitoring resources."
  default     = "rg-weather-monitoring"
}

variable "location" {
  type        = string
  description = "Azure region for the monitoring resources."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Workspace ID backing this Application Insights (reuses the shared CAE workspace)."
}

variable "retention_in_days" {
  type        = number
  description = "Application Insights data retention."
  default     = 90
}

variable "alert_email" {
  type        = string
  description = "Email for alert notifications. When empty, no action group or metric alerts are created."
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
