# Azure Key Vault Module - Secure Secret Storage

## Overview

This module provisions an Azure Key Vault to securely store sensitive credentials and secrets used throughout your AVD environment. It eliminates the need to store plaintext passwords in configuration files or version control.

**Key Features:**
- **RBAC Authorization**: Modern role-based access control (no legacy access policies)
- **Soft Delete Protection**: Recover accidentally deleted secrets for 90 days
- **Optional Purge Protection**: Prevent permanent deletion (recommended for production)
- **Auto-Generated Passwords**: Create secure 24-character passwords automatically
- **Audit Ready**: Compatible with diagnostic settings for access logging
- **Cost Effective**: ~$0.03/10,000 operations (typically <$5/month)

**Secrets Stored:**
1. **Domain Administrator Password** - Used by domain-controller module for AD DS setup
2. **Local Administrator Password** - Used by session-hosts module for VM provisioning
3. **Additional Automation Secrets** - Store service principal credentials, API keys, etc.

---

## Usage

### Basic Configuration (Auto-Generated Passwords)

```hcl
module "key_vault" {
  source = "../../modules/key_vault"

  key_vault_name      = "avd-dev-kv-abc123"  # Must be globally unique
  location            = "eastus"
  resource_group_name = azurerm_resource_group.rg.name

  # Auto-generate secure 24-character passwords
  auto_generate_passwords = true

  # Security settings
  purge_protection_enabled = false  # Set to true for production
  
  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Use Key Vault outputs in other modules
module "domain_controller" {
  source = "../../modules/domain-controller"
  
  admin_password = module.key_vault.domain_admin_password  # From Key Vault
  # ... other variables
}

module "session_hosts" {
  source = "../../modules/session-hosts"
  
  vm_admin_password = module.key_vault.local_admin_password  # From Key Vault
  # ... other variables
}
```

### Advanced Configuration (Custom Passwords + Additional Secrets)

```hcl
module "key_vault" {
  source = "../../modules/key_vault"

  key_vault_name      = "avd-prod-kv-xyz789"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.rg.name

  # Provide your own passwords (NOT recommended - use auto-generate instead)
  auto_generate_passwords = false
  domain_admin_password   = var.domain_admin_password  # From terraform.tfvars (keep secure!)
  local_admin_password    = var.local_admin_password

  # Store additional automation secrets
  additional_secrets = {
    "service-principal-secret" = var.sp_secret
    "storage-account-key"      = var.storage_key
    "api-key-external-service" = var.api_key
  }

  # Production security settings
  purge_protection_enabled      = true   # Cannot be disabled once enabled!
  public_network_access_enabled = false  # Use private endpoint
  network_default_action        = "Deny"
  allowed_ip_ranges             = ["203.0.113.0/24"]  # Your office IP

  tags = {
    Environment = "production"
    Compliance  = "Required"
  }
}
```

---

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `key_vault_name` | string | Key Vault name (3-24 chars, globally unique). Example: `avd-dev-kv-abc123` |
| `location` | string | Azure region (e.g., `eastus`) |
| `resource_group_name` | string | Resource group name |

### Password Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `auto_generate_passwords` | bool | `true` | Auto-generate secure 24-character passwords. **Recommended!** |
| `domain_admin_password` | string (sensitive) | `""` | Domain admin password (only if `auto_generate_passwords = false`) |
| `local_admin_password` | string (sensitive) | `""` | Local admin password (only if `auto_generate_passwords = false`) |
| `domain_admin_password_secret_name` | string | `"domain-admin-password"` | Secret name in Key Vault |
| `local_admin_password_secret_name` | string | `"local-admin-password"` | Secret name in Key Vault |

### Security Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `purge_protection_enabled` | bool | `false` | Prevent permanent deletion. **Recommended for production**.  Cannot be disabled once enabled! |
| `public_network_access_enabled` | bool | `true` | Allow public access. Set to `false` for production (requires private endpoint) |
| `network_default_action` | string | `"Allow"` | Firewall default action: `Allow` or `Deny` |
| `allowed_ip_ranges` | list(string) | `[]` | IP ranges allowed to access Key Vault (CIDR notation) |

### Additional Secrets

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `additional_secrets` | map(string) | `{}` | Extra secrets to store. Example: `{ "api-key" = "abc123" }` |

### Feature Toggles

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | bool | `true` | Enable Key Vault deployment. Set to `false` to skip (not recommended) |

### Tags

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `tags` | map(string) | `{}` | Tags to apply to Key Vault and secrets |

