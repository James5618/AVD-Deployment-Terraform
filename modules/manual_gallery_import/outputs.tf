# ============================================================================
# Manual Gallery Import Module - Outputs
# ============================================================================

output "image_version_id" {
  description = "Resource ID of the imported image version (use this for session host deployment with pinned version)"
  value       = azurerm_shared_image_version.version.id
}

output "image_version_number" {
  description = "Version number of the imported image (e.g., '1.0.0')"
  value       = azurerm_shared_image_version.version.name
}

output "latest_image_reference" {
  description = "Full resource path to use 'latest' version with session hosts (floating version reference)"
  value       = "${var.resource_group_name}/providers/Microsoft.Compute/galleries/${var.gallery_name}/images/${var.image_definition_name}/versions/latest"
}

output "gallery_image_version_id" {
  description = "Alias for image_version_id - standardized output name for consistency"
  value       = azurerm_shared_image_version.version.id
}

output "managed_image_id" {
  description = "Resource ID of the intermediate managed image (only populated if source_type='vhd')"
  value       = var.source_type == "vhd" ? azurerm_image.from_vhd[0].id : null
}

output "source_type" {
  description = "The source type used for import (managed_image or vhd)"
  value       = var.source_type
}

output "replication_status" {
  description = "Replication regions configured for this image version"
  value = {
    primary_region      = var.location
    additional_regions  = var.replication_regions
    replica_count       = var.replica_count
    storage_type        = var.storage_account_type
  }
}

output "image_metadata" {
  description = "Metadata about the imported image"
  value = {
    gallery_name         = var.gallery_name
    image_definition     = var.image_definition_name
    version              = var.image_version
    exclude_from_latest  = var.exclude_from_latest
    os_type              = var.os_type
    hyper_v_generation   = var.hyper_v_generation
  }
}
