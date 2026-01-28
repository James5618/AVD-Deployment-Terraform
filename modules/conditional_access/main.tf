# ============================================================================
# Conditional Access Module - Entra ID Security Policies for AVD
# ============================================================================
# Manages Microsoft Entra Conditional Access policies for AVD access
# Uses Microsoft Graph (azuread provider) to enforce security requirements:
# - Multi-factor authentication (MFA)
# - Compliant or Hybrid Azure AD joined devices
# - Block legacy authentication protocols
# - Optional: Approved client apps and session controls
#
# ⚠️ SAFETY PROTECTIONS:
# 1. Policies default to report-only mode (no user blocking)
# 2. Break-glass group REQUIRED (validation enforced in variables.tf)
# 3. All policies include break-glass exclusions
# 4. Conditional creation (enabled toggle + per-policy toggles)
#
# DEPLOYMENT WORKFLOW:
# 1. Create break-glass accounts → 2. Deploy in report-only → 3. Monitor 2-4 weeks
# → 4. Enable for pilot group → 5. Enable for all users
#
# ⚠️ CRITICAL: Misconfigured policies can lock out ALL users including admins!
# ============================================================================

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# ============================================================================
# POLICY 1: Require MFA for AVD Users
# ============================================================================
# Enforces multi-factor authentication for all AVD access
# Scope: Azure Virtual Desktop cloud application
# Grant: MFA required before access granted
# ============================================================================

resource "azuread_conditional_access_policy" "require_mfa" {
  count        = var.enabled && var.require_mfa ? 1 : 0
  display_name = var.mfa_policy_name
  state        = var.mfa_policy_state
  
  conditions {
    # Target: Users and groups
    users {
      # Use target_group_ids if provided (legacy), otherwise use computed local
      included_groups = length(var.target_group_ids) > 0 ? var.target_group_ids : local.all_target_group_ids
      excluded_groups = concat(
        var.break_glass_group_ids,
        var.mfa_excluded_group_ids
      )
    }
    
    # Target: Cloud apps (Azure Virtual Desktop)
    applications {
      included_applications = var.avd_application_ids
      excluded_applications = []
    }
    
    # All platforms (Windows, macOS, iOS, Android, Linux)
    platforms {
      included_platforms = ["all"]
      excluded_platforms = []
    }
    
    # All locations (no geographic restrictions)
    locations {
      included_locations = ["All"]
      excluded_locations = []
    }
    
    # Block legacy authentication (no modern auth)
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]
  }
  
  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# ============================================================================
# POLICY 2: Require Compliant or Hybrid Joined Device
# ============================================================================
# Enforces device compliance or Hybrid Azure AD join for AVD access
# Scope: Azure Virtual Desktop cloud application
# Grant: Compliant device OR Hybrid Azure AD joined device
# ============================================================================

resource "azuread_conditional_access_policy" "require_compliant_device" {
  count        = var.enabled && var.require_compliant_device ? 1 : 0
  display_name = var.device_policy_name
  state        = var.device_policy_state
  
  conditions {
    users {
      # Use target_group_ids if provided (legacy), otherwise use computed local
      included_groups = length(var.target_group_ids) > 0 ? var.target_group_ids : local.all_target_group_ids
      excluded_groups = concat(
        var.break_glass_group_ids,
        var.device_excluded_group_ids
      )
    }
    
    applications {
      included_applications = var.avd_application_ids
      excluded_applications = []
    }
    
    platforms {
      included_platforms = ["windows"]  # Only enforce on Windows
      excluded_platforms = []
    }
    
    locations {
      included_locations = ["All"]
      excluded_locations = []
    }
    
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]
  }
  
  grant_controls {
    operator = var.require_compliant_or_hybrid ? "OR" : "AND"
    built_in_controls = var.require_compliant_or_hybrid ? [
      "compliantDevice",
      "domainJoinedDevice"  # Hybrid Azure AD joined
    ] : ["compliantDevice"]
  }
}

