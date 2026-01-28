# ============================================================================
# AVD Module - Workspace, Host Pool, Application Group, Assignments
# ============================================================================

# Random string for registration token uniqueness
resource "random_string" "avd_token" {
  length  = 16
  special = false
  upper   = true
  lower   = true
  numeric = true
}

# AVD Workspace
resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  friendly_name       = var.workspace_friendly_name
  description         = var.workspace_description

  tags = var.tags
}

# AVD Host Pool
resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                     = var.hostpool_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  type                     = var.hostpool_type
  load_balancer_type       = var.load_balancer_type
  friendly_name            = var.hostpool_friendly_name
  description              = var.hostpool_description
  validate_environment     = false
  start_vm_on_connect      = true
  custom_rdp_properties    = var.custom_rdp_properties
  maximum_sessions_allowed = var.maximum_sessions_allowed

  tags = var.tags
}

# AVD Host Pool Registration Token
resource "azurerm_virtual_desktop_host_pool_registration_info" "registrationinfo" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = timeadd(timestamp(), "48h")

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# AVD Desktop Application Group
resource "azurerm_virtual_desktop_application_group" "desktop_app_group" {
  name                = var.app_group_name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name       = var.app_group_friendly_name
  description         = var.app_group_description

  tags = var.tags
}

# Associate Application Group with Workspace
resource "azurerm_virtual_desktop_workspace_application_group_association" "workspace_app_group_association" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop_app_group.id
}

# Data source to get Azure AD users (requires users to exist in Azure AD)
data "azuread_user" "avd_users" {
  for_each            = toset(var.avd_users)
  user_principal_name = each.value
}

# Assign users to Desktop Application Group
resource "azurerm_role_assignment" "desktop_virtualization_user" {
  for_each             = toset(var.avd_users)
  scope                = azurerm_virtual_desktop_application_group.desktop_app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = data.azuread_user.avd_users[each.key].object_id
}
