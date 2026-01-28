# ============================================================================
# Session Hosts Module - Outputs
# ============================================================================

output "vm_ids" {
  description = "List of session host VM resource IDs"
  value       = azurerm_windows_virtual_machine.session_host[*].id
}

output "vm_names" {
  description = "List of session host VM names"
  value       = azurerm_windows_virtual_machine.session_host[*].name
}

output "vm_private_ips" {
  description = "List of private IP addresses of the session hosts"
  value       = azurerm_network_interface.session_host[*].private_ip_address
}

output "vm_count" {
  description = "Number of session hosts deployed"
  value       = var.vm_count
}

output "domain_join_status" {
  description = "Domain join extension provisioning state for each VM"
  value = {
    for idx, vm in azurerm_windows_virtual_machine.session_host :
    vm.name => azurerm_virtual_machine_extension.domain_join[idx].provisioning_state
  }
}

output "avd_registration_status" {
  description = "AVD agent extension provisioning state for each VM"
  value = {
    for idx, vm in azurerm_windows_virtual_machine.session_host :
    vm.name => azurerm_virtual_machine_extension.avd_agent[idx].provisioning_state
  }
}

output "fslogix_config_status" {
  description = "FSLogix configuration extension provisioning state for each VM"
  value = {
    for idx, vm in azurerm_windows_virtual_machine.session_host :
    vm.name => azurerm_virtual_machine_extension.fslogix_config[idx].provisioning_state
  }
}
