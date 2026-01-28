# Quick Configuration Guide

##  Where to Find Configuration Settings

All adjustable variables are surfaced in **three easy-to-find locations**:

### 1. **terraform.tfvars.example** (Copy to terraform.tfvars)
- **Most commonly edited settings at the top**
- Credentials ( change immediately!)
- Domain configuration
- VM counts and sizes
- Storage SKU and capacity

### 2. **variables.tf** (All user-facing inputs with defaults)
- Complete list of all configurable variables
- Organized by functional area (Basics, Networking, Domain, AVD, etc.)
- Each variable has description and default value
- Sensitive variables marked with `sensitive = true`

### 3. **main.tf locals block** (Quick reference)
- Line 40-110: USER CONFIG section
- Shows how variables map to deployment settings
- Most commonly adjusted knobs grouped at top
- Deployment order and dependency explanation

---

##  Most Commonly Edited Settings

| Setting | Where to Change | Purpose |
|---------|----------------|---------|
| **Passwords** | `terraform.tfvars` | Domain admin & local admin credentials |
| **Domain Name** | `terraform.tfvars` | AD DS domain (e.g., avd.local) |
| **VM Sizes** | `terraform.tfvars` | DC size, session host size |
| **Session Host Count** | `terraform.tfvars` | Number of AVD VMs (scale based on users) |
| **Storage SKU** | `terraform.tfvars` | Premium (prod) vs Standard (dev) |
| **Network CIDRs** | `terraform.tfvars` | VNet and subnet address spaces |
| **Azure Region** | `terraform.tfvars` | Location for all resources |

---

##  Sensitive Values

Sensitive variables are **marked in variables.tf** with `sensitive = true`:

```hcl
variable "domain_admin_password" {
  description = "Domain administrator password"
  type        = string
  sensitive   = true  # ← Protects from console output
}
```

**Best Practice for Production:**
1. **Use Azure Key Vault** to store passwords
2. Uncomment Key Vault data sources in `main.tf` (lines 35-55)
3. Reference secrets: `data.azurerm_key_vault_secret.domain_admin_password.value`
4. Never commit `terraform.tfvars` to version control

See `main.tf` for complete Key Vault integration example.

---

##  Variable Organization in variables.tf

Variables are organized by functional area with visual separators:

```
╔═══════════════════════════════════════════════════════╗
║ BASICS - Core project settings                        ║
╚═══════════════════════════════════════════════════════╝
  - environment, location, project_name, tags

╔═══════════════════════════════════════════════════════╗
║ NETWORKING - VNet and subnet configuration            ║
╚═══════════════════════════════════════════════════════╝
  - vnet_address_space, subnet_prefixes

╔═══════════════════════════════════════════════════════╗
║ DOMAIN CONTROLLER & ACTIVE DIRECTORY                  ║
╚═══════════════════════════════════════════════════════╝
  - domain_name, dc_private_ip, dc_vm_size, credentials

╔═══════════════════════════════════════════════════════╗
║ AZURE VIRTUAL DESKTOP - Host pool and workspace       ║
╚═══════════════════════════════════════════════════════╝
  - hostpool_type, load_balancer_type, max_sessions

╔═══════════════════════════════════════════════════════╗
║ SESSION HOSTS - AVD VMs configuration                 ║
╚═══════════════════════════════════════════════════════╝
  - vm_count, vm_size, image (publisher/offer/sku)

╔═══════════════════════════════════════════════════════╗
║ FSLOGIX & STORAGE - User profile storage              ║
╚═══════════════════════════════════════════════════════╝
  - storage_account_tier, share_quota_gb, replication

╔═══════════════════════════════════════════════════════╗
║ SECURITY & DIAGNOSTICS - Monitoring and logging       ║
╚═══════════════════════════════════════════════════════╝
  - enable_diagnostics, log_analytics_workspace_id
```

---

##  Configuration Flow

```
terraform.tfvars          →  variables.tf        →  main.tf locals  →  Modules
(Your values)                (Defaults &             (Computed          (Infrastructure)
                             descriptions)            values)
                              
domain_name = "avd.local" → variable "domain_name" → local.domain_name → module.domain_controller
```

---

##  Quick Start Checklist

- [ ] 1. Copy `terraform.tfvars.example` to `terraform.tfvars`
- [ ] 2. **Change passwords** (domain_admin_password, session_host_local_admin_password)
- [ ] 3. Set **domain_name** (e.g., "corp.contoso.com")
- [ ] 4. Set **location** (e.g., "eastus", "westeurope")
- [ ] 5. Adjust **session_host_count** based on user count
- [ ] 6. Review **storage_account_tier** (Standard for dev, Premium for prod)
- [ ] 7. Add **avd_users** (Azure AD user principal names)
- [ ] 8. Review network CIDRs if conflicts exist with on-premises
- [ ] 9. Run `terraform init`
- [ ] 10. Run `terraform plan` and review
- [ ] 11. Run `terraform apply`

---

##  Tips

### Finding a Specific Setting
1. **Search variables.tf** - All inputs documented with descriptions
2. **Check terraform.tfvars.example** - Common settings with examples
3. **Review main.tf locals** - See how variables are used

### Understanding Module Inputs
Each module has its own `variables.tf` with complete documentation:
- `modules/domain-controller/variables.tf` - DC configuration
- `modules/avd_core/variables.tf` - AVD workspace/host pool
- `modules/session-hosts/variables.tf` - Session host VMs
- `modules/fslogix_storage/variables.tf` - Storage configuration

**All module inputs are surfaced to environment-level variables.tf** - nothing is hidden!

### Overriding Defaults
You only need to set values in `terraform.tfvars` if you want to override the defaults from `variables.tf`.

---

##  Additional Documentation

- **README.md** - Complete deployment guide, GPO strategy, validation
- **modules/*/README.md** - Module-specific documentation
- **modules/domain-controller/README.md** - AD DS setup, OU creation
- **modules/fslogix_storage/README.md** - Azure Files AD DS authentication

---

##  Deployment Order (Automatic)

The deployment order is **automatically handled** by Terraform `depends_on`:

1. **Networking** - VNet created with empty DNS (avoids circular dependency)
2. **Domain Controller** - AD DS installed, creates OU=AVD-SessionHosts
3. **DNS Update** - VNet DNS updated to point to DC (via null_resource + Azure CLI)
4. **FSLogix Storage** - Azure Files for profiles (parallel with AVD Core)
5. **AVD Core** - Workspace, host pool, app groups (parallel with storage)
6. **Session Hosts** - Domain-joined VMs with AVD agent (waits for all above)

**Why this order?**
- Session hosts **must** resolve domain names → need VNet DNS pointing to DC
- Domain join **requires** DC with AD DS running and OU created
- No circular dependencies: DC doesn't need to know about session hosts upfront

---

##  Important Notes

### AD DS Domain Join (Not Entra ID-only)
This playbook uses **traditional AD DS domain join** because:
-  Group Policy (GPO) management for session hosts
-  Azure Files authentication via AD DS integration (Kerberos)
-  NTFS permissions for FSLogix profile folders
-  OU placement for targeted GPO application

### Avoiding Circular Dependencies
- **VNet DNS** starts empty (doesn't reference DC IP in initial deployment)
- **null_resource** updates VNet DNS after DC is deployed
- **Session hosts** wait for DNS update via `depends_on`

### Sensitive Values
- All passwords marked `sensitive = true` in variables.tf
- Terraform won't display sensitive values in console output
- Use Azure Key Vault for production (see main.tf example)
