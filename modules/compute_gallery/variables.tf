# ============================================================================
# Compute Gallery Module - Variable Definitions
# ============================================================================
# This module provides flexible Azure Compute Gallery management:
# - Create a new gallery in specified resource group
# - Use an existing gallery by providing its resource ID
#
# Use this module to centralize gallery management across multiple image
# import workflows (manual_image_import, golden_image, etc.).
# ============================================================================

variable "create_gallery" {
  description = "Whether to create a new Azure Compute Gallery. Set to false to use an existing gallery (requires existing_gallery_id)."
  type        = bool
  default     = true
}

variable "gallery_name" {
  description = "Name of the Azure Compute Gallery. Required if create_gallery=true. Must be globally unique, 1-80 alphanumeric/period/underscore characters."
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9._]{1,80}$", var.gallery_name))
    error_message = "gallery_name must be 1-80 characters, alphanumeric with periods and underscores only."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group where the gallery will be created. Required if create_gallery=true."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for the gallery (e.g., 'eastus', 'westeurope'). Required if create_gallery=true."
  type        = string
  default     = ""
}

variable "gallery_description" {
  description = "Description of the Azure Compute Gallery. Helps document the gallery's purpose."
  type        = string
  default     = "Azure Compute Gallery for custom images"
}

variable "existing_gallery_id" {
  description = "Resource ID of an existing Azure Compute Gallery. Required if create_gallery=false. Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{name}"
  type        = string
  default     = null
  
  validation {
    condition     = var.existing_gallery_id == null || can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Compute/galleries/[^/]+$", var.existing_gallery_id))
    error_message = "existing_gallery_id must be a valid Azure Compute Gallery resource ID or null."
  }
}

variable "tags" {
  description = "Tags to apply to the gallery resource. Applied only if create_gallery=true."
  type        = map(string)
  default     = {}
}
