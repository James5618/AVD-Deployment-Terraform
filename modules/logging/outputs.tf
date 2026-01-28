# ============================================================================
# Logging Module - Outputs
# ============================================================================

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "data_collection_rule_id" {
  description = "Resource ID of the VM Insights Data Collection Rule (if enabled)"
  value       = var.enable_vm_insights ? azurerm_monitor_data_collection_rule.vminsights[0].id : null
}
