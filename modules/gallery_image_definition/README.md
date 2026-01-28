# Gallery Image Definition Module

This module creates an Azure Shared Image definition (image definition) within an Azure Compute Gallery. Image definitions act as templates that can hold multiple versions of custom images.

## Overview

In Azure Compute Gallery, the hierarchy is:

- **Gallery** (top-level container)
  - **Image Definition** (this module creates this)
    - Image Version 1.0.0
    - Image Version 1.1.0
    - Image Version 2.0.0

**Image Definition** = Blueprint/template defining image properties (OS type, generation, publisher/offer/SKU)  
**Image Version** = Actual deployable image with specific content

This module creates the image definition. Image versions are created separately (via `manual_image_import` or `golden_image` modules).

## Features

- Create image definitions in Azure Compute Gallery
- Flexible gallery reference (by name+RG or by resource ID)
- Support for Windows and Linux images
- Hyper-V Gen1 and Gen2 support
- Trusted Launch configuration (Gen2)
- Publisher/Offer/SKU metadata (like Marketplace)
- VM size recommendations
- Disk type restrictions
- x64 and Arm64 architecture support  

## Usage

### Basic Example - Windows 11 AVD Image

```hcl
module "image_definition" {
  source = "../../modules/gallery_image_definition"
  
  # Gallery reference
  gallery_name                = "avd_prod_gallery"
  gallery_resource_group_name = "rg-images"
  location                    = "eastus"
  
  # Image definition
  image_definition_name        = "windows11-avd-custom"
  image_definition_description = "Windows 11 Enterprise Multi-Session with custom apps"
  
  # OS configuration
  os_type            = "Windows"
  hyper_v_generation = "V2"
  
  # Identifier (like Marketplace)
  publisher = "MyCompany"
  offer     = "Windows11-AVD"
  sku       = "22h2-custom"
  
  tags = {
    Environment = "Production"
    Purpose     = "AVD"
  }
}
```

### Using Gallery ID

```hcl
module "image_definition" {
  source = "../../modules/gallery_image_definition"
  
  # Use gallery ID instead of name+RG
  gallery_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/avd_prod_gallery"
  location   = "eastus"
  
  image_definition_name = "windows11-avd-custom"
  
  os_type            = "Windows"
  hyper_v_generation = "V2"
  
  publisher = "MyCompany"
  offer     = "Windows11-AVD"
  sku       = "custom"
}
```

### With Trusted Launch (Windows 11 Requirement)

```hcl
module "image_definition" {
  source = "../../modules/gallery_image_definition"
  
  gallery_name                = "avd_gallery"
  gallery_resource_group_name = "rg-images"
  location                    = "eastus"
  
  image_definition_name = "windows11-avd-trustedlaunch"
  
  os_type            = "Windows"
  hyper_v_generation = "V2"  # Required for Trusted Launch
  
  # Enable Trusted Launch (Secure Boot + vTPM)
  trusted_launch_enabled   = true
  trusted_launch_supported = true
  
  publisher = "MyCompany"
  offer     = "Windows11-AVD-SecureBoot"
  sku       = "22h2-trustedlaunch"
}
```

### With VM Recommendations

```hcl
module "image_definition" {
  source = "../../modules/gallery_image_definition"
  
  gallery_name                = "avd_gallery"
  gallery_resource_group_name = "rg-images"
  location                    = "eastus"
  
  image_definition_name = "windows11-avd-highperf"
  
  os_type            = "Windows"
  hyper_v_generation = "V2"
  
  # Recommend VM sizes (guides users to appropriate sizes)
  min_recommended_vcpu_count     = 4
  max_recommended_vcpu_count     = 16
  min_recommended_memory_in_gb   = 8
  max_recommended_memory_in_gb   = 64
  
  publisher = "MyCompany"
  offer     = "Windows11-AVD"
  sku       = "highperf"
}
```

### Linux Image Example

```hcl
module "ubuntu_definition" {
  source = "../../modules/gallery_image_definition"
  
  gallery_name                = "linux_images"
  gallery_resource_group_name = "rg-images"
  location                    = "eastus"
  
  image_definition_name        = "ubuntu-2204-server"
  image_definition_description = "Ubuntu 22.04 LTS Server with monitoring tools"
  
  os_type            = "Linux"
  hyper_v_generation = "V2"
  
  publisher = "MyCompany"
  offer     = "Ubuntu-Server"
  sku       = "22.04-LTS"
  
  accelerated_network_supported = true
}
```

