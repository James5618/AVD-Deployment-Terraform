# Backup Module

Azure Backup protection for Azure Virtual Desktop infrastructure.

## Overview

This module provisions a Recovery Services Vault and configures comprehensive backup protection for Domain Controllers, Session Hosts, and FSLogix user profiles.

## Features

### Recovery Services Vault
- Standard SKU with geo-redundant storage
- Soft delete protection (14-day retention after deletion)
- Centralized backup management

### VM Backup Protection
Automatically configured for:
- **Domain Controller** - Daily backups with configurable retention
- **Session Hosts** - All AVD VMs protected with same policy
- **Flexible Retention** - Daily, weekly, monthly, and yearly retention options

### Azure Files Backup (Optional)
- **FSLogix User Profiles** - Backup the "user-profiles" file share
- **Snapshot-based** - Fast recovery with instant restore
- **Separate Retention** - Independent policy from VM backups

### Backup Schedule
- **Daily backups** at configurable time (default: 02:00 UTC)
- **Timezone-aware** scheduling
- **Off-peak execution** to minimize performance impact

## Usage

```hcl
module "backup" {
  source = "../../modules/backup"

  # Basic Configuration
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  recovery_vault_name = "avd-prod-backup-vault"
  
  # VM Backup Retention (Daily + Weekly)
  vm_backup_retention_days  = 7      # 7 daily recovery points
  vm_backup_retention_weeks = 4      # 4 weekly recovery points
  vm_backup_retention_months = 0     # Disabled for cost savings
  vm_backup_retention_years  = 0     # Disabled for cost savings
  
  # Backup Schedule
  backup_time     = "02:00"          # 2 AM daily
  backup_timezone = "UTC"
  
  # VMs to Backup
  dc_vm_id = module.domain_controller.dc_vm_id
  session_host_vm_ids = {
    for idx in range(var.session_host_count) :
    "${var.environment}-avd-sh-${idx + 1}" => module.session_hosts.vm_ids[idx]
  }
  
  # FSLogix Backup (Optional)
  fslogix_backup_enabled        = true
  fslogix_backup_retention_days = 7
  fslogix_backup_retention_weeks = 4
  storage_account_id            = module.fslogix_storage.storage_account_id
  fslogix_share_name            = "user-profiles"
  
  tags = local.common_tags
}
```

## Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Name of the resource group where the Recovery Services Vault will be created | `string` | - | Yes |
| `location` | Azure region for the Recovery Services Vault | `string` | - | Yes |
| `recovery_vault_name` | Name of the Recovery Services Vault | `string` | - | Yes |
| `vm_backup_retention_days` | Number of days to retain daily VM backups (7-9999 days) | `number` | `7` | No |
| `vm_backup_retention_weeks` | Number of weeks to retain weekly VM backups (0-5163 weeks) | `number` | `4` | No |
| `vm_backup_retention_months` | Number of months to retain monthly VM backups (0-1188 months) | `number` | `0` | No |
| `vm_backup_retention_years` | Number of years to retain yearly VM backups (0-99 years) | `number` | `0` | No |
| `fslogix_backup_enabled` | Enable Azure Files backup for FSLogix user profiles share | `bool` | `false` | No |
| `fslogix_backup_retention_days` | Number of days to retain daily Azure Files backups (1-200 days) | `number` | `7` | No |
| `fslogix_backup_retention_weeks` | Number of weeks to retain weekly Azure Files backups (0-200 weeks) | `number` | `4` | No |
| `fslogix_backup_retention_months` | Number of months to retain monthly Azure Files backups (0-120 months) | `number` | `0` | No |
| `fslogix_backup_retention_years` | Number of years to retain yearly Azure Files backups (0-10 years) | `number` | `0` | No |
| `backup_time` | Time of day to run backups (HH:MM format, 24-hour) | `string` | `"02:00"` | No |
| `backup_timezone` | Timezone for backup schedule (e.g., 'UTC', 'Eastern Standard Time') | `string` | `"UTC"` | No |
| `backup_weekly_retention_weekdays` | Days of the week to retain weekly backups | `list(string)` | `["Sunday"]` | No |
| `backup_monthly_retention_weekdays` | Days of the week to retain monthly backups | `list(string)` | `["Sunday"]` | No |
| `backup_monthly_retention_weeks` | Weeks of the month to retain monthly backups (First, Second, Third, Fourth, Last) | `list(string)` | `["First"]` | No |
| `backup_yearly_retention_weekdays` | Days of the week to retain yearly backups | `list(string)` | `["Sunday"]` | No |
| `backup_yearly_retention_weeks` | Weeks of the month to retain yearly backups | `list(string)` | `["First"]` | No |
| `backup_yearly_retention_months` | Months of the year to retain yearly backups | `list(string)` | `["January"]` | No |
| `enable_soft_delete` | Enable soft delete for Recovery Services Vault (protects backups from accidental deletion for 14 days) | `bool` | `true` | No |
| `dc_vm_id` | Resource ID of the Domain Controller VM to backup. Set to null to skip DC backup | `string` | `null` | No |
| `session_host_vm_ids` | Map of session host VM resource IDs to backup (key = VM name or index, value = resource ID) | `map(string)` | `{}` | No |
| `storage_account_id` | Resource ID of the storage account containing the FSLogix file share. Required if fslogix_backup_enabled = true | `string` | `null` | No |
| `fslogix_share_name` | Name of the Azure Files share containing user profiles (typically 'user-profiles'). Required if fslogix_backup_enabled = true | `string` | `null` | No |
| `tags` | Tags to apply to backup resources | `map(string)` | `{}` | No |

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `resource_group_name` | string | Resource group for Recovery Services Vault |
| `location` | string | Azure region |
| `recovery_vault_name` | string | Vault name |

