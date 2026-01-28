# Update Management Module

Automated patch management for Azure Virtual Desktop infrastructure using Azure Update Manager.

## Overview

This module configures Azure Update Manager with separate maintenance windows for Domain Controllers and Session Hosts, ensuring controlled updates with rolling deployments to maintain AVD availability.

## Features

### Separate Maintenance Windows
- **Domain Controller** - Independent patching schedule (typically monthly)
- **Session Hosts** - Rolling updates to prevent simultaneous reboots (typically weekly)
- **Staggered Timing** - DC and session host windows are separate to avoid conflicts

### Rolling Updates for Session Hosts
**Critical Feature**: Session hosts are configured with rolling updates to ensure continuous AVD availability:
- **Prevents simultaneous reboots** of all session hosts
- **Staggers updates** across the maintenance window
- **Health checks** before proceeding to next batch
- **Users remain connected** to healthy hosts during updates

### Flexible Configuration
- **Reboot Behavior** - IfRequired, Never, or Always
- **Patch Classifications** - Critical, Security, Updates, etc.
- **KB Exclusions** - Block specific patches known to cause issues
- **Custom Schedules** - Weekly, bi-weekly, monthly, or custom recurrence

### Emergency Patching (Optional)
- **Out-of-band patching** for critical vulnerabilities
- **Manual trigger** capability
- **Separate configuration** from regular maintenance

## Usage

```hcl
module "update_management" {
  source = "../../modules/update_management"

  resource_group_name            = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  maintenance_config_name_prefix = "avd-prod-maint"
  
  # Domain Controller Maintenance Window (First Saturday of Month)
  dc_maintenance_start_datetime = "2026-02-01T02:00:00+00:00"  # Feb 1, 2026 at 2 AM UTC
  dc_maintenance_duration       = "03:00"                       # 3-hour window
  dc_maintenance_recurrence     = "1Month"                      # Monthly
  dc_reboot_setting             = "IfRequired"
  dc_patch_classifications      = ["Critical", "Security", "UpdateRollup"]
  
  # Session Host Maintenance Window (Every Sunday)
  session_host_maintenance_start_datetime = "2026-02-02T03:00:00+00:00"  # Feb 2, 2026 at 3 AM UTC (different day!)
  session_host_maintenance_duration       = "04:00"                       # 4-hour window for rolling updates
  session_host_maintenance_recurrence     = "1Week"                       # Weekly
  session_host_reboot_setting             = "IfRequired"
  session_host_patch_classifications      = ["Critical", "Security"]
  
  # Shared Settings
  maintenance_timezone = "UTC"
  
  # Exclude problematic patches (if needed)
  kb_numbers_to_exclude = []  # Example: ["KB5001234"]
  
  # VMs to Manage
  dc_vm_id = module.domain_controller.dc_vm_id
  session_host_vm_ids = {
    for idx in range(var.session_host_count) :
    "${var.environment}-avd-sh-${idx + 1}" => module.session_hosts.vm_ids[idx]
  }
  
  # Emergency Patching (Optional)
  enable_emergency_patching = false
  
  tags = local.common_tags
}
```

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `resource_group_name` | string | Resource group for maintenance configurations |
| `location` | string | Azure region |
| `maintenance_config_name_prefix` | string | Prefix for configuration names |
| `dc_maintenance_start_datetime` | string | DC window start (RFC3339 format) |
| `session_host_maintenance_start_datetime` | string | Session host window start (RFC3339) |

### Domain Controller Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `dc_maintenance_duration` | string | `"03:00"` | Window duration (01:30 to 06:00) |
| `dc_maintenance_recurrence` | string | `"1Month"` | Frequency (1Week, 2Weeks, 1Month) |
| `dc_reboot_setting` | string | `"IfRequired"` | Reboot behavior |
| `dc_patch_classifications` | list(string) | `["Critical", "Security", "UpdateRollup", "FeaturePack", "ServicePack"]` | Patch types |

### Session Host Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `session_host_maintenance_duration` | string | `"04:00"` | Window duration (longer for rolling) |
| `session_host_maintenance_recurrence` | string | `"1Week"` | Frequency (typically weekly) |
| `session_host_reboot_setting` | string | `"IfRequired"` | Reboot behavior |
| `session_host_patch_classifications` | list(string) | `["Critical", "Security", "UpdateRollup"]` | Patch types |

### Shared Settings

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `maintenance_timezone` | string | `"UTC"` | Timezone for schedules |
| `kb_numbers_to_exclude` | list(string) | `[]` | KBs to exclude |
| `kb_numbers_to_include` | list(string) | `[]` | Specific KBs to install |
| `enable_emergency_patching` | bool | `false` | Create emergency config |