---

## Outputs

### Key Vault Resource

| Output | Description |
|--------|-------------|
| `key_vault_id` | Resource ID of Key Vault |
| `key_vault_name` | Key Vault name |
| `key_vault_uri` | Key Vault URI (e.g., `https://my-kv.vault.azure.net/`) |

### Secret Values (Sensitive)

| Output | Description |
|--------|-------------|
| `domain_admin_password` | Domain admin password (pass to domain-controller module) |
| `local_admin_password` | Local admin password (pass to session-hosts module) |

### Secret Metadata

| Output | Description |
|--------|-------------|
| `domain_admin_password_secret_id` | Full secret resource ID |
| `local_admin_password_secret_id` | Full secret resource ID |
| `domain_admin_password_secret_version` | Secret version (changes when updated) |
| `local_admin_password_secret_version` | Secret version (changes when updated) |
| `additional_secret_ids` | Map of additional secret IDs |
| `additional_secret_versions` | Map of additional secret versions |

### Security Configuration

| Output | Description |
|--------|-------------|
| `purge_protection_enabled` | Whether purge protection is enabled |
| `soft_delete_retention_days` | Soft delete retention period (90 days) |
| `rbac_authorization_enabled` | Whether RBAC is enabled (always `true`) |

---

## Security Best Practices

### 1. Auto-Generate Passwords  RECOMMENDED

```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  auto_generate_passwords = true  # Let Terraform create secure passwords
  # No need to manage passwords manually!
}
```

**Benefits:**
- 24-character passwords with uppercase, lowercase, numbers, and special characters
- Cryptographically secure random generation
- No human-readable patterns
- Never stored in plaintext files

### 2. Enable Purge Protection for Production

```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  purge_protection_enabled = true  # Production only
}
```

** WARNING**: Once enabled, purge protection **CANNOT** be disabled. This prevents:
- Accidental permanent deletion of Key Vault
- Malicious deletion by compromised accounts
- Data loss from automation errors

**Recommendation**: Enable for production, disable for dev/test (easier cleanup).

### 3. Restrict Network Access

```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  public_network_access_enabled = false  # Block public internet
  # Must use private endpoint for access
}
```

**For Maximum Security (Production):**
- Deploy private endpoint (use Azure Private Link)
- Restrict to corporate network IP ranges
- Use VPN or ExpressRoute for management access

### 4. Grant Least-Privilege RBAC Roles

**Built-in Azure RBAC Roles for Key Vault:**

| Role | Permissions | Use Case |
|------|-------------|----------|
| `Key Vault Secrets Officer` | Create, read, update, delete secrets | **This module** (Terraform identity) |
| `Key Vault Secrets User` | Read secrets only | VMs, applications reading passwords |
| `Key Vault Administrator` | Full Key Vault management | Security team, break-glass accounts |
| `Key Vault Reader` | Read Key Vault metadata (no secret access) | Auditors, compliance team |

**Example - Grant session host VMs read-only access:**

```hcl
# In envs/dev/main.tf
resource "azurerm_role_assignment" "session_hosts_kv_access" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"  # Read-only
  principal_id         = azurerm_windows_virtual_machine.session_host[0].identity[0].principal_id
}
```

### 5. Enable Diagnostic Logging

```hcl
# In logging module or main.tf
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "key-vault-diagnostics"
  target_resource_id         = module.key_vault.key_vault_id
  log_analytics_workspace_id = module.logging.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"  # All secret access, Key Vault operations
  }

  metric {
    category = "AllMetrics"
  }
}
```

**What Gets Logged:**
- All secret read/write/delete operations
- Failed authentication attempts
- RBAC permission denials
- Key Vault configuration changes

### 6. Rotate Passwords Regularly

**Manual Rotation:**
1. Update secret in Key Vault (Azure Portal or CLI)
2. Secret version automatically increments
3. Applications using latest version get new password
4. Old version retained for rollback (soft delete)

**Automated Rotation (Advanced):**
- Use Azure Functions with Key Vault Event Grid integration
- Trigger rotation every 90 days
- Notify admins via email/Teams

**Example - Rotate domain admin password:**
```bash
# Azure CLI
az keyvault secret set \
  --vault-name "avd-dev-kv-abc123" \
  --name "domain-admin-password" \
  --value "NewSecureP@ssw0rd789!"
```

---

## Common Scenarios

### Scenario 1: New Deployment (Recommended)

