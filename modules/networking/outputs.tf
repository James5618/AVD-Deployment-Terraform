# ============================================================================
# Networking Module - Outputs
# ============================================================================

output "resource_group_name" {
  description = "Name of the resource group (created or existing)"
  value       = local.resource_group_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.vnet.name
}

output "dc_subnet_id" {
  description = "ID of the Domain Controller subnet"
  value       = azurerm_subnet.dc.id
}

output "avd_subnet_id" {
  description = "ID of the AVD session hosts subnet"
  value       = azurerm_subnet.avd_hosts.id
}

output "storage_subnet_id" {
  description = "ID of the storage subnet"
  value       = azurerm_subnet.storage.id
}

output "nsg_ids" {
  description = "Map of Network Security Group IDs"
  value = {
    dc          = azurerm_network_security_group.dc.id
    avd_hosts   = azurerm_network_security_group.avd_hosts.id
    storage     = azurerm_network_security_group.storage.id
  }
}

output "dc_subnet_address_prefix" {
  description = "Address prefix of the Domain Controller subnet"
  value       = var.dc_subnet_prefix
}

output "avd_subnet_address_prefix" {
  description = "Address prefix of the AVD subnet"
  value       = var.avd_subnet_prefix
}