### Integration with Environment Variables

```hcl
# In envs/dev/main.tf
locals {
  image_config = {
    gallery_name        = "avd_dev_gallery"
    gallery_rg_name     = "rg-images-dev"
    definition_name     = "windows11-avd-custom"
    publisher           = "MyCompany"
    offer               = "Windows11-AVD-Custom"
    sku                 = "custom"
    hyper_v_generation  = "V2"
    os_type             = "Windows"
  }
}

module "image_definition" {
  source = "../../modules/gallery_image_definition"
  
  gallery_name                = local.image_config.gallery_name
  gallery_resource_group_name = local.image_config.gallery_rg_name
  location                    = azurerm_resource_group.main.location
  
  image_definition_name = local.image_config.definition_name
  
  os_type            = local.image_config.os_type
  hyper_v_generation = local.image_config.hyper_v_generation
  
  publisher = local.image_config.publisher
  offer     = local.image_config.offer
  sku       = local.image_config.sku
  
  tags = local.common_tags
}
```

## Variables

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `gallery_name` | string | Conditional* | `""` | Gallery name (required if gallery_id not provided) |
| `gallery_resource_group_name` | string | Conditional* | `""` | Gallery resource group (required if gallery_id not provided) |
| `gallery_id` | string | Conditional** | `null` | Gallery resource ID (required if gallery_name not provided) |
| `image_definition_name` | string | **Yes** | - | Image definition name (1-80 chars) |
| `location` | string | **Yes** | - | Azure region |
| `os_type` | string | No | `"Windows"` | OS type: Windows or Linux |
| `os_state` | string | No | `"Generalized"` | OS state: Generalized or Specialized |
| `hyper_v_generation` | string | No | `"V2"` | Hyper-V generation: V1 or V2 |
| `publisher` | string | No | `"MyCompany"` | Publisher name |
| `offer` | string | No | `"Windows-CustomImage"` | Offer name |
| `sku` | string | No | `"custom"` | SKU identifier |
| `image_definition_description` | string | No | `""` | Image description |
| `trusted_launch_enabled` | bool | No | `false` | Enable Trusted Launch (Gen2 only) |
| `trusted_launch_supported` | bool | No | `false` | Trusted Launch supported |
| `accelerated_network_supported` | bool | No | `true` | Accelerated networking support |
| `architecture` | string | No | `"x64"` | CPU architecture: x64 or Arm64 |
| `min_recommended_vcpu_count` | number | No | `null` | Minimum recommended vCPUs |
| `max_recommended_vcpu_count` | number | No | `null` | Maximum recommended vCPUs |
| `min_recommended_memory_in_gb` | number | No | `null` | Minimum recommended memory (GB) |
| `max_recommended_memory_in_gb` | number | No | `null` | Maximum recommended memory (GB) |
| `disk_types_not_allowed` | list(string) | No | `[]` | Restricted disk types |
| `end_of_life_date` | string | No | `null` | End-of-life date (ISO 8601) |
| `tags` | map(string) | No | `{}` | Resource tags |

\* Required when `gallery_id` is not provided  
\*\* Required when `gallery_name` is not provided

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `image_definition_id` | string | Resource ID of the image definition |
| `image_definition_name` | string | Name of the image definition |
| `gallery_name` | string | Gallery name |
| `resource_group_name` | string | Resource group name |
| `location` | string | Azure region |
| `os_type` | string | Operating system type |
| `hyper_v_generation` | string | Hyper-V generation |
| `identifier` | object | Publisher/offer/sku metadata |
| `architecture` | string | CPU architecture |
| `os_state` | string | OS state (Generalized/Specialized) |
| `full_path` | string | Gallery/definition path format |

## Image Definition Naming

Best practices for `image_definition_name`:

```hcl
#  GOOD: Descriptive, version-aware
image_definition_name = "windows11-avd-22h2-custom"
image_definition_name = "ubuntu-2204-server"
image_definition_name = "rhel-8-enterprise"

#  GOOD: Purpose-based
image_definition_name = "windows11-avd-powerusers"
image_definition_name = "windows10-taskworkers"

#  BAD: Too generic
image_definition_name = "windows"
image_definition_name = "image1"
```

**Rules:**
- 1-80 characters
- Start and end with alphanumeric
- Can contain alphanumeric, hyphens, underscores, periods
- Use lowercase with hyphens for consistency

## Publisher/Offer/SKU Guidance

