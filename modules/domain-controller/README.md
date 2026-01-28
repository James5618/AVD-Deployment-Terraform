# Domain Controller Module

This module deploys a minimal Windows Server 2022 VM as an Active Directory Domain Controller with automated AD DS installation and configuration.

## Features

- **Minimal Spec Deployment**: Cost-efficient VM size (Standard_B2ms) with 128GB StandardSSD_LRS OS disk
- **Automated AD DS Installation**: Installs and configures AD DS, DNS, and promotes to a new forest
- **No Public IP**: Secure deployment without public internet exposure
- **Automated OU Creation**: Creates an Organizational Unit for AVD session hosts
- **Group Policy Ready**: Fully functional Domain Controller for managing AVD session hosts via GPO
- **Static Private IP**: Configured DNS server for the VNet

## Architecture

| Component | Description |
|-----------|-------------|
| **Virtual Network (VNet)** | Contains the domain controller subnet and DNS configuration |
| **DC Subnet** | Subnet for domain controller (e.g., 10.0.1.0/24) |
| **Domain Controller VM** | - Windows Server 2022<br>- AD DS + DNS services installed<br>- Static IP: 10.0.1.4<br>- No Public IP (secure deployment) |
| **VNet DNS Configuration** | VNet DNS points to DC IP (10.0.1.4) for domain name resolution |

## Usage

### Basic Example

```hcl
module "domain_controller" {
  source = "../../modules/domain-controller"

  # Azure Resources
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.networking.dc_subnet_id
  dc_private_ip       = "10.0.1.4"
  dc_name             = "DC01"

  # Domain Configuration
  domain_name                = "contoso.local"
  netbios_name               = "CONTOSO"
  admin_username             = "dcadmin"
  admin_password             = var.dc_admin_password
  safe_mode_admin_password   = var.dc_safe_mode_password

  # VM Configuration (optional, defaults shown)
  dc_vm_size      = "Standard_B2ms"
  os_disk_type    = "StandardSSD_LRS"
  os_disk_size_gb = 128
  timezone        = "UTC"

  # OU Configuration (optional)
  avd_ou_name        = "AVD"
  avd_ou_description = "Azure Virtual Desktop session hosts"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
```

### Using with Networking Module

```hcl
# First, deploy networking
module "networking" {
  source = "../../modules/networking"
  # ... networking config
  dns_servers = []  # Initially empty
}

# Deploy Domain Controller
module "domain_controller" {
  source = "../../modules/domain-controller"
  # ... DC config
  depends_on = [module.networking]
}

# Update VNet DNS to point to DC (separate apply or update)
module "networking" {
  source = "../../modules/networking"
  # ... networking config
  dns_servers = [module.domain_controller.dc_private_ip]
}
```

## Variables

### Required Variables

| Name | Description | Type |
|------|-------------|------|
| `domain_name` | Fully qualified domain name (e.g., 'contoso.local') | `string` |
| `netbios_name` | NetBIOS name (e.g., 'CONTOSO') | `string` |
| `safe_mode_admin_password` | Safe Mode Administrator password  | `string` (sensitive) |
| `admin_username` | Local administrator username | `string` |
| `admin_password` | Local administrator password  | `string` (sensitive) |
| `resource_group_name` | Resource group name | `string` |
| `location` | Azure region | `string` |
| `subnet_id` | Subnet ID for DC deployment | `string` |
| `dc_private_ip` | Static private IP address | `string` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `dc_vm_size` | VM size (2 vCPU, 4-8 GB RAM) | `string` | `"Standard_B2ms"` |
| `os_disk_type` | OS disk type | `string` | `"StandardSSD_LRS"` |
| `os_disk_size_gb` | OS disk size in GB | `number` | `128` |
| `timezone` | VM timezone | `string` | `"UTC"` |
| `dc_name` | DC VM name | `string` | `"DC01"` |
| `avd_ou_name` | AVD OU name | `string` | `"AVD"` |
| `avd_ou_description` | AVD OU description | `string` | `"Organizational Unit for Azure Virtual Desktop session hosts"` |
| `tags` | Resource tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `dc_vm_id` | Domain Controller VM resource ID |
| `dc_vm_name` | Domain Controller VM name |
| `dc_private_ip` | DC private IP (use for VNet DNS) |
| `domain_name` | FQDN of the domain |
| `netbios_name` | NetBIOS domain name |
| `ou_distinguished_name` | Distinguished Name of the AVD OU |

##  Password Management

###  Security Warning

**DO NOT hardcode passwords in Terraform configuration files!**

### Development/Testing

