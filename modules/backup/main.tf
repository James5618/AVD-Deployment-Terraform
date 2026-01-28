# ============================================================================
# Backup Module - Recovery Services Vault and Backup Policies
# ============================================================================
# Provisions Azure Backup for AVD environment:
# - Recovery Services Vault
# - VM backup policy with configurable retention
# - Optional Azure Files backup policy for FSLogix profiles
# - Backup protection for Domain Controller and Session Hosts
# ============================================================================

# ============================================================================
# RECOVERY SERVICES VAULT
# ============================================================================

resource "azurerm_recovery_services_vault" "vault" {
  name                = var.recovery_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  soft_delete_enabled = var.enable_soft_delete
  
  tags = var.tags
}

# ============================================================================
# VM BACKUP POLICY
# ============================================================================

resource "azurerm_backup_policy_vm" "daily" {
  name                = "${var.recovery_vault_name}-vm-policy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  timezone = var.backup_timezone

  backup {
    frequency = "Daily"
    time      = var.backup_time
  }

  retention_daily {
    count = var.vm_backup_retention_days
  }

  retention_weekly {
    count    = var.vm_backup_retention_weeks
    weekdays = var.backup_weekly_retention_weekdays
  }

  retention_monthly {
    count    = var.vm_backup_retention_months
    weekdays = var.backup_monthly_retention_weekdays
    weeks    = var.backup_monthly_retention_weeks
  }

  retention_yearly {
    count    = var.vm_backup_retention_years
    weekdays = var.backup_yearly_retention_weekdays
    weeks    = var.backup_yearly_retention_weeks
    months   = var.backup_yearly_retention_months
  }
}

# ============================================================================
# VM BACKUP PROTECTION - DOMAIN CONTROLLER
# ============================================================================

resource "azurerm_backup_protected_vm" "dc" {
  count               = var.dc_vm_id != null ? 1 : 0
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = var.dc_vm_id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# ============================================================================
# VM BACKUP PROTECTION - SESSION HOSTS
# ============================================================================

resource "azurerm_backup_protected_vm" "session_hosts" {
  for_each            = var.session_host_vm_ids
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = each.value
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# ============================================================================
# AZURE FILES BACKUP POLICY (OPTIONAL)
# ============================================================================

resource "azurerm_backup_policy_file_share" "fslogix" {
  count               = var.fslogix_backup_enabled ? 1 : 0
  name                = "${var.recovery_vault_name}-fileshare-policy"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

  timezone = var.backup_timezone

  backup {
    frequency = "Daily"
    time      = var.backup_time
  }

  retention_daily {
    count = var.fslogix_backup_retention_days
  }

  retention_weekly {
    count    = var.fslogix_backup_retention_weeks
    weekdays = var.backup_weekly_retention_weekdays
  }

  retention_monthly {
    count    = var.fslogix_backup_retention_months
    weekdays = var.backup_monthly_retention_weekdays
    weeks    = var.backup_monthly_retention_weeks
  }

  retention_yearly {
    count    = var.fslogix_backup_retention_years
    weekdays = var.backup_yearly_retention_weekdays
    weeks    = var.backup_yearly_retention_weeks
    months   = var.backup_yearly_retention_months
  }
}

# ============================================================================
# AZURE FILES BACKUP CONTAINER
# ============================================================================

resource "azurerm_backup_container_storage_account" "fslogix" {
  count               = var.fslogix_backup_enabled && var.storage_account_id != null ? 1 : 0
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  storage_account_id  = var.storage_account_id
}

# ============================================================================
# AZURE FILES BACKUP PROTECTION
# ============================================================================

resource "azurerm_backup_protected_file_share" "profiles" {
  count               = var.fslogix_backup_enabled && var.storage_account_id != null && var.fslogix_share_name != null ? 1 : 0
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_storage_account_id = var.storage_account_id
  source_file_share_name    = var.fslogix_share_name
  backup_policy_id          = azurerm_backup_policy_file_share.fslogix[0].id

  depends_on = [azurerm_backup_container_storage_account.fslogix]
}
