# ============================================================================
# FSLogix Storage Module - Azure Files for User Profiles
# ============================================================================

# Storage Account for FSLogix User Profiles
resource "azurerm_storage_account" "fslogix" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  account_kind             = var.storage_account_kind
  
  # Security defaults
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.enable_shared_access_key
  
  # Large file shares support (for Standard)
  large_file_share_enabled = var.storage_account_tier == "Standard" ? true : null
  
  # Network rules
  network_rules {
    default_action             = var.enable_private_endpoint ? "Deny" : "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_addresses
  }
  
  # Azure Files authentication
  dynamic "azure_files_authentication" {
    for_each = var.enable_ad_authentication ? [1] : []
    content {
      directory_type = "AD"
    }
  }

  tags = var.tags
}

# Azure Files Share for User Profiles
resource "azurerm_storage_share" "user_profiles" {
  name                 = "user-profiles"
  storage_account_name = azurerm_storage_account.fslogix.name
  quota                = var.file_share_quota_gb
  enabled_protocol     = "SMB"
  
  # Access tier for Premium storage
  access_tier = var.storage_account_tier == "Premium" ? var.file_share_access_tier : null

  metadata = {
    purpose     = "FSLogix User Profiles"
    environment = var.environment
  }
}

# ============================================================================
# Private Endpoint for Azure Files (Optional)
# ============================================================================

resource "azurerm_private_endpoint" "file_service" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.storage_account_name}-file-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-file-psc"
    private_connection_resource_id = azurerm_storage_account.fslogix.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_dns_zone_id != "" ? [1] : []
    content {
      name                 = "file-dns-zone-group"
      private_dns_zone_ids = [var.private_dns_zone_id]
    }
  }

  tags = var.tags
}

# ============================================================================
# Diagnostics Settings (Optional)
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "${var.storage_account_name}-diagnostics"
  target_resource_id         = azurerm_storage_account.fslogix.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Metrics
  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# Diagnostics for File Service
resource "azurerm_monitor_diagnostic_setting" "file_service" {
  count                      = var.enable_diagnostics ? 1 : 0
  name                       = "${var.storage_account_name}-file-diagnostics"
  target_resource_id         = "${azurerm_storage_account.fslogix.id}/fileServices/default"
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Logs
  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  # Metrics
  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}

# ============================================================================
# Role Assignments for Session Hosts or User Groups
# ============================================================================

# Role assignment for session host identities (if using managed identities)
resource "azurerm_role_assignment" "session_hosts_smb_contributor" {
  count                = length(var.session_host_principal_ids)
  scope                = azurerm_storage_account.fslogix.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.session_host_principal_ids[count.index]
}

# Role assignment for AVD user group (recommended for user access)
resource "azurerm_role_assignment" "avd_users_smb_contributor" {
  count                = var.avd_users_group_id != "" ? 1 : 0
  scope                = azurerm_storage_account.fslogix.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.avd_users_group_id
}

# Role assignment for custom groups or identities
resource "azurerm_role_assignment" "custom_smb_contributor" {
  count                = length(var.additional_contributor_principal_ids)
  scope                = azurerm_storage_account.fslogix.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.additional_contributor_principal_ids[count.index]
}

# ============================================================================
# Data Source for AD DS Authentication Information (Post-Configuration)
# ============================================================================

# Note: AD DS authentication requires manual configuration via PowerShell/CLI
# After configuration, this data source can retrieve the authentication details
# Uncomment after completing AD DS authentication setup:
#
# data "azurerm_storage_account" "fslogix_auth" {
#   name                = azurerm_storage_account.fslogix.name
#   resource_group_name = var.resource_group_name
#   
#   depends_on = [azurerm_storage_account.fslogix]
# }
