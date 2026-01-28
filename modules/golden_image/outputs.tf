# ============================================================================
# Golden Image Module - Outputs
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# AZURE COMPUTE GALLERY
# ─────────────────────────────────────────────────────────────────────────────

output "gallery_id" {
  description = "Resource ID of the Azure Compute Gallery (Shared Image Gallery)"
  value       = var.enabled ? azurerm_shared_image_gallery.gallery[0].id : null
}

output "gallery_name" {
  description = "Name of the Azure Compute Gallery"
  value       = var.enabled ? azurerm_shared_image_gallery.gallery[0].name : null
}

output "gallery_unique_name" {
  description = "Globally unique name of the gallery"
  value       = var.enabled ? azurerm_shared_image_gallery.gallery[0].unique_name : null
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE DEFINITION
# ─────────────────────────────────────────────────────────────────────────────

output "image_definition_id" {
  description = "Resource ID of the image definition. Use this to reference the image in VM deployments."
  value       = var.enabled ? azurerm_shared_image.avd_image[0].id : null
}

output "image_definition_name" {
  description = "Name of the image definition"
  value       = var.enabled ? azurerm_shared_image.avd_image[0].name : null
}

output "image_identifier" {
  description = "Full image identifier (publisher:offer:sku)"
  value = var.enabled ? "${azurerm_shared_image.avd_image[0].identifier[0].publisher}:${azurerm_shared_image.avd_image[0].identifier[0].offer}:${azurerm_shared_image.avd_image[0].identifier[0].sku}" : null
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE VERSION (After Build)
# ─────────────────────────────────────────────────────────────────────────────

output "image_version_id" {
  description = "Pinned gallery image version ID for session host deployment. Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{gallery}/images/{image}/versions/{version}"
  value       = var.enabled ? "${azurerm_shared_image.avd_image[0].id}/versions/${var.image_version}" : null
}

output "gallery_image_version_id" {
  description = "Alias for image_version_id. Pinned version reference for production deployments."
  value       = var.enabled ? "${azurerm_shared_image.avd_image[0].id}/versions/${var.image_version}" : null
}

output "latest_image_reference" {
  description = "Floating 'latest' image version reference. Use this to always deploy the newest image version."
  value       = var.enabled ? "${azurerm_shared_image.avd_image[0].id}/versions/latest" : null
}

output "image_version_reference" {
  description = "(DEPRECATED: Use image_version_id) Image version reference for VM deployment"
  value       = var.enabled ? "${azurerm_shared_image.avd_image[0].id}/versions/${var.image_version}" : null
}

output "latest_image_version_reference" {
  description = "(DEPRECATED: Use latest_image_reference) Reference to use 'latest' image version"
  value       = var.enabled ? "${azurerm_shared_image.avd_image[0].id}/versions/latest" : null
}

output "current_image_version" {
  description = "Current image version being built (from variables)"
  value       = var.image_version
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE BUILDER TEMPLATE
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: These outputs are disabled because azurerm_image_builder_template resource
# is not available in azurerm provider 3.x. See modules/golden_image/main.tf for
# information on enabling Image Builder support.

output "template_id" {
  description = "Resource ID of the Azure Image Builder template"
  value       = null  # Disabled - azurerm_image_builder_template requires provider >= 4.0
}

output "template_name" {
  description = "Name of the Image Builder template. Use this to trigger builds via Azure CLI/PowerShell."
  value       = null  # Disabled - azurerm_image_builder_template requires provider >= 4.0
}

# ─────────────────────────────────────────────────────────────────────────────
# MANAGED IDENTITY
# ─────────────────────────────────────────────────────────────────────────────

output "aib_identity_id" {
  description = "Resource ID of the managed identity used by Azure Image Builder"
  value       = var.enabled ? azurerm_user_assigned_identity.aib[0].id : null
}

output "aib_identity_principal_id" {
  description = "Principal ID (object ID) of the managed identity. Use for RBAC assignments."
  value       = var.enabled ? azurerm_user_assigned_identity.aib[0].principal_id : null
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILD TRIGGER COMMANDS
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: These commands are disabled because Image Builder template is not deployed.
# After enabling Image Builder (see main.tf), update these with actual template name.

output "build_command_cli" {
  description = "Azure CLI command to trigger image build"
  value = var.enabled ? "# Image Builder template not deployed - see modules/golden_image/main.tf" : null
}

output "build_command_powershell" {
  description = "PowerShell command to trigger image build"
  value = var.enabled ? "# Image Builder template not deployed - see modules/golden_image/main.tf" : null
}

# ─────────────────────────────────────────────────────────────────────────────
# SESSION HOST DEPLOYMENT REFERENCE
# ─────────────────────────────────────────────────────────────────────────────

output "session_host_image_reference" {
  description = "Image reference to use in session-hosts module for deploying from golden image"
  value = var.enabled ? {
    id = "${azurerm_shared_image.avd_image[0].id}/versions/latest"
  } : null
}

output "base_image_info" {
  description = "Base marketplace image information"
  value = {
    publisher = var.base_image_publisher
    offer     = var.base_image_offer
    sku       = var.base_image_sku
    version   = var.base_image_version
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DEPLOYMENT INSTRUCTIONS
# ─────────────────────────────────────────────────────────────────────────────

output "deployment_instructions" {
  description = "Quick reference for deploying session hosts with this golden image"
  value = var.enabled ? "See module outputs: build_command_cli, build_command_powershell, image_version_id, latest_image_reference" : "Golden image module is disabled. Set enable_golden_image = true to create image builder infrastructure."
}
