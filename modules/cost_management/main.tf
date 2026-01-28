# ============================================================================
# Cost Management Module - Azure Budget and Alerts
# ============================================================================
# Provisions cost monitoring and alerting:
# - Azure Budget scoped to resource group or subscription
# - Alert thresholds at configurable percentages (default: 80%, 90%, 100%)
# - Email notifications to specified recipients
# - Optional forecasted budget alerts
# ============================================================================

# ============================================================================
# AZURE BUDGET - RESOURCE GROUP SCOPED
# ============================================================================

resource "azurerm_consumption_budget_resource_group" "budget" {
  count             = var.enabled && var.budget_scope == "ResourceGroup" ? 1 : 0
  name              = var.budget_name
  resource_group_id = var.resource_group_id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_start_date
    end_date   = var.budget_end_date
  }

  # Alert at 80% of budget
  notification {
    enabled        = true
    threshold      = var.alert_threshold_1
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  # Alert at 90% of budget
  notification {
    enabled        = true
    threshold      = var.alert_threshold_2
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  # Alert at 100% of budget
  notification {
    enabled        = true
    threshold      = var.alert_threshold_3
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  # Optional: Forecasted budget alert
  dynamic "notification" {
    for_each = var.enable_forecasted_alerts ? [1] : []
    content {
      enabled        = true
      threshold      = var.forecasted_alert_threshold
      operator       = "GreaterThanOrEqualTo"
      threshold_type = "Forecasted"

      contact_emails = var.alert_emails
    }
  }

  filter {
    dynamic "dimension" {
      for_each = length(var.filter_tags) > 0 ? [1] : []
      content {
        name   = "ResourceGroupName"
        values = [var.resource_group_name]
      }
    }
  }
}

# ============================================================================
# AZURE BUDGET - SUBSCRIPTION SCOPED
# ============================================================================

resource "azurerm_consumption_budget_subscription" "budget" {
  count           = var.enabled && var.budget_scope == "Subscription" ? 1 : 0
  name            = var.budget_name
  subscription_id = var.subscription_id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = var.budget_start_date
    end_date   = var.budget_end_date
  }

  # Alert at 80% of budget
  notification {
    enabled        = true
    threshold      = var.alert_threshold_1
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  # Alert at 90% of budget
  notification {
    enabled        = true
    threshold      = var.alert_threshold_2
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  # Alert at 100% of budget
  notification {
    enabled        = true
    threshold      = var.alert_threshold_3
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"

    contact_emails = var.alert_emails
  }

  # Optional: Forecasted budget alert
  dynamic "notification" {
    for_each = var.enable_forecasted_alerts ? [1] : []
    content {
      enabled        = true
      threshold      = var.forecasted_alert_threshold
      operator       = "GreaterThanOrEqualTo"
      threshold_type = "Forecasted"

      contact_emails = var.alert_emails
    }
  }

  filter {
    dynamic "tag" {
      for_each = var.filter_tags
      content {
        name   = tag.key
        values = [tag.value]
      }
    }
  }
}
