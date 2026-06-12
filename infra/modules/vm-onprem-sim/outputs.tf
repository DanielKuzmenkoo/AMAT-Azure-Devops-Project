output "vm_public_ip" {
  description = "Public IP of the VM (put this in the Ansible inventory)."
  value       = azurerm_public_ip.pip.ip_address
}

output "admin_username" {
  description = "SSH admin username."
  value       = var.admin_username
}

output "ssh_command" {
  description = "Convenience SSH command."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "app_url" {
  description = "URL the app is reachable on once Ansible has deployed it."
  value       = "http://${azurerm_public_ip.pip.ip_address}:${var.app_port}"
}
