# ============================================================================
# Cost Management Module - Variables
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

variable "enabled" {
  description = "Enable cost management budget and alerts"
  type        = bool
  default     = true
}

variable "budget_name" {
  description = "Name of the Azure Budget"
  type        = string
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD (or your subscription currency). Set based on expected monthly costs."
  type        = number
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "alert_emails" {
  description = "List of email addresses to receive budget alerts. Must be valid email addresses."
  type        = list(string)
  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "At least one email address is required for budget alerts."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# BUDGET SCOPE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "budget_scope" {
  description = "Scope of the budget: 'ResourceGroup' or 'Subscription'"
  type        = string
  default     = "ResourceGroup"
  validation {
    condition     = contains(["ResourceGroup", "Subscription"], var.budget_scope)
    error_message = "Budget scope must be either 'ResourceGroup' or 'Subscription'."
  }
}

variable "resource_group_id" {
  description = "Resource group ID for budget (required if budget_scope = 'ResourceGroup')"
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource group name for filtering (required if budget_scope = 'ResourceGroup')"
  type        = string
  default     = null
}

variable "subscription_id" {
  description = "Subscription ID for budget (required if budget_scope = 'Subscription')"
  type        = string
  default     = null
}

# ─────────────────────────────────────────────────────────────────────────────
# ALERT THRESHOLD CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "alert_threshold_1" {
  description = "First alert threshold as percentage of budget (e.g., 80 for 80%). Warning level."
  type        = number
  default     = 80
  validation {
    condition     = var.alert_threshold_1 > 0 && var.alert_threshold_1 <= 1000
    error_message = "Alert threshold must be between 1 and 1000."
  }
}

variable "alert_threshold_2" {
  description = "Second alert threshold as percentage of budget (e.g., 90 for 90%). Critical warning level."
  type        = number
  default     = 90
  validation {
    condition     = var.alert_threshold_2 > 0 && var.alert_threshold_2 <= 1000
    error_message = "Alert threshold must be between 1 and 1000."
  }
}

variable "alert_threshold_3" {
  description = "Third alert threshold as percentage of budget (e.g., 100 for 100%). Budget exceeded level."
  type        = number
  default     = 100
  validation {
    condition     = var.alert_threshold_3 > 0 && var.alert_threshold_3 <= 1000
    error_message = "Alert threshold must be between 1 and 1000."
  }
}

variable "enable_forecasted_alerts" {
  description = "Enable forecasted budget alerts (predicts when budget will be exceeded based on current spending trends)"
  type        = bool
  default     = false
}

variable "forecasted_alert_threshold" {
  description = "Forecasted alert threshold as percentage of budget (e.g., 100 for 100%)"
  type        = number
  default     = 100
  validation {
    condition     = var.forecasted_alert_threshold > 0 && var.forecasted_alert_threshold <= 1000
    error_message = "Forecasted alert threshold must be between 1 and 1000."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# TIME PERIOD CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "budget_start_date" {
  description = "Budget start date in YYYY-MM-01 format (must be first day of month). Defaults to current month."
  type        = string
  default     = null
  validation {
    condition     = var.budget_start_date == null || can(regex("^\\d{4}-\\d{2}-01$", var.budget_start_date))
    error_message = "Budget start date must be in YYYY-MM-01 format (first day of month)."
  }
}

variable "budget_end_date" {
  description = "Budget end date in YYYY-MM-01 format (optional, null for indefinite). Must be first day of month."
  type        = string
  default     = null
  validation {
    condition     = var.budget_end_date == null || can(regex("^\\d{4}-\\d{2}-01$", var.budget_end_date))
    error_message = "Budget end date must be in YYYY-MM-01 format (first day of month)."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# FILTERING CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "filter_tags" {
  description = "Map of tags to filter budget scope (e.g., {Environment = 'prod', Project = 'avd'})"
  type        = map(string)
  default     = {}
}
