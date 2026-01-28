# ============================================================================
# Development Environment - Variable Definitions
# ============================================================================
# 
# ⚠️ ALL USER-FACING CONFIGURATION IS HERE
# 
# This file contains EVERY adjustable setting for the AVD deployment.
# No configuration is hidden in modules - all inputs are surfaced here.
#
# QUICK START:
# 1. Copy terraform.tfvars.example to terraform.tfvars
# 2. Search this file for the setting you want to change
# 3. Override the default value in terraform.tfvars
# 
# ORGANIZATION:
# Variables are grouped by functional area with visual separators:
# - Basics (environment, location, project name)
# - Networking (VNet, subnets)
# - Domain Controller & Active Directory
# - Azure Virtual Desktop (workspace, host pool)
# - Session Hosts (AVD VMs)
# - FSLogix & Storage (user profiles)
# - Security & Diagnostics
#
# SENSITIVE VALUES:
# Variables marked "sensitive = true" are protected from console output.
# Use Azure Key Vault for production (see main.tf for integration example).
#
# DEFAULTS:
# All variables have sensible defaults. You only need to set values in
# terraform.tfvars if you want to override the defaults.
# ============================================================================

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ BASICS - Core project settings                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources (e.g., eastus, westeurope, centralus)"
  type        = string
  default     = "eastus"
}

variable "location_short" {
  description = "Short code for Azure region used in naming (e.g., eus, weu, cus)"
  type        = string
  default     = "eus"
}

variable "project_name" {
  description = "Project identifier used for resource naming"
  type        = string
  default     = "avd"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    CostCenter = "IT"
    Owner      = "AVD Team"
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ SESSION HOST IMAGE STRATEGY - Unified image selection                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Choose ONE strategy for session host image source:
# - marketplace: Use Azure Marketplace images (Windows 11 AVD default)
# - aib_gallery: Use Azure Image Builder generated gallery images
# - manual_gallery: Use manually prepared/imported gallery images
#
# Each strategy requires different inputs:
# - marketplace: No additional inputs required (uses marketplace_image_reference)
# - aib_gallery: Requires enable_golden_image=true
# - manual_gallery: Requires enable_manual_gallery_import=true + source image details

variable "session_host_image_strategy" {
  description = "Image source strategy for session hosts. Options: 'marketplace' (Azure Marketplace images), 'aib_gallery' (Azure Image Builder), 'manual_gallery' (manually imported images)"
  type        = string
  default     = "manual_gallery"
  
  validation {
    condition     = contains(["marketplace", "aib_gallery", "manual_gallery"], var.session_host_image_strategy)
    error_message = "session_host_image_strategy must be one of: marketplace, aib_gallery, manual_gallery."
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ IMAGE - Custom Image Import Configuration                                 ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Import manually prepared/generalized images to Azure Compute Gallery for use
# by AVD session hosts. This provides versioning, replication, and easy rollback.
#
# WORKFLOW:
# 1. Create VM, install apps, run sysprep /generalize /shutdown
# 2. Capture to Managed Image OR export disk to VHD
# 3. Enable this module to import into Compute Gallery
# 4. Session hosts automatically use the gallery image version
#
# See README.md "Manual Golden Image Creation" section for detailed steps.

variable "enable_manual_gallery_import" {
  description = "Enable importing manually prepared images to Azure Compute Gallery. REQUIRED when session_host_image_strategy='manual_gallery'. Set to true to activate the import workflow."
  type        = bool
  default     = true
}

variable "image_source_type" {
  description = "Source type for image import: 'managed_image' (existing managed image) or 'vhd' (VHD file in blob storage)"
  type        = string
  default     = "managed_image"
  
  validation {
    condition     = contains(["managed_image", "vhd"], var.image_source_type)
    error_message = "image_source_type must be 'managed_image' or 'vhd'."
  }
}

variable "source_managed_image_id" {
  description = "Resource ID of existing managed image. REQUIRED when session_host_image_strategy='manual_gallery' AND image_source_type='managed_image'. Example: /subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-images/providers/Microsoft.Compute/images/win11-custom"
  type        = string
  default     = null
}

variable "source_vhd_uri" {
  description = "URI of VHD file in Azure Storage. REQUIRED when session_host_image_strategy='manual_gallery' AND image_source_type='vhd'. Example: https://mystorageacct.blob.core.windows.net/vhds/win11-custom.vhd"
  type        = string
  default     = null
}

variable "image_version" {
  description = "Semantic version for imported image (e.g., '1.0.0', '1.1.0'). Increment this to create new versions. Must be unique within image definition."
  type        = string
  default     = "1.0.0"
  
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.image_version))
    error_message = "image_version must be in semantic version format (e.g., '1.0.0')."
  }
}

