# Azure Image Builder Module - Golden Image for AVD

## Overview

This module automates the creation of custom Windows golden images for Azure Virtual Desktop using **Azure Image Builder (AIB)**. It eliminates manual image preparation and provides a consistent, repeatable image build process.

**What is a Golden Image?**
A golden image is a pre-configured, hardened, and optimized Windows image that serves as the template for all AVD session hosts. Instead of deploying from marketplace images and configuring each VM individually, you:
1. Build a golden image once with all applications, updates, and configurations
2. Deploy session hosts from the golden image (ready in 5-10 minutes vs. 30-60 minutes)
3. Rebuild the golden image monthly with latest updates and app versions

**Key Features:**
- **Azure Image Builder** - Automated, repeatable image builds
- **Azure Compute Gallery** - Versioned image storage and distribution
-**Extensible Customizations** - Scripts, packages, Windows updates
- **Multi-Region Replication** - Fast deployments worldwide
- **Infrastructure as Code** - Version-controlled image definitions
- **Cost Effective** - ~$1-3 per build, ~$5-15/month storage

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Module Architecture](#module-architecture)
3. [Base Image Options](#base-image-options)
4. [Customization Options](#customization-options)
5. [How to Trigger a New Build](#how-to-trigger-a-new-build)
6. [Monitor Build Status](#monitor-build-status)
7. [Roll Out Golden Image to Session Hosts](#roll-out-golden-image-to-session-hosts)
8. [Rollback Strategy](#rollback-strategy)
9. [Versioning Strategy](#versioning-strategy)
10. [Cost Estimation](#cost-estimation)
11. [Troubleshooting](#troubleshooting)
12. [Best Practices](#best-practices)
13. [Advanced Scenarios](#advanced-scenarios)

---

## Variables

### Required Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name for gallery and Image Builder | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `gallery_name` | Azure Compute Gallery name | `string` | - | Yes |
| `image_definition_name` | Image definition name within gallery | `string` | - | Yes |
| `image_template_name` | Azure Image Builder template name | `string` | - | Yes |

### Base Image Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `image_version` | Semantic version (e.g., 1.0.0) | `string` | `"1.0.0"` | No |
| `base_image_publisher` | Marketplace image publisher | `string` | `"MicrosoftWindowsDesktop"` | No |
| `base_image_offer` | Marketplace image offer | `string` | `"office-365"` | No |
| `base_image_sku` | Marketplace image SKU | `string` | `"win11-22h2-avd-m365"` | No |
| `base_image_version` | Marketplace image version | `string` | `"latest"` | No |
| `hyper_v_generation` | Hyper-V generation: V1 or V2 | `string` | `"V2"` | No |

### Image Definition Properties

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `image_publisher` | Custom image publisher name | `string` | `"MyCompany"` | No |
| `image_offer` | Custom image offer name | `string` | `"AVD-GoldenImage"` | No |
| `image_sku` | Custom image SKU name | `string` | `"Win11-M365-Custom"` | No |

### Customization Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `install_windows_updates` | Install latest Windows updates during build | `bool` | `true` | No |
| `powershell_modules` | PowerShell modules to install | `list(string)` | `[]` | No |
| `inline_scripts` | Inline PowerShell scripts | `map(list(string))` | `{}` | No |
| `script_uris` | Script URIs to execute | `map(string)` | `{}` | No |
| `chocolatey_packages` | Chocolatey packages to install | `list(string)` | `[]` | No |
| `restart_after_customization` | Restart after applying customizations | `bool` | `false` | No |
| `run_cleanup_script` | Run cleanup script to reduce image size | `bool` | `true` | No |

### Replication & Advanced Settings

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `replication_regions` | Additional regions for replication | `list(string)` | `[]` | No |
| `replica_count` | Replicas per region (1-10) | `number` | `1` | No |
| `storage_account_type` | Storage type for replicas | `string` | `"Standard_LRS"` | No |
| `exclude_from_latest` | Exclude from 'latest' queries | `bool` | `false` | No |
| `build_timeout_minutes` | Image build timeout | `number` | `240` | No |
| `vm_size` | Build VM size | `string` | `"Standard_D2s_v3"` | No |
| `os_disk_size_gb` | Build VM OS disk size | `number` | `127` | No |
| `tags` | Resource tags | `map(string)` | `{}` | No |

## Quick Start

### Minimal Configuration

```hcl
module "golden_image" {
  source = "../../modules/golden_image"

  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  
  gallery_name          = "avd_golden_images"
  image_definition_name = "avd-win11-m365"
  image_template_name   = "avd-golden-image-template"
  image_version         = "1.0.0"
  
  # Base image: Windows 11 multi-session + Microsoft 365 Apps
  base_image_publisher  = "MicrosoftWindowsDesktop"
  base_image_offer      = "office-365"
  base_image_sku        = "win11-22h2-avd-m365"
  base_image_version    = "latest"
  
  # Basic customizations
  install_windows_updates = true
  
  tags = local.common_tags
}
```

### Production Configuration with Customizations

```hcl
module "golden_image" {
  source = "../../modules/golden_image"

  resource_group_name   = azurerm_resource_group.rg.name
  location              = "eastus"
  
  gallery_name          = "avd_golden_images"
  image_definition_name = "avd-win11-m365-prod"
  image_template_name   = "avd-golden-image-prod-template"
  image_version         = "2.1.0"
  
  # Base image
  base_image_sku        = "win11-22h2-avd-m365"
  
  # Customizations
  install_windows_updates = true
  
  chocolatey_packages = [
    "googlechrome",
    "7zip",
    "adobereader",
    "microsoft-teams"
  ]
  
  inline_scripts = {
    "disable-ie" = [
      "Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart"
    ],
    "configure-edge" = [
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge' -Force",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge' -Name 'DefaultSearchProviderEnabled' -Value 1"
    ]
  }
  
  script_uris = {
    "install-fslogix" = "https://yourstorageaccount.blob.core.windows.net/scripts/Install-FSLogix.ps1"
  }
  
  # Multi-region replication
  replication_regions = ["eastus", "westus2", "centralus"]
  
  # Build settings
  build_vm_size        = "Standard_D8s_v5"  # Faster builds
  build_timeout_minutes = 300                # 5 hours for large builds
  
  tags = {
    Environment = "Production"
    ImageType   = "AVD-GoldenImage"
    Version     = "2.1.0"
  }
}
```

---

## Module Architecture

### Components Created

1. **Azure Compute Gallery (Shared Image Gallery)**
   - Repository for custom images
   - Supports versioning (1.0.0, 1.1.0, 2.0.0)
   - Enables image replication across regions

2. **Image Definition**
   - Metadata for the image series
   - Publisher/Offer/SKU identifier
   - OS type, Hyper-V generation

3. **Azure Image Builder Template**
   - Defines the build process
   - Source: Marketplace image
   - Customizations: Scripts, packages, updates
   - Distribution: Publish to gallery

4. **Managed Identity**
   - Used by AIB service
   - Contributor role on resource group
   - Permissions to create temp resources

### Build Process Flow

| Step | Action | Details |
|------|--------|----------|
| **1** | Start from Marketplace Image | Windows 11 multi-session + M365 Apps |
| **2** | Install Windows Updates | Security patches, cumulative updates |
| **3** | Install PowerShell Modules | Az modules, custom modules |
| **4** | Run Custom Scripts | Inline PowerShell, URI-based scripts |
| **5** | Install Applications (Chocolatey) | Chrome, 7zip, Adobe Reader, etc. |
| **6** | Restart (Optional) | If drivers or major updates require reboot |
| **7** | Cleanup and Optimize | Clear temp files, event logs, Windows Update cache |
| **8** | Sysprep and Generalize | Remove machine-specific data, prepare for deployment |
| **9** | Publish to Azure Compute Gallery | Create image version, replicate to regions |

**Build Time:** 30-90 minutes (varies based on customizations)

---

## Key Outputs

The module publishes images to **Azure Compute Gallery** and provides standardized outputs for session host deployment:

### Session Host Integration Outputs

| Output | Type | Description | Use Case |
|--------|------|-------------|----------|
| `image_version_id` | string | Pinned version resource ID | **Production** - Deploy specific version (e.g., `/versions/1.0.0`) |
| `gallery_image_version_id` | string | Alias for `image_version_id` | Consistent naming across modules |
| `latest_image_reference` | string | Floating 'latest' version | **Dev/Test** - Auto-update to newest version |

### Usage in Session Hosts Module

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"
  
  # Pinned version (recommended for production)
  gallery_image_version_id = module.golden_image[0].image_version_id
  
  # OR: Latest version (auto-update)
  # gallery_image_version_id = module.golden_image[0].latest_image_reference
}
```

### Additional Outputs

- `gallery_id` - Azure Compute Gallery resource ID
- `gallery_name` - Gallery name for Azure CLI operations
- `image_definition_id` - Image definition resource ID
- `template_name` - AIB template name for triggering builds
- `build_command_cli` - Azure CLI command to start build
- `build_command_powershell` - PowerShell command to start build

---

## Base Image Options

### Recommended Base Images for AVD

| SKU | Description | Use Case | M365 Apps | Cost |
|-----|-------------|----------|-----------|------|
| **win11-22h2-avd-m365** | Windows 11 Enterprise multi-session 22H2 + M365 Apps | **Recommended** - Modern UI, full productivity suite |  Included | Higher |
| **win11-23h2-avd-m365** | Windows 11 Enterprise multi-session 23H2 + M365 Apps | Latest Windows 11 version |  Included | Higher |
| **win11-22h2-avd** | Windows 11 Enterprise multi-session 22H2 (no M365) | No Office requirement |  Not included | Lower |
| **win10-22h2-avd-m365** | Windows 10 Enterprise multi-session 22H2 + M365 Apps | Legacy app compatibility |  Included | Higher |
| **win10-22h2-avd** | Windows 10 Enterprise multi-session 22H2 (no M365) | Legacy apps, no Office |  Not included | Lower |

### Example Base Image Configurations

**Windows 11 + Microsoft 365 (Recommended):**
```hcl
base_image_publisher = "MicrosoftWindowsDesktop"
base_image_offer     = "office-365"
base_image_sku       = "win11-22h2-avd-m365"
base_image_version   = "latest"
```

**Windows 10 + Microsoft 365:**
```hcl
base_image_publisher = "MicrosoftWindowsDesktop"
base_image_offer     = "office-365"
base_image_sku       = "win10-22h2-avd-m365"
base_image_version   = "latest"
```

**Windows 11 (No Office):**
```hcl
base_image_publisher = "MicrosoftWindowsDesktop"
base_image_offer     = "windows-11"
base_image_sku       = "win11-22h2-avd"
base_image_version   = "latest"
```

### Check Available Marketplace Images

```bash
# List all Windows 11 AVD images
az vm image list --publisher MicrosoftWindowsDesktop --offer office-365 --sku win11-*-avd-m365 --all --output table

# Get specific image details
az vm image show --location eastus --publisher MicrosoftWindowsDesktop --offer office-365 --sku win11-22h2-avd-m365 --version latest
```

---

## Customization Options

### 1. Windows Updates

```hcl
install_windows_updates = true  # Recommended - adds 15-30 minutes to build time
```

**What Gets Installed:**
- Security updates
- Cumulative updates
- .NET Framework updates
- Excludes: Preview updates (excluded by filter)

### 2. PowerShell Modules

```hcl
powershell_modules = [
  "Az.Accounts",
  "Az.Compute",
  "Az.Storage"
]
```

**Common Modules:**
- `Az.*` - Azure PowerShell modules
- `Pester` - Testing framework
- `PSWindowsUpdate` - Windows Update management

### 3. Inline PowerShell Scripts

```hcl
inline_scripts = {
  "disable-ie" = [
    "Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart"
  ],
  "enable-rdp" = [
    "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0",
    "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
  ],
  "configure-timezone" = [
    "Set-TimeZone -Id 'Eastern Standard Time'"
  ]
}
```

**Best Practices:**
- Keep scripts idempotent (can run multiple times safely)
- Use `-ErrorAction Continue` for non-critical steps
- Log to `C:\Temp\image-build.log` for troubleshooting

### 4. Script URIs (External Scripts)

```hcl
script_uris = {
  "install-fslogix"    = "https://yourstorageaccount.blob.core.windows.net/scripts/Install-FSLogix.ps1",
  "install-custom-app" = "https://yourstorageaccount.blob.core.windows.net/scripts/Install-App.ps1",
  "harden-os"          = "https://github.com/yourorg/scripts/raw/main/Harden-Windows.ps1"
}
```

**Script Requirements:**
- Must be publicly accessible or accessible via managed identity
- Must support unattended installation (no user interaction)
- Should exit with code 0 on success

**Example Script (Install-FSLogix.ps1):**
```powershell
# Download FSLogix
$url = "https://aka.ms/fslogix_download"
$output = "C:\Temp\FSLogix.zip"
Invoke-WebRequest -Uri $url -OutFile $output

# Extract and install
Expand-Archive -Path $output -DestinationPath "C:\Temp\FSLogix"
Start-Process -FilePath "C:\Temp\FSLogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "/install /quiet /norestart" -Wait

# Cleanup
Remove-Item -Path "C:\Temp\FSLogix*" -Recurse -Force
```

### 5. Chocolatey Packages

```hcl
chocolatey_packages = [
  "googlechrome",
  "7zip",
  "adobereader",
  "microsoft-teams",
  "notepadplusplus",
  "vlc"
]
```

**Popular AVD Packages:**
- `googlechrome` - Google Chrome
- `firefox` - Mozilla Firefox
- `adobereader` - Adobe Acrobat Reader DC
- `7zip` - 7-Zip file archiver
- `microsoft-teams` - Microsoft Teams
- `zoom` - Zoom video conferencing
- `vlc` - VLC media player
- `notepadplusplus` - Notepad++

**Search Packages:** https://community.chocolatey.org/packages

### 6. Restart After Customization

```hcl
restart_after_customization = true  # Use if installing drivers or major updates
```

**When to Enable:**
- Installing GPU drivers
- Installing .NET Framework major versions
- Major Windows features (Hyper-V, WSL, etc.)

### 7. Cleanup Script

```hcl
run_cleanup_script = true  # Recommended - reduces image size by 2-5GB
```

**What Gets Cleaned:**
- Temp files (`C:\Temp`, `C:\Windows\Temp`)
- Windows Update cache (`C:\Windows\SoftwareDistribution\Download`)
- Event logs (all event logs cleared)
- User profile temp folders

---

## How to Trigger a New Build

###  IMPORTANT: Manual Build Trigger Required

**Terraform creates the image builder infrastructure but does NOT automatically trigger builds.** You must manually trigger each build after `terraform apply`.

**Why Manual Trigger?**
- Builds take 30-90 minutes (avoid accidental long Terraform runs)
- Allows testing infrastructure before building
- Enables scheduled builds (nightly, weekly, etc.)

### Method 1: Azure CLI (Recommended)

```bash
# Trigger build
az image builder run \
  --resource-group avd-dev-rg \
  --name avd-golden-image-template

# Output:
# Build started. Run ID: 20260126-1530
```

### Method 2: PowerShell

```powershell
# Connect to Azure
Connect-AzAccount

# Trigger build
Start-AzImageBuilderTemplate `
  -ResourceGroupName "avd-dev-rg" `
  -Name "avd-golden-image-template"
```

### Method 3: Azure Portal

1. Navigate to **Image Builder** in Azure Portal
2. Select **Templates**
3. Click your template (e.g., `avd-golden-image-template`)
4. Click **Run** at the top
5. Confirm build start

### Method 4: Automated Builds (Azure DevOps / GitHub Actions)

**Azure DevOps Pipeline (azure-pipelines.yml):**
```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    displayName: 'Trigger Golden Image Build'
    inputs:
      azureSubscription: 'Azure-Subscription'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        az image builder run \
          --resource-group avd-dev-rg \
          --name avd-golden-image-template
```

**GitHub Actions (.github/workflows/build-image.yml):**
```yaml
name: Build Golden Image

on:
  schedule:
    - cron: '0 2 * * 0'  # Weekly on Sunday at 2 AM UTC
  workflow_dispatch:      # Manual trigger

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Trigger Image Build
        run: |
          az image builder run \
            --resource-group avd-dev-rg \
            --name avd-golden-image-template
```

---

## Monitor Build Status

### Real-Time Monitoring (Azure CLI)

```bash
# Check build status
az image builder show \
  --resource-group avd-dev-rg \
  --name avd-golden-image-template \
  --query "{Status: lastRunStatus.runState, SubStatus: lastRunStatus.runSubState, Message: lastRunStatus.message}"

# Output:
# Status      SubStatus         Message
# ----------  ----------------  ------------------------------
# Running     Distributing      Publishing image to gallery...

# Watch build status (refresh every 60 seconds)
watch -n 60 "az image builder show --resource-group avd-dev-rg --name avd-golden-image-template --query lastRunStatus"
```

### Build Status States

| State | SubState | Description | Action |
|-------|----------|-------------|--------|
| **Running** | Validating | Validating template | Wait |
| **Running** | Building | Creating temp VM, running customizations | Wait (30-60 min) |
| **Running** | Distributing | Sysprep, generalizing, publishing to gallery | Wait (10-20 min) |
| **Running** | Replicating | Replicating to additional regions | Wait (5-10 min per region) |
| **Succeeded** | - | Build completed successfully | Deploy session hosts |
| **Failed** | - | Build failed | Check logs (see troubleshooting) |

### Azure Portal Monitoring

1. **Navigate to Image Builder:**
   - Azure Portal → Search "Image Builder" → Templates

2. **View Build History:**
   - Click template name → **Run History** tab
   - Shows all builds with status, duration, errors

3. **View Build Logs:**
   - Click specific run → **Logs**
   - Download customizer logs, error logs

### PowerShell Monitoring

```powershell
# Get build status
$template = Get-AzImageBuilderTemplate -ResourceGroupName "avd-dev-rg" -Name "avd-golden-image-template"
$template.LastRunStatus | Format-List

# Wait for build completion (polling)
do {
    $template = Get-AzImageBuilderTemplate -ResourceGroupName "avd-dev-rg" -Name "avd-golden-image-template"
    Write-Host "Build Status: $($template.LastRunStatus.RunState) - $($template.LastRunStatus.RunSubState)"
    Start-Sleep -Seconds 60
} while ($template.LastRunStatus.RunState -eq "Running")

Write-Host "Build Complete: $($template.LastRunStatus.RunState)"
```

### Verify Image Version Created

```bash
# List all image versions
az sig image-version list \
  --resource-group avd-dev-rg \
  --gallery-name avd_golden_images \
  --gallery-image-definition avd-win11-m365 \
  --query "[].{Version:name, State:provisioningState, Published:publishingProfile.publishedDate}" \
  --output table

# Output:
# Version    State       Published
# ---------  ----------  ---------------------------
# 1.0.0      Succeeded   2026-01-26T15:45:23.123456Z
# 1.1.0      Succeeded   2026-01-26T16:30:12.654321Z

# Get specific version details
az sig image-version show \
  --resource-group avd-dev-rg \
  --gallery-name avd_golden_images \
  --gallery-image-definition avd-win11-m365 \
  --gallery-image-version 1.1.0 \
  --query "{Version:name, State:provisioningState, Regions:publishingProfile.targetRegions[].name, StorageType:publishingProfile.storageAccountType}"
```

---

## Roll Out Golden Image to Session Hosts

### Using session_host_image_strategy (Recommended)

**Modern approach using unified image strategy:**

```hcl
# In envs/dev/terraform.tfvars

# Set strategy to use Azure Image Builder golden images
session_host_image_strategy = "aib_gallery"

# Enable golden image module
enable_golden_image = true

# Configure image version pinning (recommended for production)
pin_golden_image_version = true  # Use specific version
# pin_golden_image_version = false  # Use latest version (auto-update)
```

The session_hosts module will automatically consume the golden image based on the strategy:

```hcl
# In envs/dev/main.tf (already configured)

module "session_hosts" {
  source = "../../modules/session-hosts"
  
  # Image automatically selected based on session_host_image_strategy
  # - "aib_gallery": Uses module.golden_image[0].image_version_id or latest_image_reference
  # - "marketplace": Uses marketplace image (default Windows 11)
  # - "manual_gallery": Uses manually imported image
  
  gallery_image_version_id = (
    local.image_strategy == "aib_gallery" ? (
      local.golden_image_config.pin_version ? 
        module.golden_image[0].image_version_id :
        module.golden_image[0].latest_image_reference
    ) : ...
  )
  
  # Other configuration...
}
```

### Strategy 1: New Session Host Pool (Greenfield)

**Best For:** Initial deployment, testing golden image

```hcl
# In envs/dev/main.tf

module "session_hosts_golden" {
  source = "../../modules/session-hosts"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.networking.avd_subnet_id
  
  vm_count       = 2
  vm_name_prefix = "avd-sh-golden"
  vm_size        = "Standard_D4s_v5"
  
  # Use golden image (recommended: pinned version)
  gallery_image_version_id = module.golden_image[0].image_version_id  # Pinned to specific version
  # gallery_image_version_id = module.golden_image[0].latest_image_reference  # Always use latest
  
  # Marketplace fallback disabled when using gallery image
  marketplace_image_reference = null
  
  # Other settings...
  domain_name           = var.domain_name
  domain_admin_username = var.domain_admin_username
  domain_admin_password = var.domain_admin_password
  
  hostpool_registration_token = module.avd_core.registration_token
  
  tags = local.common_tags
}
```

### Strategy 2: Gradual Rollout (Blue-Green Deployment)

**Best For:** Production environments, minimizing disruption

**Phase 1: Deploy Pilot Session Hosts (10%)**

```hcl
# Deploy 1-2 session hosts with golden image
module "session_hosts_pilot" {
  source = "../../modules/session-hosts"
  
  vm_count            = 1
  vm_name_prefix      = "avd-sh-pilot"
  source_image_id     = module.golden_image.latest_image_version_reference
  
  # Drain mode enabled - for testing only
  allow_new_sessions  = false
  
  # ... other settings
}
```

**Phase 2: Validate (1-2 days)**
- Test user logons
- Verify applications work
- Check performance metrics
- Monitor for errors

**Phase 3: Roll Out to Production (90%)**

```bash
# Step 1: Drain existing session hosts (stop new connections)
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name avd-sh-0 \
  --allow-new-session false

# Step 2: Wait for user sessions to end (or force logoff after hours)
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[?allowNewSession==false].{Name:name, Sessions:session}"

# Step 3: Delete old session hosts
az vm delete --resource-group avd-dev-rg --name avd-sh-0 --yes

# Step 4: Deploy new session hosts with golden image (via Terraform)
terraform apply -target=module.session_hosts
```

**Phase 4: Monitor (1 week)**
- User feedback
- Support ticket volume
- Performance metrics
- Cost analysis

### Strategy 3: Automated Rolling Update

**Best For:** Large deployments, automated pipelines

**Azure DevOps / GitHub Actions:**

```yaml
# Pseudo-code for rolling update
steps:
  - name: Get session hosts
    run: |
      SESSION_HOSTS=$(az desktopvirtualization sessionhost list --rg avd-dev-rg --host-pool avd-dev-hostpool --query "[].name" -o tsv)

  - name: Update one session host at a time
    run: |
      for SH in $SESSION_HOSTS; do
        echo "Draining $SH..."
        az desktopvirtualization sessionhost update --rg avd-dev-rg --host-pool avd-dev-hostpool --name $SH --allow-new-session false
        
        echo "Waiting for sessions to end..."
        while [ $(az desktopvirtualization sessionhost show --rg avd-dev-rg --host-pool avd-dev-hostpool --name $SH --query session -o tsv) -gt 0 ]; do
          sleep 60
        done
        
        echo "Deleting $SH..."
        az vm delete --resource-group avd-dev-rg --name $SH --yes
        
        echo "Deploying new $SH with golden image..."
        terraform apply -target="module.session_hosts.azurerm_windows_virtual_machine.session_host[$SH]"
        
        echo "Waiting 10 minutes before next session host..."
        sleep 600
      done
```

### Update session-hosts Module to Support Custom Images

**modules/session-hosts/main.tf** (add this support):

```hcl
variable "use_custom_image" {
  description = "Use custom image from Azure Compute Gallery instead of marketplace image"
  type        = bool
  default     = false
}

variable "custom_image_id" {
  description = "Full resource ID of custom image version (e.g., /subscriptions/.../images/avd-win11-m365/versions/latest)"
  type        = string
  default     = null
}

resource "azurerm_windows_virtual_machine" "session_host" {
  # ...existing code...
  
  # Use custom image if specified, otherwise marketplace image
  source_image_id = var.use_custom_image ? var.custom_image_id : null
  
  dynamic "source_image_reference" {
    for_each = var.use_custom_image ? [] : [1]
    content {
      publisher = var.image_publisher
      offer     = var.image_offer
      sku       = var.image_sku
      version   = var.image_version
    }
  }
}
```

---

## Rollback Strategy

### Scenario 1: Golden Image Has Critical Issue

**Symptoms:**
- Applications not working
- Users cannot log in
- Performance degradation

**Immediate Rollback (Emergency):**

```bash
# Step 1: Update session-hosts module to use previous image version
# In envs/dev/main.tf:
source_image_id = "/subscriptions/.../images/avd-win11-m365/versions/1.0.0"  # Previous working version

# Step 2: Destroy current session hosts
terraform destroy -target=module.session_hosts

# Step 3: Redeploy with previous image version
terraform apply -target=module.session_hosts
```

**Gradual Rollback (Controlled):**

```bash
# Deploy parallel session hosts with old image version
module "session_hosts_rollback" {
  source = "../../modules/session-hosts"
  
  vm_count        = 5
  vm_name_prefix  = "avd-sh-stable"
  source_image_id = "/subscriptions/.../images/avd-win11-m365/versions/1.0.0"  # Old version
  
  # ... other settings
}

# Drain and remove golden image session hosts
terraform destroy -target=module.session_hosts_golden
```

### Scenario 2: Marketplace Image Rollback

**When:** Golden image completely unusable, revert to marketplace image

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"
  
  # Disable custom image, use marketplace image
  use_custom_image = false
  
  # Marketplace image settings
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "office-365"
  image_sku       = "win11-22h2-avd-m365"
  image_version   = "latest"
  
  # ... other settings
}
```

### Image Version Management

**List All Image Versions:**
```bash
az sig image-version list \
  --resource-group avd-dev-rg \
  --gallery-name avd_golden_images \
  --gallery-image-definition avd-win11-m365 \
  --output table
```

**Delete Bad Image Version:**
```bash
az sig image-version delete \
  --resource-group avd-dev-rg \
  --gallery-name avd_golden_images \
  --gallery-image-definition avd-win11-m365 \
  --gallery-image-version 1.1.0
```

**Mark Image Version as Non-Latest:**
```hcl
# In module configuration
exclude_from_latest = true  # Test builds don't become "latest"
```

---

## Versioning Strategy

### Semantic Versioning (Recommended)

**Format:** `MAJOR.MINOR.PATCH` (e.g., `1.0.0`)

| Version | When to Increment | Example |
|---------|-------------------|---------|
| **MAJOR** | Breaking changes, OS upgrade, major app version change | 1.0.0 → 2.0.0 (Win10 → Win11) |
| **MINOR** | New features, new applications, significant updates | 1.0.0 → 1.1.0 (Added Chrome, Teams) |
| **PATCH** | Bug fixes, minor updates, security patches | 1.0.0 → 1.0.1 (Monthly Windows Update) |

**Examples:**

```hcl
# Initial release
image_version = "1.0.0"

# Added new applications (Chrome, 7zip)
image_version = "1.1.0"

# Monthly Windows Update
image_version = "1.1.1"

# Major OS upgrade (Windows 10 → Windows 11)
image_version = "2.0.0"
```

### Date-Based Versioning

**Format:** `YYYY.MM.DD` (e.g., `2026.01.26`)

**Best For:** Monthly builds, clear timeline

```hcl
# January 2026 build
image_version = "2026.01.0"

# February 2026 build
image_version = "2026.02.0"

# Mid-month hotfix
image_version = "2026.02.1"
```

### Tagging Strategy

```hcl
tags = {
  ImageVersion      = "1.1.0"
  BuildDate         = "2026-01-26"
  BaseImage         = "win11-22h2-avd-m365"
  WindowsUpdates    = "2026-01"
  Applications      = "Chrome,Teams,7zip"
  TestedBy          = "AVD-Team"
  ApprovedBy        = "John Doe"
  ApprovedDate      = "2026-01-27"
}
```

---

## Cost Estimation

### Build Costs (Per Build)

| Component | Cost | Notes |
|-----------|------|-------|
| **Temporary Build VM** | $1.00 - $2.00 | Standard_D4s_v5 for 1-2 hours |
| **Temporary Disk** | $0.10 - $0.20 | 127GB Premium SSD for 1-2 hours |
| **Network Egress** | $0.05 - $0.10 | Script downloads, package installs |
| **AIB Service** | $0.00 | FREE (no separate charge) |
| **Total Per Build** | **$1.15 - $2.30** | One-time cost per build |

### Storage Costs (Monthly)

| Component | Cost | Notes |
|-----------|------|-------|
| **Image Storage (1 region)** | $5.00 - $10.00 | 127GB image, Standard_LRS |
| **Image Storage (3 regions)** | $15.00 - $30.00 | 3x replication |
| **Compute Gallery** | $0.00 | FREE (no separate charge) |
| **Snapshots/Versions** | $1.00 - $5.00 | Old versions retained |
| **Total Monthly** | **$6.00 - $35.00** | Depends on regions/versions |

### Example: Monthly Builds

**Scenario:** Build new image monthly, keep 3 versions, replicate to 2 regions

- **Builds:** 1 build/month × $2 = **$2/month**
- **Storage:** 127GB × 3 versions × 2 regions × $0.10/GB = **$76.20/month**
- **Total:** **$78.20/month**

**Optimization:**
- Delete old versions (keep last 3): **$38/month**
- Use Standard_LRS instead of Premium: **$25/month**
- Single region only: **$12/month**

### Cost Savings from Golden Images

**Without Golden Image (Marketplace):**
- Session host deployment: 30-60 minutes per VM
- Script execution on every VM
- Windows Update on every VM (15-30 minutes)
- Total: 45-90 minutes per VM

**With Golden Image:**
- Session host deployment: 5-10 minutes per VM (6x faster!)
- No script execution needed
- No Windows Update needed
- Total: 5-10 minutes per VM

**Savings for 10 Session Hosts:**
- Time saved: 400-800 minutes (6-13 hours)
- Reduced compute costs during deployment
- Faster scale-out during peak demand

---

## Troubleshooting

### Build Failed - Check Logs

```bash
# Get build run ID
az image builder show \
  --resource-group avd-dev-rg \
  --name avd-golden-image-template \
  --query "lastRunStatus.runSubState"

# Download customization logs
az image builder show-runs \
  --resource-group avd-dev-rg \
  --name avd-golden-image-template \
  --output-name <run-id> \
  --download-path ./build-logs
```

**Common Log Locations:**
- `customization.log` - All customization steps
- `error.log` - Errors only
- `summary.json` - Build summary and status

### Common Build Failures

#### 1. Script Execution Failed

**Symptoms:**
```
Error: Customization step 'Custom-Script-1' failed with exit code 1
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Script has syntax errors | Test script locally on Windows 11 VM |
| Missing dependencies | Install prerequisites in earlier script |
| Network timeout | Increase `build_timeout_minutes` |
| Access denied | Ensure `run_as_system = true` |

#### 2. Windows Update Timeout

**Symptoms:**
```
Error: Windows Update step exceeded timeout
```

**Solutions:**
- Increase `build_timeout_minutes` to 360 (6 hours)
- Start from more recent marketplace image (fewer updates needed)
- Split into multiple builds (base updates → applications)

#### 3. Out of Disk Space

**Symptoms:**
```
Error: Insufficient disk space during customization
```

**Solutions:**
- Enable cleanup script: `run_cleanup_script = true`
- Use larger build VM with larger OS disk
- Remove unnecessary files in custom scripts

#### 4. Sysprep Failed

**Symptoms:**
```
Error: Sysprep failed during generalization
```

**Common Causes:**
- Windows Store apps not properly removed
- User profiles not cleaned up
- Pending Windows updates requiring reboot

**Solutions:**
```powershell
# Add to custom script before Sysprep
# Remove built-in apps that cause Sysprep failures
Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*Xbox*"} | Remove-AppxPackage -AllUsers
Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*Zune*"} | Remove-AppxPackage -AllUsers

# Clear user profiles
Remove-Item -Path "C:\Users\*" -Exclude "Public","Default*" -Recurse -Force -ErrorAction SilentlyContinue
```

#### 5. RBAC Permissions Error

**Symptoms:**
```
Error: Managed identity does not have permissions to create resources
```

**Solutions:**
```bash
# Verify managed identity has Contributor role
az role assignment list \
  --assignee <identity-principal-id> \
  --scope "/subscriptions/{sub-id}/resourceGroups/avd-dev-rg"

# Re-create role assignment
az role assignment create \
  --assignee <identity-principal-id> \
  --role "Contributor" \
  --scope "/subscriptions/{sub-id}/resourceGroups/avd-dev-rg"

# Wait 2-3 minutes for RBAC propagation
```

### Verify Template Configuration

```bash
# Validate template syntax
az image builder show \
  --resource-group avd-dev-rg \
  --name avd-golden-image-template \
  --query "source"

# Check customizations
az image builder show \
  --resource-group avd-dev-rg \
  --name avd-golden-image-template \
  --query "customize[].{Type:type, Name:name}"
```

---

## Best Practices

### 1.  Version Control Golden Image Definitions

Store image customization scripts in Git:

```
/avd-golden-images/
  /scripts/
    Install-FSLogix.ps1
    Install-Applications.ps1
    Configure-Registry.ps1
  /terraform/
    main.tf
    variables.tf
  CHANGELOG.md
  README.md
```

### 2.  Test Before Production

```hcl
# Dev/Test golden image
module "golden_image_dev" {
  source = "../../modules/golden_image"
  
  image_definition_name = "avd-win11-m365-dev"
  image_version         = "1.1.0-beta"
  exclude_from_latest   = true  # Don't mark as "latest"
  
  # Test customizations here first
}

# Production golden image (after testing)
module "golden_image_prod" {
  source = "../../modules/golden_image"
  
  image_definition_name = "avd-win11-m365-prod"
  image_version         = "1.1.0"
  exclude_from_latest   = false  # Mark as "latest"
}
```

### 3.  Schedule Regular Builds

**Monthly builds recommended:**
- Patch Tuesday (2nd Tuesday of month) + 7 days
- Allows time for Microsoft to address any patch issues

**Azure Automation Schedule:**
```powershell
# Create runbook to trigger build monthly
$runbook = @"
\$resourceGroup = "avd-dev-rg"
\$templateName = "avd-golden-image-template"

Write-Output "Triggering golden image build..."
Start-AzImageBuilderTemplate -ResourceGroupName \$resourceGroup -Name \$templateName
Write-Output "Build started successfully"
"@

New-AzAutomationRunbook -Name "Trigger-GoldenImageBuild" -Type PowerShell -ResourceGroupName "automation-rg" -AutomationAccountName "avd-automation"
```

### 4.  Document Image Versions

**CHANGELOG.md:**
```markdown
# Golden Image Changelog

## Version 1.1.0 (2026-01-26)
### Added
- Google Chrome 120.0.6099.109
- Microsoft Teams 1.6.00.4472
- 7-Zip 23.01

### Updated
- Windows 11 22H2 cumulative update (KB5034204)
- Microsoft 365 Apps to version 2312

### Fixed
- Disabled Windows Consumer Features
- Configured Edge as default browser

## Version 1.0.0 (2025-12-15)
### Initial Release
- Windows 11 22H2 multi-session
- Microsoft 365 Apps
- FSLogix 2.9.8884.27471
```

### 5.  Monitor Image Usage

```kql
// Session hosts using golden image vs marketplace
AzureActivity
| where ResourceProvider == "Microsoft.Compute"
| where OperationNameValue == "Microsoft.Compute/virtualMachines/write"
| extend ImageReference = tostring(parse_json(Properties).imageReference)
| summarize Count = count() by ImageReference
```

### 6.  Implement Change Control

**Before deploying new golden image version:**
- [ ] Test on pilot session hosts (10%)
- [ ] Validate all applications work
- [ ] Check performance metrics (CPU, memory, disk)
- [ ] Collect user feedback
- [ ] Document known issues
- [ ] Get approval from change board
- [ ] Schedule rollout during maintenance window

---

## Advanced Scenarios

### Scenario 1: Multi-Tier Images (Dev/Test/Prod)

```hcl
# Development image - more tools, less hardening
module "golden_image_dev" {
  source = "../../modules/golden_image"
  
  image_definition_name = "avd-win11-dev"
  
  chocolatey_packages = [
    "googlechrome",
    "vscode",
    "git",
    "postman",
    "notepadplusplus"
  ]
}

# Production image - hardened, minimal tools
module "golden_image_prod" {
  source = "../../modules/golden_image"
  
  image_definition_name = "avd-win11-prod"
  
  chocolatey_packages = [
    "googlechrome",
    "adobereader"
  ]
  
  inline_scripts = {
    "harden" = [
      "# Disable unused services",
      "Set-Service -Name 'XboxGipSvc' -StartupType Disabled",
      "# Configure Windows Defender",
      "Set-MpPreference -DisableRealtimeMonitoring $false",
      "# Enable audit logging",
      "auditpol /set /category:'Logon/Logoff' /success:enable /failure:enable"
    ]
  }
}
```

### Scenario 2: GPU-Enabled Image

```hcl
module "golden_image_gpu" {
  source = "../../modules/golden_image"
  
  image_definition_name = "avd-win11-gpu"
  build_vm_size         = "Standard_NV6ads_A10_v5"  # GPU VM
  
  script_uris = {
    "install-nvidia-driver" = "https://go.microsoft.com/fwlink/?linkid=874181"  # NVIDIA GRID driver
  }
  
  restart_after_customization = true  # GPU driver requires reboot
}
```

### Scenario 3: Regional Images

```hcl
module "golden_image_global" {
  source = "../../modules/golden_image"
  
  location = "eastus"  # Primary build region
  
  # Replicate to all AVD regions
  replication_regions = [
    "eastus",
    "westus2",
    "westeurope",
    "eastasia",
    "australiaeast"
  ]
  
  # Use Zone-Redundant Storage for high availability
  gallery_image_storage_account_type = "Standard_ZRS"
}
```

---

## Additional Resources

- [Azure Image Builder Documentation](https://docs.microsoft.com/azure/virtual-machines/image-builder-overview)
- [Azure Compute Gallery Documentation](https://docs.microsoft.com/azure/virtual-machines/azure-compute-gallery)
- [AVD Image Management Best Practices](https://docs.microsoft.com/azure/virtual-desktop/set-up-golden-image)
- [Marketplace Image List](https://docs.microsoft.com/azure/virtual-machines/windows/cli-ps-findimage)

---

## Support

**Common Questions:**

**Q: How long does a build take?**
A: 30-90 minutes depending on customizations. Windows Updates add 15-30 minutes.

**Q: Can I cancel a running build?**
A: Yes, via Azure Portal or `az image builder cancel-run`.

**Q: How many image versions should I keep?**
A: Recommend keeping last 3-6 versions for rollback purposes.

**Q: Can I build multiple images simultaneously?**
A: Yes, each template can run one build at a time, but multiple templates can build in parallel.

**Q: What if my script needs to download large files?**
A: Use larger build VM size (Standard_D8s_v5+) and increase timeout. Consider pre-staging files in Azure Blob Storage for faster access.

**Need Help?**
1. Check build logs (Azure Portal → Image Builder → Template → Run History)
2. Review [Troubleshooting](#troubleshooting) section
3. Test scripts locally on Windows 11 VM
4. Contact Azure Support with template ID and run ID
