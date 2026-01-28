# Session Hosts Module

Deploys Azure Virtual Desktop (AVD) session host VMs with domain join, AVD agent installation, and FSLogix configuration.

## Features

- **Windows Multi-Session VMs**: Deploys Windows 11/10 Enterprise multi-session VMs
- **Three Flexible Image Sources**: 
  - Azure Marketplace (quick start, latest Windows updates)
  - Azure Compute Gallery (Golden Image or Manual Import for customization)
  - Managed Image (legacy/temporary custom images)
- **Domain Join**: Automatically joins VMs to Active Directory domain with OU placement
- **AVD Agent**: Installs and registers session hosts to AVD host pool
- **FSLogix Configuration**: Configures profile redirection to Azure Files share
- **Managed Identity**: System-assigned identity for Azure integrations
- **Custom DNS**: Uses VNet DNS servers pointing to domain controller

## Image Source Selection

The module supports three image sources controlled by `session_host_image_source`:

| Source | Value | Use Case | Configuration |
|--------|-------|----------|---------------|
| **Marketplace** | `"marketplace"` | Quick start, testing, always latest patches | `marketplace_image_reference` object |
| **Gallery** | `"gallery"` | Production, custom apps, Golden Image pipeline | `gallery_image_version_id` |
| **Managed Image** | `"managed_image"` | Legacy images, temporary testing | `managed_image_id` |

**How it works:**
```hcl
# In the VM resource:
source_image_id = (
  session_host_image_source == "gallery" ? gallery_image_version_id :
  session_host_image_source == "managed_image" ? managed_image_id :
  null  # Use source_image_reference for marketplace
)

dynamic "source_image_reference" {
  for_each = session_host_image_source == "marketplace" ? [1] : []
  content {
    publisher = marketplace_image_reference.publisher
    offer     = marketplace_image_reference.offer
    sku       = marketplace_image_reference.sku
    version   = marketplace_image_reference.version
  }
}
```

## Quick Start

### Option 1: Using Azure Marketplace Image (Default)

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.networking.avd_subnet_id
  vnet_dns_servers    = ["10.0.1.4"]
  
  # VM Configuration
  vm_count       = 2
  vm_name_prefix = "avd-sh"
  vm_size        = "Standard_D2s_v5"
  timezone       = "UTC"
  
  # Marketplace Image (default behavior)
  use_golden_image = false
  image_publisher  = "MicrosoftWindowsDesktop"
  image_offer      = "windows-11"
  image_sku        = "win11-22h2-avd"
  image_version    = "latest"
  
  # Credentials
  local_admin_username  = "localadmin"
  local_admin_password  = "SecurePassword123!"
  domain_admin_username = "domainadmin"
  domain_admin_password = "SecurePassword456!"
  
  # Domain Join
  domain_name         = "contoso.local"
  domain_netbios_name = "CONTOSO"
  domain_ou_path      = "OU=AVD,DC=contoso,DC=local"
  
  # AVD Registration
  hostpool_name               = "avd-hostpool"
  hostpool_registration_token = "eyJ0eXAiOi..."
  
  # FSLogix
  fslogix_share_path = "\\\\storage.file.core.windows.net\\profiles"
}
```

### Option 1: Using Azure Marketplace Image

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.networking.avd_subnet_id
  vnet_dns_servers    = ["10.0.1.4"]
  
  # VM Configuration
  vm_count       = 2
  vm_name_prefix = "avd-sh"
  vm_size        = "Standard_D2s_v5"
  
  # Image Source: Marketplace
  session_host_image_source = "marketplace"
  marketplace_image_reference = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }
  
  # Credentials
  local_admin_username  = "localadmin"
  local_admin_password  = "SecurePassword123!"
  domain_admin_username = "domainadmin"
  domain_admin_password = "SecurePassword456!"
  
  # Domain Join
  domain_name         = "contoso.local"
  domain_netbios_name = "CONTOSO"
  domain_ou_path      = "OU=AVD,DC=contoso,DC=local"
  
  # AVD Registration
  hostpool_name               = "avd-hostpool"
  hostpool_registration_token = "eyJ0eXAiOi..."
  
  # FSLogix
  fslogix_share_path = "\\\\storage.file.core.windows.net\\profiles"
}
```

