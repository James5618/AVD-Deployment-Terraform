# ============================================================================
# AVD Core Module - Workspace, Host Pool, App Group, and Assignments
# ============================================================================

# AVD Workspace
resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = "${var.prefix}-${var.env}-workspace"
  location            = var.location
  resource_group_name = var.resource_group_name
  friendly_name       = var.workspace_friendly_name
  description         = var.workspace_description

  tags = var.tags
}

# AVD Host Pool (Pooled)
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                     = var.host_pool_name != "" ? var.host_pool_name : "${var.prefix}-${var.env}-hp"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  type                     = "Pooled"
  load_balancer_type       = var.load_balancer_type
  friendly_name            = var.host_pool_friendly_name
  description              = var.host_pool_description
  validate_environment     = false
  start_vm_on_connect      = var.start_vm_on_connect
  custom_rdp_properties    = var.custom_rdp_properties
  maximum_sessions_allowed = var.max_sessions
  
  # Scheduled agent updates (optional)
  dynamic "scheduled_agent_updates" {
    for_each = var.enable_scheduled_agent_updates ? [1] : []
    content {
      enabled = true
      schedule {
        day_of_week = "Sunday"
        hour_of_day = 2
      }
    }
  }

  tags = var.tags
}

# AVD Host Pool Registration Token
resource "azurerm_virtual_desktop_host_pool_registration_info" "registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = timeadd(timestamp(), var.registration_token_ttl_hours)

  lifecycle {
    ignore_changes = [
      expiration_date
    ]
  }
}

# AVD Desktop Application Group
resource "azurerm_virtual_desktop_application_group" "desktop_app_group" {
  name                = "${var.prefix}-${var.env}-dag"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name       = var.app_group_friendly_name
  description         = var.app_group_description

  tags = var.tags
}

# Associate Application Group with Workspace
resource "azurerm_virtual_desktop_workspace_application_group_association" "workspace_app_assoc" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop_app_group.id
}

# Role Assignment - Assign AVD users group to the desktop application group
resource "azurerm_role_assignment" "avd_users_desktop" {
  count                = var.user_group_object_id != "" ? 1 : 0
  scope                = azurerm_virtual_desktop_application_group.desktop_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = var.user_group_object_id
}
