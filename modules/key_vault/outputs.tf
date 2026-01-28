# ============================================================================
# Key Vault Module - Outputs
# ============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# KEY VAULT RESOURCE
# ─────────────────────────────────────────────────────────────────────────────

output "key_vault_id" {
  description = "Resource ID of the Key Vault"
  value       = var.enabled ? azurerm_key_vault.kv[0].id : null
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = var.enabled ? azurerm_key_vault.kv[0].name : null
}

output "key_vault_uri" {
  description = "URI of the Key Vault (e.g., https://my-keyvault.vault.azure.net/)"
  value       = var.enabled ? azurerm_key_vault.kv[0].vault_uri : null
}

# ─────────────────────────────────────────────────────────────────────────────
# SECRET VALUES - Used by other modules (domain-controller, session-hosts)
# ─────────────────────────────────────────────────────────────────────────────

output "domain_admin_password" {
  description = "Domain administrator password retrieved from Key Vault. Pass this to domain-controller module."
  value       = var.enabled ? azurerm_key_vault_secret.domain_admin_password[0].value : ""
  sensitive   = true
}

output "local_admin_password" {
  description = "Local administrator password retrieved from Key Vault. Pass this to session-hosts module."
  value       = var.enabled ? azurerm_key_vault_secret.local_admin_password[0].value : ""
  sensitive   = true
}

# ─────────────────────────────────────────────────────────────────────────────
# SECRET METADATA
# ─────────────────────────────────────────────────────────────────────────────

output "domain_admin_password_secret_id" {
  description = "Full resource ID of domain admin password secret"
  value       = var.enabled ? azurerm_key_vault_secret.domain_admin_password[0].id : null
}

output "local_admin_password_secret_id" {
  description = "Full resource ID of local admin password secret"
  value       = var.enabled ? azurerm_key_vault_secret.local_admin_password[0].id : null
}

output "domain_admin_password_secret_version" {
  description = "Version ID of domain admin password secret (changes when secret is updated)"
  value       = var.enabled ? azurerm_key_vault_secret.domain_admin_password[0].version : null
}

output "local_admin_password_secret_version" {
  description = "Version ID of local admin password secret (changes when secret is updated)"
  value       = var.enabled ? azurerm_key_vault_secret.local_admin_password[0].version : null
}

# ─────────────────────────────────────────────────────────────────────────────
# ADDITIONAL SECRETS
# ─────────────────────────────────────────────────────────────────────────────

output "additional_secret_ids" {
  description = "Map of additional secret names to their resource IDs"
  value       = var.enabled ? { for k, v in azurerm_key_vault_secret.automation_secrets : k => v.id } : {}
}

output "additional_secret_versions" {
  description = "Map of additional secret names to their version IDs"
  value       = var.enabled ? { for k, v in azurerm_key_vault_secret.automation_secrets : k => v.version } : {}
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

output "purge_protection_enabled" {
  description = "Whether purge protection is enabled (true = Key Vault cannot be permanently deleted)"
  value       = var.enabled ? azurerm_key_vault.kv[0].purge_protection_enabled : null
}

output "soft_delete_retention_days" {
  description = "Number of days deleted secrets are retained (90 days mandatory in Azure)"
  value       = var.enabled ? azurerm_key_vault.kv[0].soft_delete_retention_days : null
}

output "rbac_authorization_enabled" {
  description = "Whether RBAC authorization is enabled (true = using modern RBAC, false = legacy access policies)"
  value       = var.enabled ? azurerm_key_vault.kv[0].enable_rbac_authorization : null
}