### Option 2: Using Azure Compute Gallery Image (Golden Image or Imported)

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.networking.avd_subnet_id
  vnet_dns_servers    = ["10.0.1.4"]
  
  # VM Configuration
  vm_count       = 2
  vm_name_prefix = "avd-sh"
  vm_size        = "Standard_D2s_v5"
  
  # Image Source: Azure Compute Gallery
  session_host_image_source = "gallery"
  gallery_image_version_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-images/providers/Microsoft.Compute/galleries/myGallery/images/win11-avd-golden/versions/1.0.0"
  # OR use 'latest' version:
  # gallery_image_version_id = ".../versions/latest"
  
  # Credentials (same as Option 1)
  local_admin_username  = "localadmin"
  local_admin_password  = "SecurePassword123!"
  domain_admin_username = "domainadmin"
  domain_admin_password = "SecurePassword456!"
  
  # Domain Join (same as Option 1)
  domain_name         = "contoso.local"
  domain_netbios_name = "CONTOSO"
  domain_ou_path      = "OU=AVD,DC=contoso,DC=local"
  
  # AVD Registration (same as Option 1)
  hostpool_name               = "avd-hostpool"
  hostpool_registration_token = "eyJ0eXAiOi..."
  
  # FSLogix (same as Option 1)
  fslogix_share_path = "\\\\storage.file.core.windows.net\\profiles"
}
```

### Option 3: Using Managed Image (Custom Image)

```hcl
module "session_hosts" {
  source = "../../modules/session-hosts"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = module.networking.avd_subnet_id
  vnet_dns_servers    = ["10.0.1.4"]
  
  # VM Configuration
  vm_count       = 2
  vm_name_prefix = "avd-sh"
  vm_size        = "Standard_D2s_v5"
  
  # Image Source: Managed Image
  session_host_image_source = "managed_image"
  managed_image_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-images/providers/Microsoft.Compute/images/my-custom-avd-image"
  
  # Credentials, Domain Join, AVD Registration, FSLogix (same as Options 1-2)
  # ...
}
```

### Option 4: Integration with Golden Image Module

```hcl
# Build custom golden image
module "golden_image" {
  count  = var.enable_golden_image ? 1 : 0
  source = "../../modules/golden_image"
  
  # Gallery configuration
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  gallery_name          = "myGallery"
  image_definition_name = "win11-avd-golden"
  image_template_name   = "win11-avd-template"
  image_version         = "1.0.0"
  
  # Base image and customizations
  base_image_sku          = "win11-22h2-avd-m365"
  install_windows_updates = true
  chocolatey_packages     = ["googlechrome", "7zip"]
}

# Deploy session hosts using golden image
module "session_hosts" {
  source = "../../modules/session-hosts"
  
  # ... (other configuration same as Option 2)
  
  # Automatically wire golden image output to session hosts
  session_host_image_source = var.enable_golden_image ? "gallery" : "marketplace"
  gallery_image_version_id  = var.enable_golden_image ? module.golden_image[0].latest_image_version_reference : null
  