### VM Backup Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vm_backup_retention_days` | number | `7` | Daily retention (7-9999 days) |
| `vm_backup_retention_weeks` | number | `4` | Weekly retention (0-5163 weeks) |
| `vm_backup_retention_months` | number | `0` | Monthly retention (0-1188 months) |
| `vm_backup_retention_years` | number | `0` | Yearly retention (0-99 years) |

### Azure Files Backup Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `fslogix_backup_enabled` | bool | `false` | Enable Azure Files backup |
| `fslogix_backup_retention_days` | number | `7` | Daily retention (1-200 days) |
| `fslogix_backup_retention_weeks` | number | `4` | Weekly retention (0-200 weeks) |
| `fslogix_backup_retention_months` | number | `0` | Monthly retention (0-120 months) |
| `fslogix_backup_retention_years` | number | `0` | Yearly retention (0-10 years) |

### Schedule Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `backup_time` | string | `"02:00"` | Backup time (HH:MM, 24-hour) |
| `backup_timezone` | string | `"UTC"` | Timezone for schedule |
| `backup_weekly_retention_weekdays` | list(string) | `["Sunday"]` | Days for weekly backups |

### Resource IDs

| Variable | Type | Description |
|----------|------|-------------|
| `dc_vm_id` | string | Domain Controller VM ID |
| `session_host_vm_ids` | map(string) | Map of session host VM IDs |
| `storage_account_id` | string | Storage account ID (for Azure Files backup) |
| `fslogix_share_name` | string | File share name (typically "user-profiles") |

### Vault Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_soft_delete` | bool | `true` | Protect backups from accidental deletion (14 days) |

## Outputs

| Output | Description |
|--------|-------------|
| `recovery_services_vault_id` | Vault resource ID |
| `recovery_services_vault_name` | Vault name |
| `vm_backup_policy_id` | VM backup policy ID |
| `fslogix_backup_policy_id` | Azure Files backup policy ID |
| `dc_backup_enabled` | Whether DC backup is enabled |
| `session_hosts_backup_count` | Number of session hosts with backup |
| `fslogix_backup_enabled` | Whether Azure Files backup is enabled |

## Cost Considerations

### Azure Backup Pricing Components

**1. Protected Instances (VMs):**
- First 50 instances: **$5/month per instance**
- Domain Controller: $5/month
- 2 Session Hosts: $10/month
- **Subtotal**: $15/month

**2. Backup Storage (VM):**
- GRS Storage: **$0.10 per GB/month**
- Typical VM backup size: 30-50 GB per VM
- 3 VMs × 40 GB average × 7 days = ~840 GB
- **Subtotal**: ~$84/month

**3. Azure Files Backup:**
- Snapshot storage: **$0.05 per GB/month**
- 100 GB profile share × 7 snapshots = 700 GB
- **Subtotal**: ~$35/month

**Total Estimated Cost: ~$134/month**

### Cost Optimization Strategies

#### 1. Reduce Retention Periods
```hcl
# Minimal retention (cost-effective for dev/test)
vm_backup_retention_days  = 7      # 7 days only
vm_backup_retention_weeks = 0      # Disable weekly
```
**Savings**: ~40% reduction in backup storage costs

