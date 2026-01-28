# FSLogix Storage Module

Comprehensive Azure Files storage module for FSLogix user profiles in Azure Virtual Desktop environments. Includes secure defaults, optional private endpoint, AD DS authentication support, and comprehensive monitoring.

## Features

- **Azure Storage Account** - Premium or Standard tier with secure defaults
- **User Profiles File Share** - Named "user-profiles" for FSLogix
- **Private Endpoint** - Optional private connectivity for enhanced security
- **AD DS Authentication** - Full support with documented setup process
- **RBAC Integration** - Automatic role assignments for session hosts and user groups
- **Diagnostics** - Log Analytics integration for monitoring
- **Secure Defaults** - TLS 1.2, HTTPS only, no public blob access

## Architecture

| Layer | Component | Configuration |
|-------|-----------|---------------|
| **Storage Account** | Premium FileStorage | - TLS 1.2 minimum<br>- HTTPS only<br>- Network: Private Endpoint or Service Endpoint<br>- Authentication: AD DS integrated |
| **Azure Files Share** | Share name: "user-profiles" | - SMB 3.1.1 protocol<br>- Size: 100-102400 GB<br>- Access: AD DS authenticated + RBAC |
| **FSLogix Profile Containers** | User profile VHD files | - Format: `%username%_S-1-5-21-xxx.vhdx`<br>- Dynamic VHD expansion<br>- User-specific access via AD permissions<br>- Mounted via UNC path |

## Usage

### Basic Example (Premium Storage with Private Endpoint)

```hcl
module "fslogix_storage" {
  source = "../../modules/fslogix_storage"

  # Core Configuration
  storage_account_name = "avdfslogixprod01"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = "eastus"
  environment          = "prod"

  # Storage Configuration
  storage_account_tier    = "Premium"
  storage_replication_type = "LRS"
  storage_account_kind    = "FileStorage"
  file_share_quota_gb     = 1024  # 1TB

  # Private Endpoint (Recommended)
  enable_private_endpoint      = true
  private_endpoint_subnet_id   = module.networking.storage_subnet_id
  private_dns_zone_id          = azurerm_private_dns_zone.file.id

  # AD DS Authentication (requires manual setup - see below)
  enable_ad_authentication = true
  ad_domain_name          = "contoso.local"
  ad_netbios_domain_name  = "CONTOSO"
  ad_forest_name          = "contoso.local"

  # RBAC - Grant access to AVD users
  avd_users_group_id = data.azuread_group.avd_users.object_id

  # Diagnostics
  enable_diagnostics           = true
  log_analytics_workspace_id   = azurerm_log_analytics_workspace.avd.id

  tags = {
    Environment = "Production"
    Purpose     = "FSLogix User Profiles"
    ManagedBy   = "Terraform"
  }
}

# Use the UNC path in session hosts
output "fslogix_share_path" {
  value = module.fslogix_storage.unc_path
}
```

### Standard Storage Example (Lower Cost)

```hcl
module "fslogix_storage" {
  source = "../../modules/fslogix_storage"

  storage_account_name     = "avdfslogixdev01"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = "eastus"
  environment              = "dev"

  # Standard tier - lower cost, good performance
  storage_account_tier     = "Standard"
  storage_replication_type = "LRS"
  storage_account_kind     = "StorageV2"
  file_share_quota_gb      = 100
  file_share_access_tier   = "TransactionOptimized"

  # Public access with service endpoint
  enable_private_endpoint = false
  allowed_subnet_ids      = [module.networking.avd_subnet_id]

  # AD Authentication
  enable_ad_authentication = true
  ad_domain_name          = "contoso.local"
  ad_netbios_domain_name  = "CONTOSO"
  ad_forest_name          = "contoso.local"

  # RBAC
  avd_users_group_id = data.azuread_group.avd_users.object_id

  tags = {
    Environment = "Development"
    Purpose     = "FSLogix User Profiles"
  }
}
```

### With Session Host Managed Identities

