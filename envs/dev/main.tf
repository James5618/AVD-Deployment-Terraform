# ============================================================================
# Development Environment - Main Configuration
# ============================================================================

terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

provider "azuread" {
}

# ============================================================================
# DATA SOURCES - Current Azure Configuration
# ============================================================================

data "azurerm_client_config" "current" {
}

# ============================================================================
# USER CONFIG - All user-editable configuration consolidated here
# ============================================================================
# IMPORTANT: These locals reference variables from variables.tf
# 
# To customize your deployment:
# 1. Copy terraform.tfvars.example to terraform.tfvars
# 2. Edit terraform.tfvars with your values
# 3. All variables have defaults in variables.tf
#
# ─────────────────────────────────────────────────────────────────────────────
# VERIFICATION: Legacy Module Cleanup
# ─────────────────────────────────────────────────────────────────────────────
# To verify no legacy modules remain:
#   grep -r "module.gallery_import\|module.manual_image_import" envs/dev/*.tf
#   Should return: No matches
#
# Manual gallery strategy uses only these modules:
#   - module.manual_compute_gallery
#   - module.manual_image_definition  
#   - module.manual_gallery_import
#
# Verify single image path:
#   terraform validate   # Should pass
#   terraform plan       # Should show only one gallery_image_version_id path
# ============================================================================

