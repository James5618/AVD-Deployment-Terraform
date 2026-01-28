# ============================================================================
# AVD Core Module - Variables
# ============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# CORE CONFIGURATION - Simple, user-friendly variables
# ──────────────────────────────────────────────────────────────────────────────

variable "prefix" {
  description = "Naming prefix for AVD resources (e.g., 'avd', 'vdi')"
  type        = string
  default     = "avd"
}

variable "env" {
  description = "Environment name (e.g., 'dev', 'prod', 'staging')"
  type        = string
}

variable "location" {
  description = "Azure region for AVD resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for AVD resources"
  type        = string
}

# ──────────────────────────────────────────────────────────────────────────────
# HOST POOL CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "host_pool_name" {
  description = "Name of the host pool (leave empty for auto-generated name based on prefix-env-hp)"
  type        = string
  default     = ""
}

variable "max_sessions" {
  description = "Maximum number of concurrent sessions per session host"
  type        = number
  default     = 10
  validation {
    condition     = var.max_sessions >= 1 && var.max_sessions <= 999999
    error_message = "Maximum sessions must be between 1 and 999999."
  }
}

variable "load_balancer_type" {
  description = "Load balancing algorithm: 'BreadthFirst' (spread users) or 'DepthFirst' (fill hosts)"
  type        = string
  default     = "BreadthFirst"
  validation {
    condition     = contains(["BreadthFirst", "DepthFirst"], var.load_balancer_type)
    error_message = "Load balancer type must be 'BreadthFirst' or 'DepthFirst'."
  }
}

variable "start_vm_on_connect" {
  description = "Enable Start VM on Connect feature (requires Azure Power Management permissions)"
  type        = bool
  default     = true
}

variable "custom_rdp_properties" {
  description = "Custom RDP properties for the host pool"
  type        = string
  default     = "audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2"
}

# ──────────────────────────────────────────────────────────────────────────────
# USER ACCESS CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "user_group_object_id" {
  description = "Azure AD group object ID for AVD users (leave empty to skip role assignment)"
  type        = string
  default     = ""
}

# ──────────────────────────────────────────────────────────────────────────────
# REGISTRATION TOKEN CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "registration_token_ttl_hours" {
  description = "Registration token time-to-live in hours (e.g., '48h', '720h')"
  type        = string
  default     = "48h"
}

# ──────────────────────────────────────────────────────────────────────────────
# OPTIONAL - FRIENDLY NAMES AND DESCRIPTIONS
# ──────────────────────────────────────────────────────────────────────────────

variable "workspace_friendly_name" {
  description = "Display name for the AVD workspace"
  type        = string
  default     = "AVD Workspace"
}

variable "workspace_description" {
  description = "Description for the AVD workspace"
  type        = string
  default     = "Azure Virtual Desktop Workspace"
}

variable "host_pool_friendly_name" {
  description = "Display name for the AVD host pool"
  type        = string
  default     = "AVD Host Pool"
}

variable "host_pool_description" {
  description = "Description for the AVD host pool"
  type        = string
  default     = "Azure Virtual Desktop Host Pool"
}

variable "app_group_friendly_name" {
  description = "Display name for the desktop application group"
  type        = string
  default     = "Desktop"
}

variable "app_group_description" {
  description = "Description for the desktop application group"
  type        = string
  default     = "Desktop Application Group"
}

# ──────────────────────────────────────────────────────────────────────────────
# ADVANCED CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────

variable "enable_scheduled_agent_updates" {
  description = "Enable scheduled agent updates (updates on Sundays at 2 AM)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all AVD resources"
  type        = map(string)
  default     = {}
}