#### 2. Disable Session Host Backups
```hcl
# Backup DC only (session hosts are ephemeral)
session_host_vm_ids = {}           # Empty map
```
**Savings**: $10/month (instances) + ~$56/month (storage) = **~$66/month**

**Rationale**: Session hosts can be rebuilt from images; only DC contains critical AD data.

#### 3. Disable FSLogix Backup
```hcl
fslogix_backup_enabled = false
```
**Savings**: ~$35/month

**Alternative**: Use Azure Files soft delete (free) for 7-day protection.

#### 4. Development Environment Settings
```hcl
# Minimal backup for dev environments
vm_backup_retention_days   = 7     # Minimum retention
vm_backup_retention_weeks  = 0     # No weekly
fslogix_backup_enabled     = false # Rely on soft delete
session_host_vm_ids        = {}    # DC only
```
**Total Cost**: ~$8-15/month (DC backup only)

### Production vs. Development

**Production Recommendations:**
- Daily: 30 days
- Weekly: 12 weeks (3 months)
- Monthly: 12 months (1 year)
- Yearly: 3-7 years (compliance)

**Development Recommendations:**
- Daily: 7 days
- Weekly: 0 (disabled)
- Monthly: 0 (disabled)
- Session hosts: Not backed up (ephemeral)

## Backup Schedule Best Practices

### Recommended Times by Timezone

**UTC Environments:**
```hcl
backup_time     = "02:00"
backup_timezone = "UTC"
```

**US East Coast:**
```hcl
backup_time     = "02:00"
backup_timezone = "Eastern Standard Time"
```

**US West Coast:**
```hcl
backup_time     = "02:00"
backup_timezone = "Pacific Standard Time"
```

### Weekly Backup Days

Choose days with lowest user activity:
```hcl
backup_weekly_retention_weekdays = ["Sunday"]    # Typical for business environments
# OR
backup_weekly_retention_weekdays = ["Saturday"]  # Alternative
```

## Recovery Procedures

### VM Restore Options

**1. Full VM Restore:**
- Restores entire VM to new location
- Use for disaster recovery
- Time: 30-60 minutes

**2. File-Level Recovery:**
- Mount backup as iSCSI disk
- Copy specific files
- Time: 5-10 minutes

**3. Disk Restore:**
- Restore individual disks
- Attach to existing or new VM
- Time: 15-30 minutes

### Azure Files Restore Options

**1. Full Share Restore:**
```powershell
# Restore entire "user-profiles" share
Restore-AzRecoveryServicesBackupItem `
  -RecoveryPoint $rp `
  -RestoreToSecondaryRegion
```

**2. Item-Level Restore:**
```powershell
# Restore specific user profile
Restore-AzRecoveryServicesBackupItem `
  -RecoveryPoint $rp `
  -SourceFilePath "/user1.VHDX" `
  -TargetFilePath "/restored/"
```

### Recovery Time Objectives (RTO)

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single file from Azure Files | 5 min | 24 hours |
| Full user profile restore | 15 min | 24 hours |
| Session host VM restore | 45 min | 24 hours |
| Domain Controller restore | 60 min | 24 hours |
| Full environment rebuild | 2-4 hours | 24 hours |

## Monitoring and Alerts

### Azure Portal Monitoring

**Navigate to Recovery Services Vault:**
1. Backup Jobs - View backup job status
2. Backup Items - See protected VMs and file shares
3. Backup Alerts - Configure alert rules

### Key Metrics to Monitor

- **Backup Success Rate** - Should be 100%
- **Backup Duration** - Baseline for performance
- **Storage Growth** - Track retention costs
- **Failed Backup Jobs** - Immediate attention required

### Recommended Alerts

**1. Backup Failure Alert:**
```hcl
# Configure in Azure Portal or via Terraform azurerm_monitor_metric_alert
# Alert when any backup job fails
Severity: Critical
Action: Email admin team
```

**2. Long Backup Duration:**
```hcl
# Alert if backup takes >4 hours
Severity: Warning
Action: Review VM performance
```

**3. Storage Growth:**
```hcl
# Alert if backup storage exceeds budget threshold
Severity: Informational
Action: Review retention policy
```

## Troubleshooting

### Common Issues

#### Backup Job Fails - "UserErrorVMNotInDesirableState"
**Cause**: VM is not in a running or stopped state during backup.
**Solution**:
```powershell
# Ensure VM is in stable state
Get-AzVM -ResourceGroupName "rg" -Name "vm" | Select-Object PowerState
# If deallocated, start VM before backup
```

#### Azure Files Backup Fails - "UserErrorStorageAccountNotRegistered"
**Cause**: Storage account not registered with Recovery Services Vault.
**Solution**:
- Ensure `azurerm_backup_container_storage_account` resource is created
- Wait 5-10 minutes for registration to complete
- Retry backup operation

#### "ProtectionContainerNotRegistered"
**Cause**: Storage account container not fully registered.
**Solution**:
```bash
# Verify container registration
az backup container show \
  --resource-group rg \
  --vault-name vault \
  --name "storagecontainer;Storage;rg;storageaccountname"
