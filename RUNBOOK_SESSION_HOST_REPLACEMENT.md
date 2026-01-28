# Session Host Rolling Replacement Runbook

**Purpose:** Update AVD session hosts with zero downtime using golden image rolling replacement.

**Duration:** 1-8 hours (depending on active session drain time)

**Risk Level:** Low (old hosts remain available during rollout)

---

## Overview

This runbook covers the **rolling replacement** strategy for updating session hosts:

1. Deploy new session hosts (temporarily double capacity)
2. Enable drain mode on old hosts (block new sessions)
3. Wait for active sessions to complete (1-8 hours)
4. Remove old hosts from infrastructure

**Key Benefit:** Zero downtime - users continue working on old hosts while new hosts are prepared.

**Variables Used:** Replace the following in all commands:
- `avd-dev-rg` - Your resource group name
- `avd-dev-hostpool` - Your host pool name
- `avd-sh-1`, `avd-sh-2` - Your current session host names
- `contoso.local` - Your domain name

---

## Pre-Running Checklist

Before starting, verify:

- [ ] New golden image version built and tested
- [ ] Current session host count documented (e.g., 2 VMs)
- [ ] Active session count checked (impacts drain time)
- [ ] Backup/snapshot policy confirmed
- [ ] Monitoring enabled (Azure Monitor or Log Analytics)
- [ ] Rollback plan reviewed
- [ ] Change ticket opened (if required)
- [ ] Maintenance window scheduled (optional for drain mode)

**Check active sessions:**
```bash
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, ActiveSessions:sessions, Status:status}" \
  --output table
```

**Expected Output:**
```
Name                        ActiveSessions    Status
--------------------------  ----------------  ----------
avd-sh-1.contoso.local      3                 Available
avd-sh-2.contoso.local      5                 Available
```

---

## Deploy New Session Hosts

**Duration:** 5-10 minutes (with golden image) or 30-60 minutes (marketplace image)

**Goal:** Deploy new session hosts alongside existing hosts (double capacity temporarily).

### Update Terraform Variables

Edit `envs/dev/terraform.tfvars`:

```hcl
# Before (current state)
session_host_count = 2

# After (temporary - double capacity)
session_host_count = 4

# Optional: Verify golden image enabled
enable_golden_image = true
golden_image_version = "2.0.0"  # New version
```

### Apply Terraform to Deploy New Hosts

```bash
cd envs/dev

# Preview changes
terraform plan -target=module.session_hosts

# Expected output: Plan to add 2 VMs (avd-sh-3, avd-sh-4)
# + azurerm_windows_virtual_machine.session_host[2]
# + azurerm_windows_virtual_machine.session_host[3]

# Apply changes
terraform apply -target=module.session_hosts

# Deployment time:
# - Golden image: 5-10 minutes
# - Marketplace: 30-60 minutes
```

### Verify New Hosts Registered

```bash
# Wait 2-3 minutes for AVD agent registration
sleep 180

# Check all session hosts
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, Status:status, AllowNewSession:allowNewSession, Sessions:sessions}" \
  --output table
```

**Expected Output:**
```
Name                        Status       AllowNewSession    Sessions
--------------------------  -----------  -----------------  --------
avd-sh-1.contoso.local      Available    True               3
avd-sh-2.contoso.local      Available    True               5
avd-sh-3.contoso.local      Available    True               0
avd-sh-4.contoso.local      Available    True               0
```


---

## Drain Old Session Hosts

**Duration:** 30 seconds (command execution) + 1-8 hours (session drain)

**Goal:** Prevent new sessions on old hosts, wait for active sessions to complete.

### Enable Drain Mode on Old Hosts

```bash
# Drain old session hosts (avd-sh-1, avd-sh-2)
# This sets AllowNewSession = false (no new logins, existing sessions continue)

az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-1.contoso.local" \
  --allow-new-session false

az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-2.contoso.local" \
  --allow-new-session false
```

### Verify Drain Mode Enabled

```bash
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, AllowNewSession:allowNewSession, Sessions:sessions}" \
  --output table
```

**Expected Output:**
```
Name                        AllowNewSession    Sessions
--------------------------  -----------------  --------
avd-sh-1.contoso.local      False              3        # Drain mode (old)
avd-sh-2.contoso.local      False              5        # Drain mode (old)
avd-sh-3.contoso.local      True               0        # Accepting new (new)
avd-sh-4.contoso.local      True               0        # Accepting new (new)
```

