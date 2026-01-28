# ============================================================================
# Azure Image Builder Module - Golden Image for AVD
# ============================================================================
# This module provisions:
# - Azure Compute Gallery (Shared Image Gallery)
# - Image Definition (Windows 11/10 multi-session)
# - Image Template with Azure Image Builder
# - Customization scripts (extensible)
# - Managed identity for AIB service
#
# Azure Image Builder (AIB) automates the creation of custom VM images:
# 1. Starts from marketplace base image (Windows 11/10 multi-session + M365)
# 2. Applies customizations (scripts, packages, updates)
# 3. Syspreps and generalizes the image
# 4. Publishes to Azure Compute Gallery
# 5. Replicates to multiple regions (optional)
#
# Cost: 
# - AIB build: ~$1-3 per build (temp VMs, storage)
# - Compute Gallery: FREE (storage charged separately ~$0.10/GB/month)
# - Image storage: ~$5-15/month for 127GB image with 1 region
# ============================================================================

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Current Deployment Context
# ─────────────────────────────────────────────────────────────────────────────
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# Azure Compute Gallery (Shared Image Gallery)
# ─────────────────────────────────────────────────────────────────────────────
# Central repository for custom images. Images are versioned and can be
# replicated to multiple regions for faster VM deployments.
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_shared_image_gallery" "gallery" {
  count = var.enabled ? 1 : 0

  name                = var.gallery_name
  resource_group_name = var.resource_group_name
  location            = var.location
  description         = "Azure Compute Gallery for AVD golden images"

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Image Definition - Defines image properties and supported configurations
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_shared_image" "avd_image" {
  count = var.enabled ? 1 : 0

  name                = var.image_definition_name
  gallery_name        = azurerm_shared_image_gallery.gallery[0].name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  hyper_v_generation  = var.hyper_v_generation

  identifier {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
  }

  description = "Custom AVD golden image with pre-installed applications and configurations"

  # Recommended settings for AVD multi-session
  specialized = false # Generalized image (Sysprep applied)

  tags = var.tags
}