  # Marketplace fallback if golden image disabled
  marketplace_image_reference = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-avd"
    version   = "latest"
  }
}
```

## Image Source Selection Logic

The module automatically selects the correct image source based on `session_host_image_source`:

| `session_host_image_source` | Required Variable | Image Source Used |
|-----------------------------|-------------------|-------------------|
| `"marketplace"` | `marketplace_image_reference` | **Azure Marketplace** using publisher/offer/sku/version |
| `"gallery"` | `gallery_image_version_id` | **Azure Compute Gallery** (Golden Image or imported image) |
| `"managed_image"` | `managed_image_id` | **Managed Image** (custom image created manually) |

**Validation:** The module validates that the required variable is provided for your chosen image source.
| `true` | `null` or empty | **Error**: `gallery_image_version_id` required when `use_golden_image = true` |

## Module Architecture

| Component | Description |
|-----------|-------------|
| **Network Interfaces** | Each session host has a NIC configured with VNet DNS servers pointing to domain controller |
| **Session Host VMs** | Windows 11 Multi-Session VMs (or Windows 10)<br>- **Image Source:** Marketplace (quick start) OR Azure Compute Gallery (custom golden image)<br>- Multiple VMs deployed (VM 1, VM 2, ... VM N) |
| **VM Extensions** | Applied to each VM in sequence:<br>1. **Domain Join Extension** - Joins VM to Active Directory<br>2. **AVD Agent Extension** - Installs AVD agent and registers to host pool<br>3. **FSLogix Configuration** - Configures profile redirection to Azure Files |

## Deployment Process

1. **Network Interfaces**: Creates NICs with VNet DNS servers (pointing to DC)
2. **Virtual Machines**: Deploys Windows VMs with:
   - Marketplace image (if `use_golden_image = false`)
   - Azure Compute Gallery image (if `use_golden_image = true`)
   - System-assigned managed identity
   - Windows Client license type (cost savings)
3. **Domain Join Extension**: Joins VMs to AD domain with OU placement
4. **AVD Agent Extension**: Installs AVD agent and registers to host pool
5. **FSLogix Configuration**: Configures profile redirection via PowerShell script

## Golden Image vs Marketplace Image

### When to Use Marketplace Images

 **Use marketplace images when:**
- Quick proof-of-concept or testing
- No custom applications or configurations required
- Minimal infrastructure (1-2 session hosts)
- Budget-constrained (avoid image build costs)
- Prefer latest Windows updates from Microsoft

**Benefits:**
- Zero upfront cost (no image build)
- Always latest security patches from Microsoft
- Simple configuration
- No image maintenance required

**Drawbacks:**
- Slower deployments (30-60 min per VM for Windows Updates + apps)
- Inconsistent configuration across VMs
- Requires extensive post-deployment scripting
- Higher operational overhead

### When to Use Golden Images

 **Use golden images when:**
- Production AVD environment
- Custom applications required (Office, Chrome, LOB apps)
- Multiple session hosts (5+ VMs)
- Need consistent configuration
- Faster scaling required

**Benefits:**
- **6x faster deployments** (5-10 min vs 30-60 min per VM)
- Pre-installed applications and updates
- Consistent configuration across all VMs
- Reduced post-deployment scripting
- Better user experience (pre-warmed apps)

**Drawbacks:**
- Image build cost (~$1-3 per build)
- Storage cost (~$5-15/month)
- Image maintenance required (monthly builds)
- Manual build trigger after terraform apply

## Image Configuration Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `session_host_image_source` | `string` | `"marketplace"` | Image source: `"marketplace"`, `"gallery"`, or `"managed_image"` |
| `marketplace_image_reference` | `object` | See below | Marketplace image config (publisher/offer/sku/version) |
| `gallery_image_version_id` | `string` | `null` | Azure Compute Gallery image version ID (required if source = `"gallery"`) |
| `managed_image_id` | `string` | `null` | Managed Image resource ID (required if source = `"managed_image"`) |

**Default `marketplace_image_reference` object:**
```hcl
{
  publisher = "MicrosoftWindowsDesktop"
  offer     = "windows-11"
  sku       = "win11-22h2-avd"
  version   = "latest"
}
```

**Deprecated Variables (backward compatibility):**
- `use_golden_image` - Use `session_host_image_source = "gallery"` instead
- `image_publisher`, `image_offer`, `image_sku`, `image_version` - Use `marketplace_image_reference` object instead

## Available Marketplace Image SKUs

If using marketplace images (`use_golden_image = false`), choose from:

| SKU | Description | M365 Apps | Use Case |
|-----|-------------|-----------|----------|
| `win11-22h2-avd` | Windows 11 Enterprise multi-session 22H2 |  No | Basic AVD, no Office required |
| `win11-22h2-avd-m365` | Windows 11 Enterprise multi-session 22H2 + M365 |  Yes | Most common, includes Office |
| `win11-23h2-avd` | Windows 11 Enterprise multi-session 23H2 |  No | Newer build, no Office |
| `win11-23h2-avd-m365` | Windows 11 Enterprise multi-session 23H2 + M365 |  Yes | Newer build + Office |
| `win10-22h2-avd` | Windows 10 Enterprise multi-session 22H2 |  No | Legacy support |
| `win10-22h2-avd-m365` | Windows 10 Enterprise multi-session 22H2 + M365 |  Yes | Legacy support + Office |

## Domain Join Configuration

The module automatically:
1. Joins VMs to AD domain using `JsonADDomainExtension`
2. Places VMs in specified OU (`domain_ou_path`)
3. Uses VNet DNS servers pointing to domain controller
4. Configures proper domain credentials

**Prerequisites:**
- Domain controller must be running and accessible
- VNet DNS must point to domain controller IP
- Domain OU must exist (created by domain-controller module)
- Domain admin credentials must be valid

## AVD Registration

The module:
1. Installs AVD agent using `DSC` extension
2. Registers session hosts to AVD host pool
3. Uses registration token from AVD core module
4. Configures session host properties

**Prerequisites:**
- AVD host pool must exist
- Valid registration token (expires after 90 days by default)
- Session hosts must have internet access (Azure endpoints)

## FSLogix Configuration

The module configures FSLogix via PowerShell script:
- Enables FSLogix profile containers
- Sets Azure Files UNC path (`\\storage.file.core.windows.net\profiles`)
- Configures VHD location format
- Sets deletion policy for local profiles

**Prerequisites:**
- Azure Files share must be created (fslogix_storage module)
- Share must be accessible from session host subnet
- Storage account must have AD DS authentication enabled

## Cost Estimation

### Marketplace Image Deployment

| Component | Cost (per VM) | Notes |
|-----------|---------------|-------|
| Session Host VM | $0.096/hour | Standard_D2s_v5 (2 vCPU, 8 GB RAM) |
| OS Disk (128 GB Premium SSD) | $19.71/month | Premium_LRS |
| **Total per VM** | **~$89/month** | Compute + storage |
| **2 VMs** | **~$178/month** | Typical small deployment |

### Golden Image Deployment

| Component | Cost | Notes |
|-----------|------|-------|
| Session Host VMs (same as above) | ~$178/month | 2 VMs |
| Golden Image Build | $1-3/build | 30-90 min build time |
| Golden Image Storage | $5-15/month | Depends on replication |
| **Total (first month)** | **~$196/month** | Includes first build |
| **Total (ongoing)** | **~$193/month** | Monthly rebuild |

**Cost Comparison:**
- Golden image adds ~$15-18/month (~8% increase)
- **Time savings**: 45-90 min per VM deployment → **6x faster**
- Break-even: 5+ VMs or frequent scaling

## Deployment Time Comparison

| Deployment Type | Time per VM | Total for 2 VMs | Total for 10 VMs |
|----------------|-------------|-----------------|------------------|
| **Marketplace Image** | 30-60 min | 60-120 min | 300-600 min (5-10 hours) |
| **Golden Image** | 5-10 min | 10-20 min | 50-100 min (1-2 hours) |
| **Speed Improvement** | **6x faster** | **6x faster** | **6x faster** |

*Marketplace time includes: VM provision (5 min) + Windows Updates (15-30 min) + app installs (10-25 min)*  
*Golden image time: VM provision only (5-10 min) - updates/apps pre-installed*

## Troubleshooting

### Issue: VMs fail to join domain

**Symptoms:**
- Domain join extension fails with error "The specified domain either does not exist or could not be contacted"

**Causes:**
1. VNet DNS not pointing to DC
2. Domain controller not running
3. Network connectivity issue
4. Invalid domain credentials

**Solution:**
```bash
# 1. Verify VNet DNS settings
az network vnet show --resource-group <rg> --name <vnet> --query "dhcpOptions.dnsServers"