These identifiers help organize and categorize your images, similar to Azure Marketplace:

```hcl
# Example: Azure Marketplace Windows 11
publisher = "MicrosoftWindowsDesktop"
offer     = "windows-11"
sku       = "win11-22h2-avd"

# Your custom Windows 11 AVD image
publisher = "MyCompany"           # Your organization
offer     = "Windows11-AVD"       # Product line
sku       = "22h2-custom-apps"    # Specific variant

# Your custom Ubuntu server
publisher = "MyCompany"
offer     = "Ubuntu-Server"
sku       = "22.04-hardened"
```

**Best Practices:**
- **Publisher**: Use your company name (consistent across all images)
- **Offer**: Describe the OS and purpose (e.g., "Windows11-AVD", "Ubuntu-Server")
- **SKU**: Identify specific variant (e.g., "22h2-custom", "with-monitoring")

## Hyper-V Generation

| Generation | Description | Use Cases | VM Support |
|------------|-------------|-----------|------------|
| **V1** | Legacy BIOS | Older Windows/Linux, legacy apps | All Azure VM sizes |
| **V2** | UEFI (newer) | Windows 11, modern Linux, Trusted Launch | Most modern VM sizes |

**Recommendations:**
- Windows 11: **Must use V2**
- Windows 10: V2 recommended, V1 supported
- Modern Linux: V2 recommended
- Legacy apps: V1 if compatibility issues

**Important:** Hyper-V generation cannot be changed after VM creation. Ensure your source VM matches the generation specified here.

## Trusted Launch (Gen2 Only)

Trusted Launch provides additional security features:

- **Secure Boot**: Prevents unauthorized OS/drivers from loading
- **vTPM**: Virtual Trusted Platform Module for encryption key storage
- **Boot Integrity Monitoring**: Monitors boot process for tampering

```hcl
# Enable Trusted Launch
trusted_launch_enabled   = true  # Require Trusted Launch for VMs
trusted_launch_supported = true  # Allow but don't require

# Requirements:
# - hyper_v_generation = "V2"
# - Supported OS (Windows 11, Windows Server 2022, recent Linux)
```

**When to Use:**
- Windows 11 (recommended/required)
- High-security environments
- Compliance requirements (PCI-DSS, HIPAA)

## OS State: Generalized vs Specialized

| State | Description | Created By | VM Behavior |
|-------|-------------|------------|-------------|
| **Generalized** | Machine-specific info removed | sysprep (Windows), waagent (Linux) | Requires setup on first boot |
| **Specialized** | Machine-specific info intact | Direct capture | Ready to use immediately |

**Most images should be Generalized:**

```hcl
# Windows - Run sysprep before capture
os_state = "Generalized"  # Default

# Specialized images (rare use cases)
os_state = "Specialized"  # Keeps computer name, users, etc.
```

## VM Recommendations

Guide users to appropriate VM sizes:

```hcl
# Light workloads (task workers)
min_recommended_vcpu_count     = 2
max_recommended_vcpu_count     = 8
min_recommended_memory_in_gb   = 4
max_recommended_memory_in_gb   = 32

# Heavy workloads (power users)
min_recommended_vcpu_count     = 8
max_recommended_vcpu_count     = 32
min_recommended_memory_in_gb   = 16
max_recommended_memory_in_gb   = 128
```

## Disk Type Restrictions

Restrict disk types if needed for performance/cost control:

```hcl
# Only allow Premium SSD
disk_types_not_allowed = [
  "Standard_LRS",
  "StandardSSD_LRS"
]

# Only allow Standard/Standard SSD (no Premium)
disk_types_not_allowed = [
  "Premium_LRS",
  "UltraSSD_LRS"
]
```

## Architecture Support

```hcl
# Standard x64 (Intel/AMD)
architecture = "x64"  # Default

# ARM-based VMs
architecture = "Arm64"  # For ARM-based Azure VMs
```

## End-of-Life Date

Set a retirement date for old image definitions:

```hcl
# Retire Windows 10 images on December 31, 2026
end_of_life_date = "2026-12-31T23:59:59Z"

# After this date, no new image versions can be created
# Existing versions remain deployable
```

## Complete Example with All Features

