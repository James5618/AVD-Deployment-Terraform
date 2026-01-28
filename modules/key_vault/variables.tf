# ============================================================================
# Key Vault Module - Input Variables
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# REQUIRED VARIABLES
# ─────────────────────────────────────────────────────────────────────────────

variable "key_vault_name" {
  description = "Name of the Azure Key Vault. Must be globally unique (3-24 chars, alphanumeric and hyphens). Example: avd-dev-kv-abc123"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,24}$", var.key_vault_name))
    error_message = "Key Vault name must be 3-24 characters, alphanumeric and hyphens only."
  }
}

variable "location" {
  description = "Azure region where Key Vault will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where Key Vault will be created"
  type        = string
}

# ─────────────────────────────────────────────────────────────────────────────
# PASSWORD CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "auto_generate_passwords" {
  description = "Auto-generate secure 24-character passwords for domain admin and local admin. If false, you must provide domain_admin_password and local_admin_password variables."
  type        = bool
  default     = true
}

variable "domain_admin_password" {
  description = "Domain administrator password. Only required if auto_generate_passwords = false. Leave empty to auto-generate. Store this value in terraform.tfvars (NOT committed to git)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "local_admin_password" {
  description = "Session host local administrator password. Only required if auto_generate_passwords = false. Leave empty to auto-generate."
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain_admin_password_secret_name" {
  description = "Name of the Key Vault secret for domain administrator password"
  type        = string
  default     = "domain-admin-password"
}

variable "local_admin_password_secret_name" {
  description = "Name of the Key Vault secret for local administrator password"
  type        = string
  default     = "local-admin-password"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

variable "purge_protection_enabled" {
  description = "Enable purge protection (prevents permanent deletion of Key Vault and secrets). Recommended for production. WARNING: Once enabled, cannot be disabled!"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Allow public network access to Key Vault. Set to false and use private endpoint for production."
  type        = bool
  default     = true
}

variable "network_default_action" {
  description = "Default network action for Key Vault firewall. 'Deny' requires IP allowlist or private endpoint. 'Allow' permits all traffic (not recommended for production)."
  type        = string
  default     = "Allow"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "network_default_action must be either 'Allow' or 'Deny'."
  }
}

variable "allowed_ip_ranges" {
  description = "List of IP address ranges (CIDR notation) allowed to access Key Vault. Only applies when network_default_action = 'Deny'. Example: ['203.0.113.0/24']"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────────────────────
# ADDITIONAL SECRETS
# ─────────────────────────────────────────────────────────────────────────────

variable "additional_secrets" {
  description = "Map of additional secrets to store in Key Vault. Key = secret name, Value = secret value. Example: { 'service-principal-secret' = 'abc123', 'api-key' = 'xyz789' }"
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────────────────────
# FEATURE TOGGLES
# ─────────────────────────────────────────────────────────────────────────────

variable "enabled" {
  description = "Enable Key Vault deployment. Set to false to skip Key Vault creation and use plaintext passwords (NOT recommended)."
  type        = bool
  default     = true
}

# ─────────────────────────────────────────────────────────────────────────────
# TAGS
# ─────────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to Key Vault and secrets"
  type        = map(string)
  default     = {}
}