# ─────────────────────────────────────────────────────────────────────────────
# Managed Identity for Azure Image Builder
# ─────────────────────────────────────────────────────────────────────────────
# AIB needs permissions to:
# - Read source marketplace image
# - Create temporary VMs and disks
# - Write to Azure Compute Gallery
# ─────────────────────────────────────────────────────────────────────────────
resource "azurerm_user_assigned_identity" "aib" {
  count = var.enabled ? 1 : 0

  name                = "${var.gallery_name}-aib-identity"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

# Grant Contributor role to resource group (AIB needs to create temp resources)
resource "azurerm_role_assignment" "aib_contributor" {
  count = var.enabled ? 1 : 0

  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.aib[0].principal_id
}

# Wait for RBAC to propagate
resource "time_sleep" "rbac_propagation" {
  count = var.enabled ? 1 : 0

  depends_on = [azurerm_role_assignment.aib_contributor]

  create_duration = "60s"
}

# ─────────────────────────────────────────────────────────────────────────────
# Azure Image Builder Template
# ─────────────────────────────────────────────────────────────────────────────
# AZURE IMAGE BUILDER TEMPLATE
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: azurerm_image_builder_template requires azurerm provider >= 4.0 or azapi provider
# Current version (3.x) does not support this resource type.
# 
# OPTIONS TO ENABLE:
# 1. Upgrade to azurerm provider 4.x:
#    version = "~> 4.0"
# 2. Use azapi provider for Image Builder:
#    Add to required_providers: azapi = { source = "Azure/azapi", version = "~> 1.0" }
# 3. Use Azure CLI/Portal to create Image Builder templates manually
#
# For now, this resource is commented out to allow deployment.
# ─────────────────────────────────────────────────────────────────────────────

/*
resource "azurerm_image_builder_template" "avd_template" {
  count = var.enabled ? 1 : 0

  name                = var.image_template_name
  resource_group_name = var.resource_group_name
  location            = var.location

  # Managed identity for AIB service
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aib[0].id
    ]
  }

  # ───────────────────────────────────────────────────────────────────────────
  # SOURCE - Marketplace base image
  # ───────────────────────────────────────────────────────────────────────────
  source {
    type      = "PlatformImage"
    publisher = var.base_image_publisher
    offer     = var.base_image_offer
    sku       = var.base_image_sku
    version   = var.base_image_version
  }

  # ───────────────────────────────────────────────────────────────────────────
  # CUSTOMIZATIONS - Apply scripts and configurations
  # ───────────────────────────────────────────────────────────────────────────
  
  # Windows Update (recommended for golden images)
  dynamic "customize" {
    for_each = var.install_windows_updates ? [1] : []
    content {
      type                      = "WindowsUpdate"
      search_criteria           = "IsInstalled=0"
      filters                   = ["exclude:$_.Title -like '*Preview*'"]
      update_limit              = 1000
    }
  }

  # Install PowerShell modules (e.g., Az, FSLogix)
  dynamic "customize" {
    for_each = var.powershell_modules
    content {
      type        = "PowerShell"
      name        = "Install-${customize.value}"
      inline      = [
        "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force",
        "Install-Module -Name ${customize.value} -Force -AllowClobber -Scope AllUsers"
      ]
      run_as_system = true
    }
  }

  # Custom PowerShell scripts (inline)
  dynamic "customize" {
    for_each = var.inline_scripts
    content {
      type          = "PowerShell"
      name          = "Custom-Script-${customize.key}"
      inline        = customize.value
      run_as_system = true
    }
  }

  # Custom PowerShell scripts (from URI)
  dynamic "customize" {
    for_each = var.script_uris
    content {
      type          = "PowerShell"
      name          = "Script-${customize.key}"
      script_uri    = customize.value
      run_as_system = true
    }
  }

  # Install applications via Chocolatey (optional)
  dynamic "customize" {
    for_each = length(var.chocolatey_packages) > 0 ? [1] : []
    content {
      type          = "PowerShell"
      name          = "Install-Chocolatey"
      inline        = [
        "Set-ExecutionPolicy Bypass -Scope Process -Force",
        "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
        "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
      ]
      run_as_system = true
    }
  }

  dynamic "customize" {
    for_each = var.chocolatey_packages
    content {
      type          = "PowerShell"
      name          = "Install-${customize.value}"
      inline        = ["choco install ${customize.value} -y"]
      run_as_system = true
    }
  }

  # Windows Restart (if needed after updates/installations)
  dynamic "customize" {
    for_each = var.restart_after_customization ? [1] : []
    content {
      type                 = "WindowsRestart"
      restart_check_command = "echo 'Reboot complete'"
      restart_timeout      = "10m"
    }
  }

  # Final cleanup and optimization
  dynamic "customize" {
    for_each = var.run_cleanup_script ? [1] : []
    content {
      type          = "PowerShell"
      name          = "Cleanup-Image"
      inline        = [
        "# Clear temp files",
        "Remove-Item -Path $env:TEMP\\* -Recurse -Force -ErrorAction SilentlyContinue",
        "Remove-Item -Path C:\\Windows\\Temp\\* -Recurse -Force -ErrorAction SilentlyContinue",
        "# Clear Windows Update cache",
        "Stop-Service wuauserv",
        "Remove-Item -Path C:\\Windows\\SoftwareDistribution\\Download\\* -Recurse -Force -ErrorAction SilentlyContinue",
        "Start-Service wuauserv",
        "# Clear event logs",
        "wevtutil el | Foreach-Object {wevtutil cl $_}",
        "Write-Host 'Image cleanup complete'"
      ]
      run_as_system = true
    }
  }

  # Sysprep (generalize) - ALWAYS LAST STEP
  # AIB handles Sysprep automatically, but we can customize if needed
  # The image will be generalized before publishing to gallery

  # ───────────────────────────────────────────────────────────────────────────
  # DISTRIBUTE - Publish to Azure Compute Gallery
  # ───────────────────────────────────────────────────────────────────────────
  distribute {
    type                   = "SharedImage"
    gallery_image_id       = azurerm_shared_image.avd_image[0].id
    run_output_name        = "${var.image_definition_name}-${var.image_version}"
    artifact_tags          = merge(var.tags, { ImageVersion = var.image_version })
    replication_regions    = var.replication_regions
    storage_account_type   = var.gallery_image_storage_account_type

    # Exclude from latest version if this is a test build
    exclude_from_latest = var.exclude_from_latest
  }

  # ───────────────────────────────────────────────────────────────────────────
  # BUILD CONFIGURATION
  # ───────────────────────────────────────────────────────────────────────────
  vm_size = var.build_vm_size

  # Build timeout (default: 4 hours, increase for large customizations)
  build_timeout_in_minutes = var.build_timeout_minutes

  tags = merge(var.tags, {
    ImageVersion = var.image_version
    BaseImage    = "${var.base_image_publisher}:${var.base_image_offer}:${var.base_image_sku}"
  })

  depends_on = [
    time_sleep.rbac_propagation,
    azurerm_shared_image.avd_image
  ]
}
*/

# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANT: Image Builder Template Disabled
# ─────────────────────────────────────────────────────────────────────────────
# The azurerm_image_builder_template resource is commented out due to provider
# version constraints. To use Azure Image Builder:
#
# Option 1 - Upgrade azurerm provider:
#   terraform {
#     required_providers {
#       azurerm = {
#         source  = "hashicorp/azurerm"
#         version = "~> 4.0"
#       }
#     }
#   }
#
# Option 2 - Use azapi provider:
#   terraform {
#     required_providers {
#       azapi = {
#         source  = "Azure/azapi"
#         version = "~> 1.0"
#       }
#     }
#   }
#   
#   Then use azapi_resource for Image Builder template.
#
# Option 3 - Manual creation:
#   Use Azure CLI or Portal to create and manage Image Builder templates:
#   
#   Azure CLI:
#     az image builder create \
#       --resource-group avd-dev-rg \
#       --name avd-golden-image-template \
#       --image-source MicrosoftWindowsDesktop:office-365:win11-22h2-avd-m365:latest \
#       --managed-image-destinations image_1=westus
#   
#   PowerShell:
#     New-AzImageBuilderTemplate -ResourceGroupName "avd-dev-rg" -Name "avd-golden-image-template"
#
# After enabling Image Builder, trigger builds with:
#   az image builder run --resource-group <rg> --name <template-name>
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANT: Manual Build Trigger Required
# ─────────────────────────────────────────────────────────────────────────────
# After template creation, you must manually trigger the build:
# 
# Azure CLI:
#   az image builder run \
#     --resource-group avd-dev-rg \
#     --name avd-golden-image-template
#
# PowerShell:
#   Start-AzImageBuilderTemplate -ResourceGroupName "avd-dev-rg" -Name "avd-golden-image-template"
#
# Azure Portal:
#   Image Builder → Templates → [template-name] → Run
#
# Build time: 30-90 minutes depending on customizations and Windows updates
# ─────────────────────────────────────────────────────────────────────────────
