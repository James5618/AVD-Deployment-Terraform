# ============================================================================
# Manual Image Import Module - Main Configuration
# ============================================================================
# Import manually created images (generalized VMs) into Azure Compute Gallery
# 
# PREREQUISITES:
# 1. VM must be generalized (sysprep for Windows, waagent -deprovision for Linux)
# 2. VM must be deallocated (stopped)
# 3. Image source must be available:
#    - Managed Image: Already created from generalized VM
#    - VHD: Uploaded to Azure Storage account
# 
# See README.md for detailed sysprep and image capture instructions.
# ============================================================================

# Validation: Ensure exactly one source is provided
locals {
  # Validate source_type matches provided source
  source_validation = (
    var.source_type == "managed_image" ? (
      var.managed_image_id != null ? true : tobool("ERROR: managed_image_id is required when source_type='managed_image'")
    ) : (
      var.source_vhd_uri != null ? true : tobool("ERROR: source_vhd_uri is required when source_type='vhd'")
    )
  )
  
  # Determine which gallery to use
  gallery_id = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].id : var.existing_gallery_id
  
  # Auto-generate managed image name from VHD if not provided
  vhd_image_name = var.vhd_managed_image_name != "" ? var.vhd_managed_image_name : "${var.image_definition_name}-vhd-import"
  
  # Determine source managed image ID (either provided or created from VHD)
  source_managed_image_id = var.source_type == "managed_image" ? var.managed_image_id : azurerm_image.from_vhd[0].id
}

# ============================================================================
# AZURE COMPUTE GALLERY (optional creation)
# ============================================================================

resource "azurerm_shared_image_gallery" "gallery" {
  count               = var.create_gallery ? 1 : 0
  name                = var.gallery_name
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = var.gallery_description

  tags = merge(
    var.tags,
    {
      Purpose = "Manual Image Import"
      Module  = "manual_image_import"
    }
  )
}

# ============================================================================
# IMAGE DEFINITION - Defines the image properties
# ============================================================================

resource "azurerm_shared_image" "definition" {
  name                = var.image_definition_name
  gallery_name        = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].name : basename(var.existing_gallery_id)
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = var.image_definition_description
  os_type             = var.os_type
  hyper_v_generation  = var.hyper_v_generation

  identifier {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
  }

  tags = merge(
    var.tags,
    {
      Publisher         = var.image_publisher
      Offer             = var.image_offer
      SKU               = var.image_sku
      HyperVGeneration  = var.hyper_v_generation
      ImportMethod      = "Manual"
    }
  )

  depends_on = [
    azurerm_shared_image_gallery.gallery
  ]
}

# ============================================================================
# MANAGED IMAGE FROM VHD (only if source_type = 'vhd')
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
    os_state     = var.os_state
    blob_uri     = var.source_vhd_uri
    storage_type = "Standard_LRS"
  }

  tags = merge(
    var.tags,
    {
      Purpose      = "VHD Import - Intermediate Managed Image"
      SourceVHD    = var.source_vhd_uri
      TargetGallery = var.gallery_name
    }
  )
}

# ============================================================================
# GALLERY IMAGE VERSION - The actual imported image
# ============================================================================
# Creates a versioned image in the gallery from either:
# - Existing managed image (if source_type = 'managed_image')
# - Managed image created from VHD (if source_type = 'vhd')
# ============================================================================

resource "azurerm_shared_image_version" "version" {
  name                = var.image_version
  gallery_name        = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].name : basename(var.existing_gallery_id)
  image_name          = azurerm_shared_image.definition.name
  resource_group_name = var.resource_group_name
  location            = var.location
  managed_image_id    = local.source_managed_image_id
  exclude_from_latest = var.exclude_from_latest

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
      Version        = var.image_version
      SourceType     = var.source_type
      SourceImage    = local.source_managed_image_id
      ExcludeFromLatest = var.exclude_from_latest ? "true" : "false"
    }
  )

  depends_on = [
    azurerm_shared_image.definition,
    azurerm_image.from_vhd
  ]
}
