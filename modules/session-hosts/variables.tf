# ============================================================================
# Session Hosts Module - Variables
# ============================================================================
# User-friendly variables organized by functional area
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# VM CONFIGURATION - Count, size, and naming
# ─────────────────────────────────────────────────────────────────────────────

variable "vm_count" {
  description = "Number of session host VMs to deploy (scale based on concurrent users)"
  type        = number
  default     = 2
  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 100
    error_message = "VM count must be between 1 and 100."
  }
}

variable "vm_name_prefix" {
  description = "Prefix for session host VM names (will be appended with -1, -2, etc.)"
  type        = string
  default     = "avd-sh"
}

variable "vm_size" {
  description = "VM SKU for session hosts (e.g., Standard_D2s_v5, Standard_D4s_v5)"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "timezone" {
  description = "Timezone for the session host VMs (e.g., 'UTC', 'Eastern Standard Time')"
  type        = string
  default     = "UTC"
}

# ─────────────────────────────────────────────────────────────────────────────
# DISK CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "os_disk_type" {
  description = "OS disk type (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_type)
    error_message = "OS disk type must be Standard_LRS, StandardSSD_LRS, or Premium_LRS."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB (leave null for default size based on image)"
  type        = number
  default     = null
}

# ─────────────────────────────────────────────────────────────────────────────
# IMAGE SOURCE CONFIGURATION - Simplified single-variable approach
# ─────────────────────────────────────────────────────────────────────────────
# When gallery_image_version_id is provided, session hosts use that custom image.
# When null, falls back to default Azure Marketplace Windows 11 image.

variable "gallery_image_version_id" {
  description = "Azure Compute Gallery image version resource ID. When provided, VMs use this custom image instead of marketplace. Example: /subscriptions/.../galleries/.../images/.../versions/1.0.0 (pinned) or .../versions/latest (floating). Set to null to use default marketplace image."
  type        = string
  default     = null
  
  validation {
    condition     = var.gallery_image_version_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Compute/galleries/.+/images/.+/versions/.+$", var.gallery_image_version_id))
    error_message = "gallery_image_version_id must be a valid Azure Compute Gallery image version resource ID or null."
  }
}

variable "marketplace_image_reference" {
  description = "FALLBACK: Azure Marketplace image reference used when gallery_image_version_id is null. Default: Windows 11 Multi-Session + M365"
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

variable "managed_image_id" {
  description = "Managed Image resource ID (only used if session_host_image_source = 'managed_image'). Example: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/images/{imageName}"
  type        = string
  default     = null
  
  validation {
    condition     = var.managed_image_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft.Compute/images/.+$", var.managed_image_id))
    error_message = "managed_image_id must be a valid Azure Managed Image resource ID or null."
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# DEPRECATED VARIABLES (maintained for backward compatibility, will be removed in future version)
# ─────────────────────────────────────────────────────────────────────────────

variable "use_golden_image" {
  description = "DEPRECATED: Use session_host_image_source = 'gallery' instead. This variable is ignored."
  type        = bool
  default     = false
}

variable "image_publisher" {
  description = "DEPRECATED: Use marketplace_image_reference.publisher instead. This variable is ignored."
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "image_offer" {
  description = "DEPRECATED: Use marketplace_image_reference.offer instead. This variable is ignored."
  type        = string
  default     = "windows-11"
}

variable "image_sku" {
  description = "DEPRECATED: Use marketplace_image_reference.sku instead. This variable is ignored."
  type        = string
  default     = "win11-22h2-avd"
}

variable "image_version" {
  description = "DEPRECATED: Use marketplace_image_reference.version instead. This variable is ignored."
  type        = string
  default     = "latest"
}

# ─────────────────────────────────────────────────────────────────────────────
# LOCAL ADMIN CREDENTIALS
# ─────────────────────────────────────────────────────────────────────────────

variable "local_admin_username" {
  description = "Local administrator username for session host VMs"
  type        = string
}

variable "local_admin_password" {
  description = "Local administrator password for session host VMs (Store in Key Vault!)"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────────────────────
# DOMAIN JOIN CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Fully qualified domain name to join (e.g., 'contoso.local')"
  type        = string
}

variable "domain_netbios_name" {
  description = "NetBIOS domain name (e.g., 'CONTOSO')"
  type        = string
}

variable "domain_admin_username" {
  description = "Domain administrator username for domain join"
  type        = string
}

variable "domain_admin_password" {
  description = "Domain administrator password for domain join (Store in Key Vault!)"
  type        = string
  sensitive   = true
}

variable "domain_ou_path" {
  description = "OU Distinguished Name where computer accounts will be created (e.g., 'OU=AVD,DC=contoso,DC=local'). Leave empty for default Computers container."
  type        = string
  default     = ""
}

# ─────────────────────────────────────────────────────────────────────────────
# AVD HOST POOL CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "hostpool_name" {
  description = "Name of the AVD host pool to register session hosts to"
  type        = string
}

variable "hostpool_registration_token" {
  description = "Registration token for the AVD host pool (sensitive)"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────────────────────
# FSLOGIX CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "fslogix_share_path" {
  description = "UNC path to the FSLogix profile share (e.g., '\\\\storageaccount.file.core.windows.net\\user-profiles')"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# AZURE RESOURCES
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group where session hosts will be deployed"
  type        = string
}

variable "location" {
  description = "Azure region for session hosts"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet where session hosts will be deployed"
  type        = string
}

variable "vnet_dns_servers" {
  description = "List of DNS server IPs (should point to DC). Leave empty to use VNet default."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
