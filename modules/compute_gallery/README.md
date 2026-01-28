# Azure Compute Gallery Module

This module provides flexible management of Azure Compute Galleries, supporting both creation of new galleries and usage of existing ones.

## Overview

Azure Compute Gallery (formerly Shared Image Gallery) is a service for managing and sharing custom VM images across subscriptions, regions, and tenants. This module simplifies gallery management by providing:

- **Conditional Creation**: Create a new gallery or use an existing one
- **Validation**: Ensures required inputs are provided based on mode
- **Consistent Interface**: Same output structure regardless of creation mode

## Use Cases

| Scenario | Configuration | Use Case |
|----------|---------------|----------|
| **New Gallery** | `create_gallery = true` | First-time deployment, isolated environments |
| **Existing Gallery** | `create_gallery = false` | Shared gallery across projects, centralized image management |
| **Multi-Region** | Create in primary region | Images can be replicated to other regions via image version replication |
| **Multi-Subscription** | Use existing gallery ID | Share images across subscription boundaries |

## Features

- Create new Azure Compute Gallery with custom name and description
- Use existing gallery by providing resource ID
- Input validation ensures correct configuration
- Consistent outputs regardless of mode
- Support for tags (when creating new gallery)
- Data source validation for existing galleries  

## Usage

### Option 1: Create New Gallery

```hcl
module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "my_company_avd_gallery"
  resource_group_name = "rg-images-prod"
  location            = "eastus"
  gallery_description = "Production AVD custom images"
  
  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    CostCenter  = "IT"
  }
}
```

### Option 2: Use Existing Gallery

```hcl
module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery        = false
  gallery_name          = "existing_gallery"  # Still required for reference
  existing_gallery_id   = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/existing_gallery"
}
```

### Option 3: Conditional Based on Variable

```hcl
variable "use_existing_gallery" {
  type    = bool
  default = false
}

variable "existing_gallery_id" {
  type    = string
  default = null
}

module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery        = !var.use_existing_gallery
  gallery_name          = var.use_existing_gallery ? "existing_gallery" : "new_gallery"
  resource_group_name   = var.use_existing_gallery ? "" : azurerm_resource_group.main.name
  location              = var.use_existing_gallery ? "" : azurerm_resource_group.main.location
  existing_gallery_id   = var.existing_gallery_id
  
  tags = local.common_tags
}
```

### Integration with Image Import Module

```hcl
# Centralized gallery management
module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "avd_images"
  resource_group_name = azurerm_resource_group.images.name
  location            = "eastus"
}

# Import manual image using the gallery
module "manual_image_import" {
  source = "../../modules/manual_image_import"
  
  import_enabled      = true
  resource_group_name = azurerm_resource_group.images.name
  location            = "eastus"
  
  # Use gallery module output
  create_gallery      = false
  existing_gallery_id = module.compute_gallery.gallery_id
  
  # Image configuration
  image_definition_name = "windows11-avd-custom"
  source_type           = "managed_image"
  managed_image_id      = var.source_managed_image_id
  image_version         = "1.0.0"
  
  # ... other configuration
}

# Golden image using the same gallery
module "golden_image" {
  source = "../../modules/golden_image"
  
  # Use the same gallery
  gallery_id            = module.compute_gallery.gallery_id
  image_definition_name = "windows11-avd-golden"
  
  # ... other configuration
}
```

## Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `create_gallery` | Whether to create a new Azure Compute Gallery. Set to false to use an existing gallery (requires existing_gallery_id) | `bool` | `true` | No |
| `gallery_name` | Name of the Azure Compute Gallery. Required if create_gallery=true. Must be globally unique, 1-80 alphanumeric/period/underscore characters | `string` | - | Yes |
| `resource_group_name` | Name of the resource group where the gallery will be created. Required if create_gallery=true | `string` | `""` | No |
| `location` | Azure region for the gallery (e.g., 'eastus', 'westeurope'). Required if create_gallery=true | `string` | `""` | No |
| `gallery_description` | Description of the Azure Compute Gallery. Helps document the gallery's purpose | `string` | `"Azure Compute Gallery for custom images"` | No |
| `existing_gallery_id` | Resource ID of an existing Azure Compute Gallery. Required if create_gallery=false. Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{name} | `string` | `null` | No |
| `tags` | Tags to apply to the gallery resource. Applied only if create_gallery=true | `map(string)` | `{}` | No |

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `create_gallery` | bool | Yes | `true` | Whether to create a new gallery (true) or use existing (false) |
| `gallery_name` | string | Yes | - | Gallery name (1-80 alphanumeric/period/underscore characters) |
| `resource_group_name` | string | Conditional* | `""` | Resource group name (required if create_gallery=true) |
| `location` | string | Conditional* | `""` | Azure region (required if create_gallery=true) |
| `gallery_description` | string | No | `"Azure Compute Gallery for custom images"` | Gallery description |
| `existing_gallery_id` | string | Conditional** | `null` | Existing gallery resource ID (required if create_gallery=false) |
| `tags` | map(string) | No | `{}` | Tags for the gallery (applied only when creating) |

