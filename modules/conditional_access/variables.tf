# ============================================================================
# Conditional Access Module - Variables
# ============================================================================
# Security policy configuration for AVD access via Entra Conditional Access
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# MASTER TOGGLE
# ─────────────────────────────────────────────────────────────────────────────

variable "enabled" {
  description = "Enable Conditional Access policies (set to false to disable without destroying)"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# TARGET CONFIGURATION - Users and Applications
# ─────────────────────────────────────────────────────────────────────────────

variable "avd_users_group_id" {
  description = "Primary Entra ID group object ID for AVD users (typically from avd_core module output). This group receives AVD app access and is targeted by CA policies."
  type        = string
  default     = ""
}

variable "additional_target_group_ids" {
  description = "Additional Entra ID group object IDs to include in policies (optional). Use for pilot groups or additional user sets."
  type        = list(string)
  default     = []
}

# Internal computed variable - combines primary and additional groups
locals {
  # Combine AVD users group with additional groups, filtering out empty strings
  all_target_group_ids = compact(concat(
    [var.avd_users_group_id],
    var.additional_target_group_ids
  ))
}

variable "target_group_ids" {
  description = "DEPRECATED: Use avd_users_group_id + additional_target_group_ids instead. List of Entra ID group object IDs to include in policies."
  type        = list(string)
  default     = []
}

variable "break_glass_group_ids" {
  description = "CRITICAL: List of Entra ID group object IDs for break-glass/emergency access accounts. These accounts are EXCLUDED from all policies to prevent lockout. MUST be explicitly set before enabling policies."
  type        = list(string)
  default     = []
  
  validation {
    condition     = var.enabled == false || length(var.break_glass_group_ids) > 0
    error_message = "SAFETY CHECK FAILED: break_glass_group_ids MUST be set when enabled=true. Create break-glass accounts and group first to prevent admin lockout. See README.md for setup instructions."
  }
}

variable "avd_application_ids" {
  description = "List of cloud application IDs for AVD. Default: ['9cdead84-a844-4324-93f2-b2e6bb768d07'] (Azure Virtual Desktop), ['38aa3b87-a06d-4817-b275-7a316988d93b'] (Windows Sign-In)"
  type        = list(string)
  default = [
    "9cdead84-a844-4324-93f2-b2e6bb768d07",  # Azure Virtual Desktop
    "38aa3b87-a06d-4817-b275-7a316988d93b"   # Windows Sign-In
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY 1: MFA Requirement
# ─────────────────────────────────────────────────────────────────────────────

variable "require_mfa" {
  description = "Enable MFA requirement policy for AVD access"
  type        = bool
  default     = true
}

variable "mfa_policy_name" {
  description = "Display name for MFA policy"
  type        = string
  default     = "AVD: Require Multi-Factor Authentication"
}

variable "mfa_policy_state" {
  description = "Policy state: enabled (enforced), enabledForReportingButNotEnforced (audit mode), disabled"
  type        = string
  default     = "enabledForReportingButNotEnforced"  # Audit mode for safety
  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.mfa_policy_state)
    error_message = "Must be: enabled, enabledForReportingButNotEnforced, or disabled"
  }
}

variable "mfa_excluded_group_ids" {
  description = "Additional group IDs to exclude from MFA policy (beyond break-glass accounts)"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY 2: Compliant/Hybrid Joined Device Requirement
# ─────────────────────────────────────────────────────────────────────────────

variable "require_compliant_device" {
  description = "Enable compliant/hybrid joined device requirement policy"
  type        = bool
  default     = false  # Disabled by default (requires Intune setup)
}

variable "device_policy_name" {
  description = "Display name for device compliance policy"
  type        = string
  default     = "AVD: Require Compliant or Hybrid Joined Device"
}

variable "device_policy_state" {
  description = "Policy state: enabled, enabledForReportingButNotEnforced (audit), disabled"
  type        = string
  default     = "enabledForReportingButNotEnforced"
  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.device_policy_state)
    error_message = "Must be: enabled, enabledForReportingButNotEnforced, or disabled"
  }
}

