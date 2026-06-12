variable "resource_group_name" {
  type        = string
  description = "Name of the shared resource group that holds the ACR."
}

variable "location" {
  type        = string
  description = "Azure region for the shared resources."
}

variable "acr_name" {
  type        = string
  description = "Globally unique Azure Container Registry name (alphanumeric, 5-50 chars)."
}

variable "sku" {
  type        = string
  description = "ACR SKU."
  default     = "Standard"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}
