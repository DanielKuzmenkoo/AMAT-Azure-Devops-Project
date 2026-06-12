variable "name" {
  type        = string
  description = "Name of the shared Container Apps managed environment."
  default     = "cae-weather"
}

variable "location" {
  type        = string
  description = "Azure region. Every Container App in this environment runs here."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that holds the shared environment."
  default     = "rg-weather-cae"
}

variable "log_analytics_name" {
  type        = string
  description = "Name of the Log Analytics workspace backing the environment."
  default     = "log-weather-shared"
}

variable "log_analytics_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