**Goal**: Deploy AVD with auto-generated passwords stored in Key Vault.

```hcl
# Step 1: Create Key Vault with auto-generated passwords
module "key_vault" {
  source = "../../modules/key_vault"
  
  key_vault_name          = "avd-dev-kv-${random_string.suffix.result}"
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  auto_generate_passwords = true  # Auto-generate
  
  tags = var.common_tags
}

# Step 2: Use Key Vault passwords in other modules
module "domain_controller" {
  source = "../../modules/domain-controller"
  
  admin_password = module.key_vault.domain_admin_password  # From Key Vault
  # ... other variables
  
  depends_on = [module.key_vault]  # Wait for Key Vault
}

module "session_hosts" {
  source = "../../modules/session-hosts"
  
  vm_admin_password = module.key_vault.local_admin_password  # From Key Vault
  # ... other variables
  
  depends_on = [module.key_vault]
}
```

**Benefits:**
- No passwords in `terraform.tfvars`
- No passwords in state files (only references)
- Passwords never exposed to users
- Full audit trail

### Scenario 2: Migrate Existing Deployment

**Goal**: Move existing plaintext passwords to Key Vault.

```hcl
# Step 1: Create Key Vault with EXISTING passwords
module "key_vault" {
  source = "../../modules/key_vault"
  
  key_vault_name          = "avd-prod-kv-xyz789"
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  
  # Import existing passwords
  auto_generate_passwords = false
  domain_admin_password   = var.domain_admin_password  # From current terraform.tfvars
  local_admin_password    = var.local_admin_password
  
  tags = var.common_tags
}

# Step 2: Update other modules to use Key Vault
module "domain_controller" {
  source = "../../modules/domain-controller"
  
  admin_password = module.key_vault.domain_admin_password  # Now from Key Vault
  # ... other variables
}

# Step 3: After deployment, remove passwords from terraform.tfvars
# Keep them only in Key Vault!
```

### Scenario 3: Store Service Principal Credentials

**Goal**: Store Azure DevOps service principal secret for automation.

```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  key_vault_name      = "avd-automation-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # Store automation secrets
  additional_secrets = {
    "azure-devops-sp-secret" = var.service_principal_secret
    "github-pat-token"       = var.github_token
    "api-key-monitoring"     = var.monitoring_api_key
  }
  
  tags = { Purpose = "Automation" }
}

# Reference in Azure DevOps variable group
output "service_principal_secret_id" {
  value = module.key_vault.additional_secret_ids["azure-devops-sp-secret"]
}
```

### Scenario 4: Production with Private Endpoint

**Goal**: Secure production Key Vault with private networking.

```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  key_vault_name      = "avd-prod-kv-secure"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
  # Maximum security settings
  purge_protection_enabled      = true   # Cannot delete permanently
  public_network_access_enabled = false  # No public internet access
  network_default_action        = "Deny" # Whitelist only
  
  tags = { Compliance = "SOC2" }
}

# Create private endpoint
resource "azurerm_private_endpoint" "kv" {
  name                = "avd-prod-kv-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "kv-privatelink"
    private_connection_resource_id = module.key_vault.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}
```

---

## Cost Estimation

### Key Vault Pricing (Standard Tier)

| Component | Price | Typical Monthly Cost |
|-----------|-------|---------------------|
| **Secret Operations** | $0.03 per 10,000 operations | **$0.60 - $3.00** |
| **Secret Storage** | $0.03 per secret per month | **$0.06 - $0.30** |
| **Certificate Operations** | $3.00 per renewal | **$0.00** (not used) |
| **HSM Protected Keys** | Not used (Standard tier) | **$0.00** |
| **Total (Typical)** | — | **$1 - $5/month** |

**Cost Breakdown Example (Dev Environment):**
- 2 secrets (domain admin, local admin): $0.06/month
- 1000 operations/month (Terraform, VMs): $0.03/month
- **Total**: ~$0.09/month (~$1/year) 

**Cost Breakdown Example (Production Environment):**
- 10 secrets (passwords, API keys, certificates): $0.30/month
- 50,000 operations/month (frequent access): $0.15/month
- **Total**: ~$0.45/month (~$5/year) 

**Operations Counted:**
- Secret creation, update, deletion
- Secret reads (get secret value)
- List secrets, get secret versions
- RBAC operations (not counted separately)

**Cost Optimization Tips:**
- Cache secret values in applications (reduce read operations)
- Use managed identities instead of service principals (fewer secret rotations)
- Avoid polling Key Vault frequently (use webhooks/Event Grid)