### VM Resource IDs

| Variable | Type | Description |
|----------|------|-------------|
| `dc_vm_id` | string | Domain Controller VM ID |
| `session_host_vm_ids` | map(string) | Map of session host VM IDs |

## Outputs

| Output | Description |
|--------|-------------|
| `dc_maintenance_configuration_id` | DC maintenance config resource ID |
| `session_host_maintenance_configuration_id` | Session host config resource ID |
| `dc_maintenance_window` | DC window details (start, duration, recurrence) |
| `session_host_maintenance_window` | Session host window details |
| `assigned_vm_count` | Number of VMs assigned to each config |

## Rolling Updates

### How It Works

```
Maintenance Window: 4 hours (03:00-07:00 UTC)
Session Hosts: 4 VMs (SH-1, SH-2, SH-3, SH-4)

Timeline:
03:00 - SH-1 starts patching
03:45 - SH-1 reboots, SH-2 starts patching
04:30 - SH-2 reboots, SH-3 starts patching
05:15 - SH-3 reboots, SH-4 starts patching
06:00 - SH-4 reboots
06:30 - All hosts healthy and available

During entire window:
- 3 out of 4 hosts always available
- Users can connect to healthy hosts
- No service disruption
```

### Configuration Best Practices

**1. Maintenance Window Duration:**
```hcl
# Calculate based on: (Number of hosts × Average patch time) + Buffer
# Example: 4 hosts × 45 min + 30 min buffer = 3.5 hours minimum
session_host_maintenance_duration = "04:00"  # 4 hours for 4 hosts
```

**2. Stagger DC and Session Host Windows:**
```hcl
# WRONG - Same time risks AD unavailability during session host updates
dc_maintenance_start_datetime            = "2026-02-01T02:00:00+00:00"
session_host_maintenance_start_datetime = "2026-02-01T02:00:00+00:00"  #  Same time!

# CORRECT - Different days/times ensures DC availability
dc_maintenance_start_datetime            = "2026-02-01T02:00:00+00:00"  # Saturday
session_host_maintenance_start_datetime = "2026-02-02T03:00:00+00:00"  # Sunday, 1 hour later
```

**3. Reboot Settings:**
```hcl
# Domain Controller - Be cautious with reboots
dc_reboot_setting = "IfRequired"  # Only reboot if necessary

# Session Hosts - Can be more aggressive due to rolling updates
session_host_reboot_setting = "IfRequired"  # Safe with rolling updates
```

## Maintenance Schedules

### Recommended Schedules

**Production Environment:**
```hcl
# Domain Controller: Monthly (First Saturday)
dc_maintenance_start_datetime = "2026-02-01T02:00:00+00:00"
dc_maintenance_recurrence     = "1Month"

# Session Hosts: Weekly (Every Sunday)
session_host_maintenance_start_datetime = "2026-02-02T03:00:00+00:00"
session_host_maintenance_recurrence     = "1Week"
```

**Development Environment:**
```hcl
# Both can be more frequent for testing
dc_maintenance_recurrence         = "2Weeks"
session_host_maintenance_recurrence = "1Week"
```

**High-Security Environment:**
```hcl
# More aggressive patching cadence
session_host_maintenance_recurrence = "1Week"  # Patch weekly
dc_maintenance_recurrence           = "2Weeks" # DC bi-weekly
```

### Date/Time Format (RFC3339)

**UTC Format:**
```hcl
dc_maintenance_start_datetime = "2026-02-01T02:00:00+00:00"
#                                YYYY-MM-DD HH:MM:SS TIMEZONE
```

**Common Timezones:**
- UTC: `+00:00`
- Eastern: `"2026-02-01T02:00:00-05:00"` (EST) or `"2026-02-01T02:00:00-04:00"` (EDT)
- Pacific: `"2026-02-01T02:00:00-08:00"` (PST) or `"2026-02-01T02:00:00-07:00"` (PDT)

**Tip**: Use UTC timezone variable for clarity:
```hcl
maintenance_timezone = "Eastern Standard Time"
dc_maintenance_start_datetime = "2026-02-01T02:00:00+00:00"  # Still use UTC in datetime
```

## Patch Classifications

### Classification Types

| Classification | Description | Recommended For |
|----------------|-------------|-----------------|
| `Critical` | Critical security patches | All systems |
| `Security` | Security updates | All systems |
| `UpdateRollup` | Cumulative updates | Production systems |
| `FeaturePack` | New features | Dev/test only |
| `ServicePack` | Major updates | Planned separately |
| `Definition` | Virus definitions | Anti-malware only |
| `Tools` | Tools and utilities | Rarely needed |
| `Updates` | Non-security updates | Optional |