**Drain mode enabled:** New users will connect to avd-sh-3/avd-sh-4 only.

### Notify Users (Optional but Recommended)

**Option A: Azure Portal Message**

1. Navigate to **Azure Virtual Desktop** > **Host pools** > **avd-dev-hostpool**
2. Select **Session hosts** > Select **avd-sh-1**
3. Click **Send message**
4. Configure message:
   - **Title:** "Planned Maintenance"
   - **Message:** "System maintenance scheduled in 2 hours. Please save your work and sign out. You will automatically reconnect to an updated session host."
   - **Type:** Warning
5. Repeat for **avd-sh-2**

**Option B: PowerShell Bulk Message**

```powershell
# Send message to all users on old hosts
$ResourceGroup = "avd-dev-rg"
$HostPool = "avd-dev-hostpool"
$OldHosts = @("avd-sh-1.contoso.local", "avd-sh-2.contoso.local")

foreach ($HostName in $OldHosts) {
    Send-AzWvdUserSessionMessage `
        -ResourceGroupName $ResourceGroup `
        -HostPoolName $HostPool `
        -SessionHostName $HostName `
        -MessageTitle "Planned Maintenance in 2 Hours" `
        -MessageBody "Please save your work and sign out by 5:00 PM. You can reconnect immediately to continue working." `
        -MessageType Warning
}
```

### Monitor Session Drain Progress

```bash
# Monitor active sessions every 5 minutes
watch -n 300 'az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[?contains(name, \"avd-sh-1\") || contains(name, \"avd-sh-2\")].{Name:name, Sessions:sessions, AllowNew:allowNewSession}" \
  --output table'
```

**Expected Timeline:**
- **Hour 0-1:** Gradual session decrease (users log off naturally)
- **Hour 1-2:** 50-70% sessions remain (lunch breaks, end of workday)
- **Hour 2-4:** 20-40% sessions remain (long-running tasks, idle sessions)
- **Hour 4-8:** 0-10% sessions remain (overnight batch jobs, forgotten sessions)

**Decision Point:** Wait for organic logout OR force logoff after grace period.

### Force Logoff (Optional, After Grace Period)

**Use Cautiously:** Only after users have been notified and grace period expired.