---

## Monitoring & Compliance

### View Secrets in Azure Portal

1. Navigate to Key Vault → **Secrets**
2. Click secret name (e.g., `domain-admin-password`)
3. Click **Current Version** to view metadata (NOT the secret value)
4. Click **Show Secret Value** (requires `Key Vault Secrets User` role or higher)

**Security Note**: Secret access is logged in diagnostic logs. Every "Show Secret Value" click creates an audit event.

### Retrieve Secrets via Azure CLI

```bash
# List all secrets
az keyvault secret list --vault-name "avd-dev-kv-abc123" --output table

# Get secret value
az keyvault secret show \
  --vault-name "avd-dev-kv-abc123" \
  --name "domain-admin-password" \
  --query "value" \
  --output tsv

# Get secret metadata (without value)
az keyvault secret show \
  --vault-name "avd-dev-kv-abc123" \
  --name "domain-admin-password" \
  --query "{name:name, version:id, created:attributes.created}"
```

### Retrieve Secrets via PowerShell

```powershell
# List all secrets
Get-AzKeyVaultSecret -VaultName "avd-dev-kv-abc123"

# Get secret value (returns SecureString)
$secret = Get-AzKeyVaultSecret -VaultName "avd-dev-kv-abc123" -Name "domain-admin-password"
$plaintext = $secret.SecretValue | ConvertFrom-SecureString -AsPlainText

# Get secret metadata
Get-AzKeyVaultSecret -VaultName "avd-dev-kv-abc123" -Name "domain-admin-password" | 
  Select-Object Name, Version, Created, Updated, Enabled
```

### Query Audit Logs

```kql
// Key Vault audit logs (Log Analytics workspace)
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where Category == "AuditEvent"
| project TimeGenerated, OperationName, CallerIPAddress, identity_claim_upn_s, ResultSignature
| order by TimeGenerated desc
| take 100

// Secret access by specific user
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.KEYVAULT"
| where OperationName == "SecretGet"
| where identity_claim_upn_s contains "john.doe@company.com"
| project TimeGenerated, id_s, CallerIPAddress, ResultSignature
```

---

## Troubleshooting

### Issue: "403 Forbidden" when creating secrets

**Symptoms:**
```
Error: Insufficient privileges to access Key Vault 'avd-dev-kv-abc123'
Error: The user, service principal, or managed identity does not have secrets set permission
```

**Cause**: RBAC assignment hasn't propagated (can take 1-2 minutes).

**Solution 1** - Wait and retry:
```bash
terraform apply  # Wait 60 seconds, try again
```

**Solution 2** - Increase propagation delay:
```hcl
# In modules/key_vault/main.tf
resource "time_sleep" "rbac_propagation" {
  create_duration = "120s"  # Increase to 2 minutes
}
```

**Solution 3** - Manual RBAC assignment:
```bash
# Get your identity object ID
OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Assign Key Vault Secrets Officer role
az role assignment create \
  --assignee "$OBJECT_ID" \
  --role "Key Vault Secrets Officer" \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kv-name}"
```

### Issue: Key Vault name already exists

**Symptoms:**
```
Error: A vault with the same name already exists in deleted state
Error: Key Vault name 'avd-dev-kv-abc123' is not available
```

**Cause**: Key Vault was deleted but is in soft-delete state (90-day retention).

**Solution 1** - Recover deleted Key Vault:
```bash
az keyvault recover --name "avd-dev-kv-abc123"
```

**Solution 2** - Purge deleted Key Vault (if purge protection disabled):
```bash
az keyvault purge --name "avd-dev-kv-abc123"
```

**Solution 3** - Use different name:
```hcl
key_vault_name = "avd-dev-kv-${random_string.suffix.result}"  # Generate unique suffix
```

### Issue: Cannot access Key Vault from VM

**Symptoms:**
- VM cannot retrieve secrets from Key Vault
- Error: "Network access denied"

**Cause**: Network firewall blocking VM subnet.

**Solution 1** - Allow VM subnet:
```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  network_default_action = "Deny"
  allowed_ip_ranges      = []  # Not for subnets!
  # Need to add subnet exception separately
}

# Add subnet exception
resource "azurerm_key_vault_network_acl" "allow_vm_subnet" {
  key_vault_id = module.key_vault.key_vault_id
  
  default_action             = "Deny"
  bypass                     = "AzureServices"
  virtual_network_subnet_ids = [azurerm_subnet.avd_subnet.id]
}
```