### Recommended Configurations

**Domain Controller (Conservative):**
```hcl
dc_patch_classifications = [
  "Critical",
  "Security",
  "UpdateRollup"
]
```

**Session Hosts (Standard):**
```hcl
session_host_patch_classifications = [
  "Critical",
  "Security",
  "UpdateRollup"
]
```

**Session Hosts (Aggressive - Dev/Test):**
```hcl
session_host_patch_classifications = [
  "Critical",
  "Security",
  "UpdateRollup",
  "Updates",
  "FeaturePack"
]
```

## Excluding Problematic Patches

### KB Exclusion Examples

```hcl
# Exclude specific KBs known to cause issues
kb_numbers_to_exclude = [
  "KB5001234",  # Example: Causes blue screen on session hosts
  "KB5005678"   # Example: Breaks FSLogix profile loading
]
```

### Testing Process

1. **Test in dev environment first:**
   ```hcl
   # Dev environment - install all patches
   kb_numbers_to_exclude = []
   ```

2. **Monitor for issues** (7-14 days)

3. **Add exclusions to prod if needed:**
   ```hcl
   # Prod environment - exclude problematic patches
   kb_numbers_to_exclude = ["KB5001234"]
   ```

4. **Document exclusions** in your change log

## Emergency Patching

### When to Use Emergency Patching

- **Critical zero-day vulnerabilities** announced
- **Active exploitation** of security flaws
- **Compliance requirements** for immediate patching
- **Vendor urgent recommendations**

### Configuration

```hcl
enable_emergency_patching = true
emergency_maintenance_start_datetime = "2026-02-15T00:00:00+00:00"  # Future date for manual trigger

# Emergency window only installs Critical and Security patches
# Always reboots to ensure patches are applied immediately
```

### Triggering Emergency Maintenance

**Azure Portal:**
1. Navigate to: Update Manager → Maintenance Configurations
2. Select the emergency configuration
3. Click "Update now" or "Schedule one-time update"

**Azure CLI:**
```bash
az maintenance assignment create \
  --resource-group avd-prod-rg \
  --configuration-name avd-prod-maint-emergency \
  --resource-name DEV-DC01 \
  --resource-type virtualMachines
```

**PowerShell:**
```powershell
New-AzMaintenanceAssignment `
  -ResourceGroupName "avd-prod-rg" `
  -MaintenanceConfigurationName "avd-prod-maint-emergency" `
  -ResourceId "/subscriptions/.../virtualMachines/DEV-DC01"
```

## Monitoring and Alerts

### Key Metrics to Monitor

**Azure Portal: Update Manager Dashboard**
- Patch compliance percentage
- Pending updates count
- Failed update installations
- Last successful update time

### Recommended Alerts

**1. Failed Update Alert:**
```hcl
# Configure via Azure Monitor
Alert: Maintenance job failed
Severity: High
Action: Email ops team
```

**2. Compliance Alert:**
```hcl
Alert: VM patch compliance < 95%
Severity: Medium
Action: Review and remediate
```

**3. Reboot Required Alert:**
```hcl
Alert: Pending reboot > 7 days
Severity: Low
Action: Schedule manual reboot window
```

### KQL Queries

**Check Update Status:**
```kql
UpdateSummary
| where TimeGenerated > ago(7d)
| where Computer startswith "DEV-"
| summarize 
    TotalUpdates = sum(TotalUpdatesMissing),
    CriticalUpdates = sum(CriticalUpdatesMissing),
    SecurityUpdates = sum(SecurityUpdatesMissing)
  by Computer
| order by TotalUpdates desc
```

**View Update History:**
```kql
Update
| where TimeGenerated > ago(30d)
| where Computer startswith "DEV-"
| where UpdateState == "Needed" or UpdateState == "Installed"
| summarize count() by Computer, Classification, UpdateState
```

## Troubleshooting

### Common Issues

#### Updates Not Installing

**Cause**: VM is not running during maintenance window.
**Solution**:
```hcl
# Ensure VMs are running or enable Start-Stop automation
# Check VM power state:
Get-AzVM -ResourceGroupName "rg" -Name "vm" -Status
```

#### All Session Hosts Rebooting Simultaneously

**Cause**: Maintenance window too short for rolling updates.
**Solution**:
```hcl
# Increase duration to allow time for staggered updates
session_host_maintenance_duration = "04:00"  # Was: "02:00"
```

#### Domain Controller Unavailable During Session Host Updates

**Cause**: Overlapping maintenance windows.
**Solution**:
```hcl
# Stagger the windows - DC should complete before session hosts start
dc_maintenance_start_datetime            = "2026-02-01T02:00:00+00:00"  # Saturday 2 AM
session_host_maintenance_start_datetime = "2026-02-02T03:00:00+00:00"  # Sunday 3 AM (25 hours later)
```

#### Specific Update Fails Repeatedly

**Cause**: Dependency issue or incompatible update.
**Solution**:
```hcl
# Exclude the problematic KB
kb_numbers_to_exclude = ["KB5001234"]

