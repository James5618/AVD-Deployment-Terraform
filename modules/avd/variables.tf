# ============================================================================
# AVD Module - Variables
# ============================================================================

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "workspace_name" {
  description = "Name of the AVD workspace"
  type        = string
}

variable "workspace_friendly_name" {
  description = "Friendly name for the AVD workspace"
  type        = string
  default     = "AVD Workspace"
}

variable "workspace_description" {
  description = "Description for the AVD workspace"
  type        = string
  default     = "Azure Virtual Desktop Workspace"
}

variable "hostpool_name" {
  description = "Name of the AVD host pool"
  type        = string
}

variable "hostpool_type" {
  description = "Type of host pool (Pooled or Personal)"
  type        = string
  default     = "Pooled"
  validation {
    condition     = contains(["Pooled", "Personal"], var.hostpool_type)
    error_message = "Host pool type must be either 'Pooled' or 'Personal'."
  }
}

variable "load_balancer_type" {
  description = "Load balancer type for the host pool (BreadthFirst or DepthFirst)"
  type        = string
  default     = "BreadthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.load_balancer_type)
    error_message = "Load balancer type must be either 'BreadthFirst' or 'DepthFirst'."
  }
}

variable "hostpool_friendly_name" {
  description = "Friendly name for the AVD host pool"
  type        = string
  default     = "AVD Host Pool"
}

variable "hostpool_description" {
  description = "Description for the AVD host pool"
  type        = string
  default     = "Azure Virtual Desktop Host Pool"
}

variable "custom_rdp_properties" {
  description = "Custom RDP properties for the host pool"
  type        = string
  default     = "audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2"
}

variable "maximum_sessions_allowed" {
  description = "Maximum number of sessions allowed per session host"
  type        = number
  default     = 10
}

variable "app_group_name" {
  description = "Name of the AVD desktop application group"
  type        = string
}

variable "app_group_friendly_name" {
  description = "Friendly name for the AVD desktop application group"
  type        = string
  default     = "Desktop Application Group"
}

variable "app_group_description" {
  description = "Description for the AVD desktop application group"
  type        = string
  default     = "AVD Desktop Application Group"
}

variable "avd_users" {
  description = "List of user principal names to assign to the desktop application group"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