# 2. Verify DC is running
az vm get-instance-view --resource-group <rg> --name <dc-vm> --query "instanceView.statuses[?code=='PowerState/running']"

# 3. Test connectivity from session host
# RDP to session host and run:
nslookup contoso.local
ping contoso.local
```

### Issue: AVD agent registration fails

**Symptoms:**
- VMs appear in Azure but not in AVD host pool
- DSC extension fails

**Causes:**
1. Invalid registration token
2. Token expired (>90 days old)
3. No internet connectivity
4. Host pool doesn't exist

**Solution:**
```bash
# 1. Generate new registration token
az desktopvirtualization hostpool update \
  --resource-group <rg> \
  --name <hostpool> \
  --registration-info expiration-time="2024-12-31T23:59:59" registration-token-operation="Update"

# 2. Verify host pool exists
az desktopvirtualization hostpool show --resource-group <rg> --name <hostpool>

# 3. Check internet connectivity (Azure endpoints required)
# From session host:
Test-NetConnection login.microsoftonline.com -Port 443
Test-NetConnection rdweb.wvd.microsoft.com -Port 443
```

### Issue: Gallery image version not found

**Symptoms:**
- VM deployment fails with "Image not found" or "Gallery image version does not exist"

**Causes:**
1. Image version doesn't exist yet
2. Using `latest` before first image built
3. Incorrect gallery/image/version ID
4. Insufficient permissions

**Solution:**
```bash
# 1. Verify image version exists
az sig image-version show \
  --resource-group <rg> \
  --gallery-name <gallery> \
  --gallery-image-definition <image> \
  --gallery-image-version 1.0.0

