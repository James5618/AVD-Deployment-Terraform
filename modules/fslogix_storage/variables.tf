# ============================================================================
# FSLogix Storage Module - Variables
# ============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# CORE CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 lowercase alphanumeric)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase alphanumeric characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group for storage resources"
  type        = string
}

variable "location" {
  description = "Azure region for storage account"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., 'dev', 'prod', 'staging')"
  type        = string
  default     = "dev"
}

# ──────────────────────────────────────────────────────────────────────────────
# STORAGE ACCOUNT CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "storage_account_tier" {
  description = "Storage account tier: 'Standard' (good for most) or 'Premium' (low latency, higher cost)"
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage tier must be 'Standard' or 'Premium'."
  }
}

variable "storage_replication_type" {
  description = "Replication type: LRS (cheapest), ZRS (zone redundant), GRS (geo-redundant)"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.storage_replication_type)
    error_message = "Replication type must be LRS, ZRS, GRS, or GZRS."
  }
}

variable "storage_account_kind" {
  description = "Storage account kind: 'FileStorage' (Premium only) or 'StorageV2' (Standard)"
  type        = string
  default     = "FileStorage"
  validation {
    condition     = contains(["FileStorage", "StorageV2"], var.storage_account_kind)
    error_message = "Account kind must be 'FileStorage' or 'StorageV2'."
  }
}

variable "enable_shared_access_key" {
  description = "Enable storage account key access (disable for enhanced security, requires Azure AD auth)"
  type        = bool
  default     = true
}

# ──────────────────────────────────────────────────────────────────────────────
# FILE SHARE CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "file_share_quota_gb" {
  description = "File share size in GB (Premium: 100-102400, Standard: 1-102400)"
  type        = number
  default     = 100
  validation {
    condition     = var.file_share_quota_gb >= 1 && var.file_share_quota_gb <= 102400
    error_message = "File share quota must be between 1 and 102400 GB."
  }
}

variable "file_share_access_tier" {
  description = "Access tier for Premium file shares: 'Premium', 'Hot', 'Cool', 'TransactionOptimized'"
  type        = string
  default     = "Premium"
  validation {
    condition     = contains(["Premium", "Hot", "Cool", "TransactionOptimized"], var.file_share_access_tier)
    error_message = "Access tier must be Premium, Hot, Cool, or TransactionOptimized."
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# NETWORK SECURITY
# ──────────────────────────────────────────────────────────────────────────────

variable "enable_private_endpoint" {
  description = "Enable private endpoint for Azure Files (recommended for production)"
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint (required if enable_private_endpoint = true)"
  type        = string
  default     = ""
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for privatelink.file.core.windows.net (leave empty to skip DNS integration)"
  type        = string
  default     = ""
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access storage account (for public access scenarios)"
  type        = list(string)
  default     = []
}

variable "allowed_ip_addresses" {
  description = "List of IP addresses/CIDR ranges allowed to access storage account"
  type        = list(string)
  default     = []
}

# ──────────────────────────────────────────────────────────────────────────────
# AD DS AUTHENTICATION CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "enable_ad_authentication" {
  description = "Enable AD DS authentication for Azure Files (requires manual domain join - see README)"
  type        = bool
  default     = false
}

variable "ad_domain_name" {
  description = "AD domain FQDN for storage account authentication (e.g., 'contoso.local')"
  type        = string
  default     = ""
}

variable "ad_domain_guid" {
  description = "AD domain GUID (required for AD DS auth - obtain via PowerShell, see README)"
  type        = string
  default     = ""
}

variable "ad_domain_sid" {
  description = "AD domain SID (required for AD DS auth - obtain via PowerShell, see README)"
  type        = string
  default     = ""
}

variable "ad_forest_name" {
  description = "AD forest name (usually same as domain name)"
  type        = string
  default     = ""
}

variable "ad_netbios_domain_name" {
  description = "AD NetBIOS domain name (e.g., 'CONTOSO')"
  type        = string
  default     = ""
}

# ──────────────────────────────────────────────────────────────────────────────
# DIAGNOSTICS AND MONITORING
# ──────────────────────────────────────────────────────────────────────────────

variable "enable_diagnostics" {
  description = "Enable diagnostics logging to Log Analytics"
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics (required if enable_diagnostics = true)"
  type        = string
  default     = ""
}

# ──────────────────────────────────────────────────────────────────────────────
# RBAC AND ACCESS CONTROL
# ──────────────────────────────────────────────────────────────────────────────

variable "session_host_principal_ids" {
  description = "List of session host managed identity principal IDs (for RBAC)"
  type        = list(string)
  default     = []
}

variable "avd_users_group_id" {
  description = "Azure AD group object ID for AVD users (recommended for user profile access)"
  type        = string
  default     = ""
}

variable "additional_contributor_principal_ids" {
  description = "Additional principal IDs to grant Storage File Data SMB Share Contributor role"
  type        = list(string)
  default     = []
}

# ──────────────────────────────────────────────────────────────────────────────
# TAGS
# ──────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to all storage resources"
  type        = map(string)
  default     = {}
}
