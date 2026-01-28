# ============================================================================
# Logging Module - Variables
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group where the Log Analytics workspace will be created"
  type        = string
}

variable "location" {
  description = "Azure region for the Log Analytics workspace"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# LOG ANALYTICS CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace. Use 'PerGB2018' for pay-as-you-go pricing."
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["Free", "PerNode", "Premium", "Standard", "Standalone", "Unlimited", "CapacityReservation", "PerGB2018"], var.log_analytics_sku)
    error_message = "Log Analytics SKU must be one of: Free, PerNode, Premium, Standard, Standalone, Unlimited, CapacityReservation, PerGB2018."
  }
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace (30-730 days, or 7 days for Free tier)"
  type        = number
  default     = 30
  validation {
    condition     = var.log_analytics_retention_days >= 7 && var.log_analytics_retention_days <= 730
    error_message = "Log retention must be between 7 and 730 days."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# AVD RESOURCE IDS - For Diagnostic Settings
# ─────────────────────────────────────────────────────────────────────────────

variable "avd_workspace_id" {
  description = "Resource ID of the AVD workspace to enable diagnostics. Set to null to skip."
  type        = string
  default     = null
}

variable "avd_hostpool_id" {
  description = "Resource ID of the AVD host pool to enable diagnostics. Set to null to skip."
  type        = string
  default     = null
}

variable "avd_app_group_ids" {
  description = "Map of AVD application group IDs to enable diagnostics (key = descriptive name, value = resource ID)"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# STORAGE ACCOUNT - For Diagnostic Settings
# ─────────────────────────────────────────────────────────────────────────────

variable "storage_account_id" {
  description = "Resource ID of the storage account (FSLogix) to enable diagnostics. Set to null to skip."
  type        = string
  default     = null
}

# ─────────────────────────────────────────────────────────────────────────────
# NETWORK SECURITY GROUPS - For Diagnostic Settings
# ─────────────────────────────────────────────────────────────────────────────

variable "nsg_ids" {
  description = "Map of NSG resource IDs to enable diagnostics (key = descriptive name, value = resource ID)"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# VM INSIGHTS CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "enable_vm_insights" {
  description = "Enable VM Insights for Domain Controller and Session Hosts (installs Azure Monitor Agent and Dependency Agent)"
  type        = bool
  default     = true
}

variable "dc_vm_id" {
  description = "Resource ID of the Domain Controller VM for VM Insights. Set to null to skip."
  type        = string
  default     = null
}

variable "session_host_vm_ids" {
  description = "Map of session host VM resource IDs for VM Insights (key = VM name or index, value = resource ID)"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to logging resources"
  type        = map(string)
  default     = {}
}
