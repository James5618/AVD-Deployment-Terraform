# ============================================================================
# Update Management Module - Variables
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group where maintenance configurations will be created"
  type        = string
}

variable "location" {
  description = "Azure region for maintenance configurations"
  type        = string
}

variable "maintenance_config_name_prefix" {
  description = "Prefix for maintenance configuration names (e.g., 'avd-prod-maint')"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# DOMAIN CONTROLLER MAINTENANCE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "dc_maintenance_start_datetime" {
  description = "Start date/time for DC maintenance window in RFC3339 format (e.g., '2026-01-01T02:00:00+00:00'). Must be in the future."
  type        = string
  validation {
    condition     = can(formatdate("RFC3339", var.dc_maintenance_start_datetime))
    error_message = "DC maintenance start datetime must be in RFC3339 format (e.g., '2026-01-01T02:00:00+00:00')."
  }
}

variable "dc_maintenance_duration" {
  description = "Duration of DC maintenance window in HH:MM format (e.g., '03:00' for 3 hours). Range: 01:30 to 06:00."
  type        = string
  default     = "03:00"
  validation {
    condition     = can(regex("^0[1-6]:[0-5][0-9]$", var.dc_maintenance_duration))
    error_message = "Duration must be between 01:30 and 06:00 in HH:MM format."
  }
}

variable "dc_maintenance_recurrence" {
  description = "Recurrence pattern for DC maintenance (e.g., '1Week', '2Weeks', '1Month'). Domain Controllers typically patched monthly."
  type        = string
  default     = "1Month"
}

variable "dc_reboot_setting" {
  description = "Reboot behavior for Domain Controller after patching (IfRequired, Never, Always)"
  type        = string
  default     = "IfRequired"
  validation {
    condition     = contains(["IfRequired", "Never", "Always"], var.dc_reboot_setting)
    error_message = "Reboot setting must be: IfRequired, Never, or Always."
  }
}

variable "dc_patch_classifications" {
  description = "Patch classifications to install on Domain Controller"
  type        = list(string)
  default     = ["Critical", "Security", "UpdateRollup", "FeaturePack", "ServicePack"]
}

# ─────────────────────────────────────────────────────────────────────────────
# SESSION HOST MAINTENANCE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "session_host_maintenance_start_datetime" {
  description = "Start date/time for session host maintenance window in RFC3339 format. Should be DIFFERENT from DC window to avoid simultaneous updates."
  type        = string
  validation {
    condition     = can(formatdate("RFC3339", var.session_host_maintenance_start_datetime))
    error_message = "Session host maintenance start datetime must be in RFC3339 format."
  }
}

variable "session_host_maintenance_duration" {
  description = "Duration of session host maintenance window in HH:MM format. Longer duration allows for rolling updates across all hosts."
  type        = string
  default     = "04:00"
  validation {
    condition     = can(regex("^0[1-6]:[0-5][0-9]$", var.session_host_maintenance_duration))
    error_message = "Duration must be between 01:30 and 06:00 in HH:MM format."
  }
}

variable "session_host_maintenance_recurrence" {
  description = "Recurrence pattern for session host maintenance (e.g., '1Week', '2Weeks', '1Month')"
  type        = string
  default     = "1Week"
}

variable "session_host_reboot_setting" {
  description = "Reboot behavior for session hosts after patching. 'IfRequired' is recommended to minimize user impact."
  type        = string
  default     = "IfRequired"
  validation {
    condition     = contains(["IfRequired", "Never", "Always"], var.session_host_reboot_setting)
    error_message = "Reboot setting must be: IfRequired, Never, or Always."
  }
}

variable "session_host_patch_classifications" {
  description = "Patch classifications to install on session hosts"
  type        = list(string)
  default     = ["Critical", "Security", "UpdateRollup"]
}

# ─────────────────────────────────────────────────────────────────────────────
# SHARED MAINTENANCE SETTINGS
# ─────────────────────────────────────────────────────────────────────────────

variable "maintenance_timezone" {
  description = "Timezone for maintenance windows (e.g., 'UTC', 'Eastern Standard Time', 'Pacific Standard Time')"
  type        = string
  default     = "UTC"
}

variable "maintenance_expiration_datetime" {
  description = "Expiration date/time for maintenance schedules in RFC3339 format. Set to null for indefinite schedules."
  type        = string
  default     = null
}

variable "kb_numbers_to_exclude" {
  description = "List of KB article numbers to exclude from patching (e.g., ['KB5001234', 'KB5005678'])"
  type        = list(string)
  default     = []
}

variable "kb_numbers_to_include" {
  description = "List of specific KB article numbers to include (overrides classifications if specified)"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────────────────────
# EMERGENCY PATCHING CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "enable_emergency_patching" {
  description = "Create emergency maintenance configuration for critical out-of-band patches (manually triggered)"
  type        = bool
  default     = false
}

variable "emergency_maintenance_start_datetime" {
  description = "Start date/time for emergency maintenance window (only used if enable_emergency_patching = true)"
  type        = string
  default     = "2026-01-01T00:00:00+00:00"
}

# ─────────────────────────────────────────────────────────────────────────────
# VM RESOURCE IDS
# ─────────────────────────────────────────────────────────────────────────────

variable "dc_vm_id" {
  description = "Resource ID of the Domain Controller VM to apply maintenance configuration"
  type        = string
  default     = null
}

variable "session_host_vm_ids" {
  description = "Map of session host VM resource IDs (key = VM name or index, value = resource ID). All session hosts will receive rolling updates."
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to maintenance configurations"
  type        = map(string)
  default     = {}
}