locals {
  # ---------------------------------------------------------------------------
  # Feature Toggles - Enable/Disable Optional Modules
  # ---------------------------------------------------------------------------
  feature_toggles = {
    enable_golden_image           = var.enable_golden_image              # Azure Image Builder for golden images
    enable_manual_gallery_import  = var.enable_manual_gallery_import    # Import manually prepared images to gallery
    enable_scaling_plan           = var.enable_scaling_plan              # Auto-scaling (60-80% cost savings)
    enable_conditional_access     = var.enable_conditional_access        # Entra ID security policies (MFA, device compliance)
    enable_backup                 = false                                # Azure Backup (Recovery Services Vault)
    enable_logging                = false                                # Log Analytics & VM Insights
  }

  # ---------------------------------------------------------------------------
  # Image Strategy - Unified session host image selection
  # ---------------------------------------------------------------------------
  image_strategy = var.session_host_image_strategy

  # ---------------------------------------------------------------------------
  # Image Config - Custom image import configuration
  # ---------------------------------------------------------------------------
  # For manual_gallery strategy: requires enable_manual_gallery_import=true
  # and appropriate source image details (source_managed_image_id OR source_vhd_uri)
  image_config = {
    strategy            = local.image_strategy
    enable              = var.enable_manual_gallery_import
    source_type         = var.image_source_type
    managed_image_id    = var.source_managed_image_id
    vhd_uri             = var.source_vhd_uri
    version             = var.image_version
    gallery_name        = var.gallery_name != "" ? var.gallery_name : "${var.project_name}_${var.environment}_gallery"
    gallery_rg_name     = var.gallery_rg_name
    create_gallery      = var.gallery_rg_name == ""
    definition_name     = var.image_definition_name
    publisher           = var.image_publisher
    offer               = var.image_offer
    sku                 = var.image_sku
    os_type             = var.os_type
    hyper_v_generation  = var.hyper_v_generation
    pin_version         = var.pin_image_version_id
    replication_regions = length(var.image_replication_regions) > 0 ? var.image_replication_regions : [var.location]
    exclude_from_latest = var.exclude_from_latest
  }

  # ---------------------------------------------------------------------------
  # Scaling Config - Auto-scaling schedule configuration
  # ---------------------------------------------------------------------------
  scaling_config = {
    # Weekday schedule (Monday-Friday)
    weekday_ramp_up_start                = var.weekday_ramp_up_start_time
    weekday_peak_start                   = var.weekday_peak_start_time
    weekday_ramp_down_start              = var.weekday_ramp_down_start_time
    weekday_off_peak_start               = var.weekday_off_peak_start_time
    # Weekend schedule (Saturday-Sunday)
    weekend_ramp_up_start                = "10:00"
    weekend_peak_start                   = "11:00"
    weekend_ramp_down_start              = "16:00"
    weekend_off_peak_start               = "18:00"
    # Capacity thresholds
    ramp_up_capacity_threshold           = var.weekday_ramp_up_capacity_threshold
    ramp_down_capacity_threshold         = var.weekday_ramp_down_capacity_threshold
    ramp_up_min_hosts_percent            = var.weekday_ramp_up_min_hosts_percent
    ramp_down_min_hosts_percent          = var.weekday_ramp_down_min_hosts_percent
    # Behavior settings
    timezone                             = var.scaling_plan_timezone
    force_logoff_users                   = var.scaling_force_logoff_users
    wait_time_minutes                    = var.scaling_wait_time_minutes
    notification_message                 = var.scaling_notification_message
  }

  # ---------------------------------------------------------------------------
  # DC Config - Domain Controller configuration
  # ---------------------------------------------------------------------------
  dc_config = {
    vm_size              = var.dc_vm_size
    os_disk_type         = var.dc_os_disk_type
    os_disk_size_gb      = var.dc_os_disk_size_gb
    private_ip           = var.dc_private_ip
    enable_public_ip     = var.dc_enable_public_ip
    domain_name          = var.domain_name
    domain_netbios_name  = split(".", var.domain_name)[0]
    avd_ou_name          = var.avd_ou_name
    admin_username       = var.domain_admin_username
  }

  # ---------------------------------------------------------------------------
  # Session Hosts Config - Session host VM configuration
  # ---------------------------------------------------------------------------
  session_hosts_config = {
    count                       = var.session_host_count
    vm_size                     = var.session_host_vm_size
    os_disk_type                = var.session_host_os_disk_type
    name_prefix                 = "${var.environment}-avd-sh"
    local_admin_username        = var.session_host_local_admin_username
    timezone                    = var.timezone
    marketplace_image_reference = var.marketplace_image_reference
  }

  # ---------------------------------------------------------------------------
  # AVD Config - Azure Virtual Desktop configuration
  # ---------------------------------------------------------------------------
  avd_config = {
    hostpool_type               = var.hostpool_type
    load_balancer_type          = var.load_balancer_type
    maximum_sessions_allowed    = var.maximum_sessions_allowed
    start_vm_on_connect         = var.start_vm_on_connect
    avd_users                   = var.avd_users
    registration_token_ttl_hours = var.registration_token_ttl_hours
    workspace_friendly_name     = var.workspace_friendly_name
    hostpool_friendly_name      = var.hostpool_friendly_name
    app_group_friendly_name     = var.app_group_friendly_name
  }

  # ---------------------------------------------------------------------------
  # Storage Config - FSLogix storage configuration
  # ---------------------------------------------------------------------------
  storage_config = {
    account_tier             = var.storage_account_tier
    replication_type         = var.storage_replication_type
    account_kind             = var.storage_account_kind
    file_share_quota_gb      = var.fslogix_share_quota_gb
    enable_private_endpoint  = var.enable_storage_private_endpoint
    enable_ad_authentication = var.enable_ad_authentication_storage
  }

  # ---------------------------------------------------------------------------
  # Logging Config - Log Analytics and monitoring configuration
  # ---------------------------------------------------------------------------
  logging_config = {
    workspace_name           = var.log_analytics_workspace_name != "" ? var.log_analytics_workspace_name : "${var.project_name}-${var.environment}-logs"
    retention_days           = var.log_analytics_retention_days
    enable_vm_insights       = var.enable_vm_insights
    enable_storage_diagnostics = var.enable_storage_diagnostics
    enable_nsg_diagnostics   = var.enable_nsg_diagnostics
  }

  # ---------------------------------------------------------------------------
  # Backup Config - Azure Backup configuration
  # ---------------------------------------------------------------------------
  backup_config = {
    recovery_vault_name       = var.recovery_vault_name != "" ? var.recovery_vault_name : "${var.project_name}-${var.environment}-backup"
    vm_retention_days         = var.vm_backup_retention_days
    vm_retention_weeks        = var.vm_backup_retention_weeks
    backup_time               = var.backup_time
    backup_timezone           = var.timezone
    backup_session_hosts      = var.backup_session_hosts
    fslogix_backup_enabled    = var.fslogix_backup_enabled
    fslogix_retention_days    = var.fslogix_backup_retention_days
    enable_soft_delete        = true
  }

  # ---------------------------------------------------------------------------
  # Update Management Config - Automated patching configuration
  # ---------------------------------------------------------------------------
  update_management_config = {
    maintenance_config_prefix               = "${var.project_name}-${var.environment}-maint"
    dc_start_datetime                       = var.dc_maintenance_start_datetime
    dc_duration                             = "03:00"
    dc_recurrence                           = var.dc_maintenance_recurrence
    dc_reboot_setting                       = var.dc_reboot_setting
    session_host_start_datetime             = var.session_host_maintenance_start_datetime
    session_host_duration                   = var.session_host_maintenance_duration
    session_host_recurrence                 = var.session_host_maintenance_recurrence
    session_host_reboot_setting             = var.session_host_reboot_setting
    maintenance_timezone                    = var.timezone
    kb_exclusions                           = var.patch_kb_exclusions
  }

  # ---------------------------------------------------------------------------
  # Cost Management Config - Budget and alert configuration
  # ---------------------------------------------------------------------------
  cost_management_config = {
    budget_name            = "${var.project_name}-${var.environment}-budget"
    monthly_budget_amount  = var.monthly_budget_amount
    alert_emails           = var.budget_alert_emails
    alert_threshold_1      = var.budget_alert_threshold_1
    alert_threshold_2      = var.budget_alert_threshold_2
    alert_threshold_3      = var.budget_alert_threshold_3
  }

  # ---------------------------------------------------------------------------
  # Golden Image Config - Custom image build configuration
  # ---------------------------------------------------------------------------
  golden_image_config = {
    version                  = var.golden_image_version
    base_sku                 = var.golden_image_base_sku
    install_windows_updates  = var.golden_image_install_windows_updates
    chocolatey_packages      = var.golden_image_chocolatey_packages
    custom_scripts           = var.golden_image_custom_scripts
    replication_regions      = var.golden_image_replication_regions
    pin_version              = var.pin_image_version_id  # Reuse same pinning setting
  }

  # ---------------------------------------------------------------------------
  # Key Vault Config - Secure password storage configuration
  # ---------------------------------------------------------------------------
  key_vault_config = {
    enabled                = var.enable_key_vault
    auto_generate_passwords = var.auto_generate_passwords
    purge_protection       = var.key_vault_purge_protection
    name                   = var.key_vault_name
  }

  # ---------------------------------------------------------------------------
  # Conditional Access Config - Entra ID security policies
  # ---------------------------------------------------------------------------
  conditional_access_config = {
    require_mfa                 = var.ca_require_mfa
    require_compliant_device    = var.ca_require_compliant_device
    block_legacy_auth           = var.ca_block_legacy_auth
    additional_target_group_ids = var.ca_additional_target_group_ids
    break_glass_group_ids       = var.ca_break_glass_group_ids
    mfa_policy_state            = var.ca_mfa_policy_state
    device_policy_state         = var.ca_device_policy_state
    legacy_auth_policy_state    = var.ca_legacy_auth_policy_state
  }

  # ---------------------------------------------------------------------------
  # Naming - Resource names (auto-generated)
  # ---------------------------------------------------------------------------
  naming = {
    resource_group_name  = "${var.project_name}-${var.environment}-rg"
    vnet_name            = "${var.project_name}-${var.environment}-vnet"
    dc_name              = "${upper(var.environment)}-DC01"
    workspace_name       = "${var.project_name}-${var.environment}-workspace"
    hostpool_name        = "${var.project_name}-${var.environment}-hp"
    app_group_name       = "${var.project_name}-${var.environment}-dag"
    session_host_prefix  = "${var.environment}-avd-sh"
    storage_account_name = replace("${lower(var.project_name)}${lower(var.environment)}fslogix", "-", "")
  }

  # ---------------------------------------------------------------------------
  # Tags - Common tags applied to all resources
  # ---------------------------------------------------------------------------
  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Location    = var.location
    }
  )
}

# ============================================================================
# RESOURCE GROUP
# ============================================================================

resource "azurerm_resource_group" "rg" {
  name     = local.naming.resource_group_name
  location = var.location
  tags     = local.tags
}

# ============================================================================
# OPTIONAL: Azure Key Vault Integration for Sensitive Values
# ============================================================================
# Uncomment the blocks below to retrieve passwords from Azure Key Vault
# instead of storing them in terraform.tfvars.
#
# Prerequisites:
# 1. Create Azure Key Vault and store secrets
# 2. Grant Terraform service principal access
# 3. Uncomment the data sources below
# ============================================================================