# ============================================================================
# POLICY 3: Block Legacy Authentication
# ============================================================================
# Blocks legacy authentication protocols (no modern auth support)
# Scope: All cloud applications (broader than just AVD)
# Action: Block access from legacy protocols
#
# Legacy protocols include:
# - Exchange ActiveSync (non-modern clients)
# - IMAP, POP3, SMTP
# - Authenticated SMTP
# - Legacy Office clients (Office 2010 and older)
# ============================================================================

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  count        = var.enabled && var.block_legacy_auth ? 1 : 0
  display_name = var.legacy_auth_policy_name
  state        = var.legacy_auth_policy_state
  
  conditions {
    users {
      included_groups = length(var.target_group_ids) > 0 ? var.target_group_ids : local.all_target_group_ids
      excluded_groups = concat(
        var.break_glass_group_ids,
        var.legacy_auth_excluded_group_ids
      )
    }
    
    applications {
      included_applications = var.block_legacy_auth_all_apps ? ["All"] : var.avd_application_ids
      excluded_applications = []
    }
    
    # Target legacy authentication client app types
    client_app_types = [
      "exchangeActiveSync",
      "other"  # Covers IMAP, POP3, SMTP, etc.
    ]
  }
  
  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# ============================================================================
# POLICY 4: Require Approved Client App (Optional)
# ============================================================================
# Requires approved client applications for mobile access
# Scope: Azure Virtual Desktop cloud application
# Grant: Approved client app required
#
# Approved apps for AVD:
# - Microsoft Remote Desktop (iOS/Android)
# - Windows 365 app
# - Microsoft Edge
# ============================================================================

resource "azuread_conditional_access_policy" "require_approved_app" {
  count        = var.enabled && var.require_approved_app ? 1 : 0
  display_name = var.approved_app_policy_name
  state        = var.approved_app_policy_state
  
  conditions {
    users {
      included_groups = length(var.target_group_ids) > 0 ? var.target_group_ids : local.all_target_group_ids
      excluded_groups = concat(
        var.break_glass_group_ids,
        var.approved_app_excluded_group_ids
      )
    }
    
    applications {
      included_applications = var.avd_application_ids
      excluded_applications = []
    }
    
    platforms {
      included_platforms = ["iOS", "android"]  # Mobile only
      excluded_platforms = []
    }
    
    locations {
      included_locations = ["All"]
      excluded_locations = []
    }
    
    client_app_types = ["mobileAppsAndDesktopClients"]
  }
  
  grant_controls {
    operator          = "OR"
    built_in_controls = ["approvedApplication"]
  }
}

# ============================================================================
# POLICY 5: Session Controls (Optional)
# ============================================================================
# Enforces session controls for AVD access:
# - Sign-in frequency: Force re-authentication every X hours/days
# - Persistent browser session: Disable "Stay signed in" prompt
# ============================================================================

resource "azuread_conditional_access_policy" "session_controls" {
  count        = var.enabled && var.enable_session_controls ? 1 : 0
  display_name = var.session_controls_policy_name
  state        = var.session_controls_policy_state
  
  conditions {
    users {
      included_groups = length(var.target_group_ids) > 0 ? var.target_group_ids : local.all_target_group_ids
      excluded_groups = concat(
        var.break_glass_group_ids,
        var.session_controls_excluded_group_ids
      )
    }
    
    applications {
      included_applications = var.avd_application_ids
      excluded_applications = []
    }
    
    platforms {
      included_platforms = ["all"]
      excluded_platforms = []
    }
    
    locations {
      included_locations = ["All"]
      excluded_locations = []
    }
    
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]
  }
  
  grant_controls {
    operator          = "AND"
    built_in_controls = []  # No grant controls, only session controls
  }
  
  session_controls {
    # Sign-in frequency control
    sign_in_frequency        = var.sign_in_frequency_hours
    sign_in_frequency_period = var.sign_in_frequency_period
    
    # Persistent browser session control
    persistent_browser_mode = var.persistent_browser_mode
  }
}
