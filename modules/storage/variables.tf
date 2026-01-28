# ============================================================================
# Storage Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 chars, lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase letters and numbers only."
  }
}

variable "share_name" {
  description = "Name of the Azure Files share"
  type        = string
  default     = "user-profiles"
}

variable "share_quota_gb" {
  description = "Quota size in GB for the Azure Files share"
  type        = number
  default     = 100
}

variable "subnet_id" {
  description = "ID of the subnet for the private endpoint"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network for private DNS zone link"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
