# ============================================================================
# Manual Image Import Module - Variables
# ============================================================================
# Import manually created images (generalized VMs) into Azure Compute Gallery
# Supports two source types:
# 1. Managed Image (already captured from generalized VM)
# 2. VHD file (stored in Azure Storage, will create managed image first)
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# MODULE CONTROL
# ─────────────────────────────────────────────────────────────────────────────

variable "import_enabled" {
  description = "Enable manual image import to Azure Compute Gallery. Set to false to skip this module."
  type        = bool
  default     = false
}

# ─────────────────────────────────────────────────────────────────────────────
# RESOURCE GROUP & LOCATION
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Resource group name for Azure Compute Gallery and managed images"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# AZURE COMPUTE GALLERY CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "create_gallery" {
  description = "Create a new Azure Compute Gallery. Set to false to use existing gallery."
  type        = bool
  default     = true
}

variable "gallery_name" {
  description = "Azure Compute Gallery name (must be globally unique). Created if create_gallery=true, or used if gallery already exists."
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9._]{0,79}$", var.gallery_name))
    error_message = "Gallery name must start with a letter, contain only letters, numbers, periods, and underscores, and be 1-80 characters long."
  }
}

variable "gallery_description" {
  description = "Description for the Azure Compute Gallery"
  type        = string
  default     = "Gallery for manually imported AVD images"
}

variable "existing_gallery_id" {
  description = "Resource ID of existing Azure Compute Gallery (only used if create_gallery=false). Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{name}"
  type        = string
  default     = null
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE DEFINITION CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "image_definition_name" {
  description = "Name for the image definition (e.g., 'windows11-avd-custom', 'win10-apps-imported')"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,79}$", var.image_definition_name))
    error_message = "Image definition name must start with letter/number, contain only letters, numbers, periods, hyphens, and underscores, and be 1-80 characters."
  }
}

variable "image_definition_description" {
  description = "Description for the image definition"
  type        = string
  default     = "Manually imported custom AVD image"
}

variable "image_publisher" {
  description = "Publisher name for the image (e.g., 'Contoso', 'MyCompany'). Used for organization and filtering."
  type        = string
  default     = "MyCompany"
}

variable "image_offer" {
  description = "Offer name for the image (e.g., 'Windows11-AVD', 'CustomAVD')"
  type        = string
  default     = "Windows-AVD-Custom"
}

variable "image_sku" {
  description = "SKU name for the image (e.g., 'custom-1.0', 'apps-v2')"
  type        = string
  default     = "custom"
}

variable "os_type" {
  description = "Operating system type: 'Windows' or 'Linux'"
  type        = string
  default     = "Windows"
  
  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "os_type must be 'Windows' or 'Linux'."
  }
}

variable "hyper_v_generation" {
  description = "Hyper-V generation: 'V1' or 'V2'. Must match source VM generation."
  type        = string
  default     = "V2"
  
  validation {
    condition     = contains(["V1", "V2"], var.hyper_v_generation)
    error_message = "hyper_v_generation must be 'V1' or 'V2'."
  }
}

variable "os_state" {
  description = "OS state: 'Generalized' (sysprepped) or 'Specialized' (not sysprepped). Use 'Generalized' for AVD."
  type        = string
  default     = "Generalized"
  
  validation {
    condition     = contains(["Generalized", "Specialized"], var.os_state)
    error_message = "os_state must be 'Generalized' or 'Specialized'."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE SOURCE - Managed Image OR VHD (mutually exclusive)
# ─────────────────────────────────────────────────────────────────────────────

variable "source_type" {
  description = "Image source type: 'managed_image' (use existing managed image) or 'vhd' (import from VHD file)"
  type        = string
  
  validation {
    condition     = contains(["managed_image", "vhd"], var.source_type)
    error_message = "source_type must be 'managed_image' or 'vhd'."
  }
}

variable "managed_image_id" {
  description = "Resource ID of existing managed image (only used if source_type='managed_image'). Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/images/{name}"
  type        = string
  default     = null
  
  validation {
    condition     = var.managed_image_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Compute/images/.+$", var.managed_image_id))
    error_message = "managed_image_id must be a valid Azure Managed Image resource ID or null."
  }
}

variable "source_vhd_uri" {
  description = "URI of VHD file in Azure Storage (only used if source_type='vhd'). Example: https://mystorageacct.blob.core.windows.net/vhds/myimage.vhd"
  type        = string
  default     = null
  
  validation {
    condition     = var.source_vhd_uri == null || can(regex("^https://.+\\.blob\\.core\\.windows\\.net/.+\\.vhd$", var.source_vhd_uri))
    error_message = "source_vhd_uri must be a valid Azure Storage blob URI ending in .vhd or null."
  }
}

variable "vhd_managed_image_name" {
  description = "Name for managed image created from VHD (only used if source_type='vhd'). Leave empty to auto-generate."
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE VERSION CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "image_version" {
  description = "Semantic version for the imported image (e.g., '1.0.0', '1.1.0'). Must be unique within the image definition."
  type        = string
  
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.image_version))
    error_message = "image_version must be in semantic version format: major.minor.patch (e.g., 1.0.0)."
  }
}

variable "exclude_from_latest" {
  description = "Exclude this version from being returned as 'latest'. Set to true for testing/rollback versions."
  type        = bool
  default     = false
}

variable "replication_regions" {
  description = "Azure regions to replicate the image version to (for multi-region deployments). Leave empty to replicate only to source region."
  type        = list(string)
  default     = []
}

variable "replica_count" {
  description = "Number of replicas per region (1-3). Higher counts improve VM deployment performance."
  type        = number
  default     = 1
  
  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 3
    error_message = "replica_count must be between 1 and 3."
  }
}

variable "storage_account_type" {
  description = "Storage type for image replicas: 'Standard_LRS' (cheaper, slower) or 'Premium_LRS' (faster, more expensive)"
  type        = string
  default     = "Standard_LRS"
  
  validation {
    condition     = contains(["Standard_LRS", "Premium_LRS"], var.storage_account_type)
    error_message = "storage_account_type must be 'Standard_LRS' or 'Premium_LRS'."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