# 2. List all available versions
az sig image-version list \
  --resource-group <rg> \
  --gallery-name <gallery> \
  --gallery-image-definition <image> \
  --output table

# 3. Trigger image build if no versions exist
az image builder run \
  --resource-group <rg> \
  --name <template-name>
```

### Issue: Slow VM deployments even with golden image

**Symptoms:**
- VMs take 30+ minutes to deploy despite using golden image
- Windows Updates still running on session hosts

**Causes:**
1. Golden image not actually being used (check `use_golden_image` flag)
2. Golden image is old (Windows Updates accumulate)
3. Post-deployment scripts running (disable if not needed)

**Solution:**
```bash
# 1. Verify VM is using gallery image
az vm show --resource-group <rg> --name <vm> --query "storageProfile.imageReference"
# Should show: "id": "/subscriptions/.../galleries/.../images/.../versions/..."

# 2. Rebuild golden image monthly
# See modules/golden_image/README.md for build instructions

# 3. Verify image build includes Windows Updates
# Check golden_image module: install_windows_updates = true
```

## Best Practices

### 1. Use Golden Images for Production
- Build monthly to include latest security patches
- Pre-install common applications (Office, Chrome, etc.)
- Document image version changes
- Test new images before production rollout

### 2. Implement Rolling Replacement (Production Zero-Downtime)

For production environments, use rolling replacement to update session hosts without service interruption.

#### Strategy Overview

| Phase | Action | Host Status | Result |
|-------|--------|-------------|--------|
| **Phase 1: Deploy New Hosts** | Increase `vm_count` from 2 to 4 | **Old Hosts:** Old-1 (Active), Old-2 (Active)<br>**New Hosts:** New-1 (Active), New-2 (Active) | 4 total hosts running (2 old + 2 new) |
| **Phase 2: Drain Old Hosts** | Set drain mode on old hosts, wait for user logout | **Old Hosts:** Old-1 (DRAIN), Old-2 (DRAIN) - no new sessions<br>**New Hosts:** New-1 (Active), New-2 (Active) - receive new sessions | Users gradually migrate to new hosts |
| **Phase 3: Remove Old Hosts** | Reduce `vm_count` from 4 to 2, remove old hosts | **New Hosts:** New-1 (Active), New-2 (Active) | Only new hosts remain (2 total hosts) |

#### Detailed Runbook

**Prerequisites:**
- New golden image version built and available
- Maintenance window scheduled (or use drain mode for zero-downtime)
- Monitoring enabled to track active sessions

**Step 1: Deploy New Session Hosts (5-10 minutes)**

```bash
# Update terraform.tfvars to DOUBLE vm_count temporarily
# Example: 2 VMs → 4 VMs (keeps old 2, adds new 2)

