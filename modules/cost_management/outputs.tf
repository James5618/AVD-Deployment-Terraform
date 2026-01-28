# ============================================================================
# Cost Management Module - Outputs
# ============================================================================

output "budget_id" {
  description = "Resource ID of the Azure Budget"
  value       = var.enabled ? (var.budget_scope == "ResourceGroup" ? azurerm_consumption_budget_resource_group.budget[0].id : azurerm_consumption_budget_subscription.budget[0].id) : null
}

output "budget_name" {
  description = "Name of the Azure Budget"
  value       = var.enabled ? var.budget_name : null
}

output "budget_amount" {
  description = "Monthly budget amount"
  value       = var.enabled ? var.monthly_budget_amount : null
}

output "alert_thresholds" {
  description = "Configured alert thresholds as percentages"
  value = var.enabled ? {
    warning  = var.alert_threshold_1
    critical = var.alert_threshold_2
    exceeded = var.alert_threshold_3
  } : null
}

output "alert_recipients" {
  description = "Email addresses receiving budget alerts"
  value       = var.enabled ? var.alert_emails : []
  sensitive   = true
}

output "budget_scope" {
  description = "Scope of the budget (ResourceGroup or Subscription)"
  value       = var.enabled ? var.budget_scope : null
}
