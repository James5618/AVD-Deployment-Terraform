# ============================================================================
# Scaling Plan Module - Variables
# ============================================================================
# User-friendly variables for AVD auto-scaling configuration
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# BASIC CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "enabled" {
  description = "Enable AVD auto-scaling (set to false to disable without destroying resource)"
  type        = bool
  default     = true
}

variable "scaling_plan_name" {
  description = "Name of the scaling plan"
  type        = string
}

variable "location" {
  description = "Azure region for the scaling plan"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "friendly_name" {
  description = "Friendly name for the scaling plan (displayed in Azure Portal)"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the scaling plan"
  type        = string
  default     = "Automatic scaling for AVD session hosts based on time-of-day and user demand"
}

variable "timezone" {
  description = "Timezone for schedule times (e.g., 'GMT Standard Time', 'Pacific Standard Time', 'UTC'). See: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-time-zones"
  type        = string
  default     = "GMT Standard Time"  # Europe/London
}

variable "host_pool_ids" {
  description = "List of AVD host pool IDs to associate with this scaling plan"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to the scaling plan"
  type        = map(string)
  default     = {}
}

# ─────────────────────────────────────────────────────────────────────────────
# WEEKDAY SCHEDULE - Monday to Friday business hours
# ─────────────────────────────────────────────────────────────────────────────

# RAMP-UP PHASE (Morning startup)
variable "weekday_ramp_up_start_time" {
  description = "Weekday ramp-up start time in HH:MM format (24-hour). Example: 07:00 for 7 AM"
  type        = string
  default     = "07:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekday_ramp_up_start_time))
    error_message = "Time must be in HH:MM format (24-hour), e.g., 07:00 or 18:30"
  }
}

variable "weekday_ramp_up_min_hosts_percent" {
  description = "Weekday ramp-up: Minimum % of host pool capacity to keep online (e.g., 20 = keep 20% of hosts running)"
  type        = number
  default     = 20
  validation {
    condition     = var.weekday_ramp_up_min_hosts_percent >= 0 && var.weekday_ramp_up_min_hosts_percent <= 100
    error_message = "Min hosts percent must be between 0 and 100"
  }
}

variable "weekday_ramp_up_capacity_threshold_percent" {
  description = "Weekday ramp-up: Start new hosts when average load exceeds this % (e.g., 60 = start hosts when >60% utilized)"
  type        = number
  default     = 60
  validation {
    condition     = var.weekday_ramp_up_capacity_threshold_percent >= 0 && var.weekday_ramp_up_capacity_threshold_percent <= 100
    error_message = "Capacity threshold must be between 0 and 100"
  }
}

# PEAK PHASE (Business hours)
variable "weekday_peak_start_time" {
  description = "Weekday peak hours start time in HH:MM format (24-hour). Example: 09:00 for 9 AM"
  type        = string
  default     = "09:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekday_peak_start_time))
    error_message = "Time must be in HH:MM format (24-hour), e.g., 09:00 or 18:30"
  }
}

# RAMP-DOWN PHASE (Evening wind-down)
variable "weekday_ramp_down_start_time" {
  description = "Weekday ramp-down start time in HH:MM format (24-hour). Example: 17:00 for 5 PM"
  type        = string
  default     = "17:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekday_ramp_down_start_time))
    error_message = "Time must be in HH:MM format (24-hour), e.g., 17:00 or 18:30"
  }
}

variable "weekday_ramp_down_min_hosts_percent" {
  description = "Weekday ramp-down: Minimum % of host pool capacity to keep online (e.g., 10 = keep 10% of hosts for late workers)"
  type        = number
  default     = 10
  validation {
    condition     = var.weekday_ramp_down_min_hosts_percent >= 0 && var.weekday_ramp_down_min_hosts_percent <= 100
    error_message = "Min hosts percent must be between 0 and 100"
  }
}

variable "weekday_ramp_down_capacity_threshold_percent" {
  description = "Weekday ramp-down: Stop hosts when average load falls below this % (e.g., 90 = keep hosts until <90% utilized)"
  type        = number
  default     = 90
  validation {
    condition     = var.weekday_ramp_down_capacity_threshold_percent >= 0 && var.weekday_ramp_down_capacity_threshold_percent <= 100
    error_message = "Capacity threshold must be between 0 and 100"
  }
}

