# ============================================================================
# Backup Module - Variables
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group where the Recovery Services Vault will be created"
  type        = string
}

variable "location" {
  description = "Azure region for the Recovery Services Vault"
  type        = string
}

variable "recovery_vault_name" {
  description = "Name of the Recovery Services Vault"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# VM BACKUP CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "vm_backup_retention_days" {
  description = "Number of days to retain daily VM backups (7-9999 days). Recommended: 7-30 days for cost efficiency."
  type        = number
  default     = 7
  validation {
    condition     = var.vm_backup_retention_days >= 7 && var.vm_backup_retention_days <= 9999
    error_message = "VM backup retention must be between 7 and 9999 days."
  }
}

variable "vm_backup_retention_weeks" {
  description = "Number of weeks to retain weekly VM backups (1-5163 weeks). Set to 0 to disable weekly retention."
  type        = number
  default     = 4
  validation {
    condition     = var.vm_backup_retention_weeks >= 0 && var.vm_backup_retention_weeks <= 5163
    error_message = "VM backup weekly retention must be between 0 and 5163 weeks."
  }
}

variable "vm_backup_retention_months" {
  description = "Number of months to retain monthly VM backups (1-1188 months). Set to 0 to disable monthly retention."
  type        = number
  default     = 0
  validation {
    condition     = var.vm_backup_retention_months >= 0 && var.vm_backup_retention_months <= 1188
    error_message = "VM backup monthly retention must be between 0 and 1188 months."
  }
}

variable "vm_backup_retention_years" {
  description = "Number of years to retain yearly VM backups (1-99 years). Set to 0 to disable yearly retention."
  type        = number
  default     = 0
  validation {
    condition     = var.vm_backup_retention_years >= 0 && var.vm_backup_retention_years <= 99
    error_message = "VM backup yearly retention must be between 0 and 99 years."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# AZURE FILES BACKUP CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "fslogix_backup_enabled" {
  description = "Enable Azure Files backup for FSLogix user profiles share"
  type        = bool
  default     = false
}

variable "fslogix_backup_retention_days" {
  description = "Number of days to retain daily Azure Files backups (1-200 days)"
  type        = number
  default     = 7
  validation {
    condition     = var.fslogix_backup_retention_days >= 1 && var.fslogix_backup_retention_days <= 200
    error_message = "Azure Files backup retention must be between 1 and 200 days."
  }
}

variable "fslogix_backup_retention_weeks" {
  description = "Number of weeks to retain weekly Azure Files backups (1-200 weeks). Set to 0 to disable weekly retention."
  type        = number
  default     = 4
  validation {
    condition     = var.fslogix_backup_retention_weeks >= 0 && var.fslogix_backup_retention_weeks <= 200
    error_message = "Azure Files backup weekly retention must be between 0 and 200 weeks."
  }
}

variable "fslogix_backup_retention_months" {
  description = "Number of months to retain monthly Azure Files backups (1-120 months). Set to 0 to disable monthly retention."
  type        = number
  default     = 0
  validation {
    condition     = var.fslogix_backup_retention_months >= 0 && var.fslogix_backup_retention_months <= 120
    error_message = "Azure Files backup monthly retention must be between 0 and 120 months."
  }
}

variable "fslogix_backup_retention_years" {
  description = "Number of years to retain yearly Azure Files backups (1-10 years). Set to 0 to disable yearly retention."
  type        = number
  default     = 0
  validation {
    condition     = var.fslogix_backup_retention_years >= 0 && var.fslogix_backup_retention_years <= 10
    error_message = "Azure Files backup yearly retention must be between 0 and 10 years."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# BACKUP SCHEDULE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "backup_time" {
  description = "Time of day to run backups (HH:MM format, 24-hour). Recommended: off-peak hours like 02:00."
  type        = string
  default     = "02:00"
  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_time))
    error_message = "Backup time must be in HH:MM format (24-hour)."
  }
}

variable "backup_timezone" {
  description = "Timezone for backup schedule (e.g., 'UTC', 'Eastern Standard Time', 'Pacific Standard Time')"
  type        = string
  default     = "UTC"
}

variable "backup_weekly_retention_weekdays" {
  description = "Days of the week to retain weekly backups (Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday)"
  type        = list(string)
  default     = ["Sunday"]
  validation {
    condition = alltrue([
      for day in var.backup_weekly_retention_weekdays :
      contains(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], day)
    ])
    error_message = "Weekdays must be valid day names (Sunday through Saturday)."
  }
}

variable "backup_monthly_retention_weekdays" {
  description = "Days of the week to retain monthly backups"
  type        = list(string)
  default     = ["Sunday"]
  validation {
    condition = alltrue([
      for day in var.backup_monthly_retention_weekdays :
      contains(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], day)
    ])
    error_message = "Weekdays must be valid day names (Sunday through Saturday)."
  }
}

variable "backup_monthly_retention_weeks" {
  description = "Weeks of the month to retain monthly backups (First, Second, Third, Fourth, Last)"
  type        = list(string)
  default     = ["First"]
  validation {
    condition = alltrue([
      for week in var.backup_monthly_retention_weeks :
      contains(["First", "Second", "Third", "Fourth", "Last"], week)
    ])
    error_message = "Weeks must be: First, Second, Third, Fourth, or Last."
  }
}

variable "backup_yearly_retention_weekdays" {
  description = "Days of the week to retain yearly backups"
  type        = list(string)
  default     = ["Sunday"]
  validation {
    condition = alltrue([
      for day in var.backup_yearly_retention_weekdays :
      contains(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], day)
    ])
    error_message = "Weekdays must be valid day names (Sunday through Saturday)."
  }
}

variable "backup_yearly_retention_weeks" {
  description = "Weeks of the month to retain yearly backups (First, Second, Third, Fourth, Last)"
  type        = list(string)
  default     = ["First"]
  validation {
    condition = alltrue([
      for week in var.backup_yearly_retention_weeks :
      contains(["First", "Second", "Third", "Fourth", "Last"], week)
    ])
    error_message = "Weeks must be: First, Second, Third, Fourth, or Last."
  }
}

variable "backup_yearly_retention_months" {
  description = "Months of the year to retain yearly backups (January through December)"
  type        = list(string)
  default     = ["January"]
  validation {
    condition = alltrue([
      for month in var.backup_yearly_retention_months :
      contains(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], month)
    ])
    error_message = "Months must be valid month names (January through December)."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# RECOVERY SERVICES VAULT CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "enable_soft_delete" {
  description = "Enable soft delete for Recovery Services Vault (protects backups from accidental deletion for 14 days)"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# VM RESOURCE IDS - VMs to backup
# ─────────────────────────────────────────────────────────────────────────────

variable "dc_vm_id" {
  description = "Resource ID of the Domain Controller VM to backup. Set to null to skip DC backup."
  type        = string
  default     = null
}

variable "session_host_vm_ids" {
  description = "Map of session host VM resource IDs to backup (key = VM name or index, value = resource ID)"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# STORAGE ACCOUNT - For Azure Files backup
# ─────────────────────────────────────────────────────────────────────────────

variable "storage_account_id" {
  description = "Resource ID of the storage account containing the FSLogix file share. Required if fslogix_backup_enabled = true."
  type        = string
  default     = null
}

variable "fslogix_share_name" {
  description = "Name of the Azure Files share containing user profiles (typically 'user-profiles'). Required if fslogix_backup_enabled = true."
  type        = string
  default     = null
}

# ─────────────────────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to backup resources"
  type        = map(string)
  default     = {}
}