```powershell
# Force logoff after 2-hour grace period
$ResourceGroup = "avd-dev-rg"
$HostPool = "avd-dev-hostpool"
$OldHosts = @("avd-sh-1.contoso.local", "avd-sh-2.contoso.local")

foreach ($HostName in $OldHosts) {
    # Get all active sessions
    $Sessions = Get-AzWvdUserSession `
        -ResourceGroupName $ResourceGroup `
        -HostPoolName $HostPool `
        -SessionHostName $HostName
    
    # Force logoff each session
    foreach ($Session in $Sessions) {
        Write-Host "Logging off user: $($Session.ActiveDirectoryUserName) from $HostName"
        Remove-AzWvdUserSession `
            -ResourceGroupName $ResourceGroup `
            -HostPoolName $HostPool `
            -SessionHostName $HostName `
            -Id $Session.Name `
            -Force
    }
}

# Verify sessions cleared
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[?contains(name, 'avd-sh-1') || contains(name, 'avd-sh-2')].{Name:name, Sessions:sessions}" \
  --output table
```

**Expected Output:**
```
Name                        Sessions
--------------------------  --------
avd-sh-1.contoso.local      0
avd-sh-2.contoso.local      0
```

**Complete:** Old hosts drained (0 active sessions).

---

## Deallocate Old Hosts (Optional)

**Duration:** 2 minutes

**Goal:** Stop compute billing while keeping VMs for potential rollback (24-48 hour testing period).

### Deallocate Old VMs

```bash
# Stop VMs without deleting (saves ~$70/VM/month in compute costs)
az vm deallocate --resource-group avd-dev-rg --name avd-sh-1 --no-wait
az vm deallocate --resource-group avd-dev-rg --name avd-sh-2 --no-wait

# Wait for deallocation to complete
sleep 120
```

### Verify Deallocation

```bash
# Check VM power state
az vm get-instance-view --resource-group avd-dev-rg --name avd-sh-1 \
  --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv

# Expected: "VM deallocated"

az vm get-instance-view --resource-group avd-dev-rg --name avd-sh-2 \
  --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv

# Expected: "VM deallocated"
```

**Complete:** Old hosts deallocated (no compute cost, disks retained).

**Testing Period:** Monitor new hosts for 24-48 hours before final removal.

---

## Testing & Validation

**Duration:** 24-48 hours

**Goal:** Verify new hosts are stable before removing old hosts permanently.

### Monitor New Host Health

```bash
# Check session host status every hour
watch -n 3600 'az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[?contains(name, \"avd-sh-3\") || contains(name, \"avd-sh-4\")].{Name:name, Status:status, Sessions:sessions, UpdateState:updateState}" \
  --output table'
```

### Validate Key Metrics

| Metric | Check Command | Expected Value |
|--------|---------------|----------------|
| **AVD Status** | `az desktopvirtualization sessionhost show ... --query status` | `Available` |
| **Active Sessions** | `az desktopvirtualization sessionhost show ... --query sessions` | > 0 (users connecting) |
| **FSLogix Profiles** | RDP to host, check `C:\ProfileContainers\*.vhdx` | Files present |
| **Windows Updates** | RDP to host, check `Get-WindowsUpdate -Last 30` | Updates applied |
| **Applications** | RDP to host, check Start menu | Apps installed |
| **Performance** | Azure Monitor, check CPU/Memory | < 80% average |

### User Feedback Collection

```bash
# Check for user-reported issues
# Review:
# - Help desk tickets
# - Azure Monitor Application Insights (if enabled)
# - User surveys or feedback channels
```

**Complete:** New hosts validated, no issues reported for 24-48 hours.

---

## Remove Old Hosts Permanently

**Duration:** 5 minutes

**Goal:** Clean up old hosts and restore original vm_count.

### Remove Old Hosts from Terraform State

```bash
# Remove old hosts from Terraform state (preserves VMs in Azure temporarily)
cd envs/dev

terraform state rm 'module.session_hosts.azurerm_network_interface.session_host[0]'
terraform state rm 'module.session_hosts.azurerm_network_interface.session_host[1]'
terraform state rm 'module.session_hosts.azurerm_windows_virtual_machine.session_host[0]'
terraform state rm 'module.session_hosts.azurerm_windows_virtual_machine.session_host[1]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.domain_join[0]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.domain_join[1]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.avd_agent[0]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.avd_agent[1]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.fslogix_config[0]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.fslogix_config[1]'
```

### Update Terraform Variables

Edit `envs/dev/terraform.tfvars`:

```hcl
# Restore original vm_count
session_host_count = 2  # Back to original (was temporarily 4)
```

### Apply Terraform Changes

```bash
# Apply to sync state (no resources destroyed, just state updated)
terraform apply

# Expected: "No changes. Your infrastructure matches the configuration."
```

### Delete Old VMs from Azure

```bash
# Permanently delete old VMs (including disks, NICs)
az vm delete --resource-group avd-dev-rg --name avd-sh-1 --yes --no-wait
az vm delete --resource-group avd-dev-rg --name avd-sh-2 --yes --no-wait

# Wait for deletion to complete
sleep 60

# Verify deletion
az vm show --resource-group avd-dev-rg --name avd-sh-1 2>/dev/null
# Expected: ERROR: (ResourceNotFound)

az vm show --resource-group avd-dev-rg --name avd-sh-2 2>/dev/null
# Expected: ERROR: (ResourceNotFound)
```

### Clean Up Session Host Registrations

```bash
# Remove old hosts from AVD host pool (if still registered)
az desktopvirtualization sessionhost delete \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-1.contoso.local" \
  --force

az desktopvirtualization sessionhost delete \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-2.contoso.local" \
  --force

# Verify only new hosts remain
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, Status:status}" \
  --output table
```

**Expected Output:**
```
Name                        Status
--------------------------  ----------
avd-sh-3.contoso.local      Available
avd-sh-4.contoso.local      Available
```

**Complete:** Old hosts removed, infrastructure clean.

---

## Rollback Procedure

**When to use:** If new hosts have issues discovered during the testing period.

**Prerequisite:** Old hosts must still exist (deallocated or running).

### Re-enable Old Hosts

```bash
# Start deallocated VMs
az vm start --resource-group avd-dev-rg --name avd-sh-1 --no-wait
az vm start --resource-group avd-dev-rg --name avd-sh-2 --no-wait

# Wait for VMs to start
sleep 120

# Remove drain mode (allow new sessions)
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-1.contoso.local" \
  --allow-new-session true

az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-2.contoso.local" \
  --allow-new-session true
```

### Drain New Hosts

```bash
# Enable drain mode on new hosts
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-3.contoso.local" \
  --allow-new-session false

az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-4.contoso.local" \
  --allow-new-session false
```

### Remove New Hosts

```bash
# After sessions drain, destroy new hosts
cd envs/dev

# Update vm_count back to original
# terraform.tfvars: session_host_count = 2

terraform apply -target=module.session_hosts
# This will destroy avd-sh-3 and avd-sh-4
```

---

## Post-Deployment Checklist

- [ ] New session hosts (avd-sh-3, avd-sh-4) are Available status
- [ ] Old session hosts (avd-sh-1, avd-sh-2) deleted from Azure
- [ ] AVD host pool shows only 2 active hosts
- [ ] Terraform state matches actual infrastructure
- [ ] User feedback collected (no issues reported)
- [ ] Monitoring alerts reviewed (no anomalies)
- [ ] Documentation updated (new image version, deployment date)
- [ ] Change ticket closed (if applicable)
- [ ] Team notified of successful deployment

---

## Best Practices

### 1. Schedule During Low Usage Periods
- **Ideal times:** Weekends, after hours, holidays
- **Check usage:** Run `az desktopvirtualization sessionhost list` to verify low session count before starting

### 2. Always Test Golden Images Before Production
```bash
# Deploy test session host with new image
# terraform.tfvars: session_host_count = 3 (add 1 test host)
# Test for 24 hours with pilot users before full rollout
```

### 3. Automate Session Monitoring
```bash
# Create Azure Monitor alert for failed session hosts
az monitor metrics alert create \
  --name "AVD-SessionHost-Unavailable" \
  --resource-group avd-dev-rg \
  --scopes /subscriptions/.../hostpools/avd-dev-hostpool \
  --condition "avg Status == 0" \
  --description "Session host unavailable for 5 minutes"
```

### 4. Document Image Versions
```bash
# Tag new hosts with image version
az vm update \
  --resource-group avd-dev-rg \
  --name avd-sh-3 \
  --set tags.ImageVersion=2.0.0 tags.DeployedDate=2026-01-26
```

### 5. Keep Rollback Window Open
- **Recommended:** Retain old VMs (deallocated) for 48 hours minimum
- **Cost:** $0 compute (deallocated), ~$20/month disk storage (temporary)
- **Benefit:** Instant rollback if issues discovered

---

## Troubleshooting

### Issue: New hosts not appearing in AVD host pool

**Solution:**
```bash
# Check AVD agent extension status
az vm extension show \
  --resource-group avd-dev-rg \
  --vm-name avd-sh-3 \
  --name DSC \
  --query "{Status:provisioningState, Message:instanceView.statuses[0].message}"

# Re-apply extension if failed
terraform apply -target='module.session_hosts.azurerm_virtual_machine_extension.avd_agent[2]'
```

### Issue: Users can't connect to new hosts

**Solution:**
```bash
# Verify domain join
az vm run-command invoke \
  --resource-group avd-dev-rg \
  --name avd-sh-3 \
  --command-id RunPowerShellScript \
  --scripts "(Get-WmiObject -Class Win32_ComputerSystem).Domain"

# Expected: "contoso.local"
```

### Issue: FSLogix profiles not working on new hosts

**Solution:**
```bash
# Check FSLogix registry settings
az vm run-command invoke \
  --resource-group avd-dev-rg \
  --name avd-sh-3 \
  --command-id RunPowerShellScript \
  --scripts "Get-ItemProperty -Path 'HKLM:\SOFTWARE\FSLogix\Profiles' -Name 'VHDLocations'"

# Expected: "\\storage.file.core.windows.net\profiles"
```

---

## Summary

**Total Duration:** 1-8 hours (mostly passive session drain time)

**Active Work:** ~30 minutes (Terraform apply + Azure CLI commands)

**Risk:** Low (old hosts remain available as fallback)

**User Impact:** Zero downtime (users unaffected, transparent migration)

**Cost Impact:** Temporary doubling of VM costs during rollout (~$4-8/hour for 2 extra VMs)

---

## Related Documentation

- [Session Hosts Module README](modules/session-hosts/README.md)
- [Golden Image Module README](modules/golden_image/README.md)
- [Azure AVD Drain Mode Documentation](https://docs.microsoft.com/azure/virtual-desktop/drain-mode)
- [Terraform State Management](https://www.terraform.io/docs/language/state/index.html)