For development and testing, you can use `terraform.tfvars` (ensure it's in `.gitignore`):

```hcl
# terraform.tfvars (DO NOT COMMIT!)
dc_admin_password      = "YourComplexPassword123!"
dc_safe_mode_password  = "YourComplexPassword123!"
```

### Production Deployment (Recommended)

**Use Azure Key Vault** to store and retrieve passwords:

#### Step 1: Store Passwords in Key Vault

```bash
# Create Key Vault (if not exists)
az keyvault create \
  --name "myavdkeyvault" \
  --resource-group "myavd-rg" \
  --location "eastus"

# Store passwords as secrets
az keyvault secret set \
  --vault-name "myavdkeyvault" \
  --name "dc-admin-password" \
  --value "YourComplexPassword123!"

az keyvault secret set \
  --vault-name "myavdkeyvault" \
  --name "dc-safe-mode-password" \
  --value "YourComplexPassword123!"
```

#### Step 2: Reference Secrets in Terraform

```hcl
# Retrieve Key Vault
data "azurerm_key_vault" "avd" {
  name                = "myavdkeyvault"
  resource_group_name = "myavd-rg"
}

# Retrieve secrets
data "azurerm_key_vault_secret" "dc_admin_password" {
  name         = "dc-admin-password"
  key_vault_id = data.azurerm_key_vault.avd.id
}

data "azurerm_key_vault_secret" "dc_safe_mode_password" {
  name         = "dc-safe-mode-password"
  key_vault_id = data.azurerm_key_vault.avd.id
}

# Use secrets in module
module "domain_controller" {
  source = "../../modules/domain-controller"
  
  admin_password           = data.azurerm_key_vault_secret.dc_admin_password.value
  safe_mode_admin_password = data.azurerm_key_vault_secret.dc_safe_mode_password.value
  
  # ... other configuration
}
```

### Password Requirements

Both passwords must meet Windows Server complexity requirements:
- At least 8 characters long
- Contains characters from at least 3 of these categories:
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Special characters (!, @, #, $, %, etc.)

## Deployment Process

### What Happens During Deployment

1. **VM Creation** (~3-5 minutes)
   - Windows Server 2022 VM is created
   - Network interface with static private IP is configured
   - OS disk is provisioned

2. **AD DS Installation** (~10-15 minutes)
   - CustomScriptExtension downloads and runs installation script
   - AD DS role and management tools are installed
   - New forest and domain are created
   - DNS server is configured
   - **VM automatically reboots** after AD DS installation

3. **OU Creation** (~2-3 minutes after reboot)
   - Scheduled task runs after reboot
   - Waits for AD Web Services to be ready
   - Creates AVD Organizational Unit
   - Disables scheduled task

**Total Deployment Time**: ~15-20 minutes

### Monitoring Deployment

#### Check VM Extension Status

```bash
az vm extension list \
  --resource-group <resource-group-name> \
  --vm-name <dc-vm-name> \
  --output table
```

#### View Installation Logs

RDP to the DC and check these log files:
- `C:\Windows\Temp\ADDS-Install.log` - AD DS installation log
- `C:\Windows\Temp\OU-Creation.log` - OU creation log

#### Verify Domain Controller

```powershell
# Check domain
Get-ADDomain

# Check forest
Get-ADForest

# Check DNS
Get-DnsServerZone

# Check OU
Get-ADOrganizationalUnit -Filter 'Name -eq "AVD"'
```

## Post-Deployment Steps

### 1. Update VNet DNS Configuration

After DC deployment completes, update the VNet to use the DC as DNS:

```hcl
module "networking" {
  source = "../../modules/networking"
  # ... other config
  dns_servers = [module.domain_controller.dc_private_ip]
}
```

Apply the change:
```bash
terraform apply
```

### 2. Create AD Users for AVD

RDP to the Domain Controller and create user accounts:

```powershell
# Example: Create AVD test user
New-ADUser `
  -Name "AVD User 1" `
  -SamAccountName "avduser1" `
  -UserPrincipalName "avduser1@contoso.local" `
  -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force) `
  -Enabled $true `
  -Path "OU=AVD,DC=contoso,DC=local"
```

### 3. Configure Group Policies (Optional)

Create and link GPOs for AVD session hosts:

```powershell
# Create GPO for AVD session hosts
New-GPO -Name "AVD Session Host Policy" | New-GPLink -Target "OU=AVD,DC=contoso,DC=local"
```

## Troubleshooting

### AD DS Installation Failed

1. Check the installation log: `C:\Windows\Temp\ADDS-Install.log`
2. Verify password meets complexity requirements
3. Check VM has sufficient resources (2 vCPU, 4GB+ RAM minimum)

### OU Not Created

1. Check the OU creation log: `C:\Windows\Temp\OU-Creation.log`
2. Verify scheduled task ran: `Get-ScheduledTask -TaskName "Create-AVD-OU"`
3. Manually run the script if needed: `C:\Windows\Temp\Create-OU.ps1`

### DNS Not Resolving

1. Verify VNet DNS servers are set to DC private IP
2. Check DNS service is running on DC: `Get-Service -Name DNS`
3. Test DNS from another VM: `nslookup contoso.local 10.0.1.4`

### Cannot RDP to Domain Controller

- DC has no public IP by design for security
- Use Azure Bastion or VPN for secure access
- Or deploy a jump box VM with public IP in the same VNet

## VM Sizing Guidance

| VM Size | vCPU | RAM | Use Case | Monthly Cost* |
|---------|------|-----|----------|---------------|
| Standard_B2ms | 2 | 8 GB | Development/Test | ~$60 |
| Standard_D2s_v5 | 2 | 8 GB | Small Production (<50 users) | ~$70 |
| Standard_D4s_v5 | 4 | 16 GB | Medium Production (50-200 users) | ~$140 |
| Standard_D8s_v5 | 8 | 32 GB | Large Production (200+ users) | ~$280 |

*Approximate costs for East US region with pay-as-you-go pricing.

## Limitations

- Single Domain Controller (no high availability)
- No backup/disaster recovery configured
- No monitoring or alerts configured
- Basic AD DS configuration (no advanced features)

### Production Considerations

For production environments, consider:
- Deploy a second DC for redundancy
- Configure Azure Backup for DC VM
- Implement Azure Monitor for DC monitoring
- Use Azure AD Domain Services instead of IaaS DC
- Configure Site-to-Site VPN or ExpressRoute for on-premises integration

## License

This module is part of the Azure Virtual Desktop Terraform Playbook.
