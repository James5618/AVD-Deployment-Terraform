# ============================================================================
# Storage Module - Outputs
# ============================================================================

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.fslogix.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.fslogix.name
}

output "storage_account_primary_file_endpoint" {
  description = "Primary file endpoint of the storage account"
  value       = azurerm_storage_account.fslogix.primary_file_endpoint
}

output "file_share_name" {
  description = "Name of the Azure Files share"
  value       = azurerm_storage_share.profiles.name
}

output "file_share_url" {
  description = "URL of the Azure Files share"
  value       = azurerm_storage_share.profiles.url
}

output "fslogix_share_path" {
  description = "UNC path for FSLogix profile configuration"
  value       = "\\\\${azurerm_storage_account.fslogix.name}.file.core.windows.net\\${azurerm_storage_share.profiles.name}"
}

output "private_endpoint_ip" {
  description = "Private IP address of the storage account private endpoint"
  value       = azurerm_private_endpoint.storage_pe.private_service_connection[0].private_ip_address
}