# # Reference existing Key Vault
# data "azurerm_key_vault" "vault" {
#   name                = "avd-keyvault-dev"
#   resource_group_name = "security-rg"
# }
#
# # Retrieve domain admin password from Key Vault
# data "azurerm_key_vault_secret" "domain_admin_password" {
#   name         = "domain-admin-password"
#   key_vault_id = data.azurerm_key_vault.vault.id
# }
#
# # Retrieve session host admin password from Key Vault
# data "azurerm_key_vault_secret" "session_host_admin_password" {
#   name         = "session-host-admin-password"
#   key_vault_id = data.azurerm_key_vault.vault.id
# }

# ============================================================================
# STEP 1: Networking Module (VNet, Subnets, NSGs)
# ============================================================================
# Created first without DNS servers to avoid circular dependency.
# DNS servers will be updated after Domain Controller is deployed.
# ============================================================================

module "networking" {
  source = "../../modules/networking"

  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  vnet_name               = local.naming.vnet_name
  vnet_address_space      = var.vnet_address_space
  dc_subnet_prefix        = var.dc_subnet_prefix
  avd_subnet_prefix       = var.avd_subnet_prefix
  storage_subnet_prefix   = var.storage_subnet_prefix
  
  # DNS servers initially empty - will be updated after DC deployment
  dns_servers             = []
  
  create_resource_group   = false  # We create it above
  
  tags = local.tags
}

# ============================================================================
# STEP 2: Key Vault Module (Secure Password Storage)
# ============================================================================
# Deploys Azure Key Vault to securely store domain admin and local admin
# passwords. This eliminates plaintext passwords from terraform.tfvars.
# Passwords are auto-generated (24 chars) or manually provided.
#
# Security Features:
# - RBAC authorization (no legacy access policies)
# - Soft delete enabled (90-day recovery period)
# - Optional purge protection (production only)
# - Audit logging ready (configure in logging module)
#
# Cost: ~$1-5/month (minimal - mostly secret operations)
# ============================================================================

# Generate random suffix for globally unique Key Vault name
resource "random_string" "kv_suffix" {
  count   = local.key_vault_config.enabled && local.key_vault_config.name == "" ? 1 : 0
  length  = 6
  special = false
  upper   = false
}

module "key_vault" {
  count  = local.key_vault_config.enabled ? 1 : 0
  source = "../../modules/key_vault"

  key_vault_name      = local.key_vault_config.name != "" ? local.key_vault_config.name : "${var.project_name}-${var.environment}-kv-${random_string.kv_suffix[0].result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Password Configuration
  auto_generate_passwords = local.key_vault_config.auto_generate_passwords
  domain_admin_password   = local.key_vault_config.auto_generate_passwords ? "" : var.domain_admin_password
  local_admin_password    = local.key_vault_config.auto_generate_passwords ? "" : var.session_host_local_admin_password

  # Security Settings
  purge_protection_enabled      = local.key_vault_config.purge_protection
  public_network_access_enabled = true  # Set to false in production (requires private endpoint)
  network_default_action        = "Allow"

  # Additional secrets (optional - for service principals, API keys, etc.)
  additional_secrets = {}

  tags = local.tags

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================================
# STEP 3: Domain Controller Module (AD DS + OU Creation)
# ============================================================================
# Deploys Windows Server VM, installs AD DS, creates AVD OU.
# Must complete before session hosts can domain join.
# NOW USES KEY VAULT PASSWORDS (if enabled) instead of plaintext variables.
# ============================================================================

module "domain_controller" {
  source = "../../modules/domain-controller"

  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  dc_name                  = local.naming.dc_name
  dc_vm_size               = local.dc_config.vm_size
  os_disk_type             = local.dc_config.os_disk_type
  os_disk_size_gb          = local.dc_config.os_disk_size_gb
  subnet_id                = module.networking.dc_subnet_id
  dc_private_ip            = local.dc_config.private_ip
  admin_username           = local.dc_config.admin_username
  admin_password           = local.key_vault_config.enabled ? module.key_vault[0].domain_admin_password : var.domain_admin_password
  
  # Active Directory Configuration
  domain_name              = local.dc_config.domain_name
  netbios_name             = local.dc_config.domain_netbios_name
  safe_mode_admin_password = local.key_vault_config.enabled ? module.key_vault[0].domain_admin_password : var.domain_admin_password
  avd_ou_name              = local.dc_config.avd_ou_name
  
  tags = local.tags