```hcl
# Create managed identities for session hosts
resource "azurerm_user_assigned_identity" "session_hosts" {
  count               = 3
  name                = "avd-session-host-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus"
}

module "fslogix_storage" {
  source = "../../modules/fslogix_storage"
  # ... other configuration

  # Grant session host identities access
  session_host_principal_ids = azurerm_user_assigned_identity.session_hosts[*].principal_id
  
  # Also grant AVD users group access
  avd_users_group_id = data.azuread_group.avd_users.object_id
}
```

## Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `storage_account_name` | Storage account name (3-24 lowercase alphanumeric) | `string` |
| `resource_group_name` | Resource group name | `string` |
| `location` | Azure region | `string` |

### Storage Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `storage_account_tier` | Standard or Premium | `string` | `"Premium"` |
| `storage_replication_type` | LRS, ZRS, GRS, GZRS | `string` | `"LRS"` |
| `storage_account_kind` | FileStorage or StorageV2 | `string` | `"FileStorage"` |
| `file_share_quota_gb` | File share size (1-102400 GB) | `number` | `100` |
| `file_share_access_tier` | Premium, Hot, Cool, TransactionOptimized | `string` | `"Premium"` |
| `enable_shared_access_key` | Enable storage account key access | `bool` | `true` |

### Network Security

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_private_endpoint` | Enable private endpoint | `bool` | `true` |
| `private_endpoint_subnet_id` | Subnet ID for private endpoint | `string` | `""` |
| `private_dns_zone_id` | Private DNS zone ID | `string` | `""` |
| `allowed_subnet_ids` | Allowed subnet IDs (public access) | `list(string)` | `[]` |
| `allowed_ip_addresses` | Allowed IP addresses/CIDR | `list(string)` | `[]` |

### AD DS Authentication

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_ad_authentication` | Enable AD DS authentication | `bool` | `false` |
| `ad_domain_name` | AD domain FQDN | `string` | `""` |
| `ad_domain_guid` | AD domain GUID | `string` | `""` |
| `ad_domain_sid` | AD domain SID | `string` | `""` |
| `ad_forest_name` | AD forest name | `string` | `""` |
| `ad_netbios_domain_name` | AD NetBIOS name | `string` | `""` |

### RBAC

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `session_host_principal_ids` | Session host identity principal IDs | `list(string)` | `[]` |
| `avd_users_group_id` | AVD users group object ID | `string` | `""` |
| `additional_contributor_principal_ids` | Additional principal IDs for access | `list(string)` | `[]` |

### Diagnostics

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `enable_diagnostics` | Enable Log Analytics diagnostics | `bool` | `true` |
| `log_analytics_workspace_id` | Log Analytics workspace ID | `string` | `""` |

## Outputs

| Name | Description |
|------|-------------|
| `storage_account_id` | Storage account resource ID |
| `storage_account_name` | Storage account name |
| `file_share_id` | File share resource ID |
| `file_share_name` | File share name (user-profiles) |
| `unc_path` | UNC path for FSLogix configuration |
| `fslogix_vhd_locations_registry_value` | Value for FSLogix registry |
| `connection_info` | Connection details object |
| `private_endpoint_ip` | Private endpoint IP (if enabled) |
| `ad_auth_setup_commands` | PowerShell commands for AD DS setup |
| `test_mount_command` | PowerShell command to test mount |
| `fslogix_registry_settings` | FSLogix registry settings |

## AD DS Authentication Setup

Azure Files supports native AD DS authentication, allowing users to access file shares using their domain credentials. This is **required** for FSLogix to work properly with NTFS permissions.

### Prerequisites

1. **Domain Controller** running and accessible from Azure
2. **Domain-joined machine** with Azure PowerShell installed
3. **Azure permissions** to modify storage account
4. **AD permissions** to create computer accounts

### Setup Process

#### Step 1: Install AzFilesHybrid PowerShell Module

Run from a domain-joined machine with Azure PowerShell:

```powershell
# Install the module
Install-Module -Name AzFilesHybrid -Force -AllowClobber

# Import the module
Import-Module AzFilesHybrid

# Verify installation
Get-Command -Module AzFilesHybrid
```

#### Step 2: Connect to Azure