variable "require_compliant_or_hybrid" {
  description = "Require compliant OR hybrid joined device (true) vs compliant AND hybrid joined (false)"
  type        = bool
  default     = true  # OR = more flexible
}

variable "device_excluded_group_ids" {
  description = "Additional group IDs to exclude from device policy"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY 3: Block Legacy Authentication
# ─────────────────────────────────────────────────────────────────────────────

variable "block_legacy_auth" {
  description = "Enable policy to block legacy authentication protocols (IMAP, POP3, SMTP, Exchange ActiveSync)"
  type        = bool
  default     = true
}

variable "legacy_auth_policy_name" {
  description = "Display name for legacy authentication blocking policy"
  type        = string
  default     = "AVD: Block Legacy Authentication"
}

variable "legacy_auth_policy_state" {
  description = "Policy state: enabled, enabledForReportingButNotEnforced (audit), disabled"
  type        = string
  default     = "enabledForReportingButNotEnforced"  # Start with report-only for safety
  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.legacy_auth_policy_state)
    error_message = "Must be: enabled, enabledForReportingButNotEnforced, or disabled"
  }
}

variable "block_legacy_auth_all_apps" {
  description = "Block legacy auth for all cloud apps (true) or only AVD apps (false)"
  type        = bool
  default     = true  # Recommended: block globally
}

variable "legacy_auth_excluded_group_ids" {
  description = "Additional group IDs to exclude from legacy auth blocking (not recommended)"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY 4: Approved Client App (Optional)
# ─────────────────────────────────────────────────────────────────────────────

variable "require_approved_app" {
  description = "Enable approved client app requirement for mobile access (iOS/Android)"
  type        = bool
  default     = false
}

variable "approved_app_policy_name" {
  description = "Display name for approved app policy"
  type        = string
  default     = "AVD: Require Approved Client App (Mobile)"
}

variable "approved_app_policy_state" {
  description = "Policy state: enabled, enabledForReportingButNotEnforced (audit), disabled"
  type        = string
  default     = "enabledForReportingButNotEnforced"
  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.approved_app_policy_state)
    error_message = "Must be: enabled, enabledForReportingButNotEnforced, or disabled"
  }
}

variable "approved_app_excluded_group_ids" {
  description = "Additional group IDs to exclude from approved app policy"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY 5: Session Controls (Optional)
# ─────────────────────────────────────────────────────────────────────────────

variable "enable_session_controls" {
  description = "Enable session controls (sign-in frequency, persistent browser)"
  type        = bool
  default     = false
}

variable "session_controls_policy_name" {
  description = "Display name for session controls policy"
  type        = string
  default     = "AVD: Session Controls"
}

variable "session_controls_policy_state" {
  description = "Policy state: enabled, enabledForReportingButNotEnforced (audit), disabled"
  type        = string
  default     = "enabledForReportingButNotEnforced"
  validation {
    condition     = contains(["enabled", "enabledForReportingButNotEnforced", "disabled"], var.session_controls_policy_state)
    error_message = "Must be: enabled, enabledForReportingButNotEnforced, or disabled"
  }
}

variable "sign_in_frequency_hours" {
  description = "Force re-authentication after X hours. Recommended: 8-24 hours for AVD sessions."
  type        = number
  default     = 12
  validation {
    condition     = var.sign_in_frequency_hours >= 1 && var.sign_in_frequency_hours <= 720
    error_message = "Sign-in frequency must be between 1 and 720 hours (30 days)"
  }
}

variable "sign_in_frequency_period" {
  description = "Period for sign-in frequency: hours or days"
  type        = string
  default     = "hours"
  validation {
    condition     = contains(["hours", "days"], var.sign_in_frequency_period)
    error_message = "Must be: hours or days"
  }
}

variable "persistent_browser_mode" {
  description = "Persistent browser session mode: always (always persist), never (never persist)"
  type        = string
  default     = "never"  # Disable 'Stay signed in' for security
  validation {
    condition     = contains(["always", "never"], var.persistent_browser_mode)
    error_message = "Must be: always or never"
  }
}

variable "session_controls_excluded_group_ids" {
  description = "Additional group IDs to exclude from session controls"
  type        = list(string)
  default     = []
}