variable "pin_image_version_id" {
  description = "Pin session hosts to specific image version (true) instead of floating to 'latest' (false). RECOMMENDED: true for production to prevent unexpected updates. Set false only for dev/test environments where automatic updates are acceptable."
  type        = bool
  default     = true
}

variable "image_replication_regions" {
  description = "Azure regions to replicate the image to. Default: current location only. Add regions where you deploy session hosts. Example: ['eastus', 'westus2', 'westeurope']"
  type        = list(string)
  default     = []
}

variable "exclude_from_latest" {
  description = "Exclude this image version from being returned by 'latest' queries. RECOMMENDED: true for production to enforce explicit version pinning. Set false only if you want this version to be used by 'latest' references."
  type        = bool
  default     = true
}

variable "gallery_name" {
  description = "Azure Compute Gallery name for image storage. Leave empty to auto-generate unique name based on project/environment."
  type        = string
  default     = ""
}

variable "gallery_rg_name" {
  description = "Resource group name for existing Azure Compute Gallery. Leave empty to create gallery in main resource group."
  type        = string
  default     = ""
}

variable "image_definition_name" {
  description = "Name for the image definition in the gallery (e.g., 'windows11-avd-custom', 'win10-enterprise-apps')"
  type        = string
  default     = "windows11-avd-custom"
}

variable "image_publisher" {
  description = "Publisher name for image metadata (e.g., 'MyCompany', 'Contoso'). Used for organization and filtering."
  type        = string
  default     = "MyCompany"
}

variable "image_offer" {
  description = "Offer name for image metadata (e.g., 'Windows11-AVD', 'Windows10-Enterprise')"
  type        = string
  default     = "Windows11-AVD-Custom"
}

variable "image_sku" {
  description = "SKU identifier for image metadata (e.g., 'custom-v1', 'enterprise-apps')"
  type        = string
  default     = "custom"
}

variable "hyper_v_generation" {
  description = "Hyper-V generation for the image: 'V1' (legacy BIOS) or 'V2' (UEFI, required for Windows 11). Must match source VM/VHD generation."
  type        = string
  default     = "V2"
  
  validation {
    condition     = contains(["V1", "V2"], var.hyper_v_generation)
    error_message = "hyper_v_generation must be 'V1' or 'V2'."
  }
}

