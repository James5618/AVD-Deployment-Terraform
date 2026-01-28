# ============================================================================
# Production Environment - Variable Definitions
# ============================================================================
# Variables are organized by functional area for easy navigation.
# Set values in terraform.tfvars or use defaults provided here.
# ============================================================================

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ BASICS - Core project settings                                            ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
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
    CostCenter  = "IT"
    Owner       = "AVD Production Team"
    Criticality = "High"
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ NETWORKING - Virtual network and subnet configuration                     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "vnet_address_space" {
  description = "Address space for the virtual network in CIDR notation"
  type        = string
  default     = "10.10.0.0/16"
}

variable "dc_subnet_prefix" {
  description = "Subnet CIDR for Domain Controller"
  type        = string
  default     = "10.10.1.0/24"
}

variable "avd_subnet_prefix" {
  description = "Subnet CIDR for AVD session hosts"
  type        = string
  default     = "10.10.2.0/24"
}

variable "storage_subnet_prefix" {
  description = "Subnet CIDR for storage private endpoint"
  type        = string
  default     = "10.10.3.0/24"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ DOMAIN CONTROLLER & ACTIVE DIRECTORY - DC VM and AD DS configuration      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "dc_private_ip" {
  description = "Static private IP for DC (must be within dc_subnet_prefix, e.g., 10.10.1.4)"
  type        = string
  default     = "10.10.1.4"
}

variable "dc_vm_size" {
  description = "VM size for Domain Controller (e.g., Standard_D2s_v5 for production workloads)"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "dc_enable_public_ip" {
  description = "Enable public IP for DC (Recommended: false for prod, use Azure Bastion)"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Fully qualified domain name (FQDN) for Active Directory (e.g., corp.contoso.com)"
  type        = string
  default     = "corp.contoso.com"
}

variable "domain_admin_username" {
  description = "Domain administrator username"
  type        = string
  default     = "domainadmin"
}

variable "domain_admin_password" {
  description = "Domain administrator password (PRODUCTION: Use Azure Key Vault!)"
  type        = string
  sensitive   = true
  # In production, reference from Key Vault instead of hardcoding
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ AZURE VIRTUAL DESKTOP - Workspace, host pool, and user configuration      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "workspace_friendly_name" {
  description = "Display name for the AVD workspace shown to users"
  type        = string
  default     = "Production AVD Workspace"
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
  description = "Load balancing: 'BreadthFirst' (spread users) or 'DepthFirst' (fill hosts first)"
  type        = string
  default     = "DepthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.load_balancer_type)
    error_message = "Load balancer type must be 'BreadthFirst' or 'DepthFirst'."
  }
}

variable "hostpool_friendly_name" {
  description = "Display name for the AVD host pool"
  type        = string
  default     = "Production Host Pool"
}

variable "maximum_sessions_allowed" {
  description = "Maximum concurrent user sessions per session host (only for Pooled type)"
  type        = number
  default     = 15
}

variable "app_group_friendly_name" {
  description = "Display name for the desktop application group"
  type        = string
  default     = "Production Desktop"
}

variable "avd_users" {
  description = "List of user principal names (UPNs) to grant AVD access (must exist in Azure AD)"
  type        = list(string)
  # Configure in terraform.tfvars
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ SESSION HOSTS - AVD virtual machines for user sessions                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "session_host_count" {
  description = "Number of session host VMs to deploy (scale based on concurrent users)"
  type        = number
  default     = 5
}

variable "session_host_vm_size" {
  description = "VM SKU for session hosts (e.g., Standard_D4s_v5=4vCPU/16GB for production)"
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
  description = "Local administrator password (PRODUCTION: Use Azure Key Vault!)"
  type        = string
  sensitive   = true
  # In production, reference from Key Vault instead of hardcoding
}

variable "timezone" {
  description = "Timezone for VMs (e.g., 'UTC', 'Eastern Standard Time', 'Pacific Standard Time')"
  type        = string
  default     = "UTC"
}

# Image Configuration
variable "image_publisher" {
  description = "VM image publisher for session hosts"
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "image_offer" {
  description = "VM image offer for session hosts (e.g., 'windows-11', 'windows-10', 'office-365')"
  type        = string
  default     = "windows-11"
}

variable "image_sku" {
  description = "VM image SKU (e.g., 'win11-22h2-avd', 'win11-23h2-avd', 'win10-22h2-avd-m365')"
  type        = string
  default     = "win11-22h2-avd"
}

variable "image_version" {
  description = "VM image version ('latest' for most recent)"
  type        = string
  default     = "latest"
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ FSLOGIX & STORAGE - User profile storage configuration                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "fslogix_share_name" {
  description = "Name of the Azure Files share for FSLogix user profiles"
  type        = string
  default     = "user-profiles"
}

variable "fslogix_share_quota_gb" {
  description = "Storage quota in GB (estimate 30-50GB per user for profiles)"
  type        = number
  default     = 500
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║ SECURITY & DIAGNOSTICS - Monitoring and security features (future)        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Add variables here for:
# - Log Analytics workspace integration
# - Azure Monitor configuration
# - Backup policies
# - Azure Bastion deployment (recommended for production)
# - Network Watcher
# - Azure Security Center settings
