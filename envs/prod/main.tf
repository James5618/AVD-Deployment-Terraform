# ============================================================================
# Production Environment - Main Configuration
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
  }

  # Uncomment to use remote backend for state management
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstateprodavd"
  #   container_name       = "tfstate"
  #   key                  = "prod.terraform.tfstate"
  # }
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
# USER CONFIG - Customize deployment settings here
# ============================================================================
# This section mirrors key variables for easy reference and allows quick
# adjustments without searching through variables.tf. Modify these values
# or their corresponding variables in terraform.tfvars.
# ============================================================================

locals {
  # ─────────────────────────────────────────────────────────────────────────
  # BASICS - Project identification and location
  # ─────────────────────────────────────────────────────────────────────────
  environment    = var.environment       # dev, staging, prod
  location       = var.location          # Azure region
  location_short = var.location_short    # Short code for naming
  project_name   = var.project_name      # Project identifier

  # ─────────────────────────────────────────────────────────────────────────
  # DEPLOYMENT SIZING - Control resource counts and VM sizes
  # ─────────────────────────────────────────────────────────────────────────
  session_host_count     = var.session_host_count          # Number of AVD VMs (default: 5)
  session_host_vm_size   = var.session_host_vm_size        # VM SKU for session hosts
  dc_vm_size             = var.dc_vm_size                  # VM SKU for Domain Controller
  fslogix_share_quota_gb = var.fslogix_share_quota_gb      # Profile storage size in GB

  # ─────────────────────────────────────────────────────────────────────────
  # AVD CONFIGURATION - Host pool and user settings
  # ─────────────────────────────────────────────────────────────────────────
  hostpool_type            = var.hostpool_type              # Pooled or Personal
  load_balancer_type       = var.load_balancer_type         # BreadthFirst or DepthFirst
  maximum_sessions_allowed = var.maximum_sessions_allowed   # Max users per session host
  avd_users                = var.avd_users                  # List of UPNs for AVD access

  # ─────────────────────────────────────────────────────────────────────────
  # DOMAIN CONFIGURATION
  # ─────────────────────────────────────────────────────────────────────────
  domain_name         = var.domain_name                    # FQDN (e.g., corp.contoso.com)
  domain_netbios_name = split(".", var.domain_name)[0]     # NetBIOS name
  dc_private_ip       = var.dc_private_ip                  # Static IP for DC
  dc_enable_public_ip = var.dc_enable_public_ip            # Public IP (false for prod)

  # ─────────────────────────────────────────────────────────────────────────
  # RESOURCE NAMING - Automatically generated from above settings
  # ─────────────────────────────────────────────────────────────────────────
  resource_group_name  = "${var.project_name}-${var.environment}-rg"
  vnet_name            = "${var.project_name}-${var.environment}-vnet"
  dc_name              = "${upper(var.environment)}-DC01"
  workspace_name       = "${var.project_name}-${var.environment}-workspace"
  hostpool_name        = "${var.project_name}-${var.environment}-hp"
  app_group_name       = "${var.project_name}-${var.environment}-dag"
  session_host_prefix  = "${var.environment}-avd-sh"
  storage_account_name = "${lower(var.project_name)}${lower(var.environment)}fslogix"

  # ─────────────────────────────────────────────────────────────────────────
  # TAGS - Applied to all resources
  # ─────────────────────────────────────────────────────────────────────────
  tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      DeployedOn  = timestamp()
    }
  )
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

# ============================================================================
# Networking Module
# ============================================================================

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vnet_name           = local.vnet_name
  vnet_address_space  = var.vnet_address_space
  dc_subnet_prefix    = var.dc_subnet_prefix
  avd_subnet_prefix   = var.avd_subnet_prefix
  storage_subnet_prefix = var.storage_subnet_prefix
  dns_servers         = [local.dc_private_ip]
  
  tags = local.tags

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================================
# Domain Controller Module
# ============================================================================

module "domain_controller" {
  source = "../../modules/domain-controller"

  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  dc_name                   = local.dc_name
  dc_vm_size                = var.dc_vm_size
  subnet_id                 = module.networking.dc_subnet_id
  dc_private_ip             = local.dc_private_ip
  admin_username            = var.domain_admin_username
  admin_password            = var.domain_admin_password
  domain_name               = local.domain_name
  netbios_name              = local.domain_netbios_name
  safe_mode_admin_password  = var.domain_admin_password
  
  tags = local.tags

  depends_on = [module.networking]
}

# ============================================================================
# AVD Module
# ============================================================================

module "avd" {
  source = "../../modules/avd"

  resource_group_name       = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  workspace_name            = local.workspace_name
  workspace_friendly_name   = var.workspace_friendly_name
  hostpool_name             = local.hostpool_name
  hostpool_type             = var.hostpool_type
  load_balancer_type        = var.load_balancer_type
  hostpool_friendly_name    = var.hostpool_friendly_name
  maximum_sessions_allowed  = var.maximum_sessions_allowed
  app_group_name            = local.app_group_name
  app_group_friendly_name   = var.app_group_friendly_name
  avd_users                 = var.avd_users
  
  tags = local.tags

  depends_on = [azurerm_resource_group.rg]
}

# ============================================================================
# Storage Module
# ============================================================================

module "storage" {
  source = "../../modules/storage"

  resource_group_name  = azurerm_resource_group.rg.name
  location             = azurerm_resource_group.rg.location
  storage_account_name = local.storage_account_name
  share_name           = var.fslogix_share_name
  share_quota_gb       = var.fslogix_share_quota_gb
  subnet_id            = module.networking.storage_subnet_id
  vnet_id              = module.networking.vnet_id
  
  tags = local.tags

  depends_on = [module.networking]
}

# ============================================================================
# Session Hosts Module
# ============================================================================

module "session_hosts" {
  source = "../../modules/session-hosts"

  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  subnet_id             = module.networking.avd_subnet_id
  vnet_dns_servers      = [local.dc_private_ip]
  
  # VM Configuration
  vm_count              = local.session_host_count
  vm_name_prefix        = local.session_host_prefix
  vm_size               = local.session_host_vm_size
  timezone              = var.timezone
  
  # Image Configuration
  image_publisher       = var.image_publisher
  image_offer           = var.image_offer
  image_sku             = var.image_sku
  image_version         = var.image_version
  os_disk_type          = var.session_host_os_disk_type
  
  # Local Admin
  local_admin_username  = var.session_host_local_admin_username
  local_admin_password  = var.session_host_local_admin_password
  
  # Domain Join
  domain_name           = local.domain_name
  domain_netbios_name   = local.domain_netbios_name
  domain_admin_username = var.domain_admin_username
  domain_admin_password = var.domain_admin_password
  domain_ou_path        = module.domain_controller.ou_distinguished_name
  
  # AVD Registration
  hostpool_name                = module.avd.hostpool_name
  hostpool_registration_token  = module.avd.hostpool_registration_token
  
  # FSLogix
  fslogix_share_path    = module.storage.fslogix_share_path
  
  tags = local.tags

  depends_on = [
    module.domain_controller,
    module.avd,
    module.storage
  ]
}
