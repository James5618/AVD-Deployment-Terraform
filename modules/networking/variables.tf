# ============================================================================
# Networking Module - Variables
# ============================================================================

variable "create_resource_group" {
  description = "Whether to create a new resource group (true) or use an existing one (false)"
  type        = bool
  default     = false
}

variable "resource_group_name" {
  description = "Name of the resource group (will be created if create_resource_group=true)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network (CIDR)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "dc_subnet_name" {
  description = "Name of the Domain Controller subnet"
  type        = string
  default     = "snet-dc"
}

variable "dc_subnet_prefix" {
  description = "Address prefix for the Domain Controller subnet (CIDR)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "avd_subnet_name" {
  description = "Name of the AVD session hosts subnet"
  type        = string
  default     = "snet-avd"
}

variable "avd_subnet_prefix" {
  description = "Address prefix for the AVD subnet (CIDR)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "storage_subnet_name" {
  description = "Name of the storage subnet for private endpoints"
  type        = string
  default     = "snet-storage"
}

variable "storage_subnet_prefix" {
  description = "Address prefix for the storage subnet (CIDR)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "dns_servers" {
  description = "List of DNS server IP addresses for the VNet (e.g., DC private IPs). Can be updated after initial deployment without recreating the VNet. Leave empty to use Azure default DNS."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
