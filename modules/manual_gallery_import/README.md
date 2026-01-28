# Manual Gallery Import Module

Lightweight module to import manually created images into **existing** Azure Compute Gallery infrastructure.

## Purpose

This module creates **only** the `azurerm_shared_image_version` resource to import manually prepared images into an existing gallery. It does NOT create the gallery or image definition - those must already exist.

## Use Cases

- Import manually generalized VMs into existing gallery infrastructure
- Create new versions of existing image definitions
- Migrate customized VMs to AVD with version control
- Test custom configurations before automating

## Prerequisites

1. **Azure Compute Gallery must exist** (created by `compute_gallery` module)
2. **Image Definition must exist** (created by `gallery_image_definition` module)
3. **Source image must be generalized**:
   - Windows: Run `sysprep.exe /generalize /oobe /shutdown`
   - Linux: Run `waagent -deprovision+user`
4. Source must be either:
   - **Managed Image**: Already captured from generalized VM
   - **VHD**: Uploaded to Azure Storage account

## Variables

### Required Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group where gallery exists | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `gallery_name` | Existing Azure Compute Gallery name | `string` | - | Yes |
| `image_definition_name` | Existing image definition name | `string` | - | Yes |
| `source_type` | Source type: managed_image or vhd | `string` | - | Yes |
| `image_version` | Semantic version (e.g., 1.0.0) | `string` | - | Yes |

### Image Source Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `managed_image_id` | Managed image resource ID (if source_type=managed_image) | `string` | `null` | Conditional |
| `source_vhd_uri` | VHD URI in blob storage (if source_type=vhd) | `string` | `null` | Conditional |
| `vhd_managed_image_name` | Intermediate managed image name (VHD only) | `string` | `""` | No |
| `os_type` | OS type: Windows or Linux | `string` | `"Windows"` | No |
| `hyper_v_generation` | Hyper-V generation: V1 or V2 | `string` | `"V2"` | No |

### Image Version Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `exclude_from_latest` | Exclude from 'latest' queries | `bool` | `true` | No |

### Replication Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `replication_regions` | Additional regions for replication | `list(string)` | `[]` | No |
| `replica_count` | Replicas per region (1-10) | `number` | `1` | No |
| `storage_account_type` | Storage type: Standard_LRS or Premium_LRS | `string` | `"Standard_LRS"` | No |
| `tags` | Resource tags | `map(string)` | `{}` | No |

## Usage

### Basic Example with Managed Image

```hcl
module "manual_gallery_import" {
  source = "../../modules/manual_gallery_import"

  resource_group_name   = "avd-prod-rg"
  location              = "eastus"
  
  # Reference existing gallery infrastructure
  gallery_name          = "avd_prod_gallery"
  image_definition_name = "windows11-avd-custom"
  
  # Source configuration
  source_type           = "managed_image"
  managed_image_id      = "/subscriptions/.../images/win11-golden-ref"
  
  # Version configuration
  image_version         = "1.0.0"
  exclude_from_latest   = true
  
  # Replication
  replication_regions   = ["westus2", "westeurope"]
  replica_count         = 2
  
  tags = {
    Environment = "Production"
    Purpose     = "AVD Custom Image"
  }
}
```

### Example with VHD Import

```hcl
module "manual_gallery_import" {
  source = "../../modules/manual_gallery_import"

  resource_group_name   = "avd-prod-rg"
  location              = "eastus"
  
  # Reference existing gallery infrastructure
  gallery_name          = "avd_prod_gallery"
  image_definition_name = "windows11-avd-custom"
  
  # VHD source configuration
  source_type           = "vhd"
  source_vhd_uri        = "https://mystorageacct.blob.core.windows.net/vhds/win11-custom.vhd"
  os_type               = "Windows"
  hyper_v_generation    = "V2"
  
  # Version configuration
  image_version         = "1.0.0"
  exclude_from_latest   = true
  
  tags = {
    Environment = "Production"
  }
}
```

### Integration with Session Hosts

```hcl
# Create gallery infrastructure first
module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "avd_prod_gallery"
  resource_group_name = "avd-prod-rg"
  location            = "eastus"
}

module "gallery_image_definition" {
  source = "../../modules/gallery_image_definition"
  
  gallery_name          = module.compute_gallery.gallery_name
  resource_group_name   = "avd-prod-rg"
  location              = "eastus"
  
  image_definition_name = "windows11-avd-custom"
  os_type               = "Windows"
  hyper_v_generation    = "V2"
  
  publisher             = "MyCompany"
  offer                 = "Windows11-AVD"
  sku                   = "custom"
}

# Import image version
module "manual_gallery_import" {
  source = "../../modules/manual_gallery_import"
  
  resource_group_name   = "avd-prod-rg"
  location              = "eastus"
  gallery_name          = module.compute_gallery.gallery_name
  image_definition_name = module.gallery_image_definition.image_definition_name
  
  source_type           = "managed_image"
  managed_image_id      = "/subscriptions/.../images/win11-golden-ref"
  image_version         = "1.0.0"
  
  depends_on = [
    module.compute_gallery,
    module.gallery_image_definition
  ]
}

# Deploy session hosts with imported image
module "session_hosts" {
  source = "../../modules/session-hosts"
  
  # Use pinned version (recommended for production)
  gallery_image_version_id = module.manual_gallery_import.image_version_id
  
  # OR use floating 'latest' version
  # gallery_image_version_id = module.manual_gallery_import.latest_image_reference
  
  # ... other session host configuration
}
```

