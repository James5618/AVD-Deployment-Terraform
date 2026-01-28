# ============================================================================
# Manual Gallery Import Module - Variables
# ============================================================================
# Lightweight module to create image versions in EXISTING galleries.
# Does NOT create gallery or image definition - those must exist.
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# RESOURCE GROUP & LOCATION
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Resource group name where the gallery and image definition exist"
  type        = string
}

variable "location" {
  description = "Azure region for the image version and any intermediate resources"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# EXISTING GALLERY REFERENCES (must already exist)
# ─────────────────────────────────────────────────────────────────────────────

variable "gallery_name" {
  description = "Name of the EXISTING Azure Compute Gallery"
  type        = string
}

variable "image_definition_name" {
  description = "Name of the EXISTING image definition in the gallery"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE SOURCE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "source_type" {
  description = "Source type for image import: 'managed_image' (existing managed image) or 'vhd' (VHD file in blob storage)"
  type        = string
  
  validation {
    condition     = contains(["managed_image", "vhd"], var.source_type)
    error_message = "source_type must be 'managed_image' or 'vhd'."
  }
}

variable "managed_image_id" {
  description = "Resource ID of existing managed image (required if source_type='managed_image'). Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/images/win11-custom"
  type        = string
  default     = null
  
  validation {
    condition     = var.managed_image_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Compute/images/.+$", var.managed_image_id))
    error_message = "managed_image_id must be a valid Azure Managed Image resource ID or null."
  }
}

variable "source_vhd_uri" {
  description = "URI of VHD file in Azure Storage (required if source_type='vhd'). Example: https://mystorageacct.blob.core.windows.net/vhds/win11-custom.vhd"
  type        = string
  default     = null
  
  validation {
    condition     = var.source_vhd_uri == null || can(regex("^https?://.+\\.vhd$", var.source_vhd_uri))
    error_message = "source_vhd_uri must be a valid HTTPS URL ending in .vhd or null."
  }
}

variable "vhd_managed_image_name" {
  description = "Name for intermediate managed image created from VHD (only used if source_type='vhd'). Leave empty to auto-generate."
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# OS CONFIGURATION (required for VHD import)
# ─────────────────────────────────────────────────────────────────────────────

variable "os_type" {
  description = "Operating system type: 'Windows' or 'Linux'. Required for VHD import."
  type        = string
  default     = "Windows"
  
  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "os_type must be 'Windows' or 'Linux'."
  }
}

variable "hyper_v_generation" {
  description = "Hyper-V generation: 'V1' (BIOS) or 'V2' (UEFI). Must match source VM. V2 required for Windows 11."
  type        = string
  default     = "V2"
  
  validation {
    condition     = contains(["V1", "V2"], var.hyper_v_generation)
    error_message = "hyper_v_generation must be 'V1' or 'V2'."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE VERSION CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "image_version" {
  description = "Semantic version for the image (e.g., '1.0.0', '1.1.0'). Must be unique within image definition."
  type        = string
  
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_version))
    error_message = "image_version must be in semantic version format (e.g., '1.0.0')."
  }
}

variable "exclude_from_latest" {
  description = "Exclude this image version from being returned by 'latest' queries. Recommended: true for production."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# REPLICATION CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "replication_regions" {
  description = "Additional Azure regions to replicate the image to (besides the primary location). Example: ['westus2', 'westeurope']"
  type        = list(string)
  default     = []
}

variable "replica_count" {
  description = "Number of replicas to maintain per region (1-10). Higher count improves deployment speed but increases storage cost."
  type        = number
  default     = 1
  
  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 10
    error_message = "replica_count must be between 1 and 10."
  }
}

variable "storage_account_type" {
  description = "Storage account type for replicas: 'Standard_LRS' (lower cost) or 'Premium_LRS' (faster deployment)"
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
