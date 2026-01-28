# AVD Operations & Troubleshooting Guide

## Overview

This guide covers day-to-day operations, monitoring, and troubleshooting for your Azure Virtual Desktop (AVD) environment. Use this as a reference for common operational tasks and resolving issues.

**Quick Links:**
- [Connection Logs](#avd-connection-logs) - Diagnose user connection issues
- [FSLogix Logs](#fslogix-logs) - Profile loading and storage issues
- [Backup Verification](#verify-backups-are-running) - Ensure disaster recovery is working
- [Profile Recovery](#restore-deleted-fslogix-profile) - Recover accidentally deleted profiles
- [Common Alerts](#common-alerts-to-create) - Proactive monitoring alerts

---

## Table of Contents

1. [AVD Connection Logs](#avd-connection-logs)
2. [FSLogix Logs](#fslogix-logs)
3. [Verify Backups Are Running](#verify-backups-are-running)
4. [Restore Deleted FSLogix Profile](#restore-deleted-fslogix-profile)
5. [Common Alerts to Create](#common-alerts-to-create)
6. [Performance Troubleshooting](#performance-troubleshooting)
7. [Session Host Health Checks](#session-host-health-checks)
8. [Domain Controller Operations](#domain-controller-operations)
9. [Storage Account Operations](#storage-account-operations)
10. [Quick Reference Commands](#quick-reference-commands)

---

## AVD Connection Logs

### Where to Find AVD Connection Logs

AVD connection diagnostics are available in multiple locations depending on what you're troubleshooting.

#### 1. **Azure Portal - AVD Insights (Recommended)**

**Location:** Azure Portal → Azure Virtual Desktop → Insights

**What You'll See:**
- Connection success/failure rates
- Connection duration and latency
- User connection timeline
- Error codes and failure reasons
- Session host utilization

**Steps:**
1. Navigate to Azure Portal → **Azure Virtual Desktop**
2. Select **Insights** (requires Log Analytics workspace - included in this deployment)
3. Choose timeframe (last 24 hours, 7 days, etc.)
4. View:
   - **Connection Performance** - Latency and bandwidth
   - **Connection Reliability** - Success vs. failure rates
   - **User Activity** - Who connected, when, and from where

**Key Metrics:**
- `ConnectionSuccessRate` - Should be >95%
- `AverageConnectionDuration` - Typical: 30-60 seconds
- `ConnectionErrors` - Error codes (see table below)

#### 2. **Log Analytics Workspace**

**Query Connection Attempts:**

```kql
// All connection attempts in last 24 hours
WVDConnections
| where TimeGenerated > ago(24h)
| project TimeGenerated, UserName, State, ClientOS, ClientVersion, ConnectionType, CorrelationId
| order by TimeGenerated desc
| take 100

// Failed connections only
WVDConnections
| where TimeGenerated > ago(24h)
| where State == "Failed"
| project TimeGenerated, UserName, State, FailureReason, ErrorCode, CorrelationId
| order by TimeGenerated desc

// Specific user's connection history
WVDConnections
| where TimeGenerated > ago(7d)
| where UserName contains "john.doe"
| project TimeGenerated, State, SessionHostName, ConnectionType, ClientOS
| order by TimeGenerated desc
```

**Query Session Durations:**

```kql
// Average session duration by user
WVDConnections
| where TimeGenerated > ago(7d)
| where State == "Connected"
| summarize AvgDuration = avg(Duration) by UserName
| order by AvgDuration desc

// Long-running sessions (>8 hours)
WVDConnections
| where TimeGenerated > ago(24h)
| where Duration > 28800 // 8 hours in seconds
| project TimeGenerated, UserName, SessionHostName, Duration
```

#### 3. **Session Host Event Logs**

**Location on Session Host VM:**
- Event Viewer → Applications and Services Logs → Microsoft → Windows → TerminalServices-RemoteConnectionManager → Operational
- Event Viewer → Applications and Services Logs → Microsoft → Windows → TerminalServices-LocalSessionManager → Operational

**Key Event IDs:**

| Event ID | Log | Description |
|----------|-----|-------------|
| **1149** | RemoteConnectionManager | Successful RDP authentication |
| **1158** | RemoteConnectionManager | Connection authentication failed |
| **21** | LocalSessionManager | Remote Desktop Services - Session logon succeeded |
| **24** | LocalSessionManager | Remote Desktop Services - Session has been disconnected |
| **25** | LocalSessionManager | Remote Desktop Services - Session reconnection succeeded |
| **39** | LocalSessionManager | Session X has been disconnected by session Y |
| **40** | LocalSessionManager | Session X has been reconnected to session Y |

**PowerShell Query:**

```powershell
# Get last 50 RDP connection events
Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational" -MaxEvents 50 |
  Where-Object { $_.Id -in @(1149, 1158) } |
  Format-Table TimeCreated, Id, Message -AutoSize

# Get user logon/logoff events
Get-WinEvent -LogName "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational" -MaxEvents 50 |
  Where-Object { $_.Id -in @(21, 23, 24, 25) } |
  Format-Table TimeCreated, Id, Message -AutoSize
```

#### 4. **Common Connection Error Codes**

| Error Code | Description | Common Causes | Resolution |
|------------|-------------|---------------|------------|
| **0x204** | The connection was terminated | Network interruption | Check network stability, VPN |
| **0x3** | No available session hosts | No session hosts or all at max capacity | Add session hosts or increase `maximum_sessions_allowed` |
| **0x908** | Timeout waiting for session | Session host overloaded | Scale up session host VM size or add more session hosts |
| **0xC000006D** | Logon failure: bad username/password | Authentication failed | Verify AD credentials, check account lockout |
| **0xC0000064** | Logon failure: user name does not exist | User not found in AD | Check user exists in Active Directory domain |
| **0xC0000072** | Account disabled | User account disabled | Enable account in Active Directory |
| **0xC000006F** | Logon outside allowed time | GPO time restrictions | Check GPO logon hours policy |
| **0xC0000193** | Account expiration | User account expired | Extend account expiration date |
| **0x112F** | Profile load failure | FSLogix profile issue | Check FSLogix logs (see section below) |

#### 5. **Connection Broker Logs**

**Azure Portal Location:**
- Azure Virtual Desktop → Host Pools → [your-host-pool] → Session hosts → Select session host → **Diagnostics**

**View Connection Broker Activity:**
```kql
WVDAgentHealthStatus
| where TimeGenerated > ago(1h)
| where Status != "Available"
| project TimeGenerated, SessionHostName, Status, LastHeartBeat
| order by TimeGenerated desc
```

---

## FSLogix Logs

FSLogix maintains both Windows Event Logs and detailed file-based logs for profile operations.

### FSLogix Event Logs (Recommended for Real-Time Monitoring)

**Location on Session Host VM:**
- Event Viewer → Applications and Services Logs → **FSLogix-Apps/Operational**
- Event Viewer → Applications and Services Logs → **FSLogix-Apps/Admin**

#### **Key Event IDs:**

| Event ID | Severity | Description | Action Required |
|----------|----------|-------------|-----------------|
| **1** | Information | Profile attached successfully | None - normal operation |
| **2** | Information | Profile detached successfully | None - normal operation |
| **13** | Warning | Profile disk already in use | User may have active session elsewhere |
| **14** | Error | Failed to attach profile disk | Check storage connectivity, NTFS permissions |
| **15** | Error | Profile disk is locked | Another session has exclusive lock |
| **31** | Error | Storage provider connection failed | Check network, storage account firewall |
| **40** | Error | Profile disk is corrupt | Disk integrity check required |
| **43** | Warning | Profile size approaching limit | Increase quota or clean up profile |
| **50** | Error | Insufficient disk space on storage | Increase Azure Files quota |
| **52** | Error | No profile containers found | Check storage account path, permissions |

#### **PowerShell Query for FSLogix Events:**

```powershell
# Get FSLogix errors in last 24 hours
Get-WinEvent -LogName "FSLogix-Apps/Operational" -MaxEvents 100 |
  Where-Object { $_.LevelDisplayName -eq "Error" } |
  Format-Table TimeCreated, Id, Message -AutoSize -Wrap

# Get specific user's FSLogix events
Get-WinEvent -LogName "FSLogix-Apps/Operational" -MaxEvents 200 |
  Where-Object { $_.Message -like "*john.doe*" } |
  Format-Table TimeCreated, Id, LevelDisplayName, Message -AutoSize -Wrap

# Get profile attach/detach events
Get-WinEvent -LogName "FSLogix-Apps/Operational" -MaxEvents 50 |
  Where-Object { $_.Id -in @(1, 2) } |
  Format-Table TimeCreated, Id, Message -AutoSize
```

### FSLogix File Logs (Detailed Debugging)

**Location on Session Host VM:**
- **Profile Logs:** `C:\ProgramData\FSLogix\Logs\Profile\*.log`
- **ODFC Logs:** `C:\ProgramData\FSLogix\Logs\ODFC\*.log` (if Office Container enabled)

**Log File Naming:**
- `Profile_<SessionID>.log` - Per-session profile operations
- `Profile_<Username>.log` - User-specific aggregated logs

#### **Common Log Patterns:**

**Successful Profile Load:**
```
[INFO] Attempting to mount profile for user: DOMAIN\john.doe
[INFO] VHD location: \\avd-dev-fslogix.file.core.windows.net\user-profiles\john.doe_S-1-5-21-xxx.vhdx
[INFO] Mounted profile container successfully
[INFO] Profile size: 2.3 GB
[INFO] Profile load time: 4.2 seconds
```

**Profile Load Failure (Permissions):**
```
[ERROR] Failed to access VHD location: \\avd-dev-fslogix.file.core.windows.net\user-profiles
[ERROR] Access denied - check NTFS permissions and storage account firewall
[ERROR] User: DOMAIN\john.doe SID: S-1-5-21-xxx
```

**Profile Load Failure (Disk Locked):**
```
[ERROR] VHD file is locked: john.doe_S-1-5-21-xxx.vhdx
[ERROR] Another session has exclusive access to the profile
[WARN] User may be logged in elsewhere or previous session did not detach cleanly
```

#### **View FSLogix File Logs:**

```powershell
# View latest profile log
Get-Content "C:\ProgramData\FSLogix\Logs\Profile\Profile_*.log" -Tail 50

# Search for errors in all profile logs
Get-ChildItem "C:\ProgramData\FSLogix\Logs\Profile\*.log" |
  ForEach-Object { Get-Content $_.FullName | Select-String -Pattern "ERROR" }

# View specific user's log
Get-Content "C:\ProgramData\FSLogix\Logs\Profile\Profile_john.doe.log" -Tail 100

# Monitor logs in real-time (like tail -f)
Get-Content "C:\ProgramData\FSLogix\Logs\Profile\Profile_*.log" -Wait -Tail 20
```

### FSLogix Configuration Check

**Verify FSLogix is configured correctly:**

```powershell
# Check FSLogix registry settings
Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Profiles"

# Should show:
# Enabled: 1
# VHDLocations: \\avd-dev-fslogix.file.core.windows.net\user-profiles
# SizeInMBs: 30000 (30 GB)
# VolumeType: VHDX

# Check FSLogix service status
Get-Service frxsvc, frxdrv, frxccds | Format-Table Name, Status, StartType

# Should all be: Status=Running, StartType=Automatic
```

### Log Analytics Query for FSLogix Issues

If VM Insights and custom log collection are configured:

```kql
// FSLogix profile load failures
Event
| where EventLog == "FSLogix-Apps/Operational"
| where EventLevelName == "Error"
| where EventID in (14, 31, 40, 50, 52)
| project TimeGenerated, Computer, RenderedDescription
| order by TimeGenerated desc
| take 50

// FSLogix profile load times (slow profiles)
Event
| where EventLog == "FSLogix-Apps/Operational"
| where EventID == 1 // Profile attached
| extend LoadTime = extract("time: ([0-9.]+)", 1, RenderedDescription)
| where todouble(LoadTime) > 10.0 // Profiles taking >10 seconds
| project TimeGenerated, Computer, LoadTime, RenderedDescription
```

---

## Verify Backups Are Running

### Azure Backup Verification (Recovery Services Vault)

#### 1. **Azure Portal - Backup Status**

**Location:** Azure Portal → Recovery Services Vault → Backup Items

**Steps:**
1. Navigate to **Recovery Services Vault** (e.g., `avd-dev-rsv`)
2. Click **Backup Items**
3. View backup status by type:
   - **Azure Virtual Machine** - Session hosts and DC
   - **Azure Files** - FSLogix profiles

**What to Check:**
- **Last Backup Status:** Should be "Completed" (green checkmark)
- **Next Backup:** Should show upcoming scheduled time
- **Alerts:** Should be 0 (no failed backups)

#### 2. **Check Backup Jobs**

**Location:** Recovery Services Vault → Backup Jobs

```kql
// View backup jobs in last 7 days
AzureDiagnostics
| where Category == "AzureBackupReport"
| where OperationName == "Job"
| where TimeGenerated > ago(7d)
| project TimeGenerated, JobOperation, JobStatus, ResourceType, Resource_s
| order by TimeGenerated desc

// Failed backups only
AzureDiagnostics
| where Category == "AzureBackupReport"
| where JobStatus == "Failed"
| where TimeGenerated > ago(7d)
| project TimeGenerated, Resource_s, JobFailureCode, JobFailureReason
```

#### 3. **Verify Backup Policy**

**Azure Portal:**
1. Recovery Services Vault → **Backup policies**
2. Select policy (e.g., `avd-dev-vm-backup-policy`)
3. Verify:
   - **Schedule:** Daily at 02:00 (or your configured time)
   - **Retention:** 7 days (or your configured retention)
   - **Status:** Active

**Azure CLI:**

```bash
# List backup policies
az backup policy list \
  --resource-group avd-dev-rg \
  --vault-name avd-dev-rsv \
  --output table

# Get specific policy details
az backup policy show \
  --resource-group avd-dev-rg \
  --vault-name avd-dev-rsv \
  --name avd-dev-vm-backup-policy \
  --query '{Name:name, ScheduleType:schedulePolicy.scheduleRunFrequency, RetentionDays:retentionPolicy.dailySchedule.retentionDuration.count}'
```

#### 4. **Test Restore (Recommended Monthly)**

**Restore a Test VM to Verify Backups Work:**

```bash
# List recovery points for a VM
az backup recoverypoint list \
  --resource-group avd-dev-rg \
  --vault-name avd-dev-rsv \
  --container-name <vm-name> \
  --item-name <vm-name> \
  --backup-management-type AzureIaasVM \
  --output table

# Restore VM to new location (test restore)
az backup restore restore-disks \
  --resource-group avd-dev-rg \
  --vault-name avd-dev-rsv \
  --container-name <vm-name> \
  --item-name <vm-name> \
  --rp-name <recovery-point-name> \
  --storage-account avddevteststorage \
  --target-resource-group avd-dev-test-rg
```

#### 5. **PowerShell Verification**

```powershell
# Connect to Azure
Connect-AzAccount

# Get Recovery Services Vault
$vault = Get-AzRecoveryServicesVault -Name "avd-dev-rsv" -ResourceGroupName "avd-dev-rg"

# Get backup items
$backupItems = Get-AzRecoveryServicesBackupItem `
  -BackupManagementType AzureVM `
  -WorkloadType AzureVM `
  -VaultId $vault.ID

# Display backup status
$backupItems | Format-Table FriendlyName, LastBackupStatus, LastBackupTime, ProtectionState

# Get backup jobs in last 7 days
Get-AzRecoveryServicesBackupJob `
  -VaultId $vault.ID `
  -From (Get-Date).AddDays(-7) `
  -To (Get-Date) |
  Format-Table JobId, Operation, Status, StartTime, EndTime, WorkloadName
```

### FSLogix Profile Backup Verification (Azure Files Snapshots)

#### 1. **Azure Portal - File Share Snapshots**

**Location:** Storage Account → File Shares → user-profiles → Snapshots

**Steps:**
1. Navigate to **Storage Account** (e.g., `avddevfslogix`)
2. Click **File shares** → **user-profiles**
3. Click **Snapshots** tab
4. Verify:
   - Snapshots exist with expected schedule (daily recommended)
   - Snapshot sizes are reasonable (should match profile storage usage)

#### 2. **Azure CLI - List Snapshots**

```bash
# List snapshots for FSLogix file share
az storage share snapshot list \
  --name user-profiles \
  --account-name avddevfslogix \
  --output table

# Get snapshot details
az storage share show \
  --name user-profiles \
  --snapshot <snapshot-time> \
  --account-name avddevfslogix \
  --query '{Name:name, Quota:properties.quota, SnapshotTime:snapshot}'
```

#### 3. **PowerShell - Snapshot Management**

```powershell
# Connect to storage account
$context = New-AzStorageContext -StorageAccountName "avddevfslogix" -UseConnectedAccount

# List snapshots
Get-AzStorageShare -Context $context -Name "user-profiles" -SnapshotTime * |
  Format-Table Name, SnapshotTime, LastModified, QuotaGiB

# Create manual snapshot (for testing)
$share = Get-AzStorageShare -Context $context -Name "user-profiles"
$snapshot = $share.CloudFileShare.Snapshot()
Write-Host "Created snapshot: $($snapshot.SnapshotTime)"
```

---

## Restore Deleted FSLogix Profile

### Scenario 1: Restore from Azure Files Snapshot (Recommended)

**When to Use:** Profile accidentally deleted within last 30 days (if snapshots enabled).

#### **Azure Portal Restore:**

1. **Navigate to Storage Account:**
   - Azure Portal → Storage Account → File shares → user-profiles

2. **Find Deleted Profile:**
   - Click **Browse** → locate user's VHD folder (e.g., `john.doe_S-1-5-21-xxx`)
   - If folder is deleted, proceed to snapshot restore

3. **Restore from Snapshot:**
   - Click **Snapshots** tab
   - Select snapshot from before deletion
   - Click **Browse** on the snapshot
   - Navigate to user's profile folder
   - Right-click folder → **Restore** → **Overwrite original** or **Restore to different location**

4. **Verify Restore:**
   - User logs out/in to AVD session
   - Profile should load from restored VHD

#### **Azure CLI Restore:**

```bash
# List available snapshots
az storage share snapshot list \
  --name user-profiles \
  --account-name avddevfslogix \
  --output table

# Restore specific file from snapshot
az storage file copy start \
  --source-account-name avddevfslogix \
  --source-share user-profiles \
  --source-path "john.doe_S-1-5-21-xxx/Profile_john.doe.vhdx" \
  --snapshot <snapshot-time> \
  --destination-share user-profiles \
  --destination-path "john.doe_S-1-5-21-xxx/Profile_john.doe.vhdx"
```

#### **PowerShell Restore:**

```powershell
# Connect to storage account
$context = New-AzStorageContext -StorageAccountName "avddevfslogix" -UseConnectedAccount

# Get snapshot from 24 hours ago
$snapshot = Get-AzStorageShare -Context $context -Name "user-profiles" -SnapshotTime * |
  Where-Object { $_.SnapshotTime -lt (Get-Date).AddHours(-24) -and $_.SnapshotTime -gt (Get-Date).AddDays(-2) } |
  Select-Object -First 1

# Restore user's profile folder
$sourceFile = Get-AzStorageFile -Share $snapshot -Path "john.doe_S-1-5-21-xxx/Profile_john.doe.vhdx"
Start-AzStorageFileCopy `
  -SrcFile $sourceFile `
  -DestShareName "user-profiles" `
  -DestContext $context `
  -DestFilePath "john.doe_S-1-5-21-xxx/Profile_john.doe.vhdx" `
  -Force

# Wait for copy to complete
Get-AzStorageFileCopyState `
  -Context $context `
  -ShareName "user-profiles" `
  -FilePath "john.doe_S-1-5-21-xxx/Profile_john.doe.vhdx" |
  Format-Table Status, BytesCopied, TotalBytes
```

### Scenario 2: Restore from Azure Backup (Recovery Services Vault)

**When to Use:** Azure Files backup enabled, need to restore from longer retention period.

#### **Steps:**

1. **Navigate to Recovery Services Vault:**
   - Azure Portal → Recovery Services Vault → Backup Items → Azure Files

2. **Select Storage Account:**
   - Click storage account containing FSLogix profiles
   - Click file share: **user-profiles**

3. **Restore File/Folder:**
   - Click **Restore** at the top
   - Choose **File Recovery** (not full share restore)
   - Select **Recovery Point** (date/time of backup)
   - Choose **Original Location** or **Alternate Location**
   - Browse to user's profile folder
   - Click **Restore**

4. **Monitor Restore Job:**
   - Recovery Services Vault → Backup Jobs
   - Wait for status: **Completed**

### Scenario 3: Create New Profile (Last Resort)

**When to Use:** No backups available, profile is corrupt beyond repair.

#### **Steps:**

1. **Delete Corrupt Profile:**
   ```powershell
   # Connect to storage account
   $context = New-AzStorageContext -StorageAccountName "avddevfslogix" -UseConnectedAccount
   
   # Delete user's profile folder
   Remove-AzStorageDirectory `
     -ShareName "user-profiles" `
     -Path "john.doe_S-1-5-21-xxx" `
     -Context $context `
     -Force
   ```

2. **Clear Local Profile (on session host):**
   ```powershell
   # Delete local Windows profile
   Remove-CimInstance -Query "SELECT * FROM Win32_UserProfile WHERE LocalPath='C:\\Users\\john.doe'"
   ```

3. **User Logs In:**
   - FSLogix creates new profile VHD
   - User starts with fresh profile
   - ** All previous data lost!**

### Profile Restore Best Practices

 **DO:**
- Take snapshots before major changes (Windows updates, app deployments)
- Test restore process monthly
- Document profile restore procedures
- Notify user before/after restore
- Verify profile loads successfully after restore

 **DON'T:**
- Restore while user is logged in (will fail due to lock)
- Overwrite existing profile without backup
- Restore to wrong user SID folder
- Skip verification step

---

## Common Alerts to Create

### Azure Monitor Alerts (Recommended)

#### 1. **Session Host CPU Alert (Performance)**

**Alert:** Session host CPU >80% for 15 minutes

```bash
# Azure CLI
az monitor metrics alert create \
  --name "AVD Session Host High CPU" \
  --resource-group avd-dev-rg \
  --scopes "/subscriptions/{sub-id}/resourceGroups/avd-dev-rg/providers/Microsoft.Compute/virtualMachines/dev-avd-sh-0" \
  --condition "avg Percentage CPU > 80" \
  --window-size 15m \
  --evaluation-frequency 5m \
  --severity 2 \
  --description "Session host CPU usage exceeds 80% - consider scaling up or adding session hosts"
```

**Log Analytics Query Alert:**

```kql
Perf
| where CounterName == "% Processor Time"
| where InstanceName == "_Total"
| where Computer startswith "dev-avd-sh"
| summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| where AvgCPU > 80
```

#### 2. **Session Host Memory Alert**

**Alert:** Session host memory >85% for 10 minutes

```kql
Perf
| where CounterName == "% Committed Bytes In Use"
| where Computer startswith "dev-avd-sh"
| summarize AvgMemory = avg(CounterValue) by Computer, bin(TimeGenerated, 5m)
| where AvgMemory > 85
```

#### 3. **Azure Files Disk Latency Alert (Critical for FSLogix)**

**Alert:** Storage latency >100ms for 10 minutes

```bash
az monitor metrics alert create \
  --name "FSLogix Storage High Latency" \
  --resource-group avd-dev-rg \
  --scopes "/subscriptions/{sub-id}/resourceGroups/avd-dev-rg/providers/Microsoft.Storage/storageAccounts/avddevfslogix" \
  --condition "avg SuccessE2ELatency > 100" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --severity 1 \
  --description "FSLogix storage latency exceeds 100ms - profile load times will be slow"
```

**Log Analytics Query:**

```kql
AzureMetrics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where MetricName == "SuccessE2ELatency"
| summarize AvgLatency = avg(Average) by Resource, bin(TimeGenerated, 5m)
| where AvgLatency > 100
```

#### 4. **FSLogix Profile Load Failure Alert**

**Alert:** FSLogix Event ID 14 (profile attach failure)

```kql
Event
| where EventLog == "FSLogix-Apps/Operational"
| where EventID == 14 // Profile attach failed
| where TimeGenerated > ago(15m)
| summarize Count = count() by Computer, bin(TimeGenerated, 5m)
| where Count > 0
```

**Action Group:** Email to `avd-admins@company.com`, Teams webhook

#### 5. **AVD Connection Failure Alert**

**Alert:** >5 failed connections in 10 minutes

```kql
WVDConnections
| where TimeGenerated > ago(10m)
| where State == "Failed"
| summarize FailedConnections = count() by bin(TimeGenerated, 10m)
| where FailedConnections > 5
```

#### 6. **Session Host Offline Alert**

**Alert:** Session host agent not reporting for >10 minutes

```kql
WVDAgentHealthStatus
| where TimeGenerated > ago(15m)
| where Status != "Available"
| summarize arg_max(TimeGenerated, *) by SessionHostName
| where TimeGenerated < ago(10m)
```

#### 7. **Backup Failure Alert**

**Alert:** Backup job failed

```kql
AzureDiagnostics
| where Category == "AzureBackupReport"
| where JobStatus == "Failed"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Resource_s, JobOperation, JobFailureReason
```

#### 8. **Storage Account Capacity Alert**

**Alert:** FSLogix storage >80% capacity

```bash
az monitor metrics alert create \
  --name "FSLogix Storage Capacity Warning" \
  --resource-group avd-dev-rg \
  --scopes "/subscriptions/{sub-id}/resourceGroups/avd-dev-rg/providers/Microsoft.Storage/storageAccounts/avddevfslogix" \
  --condition "avg UsedCapacity > 85899345920" \
  --window-size 1h \
  --evaluation-frequency 15m \
  --severity 2 \
  --description "FSLogix storage capacity exceeds 80GB of 100GB quota"
```

#### 9. **Domain Controller Offline Alert**

**Alert:** DC heartbeat missing for >5 minutes

```kql
Heartbeat
| where Computer contains "dc"
| summarize LastHeartbeat = max(TimeGenerated) by Computer
| where LastHeartbeat < ago(5m)
```

#### 10. **User Session Capacity Alert**

**Alert:** Session host at max capacity

```kql
WVDAgentHealthStatus
| where TimeGenerated > ago(5m)
| extend SessionCount = toint(SessionCount)
| extend MaxSessions = toint(MaxSessionLimit)
| where SessionCount >= MaxSessions
| project TimeGenerated, SessionHostName, SessionCount, MaxSessions
```

### Create Alert Action Group

**Action Group** (email, SMS, Teams, Logic App):

```bash
# Create action group for AVD alerts
az monitor action-group create \
  --name "AVD-Critical-Alerts" \
  --resource-group avd-dev-rg \
  --short-name "AVDAlerts" \
  --email-receiver name="AVD Admins" email="avd-admins@company.com" \
  --email-receiver name="On-Call" email="oncall@company.com"
```

### Alert Best Practices

 **DO:**
- Set different severity levels (Critical, Warning, Informational)
- Use multiple thresholds (e.g., CPU >70% warning, >85% critical)
- Include actionable descriptions
- Test alerts before production
- Route critical alerts to on-call rotation
- Review and tune alert thresholds monthly

 **DON'T:**
- Set thresholds too low (alert fatigue)
- Send all alerts to everyone
- Ignore repeated alerts
- Forget to update action groups when team changes

---

## Performance Troubleshooting

### Session Host Performance Issues

#### **High CPU Usage**

**Symptoms:**
- Slow application response
- Desktop freezing
- User complaints of lag

**Diagnosis:**

```powershell
# On session host VM
Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet

# Check per-user CPU usage
query user
Get-Counter "\Processor(*)\% Processor Time" -SampleInterval 5 -MaxSamples 12
```

**Common Causes:**
- Antivirus scans during business hours
- Windows Update downloads
- Runaway application process
- Too many concurrent users

**Solutions:**
- Scale up VM size (e.g., D4s_v5 → D8s_v5)
- Add more session hosts
- Configure antivirus exclusions
- Lower `maximum_sessions_allowed`

#### **High Memory Usage**

**Diagnosis:**

```powershell
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10 Name, WorkingSet, PrivateMemorySize
Get-Counter "\Memory\Available MBytes"
```

**Solutions:**
- Close unused applications
- Scale up to VM with more RAM
- Investigate memory leaks (Process Explorer)

#### **Slow Logon Times**

**Target:** <30 seconds from credential entry to desktop

**Diagnosis:**

```powershell
# Check GPO processing time
gpresult /h c:\temp\gpresult.html
# Open in browser, check "Component Status" section

# Check FSLogix profile load time (in FSLogix logs)
Select-String -Path "C:\ProgramData\FSLogix\Logs\Profile\*.log" -Pattern "Profile load time"
```

**Common Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Slow GPO processing | Reduce number of GPOs, optimize GPO filters |
| FSLogix profile load >10s | Check storage latency, consider Premium Files |
| Large roaming profile | Enable FSLogix folder redirections |
| Network latency to DC | Place DC in same region as session hosts |
| Too many logon scripts | Consolidate or eliminate unnecessary scripts |

### Storage Performance Issues

#### **High Storage Latency**

**Diagnosis:**

```bash
# Check Azure Files metrics
az monitor metrics list \
  --resource /subscriptions/{sub-id}/resourceGroups/avd-dev-rg/providers/Microsoft.Storage/storageAccounts/avddevfslogix \
  --metric SuccessE2ELatency \
  --aggregation Average \
  --interval PT5M
```

**Thresholds:**
- **Good:** <20ms
- **Acceptable:** 20-50ms
- **Slow:** 50-100ms
- **Critical:** >100ms

**Solutions:**
- Upgrade to Premium Files (from Standard)
- Increase provisioned IOPS (Premium Files)
- Enable SMB Multichannel
- Check network path (ExpressRoute vs. Internet)

---

## Session Host Health Checks

### Daily Health Check Script

```powershell
# AVD Session Host Health Check
# Run on each session host

Write-Host "=== AVD Session Host Health Check ===" -ForegroundColor Cyan

# 1. Check Windows services
$services = @('frxsvc', 'frxdrv', 'TermService', 'RdAgent')
foreach ($svc in $services) {
    $status = Get-Service $svc -ErrorAction SilentlyContinue
    if ($status.Status -eq 'Running') {
        Write-Host "✓ Service $svc is running" -ForegroundColor Green
    } else {
        Write-Host "✗ Service $svc is not running!" -ForegroundColor Red
    }
}

# 2. Check disk space
$disk = Get-PSDrive C
$freePercent = [math]::Round(($disk.Free / $disk.Used) * 100, 2)
if ($freePercent -gt 20) {
    Write-Host "✓ Disk space OK: $freePercent% free" -ForegroundColor Green
} else {
    Write-Host "✗ Low disk space: $freePercent% free" -ForegroundColor Red
}

# 3. Check domain connectivity
$domain = (Get-WmiObject Win32_ComputerSystem).Domain
$dcPing = Test-Connection -ComputerName $domain -Count 1 -Quiet
if ($dcPing) {
    Write-Host "✓ Domain connectivity OK: $domain" -ForegroundColor Green
} else {
    Write-Host "✗ Cannot reach domain: $domain" -ForegroundColor Red
}

# 4. Check FSLogix storage
$fslogixPath = (Get-ItemProperty "HKLM:\SOFTWARE\FSLogix\Profiles").VHDLocations
$testPath = Test-Path $fslogixPath
if ($testPath) {
    Write-Host "✓ FSLogix storage accessible: $fslogixPath" -ForegroundColor Green
} else {
    Write-Host "✗ FSLogix storage NOT accessible: $fslogixPath" -ForegroundColor Red
}

# 5. Check AVD agent status
$agentRegistry = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -ErrorAction SilentlyContinue
if ($agentRegistry) {
    Write-Host "✓ AVD Agent installed" -ForegroundColor Green
} else {
    Write-Host "✗ AVD Agent not found!" -ForegroundColor Red
}

# 6. Check current user sessions
$sessions = query user 2>$null
Write-Host "`nActive Sessions:" -ForegroundColor Cyan
$sessions

Write-Host "`n=== Health Check Complete ===" -ForegroundColor Cyan
```

---

## Domain Controller Operations

### Check AD DS Health

```powershell
# On Domain Controller

# Check FSMO roles
netdom query fsmo

# Check replication status
repadmin /replsummary
repadmin /showrepl

# Check DNS
dcdiag /test:dns

# Check sysvol replication
dfsrdiag pollad

# List domain controllers
nltest /dclist:avd.local

# Verify domain trusts
nltest /domain_trusts
```

### Common DC Issues

| Symptom | Diagnosis | Solution |
|---------|-----------|----------|
| Domain join failures | `nltest /dsgetdc:avd.local` | Check firewall, DNS resolution |
| GPO not applying | `gpupdate /force` on session host | Check replication, SYSVOL access |
| DNS not resolving | `nslookup avd.local` | Restart DNS service, check forwarders |
| DC not responsive | Check Event Viewer: System log | Restart VM, check resource utilization |

---

## Storage Account Operations

### Check Azure Files Health

```bash
# Check storage account status
az storage account show \
  --name avddevfslogix \
  --resource-group avd-dev-rg \
  --query '{Name:name, ProvisioningState:provisioningState, StatusOfPrimary:statusOfPrimary}'

# Check file share quota
az storage share show \
  --name user-profiles \
  --account-name avddevfslogix \
  --query '{Name:name, Quota:properties.quota, Usage:properties.shareUsageBytes}'

# Check storage metrics (last hour)
az monitor metrics list \
  --resource /subscriptions/{sub-id}/resourceGroups/avd-dev-rg/providers/Microsoft.Storage/storageAccounts/avddevfslogix \
  --metric Transactions \
  --aggregation Total \
  --interval PT1H
```

### Storage Troubleshooting

**Cannot Access File Share:**

1. Check storage account firewall:
   ```bash
   az storage account show \
     --name avddevfslogix \
     --query networkRuleSet
   ```

2. Verify network connectivity from session host:
   ```powershell
   Test-NetConnection -ComputerName avddevfslogix.file.core.windows.net -Port 445
   ```

3. Check SMB version (SMB 3.0+ required):
   ```powershell
   Get-SmbConnection | Format-Table ServerName, ShareName, Dialect
   ```

---

## Quick Reference Commands

### Session Host Commands

```powershell
# List active users
query user

# Log off user session
logoff <session-id>

# Restart AVD agent
Restart-Service RdAgent

# Restart FSLogix service
Restart-Service frxsvc

# Clear local profile cache
Remove-Item "C:\Users\*" -Recurse -Force -Exclude Public, Default*

# Check AVD registration
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\RDInfraAgent"
```

### Azure CLI Commands

```bash
# List session hosts
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --output table

# Get session host status
az desktopvirtualization sessionhost show \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name <session-host-name>

# Drain session host (prevent new connections)
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name <session-host-name> \
  --allow-new-session false
```

### Log Analytics Queries

```kql
// Session host performance snapshot
Perf
| where TimeGenerated > ago(1h)
| where Computer startswith "dev-avd-sh"
| where CounterName in ("% Processor Time", "% Committed Bytes In Use", "Disk Reads/sec")
| summarize avg(CounterValue) by Computer, CounterName
| order by Computer, CounterName

// User connection timeline
WVDConnections
| where TimeGenerated > ago(24h)
| project TimeGenerated, UserName, State, SessionHostName
| order by TimeGenerated desc

// FSLogix errors today
Event
| where TimeGenerated > startofday(now())
| where EventLog == "FSLogix-Apps/Operational"
| where EventLevelName == "Error"
| project TimeGenerated, Computer, RenderedDescription
| order by TimeGenerated desc
```

---

## Additional Resources

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [FSLogix Documentation](https://docs.microsoft.com/fslogix/)
- [Azure Backup Documentation](https://docs.microsoft.com/azure/backup/)
- [Azure Monitor Alerts](https://docs.microsoft.com/azure/azure-monitor/alerts/)

---

## Need Help?

1. Check **Event Viewer** on session hosts (System, Application, FSLogix logs)
2. Query **Log Analytics** for historical data and patterns
3. Review **Azure Portal** for service health and resource status
4. Check this guide's troubleshooting sections
5. Contact Azure Support with specific error codes and logs

**Quick Diagnostics Checklist:**
- [ ] Session hosts are running and registered to host pool
- [ ] Domain Controller is online and reachable
- [ ] FSLogix storage account is accessible
- [ ] DNS is resolving correctly (VNet points to DC)
- [ ] Backups completed in last 24 hours
- [ ] No critical alerts in Azure Monitor
- [ ] Log Analytics receiving data from all VMs