## Source Types

### Managed Image (Recommended)

**When to use:**
- Fastest import method (10-20 minutes)
- Image already captured from generalized VM
- Same subscription deployment

**How to create:**

```bash
# Generalize and deallocate VM
az vm deallocate -g rg-temp -n vm-golden-ref
az vm generalize -g rg-temp -n vm-golden-ref

# Create managed image
az image create \
  --resource-group rg-temp \
  --name img-win11-custom \
  --source vm-golden-ref \
  --hyper-v-generation V2

# Get resource ID for Terraform
az image show \
  --resource-group rg-temp \
  --name img-win11-custom \
  --query id -o tsv
```

### VHD

**When to use:**
- Cross-subscription/tenant import
- Archived images in blob storage
- Legacy migration scenarios

**How to create:**

```bash
# Export VM disk to VHD (requires SAS token)
DISK_ID=$(az vm show -g rg-temp -n vm-ref --query storageProfile.osDisk.managedDisk.id -o tsv)

SAS_URL=$(az disk grant-access \
  --ids $DISK_ID \
  --duration-in-seconds 3600 \
  --access-level Read \
  --query accessSas -o tsv)

# Copy to storage account
az storage blob copy start \
  --source-uri "$SAS_URL" \
  --destination-blob win11-custom.vhd \
  --destination-container vhds \
  --account-name mystorageacct
```

## Version Management

### Semantic Versioning

Use semantic versioning for clear intent:

```
MAJOR.MINOR.PATCH

Examples:
1.0.0 - Initial release
1.0.1 - Hotfix: Security patches
1.1.0 - Feature: Added Chrome
2.0.0 - Major: Windows 11 23H2 upgrade
```

### Version Pinning

**Production (Recommended):**
```hcl
exclude_from_latest = true  # Force explicit version references
# Use: module.manual_gallery_import.image_version_id
```

**Dev/Test:**
```hcl
exclude_from_latest = false  # Allow 'latest' references
# Use: module.manual_gallery_import.latest_image_reference
```

## Replication

### Single Region (Default)

```hcl
# Deploys only to primary location
replication_regions = []
```

### Multi-Region

```hcl
# Replicate to additional regions (10-30 minutes per region)
replication_regions = ["westus2", "westeurope"]
replica_count       = 2  # Improves deployment speed
```

**Cost:** ~$5-10/month per image version + $2-5/month per additional region

## Outputs

| Output | Description | Example Use |
|--------|-------------|-------------|
| `image_version_id` | Pinned version resource ID | Session host deployment (pinned) |
| `latest_image_reference` | Floating 'latest' reference | Dev/test environments |
| `gallery_image_version_id` | Alias for `image_version_id` | Standardized naming |
| `managed_image_id` | Intermediate managed image (VHD only) | Cleanup/troubleshooting |
| `replication_status` | Replication configuration | Monitoring |

## Comparison with manual_image_import Module

| Feature | manual_gallery_import (this) | manual_image_import |
|---------|------------------------------|---------------------|
| Creates Gallery | No (must exist) | Yes (optional) |
| Creates Image Definition | No (must exist) | Yes |
| Creates Image Version | Yes | Yes |
| Use Case | Existing infrastructure | Standalone import |
| Module Weight | Lightweight | Full-featured |

## Troubleshooting

### Error: "Image definition not found"

**Cause:** Image definition doesn't exist in the gallery.

**Solution:**
```hcl
# Create image definition first
module "gallery_image_definition" {
  source = "../../modules/gallery_image_definition"
  # ...
}
```

### Error: "Source image not generalized"

**Cause:** VM wasn't generalized before capture.

**Solution:**
```bash
# Generalize VM
az vm generalize -g rg-temp -n vm-ref
```

### Replication Timeout

**Cause:** Large image or many regions.

**Expected Times:**
- Single region: 10-20 minutes
- 3 regions: 30-60 minutes
- 5+ regions: 60-120 minutes

**Solution:** Be patient or reduce `replication_regions`.

## See Also

- [compute_gallery module](../compute_gallery/README.md) - Create/manage galleries
- [gallery_image_definition module](../gallery_image_definition/README.md) - Create image definitions
- [session-hosts module](../session-hosts/README.md) - Deploy session hosts
- [Main README](../../README.md) - Full workflow documentation
