# ============================================================================
# Domain Controller Module - Outputs
# ============================================================================

output "dc_vm_id" {
  description = "ID of the Domain Controller VM"
  value       = azurerm_windows_virtual_machine.dc.id
}

output "dc_vm_name" {
  description = "Name of the Domain Controller VM"
  value       = azurerm_windows_virtual_machine.dc.name
}

output "dc_private_ip" {
  description = "Private IP address of the Domain Controller (use this for VNet DNS configuration)"
  value       = azurerm_network_interface.dc.private_ip_address
}

output "domain_name" {
  description = "Fully qualified domain name (FQDN)"
  value       = var.domain_name
}

output "netbios_name" {
  description = "NetBIOS domain name"
  value       = var.netbios_name
}

output "ou_distinguished_name" {
  description = "Distinguished Name of the AVD Organizational Unit (e.g., 'OU=AVD,DC=contoso,DC=local')"
  value       = local.avd_ou_dn
}
