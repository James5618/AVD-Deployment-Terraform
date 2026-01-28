# ============================================================================
# AVD Module - Outputs
# ============================================================================

output "workspace_id" {
  description = "ID of the AVD workspace"
  value       = azurerm_virtual_desktop_workspace.workspace.id
}

output "workspace_name" {
  description = "Name of the AVD workspace"
  value       = azurerm_virtual_desktop_workspace.workspace.name
}

output "hostpool_id" {
  description = "ID of the AVD host pool"
  value       = azurerm_virtual_desktop_host_pool.hostpool.id
}

output "hostpool_name" {
  description = "Name of the AVD host pool"
  value       = azurerm_virtual_desktop_host_pool.hostpool.name
}

output "hostpool_registration_token" {
  description = "Registration token for adding session hosts to the host pool"
  value       = azurerm_virtual_desktop_host_pool_registration_info.registrationinfo.token
  sensitive   = true
}

output "desktop_app_group_id" {
  description = "ID of the desktop application group"
  value       = azurerm_virtual_desktop_application_group.desktop_app_group.id
}

output "desktop_app_group_name" {
  description = "Name of the desktop application group"
  value       = azurerm_virtual_desktop_application_group.desktop_app_group.name
}
