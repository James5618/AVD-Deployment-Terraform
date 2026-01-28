# ============================================================================
# AVD Core Module - Outputs
# ============================================================================

output "workspace_id" {
  description = "Resource ID of the AVD workspace"
  value       = azurerm_virtual_desktop_workspace.workspace.id
}

output "workspace_name" {
  description = "Name of the AVD workspace"
  value       = azurerm_virtual_desktop_workspace.workspace.name
}

output "host_pool_id" {
  description = "Resource ID of the AVD host pool"
  value       = azurerm_virtual_desktop_host_pool.hostpool.id
}

output "host_pool_name" {
  description = "Name of the AVD host pool"
  value       = azurerm_virtual_desktop_host_pool.hostpool.name
}

output "app_group_id" {
  description = "Resource ID of the desktop application group"
  value       = azurerm_virtual_desktop_application_group.desktop_app_group.id
}

output "app_group_name" {
  description = "Name of the desktop application group"
  value       = azurerm_virtual_desktop_application_group.desktop_app_group.name
}

output "registration_token" {
  description = "Host pool registration token for joining session hosts (sensitive)"
  value       = azurerm_virtual_desktop_host_pool_registration_info.registration.token
  sensitive   = true
}

output "registration_token_expiration" {
  description = "Expiration date/time of the registration token"
  value       = azurerm_virtual_desktop_host_pool_registration_info.registration.expiration_date
}

output "registration_token_ttl" {
  description = "Time-to-live for the registration token"
  value       = var.registration_token_ttl_hours
}

# ──────────────────────────────────────────────────────────────────────────────
# CONNECTION INFORMATION
# ──────────────────────────────────────────────────────────────────────────────

output "user_group_object_id" {
  description = "Azure AD group object ID for AVD users (used for app group assignment and conditional access)"
  value       = var.user_group_object_id
}

output "connection_info" {
  description = "Connection information for AVD users"
  value = {
    web_client_url      = "https://client.wvd.microsoft.com/"
    windows_client_url  = "https://docs.microsoft.com/azure/virtual-desktop/user-documentation/connect-windows-7-10"
    workspace_name      = azurerm_virtual_desktop_workspace.workspace.name
    workspace_id        = azurerm_virtual_desktop_workspace.workspace.id
  }
}
