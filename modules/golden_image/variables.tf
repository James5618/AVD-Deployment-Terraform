# ============================================================================
# Golden Image Module - Input Variables
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group for Azure Compute Gallery and Image Builder"
  type        = string
}

variable "location" {
  description = "Azure region for gallery and image definition"
  type        = string
}

variable "gallery_name" {
  description = "Name of Azure Compute Gallery (Shared Image Gallery). Must be unique within resource group."
  type        = string
}

variable "image_definition_name" {
  description = "Name of the image definition within the gallery (e.g., avd-win11-m365)"
  type        = string
}

variable "image_template_name" {
  description = "Name of the Azure Image Builder template"
  type        = string
}

variable "image_version" {
  description = "Semantic version for this image build (e.g., 1.0.0, 1.1.0). Increment for each new build."
  type        = string
  default     = "1.0.0"

  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+$", var.image_version))
    error_message = "Image version must be in semantic version format: major.minor.patch (e.g., 1.0.0)."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# BASE IMAGE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "base_image_publisher" {
  description = "Marketplace image publisher (e.g., MicrosoftWindowsDesktop)"
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "base_image_offer" {
  description = "Marketplace image offer (e.g., windows-11, office-365)"
  type        = string
  default     = "office-365"
}

variable "base_image_sku" {
  description = "Marketplace image SKU. Examples: win11-22h2-avd-m365 (Win11 + M365), win10-22h2-avd-m365 (Win10 + M365), win11-22h2-avd (Win11 no M365)"
  type        = string
  default     = "win11-22h2-avd-m365"
}

variable "base_image_version" {
  description = "Marketplace image version. Use 'latest' for most recent, or specific version like '22621.2715.231109'"
  type        = string
  default     = "latest"
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE DEFINITION PROPERTIES
# ─────────────────────────────────────────────────────────────────────────────

variable "image_publisher" {
  description = "Custom image publisher name (your company name)"
  type        = string
  default     = "MyCompany"
}

variable "image_offer" {
  description = "Custom image offer name"
  type        = string
  default     = "AVD-GoldenImage"
}

variable "image_sku" {
  description = "Custom image SKU name"
  type        = string
  default     = "Win11-M365-Custom"
}

variable "hyper_v_generation" {
  description = "Hyper-V generation: V1 or V2. Most modern VMs use V2 (UEFI). Check base image compatibility."
  type        = string
  default     = "V2"

  validation {
    condition     = contains(["V1", "V2"], var.hyper_v_generation)
    error_message = "Hyper-V generation must be V1 or V2."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# CUSTOMIZATION CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "install_windows_updates" {
  description = "Install latest Windows updates during image build (recommended). Adds 15-30 minutes to build time."
  type        = bool
  default     = true
}

variable "powershell_modules" {
  description = "List of PowerShell modules to install (e.g., ['Az.Accounts', 'Az.Compute'])"
  type        = list(string)
  default     = []
}

variable "inline_scripts" {
  description = "Map of inline PowerShell scripts. Key = script name, Value = list of PowerShell commands. Example: { 'disable-ie' = ['Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart'] }"
  type        = map(list(string))
  default     = {}
}

variable "script_uris" {
  description = "Map of script URIs to execute. Key = script name, Value = URI. Example: { 'install-apps' = 'https://example.com/install-apps.ps1' }"
  type        = map(string)
  default     = {}
}

variable "chocolatey_packages" {
  description = "List of Chocolatey packages to install (e.g., ['googlechrome', '7zip', 'adobereader']). Chocolatey will be installed automatically."
  type        = list(string)
  default     = []
}

variable "restart_after_customization" {
  description = "Restart Windows after applying customizations. Recommended if installing drivers or major updates."
  type        = bool
  default     = false
}

variable "run_cleanup_script" {
  description = "Run cleanup script to reduce image size (clear temp files, event logs, Windows Update cache)"
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# BUILD CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "build_vm_size" {
  description = "VM size for temporary build VM. Larger VM = faster builds. Recommended: Standard_D4s_v5 or larger."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "build_timeout_minutes" {
  description = "Maximum time for image build in minutes. Default: 240 (4 hours). Increase if installing many packages or Windows updates."
  type        = number
  default     = 240

  validation {
    condition     = var.build_timeout_minutes >= 60 && var.build_timeout_minutes <= 960
    error_message = "Build timeout must be between 60 and 960 minutes (1-16 hours)."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DISTRIBUTION CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "replication_regions" {
  description = "List of Azure regions to replicate the image to. Include all regions where you deploy AVD session hosts for faster VM creation."
  type        = list(string)
  default     = []
}

variable "gallery_image_storage_account_type" {
  description = "Storage account type for replicated images: Standard_LRS (cheapest), Standard_ZRS (zone-redundant), Premium_LRS (fastest)"
  type        = string
  default     = "Standard_LRS"

  validation {
    condition     = contains(["Standard_LRS", "Standard_ZRS", "Premium_LRS"], var.gallery_image_storage_account_type)
    error_message = "Storage account type must be Standard_LRS, Standard_ZRS, or Premium_LRS."
  }
}

variable "exclude_from_latest" {
  description = "Exclude this image version from being marked as 'latest'. Set to true for test builds, false for production releases."
  type        = bool
  default     = false
}

# ─────────────────────────────────────────────────────────────────────────────
# FEATURE TOGGLES
# ─────────────────────────────────────────────────────────────────────────────

variable "enabled" {
  description = "Enable golden image module deployment. Set to false to skip image builder infrastructure."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to gallery, image definition, and template"
  type        = map(string)
  default     = {}
}