# Document the exclusion and monitor for superseding updates
```

### Validation Commands

**Check Maintenance Configuration Assignment:**
```bash
az maintenance assignment list \
  --resource-group avd-prod-rg \
  --provider-name Microsoft.Compute \
  --resource-type virtualMachines \
  --resource-name DEV-DC01
```

**View Pending Updates:**
```bash
az vm assess-patches \
  --resource-group avd-prod-rg \
  --name DEV-DC01
```

**Check Last Update Run:**
```bash
az maintenance applyupdate list \
  --resource-group avd-prod-rg
```

## Best Practices

### 1. Always Test First
- Deploy updates to dev environment first
- Wait 7-14 days to identify issues
- Apply same patch exclusions to production

### 2. Separate DC and Session Host Windows
- DC maintenance should complete before session hosts start
- Ensures domain services are available during AVD updates
- Typical stagger: 24-48 hours between windows

### 3. Plan for Rolling Updates
- Duration should be: (# of hosts × 45 min) + 30% buffer
- Example: 4 hosts × 45 min + 50 min = 4 hours minimum

### 4. Monitor Patch Compliance
- Set target: >95% compliance
- Review quarterly: Exclude problematic patches if needed
- Automate reporting with Azure Monitor workbooks

### 5. Communicate Maintenance Windows
- Notify users in advance
- Use FSLogix profile container migration during maintenance
- Consider drain mode for session hosts before reboot

### 6. Document Exclusions
- Maintain change log of excluded KBs
- Include reason for exclusion
- Review monthly for superseding updates

### 7. Coordinate with AVD Features
- Enable session host drain mode before maintenance
- Use host pool scaling to maintain capacity
- Configure user notifications for pending reboots

## Cost Considerations

**Azure Update Manager Pricing:**
- **FREE** - No additional cost for Update Manager
- **Included** - Part of Azure management platform
- **No per-VM charges**

**Associated Costs:**
- Minimal compute during patching (VM already running)
- Network egress for downloading patches (typically negligible)
- Log Analytics storage if monitoring is enabled

**Cost Optimization:**
- No direct cost to optimize
- Consider scheduling updates during existing VM availability hours

## Integration with Other Services

### Azure Automation (Legacy)
Azure Update Manager **replaces** Azure Automation Update Management:
- Simpler configuration (no automation account needed)
- Better integration with Azure Monitor
- Improved rolling update capabilities

### Azure Monitor
- Automatic integration for update status
- Workbooks for compliance reporting
- Alerts for failed updates

### Azure Policy
Enforce update management compliance:
```hcl
# Example policy: Require maintenance configuration on all VMs
# Policy: "Virtual machines should have a maintenance configuration"
```

## Security Considerations

### Patch Prioritization

**Priority 1 - Critical/Security (Install ASAP):**
- Zero-day vulnerabilities
- Actively exploited vulnerabilities
- CVSS score ≥ 9.0

**Priority 2 - Important Updates:**
- Security updates with CVSS 7.0-8.9
- Update rollups
- Apply within 30 days

**Priority 3 - Optional Updates:**
- Feature packs (test first)
- Non-security updates
- Apply at convenience

### Compliance Requirements

**Common Standards:**
- **PCI-DSS**: Critical patches within 30 days
- **HIPAA**: Risk-based approach, typically 30 days
- **SOX**: Critical patches within 30 days
- **NIST**: Based on severity and risk assessment

**Example Compliance-Driven Schedule:**
```hcl
# Session Hosts: Weekly to meet 30-day requirement
session_host_maintenance_recurrence = "1Week"

# Domain Controller: Monthly (more controlled)
dc_maintenance_recurrence = "1Month"
```

## References

- [Azure Update Manager Documentation](https://learn.microsoft.com/azure/update-manager/)
- [Maintenance Configurations](https://learn.microsoft.com/azure/update-manager/manage-multiple-machines)
- [Rolling Updates](https://learn.microsoft.com/azure/update-manager/manage-updates-customized-images)
- [Azure Monitor Integration](https://learn.microsoft.com/azure/update-manager/query-logs)
- [Update Classifications](https://learn.microsoft.com/azure/update-manager/overview#update-classifications)
