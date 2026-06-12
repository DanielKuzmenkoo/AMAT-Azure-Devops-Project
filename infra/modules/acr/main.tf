# Shared Azure Container Registry.
# One registry is shared across dev/staging/prod so the SAME image built once
# can be promoted between environments (no rebuild per environment).

resource "azurerm_resource_group" "shared" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = var.sku

  # Admin user disabled: environments pull via managed identity (AcrPull),
  # which is the secure default and needs no stored credentials.
  admin_enabled = false

  tags = var.tags
}
