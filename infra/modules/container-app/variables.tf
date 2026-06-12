variable "environment" {
  type        = string
  description = "Environment name: dev, staging, or prod."
}

variable "location" {
  type        = string
  description = "Azure region for this environment."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for this environment (e.g. rg-weather-dev)."
}

variable "container_app_name" {
  type        = string
  description = "Name of the Container App."
}

variable "acr_login_server" {
  type        = string
  description = "ACR login server, from the shared acr module output."
}

variable "acr_id" {
  type        = string
  description = "ACR resource ID, used to grant AcrPull to the app identity."
}

variable "image" {
  type        = string
  description = "Full image reference to run, e.g. myregistry.azurecr.io/weather-api:123."
}

variable "app_port" {
  type        = number
  description = "Container port the app listens on."
  default     = 8000
}

# --- Application configuration (non-secret; Open-Meteo needs no API key) ---

variable "forecast_days" {
  type    = number
  default = 14
}

variable "geocoding_api_base_url" {
  type    = string
  default = "https://geocoding-api.open-meteo.com/v1"
}

variable "weather_api_base_url" {
  type    = string
  default = "https://api.open-meteo.com/v1"
}

variable "http_timeout_seconds" {
  type    = number
  default = 5
}

# --- Sizing / scaling ---

variable "cpu" {
  type    = number
  default = 0.5
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "min_replicas" {
  type    = number
  default = 1
}

variable "max_replicas" {
  type    = number
  default = 2
}

variable "log_analytics_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
