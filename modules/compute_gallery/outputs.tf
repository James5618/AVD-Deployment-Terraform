# ============================================================================
# Compute Gallery Module - Outputs
# ============================================================================

output "gallery_id" {
  description = "Resource ID of the Azure Compute Gallery (created or existing)"
  value       = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].id : var.existing_gallery_id
}

output "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  value       = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].name : data.azurerm_shared_image_gallery.existing[0].name
}

output "gallery_location" {
  description = "Azure region of the gallery"
  value       = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].location : data.azurerm_shared_image_gallery.existing[0].location
}

output "gallery_unique_name" {
  description = "Unique name of the gallery (same as gallery_name)"
  value       = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].unique_name : data.azurerm_shared_image_gallery.existing[0].unique_name
}

output "gallery_resource_group_name" {
  description = "Resource group name where the gallery is located"
  value       = var.create_gallery ? azurerm_shared_image_gallery.gallery[0].resource_group_name : data.azurerm_shared_image_gallery.existing[0].resource_group_name
}

output "create_gallery" {
  description = "Indicates whether gallery was created (true) or existing was used (false)"
  value       = var.create_gallery
}
