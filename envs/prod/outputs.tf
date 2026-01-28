# ============================================================================
# Production Environment - Outputs
# ============================================================================

# ====================
# Resource Group
# ====================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.rg.location
}

# ====================
# Networking
# ====================

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.networking.vnet_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

# ====================
# Domain Controller
# ====================

output "dc_vm_name" {
  description = "Name of the Domain Controller VM"
  value       = module.domain_controller.dc_vm_name
}

output "dc_private_ip" {
  description = "Private IP address of the Domain Controller"
  value       = module.domain_controller.dc_private_ip
}

output "dc_public_ip" {
  description = "Public IP address of the Domain Controller (if enabled)"
  value       = module.domain_controller.dc_public_ip
}

output "domain_name" {
  description = "Active Directory domain name"
  value       = module.domain_controller.domain_name
}

# ====================
# AVD
# ====================

output "workspace_name" {
  description = "Name of the AVD workspace"
  value       = module.avd.workspace_name
}

output "hostpool_name" {
  description = "Name of the AVD host pool"
  value       = module.avd.hostpool_name
}

output "desktop_app_group_name" {
  description = "Name of the desktop application group"
  value       = module.avd.desktop_app_group_name
}

# ====================
# Session Hosts
# ====================

output "session_host_names" {
  description = "Names of the session host VMs"
  value       = module.session_hosts.vm_names
}

output "session_host_count" {
  description = "Number of session hosts deployed"
  value       = module.session_hosts.vm_count
}

output "session_host_domain_join_status" {
  description = "Domain join status for each session host"
  value       = module.session_hosts.domain_join_status
}

output "session_host_avd_registration_status" {
  description = "AVD registration status for each session host"
  value       = module.session_hosts.avd_registration_status
}

# ====================
# Storage
# ====================

output "storage_account_name" {
  description = "Name of the storage account for FSLogix"
  value       = module.storage.storage_account_name
}

output "fslogix_share_path" {
  description = "UNC path to FSLogix profiles share"
  value       = module.storage.fslogix_share_path
}

# ====================
# Connection Information
# ====================

output "avd_connection_info" {
  description = "Information for connecting to AVD"
  value = {
    web_client_url          = "https://client.wvd.microsoft.com/"
    windows_client_download = "https://docs.microsoft.com/en-us/azure/virtual-desktop/user-documentation/connect-windows-7-10"
    workspace_name          = module.avd.workspace_name
  }
}

output "management_info" {
  description = "Management information"
  value = {
    dc_access     = var.dc_enable_public_ip ? "RDP via public IP" : "Use Azure Bastion or VPN"
    dc_private_ip = module.domain_controller.dc_private_ip
    domain_name   = module.domain_controller.domain_name
    admin_note    = "For production, use Azure Bastion for secure management access"
  }
}