```powershell
# Connect to Azure
Connect-AzAccount

# Select the correct subscription
Select-AzSubscription -SubscriptionId "<your-subscription-id>"

# Verify context
Get-AzContext
```

#### Step 3: Join Storage Account to AD Domain

```powershell
# Join storage account to AD DS domain
Join-AzStorageAccountForAuth `
  -ResourceGroupName "rg-avd-prod" `
  -StorageAccountName "avdfslogixprod01" `
  -DomainAccountType "ComputerAccount" `
  -OrganizationalUnitDistinguishedName "OU=AzureStorage,DC=contoso,DC=local"
```

**Parameters:**
- `-ResourceGroupName`: Resource group containing the storage account
- `-StorageAccountName`: Name of the storage account
- `-DomainAccountType`: Use "ComputerAccount" (default) or "ServiceLogonAccount"
- `-OrganizationalUnitDistinguishedName`: Optional OU for the computer account

#### Step 4: Verify Domain Join

```powershell
# Check authentication configuration
$storageAccount = Get-AzStorageAccount `
  -ResourceGroupName "rg-avd-prod" `
  -Name "avdfslogixprod01"

# Display Azure Files identity-based auth settings
$storageAccount.AzureFilesIdentityBasedAuth

# Expected output:
# DirectoryServiceOptions : AD
# ActiveDirectoryProperties : Microsoft.Azure.Management.Storage.Models.ActiveDirectoryProperties
```

#### Step 5: Retrieve AD Domain Information (Optional)

If you need to populate Terraform variables with domain information:

```powershell
# Get domain GUID
$domain = Get-ADDomain
$domainGuid = $domain.ObjectGUID.ToString()

# Get domain SID
$domainSid = $domain.DomainSID.Value

# Get domain NetBIOS name
$netbiosName = $domain.NetBIOSName

# Display all values
Write-Host "Domain GUID: $domainGuid"
Write-Host "Domain SID: $domainSid"
Write-Host "NetBIOS Name: $netbiosName"
Write-Host "Domain FQDN: $($domain.DNSRoot)"
Write-Host "Forest Name: $($domain.Forest)"
```

#### Step 6: Configure Share-Level Permissions (RBAC)

This module automatically creates RBAC role assignments, but you can verify:

```powershell
# List role assignments for the storage account
Get-AzRoleAssignment -Scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<storage-name>"

# Manually add role assignment if needed
New-AzRoleAssignment `
  -ObjectId "<group-or-user-object-id>" `
  -RoleDefinitionName "Storage File Data SMB Share Contributor" `
  -Scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<storage-name>"
```

#### Step 7: Configure NTFS Permissions

After domain join and RBAC, configure NTFS permissions for user profile folders:

```powershell
# Mount the file share
$storageAccountName = "avdfslogixprod01"
$fileShareName = "user-profiles"
$connectTestResult = Test-NetConnection -ComputerName "$storageAccountName.file.core.windows.net" -Port 445

if ($connectTestResult.TcpTestSucceeded) {
    # Mount the share
    $acctKey = (Get-AzStorageAccountKey -ResourceGroupName "rg-avd-prod" -Name $storageAccountName)[0].Value
    $securePassword = ConvertTo-SecureString -String $acctKey -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\$storageAccountName", $securePassword
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$storageAccountName.file.core.windows.net\$fileShareName" -Credential $credential -Persist

    # Set NTFS permissions for FSLogix
    # Grant "Creator Owner" full control to user profile folders
    icacls "Z:\" /grant "Creator Owner:(OI)(CI)(IO)F" /T
    
    # Grant "Domain Users" modify access to root (needed to create folders)
    icacls "Z:\" /grant "CONTOSO\Domain Users:(M)"
    
    # Remove inherited permissions from individual user folders (FSLogix will handle this)
    # Note: FSLogix automatically secures each user's profile folder
    
    # Dismount
    Remove-PSDrive -Name Z
} else {
    Write-Error "Cannot reach storage account on port 445"
}
```

### Alternative: Azure CLI Method

```bash
# Install the Azure CLI extension
az extension add --name storage-preview