```hcl
module "enterprise_image_definition" {
  source = "../../modules/gallery_image_definition"
  
  # Gallery reference
  gallery_name                = "enterprise_images"
  gallery_resource_group_name = "rg-images-prod"
  location                    = "eastus"
  
  # Image definition
  image_definition_name        = "windows11-enterprise-avd-22h2"
  image_definition_description = "Windows 11 Enterprise Multi-Session 22H2 with enterprise applications and security hardening"
  
  # OS configuration
  os_type            = "Windows"
  os_state           = "Generalized"
  hyper_v_generation = "V2"
  
  # Trusted Launch (Windows 11 best practice)
  trusted_launch_enabled   = true
  trusted_launch_supported = true
  
  # Publisher/Offer/SKU
  publisher = "ContosoIT"
  offer     = "Windows11-Enterprise-AVD"
  sku       = "22h2-hardened"
  
  # VM recommendations
  min_recommended_vcpu_count     = 4
  max_recommended_vcpu_count     = 16
  min_recommended_memory_in_gb   = 8
  max_recommended_memory_in_gb   = 64
  
  # Require Premium SSD for performance
  disk_types_not_allowed = ["Standard_LRS"]
  
  # Enable accelerated networking
  accelerated_network_supported = true
  
  # Architecture
  architecture = "x64"
  
  # Metadata
  eula                  = "https://contoso.com/eula"
  privacy_statement_uri = "https://contoso.com/privacy"
  release_note_uri      = "https://contoso.com/releases/win11-22h2"
  
  # End-of-life: Retire in 2 years
  end_of_life_date = "2028-01-31T23:59:59Z"
  
  tags = {
    Environment     = "Production"
    ManagedBy       = "Terraform"
    CostCenter      = "IT"
    Compliance      = "SOC2"
    OS              = "Windows11"
    Purpose         = "AVD"
    SecurityLevel   = "Hardened"
    UpdateSchedule  = "Monthly"
  }
}

output "image_definition_id" {
  value = module.enterprise_image_definition.image_definition_id
}
```

## Integration with Other Modules

### With compute_gallery Module

```hcl
# Step 1: Create gallery
module "gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "prod_images"
  resource_group_name = "rg-images"
  location            = "eastus"
}

# Step 2: Create image definition
module "image_definition" {
  source = "../../modules/gallery_image_definition"
  
  gallery_id = module.gallery.gallery_id
  location   = "eastus"
  
  image_definition_name = "windows11-avd-custom"
  
  os_type            = "Windows"
  hyper_v_generation = "V2"
  
  publisher = "MyCompany"
  offer     = "Windows11-AVD"
  sku       = "custom"
  
  depends_on = [module.gallery]
}

# Step 3: Import image version (using manual_image_import module)
# ... (see manual_image_import module documentation)
```

## Troubleshooting

### Error: Image definition name already exists

**Problem:** Image definition with same name exists in gallery

**Solution:**
```hcl
# Use unique names
image_definition_name = "windows11-avd-custom-v2"

# Or delete existing definition first
az sig image-definition delete \
  --resource-group rg-images \
  --gallery-name prod_images \
  --gallery-image-definition windows11-avd-custom
```

### Error: Trusted Launch not supported for Gen1

**Problem:** Trying to enable Trusted Launch on Gen1 image

**Solution:**
```hcl
# Use Gen2 for Trusted Launch
hyper_v_generation       = "V2"
trusted_launch_enabled   = true
```

### Error: Gallery not found

**Problem:** Gallery doesn't exist or incorrect reference

**Solution:**
```hcl
# Verify gallery exists
az sig show \
  --resource-group rg-images \
  --gallery-name prod_images

# Ensure module dependency
depends_on = [module.compute_gallery]
```

## Best Practices

1. **Use Descriptive Names**: Include OS version and purpose
   ```hcl
   image_definition_name = "windows11-22h2-avd-powerusers"
   ```

2. **Enable Trusted Launch for Windows 11**:
   ```hcl
   hyper_v_generation       = "V2"
   trusted_launch_enabled   = true
   ```

3. **Set VM Recommendations**: Guide users to appropriate sizes

4. **Use Consistent Publisher/Offer/SKU**: Follow your organization's naming convention

5. **Tag Appropriately**: Include environment, purpose, and compliance tags

6. **Plan for EOL**: Set end-of-life dates for old OS versions

## Azure Documentation

- [Azure Compute Gallery Overview](https://learn.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [Create image definitions](https://learn.microsoft.com/en-us/azure/virtual-machines/image-version)
- [Trusted Launch](https://learn.microsoft.com/en-us/azure/virtual-machines/trusted-launch)
- [Terraform: azurerm_shared_image](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/shared_image)