variable "os_type" {
  description = "Operating system type: 'Windows' or 'Linux'"
  type        = string
  default     = "Windows"
  
  validation {
    condition     = contains(["Windows", "Linux"], var.os_type)
    error_message = "os_type must be 'Windows' or 'Linux'."
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ SESSION HOST IMAGE SOURCE - Choose where session host VMs get their OS    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Three image sources supported:
# 1. "marketplace"    - Azure Marketplace (publisher/offer/sku/version)
# 2. "gallery"        - Azure Compute Gallery (Golden Image pipeline OR imported image)
# 3. "managed_image"  - Managed Image (manually created custom image)
#
# Only configure variables for your chosen image source. Others will be ignored.

variable "session_host_image_source" {
  description = "Image source for session hosts: 'marketplace' (Azure Marketplace), 'gallery' (Azure Compute Gallery/Golden Image), or 'managed_image' (custom managed image)"
  type        = string
  default     = "marketplace"
  
  validation {
    condition     = contains(["marketplace", "gallery", "managed_image"], var.session_host_image_source)
    error_message = "session_host_image_source must be 'marketplace', 'gallery', or 'managed_image'."
  }
}

# Marketplace Image (used if session_host_image_source = "marketplace")
variable "marketplace_image_reference" {
  description = "Azure Marketplace image reference (publisher/offer/sku/version). Used when session_host_image_strategy='marketplace' or as fallback for other strategies."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }
}

# DEPRECATED: The following variables are kept for backward compatibility
# New deployments should use session_host_image_strategy instead
# DEPRECATED: The following variables are kept for backward compatibility
# New deployments should use session_host_image_strategy instead

variable "gallery_image_version_id" {
  description = "DEPRECATED: Use session_host_image_strategy instead. Azure Compute Gallery image version ID. Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/galleries/{gallery}/images/{image}/versions/{version}"
  type        = string
  default     = null
}

variable "managed_image_id" {
  description = "DEPRECATED: Use session_host_image_strategy='manual_gallery' with source_managed_image_id instead. Managed Image resource ID. Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/images/{imageName}"
  type        = string
  default     = null
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ KEY VAULT - Secure secret storage for passwords and credentials           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_key_vault" {
  description = "Enable Azure Key Vault for secure password storage (RECOMMENDED - eliminates plaintext passwords)"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Name of Azure Key Vault (3-24 chars, globally unique). Leave empty to auto-generate: {project_name}-{environment}-kv-{random}"
  type        = string
  default     = ""
}

variable "auto_generate_passwords" {
  description = "Auto-generate secure 24-character passwords for domain admin and local admin. If false, you must provide domain_admin_password and session_host_local_admin_password variables."
  type        = bool
  default     = true
}

variable "key_vault_purge_protection" {
  description = "Enable purge protection for Key Vault (prevents permanent deletion). Recommended for production. WARNING: Cannot be disabled once enabled!"
  type        = bool
  default     = false
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ GOLDEN IMAGE - Custom AVD image with Azure Image Builder                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_golden_image" {
  description = "Enable golden image module (Azure Image Builder + Compute Gallery). Set to false to use marketplace images directly."
  type        = bool
  default     = false
}

variable "golden_image_version" {
  description = "Semantic version for golden image (e.g., 1.0.0, 1.1.0). Increment for each new build."
  type        = string
  default     = "1.0.0"
}

variable "golden_image_base_sku" {
  description = "Marketplace image SKU for golden image base. Examples: win11-22h2-avd-m365 (Win11+M365), win10-22h2-avd-m365 (Win10+M365), win11-22h2-avd (Win11 no M365)"
  type        = string
  default     = "win11-22h2-avd-m365"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ MANUAL IMAGE IMPORT - Import manually prepared images to Compute Gallery  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# Import custom images that you've manually created, generalized (sysprep), and 
# captured. Useful for migrating existing customized VMs or complex configurations
# that can't be automated with Azure Image Builder.

variable "manual_image_source_type" {
  description = "Source type for manual image: 'managed_image' (existing managed image) or 'vhd' (VHD file in storage)"
  type        = string
  default     = "managed_image"
}

variable "manual_image_managed_image_id" {
  description = "Resource ID of existing managed image (required if manual_image_source_type='managed_image'). Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/images/{name}"
  type        = string
  default     = null
}

variable "manual_image_vhd_uri" {
  description = "URI of VHD file in Azure Storage (required if manual_image_source_type='vhd'). Example: https://mystorageacct.blob.core.windows.net/vhds/myimage.vhd"
  type        = string
  default     = null
}

variable "manual_image_version" {
  description = "Semantic version for imported image (e.g., '1.0.0', '1.1.0'). Must be unique within image definition."
  type        = string
  default     = "1.0.0"
}

variable "manual_image_gallery_name" {
  description = "Azure Compute Gallery name for manual image import. Leave empty to auto-generate unique name."
  type        = string
  default     = ""
}

variable "manual_image_definition_name" {
  description = "Name for the manually imported image definition (e.g., 'windows11-avd-custom', 'win10-apps-imported')"
  type        = string
  default     = "windows11-avd-manual"
}

variable "manual_image_publisher" {
  description = "Publisher name for manual image (e.g., 'MyCompany', 'Contoso')"
  type        = string
  default     = "MyCompany"
}

variable "manual_image_offer" {
  description = "Offer name for manual image (e.g., 'Windows11-AVD-Custom')"
  type        = string
  default     = "Windows-AVD-Manual"
}

variable "manual_image_sku" {
  description = "SKU name for manual image (e.g., 'custom-v1', 'migrated')"
  type        = string
  default     = "manual"
}

variable "manual_image_hyper_v_generation" {
  description = "Hyper-V generation for manual image: 'V1' or 'V2'. Must match source VM generation."
  type        = string
  default     = "V2"
}

variable "golden_image_install_windows_updates" {
  description = "Install Windows updates during golden image build. Recommended but adds 15-30 minutes to build time."
  type        = bool
  default     = true
}

variable "golden_image_chocolatey_packages" {
  description = "List of Chocolatey packages to install in golden image (e.g., ['googlechrome', '7zip', 'adobereader'])"
  type        = list(string)
  default     = []
}

variable "golden_image_custom_scripts" {
  description = "Map of custom PowerShell scripts for golden image. Key = script name, Value = list of PowerShell commands."
  type        = map(list(string))
  default     = {}
}

variable "golden_image_replication_regions" {
  description = "Azure regions to replicate golden image to. Include all regions where you deploy session hosts."
  type        = list(string)
  default     = []
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ SCALING PLAN - Auto-scaling for cost optimization (60-80% savings)        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_scaling_plan" {
  description = "Enable AVD auto-scaling to deallocate idle session hosts during off-peak hours (saves 60-80% compute costs)"
  type        = bool
  default     = false
}

variable "scaling_plan_timezone" {
  description = "Timezone for scaling schedule (Windows timezone format). Examples: 'GMT Standard Time' (UK), 'Eastern Standard Time' (US East), 'Pacific Standard Time' (US West)"
  type        = string
  default     = "GMT Standard Time"  # Europe/London (UTC+0, UTC+1 DST)
}

variable "weekday_ramp_up_start_time" {
  description = "Weekday ramp-up start time (HH:MM 24-hour format). When to start scaling up before users arrive. Example: 07:00 for 7 AM"
  type        = string
  default     = "07:00"
}

variable "weekday_peak_start_time" {
  description = "Weekday peak hours start time (HH:MM 24-hour format). Business hours begin. Example: 09:00 for 9 AM"
  type        = string
  default     = "09:00"
}

variable "weekday_ramp_down_start_time" {
  description = "Weekday ramp-down start time (HH:MM 24-hour format). Business hours end. Example: 17:00 for 5 PM"
  type        = string
  default     = "17:00"
}

variable "weekday_off_peak_start_time" {
  description = "Weekday off-peak start time (HH:MM 24-hour format). Minimal capacity for overnight. Example: 19:00 for 7 PM"
  type        = string
  default     = "19:00"
}

variable "weekday_ramp_up_min_hosts_percent" {
  description = "Weekday ramp-up: Minimum % of host pool to keep online (0-100). Example: 20 = keep at least 20% of hosts running"
  type        = number
  default     = 20
}

variable "weekday_ramp_up_capacity_threshold" {
  description = "Weekday ramp-up: Start new hosts when load exceeds this % (0-100). Example: 60 = scale when >60% capacity used"
  type        = number
  default     = 60
}

variable "weekday_ramp_down_min_hosts_percent" {
  description = "Weekday ramp-down: Minimum % of host pool to keep online for late workers. Example: 10 = keep at least 10%"
  type        = number
  default     = 10
}

variable "weekday_ramp_down_capacity_threshold" {
  description = "Weekday ramp-down: Stop hosts when load falls below this %. Example: 90 = conservative (keep hosts until <90% used)"
  type        = number
  default     = 90
}

variable "scaling_force_logoff_users" {
  description = "Force log off users after wait time during ramp-down. false = wait indefinitely (recommended), true = force logoff after timeout"
  type        = bool
  default     = false
}

variable "scaling_wait_time_minutes" {
  description = "Minutes to wait before forcing logoff (if enabled). Recommended: 30-60 minutes to allow users to save work"
  type        = number
  default     = 30
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ CONDITIONAL ACCESS - Entra ID Security Policies (OPTIONAL)                ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
# ⚠️ REQUIRES: Entra ID Premium P1 or P2 licensing ($6-9/user/month)
# ⚠️ CRITICAL: Create break-glass accounts BEFORE enabling policies!
#
# Enforce security requirements for AVD access:
# - Multi-factor authentication (MFA)
# - Compliant or Hybrid Azure AD joined devices
# - Block legacy authentication protocols (IMAP, POP3, SMTP)
# - Approved client apps for mobile access
# - Session controls (sign-in frequency, persistent browser)

variable "enable_conditional_access" {
  description = "Enable Conditional Access policies for AVD (requires Entra ID P1/P2). CRITICAL: Create break-glass accounts FIRST!"
  type        = bool
  default     = false
}

variable "ca_require_mfa" {
  description = "Require multi-factor authentication for AVD access (recommended)"
  type        = bool
  default     = true
}

variable "ca_require_compliant_device" {
  description = "Require compliant or Hybrid Azure AD joined device (requires Intune device management)"
  type        = bool
  default     = false
}

variable "ca_block_legacy_auth" {
  description = "Block legacy authentication protocols (Exchange ActiveSync, IMAP, POP3, SMTP) - recommended"
  type        = bool
  default     = true
}

variable "ca_additional_target_group_ids" {
  description = "Additional Entra ID group object IDs to include in CA policies beyond the primary AVD users group (e.g., pilot groups). Optional."
  type        = list(string)
  default     = []
}

variable "ca_break_glass_group_ids" {
  description = "CRITICAL: List of Entra ID group object IDs for break-glass/emergency access accounts. These accounts are EXCLUDED from all policies to prevent lockout. Create break-glass accounts BEFORE enabling CA!"
  type        = list(string)
  default     = []
}

variable "ca_mfa_policy_state" {
  description = "MFA policy state: 'enabled' (enforced), 'enabledForReportingButNotEnforced' (audit mode - recommended initially), 'disabled'"
  type        = string
  default     = "enabledForReportingButNotEnforced"
}

variable "ca_device_policy_state" {
  description = "Device compliance policy state: 'enabled', 'enabledForReportingButNotEnforced' (audit mode - recommended initially), 'disabled'"
  type        = string
  default     = "enabledForReportingButNotEnforced"
}

variable "ca_legacy_auth_policy_state" {
  description = "Legacy auth blocking policy state: 'enabledForReportingButNotEnforced' (audit mode - start here), 'enabled' (can enable after 2-3 weeks validation), 'disabled'. Start with report-only for safety."
  type        = string
  default     = "enabledForReportingButNotEnforced"
}

variable "scaling_notification_message" {
  description = "Message to display to users before forced logoff (if enabled). Leave empty for no notification."
  type        = string
  default     = "You will be logged off in 30 minutes. Please save your work."
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ NETWORKING - Virtual network and subnet configuration                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "vnet_address_space" {
  description = "Address space for the virtual network in CIDR notation"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dc_subnet_prefix" {
  description = "Subnet CIDR for Domain Controller"
  type        = string
  default     = "10.0.1.0/24"
}

variable "avd_subnet_prefix" {
  description = "Subnet CIDR for AVD session hosts"
  type        = string
  default     = "10.0.2.0/24"
}

variable "storage_subnet_prefix" {
  description = "Subnet CIDR for storage private endpoint"
  type        = string
  default     = "10.0.3.0/24"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ DOMAIN CONTROLLER & ACTIVE DIRECTORY - DC VM and AD DS configuration      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "dc_private_ip" {
  description = "Static private IP for DC (must be within dc_subnet_prefix, e.g., 10.0.1.4)"
  type        = string
  default     = "10.0.1.4"
}

variable "dc_vm_size" {
  description = "VM size for Domain Controller (minimal spec: Standard_B2ms=2vCPU/8GB)"
  type        = string
  default     = "Standard_B2ms"
}

variable "dc_os_disk_type" {
  description = "OS disk type for Domain Controller (StandardSSD_LRS recommended for minimal cost)"
  type        = string
  default     = "StandardSSD_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.dc_os_disk_type)
    error_message = "DC OS disk type must be Standard_LRS, StandardSSD_LRS, or Premium_LRS."
  }
}

variable "dc_os_disk_size_gb" {
  description = "OS disk size in GB for Domain Controller"
  type        = number
  default     = 128
}

variable "dc_enable_public_ip" {
  description = "Enable public IP for DC management access (false by default - use Azure Bastion for prod)"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Fully qualified domain name (FQDN) for Active Directory (e.g., corp.contoso.com)"
  type        = string
  default     = "avd.local"
}

variable "domain_admin_username" {
  description = "Domain administrator username"
  type        = string
  default     = "domainadmin"
}

variable "domain_admin_password" {
  description = "Domain administrator password (CHANGE THIS! Use Key Vault in production)"
  type        = string
  sensitive   = true
  default     = "P@ssw0rd123!ChangeMe"
}

variable "avd_ou_name" {
  description = "Name of the OU for AVD session hosts (will be auto-created)"
  type        = string
  default     = "AVD-SessionHosts"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ AZURE VIRTUAL DESKTOP - Workspace, host pool, and user configuration      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "workspace_friendly_name" {
  description = "Display name for the AVD workspace shown to users"
  type        = string
  default     = "Development AVD Workspace"
}

variable "hostpool_type" {
  description = "Host pool type: 'Pooled' (shared) or 'Personal' (dedicated per user)"
  type        = string
  default     = "Pooled"
  validation {
    condition     = contains(["Pooled", "Personal"], var.hostpool_type)
    error_message = "Host pool type must be 'Pooled' or 'Personal'."
  }
}

variable "load_balancer_type" {
  description = "Load balancing: 'BreadthFirst' (spread users) or 'DepthFirst' (fill hosts)"
  type        = string
  default     = "BreadthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.load_balancer_type)
    error_message = "Load balancer type must be 'BreadthFirst' or 'DepthFirst'."
  }
}

variable "start_vm_on_connect" {
  description = "Enable Start VM on Connect feature for cost savings (requires proper permissions)"
  type        = bool
  default     = true
}

variable "hostpool_friendly_name" {
  description = "Display name for the AVD host pool"
  type        = string
  default     = "Development Host Pool"
}

variable "maximum_sessions_allowed" {
  description = "Maximum concurrent user sessions per session host (only for Pooled type)"
  type        = number
  default     = 10
}

variable "app_group_friendly_name" {
  description = "Display name for the desktop application group"
  type        = string
  default     = "Development Desktop"
}

variable "registration_token_ttl_hours" {
  description = "Registration token time-to-live (e.g., '48h', '72h', '168h')"
  type        = string
  default     = "48h"
}

variable "avd_users" {
  description = "List of user principal names (UPNs) to grant AVD access (must exist in Azure AD)"
  type        = list(string)
  default     = [
    # "user1@yourdomain.com",
    # "user2@yourdomain.com",
  ]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ SESSION HOSTS - AVD virtual machines for user sessions                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "session_host_count" {
  description = "Number of session host VMs to deploy (scale based on concurrent users)"
  type        = number
  default     = 2
}

variable "session_host_vm_size" {
  description = "VM SKU for session hosts (default: Standard_D4s_v5=4vCPU/16GB, suitable for 5-10 users per host)"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "session_host_os_disk_type" {
  description = "OS disk type for session hosts (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Premium_LRS"
}

variable "session_host_local_admin_username" {
  description = "Local administrator username for session host VMs"
  type        = string
  default     = "localadmin"
}

variable "session_host_local_admin_password" {
  description = "Local administrator password for session hosts (CHANGE THIS!)"
  type        = string
  sensitive   = true
  default     = "P@ssw0rd123!ChangeMe"
}

variable "timezone" {
  description = "Timezone for VMs (e.g., 'UTC', 'Eastern Standard Time', 'Pacific Standard Time')"
  type        = string
  default     = "UTC"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ FSLOGIX & STORAGE - User profile storage configuration                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "fslogix_share_quota_gb" {
  description = "Storage quota in GB (estimate 30-50GB per user for profiles)"
  type        = number
  default     = 100
}

variable "storage_account_tier" {
  description = "Storage account tier: 'Premium' (production) or 'Standard' (dev/test)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage tier must be 'Standard' or 'Premium'."
  }
}

variable "storage_replication_type" {
  description = "Storage replication: 'LRS' (locally redundant, cheapest), 'ZRS' (zone redundant), 'GRS' (geo-redundant)"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.storage_replication_type)
    error_message = "Storage replication must be LRS, ZRS, GRS, or GZRS."
  }
}

variable "storage_account_kind" {
  description = "Storage account kind: 'FileStorage' (Premium only) or 'StorageV2'"
  type        = string
  default     = "StorageV2"
}

variable "enable_storage_private_endpoint" {
  description = "Enable private endpoint for storage account (recommended for production)"
  type        = bool
  default     = false
}

variable "enable_ad_authentication_storage" {
  description = "Enable AD DS authentication for Azure Files (requires manual setup, see module README)"
  type        = bool
  default     = false
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ LOGGING & MONITORING - Log Analytics and diagnostic settings              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_logging" {
  description = "Enable centralized logging with Log Analytics workspace and diagnostic settings for all AVD resources"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace for centralized logging"
  type        = string
  default     = ""  # Auto-generated if empty: {project_name}-{environment}-logs
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace. Range: 7-730 days. Default 30 days balances cost and compliance."
  type        = number
  default     = 30
  validation {
    condition     = var.log_analytics_retention_days >= 7 && var.log_analytics_retention_days <= 730
    error_message = "Log retention must be between 7 and 730 days."
  }
}

variable "enable_vm_insights" {
  description = "Enable VM Insights for Domain Controller and Session Hosts (installs Azure Monitor Agent and Dependency Agent for performance monitoring)"
  type        = bool
  default     = true
}

variable "enable_storage_diagnostics" {
  description = "Enable diagnostic logging for storage account and Azure Files (tracks read/write/delete operations)"
  type        = bool
  default     = true
}

variable "enable_nsg_diagnostics" {
  description = "Enable diagnostic logging for Network Security Groups (tracks allowed/denied traffic)"
  type        = bool
  default     = true
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ BACKUP & DISASTER RECOVERY - Azure Backup configuration                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_backup" {
  description = "Enable Azure Backup for Domain Controller, Session Hosts, and optionally FSLogix profiles"
  type        = bool
  default     = false
}

variable "recovery_vault_name" {
  description = "Name of the Recovery Services Vault for backups"
  type        = string
  default     = ""  # Auto-generated if empty: {project_name}-{environment}-backup
}

variable "vm_backup_retention_days" {
  description = "Number of days to retain daily VM backups (7-9999). Recommended: 7-30 days for cost efficiency."
  type        = number
  default     = 7
  validation {
    condition     = var.vm_backup_retention_days >= 7 && var.vm_backup_retention_days <= 9999
    error_message = "VM backup retention must be between 7 and 9999 days."
  }
}

variable "vm_backup_retention_weeks" {
  description = "Number of weeks to retain weekly VM backups (0-5163). Set to 0 to disable weekly retention for cost savings."
  type        = number
  default     = 4
  validation {
    condition     = var.vm_backup_retention_weeks >= 0 && var.vm_backup_retention_weeks <= 5163
    error_message = "VM backup weekly retention must be between 0 and 5163 weeks."
  }
}

variable "backup_time" {
  description = "Time of day to run backups (HH:MM format, 24-hour). Recommended: off-peak hours like 02:00."
  type        = string
  default     = "02:00"
  validation {
    condition     = can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.backup_time))
    error_message = "Backup time must be in HH:MM format (24-hour)."
  }
}

variable "fslogix_backup_enabled" {
  description = "Enable Azure Files backup for FSLogix user profiles share (snapshot-based, faster recovery than VM backup)"
  type        = bool
  default     = false
}

variable "fslogix_backup_retention_days" {
  description = "Number of days to retain daily Azure Files backups (1-200). Snapshots are cost-efficient."
  type        = number
  default     = 7
  validation {
    condition     = var.fslogix_backup_retention_days >= 1 && var.fslogix_backup_retention_days <= 200
    error_message = "Azure Files backup retention must be between 1 and 200 days."
  }
}

variable "backup_session_hosts" {
  description = "Include session hosts in backup (can be disabled if session hosts are ephemeral/rebuilable from images)"
  type        = bool
  default     = true
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ UPDATE MANAGEMENT - Automated patch management with Azure Update Manager ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_update_management" {
  description = "Enable Azure Update Manager for automated patching of Domain Controller and Session Hosts with rolling updates"
  type        = bool
  default     = false
}

variable "dc_maintenance_start_datetime" {
  description = "Start date/time for DC maintenance window in RFC3339 format (e.g., '2026-02-01T02:00:00+00:00'). Must be in the future and DIFFERENT from session host window."
  type        = string
  default     = "2026-02-01T02:00:00+00:00"
}

variable "dc_maintenance_recurrence" {
  description = "DC maintenance recurrence pattern (1Week, 2Weeks, 1Month). Domain Controllers typically patched monthly for stability."
  type        = string
  default     = "1Month"
}

variable "dc_reboot_setting" {
  description = "DC reboot behavior after patching (IfRequired, Never, Always). IfRequired recommended for Domain Controllers."
  type        = string
  default     = "IfRequired"
  validation {
    condition     = contains(["IfRequired", "Never", "Always"], var.dc_reboot_setting)
    error_message = "Reboot setting must be: IfRequired, Never, or Always."
  }
}

variable "session_host_maintenance_start_datetime" {
  description = "Start date/time for session host maintenance window in RFC3339 format. Should be DIFFERENT from DC window (e.g., 24 hours later) to ensure DC availability during updates."
  type        = string
  default     = "2026-02-02T03:00:00+00:00"
}

variable "session_host_maintenance_duration" {
  description = "Session host maintenance window duration in HH:MM format. Must be long enough for rolling updates: (# hosts × 45 min) + 30% buffer. Example: 4 hosts = 04:00 minimum."
  type        = string
  default     = "04:00"
  validation {
    condition     = can(regex("^0[1-6]:[0-5][0-9]$", var.session_host_maintenance_duration))
    error_message = "Duration must be between 01:30 and 06:00 in HH:MM format."
  }
}

variable "session_host_maintenance_recurrence" {
  description = "Session host maintenance recurrence pattern (1Week, 2Weeks, 1Month). Weekly recommended for security compliance."
  type        = string
  default     = "1Week"
}

variable "session_host_reboot_setting" {
  description = "Session host reboot behavior after patching. IfRequired is safe due to rolling updates preventing simultaneous reboots."
  type        = string
  default     = "IfRequired"
  validation {
    condition     = contains(["IfRequired", "Never", "Always"], var.session_host_reboot_setting)
    error_message = "Reboot setting must be: IfRequired, Never, or Always."
  }
}

variable "patch_kb_exclusions" {
  description = "List of KB article numbers to exclude from all patching (e.g., ['KB5001234'] if known to cause issues). Test in dev first, then apply to prod."
  type        = list(string)
  default     = []
}

# Future enhancements:
# - Azure Bastion deployment
# - Network Watcher configuration
# - Microsoft Defender for Cloud settings
# - Azure Site Recovery (DR replication)
# - Pre/post-update script execution

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ COST MANAGEMENT - Budget alerts for spending control                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "enable_cost_management" {
  description = "Enable Azure Budget with email alerts for cost monitoring and control"
  type        = bool
  default     = false
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD (or subscription currency). Set based on expected costs + 20-30% buffer. Example: $500 for dev, $1500 for prod."
  type        = number
  default     = 500
  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "Budget amount must be greater than 0."
  }
}

variable "budget_alert_emails" {
  description = "List of email addresses to receive budget alerts (ops team, finance, etc.). Must include at least one valid email."
  type        = list(string)
  default     = []
}

variable "budget_alert_threshold_1" {
  description = "First alert threshold as percentage (e.g., 80 = 80% of budget). Warning level."
  type        = number
  default     = 80
  validation {
    condition     = var.budget_alert_threshold_1 > 0 && var.budget_alert_threshold_1 <= 100
    error_message = "Alert threshold must be between 1 and 100."
  }
}

variable "budget_alert_threshold_2" {
  description = "Second alert threshold as percentage (e.g., 90 = 90% of budget). Critical warning level."
  type        = number
  default     = 90
  validation {
    condition     = var.budget_alert_threshold_2 > 0 && var.budget_alert_threshold_2 <= 100
    error_message = "Alert threshold must be between 1 and 100."
  }
}

variable "budget_alert_threshold_3" {
  description = "Third alert threshold as percentage (e.g., 100 = 100% of budget). Budget exceeded level."
  type        = number
  default     = 100
  validation {
    condition     = var.budget_alert_threshold_3 > 0 && var.budget_alert_threshold_3 <= 100
    error_message = "Alert threshold must be between 1 and 100."
  }
}