\* Required when `create_gallery = true`  
\*\* Required when `create_gallery = false`

### Variable Validation

- **gallery_name**: Must be 1-80 characters, alphanumeric with periods and underscores only
- **existing_gallery_id**: Must be valid Azure Compute Gallery resource ID format
- **resource_group_name**: Required and non-empty when creating new gallery
- **location**: Required and non-empty when creating new gallery

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `gallery_id` | string | Resource ID of the gallery (created or existing) |
| `gallery_name` | string | Name of the gallery |
| `gallery_location` | string | Azure region where gallery is located |
| `gallery_unique_name` | string | Azure-assigned unique name for the gallery |
| `gallery_resource_group_name` | string | Resource group containing the gallery |
| `create_gallery` | bool | Indicates if gallery was created (true) or existing was used (false) |

## Gallery Naming Conventions

Azure Compute Gallery names must follow these rules:

- **Length**: 1-80 characters
- **Characters**: Alphanumeric, periods (.), underscores (_)
- **Global Uniqueness**: Must be unique within the subscription
- **Case**: Case-insensitive (Azure converts to lowercase internally)

### Recommended Patterns

```hcl
# Pattern 1: Project-based
gallery_name = "company_project_env_gallery"  # e.g., contoso_avd_prod_gallery

# Pattern 2: Purpose-based
gallery_name = "avd_images_prod"

# Pattern 3: Department-based
gallery_name = "it_windows_images"

# Pattern 4: Auto-generated with uniqueness
gallery_name = "${var.project}_${var.environment}_gallery_${random_string.suffix.result}"
```

## Resource ID Format

When using an existing gallery, provide the full resource ID in this format:

```
/subscriptions/{subscription-id}/resourceGroups/{resource-group-name}/providers/Microsoft.Compute/galleries/{gallery-name}
```

### Getting Existing Gallery ID

```bash
# Azure CLI
az sig show \
  --resource-group rg-images \
  --gallery-name my_company_gallery \
  --query id -o tsv

# PowerShell
$gallery = Get-AzGallery -ResourceGroupName "rg-images" -Name "my_company_gallery"
$gallery.Id
```

## Validation Logic

The module includes automatic validation:

```hcl
# When create_gallery = true
 resource_group_name must be non-empty
 location must be non-empty
 gallery_name must follow Azure naming rules

# When create_gallery = false
 existing_gallery_id must be provided
 existing_gallery_id must be valid resource ID format
 Gallery must exist (validated via data source)
```

## Cost Considerations

| Component | Cost | Notes |
|-----------|------|-------|
| **Gallery** | FREE | No charge for the gallery itself |
| **Image Definitions** | FREE | No charge for image definitions |
| **Image Versions** | ~$0.085/GB/month | Standard LRS storage pricing |
| **Replication** | Variable | Based on replica count and regions |

**Example Cost:**
- 50 GB image with 1 replica in 1 region: ~$4.25/month
- 50 GB image with 3 replicas in 3 regions: ~$12.75/month

## Permissions Required

### Creating New Gallery

- `Microsoft.Compute/galleries/write`
- `Microsoft.Compute/galleries/read`
- `Microsoft.Resources/subscriptions/resourceGroups/read`

### Using Existing Gallery

- `Microsoft.Compute/galleries/read`
- `Microsoft.Compute/galleries/images/write` (if adding image definitions)
- `Microsoft.Compute/galleries/images/versions/write` (if adding image versions)

### Role Assignments

```bash
# Contributor role on resource group (recommended)
az role assignment create \
  --assignee <principal-id> \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"

# Or custom role with minimal permissions
az role assignment create \
  --assignee <principal-id> \
  --role "Compute Gallery Image Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"
```

## Multi-Region Considerations

When creating a gallery:

1. **Primary Region**: Gallery is created in the specified `location`
2. **Image Replication**: Images can be replicated to other regions via image version configuration
3. **Access**: Gallery is accessible from all regions, but images must be explicitly replicated

Example multi-region setup:

```hcl
module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "global_avd_images"
  resource_group_name = "rg-images-global"
  location            = "eastus"  # Primary region
}

module "image_import_v1" {
  source = "../../modules/manual_image_import"
  
  existing_gallery_id   = module.compute_gallery.gallery_id
  
  # Replicate to multiple regions
  replication_regions = [
    "eastus",      # Primary
    "westus2",     # West Coast
    "westeurope"   # Europe
  ]
}
```

