# ============================================================================
# FSLogix Storage Module - Outputs
# ============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# STORAGE ACCOUNT INFORMATION
# ──────────────────────────────────────────────────────────────────────────────

output "storage_account_id" {
  description = "Resource ID of the storage account"
  value       = azurerm_storage_account.fslogix.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.fslogix.name
}

output "storage_account_primary_access_key" {
  description = "Primary access key for the storage account (sensitive)"
  value       = azurerm_storage_account.fslogix.primary_access_key
  sensitive   = true
}

output "storage_account_primary_connection_string" {
  description = "Primary connection string for the storage account (sensitive)"
  value       = azurerm_storage_account.fslogix.primary_connection_string
  sensitive   = true
}

# ──────────────────────────────────────────────────────────────────────────────
# FILE SHARE INFORMATION
# ──────────────────────────────────────────────────────────────────────────────

output "file_share_id" {
  description = "Resource ID of the user-profiles file share"
  value       = azurerm_storage_share.user_profiles.id
}

output "file_share_name" {
  description = "Name of the file share (always 'user-profiles')"
  value       = azurerm_storage_share.user_profiles.name
}

output "file_share_url" {
  description = "URL of the file share"
  value       = azurerm_storage_share.user_profiles.url
}

output "file_share_quota_gb" {
  description = "File share size quota in GB"
  value       = azurerm_storage_share.user_profiles.quota
}

# ──────────────────────────────────────────────────────────────────────────────
# UNC PATH AND CONNECTION INFORMATION
# ──────────────────────────────────────────────────────────────────────────────

output "unc_path" {
  description = "UNC path to the user-profiles share (use in FSLogix configuration)"
  value       = "\\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\${azurerm_storage_share.user_profiles.name}"
}

output "fslogix_vhd_locations_registry_value" {
  description = "Value for FSLogix VHDLocations registry setting"
  value       = "\\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\${azurerm_storage_share.user_profiles.name}"
}

output "connection_info" {
  description = "Connection information for the file share"
  value = {
    storage_account_name = azurerm_storage_account.fslogix.name
    file_share_name      = azurerm_storage_share.user_profiles.name
    unc_path            = "\\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\${azurerm_storage_share.user_profiles.name}"
    public_endpoint     = "${azurerm_storage_account.fslogix.name}.file.core.windows.net"
    private_endpoint    = var.enable_private_endpoint ? azurerm_private_endpoint.file_service[0].private_service_connection[0].private_ip_address : null
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# PRIVATE ENDPOINT INFORMATION
# ──────────────────────────────────────────────────────────────────────────────

output "private_endpoint_id" {
  description = "Resource ID of the private endpoint (if enabled)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.file_service[0].id : null
}

output "private_endpoint_ip" {
  description = "Private IP address of the file service endpoint (if enabled)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.file_service[0].private_service_connection[0].private_ip_address : null
}

# ──────────────────────────────────────────────────────────────────────────────
# AUTHENTICATION AND SECURITY
# ──────────────────────────────────────────────────────────────────────────────

output "ad_authentication_enabled" {
  description = "Whether AD DS authentication is enabled"
  value       = var.enable_ad_authentication
}

output "ad_domain_configuration" {
  description = "AD DS domain configuration for reference"
  value = var.enable_ad_authentication ? {
    domain_name         = var.ad_domain_name
    netbios_domain_name = var.ad_netbios_domain_name
    forest_name         = var.ad_forest_name
  } : null
}

# ──────────────────────────────────────────────────────────────────────────────
# POWERSHELL COMMANDS FOR AD DS AUTHENTICATION
# ──────────────────────────────────────────────────────────────────────────────

output "ad_auth_setup_commands" {
  description = "PowerShell commands to configure AD DS authentication (run from domain-joined machine)"
  value = var.enable_ad_authentication == false ? "See README.md for AD DS authentication setup commands using AzFilesHybrid PowerShell module." : "AD DS authentication is enabled. Complete domain join manually using PowerShell commands in the README."
}

# ──────────────────────────────────────────────────────────────────────────────
# TROUBLESHOOTING AND TESTING
# ──────────────────────────────────────────────────────────────────────────────

output "test_mount_command" {
  description = "PowerShell command to test mounting the file share"
  value = <<-EOT
    # Test from session host or domain-joined machine:
    New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\${azurerm_storage_share.user_profiles.name}" -Persist
    
    # Create test file:
    New-Item -Path "Z:\test.txt" -ItemType File -Value "FSLogix test file"
    
    # List files:
    Get-ChildItem -Path "Z:\"
    
    # Remove test drive:
    Remove-PSDrive -Name "Z"
  EOT
}

output "fslogix_registry_settings" {
  description = "Registry settings for FSLogix configuration on session hosts"
  value = {
    enabled           = "HKLM\\SOFTWARE\\FSLogix\\Profiles\\Enabled = 1"
    vhd_locations     = "HKLM\\SOFTWARE\\FSLogix\\Profiles\\VHDLocations = \\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\${azurerm_storage_share.user_profiles.name}"
    size_in_mbs       = "HKLM\\SOFTWARE\\FSLogix\\Profiles\\SizeInMBs = 30000"
    is_dynamic        = "HKLM\\SOFTWARE\\FSLogix\\Profiles\\IsDynamic = 1"
    volume_type       = "HKLM\\SOFTWARE\\FSLogix\\Profiles\\VolumeType = VHDX"
    flip_flop_enabled = "HKLM\\SOFTWARE\\FSLogix\\Profiles\\FlipFlopProfileDirectoryName = 1"
  }
}
