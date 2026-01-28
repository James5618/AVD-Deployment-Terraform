# ============================================================================
# Storage Module - Storage Account and Azure Files Share for FSLogix Profiles
# ============================================================================

# Storage Account for FSLogix Profiles
resource "azurerm_storage_account" "fslogix" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Premium"
  account_replication_type = "LRS"
  account_kind             = "FileStorage"

  # Enable Azure Files Active Directory Domain Service Authentication
  azure_files_authentication {
    directory_type = "AD"
  }

  tags = var.tags
}

# Azure Files Share for User Profiles
resource "azurerm_storage_share" "profiles" {
  name                 = var.share_name
  storage_account_name = azurerm_storage_account.fslogix.name
  quota                = var.share_quota_gb
  enabled_protocol     = "SMB"

  depends_on = [
    azurerm_storage_account.fslogix
  ]
}

# Private Endpoint for Storage Account
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "${var.storage_account_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-psc"
    private_connection_resource_id = azurerm_storage_account.fslogix.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }

  tags = var.tags
}

# Private DNS Zone for Storage Account
resource "azurerm_private_dns_zone" "storage_dns" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage_dns_link" {
  name                  = "${var.storage_account_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage_dns.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# DNS A Record for Private Endpoint
resource "azurerm_private_dns_a_record" "storage_dns_a" {
  name                = azurerm_storage_account.fslogix.name
  zone_name           = azurerm_private_dns_zone.storage_dns.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address]

  tags = var.tags
}

# Role assignment for session hosts to access storage (if using managed identities)
# This would typically be done at the session hosts level with their managed identity principal IDs
# For domain-joined scenarios, NTFS permissions are managed via AD groups
