# ============================================================================
# Gallery Image Definition Module - Variable Definitions
# ============================================================================
# This module creates an Azure Shared Image definition (image definition)
# inside an Azure Compute Gallery. Image definitions define the metadata
# and properties for a series of image versions.
#
# Image Definition = Template/Blueprint for images
# Image Version = Actual deployable image
#
# Use this module to create image definitions that can hold multiple
# versions of your custom images (e.g., 1.0.0, 1.1.0, 2.0.0).
# ============================================================================

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ GALLERY REFERENCE - Specify gallery by name+RG OR by resource ID          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "gallery_name" {
  description = "Name of the Azure Compute Gallery. Required if gallery_id is not provided."
  type        = string
  default     = ""
}

variable "gallery_resource_group_name" {
  description = "Resource group name of the gallery. Required if gallery_id is not provided."
  type        = string
  default     = ""
}

variable "gallery_id" {
  description = "Resource ID of the Azure Compute Gallery. If provided, gallery_name and gallery_resource_group_name are ignored. Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{name}"
  type        = string
  default     = null
  
  validation {
    condition     = var.gallery_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Compute/galleries/[^/]+$", var.gallery_id))
    error_message = "gallery_id must be a valid Azure Compute Gallery resource ID or null."
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ IMAGE DEFINITION CONFIGURATION - Define image properties                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "image_definition_name" {
  description = "Name of the image definition (e.g., 'windows11-avd-custom', 'ubuntu-2204-server'). Must be unique within the gallery. Use lowercase with hyphens for consistency."
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]{0,78}[a-zA-Z0-9]$", var.image_definition_name))
    error_message = "image_definition_name must be 1-80 characters, start/end with alphanumeric, and contain only alphanumeric, hyphens, underscores, or periods."
  }
}

variable "image_definition_description" {
  description = "Description of the image definition. Helps document the purpose and contents of this image."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for the image definition (e.g., 'eastus', 'westeurope'). Should match gallery location for optimal performance."
  type        = string
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ OS CONFIGURATION - Operating system and generation settings               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "os_type" {
  description = "Operating system type: 'Windows' or 'Linux'"
  type        = string
  default     = "Windows"
  
  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "os_type must be 'Windows' or 'Linux'."
  }
}

variable "os_state" {
  description = "OS state: 'Generalized' (sysprep/waagent run) or 'Specialized' (VM-specific). Most images should be 'Generalized'."
  type        = string
  default     = "Generalized"
  
  validation {
    condition     = contains(["Generalized", "Specialized"], var.os_state)
    error_message = "os_state must be 'Generalized' or 'Specialized'."
  }
}

variable "hyper_v_generation" {
  description = "Hyper-V generation: 'V1' (legacy BIOS, older VMs) or 'V2' (UEFI, required for Windows 11 and modern Linux). Must match source VM generation."
  type        = string
  default     = "V2"
  
  validation {
    condition     = contains(["V1", "V2"], var.hyper_v_generation)
    error_message = "hyper_v_generation must be 'V1' or 'V2'."
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ IMAGE IDENTIFIER - Publisher/Offer/SKU metadata (like Marketplace)        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# These values help organize and identify your custom images, similar to how
# Azure Marketplace images use publisher/offer/sku (e.g., MicrosoftWindowsDesktop/
# windows-11/win11-22h2-avd). Choose meaningful values for your organization.

variable "publisher" {
  description = "Publisher name for the image (e.g., 'MyCompany', 'Contoso', 'IT-Department'). Used for organization and filtering. Recommended: Use your company name."
  type        = string
  default     = "MyCompany"
}

variable "offer" {
  description = "Offer name for the image (e.g., 'Windows11-AVD', 'Windows10-Enterprise', 'Ubuntu-Server'). Groups related images. Recommended: Describe the OS and purpose."
  type        = string
  default     = "Windows-CustomImage"
}

variable "sku" {
  description = "SKU identifier for the image (e.g., 'custom-v1', 'enterprise-apps', '22h2-avd'). Identifies specific image variant. Recommended: Use version or configuration identifier."
  type        = string
  default     = "custom"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ ADDITIONAL SETTINGS - Purchase plan, features, and recommendations        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "eula" {
  description = "End-User License Agreement (EULA) for the image. Optional but recommended for documentation."
  type        = string
  default     = ""
}

variable "privacy_statement_uri" {
  description = "URI to privacy statement for the image (optional)"
  type        = string
  default     = ""
}

variable "release_note_uri" {
  description = "URI to release notes for the image (optional)"
  type        = string
  default     = ""
}

variable "end_of_life_date" {
  description = "End-of-life date for this image definition (ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ). After this date, image versions cannot be created. Example: '2026-12-31T23:59:59Z'"
  type        = string
  default     = null
}

variable "specialized" {
  description = "DEPRECATED: Use os_state='Specialized' instead. Kept for backward compatibility."
  type        = bool
  default     = null
}

variable "trusted_launch_enabled" {
  description = "Enable Trusted Launch for this image definition (Gen2 only). Provides Secure Boot and vTPM. Recommended for Windows 11 and modern Linux."
  type        = bool
  default     = false
}

variable "trusted_launch_supported" {
  description = "Indicates if Trusted Launch is supported (but not required) for VMs created from this image. Set to true if image supports Trusted Launch."
  type        = bool
  default     = false
}

variable "accelerated_network_supported" {
  description = "Indicates if accelerated networking is supported for VMs created from this image. Recommended: true for modern Windows/Linux images."
  type        = bool
  default     = true
}

variable "architecture" {
  description = "CPU architecture: 'x64' or 'Arm64'. Default is 'x64' for standard Intel/AMD CPUs."
  type        = string
  default     = "x64"
  
  validation {
    condition     = contains(["x64", "Arm64"], var.architecture)
    error_message = "architecture must be 'x64' or 'Arm64'."
  }
}

variable "disk_types_not_allowed" {
  description = "List of disk types not allowed for VMs using this image. Options: 'Standard_LRS', 'StandardSSD_LRS', 'Premium_LRS', 'UltraSSD_LRS'. Leave empty to allow all types."
  type        = list(string)
  default     = []
}

variable "max_recommended_vcpu_count" {
  description = "Maximum recommended vCPU count for VMs using this image. Helps guide VM size selection. Example: 32"
  type        = number
  default     = null
}

variable "min_recommended_vcpu_count" {
  description = "Minimum recommended vCPU count for VMs using this image. Example: 2"
  type        = number
  default     = null
}

variable "max_recommended_memory_in_gb" {
  description = "Maximum recommended memory (GB) for VMs using this image. Example: 128"
  type        = number
  default     = null
}

variable "min_recommended_memory_in_gb" {
  description = "Minimum recommended memory (GB) for VMs using this image. Example: 4"
  type        = number
  default     = null
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ TAGS - Resource tags for organization and cost tracking                   ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "tags" {
  description = "Tags to apply to the image definition resource"
  type        = map(string)
  default     = {}
}
