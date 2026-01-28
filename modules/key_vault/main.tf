# ============================================================================
# Azure Key Vault Module - Secure Secret Storage
# ============================================================================
# This module provisions:
# - Azure Key Vault with RBAC authorization (no legacy access policies)
# - Soft delete enabled (mandatory in Azure, 90-day retention)
# - Optional purge protection (prevents permanent deletion)
# - Secrets for domain admin and local admin passwords
# - Current deployment identity granted Key Vault Secrets Officer role
#
# Security Features:
# - RBAC-based access control (modern, more secure than access policies)
# - Soft delete protection (recover accidentally deleted secrets)
# - Private network integration ready (add private endpoint separately)
# - Audit logging via diagnostic settings (configure in logging module)
#
# Cost: ~$0.03/10,000 operations + $0.03/secret/month (minimal, typically <$5/month)
# ============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Current Deployment Identity - Used for RBAC assignment
# ─────────────────────────────────────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# Azure Key Vault - Secure secret storage with RBAC authorization
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_key_vault" "kv" {
  count = var.enabled ? 1 : 0

  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard" # Standard tier sufficient for most workloads

  # RBAC Authorization (modern approach, replaces legacy access policies)
  enable_rbac_authorization = true

  # Soft Delete - Mandatory in Azure (allows secret recovery for 90 days)
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.purge_protection_enabled

  # Network Security
  public_network_access_enabled = var.public_network_access_enabled
  network_acls {
    default_action = var.network_default_action
    bypass         = "AzureServices" # Allow Azure services (e.g., Terraform Cloud, Azure DevOps)
    ip_rules       = var.allowed_ip_ranges
  }

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# RBAC Assignment - Grant current identity Key Vault Secrets Officer role
# ─────────────────────────────────────────────────────────────────────────────
# This allows the Terraform deployment identity to create/read/delete secrets.
# In production, use Azure DevOps service principal or managed identity.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_role_assignment" "kv_secrets_officer" {
  count = var.enabled ? 1 : 0

  scope                = azurerm_key_vault.kv[0].id
  role_definition_name = "Key Vault Secrets Officer" # Full secret management permissions
  principal_id         = data.azurerm_client_config.current.object_id

  # Note: RBAC assignments can take 1-2 minutes to propagate. If secret creation
  # fails immediately after Key Vault creation, add a time_sleep resource.
}

# ─────────────────────────────────────────────────────────────────────────────
# Time Delay - Allow RBAC assignment to propagate
# ─────────────────────────────────────────────────────────────────────────────
resource "time_sleep" "rbac_propagation" {
  count = var.enabled ? 1 : 0

  depends_on = [azurerm_role_assignment.kv_secrets_officer]

  create_duration = "60s" # Wait 60 seconds for RBAC to propagate
}

# ─────────────────────────────────────────────────────────────────────────────
# Random Password Generation - Secure passwords for domain and local admins
# ─────────────────────────────────────────────────────────────────────────────
resource "random_password" "domain_admin" {
  count = var.enabled && var.auto_generate_passwords ? 1 : 0

  length           = 24
  special          = true
  override_special = "!@#$%&*()-_=+[]{}:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "local_admin" {
  count = var.enabled && var.auto_generate_passwords ? 1 : 0

  length           = 24
  special          = true
  override_special = "!@#$%&*()-_=+[]{}:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ─────────────────────────────────────────────────────────────────────────────
# Key Vault Secret - Domain Administrator Password
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "domain_admin_password" {
  count = var.enabled ? 1 : 0

  name         = var.domain_admin_password_secret_name
  value        = var.auto_generate_passwords ? random_password.domain_admin[0].result : var.domain_admin_password
  key_vault_id = azurerm_key_vault.kv[0].id

  content_type = "password"

  tags = merge(
    var.tags,
    {
      Purpose = "Domain Administrator Password"
      Service = "Active Directory Domain Services"
    }
  )

  depends_on = [time_sleep.rbac_propagation]
}

# ─────────────────────────────────────────────────────────────────────────────
# Key Vault Secret - Session Host Local Administrator Password
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "local_admin_password" {
  count = var.enabled ? 1 : 0

  name         = var.local_admin_password_secret_name
  value        = var.auto_generate_passwords ? random_password.local_admin[0].result : var.local_admin_password
  key_vault_id = azurerm_key_vault.kv[0].id

  content_type = "password"

  tags = merge(
    var.tags,
    {
      Purpose = "Local Administrator Password"
      Service = "Session Host VMs"
    }
  )

  depends_on = [time_sleep.rbac_propagation]
}

# ─────────────────────────────────────────────────────────────────────────────
# Additional Automation Secrets (Optional)
# ─────────────────────────────────────────────────────────────────────────────
# Store additional secrets for automation (e.g., service principal credentials,
# API keys, connection strings). Use for_each to create multiple secrets.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "automation_secrets" {
  for_each = var.enabled ? nonsensitive(var.additional_secrets) : {}

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.kv[0].id

  content_type = "automation-secret"

  tags = merge(
    var.tags,
    {
      Purpose = "Automation Secret"
      Service = "Custom"
    }
  )

  depends_on = [time_sleep.rbac_propagation]
}
