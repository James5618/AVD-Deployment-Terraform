# Quick Reference Card - Configuration at a Glance

## Where Do I Change...?

| What I Want to Change | File | Variable Name | Line # |
|----------------------|------|---------------|--------|
| **Passwords**  | terraform.tfvars | `domain_admin_password` | ~20 |
| | | `session_host_local_admin_password` | ~23 |
| **Domain Name** | terraform.tfvars | `domain_name` | ~28 |
| **Azure Region** | terraform.tfvars | `location` | ~18 |
| **# of Session Hosts** | terraform.tfvars | `session_host_count` | ~46 |
| **Session Host Size** | terraform.tfvars | `session_host_vm_size` | ~47 |
| **Storage SKU** | terraform.tfvars | `storage_account_tier` | ~59 |
| **DC VM Size** | terraform.tfvars | `dc_vm_size` | ~31 |
| **Network CIDRs** | terraform.tfvars | `vnet_address_space`, `*_subnet_prefix` | ~73-76 |

## Essential Files

```
envs/dev/
├── terraform.tfvars.example   ← COPY THIS to terraform.tfvars
├── terraform.tfvars            ← EDIT THIS (your actual config)
├── variables.tf                ← READ THIS (all 52 variables)
└── main.tf                     ← REVIEW THIS (locals block, line 40-110)
```

## Quick Commands

```bash
# Setup
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # or code terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply

# View outputs
terraform output

# Destroy
terraform destroy
```

## Sensitive Variables (Mark as sensitive in variables.tf)

1. `domain_admin_password` 
2. `session_host_local_admin_password` 

**Both are marked `sensitive = true` in variables.tf**

## Most Common Customizations

### Dev Environment
```hcl
session_host_count = 2
session_host_vm_size = "Standard_D2s_v5"
storage_account_tier = "Standard"
dc_vm_size = "Standard_B2ms"
dc_enable_public_ip = true
```

### Prod Environment
```hcl
session_host_count = 10
session_host_vm_size = "Standard_D4s_v5"
storage_account_tier = "Premium"
dc_vm_size = "Standard_D2s_v5"
dc_enable_public_ip = false  # Use Bastion
enable_storage_private_endpoint = true
```

## Deployment Order (Automatic)

```
1. Networking (VNet)
   ↓
2. Domain Controller (AD DS)
   ↓
3. DNS Update (null_resource)
   ↓
4. Storage + AVD Core (parallel)
   ↓
5. Session Hosts (domain-joined)
```

**Duration: ~25-35 minutes total**

## Validation Quick Checks

### Domain Join
```powershell
systeminfo | findstr /B "Domain"
# Expected: Domain: avd.local
```

### OU Placement
```powershell
(Get-ADComputer -Identity $env:COMPUTERNAME).DistinguishedName
# Expected: CN=...,OU=AVD-SessionHosts,DC=avd,DC=local
```

### GPO Application
```powershell
gpresult /R /SCOPE:COMPUTER
# Should show AVD GPOs applied
```

### FSLogix Profile
```powershell
Get-ItemProperty HKLM:\SOFTWARE\FSLogix\Profiles | Select-Object Enabled, VHDLocations
# Enabled=1, VHDLocations=\\storage.file.core.windows.net\user-profiles
```

## Common Issues

| Problem | Check | Solution |
|---------|-------|----------|
| Domain join fails | VNet DNS points to DC? | Wait for DNS update, verify dc_private_ip |
| GPO not applying | Session host in correct OU? | Check OU placement with Get-ADComputer |
| FSLogix not working | Azure Files domain-joined? | Run AzFilesHybrid PowerShell module |
| Can't access AVD | Users assigned to app group? | Check avd_users variable |

## Cost Estimates (per month)

| Environment | VMs | Storage | Total |
|-------------|-----|---------|-------|
| **Dev** | DC (B2ms) + 2x hosts (D2s_v5) | 100GB Standard | (~$210) (~€195) (~£168) |
| **Prod** | DC (D2s_v5) + 10x hosts (D4s_v5) | 1TB Premium | (~$2,500) (~€2,330) (~£2,000) |

## Documentation Links

- **[CONFIGURATION_GUIDE.md](CONFIGURATION_GUIDE.md)** - Detailed configuration instructions
- **[CONFIGURATION_SURFACE.md](CONFIGURATION_SURFACE.md)** - Complete variable list (52 total)
- **[README.md](README.md)** - Full deployment guide with GPO strategy
- **[modules/*/README.md](modules/)** - Module-specific documentation

## Important Reminders

1. All 52 variables are in `variables.tf` (nothing hidden)
2. Copy `terraform.tfvars.example` to `terraform.tfvars` to start
3. Change passwords immediately (domain_admin_password, session_host_local_admin_password)
4. Use AD DS domain join (not Entra ID-only) for GPO support
5. Deployment order is automatic (DC → DNS → Session Hosts)
6. terraform.tfvars is .gitignored (never commit passwords!)

## Need Help?

1. **Search variables.tf** - All settings documented with descriptions
2. **Check terraform.tfvars.example** - Examples of common configurations  
3. **Review main.tf locals** - See how variables are used
4. **Read CONFIGURATION_GUIDE.md** - Detailed configuration walkthrough
5. **Check module README files** - Module-specific guidance

---