# Before:
session_host_count = 2

# After (temporary):
session_host_count = 4

# Apply to deploy new hosts
cd envs/dev
terraform apply -target=module.session_hosts

# Verify new hosts are registered
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, Status:status, Sessions:sessions}" \
  --output table
```

**Step 2: Enable Drain Mode on Old Hosts (30 seconds)**

```bash
# Set drain mode on old session hosts (prevents new sessions)
# Replace HOST_RESOURCE_ID with actual session host resource ID

# Get session host resource IDs
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, ID:id}" \
  --output table

# Enable drain mode on old hosts (e.g., avd-sh-1, avd-sh-2)
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-1.contoso.local" \
  --allow-new-session false

az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-2.contoso.local" \
  --allow-new-session false

# Verify drain mode enabled
az desktopvirtualization sessionhost show \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-1.contoso.local" \
  --query "{Name:name, AllowNewSession:allowNewSession, ActiveSessions:sessions}"
```

**Step 3: Wait for Active Sessions to Complete (varies: 1-8 hours)**

```bash
# Monitor active sessions on old hosts
watch -n 30 'az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[?contains(name, \"avd-sh-1\") || contains(name, \"avd-sh-2\")].{Name:name, Sessions:sessions, AllowNew:allowNewSession}" \
  --output table'

# Optional: Send user notifications (3 examples)

# Example 1: Azure Portal - Send user notification
# 1. Navigate to Azure Virtual Desktop > Host pools > avd-dev-hostpool
# 2. Select "Session hosts" > Select old host
# 3. Click "Send message" 
# 4. Message: "Maintenance scheduled in 2 hours. Please save work and log off."

# Example 2: PowerShell - Send message to all users on specific host
$ResourceGroup = "avd-dev-rg"
$HostPool = "avd-dev-hostpool"
$SessionHostName = "avd-sh-1.contoso.local"

Send-AzWvdUserSessionMessage `
  -ResourceGroupName $ResourceGroup `
  -HostPoolName $HostPool `
  -SessionHostName $SessionHostName `
  -MessageTitle "Maintenance Notice" `
  -MessageBody "System maintenance in 2 hours. Please save your work and sign out. You can reconnect immediately to a new session host." `
  -MessageType Warning

# Example 3: Forced logoff after grace period (use cautiously)
# Wait for grace period (e.g., 2 hours), then force logoff
$Sessions = Get-AzWvdUserSession `
  -ResourceGroupName $ResourceGroup `
  -HostPoolName $HostPool `
  -SessionHostName $SessionHostName

foreach ($Session in $Sessions) {
  Remove-AzWvdUserSession `
    -ResourceGroupName $ResourceGroup `
    -HostPoolName $HostPool `
    -SessionHostName $SessionHostName `
    -Id $Session.Name `
    -Force
}
```

**Step 4: Deallocate Old Hosts (optional, saves cost during testing) (2 minutes)**

```bash
# Once sessions = 0 on old hosts, deallocate (optional)
# This keeps the VMs for potential rollback but stops billing compute

az vm deallocate --resource-group avd-dev-rg --name avd-sh-1 --no-wait
az vm deallocate --resource-group avd-dev-rg --name avd-sh-2 --no-wait

# Verify deallocation
az vm show --resource-group avd-dev-rg --name avd-sh-1 --query "provisioningState" -o tsv
# Expected: "Succeeded"

az vm get-instance-view --resource-group avd-dev-rg --name avd-sh-1 \
  --query "instanceView.statuses[?starts_with(code, 'PowerState')].displayStatus" -o tsv
# Expected: "VM deallocated"

# Test new hosts for 24-48 hours before final removal
```

**Step 5: Remove Old Hosts from Terraform (1 minute)**

```bash
# After confirming new hosts work, remove old hosts from Terraform state
# This allows reducing vm_count without destroying new hosts

