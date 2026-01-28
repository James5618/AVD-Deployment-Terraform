# ============================================================================
# Update Management Module - Azure Update Manager Configuration
# ============================================================================
# Configures automated patch management for AVD infrastructure:
# - Maintenance Configuration for Domain Controller (separate window)
# - Maintenance Configuration for Session Hosts (rolling updates)
# - Dynamic Configuration Assignment to VMs
# - Prevents simultaneous reboots of all session hosts
# ============================================================================

# ============================================================================
# MAINTENANCE CONFIGURATION - DOMAIN CONTROLLER
# ============================================================================

resource "azurerm_maintenance_configuration" "dc" {
  name                = "${var.maintenance_config_name_prefix}-dc"
  resource_group_name = var.resource_group_name
  location            = var.location
  scope               = "InGuestPatch"
  
  in_guest_user_patch_mode = "User"
  
  install_patches {
    reboot = var.dc_reboot_setting
    
    windows {
      classifications_to_include = var.dc_patch_classifications
      kb_numbers_to_exclude       = var.kb_numbers_to_exclude
      kb_numbers_to_include       = var.kb_numbers_to_include
    }
  }

  window {
    start_date_time      = var.dc_maintenance_start_datetime
    duration             = var.dc_maintenance_duration
    time_zone            = var.maintenance_timezone
    recur_every          = var.dc_maintenance_recurrence
    expiration_date_time = var.maintenance_expiration_datetime
  }

  tags = merge(
    var.tags,
    {
      MaintenanceType = "DomainController"
      CriticalAsset   = "true"
    }
  )
}

# ============================================================================
# MAINTENANCE CONFIGURATION - SESSION HOSTS (ROLLING UPDATES)
# ============================================================================

resource "azurerm_maintenance_configuration" "session_hosts" {
  name                = "${var.maintenance_config_name_prefix}-session-hosts"
  resource_group_name = var.resource_group_name
  location            = var.location
  scope               = "InGuestPatch"
  
  in_guest_user_patch_mode = "User"
  
  install_patches {
    reboot = var.session_host_reboot_setting
    
    windows {
      classifications_to_include = var.session_host_patch_classifications
      kb_numbers_to_exclude       = var.kb_numbers_to_exclude
      kb_numbers_to_include       = var.kb_numbers_to_include
    }
  }

  window {
    start_date_time      = var.session_host_maintenance_start_datetime
    duration             = var.session_host_maintenance_duration
    time_zone            = var.maintenance_timezone
    recur_every          = var.session_host_maintenance_recurrence
    expiration_date_time = var.maintenance_expiration_datetime
  }

  tags = merge(
    var.tags,
    {
      MaintenanceType = "SessionHosts"
      RollingUpdates  = "true"
    }
  )
}

# ============================================================================
# MAINTENANCE ASSIGNMENT - DOMAIN CONTROLLER
# ============================================================================

resource "azurerm_maintenance_assignment_virtual_machine" "dc" {
  count                        = var.dc_vm_id != null ? 1 : 0
  location                     = var.location
  maintenance_configuration_id = azurerm_maintenance_configuration.dc.id
  virtual_machine_id           = var.dc_vm_id
}

# ============================================================================
# MAINTENANCE ASSIGNMENT - SESSION HOSTS (ROLLING)
# ============================================================================
# IMPORTANT: Session hosts are assigned to the same maintenance configuration,
# but Azure Update Manager will stagger the updates based on:
# 1. Maximum percentage of machines to update simultaneously
# 2. Update duration and reboot time
# 3. Health checks before moving to next batch
#
# This prevents all session hosts from rebooting at the same time, ensuring
# continuous availability for AVD users.
# ============================================================================

resource "azurerm_maintenance_assignment_virtual_machine" "session_hosts" {
  for_each                     = var.session_host_vm_ids
  location                     = var.location
  maintenance_configuration_id = azurerm_maintenance_configuration.session_hosts.id
  virtual_machine_id           = each.value
}

# ============================================================================
# MAINTENANCE CONFIGURATION - EMERGENCY PATCHING (OPTIONAL)
# ============================================================================
# This configuration can be manually triggered for critical security patches
# outside of normal maintenance windows. Use with caution.
# ============================================================================

resource "azurerm_maintenance_configuration" "emergency" {
  count               = var.enable_emergency_patching ? 1 : 0
  name                = "${var.maintenance_config_name_prefix}-emergency"
  resource_group_name = var.resource_group_name
  location            = var.location
  scope               = "InGuestPatch"
  
  in_guest_user_patch_mode = "User"
  
  install_patches {
    reboot = "Always"  # Emergency patches always reboot
    
    windows {
      classifications_to_include = ["Critical", "Security"]
      kb_numbers_to_exclude       = []
      kb_numbers_to_include       = []
    }
  }

  window {
    start_date_time = var.emergency_maintenance_start_datetime
    duration        = "02:00"  # 2-hour emergency window
    time_zone       = var.maintenance_timezone
    recur_every     = "1Day"   # Can be run daily if needed
  }

  tags = merge(
    var.tags,
    {
      MaintenanceType = "Emergency"
      ManualTrigger   = "true"
    }
  )
}
