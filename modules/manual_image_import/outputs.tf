# ============================================================================
# Manual Image Import Module - Outputs
# ============================================================================

output "gallery_id" {
  description = "Resource ID of the Azure Compute Gallery (created or existing)"
  value       = local.gallery_id
}

output "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  value       = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].name : basename(var.existing_gallery_id)
}

output "image_definition_id" {
  description = "Resource ID of the image definition"
  value       = azurerm_shared_image.definition.id
}

output "image_definition_name" {
  description = "Name of the image definition"
  value       = azurerm_shared_image.definition.name
}

output "image_version_id" {
  description = "Resource ID of the imported image version (use this for session host deployment)"
  value       = azurerm_shared_image_version.version.id
}

output "image_version_number" {
  description = "Version number of the imported image"
  value       = azurerm_shared_image_version.version.name
}

output "latest_image_reference" {
  description = "Full resource path to use with session hosts (includes /versions/latest suffix)"
  value       = "${azurerm_shared_image.definition.id}/versions/latest"
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
  description = "Target regions for image replication"
  value = concat(
    [var.location],
    var.replication_regions
  )
}