# Option A: Remove specific VMs from state (preserves VMs in Azure, just stops managing)
terraform state rm 'module.session_hosts.azurerm_network_interface.session_host[0]'
terraform state rm 'module.session_hosts.azurerm_network_interface.session_host[1]'
terraform state rm 'module.session_hosts.azurerm_windows_virtual_machine.session_host[0]'
terraform state rm 'module.session_hosts.azurerm_windows_virtual_machine.session_host[1]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.domain_join[0]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.domain_join[1]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.avd_agent[0]'
terraform state rm 'module.session_hosts.azurerm_virtual_machine_extension.avd_agent[1]'

# Update terraform.tfvars to restore original vm_count
session_host_count = 2

# Apply to sync state (no resources destroyed, just state updated)
terraform apply

# Now manually delete old VMs from Azure Portal or CLI
az vm delete --resource-group avd-dev-rg --name avd-sh-1 --yes --no-wait
az vm delete --resource-group avd-dev-rg --name avd-sh-2 --yes --no-wait
```

#### Alternative: Simple Blue-Green with Separate Module

```hcl
# In envs/dev/main.tf, add a second session_hosts module temporarily

# Existing hosts (keep running)
module "session_hosts" {
  source = "../../modules/session-hosts"
  vm_count       = 2
  vm_name_prefix = "avd-sh"
  # ... existing config
}

# New hosts with new image (deploy alongside)
module "session_hosts_v2" {
  source = "../../modules/session-hosts"
  vm_count       = 2
  vm_name_prefix = "avd-sh-v2"
  
  use_golden_image         = true
  gallery_image_version_id = ".../versions/2.0.0"  # New version
  
  # ... copy all other config from session_hosts module
}

# Deployment steps:
# 1. Add session_hosts_v2 module, apply
# 2. Test new hosts for 24-48 hours
# 3. Drain old hosts (session_hosts module)
# 4. Remove session_hosts module, rename session_hosts_v2 to session_hosts
# 5. Apply to clean up
```

#### Rollback Procedure

If new hosts have issues:

```bash
# Step 1: Re-enable old hosts (remove drain mode)
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-1.contoso.local" \
  --allow-new-session true

az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-2.contoso.local" \
  --allow-new-session true

# Step 2: Start deallocated VMs (if deallocated)
az vm start --resource-group avd-dev-rg --name avd-sh-1 --no-wait
az vm start --resource-group avd-dev-rg --name avd-sh-2 --no-wait

# Step 3: Drain new hosts
az desktopvirtualization sessionhost update \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --name "avd-sh-3.contoso.local" \
  --allow-new-session false

# Step 4: Remove new hosts after sessions drain
terraform apply  # Will detect vm_count change and destroy new hosts
```

#### Terraform Lifecycle Configuration (Optional)

Add to `modules/session-hosts/main.tf` to prevent accidental destruction:

```hcl
resource "azurerm_windows_virtual_machine" "session_host" {
  count = var.vm_count
  # ... existing config ...
  
  lifecycle {
    # Prevent accidental destruction during apply
    prevent_destroy = false  # Set to true in production
    
    # Ignore changes to tags (allows external tagging)
    ignore_changes = [tags]
    
    # Create new VMs before destroying old ones
    create_before_destroy = false  # Can't use with domain join extension
  }
}
```

**Note:** `create_before_destroy` can't be used with domain join extension due to OU conflicts. Use the manual rolling replacement process instead.

### 3. Implement Blue-Green Deployment (Simpler Alternative)

For less critical environments or faster rollouts:

```hcl
# Deploy new session hosts with new image version
module "session_hosts_v2" {
  source = "../../modules/session-hosts"
  
  vm_count       = 2
  vm_name_prefix = "avd-sh-v2"
  
  use_golden_image         = true
  gallery_image_version_id = ".../versions/2.0.0"  # New version
  
  # ... other config same as original
}

# Test for 1-2 days, then decommission old session hosts
# terraform destroy -target=module.session_hosts
```

### 4. Automate Image Builds
```yaml
# Azure DevOps pipeline to rebuild monthly
trigger:
  schedule:
    - cron: "0 2 1 * *"  # 2 AM on 1st of month
      
