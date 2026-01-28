# ============================================================================
# Compute Gallery Module - Main Configuration
# ============================================================================
# Provides flexible Azure Compute Gallery management:
# - Conditionally creates a new gallery OR uses an existing one
# - Validates that required inputs are provided based on mode
# - Outputs consistent gallery_id regardless of creation mode
#
# Usage:
#   Option 1 - Create new gallery:
#     create_gallery      = true
#     gallery_name        = "my_company_gallery"
#     resource_group_name = "rg-images"
#     location            = "eastus"
#
#   Option 2 - Use existing gallery:
#     create_gallery        = false
#     existing_gallery_id   = "/subscriptions/.../galleries/existing_gallery"
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
# Validation
# ============================================================================
# Ensure required variables are provided based on create_gallery mode

locals {
  # Validate create mode requirements
  validate_create_mode = var.create_gallery ? (
    var.resource_group_name != "" ? true : tobool("ERROR: resource_group_name is required when create_gallery=true")
  ) : true
  
  validate_create_location = var.create_gallery ? (
    var.location != "" ? true : tobool("ERROR: location is required when create_gallery=true")
  ) : true
  
  # Validate use existing mode requirements
  validate_existing_mode = !var.create_gallery ? (
    var.existing_gallery_id != null ? true : tobool("ERROR: existing_gallery_id is required when create_gallery=false")
  ) : true
  
  # Combine all validations
  validations_pass = (
    local.validate_create_mode &&
    local.validate_create_location &&
    local.validate_existing_mode
  )
}

# ============================================================================
# Azure Compute Gallery Resource
# ============================================================================
# Only created if create_gallery = true

resource "azurerm_shared_image_gallery" "gallery" {
  count = var.create_gallery ? 1 : 0
  
  name                = var.gallery_name
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = var.gallery_description
  
  tags = var.tags
}

# ============================================================================
# Data Source for Existing Gallery
# ============================================================================
# Used when create_gallery = false to validate the existing gallery exists

data "azurerm_shared_image_gallery" "existing" {
  count = !var.create_gallery && var.existing_gallery_id != null ? 1 : 0
  
  # Extract gallery name from resource ID
  name = regex("/galleries/([^/]+)$", var.existing_gallery_id)[0]
  
  # Extract resource group from resource ID
  resource_group_name = regex("/resourceGroups/([^/]+)/", var.existing_gallery_id)[0]
}
