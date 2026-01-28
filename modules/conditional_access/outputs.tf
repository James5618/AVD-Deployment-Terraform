# ============================================================================
# Conditional Access Module - Outputs
# ============================================================================
# Policy IDs for monitoring, reference, and integration
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# INDIVIDUAL POLICY OUTPUTS
# ─────────────────────────────────────────────────────────────────────────────

output "mfa_policy_id" {
  description = "ID of the MFA requirement policy (null if not created)"
  value       = var.enabled && var.require_mfa ? azuread_conditional_access_policy.require_mfa[0].id : null
}

output "mfa_policy_name" {
  description = "Display name of the MFA policy"
  value       = var.enabled && var.require_mfa ? azuread_conditional_access_policy.require_mfa[0].display_name : null
}

output "mfa_policy_state" {
  description = "Current state of the MFA policy (enabled, enabledForReportingButNotEnforced, disabled)"
  value       = var.enabled && var.require_mfa ? azuread_conditional_access_policy.require_mfa[0].state : null
}

# ─────────────────────────────────────────────────────────────────────────────

output "device_policy_id" {
  description = "ID of the device compliance policy (null if not created)"
  value       = var.enabled && var.require_compliant_device ? azuread_conditional_access_policy.require_compliant_device[0].id : null
}

output "device_policy_name" {
  description = "Display name of the device compliance policy"
  value       = var.enabled && var.require_compliant_device ? azuread_conditional_access_policy.require_compliant_device[0].display_name : null
}

output "device_policy_state" {
  description = "Current state of the device policy"
  value       = var.enabled && var.require_compliant_device ? azuread_conditional_access_policy.require_compliant_device[0].state : null
}

# ─────────────────────────────────────────────────────────────────────────────

output "legacy_auth_policy_id" {
  description = "ID of the legacy authentication blocking policy (null if not created)"
  value       = var.enabled && var.block_legacy_auth ? azuread_conditional_access_policy.block_legacy_auth[0].id : null
}

output "legacy_auth_policy_name" {
  description = "Display name of the legacy auth blocking policy"
  value       = var.enabled && var.block_legacy_auth ? azuread_conditional_access_policy.block_legacy_auth[0].display_name : null
}

output "legacy_auth_policy_state" {
  description = "Current state of the legacy auth policy"
  value       = var.enabled && var.block_legacy_auth ? azuread_conditional_access_policy.block_legacy_auth[0].state : null
}

# ─────────────────────────────────────────────────────────────────────────────

output "approved_app_policy_id" {
  description = "ID of the approved client app policy (null if not created)"
  value       = var.enabled && var.require_approved_app ? azuread_conditional_access_policy.require_approved_app[0].id : null
}

output "approved_app_policy_name" {
  description = "Display name of the approved app policy"
  value       = var.enabled && var.require_approved_app ? azuread_conditional_access_policy.require_approved_app[0].display_name : null
}

output "approved_app_policy_state" {
  description = "Current state of the approved app policy"
  value       = var.enabled && var.require_approved_app ? azuread_conditional_access_policy.require_approved_app[0].state : null
}

# ─────────────────────────────────────────────────────────────────────────────

output "session_controls_policy_id" {
  description = "ID of the session controls policy (null if not created)"
  value       = var.enabled && var.enable_session_controls ? azuread_conditional_access_policy.session_controls[0].id : null
}

output "session_controls_policy_name" {
  description = "Display name of the session controls policy"
  value       = var.enabled && var.enable_session_controls ? azuread_conditional_access_policy.session_controls[0].display_name : null
}

output "session_controls_policy_state" {
  description = "Current state of the session controls policy"
  value       = var.enabled && var.enable_session_controls ? azuread_conditional_access_policy.session_controls[0].state : null
}

# ─────────────────────────────────────────────────────────────────────────────
# AGGREGATE OUTPUTS
# ─────────────────────────────────────────────────────────────────────────────

output "all_policy_ids" {
  description = "List of all created Conditional Access policy IDs (for monitoring/reference)"
  value = compact([
    var.enabled && var.require_mfa ? azuread_conditional_access_policy.require_mfa[0].id : "",
    var.enabled && var.require_compliant_device ? azuread_conditional_access_policy.require_compliant_device[0].id : "",
    var.enabled && var.block_legacy_auth ? azuread_conditional_access_policy.block_legacy_auth[0].id : "",
    var.enabled && var.require_approved_app ? azuread_conditional_access_policy.require_approved_app[0].id : "",
    var.enabled && var.enable_session_controls ? azuread_conditional_access_policy.session_controls[0].id : ""
  ])
}

output "policy_summary" {
  description = "Summary of all Conditional Access policies and their states"
  value = {
    mfa_enabled              = var.enabled && var.require_mfa
    device_compliance_enabled = var.enabled && var.require_compliant_device
    legacy_auth_blocked      = var.enabled && var.block_legacy_auth
    approved_app_enabled     = var.enabled && var.require_approved_app
    session_controls_enabled = var.enabled && var.enable_session_controls
    total_policies_created   = length(compact([
      var.enabled && var.require_mfa ? "1" : "",
      var.enabled && var.require_compliant_device ? "1" : "",
      var.enabled && var.block_legacy_auth ? "1" : "",
      var.enabled && var.require_approved_app ? "1" : "",
      var.enabled && var.enable_session_controls ? "1" : ""
    ]))
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# SAFETY INFORMATION
# ─────────────────────────────────────────────────────────────────────────────

output "break_glass_groups" {
  description = "Break-glass group IDs excluded from all policies (for documentation)"
  value       = var.break_glass_group_ids
  sensitive   = false  # Not sensitive data (just group IDs)
}

output "target_groups" {
  description = "Target group IDs included in policies (for documentation)"
  value       = length(var.target_group_ids) > 0 ? var.target_group_ids : local.all_target_group_ids
  sensitive   = false
}

output "avd_users_group_id" {
  description = "Primary AVD users group ID (from avd_core module)"
  value       = var.avd_users_group_id
  sensitive   = false
}

output "additional_target_group_ids" {
  description = "Additional target group IDs (pilot groups, etc.)"
  value       = var.additional_target_group_ids
  sensitive   = false
}

output "avd_applications" {
  description = "AVD application IDs targeted by policies (for documentation)"
  value       = var.avd_application_ids
  sensitive   = false
}