steps:
  - task: AzureCLI@2
    inputs:
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        # Trigger image build
        az image builder run \
          --resource-group avd-prod-rg \
          --name avd-prod-golden-template
        
        # Wait for completion (30-90 min)
        az image builder show \
          --resource-group avd-prod-rg \
          --name avd-prod-golden-template \
          --query "lastRunStatus.runState" -o tsv
```

### 4. Version Control Images
- Use semantic versioning: `1.0.0`, `1.1.0`, `2.0.0`
- Tag images with build date and Windows Update KB
- Keep 3-5 previous versions for rollback
- Document changes in image version release notes

### 5. Monitor Session Host Health
```bash
# Check session host status in AVD
az desktopvirtualization sessionhost list \
  --resource-group <rg> \
  --host-pool-name <hostpool> \
  --query "[].{Name:name, Status:status, LastHeartBeat:lastHeartBeat}" \
  --output table

# Verify FSLogix profile containers
# RDP to session host and check:
Get-ChildItem "C:\Program Files\FSLogix\Apps" -Recurse
Get-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles" -Name "VHDLocations"
```

## Variables

### VM Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `vm_count` | Number of session host VMs to deploy (1-100) | `number` | `2` | No |
| `vm_name_prefix` | Prefix for VM names (appended with -1, -2, etc.) | `string` | `"avd-sh"` | No |
| `vm_size` | VM SKU (e.g., Standard_D2s_v5) | `string` | `"Standard_D2s_v5"` | No |
| `timezone` | Timezone for VMs | `string` | `"UTC"` | No |

### Disk Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `os_disk_type` | OS disk type: Standard_LRS, StandardSSD_LRS, Premium_LRS | `string` | `"Premium_LRS"` | No |
| `os_disk_size_gb` | OS disk size in GB (null for default) | `number` | `null` | No |

### Image Source Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `gallery_image_version_id` | Gallery image version resource ID (null for marketplace) | `string` | `null` | No |
| `marketplace_image_reference` | Marketplace image reference (fallback) | `object` | Win11 Multi-Session | No |
| `managed_image_id` | Managed image resource ID | `string` | `null` | No |

### Credentials

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `local_admin_username` | Local administrator username | `string` | - | Yes |
| `local_admin_password` | Local administrator password (sensitive) | `string` | - | Yes |
| `domain_admin_username` | Domain administrator username | `string` | - | Yes |
| `domain_admin_password` | Domain administrator password (sensitive) | `string` | - | Yes |

### Domain Join Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `domain_name` | Fully qualified domain name (e.g., contoso.local) | `string` | - | Yes |
| `domain_netbios_name` | NetBIOS domain name (e.g., CONTOSO) | `string` | - | Yes |
| `domain_ou_path` | OU Distinguished Name for computer accounts | `string` | `""` | No |

### AVD Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `hostpool_name` | AVD host pool name | `string` | - | Yes |
| `hostpool_registration_token` | Host pool registration token (sensitive) | `string` | - | Yes |
| `fslogix_share_path` | UNC path to FSLogix profile share | `string` | - | Yes |

### Azure Resources

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `subnet_id` | Subnet ID for VMs | `string` | - | Yes |
| `vnet_dns_servers` | DNS server IPs (empty for VNet default) | `list(string)` | `[]` | No |
| `tags` | Resource tags | `map(string)` | `{}` | No |

## Outputs

See [outputs.tf](outputs.tf) for complete list of output values.

## Dependencies

This module depends on:
- **networking** module (VNet, subnets, NSGs)
- **domain-controller** module (AD DS, OU structure)
- **avd_core** module (host pool, registration token)
- **fslogix_storage** module (Azure Files share)
- **key_vault** module (optional, for secure password storage)
- **golden_image** module (optional, for custom images)

## Related Documentation

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [FSLogix Profile Containers](https://docs.microsoft.com/fslogix/configure-profile-container-tutorial)
- [Azure Compute Gallery](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [Golden Image Module README](../golden_image/README.md)
