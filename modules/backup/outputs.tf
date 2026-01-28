# ============================================================================
# Backup Module - Outputs
# ============================================================================

output "recovery_services_vault_id" {
  description = "Resource ID of the Recovery Services Vault"
  value       = azurerm_recovery_services_vault.vault.id
}

output "recovery_services_vault_name" {
  description = "Name of the Recovery Services Vault"
  value       = azurerm_recovery_services_vault.vault.name
}

output "vm_backup_policy_id" {
  description = "Resource ID of the VM backup policy"
  value       = azurerm_backup_policy_vm.daily.id
}

output "fslogix_backup_policy_id" {
  description = "Resource ID of the Azure Files backup policy (if enabled)"
  value       = var.fslogix_backup_enabled ? azurerm_backup_policy_file_share.fslogix[0].id : null
}

output "dc_backup_enabled" {
  description = "Whether Domain Controller backup is enabled"
  value       = var.dc_vm_id != null
}

output "session_hosts_backup_count" {
  description = "Number of session hosts with backup enabled"
  value       = length(var.session_host_vm_ids)
}

output "fslogix_backup_enabled" {
  description = "Whether FSLogix Azure Files backup is enabled"
  value       = var.fslogix_backup_enabled
}