# Update to latest version
az extension update --name storage-preview

# Enable AD DS authentication
az storage account update \
  --name avdfslogixprod01 \
  --resource-group rg-avd-prod \
  --enable-files-adds true \
  --domain-name "contoso.local" \
  --net-bios-domain-name "CONTOSO" \
  --forest-name "contoso.local" \
  --domain-guid "12345678-1234-1234-1234-123456789012" \
  --domain-sid "S-1-5-21-123456789-123456789-123456789"

# Verify
az storage account show \
  --name avdfslogixprod01 \
  --resource-group rg-avd-prod \
  --query azureFilesIdentityBasedAuthentication
```

## FSLogix Configuration

After setting up the storage account, configure FSLogix on session hosts.

### Registry Settings

Use the output `fslogix_registry_settings` or configure manually:

```powershell
# Enable FSLogix Profile Container
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "Enabled" -Value 1 -PropertyType DWORD -Force

# Set VHD location to Azure Files share
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "VHDLocations" -Value "\\avdfslogixprod01.file.core.windows.net\user-profiles" -PropertyType MultiString -Force

# Set profile size (30GB)
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "SizeInMBs" -Value 30000 -PropertyType DWORD -Force

# Enable dynamic VHD
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "IsDynamic" -Value 1 -PropertyType DWORD -Force

# Use VHDX format
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "VolumeType" -Value "VHDX" -PropertyType String -Force

# Enable flip-flop profile directory naming
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "FlipFlopProfileDirectoryName" -Value 1 -PropertyType DWORD -Force

# Delete local profile when VHD should apply
New-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -PropertyType DWORD -Force
```

### Group Policy (Recommended for Production)

1. **Download FSLogix Group Policy templates:**
   - Download from: https://aka.ms/fslogix_download
   - Extract `fslogix.admx` and `fslogix.adml` to Group Policy Central Store

2. **Create FSLogix GPO:**
   ```
   Computer Configuration > Policies > Administrative Templates > FSLogix > Profile Containers
   ```

3. **Configure settings:**
   - **Enabled**: Set to "Enabled"
   - **VHD Location**: `\\avdfslogixprod01.file.core.windows.net\user-profiles`
   - **VHD Size**: 30000 MB
   - **Dynamic VHD**: Enabled
   - **VHD Type**: VHDX
   - **Profile Type**: Try for read-write, fallback to read-only

4. **Link GPO to AVD OU:**
   ```
   OU=AVD-SessionHosts,DC=contoso,DC=local
   ```

## Storage Tier Comparison

| Feature | Premium (FileStorage) | Standard (StorageV2) |
|---------|----------------------|---------------------|
| **Performance** | High IOPS, low latency | Good for most workloads |
| **Cost** | ~$0.15/GB/month | ~$0.05/GB/month |
| **Use Case** | Production, >50 users | Dev/test, <50 users |
| **Min Size** | 100 GB | 1 GB |
| **Provisioned** | Yes (pay for allocated) | No (pay for used) |
| **Recommended** | Production | Development |

### Cost Examples (US East, per month)

**Premium - 1TB:**
- Storage: 1024 GB × $0.15 = $153.60
- Total: ~$154/month

**Standard - 1TB (500GB used):**
- Storage: 500 GB × $0.05 = $25.00
- Transactions: Variable (~$5-20)
- Total: ~$30-45/month

## Monitoring and Diagnostics

### Log Analytics Queries

```kql
// Storage account operations
StorageFileLogs
| where TimeGenerated > ago(1h)
| where AccountName == "avdfslogixprod01"
| summarize Count=count() by OperationName, StatusCode
| order by Count desc

// Failed operations
StorageFileLogs
| where TimeGenerated > ago(24h)
| where AccountName == "avdfslogixprod01"
| where StatusCode !startswith "2"
| project TimeGenerated, OperationName, StatusCode, StatusText, CallerIpAddress
| order by TimeGenerated desc

// File share capacity
StorageFileLogs
| where TimeGenerated > ago(1h)
| where AccountName == "avdfslogixprod01"
| summarize AvgCapacity=avg(UsedCapacity) by bin(TimeGenerated, 5m)
| render timechart

