# AVD Quickstart - Single-File POC Deployment

 **Deploy a complete Azure Virtual Desktop environment in minutes**

This quickstart deploys a fully functional AVD environment using a single Terraform file for rapid POC/testing.

## What Gets Deployed

- **Virtual Network** with 3 subnets (DC, AVD, Storage)
- **1 Domain Controller** (AD DS with AVD OU)
- **AVD Infrastructure** (Workspace, Host Pool, Desktop App Group)
- **2 Session Hosts** (domain-joined, AVD agent installed)
- **Azure Files Storage** with "user-profiles" share for FSLogix

## Quick Start

### 1. Prerequisites

- Azure subscription with Contributor access
- Azure CLI installed and authenticated (`az login`)
- Terraform >= 1.6 installed
- Users must exist in your Entra ID tenant

### 2. Configuration

```bash
# Copy the example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your settings
notepad terraform.tfvars
```

**Required changes in terraform.tfvars:**
- `domain_admin_password` - Set a secure password (12+ chars, complexity required)
- `avd_users` - Add UPNs of users who need AVD access

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Preview the deployment
terraform plan

# Deploy (takes 15-25 minutes)
terraform apply
```

### 4. Deployment Timeline

- **5 min**: Networking and infrastructure provisioned
- **8-12 min**: Domain Controller installed and AD DS configured
- **5-8 min**: Session hosts deployed, domain-joined, and AVD agents installed
- **Total**: ~15-25 minutes

### 5. Access Your AVD Environment

1. Go to https://client.wvd.microsoft.com/arm/webclient
2. Sign in with one of the user accounts from `avd_users`
3. Click the "SessionDesktop" tile to launch your desktop

## Cost Optimization

**Default configuration (~$350/month):**
- DC: Standard_B2ms (2vCPU, 8GB RAM) - ~$55/month
- Session Hosts: 2x Standard_D4s_v5 (4vCPU, 16GB RAM) - ~$280/month
- Storage: Standard LRS - ~$5/month
- Networking: ~$10/month

**To reduce costs:**

Edit the locals block in `main.tf`:

```hcl
# Reduce to 1 session host
session_host_count = 1

# Use smaller session host size
session_host_vm_size = "Standard_D2s_v5"  # ~$70/month each
```

## User Configuration

All user-adjustable settings are at the **top of main.tf** in the `locals` block (lines 20-70).

Common adjustments:
- `session_host_count` - Number of VMs (default: 2)
- `session_host_vm_size` - VM size (default: Standard_D4s_v5)
- `maximum_sessions_allowed` - Max users per host (default: 10)
- `domain_name` - AD domain FQDN (default: avd.local)
- `location` - Azure region (default: East US)

## Teardown

```bash
# Destroy all resources
terraform destroy
```

 **Warning**: This will permanently delete all resources including the domain controller and user profiles.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Virtual Network (10.0.0.0/16)                               │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ DC Subnet    │  │ AVD Subnet   │  │ Storage      │     │
│  │ 10.0.1.0/24  │  │ 10.0.2.0/24  │  │ 10.0.3.0/24  │     │
│  │              │  │              │  │              │     │
│  │  • DC01      │  │  • SH-1      │  │  • Storage   │     │
│  │  (AD DS)     │  │  • SH-2      │  │    Account   │     │
│  │              │  │  (Domain     │  │  • Profiles  │     │
│  │              │  │   Joined)    │  │    Share     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │ AVD Workspace    │
                  │  • Host Pool     │
                  │  • App Group     │
                  │  • Role Assign   │
                  └──────────────────┘
```

## Deployment Order

The Terraform file automatically handles dependencies:

1. **Networking** - VNet with empty DNS
2. **Domain Controller** - AD DS installed, AVD OU created
3. **DNS Update** - VNet DNS points to DC
4. **AVD Core** - Workspace, host pool, app group
5. **Storage** - Azure Files with user-profiles share
6. **Session Hosts** - Domain-joined VMs with AVD agents

## Troubleshooting

### Deployment Failures

**Domain Controller fails to install:**
- Check password meets complexity requirements
- Verify Azure region supports Windows Server 2022

**Session hosts fail to domain join:**
- Wait 2-3 minutes after DC deployment before retrying
- Verify VNet DNS was updated to DC IP
- Check DC is accessible from AVD subnet

**AVD Agent installation fails:**
- Registration token expires after 48 hours
- Run `terraform apply` again to regenerate token

### Validation Commands

Connect to DC via Bastion or RDP and run:

```powershell
# Verify AD DS is running
Get-Service ADWS, DNS, Netlogon

# Check AVD OU exists
Get-ADOrganizationalUnit -Filter 'Name -eq "AVD"'

# List domain-joined session hosts
Get-ADComputer -Filter * -SearchBase "OU=AVD,DC=avd,DC=local"

# Verify DNS resolution
nslookup avd.local 10.0.1.4
```

## Security Notes

 **This is a POC configuration - not production-ready!**

**Security considerations:**
- No public IPs by default (requires Azure Bastion for DC access)
- All passwords in terraform.tfvars (use Key Vault for production)
- No MFA enforcement
- No Network Watcher or monitoring
- Basic NSG rules only

**For production:**
- Use Azure Key Vault for secrets
- Enable MFA via Conditional Access
- Implement Azure Firewall or NVA
- Add monitoring and alerts
- Use separate admin accounts
- Enable backup and disaster recovery

## Support

This is a community quickstart template for POC/testing purposes.

For production deployments, use the modular structure in `envs/dev/` or `envs/prod/`.

## License

MIT License - Use at your own risk
