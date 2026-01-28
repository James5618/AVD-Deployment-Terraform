# ============================================================================
# Gallery Image Definition Module - Main Configuration
# ============================================================================
# Creates an Azure Shared Image definition (image definition) within an
# Azure Compute Gallery. The image definition acts as a template/blueprint
# that can hold multiple image versions.
#
# Image hierarchy:
#   Gallery → Image Definition → Image Version (1.0.0, 1.1.0, etc.)
#
# This module handles gallery reference resolution (by name+RG or by ID)
# and creates the image definition with all specified properties.
# ============================================================================

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# ============================================================================
# Locals - Resolve gallery reference and compute derived values
# ============================================================================

locals {
  # Determine if using gallery_id or gallery_name+rg_name
  use_gallery_id = var.gallery_id != null
  
  # Extract gallery name from ID if using gallery_id
  gallery_name_from_id = local.use_gallery_id ? regex("/galleries/([^/]+)$", var.gallery_id)[0] : ""
  gallery_rg_from_id   = local.use_gallery_id ? regex("/resourceGroups/([^/]+)/", var.gallery_id)[0] : ""
  
  # Final gallery name and resource group
  gallery_name                = local.use_gallery_id ? local.gallery_name_from_id : var.gallery_name
  gallery_resource_group_name = local.use_gallery_id ? local.gallery_rg_from_id : var.gallery_resource_group_name
  
  # Validation: Ensure either gallery_id OR (gallery_name + gallery_resource_group_name) is provided
  validate_gallery_reference = (
    local.use_gallery_id ? true : (
      var.gallery_name != "" && var.gallery_resource_group_name != "" ? true :
      tobool("ERROR: Either gallery_id OR both gallery_name and gallery_resource_group_name must be provided")
    )
  )
  
  # Handle deprecated 'specialized' variable for backward compatibility
  actual_os_state = var.specialized != null ? (var.specialized ? "Specialized" : "Generalized") : var.os_state
}

# ============================================================================
# Azure Shared Image (Image Definition)
# ============================================================================

resource "azurerm_shared_image" "image_definition" {
  name                = var.image_definition_name
  gallery_name        = local.gallery_name
  resource_group_name = local.gallery_resource_group_name
  location            = var.location
  os_type             = var.os_type
  hyper_v_generation  = var.hyper_v_generation
  description         = var.image_definition_description != "" ? var.image_definition_description : "Custom ${var.os_type} image: ${var.image_definition_name}"
  
  # Publisher/Offer/SKU identifier (like Marketplace images)
  identifier {
    publisher = var.publisher
    offer     = var.offer
    sku       = var.sku
  }
  
  # Optional: Trusted Launch configuration (Gen2 only)
  # Note: dynamic "features" block not supported in current provider version
  # Trusted launch must be configured during image creation/versioning
  
  # Optional: Purchase plan (for marketplace-style images)
  # Uncomment if needed for specific licensing scenarios
  # dynamic "purchase_plan" {
  #   for_each = var.plan_name != "" ? [1] : []
  #   content {
  #     name      = var.plan_name
  #     publisher = var.plan_publisher
  #     product   = var.plan_product
  #   }
  # }
  
  # Optional: VM recommendations
  # Note: dynamic "recommended" block not supported in current provider version
  # VM sizing recommendations should be documented externally
  
  # Optional: Disk types not allowed
  disk_types_not_allowed = length(var.disk_types_not_allowed) > 0 ? var.disk_types_not_allowed : null
  
  # Optional: Architecture (x64 or Arm64)
  architecture = var.architecture
  
  # Optional: Additional URIs and metadata
  eula                   = var.eula != "" ? var.eula : null
  privacy_statement_uri  = var.privacy_statement_uri != "" ? var.privacy_statement_uri : null
  release_note_uri       = var.release_note_uri != "" ? var.release_note_uri : null
  end_of_life_date       = var.end_of_life_date
  
  # Optional: Accelerated networking support
  # Note: accelerated_network_supported not supported in current provider version
  # Accelerated networking configured at VM/VMSS level
  
  tags = var.tags
}
