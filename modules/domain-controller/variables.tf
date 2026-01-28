# ============================================================================
# Domain Controller Module - Variables
# ============================================================================
# Key configuration variables are listed first for easy access.
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# DOMAIN CONFIGURATION - Active Directory domain settings
# ─────────────────────────────────────────────────────────────────────────────

variable "domain_name" {
  description = "Fully qualified domain name (FQDN) for the AD domain (e.g., 'contoso.local')"
  type        = string
}

variable "netbios_name" {
  description = "NetBIOS name for the AD domain (e.g., 'CONTOSO'). Should match the first part of domain_name."
  type        = string
}

variable "safe_mode_admin_password" {
  description = "Safe Mode Administrator password for AD DS recovery. Must meet complexity requirements. Store in Azure Key Vault for production!"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "Local administrator username for the Domain Controller VM"
  type        = string
}

variable "admin_password" {
  description = "Local administrator password for the Domain Controller VM. Must meet Windows complexity requirements. Store in Azure Key Vault for production!"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────────────────────
# VM CONFIGURATION - Size and resource settings
# ─────────────────────────────────────────────────────────────────────────────

variable "dc_vm_size" {
  description = "VM size for the Domain Controller. Minimal spec for cost efficiency (2 vCPU, 4-8 GB RAM)."
  type        = string
  default     = "Standard_B2ms"
}

variable "os_disk_type" {
  description = "OS disk type for the Domain Controller"
  type        = string
  default     = "StandardSSD_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_type)
    error_message = "OS disk type must be Standard_LRS, StandardSSD_LRS, or Premium_LRS."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB for the Domain Controller"
  type        = number
  default     = 128
  validation {
    condition     = var.os_disk_size_gb >= 127 && var.os_disk_size_gb <= 4095
    error_message = "OS disk size must be between 127 GB and 4095 GB."
  }
}

variable "timezone" {
  description = "Timezone for the Domain Controller VM (e.g., 'UTC', 'Eastern Standard Time', 'Pacific Standard Time')"
  type        = string
  default     = "UTC"
}

# ─────────────────────────────────────────────────────────────────────────────
# ORGANIZATIONAL UNIT CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "avd_ou_name" {
  description = "Name of the Organizational Unit for AVD session hosts (e.g., 'AVD', 'VDI')"
  type        = string
  default     = "AVD"
}

variable "avd_ou_description" {
  description = "Description for the AVD Organizational Unit"
  type        = string
  default     = "Organizational Unit for Azure Virtual Desktop session hosts"
}

# ─────────────────────────────────────────────────────────────────────────────
# AZURE RESOURCE CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group where the DC will be deployed"
  type        = string
}

variable "location" {
  description = "Azure region for the Domain Controller"
  type        = string
}

variable "dc_name" {
  description = "Name of the Domain Controller VM"
  type        = string
  default     = "DC01"
}

variable "subnet_id" {
  description = "ID of the subnet where the DC will be deployed"
  type        = string
}

variable "dc_private_ip" {
  description = "Static private IP address for the Domain Controller (must be within subnet range)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