**Solution 2** - Enable public access (dev only):
```hcl
module "key_vault" {
  source = "../../modules/key_vault"
  
  public_network_access_enabled = true
  network_default_action        = "Allow"  # Allow all (not recommended for prod)
}
```

**Solution 3** - Use private endpoint:
```hcl
# Create private endpoint for Key Vault
resource "azurerm_private_endpoint" "kv" {
  name                = "kv-private-endpoint"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "kv-privatelink"
    private_connection_resource_id = module.key_vault.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}
```

### Issue: Purge protection cannot be disabled

**Symptoms:**
```
Error: Purge protection cannot be disabled once enabled
```

**Cause**: This is BY DESIGN for security. Once enabled, purge protection is permanent.

**Solution**: If you need to delete the Key Vault:
1. Delete the Key Vault (enters soft-delete state for 90 days)
2. Wait 90 days for automatic purge
3. **OR** Contact Azure support to request early purge (requires justification)

**Prevention**: Only enable purge protection in production environments.

### Issue: Secret not found after creation

**Symptoms:**
```
Error: Secret "domain-admin-password" not found in Key Vault
```

**Cause**: Secret created but module trying to read before RBAC propagation.

**Solution** - Add explicit dependency:
```hcl
module "domain_controller" {
  source = "../../modules/domain-controller"
  
  admin_password = module.key_vault.domain_admin_password
  
  depends_on = [module.key_vault]  # Wait for Key Vault module to complete
}
```

---

## Best Practices Summary

###  DO

- **Auto-generate passwords** (`auto_generate_passwords = true`)
- **Enable purge protection for production** (`purge_protection_enabled = true`)
- **Restrict network access** (private endpoint or IP allowlist)
- **Use RBAC** for access control (module does this automatically)
- **Enable diagnostic logging** to audit all secret access
- **Rotate passwords regularly** (every 90 days minimum)
- **Use managed identities** for VMs accessing Key Vault (avoids storing credentials)
- **Tag secrets** for compliance tracking (`tags = { Compliance = "PCI-DSS" }`)

###  DON'T

- **Don't store passwords in terraform.tfvars** (defeats the purpose!)
- **Don't commit Key Vault secrets to git** (use `.gitignore`)
- **Don't use legacy access policies** (this module uses RBAC)
- **Don't grant excessive RBAC roles** (use `Key Vault Secrets User` for read-only)
- **Don't expose Key Vault publicly in production** (use private endpoint)
- **Don't disable soft delete** (mandatory in Azure anyway)
- **Don't enable purge protection in dev/test** (makes cleanup difficult)

---

## Integration with Other Modules

### Domain Controller Module

```hcl
module "domain_controller" {
  source = "../../modules/domain-controller"
  
  admin_password = module.key_vault.domain_admin_password  # From Key Vault
  # ... other variables
  
  depends_on = [module.key_vault]
}
```

### Session Hosts Module

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"
  
  vm_admin_password = module.key_vault.local_admin_password  # From Key Vault
  domain_join_password = module.key_vault.domain_admin_password
  # ... other variables
  
  depends_on = [module.key_vault]
}
```

### Logging Module (Diagnostic Settings)

```hcl
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "key-vault-diagnostics"
  target_resource_id         = module.key_vault.key_vault_id
  log_analytics_workspace_id = module.logging.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"  # All Key Vault operations
  }

  metric {
    category = "AllMetrics"
  }
}
```

---

## Additional Resources

- [Azure Key Vault Documentation](https://docs.microsoft.com/azure/key-vault/)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/azure/key-vault/general/best-practices)
- [Azure RBAC for Key Vault](https://docs.microsoft.com/azure/key-vault/general/rbac-guide)
- [Key Vault Soft Delete Overview](https://docs.microsoft.com/azure/key-vault/general/soft-delete-overview)
- [Key Vault Pricing](https://azure.microsoft.com/pricing/details/key-vault/)

---

## Support

For issues or questions:
1. Check **Troubleshooting** section above
2. Review Azure Key Vault diagnostic logs
3. Verify RBAC role assignments
4. Ensure network access is configured correctly

**Common Commands:**
```bash
# Test Key Vault access
az keyvault secret list --vault-name "avd-dev-kv-abc123"

# Check RBAC assignments
az role assignment list --scope "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kv-name}"

# View diagnostic logs
az monitor diagnostic-settings list --resource "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{kv-name}"
```
