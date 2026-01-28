# ============================================================================
# Manual Gallery Import Module - Main Configuration
# ============================================================================
# Lightweight module to import manually created images into EXISTING Azure 
# Compute Gallery infrastructure (gallery + image definition must exist).
#
# This module ONLY creates the azurerm_shared_image_version resource.
# Use this when gallery and image definition are managed separately.
#
# PREREQUISITES:
# 1. Azure Compute Gallery must exist (created by compute_gallery module)
# 2. Image Definition must exist (created by gallery_image_definition module)
# 3. Source image must be generalized:
#    - Managed Image: Already captured from generalized VM
#    - VHD: Uploaded to Azure Storage
# ============================================================================

locals {
  # Validate source_type matches provided source
  source_validation = (
    var.source_type == "managed_image" ? (
      var.managed_image_id != null ? true : 
      tobool("ERROR: managed_image_id is required when source_type='managed_image'")
    ) : (
      var.source_vhd_uri != null ? true :
      tobool("ERROR: source_vhd_uri is required when source_type='vhd'")
    )
  )
  
  # Auto-generate managed image name from VHD if not provided
  vhd_image_name = var.vhd_managed_image_name != "" ? var.vhd_managed_image_name : "${var.image_definition_name}-vhd-${replace(var.image_version, ".", "-")}"
  
  # Determine source managed image ID (either provided or created from VHD)
  source_managed_image_id = var.source_type == "managed_image" ? var.managed_image_id : azurerm_image.from_vhd[0].id
}

# ============================================================================
# MANAGED IMAGE FROM VHD (optional - only if source_type = 'vhd')
# ============================================================================
# Creates a managed image from a VHD file stored in Azure Storage.
# This is an intermediate step - the managed image is then imported to gallery.
# ============================================================================

resource "azurerm_image" "from_vhd" {
  count               = var.source_type == "vhd" ? 1 : 0
  name                = local.vhd_image_name
  resource_group_name = var.resource_group_name
  location            = var.location
  hyper_v_generation  = var.hyper_v_generation

  os_disk {
    os_type      = var.os_type
    os_state     = "Generalized"
    blob_uri     = var.source_vhd_uri
    storage_type = "Standard_LRS"
  }

  tags = merge(
    var.tags,
    {
      Purpose       = "VHD Import - Intermediate Managed Image"
      SourceVHD     = var.source_vhd_uri
      TargetVersion = var.image_version
    }
  )
}

# ============================================================================
# GALLERY IMAGE VERSION - Import image into existing gallery
# ============================================================================
# Creates a versioned image in the gallery from either:
# - Existing managed image (if source_type = 'managed_image')
# - Managed image created from VHD (if source_type = 'vhd')
#
# IMPORTANT: Gallery and image definition must already exist.
# ============================================================================

resource "azurerm_shared_image_version" "version" {
  name                = var.image_version
  gallery_name        = var.gallery_name
  image_name          = var.image_definition_name
  resource_group_name = var.resource_group_name
  location            = var.location
  managed_image_id    = local.source_managed_image_id
  exclude_from_latest = var.exclude_from_latest

  # Primary replication region
  target_region {
    name                   = var.location
    regional_replica_count = var.replica_count
    storage_account_type   = var.storage_account_type
  }

  # Additional replication regions
  dynamic "target_region" {
    for_each = var.replication_regions
    content {
      name                   = target_region.value
      regional_replica_count = var.replica_count
      storage_account_type   = var.storage_account_type
    }
  }

  tags = merge(
    var.tags,
    {
      ImageVersion = var.image_version
      SourceType   = var.source_type
      ImportDate   = timestamp()
    }
  )

  depends_on = [
    azurerm_image.from_vhd
  ]
}