# OFF-PEAK PHASE (Overnight)
variable "weekday_off_peak_start_time" {
  description = "Weekday off-peak start time in HH:MM format (24-hour). Example: 19:00 for 7 PM"
  type        = string
  default     = "19:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekday_off_peak_start_time))
    error_message = "Time must be in HH:MM format (24-hour), e.g., 19:00 or 22:30"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# WEEKEND SCHEDULE - Saturday and Sunday (optional)
# ─────────────────────────────────────────────────────────────────────────────

variable "enable_weekend_schedule" {
  description = "Enable separate weekend schedule (if false, scaling plan only applies Monday-Friday)"
  type        = bool
  default     = true
}

variable "weekend_ramp_up_start_time" {
  description = "Weekend ramp-up start time in HH:MM format (typically later than weekdays). Example: 10:00 for 10 AM"
  type        = string
  default     = "10:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekend_ramp_up_start_time))
    error_message = "Time must be in HH:MM format (24-hour)"
  }
}

variable "weekend_ramp_up_min_hosts_percent" {
  description = "Weekend ramp-up: Minimum % of host pool capacity (typically lower than weekdays)"
  type        = number
  default     = 10
  validation {
    condition     = var.weekend_ramp_up_min_hosts_percent >= 0 && var.weekend_ramp_up_min_hosts_percent <= 100
    error_message = "Min hosts percent must be between 0 and 100"
  }
}

variable "weekend_ramp_up_capacity_threshold_percent" {
  description = "Weekend ramp-up: Capacity threshold % (typically higher = slower scaling)"
  type        = number
  default     = 80
  validation {
    condition     = var.weekend_ramp_up_capacity_threshold_percent >= 0 && var.weekend_ramp_up_capacity_threshold_percent <= 100
    error_message = "Capacity threshold must be between 0 and 100"
  }
}

variable "weekend_peak_start_time" {
  description = "Weekend peak start time in HH:MM format. Example: 12:00 for 12 PM"
  type        = string
  default     = "12:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekend_peak_start_time))
    error_message = "Time must be in HH:MM format (24-hour)"
  }
}

variable "weekend_ramp_down_start_time" {
  description = "Weekend ramp-down start time in HH:MM format. Example: 16:00 for 4 PM"
  type        = string
  default     = "16:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekend_ramp_down_start_time))
    error_message = "Time must be in HH:MM format (24-hour)"
  }
}

variable "weekend_ramp_down_min_hosts_percent" {
  description = "Weekend ramp-down: Minimum % of host pool capacity"
  type        = number
  default     = 0
  validation {
    condition     = var.weekend_ramp_down_min_hosts_percent >= 0 && var.weekend_ramp_down_min_hosts_percent <= 100
    error_message = "Min hosts percent must be between 0 and 100"
  }
}

variable "weekend_ramp_down_capacity_threshold_percent" {
  description = "Weekend ramp-down: Capacity threshold %"
  type        = number
  default     = 90
  validation {
    condition     = var.weekend_ramp_down_capacity_threshold_percent >= 0 && var.weekend_ramp_down_capacity_threshold_percent <= 100
    error_message = "Capacity threshold must be between 0 and 100"
  }
}

variable "weekend_off_peak_start_time" {
  description = "Weekend off-peak start time in HH:MM format. Example: 18:00 for 6 PM"
  type        = string
  default     = "18:00"
  validation {
    condition     = can(regex("^([0-1][0-9]|2[0-3]):[0-5][0-9]$", var.weekend_off_peak_start_time))
    error_message = "Time must be in HH:MM format (24-hour)"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# LOAD BALANCING ALGORITHMS
# ─────────────────────────────────────────────────────────────────────────────

variable "ramp_up_load_balancing_algorithm" {
  description = "Ramp-up load balancing: BreadthFirst (spread users across hosts) or DepthFirst (fill hosts before starting new ones)"
  type        = string
  default     = "BreadthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.ramp_up_load_balancing_algorithm)
    error_message = "Must be BreadthFirst or DepthFirst"
  }
}

variable "peak_load_balancing_algorithm" {
  description = "Peak hours load balancing: BreadthFirst (spread users) or DepthFirst (consolidate users)"
  type        = string
  default     = "DepthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.peak_load_balancing_algorithm)
    error_message = "Must be BreadthFirst or DepthFirst"
  }
}