  depends_on = [
    module.networking,
    module.key_vault
  ]
}

# ============================================================================
# STEP 4: Update VNet DNS Servers (Point to Domain Controller)
# ============================================================================
# After DC is deployed and AD DS is installed, update VNet DNS to point
# to the Domain Controller. This ensures session hosts can resolve domain
# names and successfully domain join.
# ============================================================================

resource "null_resource" "update_vnet_dns" {
  # Trigger this resource when DC IP changes or DC deployment completes
  triggers = {
    dc_vm_id     = module.domain_controller.dc_vm_id
    dc_ip        = local.dc_config.private_ip
    vnet_id      = module.networking.vnet_id
  }

  # Update VNet DNS servers using Azure CLI
  provisioner "local-exec" {
    command = <<-EOT
      az network vnet update \
        --resource-group ${azurerm_resource_group.rg.name} \
        --name ${local.naming.vnet_name} \
        --dns-servers ${local.dc_config.private_ip}
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [
    module.domain_controller
  ]
}

# ============================================================================
# STEP 5: Golden Image Module (Azure Image Builder + Compute Gallery)
# ============================================================================
# OPTIONAL: Build custom golden images for AVD session hosts.
# Eliminates need to configure each session host individually.
# 
# Golden image includes:
# - Base Windows 11/10 multi-session + M365 Apps
# - Latest Windows Updates
# - Pre-installed applications (Chrome, 7zip, etc.)
# - Custom configurations and registry settings
# 
# Benefits:
# - Faster session host deployment (5-10 min vs 30-60 min)
# - Consistent configuration across all session hosts
# - Reduced post-deployment scripting
# 
# Cost: ~$1-3 per build + $5-15/month storage
# Build time: 30-90 minutes after terraform apply
# 
# IMPORTANT: After terraform apply, manually trigger build:
#   az image builder run --resource-group avd-dev-rg --name avd-golden-image-template
#
# CONDITIONAL: Only created if feature_toggles.enable_golden_image = true
# ============================================================================

module "golden_image" {
  count  = local.feature_toggles.enable_golden_image ? 1 : 0
  source = "../../modules/golden_image"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  # Gallery and image naming
  gallery_name          = replace("${var.project_name}${var.environment}goldengallery", "-", "")
  image_definition_name = "${var.project_name}-${var.environment}-avd-golden"
  image_template_name   = "${var.project_name}-${var.environment}-golden-template"
  image_version         = local.golden_image_config.version

  # Base marketplace image
  base_image_publisher = "MicrosoftWindowsDesktop"
  base_image_offer     = "office-365"
  base_image_sku       = local.golden_image_config.base_sku
  base_image_version   = "latest"

  # Custom image properties
  image_publisher = "MyCompany"
  image_offer     = "AVD-GoldenImage"
  image_sku       = local.golden_image_config.base_sku

  # Customizations
  install_windows_updates = local.golden_image_config.install_windows_updates
  chocolatey_packages     = local.golden_image_config.chocolatey_packages
  inline_scripts          = local.golden_image_config.custom_scripts

  # Build configuration
  build_vm_size         = "Standard_D4s_v5"
  build_timeout_minutes = 240

  # Distribution
  replication_regions              = local.golden_image_config.replication_regions
  gallery_image_storage_account_type = "Standard_LRS"
  exclude_from_latest              = false

  # Cleanup and optimization
  restart_after_customization = false
  run_cleanup_script          = true

  tags = local.tags

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================================
# STEP 5b: Gallery Import Module - Import Manually Prepared Images
# ============================================================================
# NEW: Streamlined image import workflow using image_config locals block.
# All configuration is in the image_config block at the top of this file.
#
# Import manually created and generalized images into Azure Compute Gallery.
# Useful for:
# - Migrating existing customized VMs to AVD
# - Complex configurations that can't be automated
# - One-time image imports before automating with Golden Image module
#
# Prerequisites:
# - Source VM must be generalized (sysprep for Windows)
# - Source must be either:
#   * Managed Image: Already captured from generalized VM
#   * VHD: Uploaded to Azure Storage account
#
# See README.md "Manual Golden Image Creation" section for detailed steps.
#
# CONDITIONAL: Only created if enable_manual_gallery_import = true
# ============================================================================

# ============================================================================
# STEP 5a: Compute Gallery (for manual_gallery strategy)
# ============================================================================
# Creates or references Azure Compute Gallery for manually imported images.
# Part of the modular manual_gallery_import workflow.
# ============================================================================

module "manual_compute_gallery" {
  count  = local.image_strategy == "manual_gallery" && local.image_config.enable ? 1 : 0
  source = "../../modules/compute_gallery"

  create_gallery      = local.image_config.create_gallery
  gallery_name        = local.image_config.gallery_name
  resource_group_name = local.image_config.gallery_rg_name != "" ? local.image_config.gallery_rg_name : azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  gallery_description = "Azure Compute Gallery for manually imported AVD images"
  existing_gallery_id = local.image_config.gallery_rg_name != "" && !local.image_config.create_gallery ? "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${local.image_config.gallery_rg_name}/providers/Microsoft.Compute/galleries/${local.image_config.gallery_name}" : null

  tags = merge(
    local.tags,
    {
      Purpose = "Manual Image Import Gallery"
      Module  = "compute_gallery"
    }
  )

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================================
# STEP 5b: Gallery Image Definition (for manual_gallery strategy)
# ============================================================================
# Creates image definition in the gallery. Defines OS type, generation, and
# publisher/offer/sku metadata for the imported images.
# ============================================================================

module "manual_image_definition" {
  count  = local.image_strategy == "manual_gallery" && local.image_config.enable ? 1 : 0
  source = "../../modules/gallery_image_definition"

  gallery_name                 = local.image_config.gallery_name
  gallery_resource_group_name  = local.image_config.gallery_rg_name != "" ? local.image_config.gallery_rg_name : azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  
  image_definition_name        = local.image_config.definition_name
  image_definition_description = "Manually imported custom AVD image - ${local.image_config.definition_name}"
  
  # OS Configuration
  os_type            = local.image_config.os_type
  os_state           = "Generalized"
  hyper_v_generation = local.image_config.hyper_v_generation
  
  # Publisher/Offer/SKU metadata
  publisher = local.image_config.publisher
  offer     = local.image_config.offer
  sku       = local.image_config.sku

  tags = merge(
    local.tags,
    {
      Purpose        = "Manual Image Import Definition"
      Publisher      = local.image_config.publisher
      Offer          = local.image_config.offer
      SKU            = local.image_config.sku
    }
  )

  depends_on = [module.manual_compute_gallery]
}

# ============================================================================
# STEP 5c: Manual Gallery Import (for manual_gallery strategy)
# ============================================================================
# Imports the manually created image version into the existing gallery.
# Creates only the azurerm_shared_image_version resource.
# Supports both managed_image and vhd source types.
# ============================================================================

module "manual_gallery_import" {
  count  = local.image_strategy == "manual_gallery" && local.image_config.enable ? 1 : 0
  source = "../../modules/manual_gallery_import"

  resource_group_name   = local.image_config.gallery_rg_name != "" ? local.image_config.gallery_rg_name : azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  
  # Reference existing gallery infrastructure
  gallery_name          = local.image_config.gallery_name
  image_definition_name = local.image_config.definition_name
  
  # Source Configuration
  source_type       = local.image_config.source_type
  managed_image_id  = local.image_config.managed_image_id
  source_vhd_uri    = local.image_config.vhd_uri
  os_type           = local.image_config.os_type
  hyper_v_generation = local.image_config.hyper_v_generation
  
  # Version Configuration
  image_version       = local.image_config.version
  exclude_from_latest = local.image_config.exclude_from_latest
  replication_regions = local.image_config.replication_regions
  replica_count       = 1
  storage_account_type = "Standard_LRS"

  tags = merge(
    local.tags,
    {
      Purpose        = "Manual Gallery Image Import"
      ImageVersion   = local.image_config.version
      SourceType     = local.image_config.source_type
      Strategy       = "manual_gallery"
    }
  )

  depends_on = [
    module.manual_compute_gallery,
    module.manual_image_definition
  ]
}

# ============================================================================
# STEP 6: FSLogix Storage Module (Azure Files for User Profiles)
# ============================================================================
# Deploys storage account with Azure Files share for FSLogix profiles.
# Can be deployed in parallel with AVD Core.
# ============================================================================

module "fslogix_storage" {
  source = "../../modules/fslogix_storage"

  storage_account_name    = local.naming.storage_account_name
  resource_group_name     = azurerm_resource_group.rg.name
  location                = azurerm_resource_group.rg.location
  environment             = var.environment
  
  # Storage Configuration
  storage_account_tier    = local.storage_config.account_tier
  storage_replication_type = local.storage_config.replication_type
  storage_account_kind    = local.storage_config.account_kind
  file_share_quota_gb     = local.storage_config.file_share_quota_gb
  
  # Network Security
  enable_private_endpoint     = local.storage_config.enable_private_endpoint
  private_endpoint_subnet_id  = local.storage_config.enable_private_endpoint ? module.networking.storage_subnet_id : ""
  private_dns_zone_id         = ""  # Optional: Add private DNS zone if needed
  
  # AD DS Authentication (requires manual configuration - see module README)
  enable_ad_authentication    = local.storage_config.enable_ad_authentication
  ad_domain_name              = local.dc_config.domain_name
  ad_netbios_domain_name      = local.dc_config.domain_netbios_name
  ad_forest_name              = local.dc_config.domain_name
  
  # RBAC - Role assignments handled by module
  avd_users_group_id          = ""  # Optional: Add Azure AD group object ID
  
  tags = local.tags

  depends_on = [module.networking]
}

# ============================================================================
# STEP 7: AVD Core Module (Workspace, Host Pool, Application Group)
# ============================================================================
# Deploys AVD infrastructure: workspace, host pool, desktop app group.
# Independent of domain controller, can be deployed in parallel.
# ============================================================================

module "avd_core" {
  source = "../../modules/avd_core"

  # Core Configuration
  prefix              = var.project_name
  env                 = var.environment
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # Host Pool Configuration
  host_pool_name       = local.naming.hostpool_name
  max_sessions         = local.avd_config.maximum_sessions_allowed
  load_balancer_type   = local.avd_config.load_balancer_type
  start_vm_on_connect  = local.avd_config.start_vm_on_connect
  
  # User Access (requires Azure AD group object ID)
  user_group_object_id = ""  # Optional: Add Azure AD group for AVD users
  
  # Registration Token
  registration_token_ttl_hours = local.avd_config.registration_token_ttl_hours
  
  # Friendly Names
  workspace_friendly_name  = local.avd_config.workspace_friendly_name
  host_pool_friendly_name  = local.avd_config.hostpool_friendly_name
  app_group_friendly_name  = local.avd_config.app_group_friendly_name
  
  tags = local.tags
}

# ============================================================================
# STEP 8: Session Hosts Module (Domain-Joined AVD VMs)
# ============================================================================
# Deploys Windows 11 multi-session VMs, domain joins them to the AVD OU,
# installs AVD agent, and configures FSLogix.
# 
# CRITICAL: Must wait for:
# 1. Domain Controller AD DS installation to complete
# 2. VNet DNS update to point to DC
# 3. FSLogix storage to be available
# 4. AVD host pool to be created (for registration token)
# ============================================================================

module "session_hosts" {
  source = "../../modules/session-hosts"

  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  subnet_id             = module.networking.avd_subnet_id
  vnet_dns_servers      = [local.dc_config.private_ip]
  
  # VM Configuration
  vm_count              = local.session_hosts_config.count
  vm_name_prefix        = local.session_hosts_config.name_prefix
  vm_size               = local.session_hosts_config.vm_size
  timezone              = local.session_hosts_config.timezone
  
  # Image Configuration - Strategy-Based Selection
  # Three strategies supported:
  # 1. marketplace: Use Azure Marketplace images (default Windows 11 AVD)
  # 2. aib_gallery: Use Azure Image Builder generated gallery images (via golden_image module)
  # 3. manual_gallery: Use manually prepared/imported gallery images (via manual_gallery_import module)
  #
  # Version Pinning (PRODUCTION BEST PRACTICE):
  # - Enabled: Uses specific version (e.g., .../versions/1.0.0)
  # - Disabled: Uses latest version (e.g., .../versions/latest)
  #
  # RECOMMENDED: Always pin versions in production (pin_image_version_id = true)
  # to prevent unexpected changes when new image versions are published.
  
  gallery_image_version_id = (
    local.image_strategy == "marketplace" ? null :  # Use marketplace fallback
    local.image_strategy == "aib_gallery" ? (
      local.feature_toggles.enable_golden_image ? (
        local.golden_image_config.pin_version ? module.golden_image[0].image_version_id : module.golden_image[0].latest_image_reference
      ) : null
    ) : # manual_gallery - always use modular manual_gallery_import
    local.feature_toggles.enable_manual_gallery_import ? (
      local.image_config.pin_version ? module.manual_gallery_import[0].image_version_id : module.manual_gallery_import[0].latest_image_reference
    ) : null
  )
  
  # Marketplace image reference (used when strategy is 'marketplace')
  marketplace_image_reference = local.session_hosts_config.marketplace_image_reference
  
  # Disk configuration
  os_disk_type = local.session_hosts_config.os_disk_type
  
  # Local Admin Credentials (from Key Vault if enabled)
  local_admin_username  = local.session_hosts_config.local_admin_username
  local_admin_password  = local.key_vault_config.enabled ? module.key_vault[0].local_admin_password : var.session_host_local_admin_password
  
  # Domain Join Configuration (domain admin password from Key Vault if enabled)
  domain_name           = local.dc_config.domain_name
  domain_netbios_name   = local.dc_config.domain_netbios_name
  domain_admin_username = local.dc_config.admin_username
  domain_admin_password = local.key_vault_config.enabled ? module.key_vault[0].domain_admin_password : var.domain_admin_password
  domain_ou_path        = module.domain_controller.ou_distinguished_name
  
  # AVD Registration
  hostpool_name                = module.avd_core.host_pool_name
  hostpool_registration_token  = module.avd_core.registration_token
  
  # FSLogix Configuration
  fslogix_share_path    = module.fslogix_storage.unc_path
  
  tags = local.tags

  # CRITICAL: Ensure proper deployment order to avoid race conditions
  # Image modules are implicitly waited for via the gallery_image_version_id output reference
  depends_on = [
    module.domain_controller,       # AD DS must be fully installed
    null_resource.update_vnet_dns,  # VNet DNS must point to DC
    module.fslogix_storage,         # Storage must be available
    module.avd_core,                # Host pool must exist for registration
    module.manual_compute_gallery,  # Gallery must exist (if using manual_gallery strategy)
    module.manual_image_definition, # Image definition must exist (if using manual_gallery strategy)
    module.manual_gallery_import,   # Image version must be available (if using manual_gallery strategy)
    module.golden_image             # AIB golden image (if using aib_gallery strategy)
  ]
}

# ============================================================================
# STEP 9: Logging Module (Log Analytics & Monitoring)
# ============================================================================
# Centralized logging and monitoring for the entire AVD environment:
# - Log Analytics workspace with configurable retention
# - Diagnostic settings for AVD workspace, host pool, app groups
# - Diagnostic settings for storage account and Azure Files
# - Diagnostic settings for NSGs
# - VM Insights for Domain Controller and Session Hosts
#
# CONDITIONAL: Only created if feature_toggles.enable_logging = true
# ============================================================================

module "logging" {
  count  = local.feature_toggles.enable_logging ? 1 : 0
  source = "../../modules/logging"

  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  log_analytics_workspace_name = local.logging_config.workspace_name
  log_analytics_retention_days = local.logging_config.retention_days
  
  # AVD Diagnostic Settings
  avd_workspace_id  = module.avd_core.workspace_id
  avd_hostpool_id   = module.avd_core.host_pool_id
  avd_app_group_ids = {
    desktop = module.avd_core.app_group_id
  }
  
  # Storage Diagnostic Settings
  storage_account_id = local.logging_config.enable_storage_diagnostics ? module.fslogix_storage.storage_account_id : null
  
  # Network Diagnostic Settings
  nsg_ids = local.logging_config.enable_nsg_diagnostics ? {
    dc  = module.networking.dc_nsg_id
    avd = module.networking.avd_nsg_id
  } : {}
  
  # VM Insights
  enable_vm_insights = local.logging_config.enable_vm_insights
  dc_vm_id           = module.domain_controller.dc_vm_id
  session_host_vm_ids = {
    for idx in range(local.session_hosts_config.count) :
    "${var.environment}-avd-sh-${idx + 1}" => module.session_hosts.vm_ids[idx]
  }
  
  tags = local.tags

  depends_on = [
    module.domain_controller,
    module.avd_core,
    module.fslogix_storage,
    module.session_hosts
  ]
}

# ============================================================================
# STEP 10: Backup Module (Recovery Services Vault & Backup Policies)
# ============================================================================
# Azure Backup protection for critical infrastructure:
# - Recovery Services Vault with geo-redundant storage
# - Daily VM backups for Domain Controller and Session Hosts
# - Optional Azure Files backup for FSLogix user profiles
# - Configurable retention policies (daily/weekly/monthly/yearly)
# - Soft delete protection against accidental deletion
#
# CONDITIONAL: Only created if feature_toggles.enable_backup = true
# ============================================================================

module "backup" {
  count  = local.feature_toggles.enable_backup ? 1 : 0
  source = "../../modules/backup"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  recovery_vault_name = local.backup_config.recovery_vault_name
  
  # VM Backup Configuration
  vm_backup_retention_days  = local.backup_config.vm_retention_days
  vm_backup_retention_weeks = local.backup_config.vm_retention_weeks
  vm_backup_retention_months = 0  # Set in variables.tf if needed
  vm_backup_retention_years  = 0  # Set in variables.tf if needed
  
  # Backup Schedule
  backup_time     = local.backup_config.backup_time
  backup_timezone = local.backup_config.backup_timezone
  
  # VMs to Backup
  dc_vm_id = module.domain_controller.dc_vm_id
  session_host_vm_ids = local.backup_config.backup_session_hosts ? {
    for idx in range(local.session_hosts_config.count) :
    "${var.environment}-avd-sh-${idx + 1}" => module.session_hosts.vm_ids[idx]
  } : {}
  
  # FSLogix Azure Files Backup (Optional)
  fslogix_backup_enabled        = local.backup_config.fslogix_backup_enabled
  fslogix_backup_retention_days = local.backup_config.fslogix_retention_days
  fslogix_backup_retention_weeks = 4
  storage_account_id            = local.backup_config.fslogix_backup_enabled ? module.fslogix_storage.storage_account_id : null
  fslogix_share_name            = local.backup_config.fslogix_backup_enabled ? "user-profiles" : null
  
  # Vault Configuration
  enable_soft_delete = local.backup_config.enable_soft_delete
  
  tags = local.tags

  depends_on = [
    module.domain_controller,
    module.session_hosts,
    module.fslogix_storage
  ]
}

# ============================================================================
# STEP 11: Update Management (Azure Update Manager)
# ============================================================================
# Automated patch management with rolling updates:
# - Domain Controller: Separate maintenance window (monthly, low-risk)
# - Session Hosts: Rolling updates to prevent simultaneous reboots (weekly)
# - Staggered timing ensures DC is available during session host updates
# - Prevents service disruption by maintaining healthy host capacity
#
# CRITICAL: Session hosts use rolling updates within their maintenance window,
# ensuring they do NOT all reboot at the same time. This maintains AVD
# availability for users throughout the patching process.
# ============================================================================

module "update_management" {
  count  = var.enable_update_management ? 1 : 0
  source = "../../modules/update_management"

  resource_group_name            = azurerm_resource_group.rg.name
  location                       = azurerm_resource_group.rg.location
  maintenance_config_name_prefix = local.update_management_config.maintenance_config_prefix
  
  # Domain Controller Maintenance (Separate Window)
  dc_maintenance_start_datetime = local.update_management_config.dc_start_datetime
  dc_maintenance_duration       = local.update_management_config.dc_duration
  dc_maintenance_recurrence     = local.update_management_config.dc_recurrence
  dc_reboot_setting             = local.update_management_config.dc_reboot_setting
  dc_patch_classifications      = ["Critical", "Security", "UpdateRollup"]
  
  # Session Host Maintenance (Rolling Updates)
  session_host_maintenance_start_datetime = local.update_management_config.session_host_start_datetime
  session_host_maintenance_duration       = local.update_management_config.session_host_duration
  session_host_maintenance_recurrence     = local.update_management_config.session_host_recurrence
  session_host_reboot_setting             = local.update_management_config.session_host_reboot_setting
  session_host_patch_classifications      = ["Critical", "Security", "UpdateRollup"]
  
  # Shared Settings
  maintenance_timezone  = local.update_management_config.maintenance_timezone
  kb_numbers_to_exclude = local.update_management_config.kb_exclusions
  
  # VMs to Manage
  dc_vm_id = module.domain_controller.dc_vm_id
  session_host_vm_ids = {
    for idx in range(local.session_hosts_config.count) :
    "${var.environment}-avd-sh-${idx + 1}" => module.session_hosts.vm_ids[idx]
  }
  
  # Emergency Patching (Disabled by default)
  enable_emergency_patching = false
  
  tags = local.tags

  depends_on = [
    module.domain_controller,
    module.session_hosts
  ]
}

# ============================================================================
# STEP 12: Cost Management (Azure Budget + Alerts)
# ============================================================================
# Budget monitoring and cost control:
# - Monthly budget with configurable amount
# - Email alerts at 80%, 90%, and 100% of budget
# - Resource group scoped for environment-specific budgets
# - Helps prevent unexpected cost overruns
#
# IMPORTANT: Set monthly_budget_amount based on expected costs + buffer
# Typical AVD costs: $300-500/month (dev), $1000-2000/month (prod)
# ============================================================================

module "cost_management" {
  count  = var.enable_cost_management && length(local.cost_management_config.alert_emails) > 0 ? 1 : 0
  source = "../../modules/cost_management"

  enabled              = true
  budget_name          = local.cost_management_config.budget_name
  monthly_budget_amount = local.cost_management_config.monthly_budget_amount
  
  # Resource Group Scoped Budget
  budget_scope        = "ResourceGroup"
  resource_group_id   = azurerm_resource_group.rg.id
  resource_group_name = azurerm_resource_group.rg.name
  
  # Alert Configuration
  alert_emails       = local.cost_management_config.alert_emails
  alert_threshold_1  = local.cost_management_config.alert_threshold_1
  alert_threshold_2  = local.cost_management_config.alert_threshold_2
  alert_threshold_3  = local.cost_management_config.alert_threshold_3
  
  # Optional: Forecasted alerts (predict budget overruns)
  enable_forecasted_alerts = false
  
  # Time Period (starts current month, indefinite)
  budget_start_date = null
  budget_end_date   = null
  
  # Optional: Filter by tags
  filter_tags = {}

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================================
# STEP 13: Scaling Plan (AVD Auto-Scaling for Cost Optimization)
# ============================================================================
# Automatically scales session hosts based on time-of-day schedules:
# - Ramp-up: Morning startup (7 AM - 9 AM)
# - Peak: Business hours (9 AM - 5 PM)
# - Ramp-down: Evening wind-down (5 PM - 7 PM)
# - Off-peak: Overnight (7 PM - 7 AM next day)
#
# Cost Savings: Deallocates idle session hosts during off-peak hours
# - Typical savings: 60-80% reduction in VM costs
# - Example: $276/month to $110/month (4 VMs, 14 off-peak hours/day)
#
# Prerequisites:
# - Host pool must be "Pooled" type (not "Personal")
# - Start VM on Connect recommended for off-peak (auto-starts when needed)
#
# Schedule times defined in scaling_config locals for easy editing.
#
# CONDITIONAL: Only created if feature_toggles.enable_scaling_plan = true
# ============================================================================

module "scaling_plan" {
  count  = local.feature_toggles.enable_scaling_plan ? 1 : 0
  source = "../../modules/scaling_plan"

  enabled              = true
  scaling_plan_name    = "${var.project_name}-${var.environment}-scaling-plan"
  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  friendly_name        = "${var.project_name} ${upper(var.environment)} Auto-Scaling"
  description          = "Automatic scaling for ${var.project_name} AVD session hosts (${var.environment} environment)"
  timezone             = local.scaling_config.timezone
  
  # Associate with AVD host pool
  host_pool_ids = [module.avd_core.host_pool_id]
  
  # WEEKDAY SCHEDULE - Monday to Friday
  # Ramp-up phase (morning startup before users arrive)
  weekday_ramp_up_start_time                 = local.scaling_config.weekday_ramp_up_start
  weekday_ramp_up_min_hosts_percent          = local.scaling_config.ramp_up_min_hosts_percent
  weekday_ramp_up_capacity_threshold_percent = local.scaling_config.ramp_up_capacity_threshold
  
  # Peak phase (business hours)
  weekday_peak_start_time = local.scaling_config.weekday_peak_start
  
  # Ramp-down phase (evening wind-down)
  weekday_ramp_down_start_time                 = local.scaling_config.weekday_ramp_down_start
  weekday_ramp_down_min_hosts_percent          = local.scaling_config.ramp_down_min_hosts_percent
  weekday_ramp_down_capacity_threshold_percent = local.scaling_config.ramp_down_capacity_threshold
  
  # Off-peak phase (overnight, minimal capacity)
  weekday_off_peak_start_time = local.scaling_config.weekday_off_peak_start
  
  # WEEKEND SCHEDULE - Saturday and Sunday (optional)
  enable_weekend_schedule = true  # Set to false if no weekend users
  
  # Weekend typically uses lower capacity (adjust if 24x7 operations)
  weekend_ramp_up_start_time                 = local.scaling_config.weekend_ramp_up_start
  weekend_ramp_up_min_hosts_percent          = 10       # Lower minimum
  weekend_ramp_up_capacity_threshold_percent = 80       # Slower scaling
  weekend_peak_start_time                    = local.scaling_config.weekend_peak_start
  weekend_ramp_down_start_time               = local.scaling_config.weekend_ramp_down_start
  weekend_ramp_down_min_hosts_percent        = 0        # Can scale to zero
  weekend_ramp_down_capacity_threshold_percent = 90
  weekend_off_peak_start_time                = local.scaling_config.weekend_off_peak_start
  
  # LOAD BALANCING - How to distribute users across hosts
  ramp_up_load_balancing_algorithm   = "BreadthFirst"  # Spread users during ramp-up
  peak_load_balancing_algorithm      = "DepthFirst"    # Consolidate during peak (cost-efficient)
  ramp_down_load_balancing_algorithm = "DepthFirst"    # Consolidate for faster deallocation
  off_peak_load_balancing_algorithm  = "DepthFirst"    # Minimize hosts overnight
  
  # USER SESSION MANAGEMENT - Ramp-down behavior
  ramp_down_force_logoff_users   = local.scaling_config.force_logoff_users
  ramp_down_wait_time_minutes    = local.scaling_config.wait_time_minutes
  ramp_down_notification_message = local.scaling_config.notification_message
  ramp_down_stop_hosts_when      = "ZeroSessions"  # Wait for all sessions to end
  
  tags = local.tags

  depends_on = [
    module.avd_core  # Host pool must exist before associating scaling plan
  ]
}

# ============================================================================
# STEP 14: Conditional Access (Entra ID Security Policies) - OPTIONAL
# ============================================================================
# Enforces security requirements for AVD access using Microsoft Entra 
# Conditional Access policies. This provides defense-in-depth security by
# evaluating user, device, location, and application signals before granting
# access.
#
# CRITICAL PREREQUISITES:
# 1. Entra ID Premium P1 or P2 licensing ($6-9/user/month)
# 2. Break-glass account created and added to exclusion group BEFORE enabling
# 3. AVD users group created in Entra ID
# 4. (Optional) Intune configured for device compliance policies
#
# Security Controls:
# - Multi-factor authentication (MFA) enforcement
# - Compliant or Hybrid Azure AD joined device requirement
# - Legacy authentication blocking (IMAP, POP3, SMTP, Exchange ActiveSync)
# - Approved client app requirement for mobile access
# - Session controls (sign-in frequency, persistent browser management)
#
# Safety Features:
# - Break-glass account exclusions in ALL policies (prevent admin lockout)
# - Per-policy additional exclusions (pilot groups, service accounts)
# - Report-only mode support (monitor without enforcement)
# - Granular control (master toggle + per-policy toggles)
#
# Deployment Strategy (RECOMMENDED):
# 1. Create break-glass accounts and test monthly
# 2. Deploy policies in report-only mode (2-4 weeks)
# 3. Review sign-in logs daily, adjust exclusions
# 4. Enable for pilot group first (1-2 weeks)
# 5. Gradual rollout to all users
#
# Rollback Procedures:
# - Emergency: Use break-glass account to disable policies
# - Temporary: Add user to break-glass group
# - Testing: Change policy state to report-only
# - Permanent: Set feature_toggles.enable_conditional_access = false
#
# Monitoring:
# - Sign-in logs: Entra ID to Monitoring to Sign-in logs
# - Azure Monitor alerts: Break-glass account usage, high policy failure rate
# - Log Analytics: KQL queries for CA policy evaluation
#
# WARNING: Misconfigured Conditional Access policies can lock out ALL users
# including Global Admins. ALWAYS create and test break-glass accounts first!
#
# CONDITIONAL: Only created if feature_toggles.enable_conditional_access = true
#
# Documentation: modules/conditional_access/README.md
# ============================================================================

module "conditional_access" {
  count  = local.feature_toggles.enable_conditional_access ? 1 : 0
  source = "../../modules/conditional_access"

  enabled = true

  # POLICY TOGGLES - Enable/disable individual policies
  require_mfa              = local.conditional_access_config.require_mfa
  require_compliant_device = local.conditional_access_config.require_compliant_device
  block_legacy_auth        = local.conditional_access_config.block_legacy_auth
  require_approved_app     = false                               # Mobile: Require MS Remote Desktop (optional)
  enable_session_controls  = false                               # Sign-in frequency controls (optional)

  # TARGETING - Users and applications
  # Primary AVD users group (automatically wired from avd_core module)
  avd_users_group_id = module.avd_core.user_group_object_id
  
  # Additional groups for pilot users or special cases (optional)
  additional_target_group_ids = local.conditional_access_config.additional_target_group_ids
  
  break_glass_group_ids = local.conditional_access_config.break_glass_group_ids
  
  # AVD application IDs (default values, can be customized)
  avd_application_ids = [
    "9cdead84-a844-4324-93f2-b2e6bb768d07",  # Azure Virtual Desktop
    "38aa3b87-a06d-4817-b275-7a316988d93b"   # Windows Sign-In (broader scope)
  ]

  # POLICY NAMES - Customizable display names
  mfa_policy_name         = "AVD-${var.environment}: Require Multi-Factor Authentication"
  device_policy_name      = "AVD-${var.environment}: Require Compliant or Hybrid Joined Device"
  legacy_auth_policy_name = "AVD-${var.environment}: Block Legacy Authentication"

  # POLICY STATES - Control enforcement level
  # Options:
  #   "enabled"                            - Enforced (blocks non-compliant users)
  #   "enabledForReportingButNotEnforced"  - Audit mode (logs only, no blocking)
  #   "disabled"                           - Policy inactive
  #
  # SAFETY: ALL policies default to report-only mode in variables.tf
  # REQUIRED WORKFLOW: Report-only (2-4 weeks) to Validate to Enable gradually
  # STAGED ROLLOUT: Legacy auth (week 3) to MFA pilot (week 5) to MFA all (week 7)
  #
  # VALIDATION: Module will fail if break_glass_group_ids not set (safety check)
  mfa_policy_state         = local.conditional_access_config.mfa_policy_state
  device_policy_state      = local.conditional_access_config.device_policy_state
  legacy_auth_policy_state = local.conditional_access_config.legacy_auth_policy_state

  # DEVICE COMPLIANCE CONFIGURATION
  require_compliant_or_hybrid = true  # true = Compliant OR Hybrid (flexible), false = AND (strict)

  # LEGACY AUTH CONFIGURATION
  block_legacy_auth_all_apps = true  # true = Block for all apps (recommended), false = AVD only

  # OPTIONAL: Per-policy additional exclusions (beyond break-glass accounts)
  # Example use cases:
  # - Pilot groups during testing
  # - Service accounts requiring legacy auth (not recommended)
  # - Temporary exclusions for troubleshooting
  mfa_excluded_group_ids         = []  # Additional MFA exclusions
  device_excluded_group_ids      = []  # Additional device policy exclusions
  legacy_auth_excluded_group_ids = []  # Additional legacy auth exclusions (not recommended)

  depends_on = [
    module.avd_core  # Ensure AVD infrastructure exists before applying CA policies
  ]
}
