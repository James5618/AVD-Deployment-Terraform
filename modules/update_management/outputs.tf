# ============================================================================
# Update Management Module - Outputs
# ============================================================================

output "dc_maintenance_configuration_id" {
  description = "Resource ID of the Domain Controller maintenance configuration"
  value       = azurerm_maintenance_configuration.dc.id
}

output "dc_maintenance_configuration_name" {
  description = "Name of the Domain Controller maintenance configuration"
  value       = azurerm_maintenance_configuration.dc.name
}

output "session_host_maintenance_configuration_id" {
  description = "Resource ID of the session host maintenance configuration"
  value       = azurerm_maintenance_configuration.session_hosts.id
}

output "session_host_maintenance_configuration_name" {
  description = "Name of the session host maintenance configuration"
  value       = azurerm_maintenance_configuration.session_hosts.name
}

output "emergency_maintenance_configuration_id" {
  description = "Resource ID of the emergency maintenance configuration (if enabled)"
  value       = var.enable_emergency_patching ? azurerm_maintenance_configuration.emergency[0].id : null
}

output "dc_maintenance_window" {
  description = "Domain Controller maintenance window details"
  value = {
    start_time  = var.dc_maintenance_start_datetime
    duration    = var.dc_maintenance_duration
    recurrence  = var.dc_maintenance_recurrence
    timezone    = var.maintenance_timezone
  }
}

output "session_host_maintenance_window" {
  description = "Session host maintenance window details"
  value = {
    start_time  = var.session_host_maintenance_start_datetime
    duration    = var.session_host_maintenance_duration
    recurrence  = var.session_host_maintenance_recurrence
    timezone    = var.maintenance_timezone
  }
}

output "assigned_vm_count" {
  description = "Number of VMs assigned to maintenance configurations"
  value = {
    domain_controller = var.dc_vm_id != null ? 1 : 0
    session_hosts     = length(var.session_host_vm_ids)
    total             = (var.dc_vm_id != null ? 1 : 0) + length(var.session_host_vm_ids)
  }
}