// Authentication failures
StorageFileLogs
| where TimeGenerated > ago(24h)
| where AccountName == "avdfslogixprod01"
| where StatusCode == "403" or StatusCode == "401"
| project TimeGenerated, CallerIpAddress, Uri, StatusText
| order by TimeGenerated desc
```

### Azure Monitor Alerts

Create alerts for critical scenarios:

```hcl
resource "azurerm_monitor_metric_alert" "storage_capacity" {
  name                = "fslogix-storage-capacity-alert"
  resource_group_name = var.resource_group_name
  scopes              = [module.fslogix_storage.storage_account_id]
  description         = "Alert when storage capacity exceeds 80%"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts/fileServices"
    metric_name      = "FileCapacity"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 858993459200  # 80% of 1TB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.ops.id
  }
}
```

## Troubleshooting

### Cannot Mount File Share

```powershell
# Test network connectivity
Test-NetConnection -ComputerName "avdfslogixprod01.file.core.windows.net" -Port 445

# Check DNS resolution
Resolve-DnsName -Name "avdfslogixprod01.file.core.windows.net"

# Test with storage account key (temporary)
$acctKey = (Get-AzStorageAccountKey -ResourceGroupName "rg-avd-prod" -Name "avdfslogixprod01")[0].Value
$securePassword = ConvertTo-SecureString -String $acctKey -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList "Azure\avdfslogixprod01", $securePassword
New-PSDrive -Name Z -PSProvider FileSystem -Root "\\avdfslogixprod01.file.core.windows.net\user-profiles" -Credential $credential
```

### AD Authentication Not Working

1. **Verify domain join:**
   ```powershell
   Get-AzStorageAccount -ResourceGroupName "rg-avd-prod" -Name "avdfslogixprod01" | Select-Object -ExpandProperty AzureFilesIdentityBasedAuth
   ```

2. **Check AD computer object:**
   ```powershell
   Get-ADComputer -Filter {Name -eq "avdfslogixprod01"}
   ```

3. **Verify RBAC:**
   ```powershell
   Get-AzRoleAssignment -Scope "/subscriptions/<sub-id>/resourceGroups/rg-avd-prod/providers/Microsoft.Storage/storageAccounts/avdfslogixprod01"
   ```

4. **Test Kerberos authentication:**
   ```cmd
   klist get cifs/avdfslogixprod01.file.core.windows.net
   ```

### FSLogix Profile Not Loading

1. **Check FSLogix logs:**
   ```
   C:\ProgramData\FSLogix\Logs\Profile\*.log
   ```

2. **Verify registry settings:**
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles"
   ```

3. **Test VHD location access:**
   ```powershell
   Test-Path "\\avdfslogixprod01.file.core.windows.net\user-profiles"
   ```

4. **Check NTFS permissions:**
   ```powershell
   icacls "\\avdfslogixprod01.file.core.windows.net\user-profiles"
   ```

## Security Best Practices

1. **Use Private Endpoints** - Eliminate public internet exposure
2. **Enable AD DS Authentication** - Required for proper NTFS permissions
3. **Implement RBAC** - Least privilege access via Azure role assignments
4. **Disable Storage Account Keys** - After AD DS auth is working (set `enable_shared_access_key = false`)
5. **Enable Diagnostics** - Monitor all access and operations
6. **Use Premium Tier** - For production workloads with >20 users
7. **Regular Backups** - Use Azure Backup for file shares
8. **Network Isolation** - Use service endpoints or private endpoints

## Performance Optimization

### For Premium Storage:
- Provision adequate IOPS (100 IOPS per GB)
- Monitor performance metrics
- Consider Premium ZRS for high availability

### For Standard Storage:
- Use TransactionOptimized tier
- Enable large file shares (up to 100TB)
- Monitor throttling metrics

### FSLogix Optimization:
- Enable dynamic VHD for space efficiency
- Use VHDX format (supports >2TB)
- Exclude OneDrive cache from profile
- Configure profile size limits

## License

Part of the Azure Virtual Desktop Terraform Playbook.
