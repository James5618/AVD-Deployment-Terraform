# ============================================================================
# Gallery Image Definition Module - Outputs
# ============================================================================

output "image_definition_id" {
  description = "Resource ID of the image definition. Use this as input for image version creation."
  value       = azurerm_shared_image.image_definition.id
}

output "image_definition_name" {
  description = "Name of the image definition"
  value       = azurerm_shared_image.image_definition.name
}

output "gallery_name" {
  description = "Name of the gallery containing this image definition"
  value       = azurerm_shared_image.image_definition.gallery_name
}

output "resource_group_name" {
  description = "Resource group name where the image definition is located"
  value       = azurerm_shared_image.image_definition.resource_group_name
}

output "location" {
  description = "Azure region of the image definition"
  value       = azurerm_shared_image.image_definition.location
}

output "os_type" {
  description = "Operating system type (Windows or Linux)"
  value       = azurerm_shared_image.image_definition.os_type
}

output "hyper_v_generation" {
  description = "Hyper-V generation (V1 or V2)"
  value       = azurerm_shared_image.image_definition.hyper_v_generation
}

output "identifier" {
  description = "Image identifier (publisher/offer/sku)"
  value = {
    publisher = azurerm_shared_image.image_definition.identifier[0].publisher
    offer     = azurerm_shared_image.image_definition.identifier[0].offer
    sku       = azurerm_shared_image.image_definition.identifier[0].sku
  }
}

output "architecture" {
  description = "CPU architecture (x64 or Arm64)"
  value       = azurerm_shared_image.image_definition.architecture
}

# output "os_state" {
#   description = "OS state (Generalized or Specialized)"
#   value       = null  # os_state attribute not available in current provider version
# }

output "full_path" {
  description = "Full path reference for the image definition (gallery/definition format)"
  value       = "${azurerm_shared_image.image_definition.gallery_name}/${azurerm_shared_image.image_definition.name}"
}
