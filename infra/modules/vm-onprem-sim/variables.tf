variable "environment" {
  type        = string
  description = "Environment name: dev, staging, or prod."
}

variable "location" {
  type        = string
  description = "Azure region for the VM."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the VM (kept separate from the Container App RG)."
}

variable "vm_name" {
  type        = string
  description = "Name of the Linux VM."
  default     = "vm-weather-onprem"
}

variable "vm_size" {
  type        = string
  description = "VM size. A small burstable size is plenty for the demo."
  default     = "Standard_B1s"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key used for VM access and by Ansible."
}

variable "app_port" {
  type        = number
  description = "Port exposed on the VM for the weather app."
  default     = 8000
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR allowed to reach SSH (22). Set to your IP; '*' allows any (demo only)."
  default     = "*"
}

variable "tags" {
  type    = map(string)
  default = {}
}