variable "ramp_down_load_balancing_algorithm" {
  description = "Ramp-down load balancing: DepthFirst recommended to consolidate users for efficient deallocation"
  type        = string
  default     = "DepthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.ramp_down_load_balancing_algorithm)
    error_message = "Must be BreadthFirst or DepthFirst"
  }
}

variable "off_peak_load_balancing_algorithm" {
  description = "Off-peak load balancing: DepthFirst recommended to minimize running hosts"
  type        = string
  default     = "DepthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.off_peak_load_balancing_algorithm)
    error_message = "Must be BreadthFirst or DepthFirst"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# RAMP-DOWN BEHAVIOR - User session management
# ─────────────────────────────────────────────────────────────────────────────

variable "ramp_down_force_logoff_users" {
  description = "Force log off users after wait time expires during ramp-down (true = force logoff, false = wait indefinitely)"
  type        = bool
  default     = false
}

variable "ramp_down_wait_time_minutes" {
  description = "Minutes to wait for users to log off before forcing logoff (if enabled). Recommended: 30-60 minutes"
  type        = number
  default     = 30
  validation {
    condition     = var.ramp_down_wait_time_minutes >= 0 && var.ramp_down_wait_time_minutes <= 480
    error_message = "Wait time must be between 0 and 480 minutes (8 hours)"
  }
}

variable "ramp_down_notification_message" {
  description = "Message to display to users before forced logoff. Leave empty for no notification."
  type        = string
  default     = "You will be logged off in 30 minutes. Please save your work."
}

variable "ramp_down_stop_hosts_when" {
  description = "When to stop session hosts during ramp-down: ZeroSessions (wait for all sessions to end) or ZeroActiveSessions (stop when no active sessions)"
  type        = string
  default     = "ZeroSessions"
  validation {
    condition     = contains(["ZeroSessions", "ZeroActiveSessions"], var.ramp_down_stop_hosts_when)
    error_message = "Must be ZeroSessions or ZeroActiveSessions"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# MONITORING ALERTS - Optional alerts for scaling health and cost anomalies
# ─────────────────────────────────────────────────────────────────────────────

variable "enable_monitoring_alerts" {
  description = "Enable Azure Monitor alerts for scaling health (no available hosts, high resource usage, cost anomalies)"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for alert queries. Required if enable_monitoring_alerts = true. Example: /subscriptions/.../workspaces/avd-logs"
  type        = string
  default     = null
}

variable "alert_emails" {
  description = "List of email addresses to receive scaling alert notifications. Example: ['admin@contoso.com', 'ops@contoso.com']"
  type        = list(string)
  default     = []
}

variable "high_cpu_threshold_percent" {
  description = "CPU usage % threshold for under-scaling alert. Alert when average CPU exceeds this value across multiple hosts. Recommended: 80-90%"
  type        = number
  default     = 85
  validation {
    condition     = var.high_cpu_threshold_percent >= 50 && var.high_cpu_threshold_percent <= 100
    error_message = "CPU threshold must be between 50 and 100"
  }
}

variable "high_memory_threshold_percent" {
  description = "Memory usage % threshold for under-scaling alert. Alert when average memory exceeds this value. Recommended: 80-90%"
  type        = number
  default     = 85
  validation {
    condition     = var.high_memory_threshold_percent >= 50 && var.high_memory_threshold_percent <= 100
    error_message = "Memory threshold must be between 50 and 100"
  }
}

variable "min_hosts_for_alert" {
  description = "Minimum number of hosts that must exceed thresholds before triggering under-scaling alert. Prevents false positives from single-host issues. Recommended: 2-3"
  type        = number
  default     = 2
  validation {
    condition     = var.min_hosts_for_alert >= 1 && var.min_hosts_for_alert <= 10
    error_message = "Min hosts for alert must be between 1 and 10"
  }
}

variable "max_off_peak_hosts" {
  description = "Maximum number of hosts expected during off-peak hours (7 PM - 7 AM, weekends). Alert if exceeded. Set to expected minimum + 1. Example: 2 (1 minimum + 1 buffer)"
  type        = number
  default     = 2
  validation {
    condition     = var.max_off_peak_hosts >= 0 && var.max_off_peak_hosts <= 50
    error_message = "Max off-peak hosts must be between 0 and 50"
  }
}

variable "enable_scaling_stuck_alert" {
  description = "Enable diagnostic alert for detecting if scaling plan is stuck (host count not changing during transitions). Useful for troubleshooting."
  type        = bool
  default     = false
}