```

#### Soft Delete Warning
**Issue**: Cannot delete backup data due to soft delete.
**Solution**:
```powershell
# Disable soft delete (requires admin approval)
Set-AzRecoveryServicesVaultProperty `
  -VaultId $vault.ID `
  -SoftDeleteFeatureState Disable
```

### Validation Steps

**Verify VM Backup Protection:**
```bash
az backup protection check-vm \
  --resource-group avd-prod-rg \
  --vm-name DEV-DC01 \
  --vault-name avd-prod-backup-vault
```

**List Backup Items:**
```bash
az backup item list \
  --resource-group avd-prod-rg \
  --vault-name avd-prod-backup-vault \
  --backup-management-type AzureIaasVM
```

**Check Latest Recovery Point:**
```bash
az backup recoverypoint list \
  --resource-group avd-prod-rg \
  --vault-name avd-prod-backup-vault \
  --item-name VM;iaasvmcontainerv2;rg;vmname \
  --backup-management-type AzureIaasVM
```

## Security Considerations

### Soft Delete Protection
- **Enabled by default** - Backups retained 14 days after deletion
- **Prevents**: Accidental or malicious backup deletion
- **Compliance**: Meets regulatory requirements for data retention

### RBAC Permissions Required

**Backup Operator Role:**
- Can enable/disable backup
- Can perform restore operations
- Cannot delete backups (requires Backup Contributor)

**Backup Contributor Role:**
- Full backup management
- Can delete backups (if soft delete disabled)
- Can modify policies

### Encryption

**VM Backups:**
- Encrypted using Azure Storage Service Encryption (SSE)
- Uses Microsoft-managed keys by default
- Option: Customer-managed keys (CMK) for compliance

**Azure Files Snapshots:**
- Encrypted using same keys as source storage account
- Inherits encryption settings from storage account

## Compliance and Governance

### Retention for Compliance

**GDPR (Europe):**
- Minimum: 1 year
- Recommended: 3 years for business records

**HIPAA (Healthcare):**
- Minimum: 6 years

**SOX (Financial):**
- Minimum: 7 years

**Example Production Policy:**
```hcl
vm_backup_retention_days   = 30    # Daily: 30 days
vm_backup_retention_weeks  = 12    # Weekly: 3 months
vm_backup_retention_months = 36    # Monthly: 3 years
vm_backup_retention_years  = 7     # Yearly: 7 years (first Sunday of January)
```

### Audit Trail

All backup operations are logged to Azure Activity Log:
- Backup job start/completion
- Restore operations
- Policy modifications
- Vault configuration changes

**Query Activity Log:**
```kql
AzureActivity
| where ResourceProvider == "Microsoft.RecoveryServices"
| where TimeGenerated > ago(30d)
| project TimeGenerated, Caller, OperationName, ActivityStatus
```

## Integration with Disaster Recovery

This backup module provides **data protection**. For full DR, consider:

1. **Azure Site Recovery** - VM replication to secondary region
2. **Read-Access Geo-Redundant Storage (RA-GRS)** - Storage account replication
3. **Multi-Region Deployment** - Active-active or active-passive

**Backup + Site Recovery = Comprehensive DR**

## References

- [Azure Backup Documentation](https://learn.microsoft.com/azure/backup/)
- [Azure Backup Pricing](https://azure.microsoft.com/pricing/details/backup/)
- [Backup Center](https://learn.microsoft.com/azure/backup/backup-center-overview)
- [Azure Files Backup](https://learn.microsoft.com/azure/backup/azure-file-share-backup-overview)
- [VM Backup Architecture](https://learn.microsoft.com/azure/backup/backup-architecture)
