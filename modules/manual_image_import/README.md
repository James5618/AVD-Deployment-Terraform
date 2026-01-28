# Manual Image Import Module

Import manually created and customized VM images into Azure Compute Gallery for use with Azure Virtual Desktop session hosts.

## Overview

This module allows you to import custom Windows images that you've manually prepared, generalized (sysprep), and captured. It supports two import methods:

1. **From Managed Image** - Import an existing Azure Managed Image
2. **From VHD File** - Import directly from a VHD file stored in Azure Storage

The imported image is stored as a versioned image in Azure Compute Gallery, making it easy to deploy session hosts and manage image lifecycle.

## Table of Contents

1. [When to Use This Module](#when-to-use-this-module)
2. [Prerequisites](#prerequisites)
3. [Manual Image Preparation](#manual-image-preparation)
4. [Usage Examples](#usage-examples)
5. [Variables](#variables)
6. [Outputs](#outputs)
7. [Image Versioning Strategy](#image-versioning-strategy)
8. [Cost Considerations](#cost-considerations)
9. [Troubleshooting](#troubleshooting)

## When to Use This Module

**Use this module when:**
-  You have specific applications that require manual installation
-  Complex configurations that can't be automated with scripts
-  Migrating existing customized VMs to AVD
-  Need full control over image preparation process
-  Testing custom images before automating with Golden Image module

**Consider Golden Image module instead when:**
-  Image build can be automated with scripts/Chocolatey packages
-  Need scheduled/repeatable image builds
-  Want CI/CD integration for image pipeline
-  Prefer Infrastructure-as-Code for everything

## Prerequisites

Before using this module, you must have **ONE** of the following:

### Option 1: Managed Image (Recommended)
- Azure Managed Image created from generalized VM
- Resource ID of the managed image

### Option 2: VHD File
- VHD file uploaded to Azure Storage Account
- Storage account with blob container
- Blob URL of the VHD file (e.g., `https://mystorageacct.blob.core.windows.net/vhds/myimage.vhd`)

**In both cases, the source VM MUST be generalized (sysprepped) before capture!**

## Manual Image Preparation

Follow these steps to prepare a Windows VM for import:

### Step 1: Create and Customize VM

1. **Deploy a Windows VM** in Azure:
   ```bash
   # Via Azure Portal or Azure CLI
   az vm create \
     --resource-group rg-image-prep \
     --name vm-image-source \
     --image Win11-22H2 \
     --size Standard_D4s_v5 \
     --admin-username localadmin
   ```

2. **Connect to VM** via RDP and customize:
   - Install applications (Office, Chrome, Adobe Reader, LOB apps, etc.)
   - Apply Windows updates
   - Configure Windows settings and registry
   - Install FSLogix if not using automated configuration
   - Remove unnecessary software and temporary files

3. **Clean up** before generalization:
   ```powershell
   # Clear temp files
   Remove-Item C:\Windows\Temp\* -Recurse -Force
   Remove-Item C:\Users\*\AppData\Local\Temp\* -Recurse -Force
   
   # Clear event logs
   wevtutil el | ForEach-Object { wevtutil cl $_ }
   
   # Remove unique identifiers
   Remove-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\SysPrepExternal -Recurse -Force -ErrorAction SilentlyContinue
   ```

### Step 2: Generalize VM with Sysprep

** CRITICAL: Once you run sysprep, the VM becomes unusable. Make a backup if needed!**

1. **Run Sysprep** (inside the VM):
   ```powershell
   # Open elevated PowerShell and run:
   C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown
   ```

   **Sysprep Options:**
   - `/generalize` - Removes machine-specific data (SID, computer name, event logs)
   - `/oobe` - VM boots to Out-of-Box Experience on first start
   - `/shutdown` - Shuts down VM after sysprep completes

2. **Wait for VM to shutdown** - This may take 5-15 minutes
   ```bash
   # Check VM power state
   az vm get-instance-view \
     --resource-group rg-image-prep \
     --name vm-image-source \
     --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
   ```

3. **Deallocate VM** (REQUIRED before capture):
   ```bash
   az vm deallocate \
     --resource-group rg-image-prep \
     --name vm-image-source
   
   # Mark VM as generalized in Azure metadata
   az vm generalize \
     --resource-group rg-image-prep \
     --name vm-image-source
   ```

### Step 3: Capture Image

Choose **ONE** of the following methods:

#### Method A: Capture to Managed Image (Recommended)

**Easiest method - creates managed image directly from VM:**

```bash
az image create \
  --resource-group rg-images \
  --name win11-avd-custom-managed \
  --source /subscriptions/{subscription-id}/resourceGroups/rg-image-prep/providers/Microsoft.Compute/virtualMachines/vm-image-source \
  --location eastus \
  --hyper-v-generation V2 \
  --os-type Windows
```

**Get the managed image resource ID:**
```bash
az image show \
  --resource-group rg-images \
  --name win11-avd-custom-managed \
  --query id -o tsv
```

Use this ID with `source_type = "managed_image"` and `managed_image_id = "<resource-id>"`

#### Method B: Capture to VHD

**Alternative method - exports OS disk to VHD file in storage:**

```bash
# Get OS disk resource ID
DISK_ID=$(az vm show \
  --resource-group rg-image-prep \
  --name vm-image-source \
  --query "storageProfile.osDisk.managedDisk.id" -o tsv)

# Grant access to disk (generates SAS URL)
SAS_URL=$(az disk grant-access \
  --resource-group rg-image-prep \
  --name $(basename $DISK_ID) \
  --duration-in-seconds 3600 \
  --query accessSas -o tsv)

# Create storage account and container
az storage account create \
  --name mystorageacct123 \
  --resource-group rg-images \
  --location eastus \
  --sku Standard_LRS

az storage container create \
  --name vhds \
  --account-name mystorageacct123

# Copy disk to storage (this may take 10-30 minutes)
az storage blob copy start \
  --destination-blob win11-avd-custom.vhd \
  --destination-container vhds \
  --account-name mystorageacct123 \
  --source-uri "$SAS_URL"

# Monitor copy progress
az storage blob show \
  --container-name vhds \
  --name win11-avd-custom.vhd \
  --account-name mystorageacct123 \
  --query "properties.copy.status"
```

**Get the VHD blob URL:**
```bash
az storage blob url \
  --container-name vhds \
  --name win11-avd-custom.vhd \
  --account-name mystorageacct123 -o tsv
```

Use this URL with `source_type = "vhd"` and `source_vhd_uri = "<blob-url>"`

### Step 4: Clean Up Source VM

**After successful image capture, delete the source VM to save costs:**

```bash
az vm delete \
  --resource-group rg-image-prep \
  --name vm-image-source \
  --yes

# Optionally delete the entire resource group
az group delete \
  --name rg-image-prep \
  --yes
```

## Usage Examples

### Example 1: Import from Managed Image (Recommended)

```hcl
module "manual_image_import" {
  source = "../../modules/manual_image_import"

  import_enabled      = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Gallery Configuration (create new gallery)
  create_gallery      = true
  gallery_name        = "avd_custom_images"
  gallery_description = "Custom AVD images prepared manually"

  # Image Definition
  image_definition_name        = "windows11-avd-apps"
  image_definition_description = "Windows 11 with Office, Chrome, and LOB apps"
  image_publisher              = "MyCompany"
  image_offer                  = "Windows11-AVD"
  image_sku                    = "apps-v1"
  os_type                      = "Windows"
  hyper_v_generation           = "V2"

  # Source: Managed Image
  source_type       = "managed_image"
  managed_image_id  = "/subscriptions/12345678-1234-1234-1234-123456789abc/resourceGroups/rg-images/providers/Microsoft.Compute/images/win11-avd-custom-managed"

  # Version Configuration
  image_version         = "1.0.0"
  exclude_from_latest   = false
  replication_regions   = []  # Replicate only to source region
  replica_count         = 1
  storage_account_type  = "Standard_LRS"

  tags = {
    Environment = "Production"
    Purpose     = "AVD Session Hosts"
    ImportDate  = "2026-01-26"
  }
}

# Use imported image with session hosts
module "session_hosts" {
  source = "../../modules/session-hosts"

  # ... other configuration ...

  session_host_image_source = "gallery"
  gallery_image_version_id  = module.manual_image_import.latest_image_reference

  depends_on = [
    module.manual_image_import
  ]
}
```

### Example 2: Import from VHD

```hcl
module "manual_image_import" {
  source = "../../modules/manual_image_import"

  import_enabled      = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Gallery Configuration
  create_gallery      = true
  gallery_name        = "avd_custom_images"

  # Image Definition
  image_definition_name = "windows11-avd-migrated"
  image_publisher       = "MyCompany"
  image_offer           = "Windows11-AVD"
  image_sku             = "migrated-v1"
  os_type               = "Windows"
  hyper_v_generation    = "V2"

  # Source: VHD
  source_type           = "vhd"
  source_vhd_uri        = "https://mystorageacct.blob.core.windows.net/vhds/win11-avd-custom.vhd"
  vhd_managed_image_name = "win11-avd-intermediate"  # Optional, auto-generated if not provided

  # Version Configuration
  image_version = "1.0.0"

  tags = {
    Environment = "Production"
    MigrationSource = "On-Premises"
  }
}
```

### Example 3: Use Existing Gallery

```hcl
module "manual_image_import" {
  source = "../../modules/manual_image_import"

  import_enabled      = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Use existing gallery (shared across multiple images)
  create_gallery       = false
  existing_gallery_id  = "/subscriptions/12345678-1234-1234-1234-123456789abc/resourceGroups/rg-shared/providers/Microsoft.Compute/galleries/shared_gallery"
  gallery_name         = "shared_gallery"  # Name is still required for reference

  # Image Definition
  image_definition_name = "windows11-avd-apps-v2"
  image_publisher       = "MyCompany"
  image_offer           = "Windows11-AVD"
  image_sku             = "apps-v2"
  os_type               = "Windows"
  hyper_v_generation    = "V2"

  # Source
  source_type      = "managed_image"
  managed_image_id = "/subscriptions/.../images/win11-avd-v2"

  # Version
  image_version = "2.0.0"

  tags = local.common_tags
}
```

### Example 4: Multi-Region Replication

```hcl
module "manual_image_import" {
  source = "../../modules/manual_image_import"

  import_enabled      = true
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus"

  # Gallery Configuration
  create_gallery = true
  gallery_name   = "avd_multi_region_images"

  # Image Definition
  image_definition_name = "windows11-avd-global"
  image_publisher       = "MyCompany"
  image_offer           = "Windows11-AVD"
  image_sku             = "global"
  os_type               = "Windows"
  hyper_v_generation    = "V2"

  # Source
  source_type      = "managed_image"
  managed_image_id = "/subscriptions/.../images/win11-avd-global"

  # Version with multi-region replication
  image_version       = "1.0.0"
  replication_regions = ["westus2", "northeurope", "southeastasia"]  # Replicate to 3 additional regions
  replica_count       = 2  # 2 replicas per region for better performance
  storage_account_type = "Premium_LRS"  # Faster replication and deployment

  tags = {
    Environment = "Production"
    Deployment  = "Global"
  }
}
```

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `resource_group_name` | `string` | Resource group for gallery and images |
| `location` | `string` | Azure region |
| `gallery_name` | `string` | Azure Compute Gallery name |
| `image_definition_name` | `string` | Name for image definition |
| `source_type` | `string` | Source type: `"managed_image"` or `"vhd"` |
| `image_version` | `string` | Semantic version (e.g., "1.0.0") |

### Source Variables (provide ONE)

| Variable | Type | Required When | Description |
|----------|------|---------------|-------------|
| `managed_image_id` | `string` | `source_type = "managed_image"` | Resource ID of managed image |
| `source_vhd_uri` | `string` | `source_type = "vhd"` | Blob URL of VHD file |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `import_enabled` | `bool` | `false` | Enable/disable module |
| `create_gallery` | `bool` | `true` | Create new gallery or use existing |
| `existing_gallery_id` | `string` | `null` | Resource ID of existing gallery |
| `image_publisher` | `string` | `"MyCompany"` | Publisher name |
| `image_offer` | `string` | `"Windows-AVD-Custom"` | Offer name |
| `image_sku` | `string` | `"custom"` | SKU name |
| `os_type` | `string` | `"Windows"` | OS type: `"Windows"` or `"Linux"` |
| `hyper_v_generation` | `string` | `"V2"` | Hyper-V generation: `"V1"` or `"V2"` |
| `os_state` | `string` | `"Generalized"` | OS state: `"Generalized"` or `"Specialized"` |
| `exclude_from_latest` | `bool` | `false` | Exclude version from "latest" |
| `replication_regions` | `list(string)` | `[]` | Additional regions for replication |
| `replica_count` | `number` | `1` | Replicas per region (1-3) |
| `storage_account_type` | `string` | `"Standard_LRS"` | Storage type for replicas |

## Outputs

| Output | Description |
|--------|-------------|
| `gallery_id` | Resource ID of gallery |
| `gallery_name` | Name of gallery |
| `image_definition_id` | Resource ID of image definition |
| `image_version_id` | Resource ID of image version |
| `latest_image_reference` | Path to use with session hosts (includes `/versions/latest`) |
| `managed_image_id` | Resource ID of intermediate managed image (VHD imports only) |
| `replication_status` | List of regions where image is replicated |

## Image Versioning Strategy

### Semantic Versioning

Use semantic versioning (MAJOR.MINOR.PATCH) for image versions:

```
1.0.0 - Initial production image
1.0.1 - Hotfix (security patch, critical bug fix)
1.1.0 - Minor update (new application version, Windows updates)
2.0.0 - Major update (Windows upgrade, significant app changes)
```

### Version Management Examples

**Scenario 1: Monthly Windows Updates**
```hcl
# January image
image_version = "1.0.0"

# February image (with January patches)
image_version = "1.1.0"

# March image (with February patches)
image_version = "1.2.0"
```

**Scenario 2: Testing Before Production**
```hcl
# Test version (excluded from latest)
image_version = "1.1.0-beta"
exclude_from_latest = true

# Production version after testing
image_version = "1.1.0"
exclude_from_latest = false
```

**Scenario 3: Rollback Strategy**
```hcl
# Keep previous versions available
# Session hosts can explicitly reference old versions:
# gallery_image_version_id = ".../versions/1.0.0"  # Instead of /versions/latest
```

## Cost Considerations

### Storage Costs

| Component | Cost (per month) | Notes |
|-----------|------------------|-------|
| Gallery (per region) | $0 | No cost for gallery itself |
| Image version (Standard_LRS) | ~$5-10 | Depends on image size (~50-100 GB typical) |
| Image version (Premium_LRS) | ~$15-20 | Faster but more expensive |
| VHD in blob storage | ~$2-5/month | Only if keeping VHD after import |
| Managed image | ~$5-10/month | Intermediate image (VHD imports only) |

**Total Monthly Cost:** $5-30 depending on storage tier and number of versions

### Replication Costs

**Example: Single-region image**
- 1 image version × $7/month = **$7/month**

**Example: Multi-region image (4 regions)**
- 4 regions × 2 replicas × $7/month = **$56/month**

 **Cost Optimization Tips:**
1. Delete old image versions after successful rollout
2. Use Standard_LRS unless you need fast deployment
3. Only replicate to regions where you deploy VMs
4. Delete intermediate managed images (VHD imports) after gallery import
5. Delete VHD files after successful import

## Troubleshooting

### Issue: "VM is not generalized"

**Symptoms:**
- Terraform fails with error about VM not being generalized
- Image capture fails

**Solution:**
```bash
# Ensure VM is deallocated
az vm deallocate --resource-group rg-image-prep --name vm-image-source

# Mark VM as generalized in Azure metadata
az vm generalize --resource-group rg-image-prep --name vm-image-source

# Verify status
az vm get-instance-view \
  --resource-group rg-image-prep \
  --name vm-image-source \
  --query "instanceView.statuses[?code=='OSState/generalized']"
```

### Issue: Sysprep Failed

**Symptoms:**
- Sysprep doesn't complete
- VM doesn't shutdown after sysprep

**Common Causes:**
1. **Modern apps not removed** - Windows Store apps can block sysprep
2. **Previous sysprep attempts** - Leftover sysprep state files
3. **Pending updates** - Windows updates requiring reboot

**Solutions:**

```powershell
# Check sysprep logs
Get-Content C:\Windows\System32\Sysprep\Panther\setuperr.log

# Remove all provisioned Windows Store apps
Get-AppxPackage -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue

# Clean up previous sysprep attempts
Remove-Item -Path C:\Windows\System32\Sysprep\Panther\* -Recurse -Force
Remove-Item -Path C:\Windows\Panther\Unattend\* -Recurse -Force -ErrorAction SilentlyContinue

# Ensure Windows is fully updated
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -Install -AcceptAll -AutoReboot

# Try sysprep again after reboot
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown
```

### Issue: VHD Import Takes Too Long

**Symptoms:**
- Terraform times out waiting for VHD import
- VHD copy to storage takes hours

**Solutions:**

```bash
# Check blob copy progress
az storage blob show \
  --container-name vhds \
  --name myimage.vhd \
  --account-name mystorageacct \
  --query "properties.copy.{status:status,progress:progress}"

# If stuck, cancel and retry with AzCopy (much faster)
az storage blob copy cancel \
  --destination-blob myimage.vhd \
  --destination-container vhds \
  --account-name mystorageacct

# Install AzCopy
# Download from: https://aka.ms/downloadazcopy-v10

# Copy with AzCopy (10-20x faster)
azcopy copy "$SAS_URL" \
  "https://mystorageacct.blob.core.windows.net/vhds/myimage.vhd?$DEST_SAS" \
  --blob-type PageBlob
```

### Issue: Session Hosts Fail to Deploy from Image

**Symptoms:**
- VMs fail to provision with image error
- VMs boot but fail domain join

**Possible Causes:**
1. **Image not generalized** - VM has unique identifiers
2. **Wrong Hyper-V generation** - Session host V2 but image is V1
3. **Image not replicated** - Deploying to region without replica

**Solutions:**

```bash
# Verify image is generalized
az image show \
  --resource-group rg-images \
  --name myimage \
  --query "storageProfile.osDisk.osState"
# Should return: "Generalized"

# Check Hyper-V generation matches
az sig image-definition show \
  --resource-group rg-images \
  --gallery-name mygallery \
  --gallery-image-definition myimagedef \
  --query "hyperVGeneration"
# Must match VM SKU generation

# Check replication status
az sig image-version show \
  --resource-group rg-images \
  --gallery-name mygallery \
  --gallery-image-definition myimagedef \
  --gallery-image-version 1.0.0 \
  --query "publishingProfile.targetRegions[].name"
```

### Issue: "Gallery name already exists"

**Symptoms:**
- Terraform fails with gallery name conflict

**Solution:**
```hcl
# Option 1: Use existing gallery
create_gallery      = false
existing_gallery_id = "/subscriptions/.../galleries/existing_gallery_name"

# Option 2: Choose a unique gallery name
gallery_name = "avd_custom_images_${var.environment}_${random_string.gallery_suffix.result}"
```

## Integration with Golden Image Module

You can use both modules in the same deployment:

- **Manual Image Import** - For initial image or complex customizations
- **Golden Image (AIB)** - For automated monthly updates

```hcl
# Manual import for initial/complex image
module "manual_image" {
  count  = var.use_manual_image ? 1 : 0
  source = "../../modules/manual_image_import"
  # ...
}

# Golden Image for automated updates
module "golden_image" {
  count  = var.enable_golden_image ? 1 : 0
  source = "../../modules/golden_image"
  # ...
}

# Session hosts use whichever is enabled
module "session_hosts" {
  source = "../../modules/session-hosts"
  
  session_host_image_source = var.use_manual_image ? "gallery" : (
    var.enable_golden_image ? "gallery" : "marketplace"
  )
  
  gallery_image_version_id = var.use_manual_image ? 
    module.manual_image[0].latest_image_reference : 
    (var.enable_golden_image ? module.golden_image[0].latest_image_version_reference : null)
  
  # Marketplace fallback
  marketplace_image_reference = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }
}
```

## Additional Resources

- [Azure Compute Gallery Documentation](https://docs.microsoft.com/azure/virtual-machines/azure-compute-gallery)
- [Sysprep Overview](https://docs.microsoft.com/windows-hardware/manufacture/desktop/sysprep--system-preparation--overview)
- [Capture VM to Managed Image](https://docs.microsoft.com/azure/virtual-machines/capture-image-resource)
- [Azure Image Builder vs Manual Images](https://docs.microsoft.com/azure/virtual-machines/image-builder-overview)