## Troubleshooting

### Error: Gallery name already exists

**Problem:** Gallery name conflicts with existing gallery in subscription

**Solution:**
```hcl
# Option 1: Use unique suffix
gallery_name = "avd_images_${random_string.suffix.result}"

# Option 2: Use existing gallery
create_gallery      = false
existing_gallery_id = "/subscriptions/.../galleries/existing_gallery"
```

### Error: Resource group not found

**Problem:** Specified resource group doesn't exist when creating gallery

**Solution:**
```hcl
# Ensure resource group is created first
resource "azurerm_resource_group" "images" {
  name     = "rg-images"
  location = "eastus"
}

module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  resource_group_name = azurerm_resource_group.images.name
  
  depends_on = [azurerm_resource_group.images]
}
```

### Error: Existing gallery not found

**Problem:** Provided existing_gallery_id doesn't exist or is inaccessible

**Solution:**
- Verify gallery ID is correct: `az sig show --ids <gallery-id>`
- Check permissions: Ensure service principal has read access
- Verify subscription context: `az account show`

## Best Practices

### 1. Gallery Naming

```hcl
#  GOOD: Descriptive, environment-specific
gallery_name = "avd_prod_images"

#  BAD: Too generic
gallery_name = "gallery"
```

### 2. Resource Group Organization

```hcl
#  GOOD: Dedicated resource group for images
resource "azurerm_resource_group" "images" {
  name     = "rg-images-${var.environment}"
  location = var.location
}

module "compute_gallery" {
  source              = "../../modules/compute_gallery"
  create_gallery      = true
  resource_group_name = azurerm_resource_group.images.name
}
```

### 3. Conditional Gallery Creation

```hcl
#  GOOD: Environment-based logic
locals {
  use_shared_gallery = var.environment == "prod"
  shared_gallery_id  = "/subscriptions/.../galleries/prod_shared"
}

module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = !local.use_shared_gallery
  gallery_name        = local.use_shared_gallery ? "prod_shared" : "avd_${var.environment}_gallery"
  resource_group_name = local.use_shared_gallery ? "" : azurerm_resource_group.main.name
  location            = local.use_shared_gallery ? "" : var.location
  existing_gallery_id = local.use_shared_gallery ? local.shared_gallery_id : null
}
```

### 4. Tagging Strategy

```hcl
#  GOOD: Comprehensive tags
module "compute_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery = true
  
  tags = {
    Environment  = var.environment
    ManagedBy    = "Terraform"
    CostCenter   = "IT"
    Purpose      = "AVD Custom Images"
    Compliance   = "SOC2"
    Owner        = "platform-team@company.com"
    Terraform    = "true"
    Repository   = "github.com/company/infrastructure"
  }
}
```

## Examples

### Example 1: Simple Gallery Creation

```hcl
module "gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "simple_gallery"
  resource_group_name = "rg-images"
  location            = "eastus"
}

output "gallery_id" {
  value = module.gallery.gallery_id
}
```

### Example 2: Environment-Specific Gallery

```hcl
variable "environment" {
  type = string
}

module "gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "avd_${var.environment}_images"
  resource_group_name = "rg-images-${var.environment}"
  location            = "eastus"
  gallery_description = "${upper(var.environment)} environment AVD images"
  
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

### Example 3: Shared Gallery Across Projects

```hcl
# Project A creates the gallery
module "shared_gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "company_shared_images"
  resource_group_name = "rg-shared-images"
  location            = "eastus"
  
  tags = {
    Purpose = "Shared across all projects"
  }
}

# Project B uses the existing gallery
module "gallery_reference" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = false
  gallery_name        = "company_shared_images"
  existing_gallery_id = "/subscriptions/.../galleries/company_shared_images"
}
```

### Example 4: Gallery with Random Suffix

```hcl
resource "random_string" "gallery_suffix" {
  length  = 6
  special = false
  upper   = false
}

module "gallery" {
  source = "../../modules/compute_gallery"
  
  create_gallery      = true
  gallery_name        = "avd_images_${random_string.gallery_suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}
```

## Azure Documentation

- [Azure Compute Gallery Overview](https://learn.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [Create an Azure Compute Gallery](https://learn.microsoft.com/en-us/azure/virtual-machines/create-gallery)
- [Share images across subscriptions](https://learn.microsoft.com/en-us/azure/virtual-machines/share-gallery)
- [Terraform: azurerm_shared_image_gallery](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/shared_image_gallery)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Azure Compute Gallery documentation
3. Verify permissions and resource IDs
4. Check Terraform plan output for validation errors
