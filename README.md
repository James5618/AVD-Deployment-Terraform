# Azure Virtual Desktop with Domain Controller - Terraform Playbook

Complete Terraform infrastructure-as-code for deploying Azure Virtual Desktop (AVD) with a minimal Active Directory Domain Controller for Group Policy management.

## Documentation Quick Links

- **[Quick Start](#quick-start)** - Deploy in 5 minutes
- **[Quick Reference Card](QUICK_REFERENCE.md)** - Configuration cheat sheet (print/bookmark this!)
- **[Configuration Guide](CONFIGURATION_GUIDE.md)** - Where to find and edit settings
- **[Session Host Image Strategies](#session-host-image-strategies)** - Marketplace, AIB Gallery, Manual Gallery
- **[Session Host Replacement Runbook](RUNBOOK_SESSION_HOST_REPLACEMENT.md)** - Zero-downtime rolling updates
- **[Scaling Plan Module](modules/scaling_plan/README.md)** - Auto-scaling for cost savings
- **[Conditional Access Module](modules/conditional_access/README.md)** - MFA & security policies (Entra ID)
- **[Module Reference Guide](MODULES.md)** - Detailed information about all modules
- **[Manual Golden Image](#manual-golden-image-creation-and-management)** - Create and manage custom images
- **[GPO Strategy](#group-policy-strategy-for-avd-session-hosts)** - Group Policy recommendations
- **[Validation Guide](#validation--testing)** - Verify domain join, GPO, FSLogix

**Key Configuration Files:**
- `envs/dev/terraform.tfvars.example` - Start here! Copy and customize
- `envs/dev/variables.tf` - All 80+ adjustable settings (nothing hidden)
- `envs/dev/main.tf` (lines 49-336) - USER CONFIG locals block

## Architecture Overview

This playbook deploys:
- **Virtual Network** with dedicated subnets for DC, AVD session hosts, and Azure Files
- **Domain Controller** (Windows Server 2022) with AD DS, DNS, and minimal spec
- **AVD Infrastructure** including workspace, host pool, and desktop application group
- **Session Host VMs** domain-joined to the DC and registered to the AVD host pool
- **Azure Files Storage** with SMB share for FSLogix user profiles
- **Security Modules** (optional):
  - Key Vault for secrets management
  - Conditional Access policies for MFA and device compliance
  - Scaling plan for cost optimization

## Prerequisites

### Required Tools
- [Terraform](https://www.terraform.io/downloads) >= 1.6.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50.0
- Azure subscription with Owner or Contributor + User Access Administrator role

### Azure Authentication
```bash
# Login to Azure
az login

# Set the subscription (if you have multiple)
az account set --subscription "your-subscription-id"

# Verify current subscription
az account show
```

## Quick Start

### 0. Find Configuration Settings

**All adjustable variables are easy to find in three locations:**

1. **terraform.tfvars.example** → Copy to terraform.tfvars, edit common settings
   - Most frequently changed settings at the top (passwords, domain name, VM sizes)
   - Comprehensive example with all options documented

2. **variables.tf** → Complete list of ALL configurable inputs
   - Every variable has description and default value
   - Organized by functional area (Basics, Networking, Domain, AVD, Storage, etc.)
   - Sensitive variables marked with `sensitive = true`
   - **Nothing is hidden** - all module inputs are surfaced here

3. **main.tf (locals block, lines 40-110)** → Quick reference
   - Shows how variables map to deployment settings
   - Most commonly adjusted knobs grouped at top

See [CONFIGURATION_GUIDE.md](CONFIGURATION_GUIDE.md) for detailed configuration instructions.

### 1. Clone and Navigate
```bash
cd envs/dev  # or envs/prod
```

### 2. Configure Variables
Copy the example file and customize:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Key variables to configure:**
- `location` - Azure region (e.g., "eastus", "westeurope")
- `domain_name` - AD domain name (e.g., "contoso.local")
- `domain_admin_username` - Domain administrator username
- `domain_admin_password` - Domain administrator password (use Azure Key Vault in prod!)
- `avd_users` - List of user principal names to assign to AVD desktop app group
- `session_host_count` - Number of AVD session hosts (default: 2)

### 3. Initialize Terraform
```bash
terraform init
```

### 4. Plan Deployment
```bash
terraform plan -out=tfplan
```

### 5. Deploy Infrastructure
```bash
terraform apply tfplan
```

**Expected deployment time:** 25-35 minutes
- Network resources: ~2 minutes
- Domain Controller + AD DS: ~15-20 minutes
- AVD + Session Hosts: ~10-15 minutes

### 6. Post-Deployment

After deployment completes:

1. **Verify Domain Controller:**
   ```bash
   # Get DC public IP from outputs
   terraform output dc_public_ip
   
   # RDP to the DC (use domain admin credentials)
   # Verify AD DS is running: Server Manager > AD DS
   ```

2. **Create AD Users for AVD:**
   - RDP to Domain Controller
   - Open "Active Directory Users and Computers"
   - Create user accounts under the domain
   - User principal names should match those in `avd_users` variable

3. **Access AVD:**
   - Users can access via https://client.wvd.microsoft.com/
   - Or download Windows Desktop client from Microsoft

## Repository Structure

### Root Files

| File | Description |
|------|-------------|
| `README.md` | Complete deployment guide |
| `CONFIGURATION_GUIDE.md` | How to find and edit settings |
| `QUICK_REFERENCE.md` | Configuration cheat sheet |
| `MODULES.md` | Module reference guide |
| `RUNBOOK_SESSION_HOST_REPLACEMENT.md` | Rolling update procedures |
| `.gitignore` | Protect sensitive files |

### Modules Directory

| Module | Purpose | Key Files |
|--------|---------|----------|
| `networking/` | VNet, subnets, NSGs | `main.tf`, `variables.tf`, `outputs.tf` |
| `domain-controller/` | Windows Server VM + AD DS | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `avd_core/` | AVD workspace, host pool, app groups | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `session-hosts/` | AVD session host VMs | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `fslogix_storage/` | Storage account + Azure Files | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `key_vault/` | Secrets management (optional) | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `golden_image/` | Azure Image Builder (optional) | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `scaling_plan/` | AVD auto-scaling - 60-80% cost savings | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `conditional_access/` | Entra ID security - MFA, device compliance | `main.tf`, `variables.tf`, `outputs.tf`, `README.md` |
| `logging/` | Log Analytics (optional) | Standard module files |
| `backup/` | Azure Backup (optional) | Standard module files |
| `update_management/` | Patch management (optional) | Standard module files |
| `cost_management/` | Budgets & alerts (optional) | Standard module files |

### Environments Directory

| Environment | Configuration Files | Description |
|-------------|---------------------|-------------|
| `envs/dev/` | `main.tf` | USER CONFIG locals (lines 40-110) |
| | `variables.tf` | ALL 52 variables with defaults |
| | `outputs.tf` | Output definitions |
| | `terraform.tfvars.example` | Quick start configuration |
| `envs/prod/` | Same structure as dev | Production environment configuration |

**Key Files for Configuration:**
- **terraform.tfvars.example** - Start here! Most common settings at top
- **variables.tf** - Complete list of ALL adjustable settings (nothing hidden)
- **main.tf (locals)** - Quick reference showing how variables are used
- **CONFIGURATION_GUIDE.md** - Detailed "where to find settings" guide

## Why Use a Domain Controller for AVD?

### Group Policy Management (GPO)
**This playbook uses Active Directory Domain Services (AD DS) domain join** instead of Entra ID-only authentication because:

**Group Policy Control** - Configure session hosts centrally via GPO:
- FSLogix profile container settings
- Windows optimization for VDI (disable consumer experiences, telemetry)
- RDP/AVD-specific policies (session timeouts, drive redirection)
- Security policies (Windows Firewall, AppLocker, etc.)

**Azure Files Authentication** - AD DS integration enables:
- Kerberos authentication to Azure Files shares
- NTFS permissions for FSLogix profile folders
- User-specific access control without storage account keys

**Organizational Unit (OU) Structure** - Session hosts are placed in a dedicated OU:
- Apply GPOs specifically to AVD machines
- Separate policies from other domain resources
- Easy filtering and targeting

### Domain Controller Sizing Guidance

**Development/Test (<10 session hosts):**
- VM Size: `Standard_B2ms` (2 vCPU, 8GB RAM)
- OS Disk: 128GB Standard SSD
- Cost: (~$60/month) (~€56/month) (~£48/month)
- Sufficient for small AVD deployments

**Production (10-50 session hosts):**
- VM Size: `Standard_D2s_v5` (2 vCPU, 8GB RAM)
- OS Disk: 128GB Premium SSD
- Cost: (~$70/month) (~€65/month) (~£56/month)
- Recommended: Deploy 2 DCs for high availability

**Large Production (50+ session hosts):**
- VM Size: `Standard_D4s_v5` (4 vCPU, 16GB RAM)
- OS Disk: 256GB Premium SSD
- Cost: (~$140/month) (~€130/month) (~£112/month) per DC
- Deploy 2-3 DCs across availability zones

**Key Considerations:**
- DCs have minimal CPU load for AVD workloads (mostly DNS queries)
- Network latency is more important than CPU/RAM
- No public IP in production - use Azure Bastion for management

## Deployment Order & Dependency Management

To avoid circular dependencies, resources are deployed in strict order:

| Step | Component | Details | Dependencies |
|------|-----------|---------|-------------|
| 1 | **Networking** | VNet, Subnets, NSGs<br>DNS: Empty initially (no DC yet) | None |
| 2 | **Domain Controller** | Windows Server + AD DS<br>- Installs AD DS role<br>- Creates forest and domain<br>- Creates OU=AVD-SessionHosts<br>Duration: ~15-20 minutes | Networking |
| 3 | **Update VNet DNS** | null_resource with Azure CLI<br>Sets VNet DNS servers = [DC_Private_IP]<br>Why: Session hosts need to resolve domain names | Domain Controller |
| 4 | **FSLogix Storage** | Azure Files for user profiles | VNet DNS |
| 5 | **AVD Core** | Host Pool, Workspace, App Groups | VNet DNS |
| 6 | **Session Hosts** | Domain-Joined AVD VMs<br>- Domain join to OU=AVD-SessionHosts<br>- AVD agent registration<br>- FSLogix configuration | DC, DNS update, Storage, AVD Core |

**Note:** Steps 4 and 5 (FSLogix Storage and AVD Core) can deploy in parallel as they don't depend on each other.

**Critical:** Session hosts **cannot** join the domain until:
1. DC has AD DS fully installed and promoted
2. VNet DNS is updated to point to DC (otherwise domain name resolution fails)
3. OU exists for computer account placement

## Domain Join & OU Placement

### How Session Hosts Are Domain-Joined

Each session host VM goes through these extension deployments in sequence:

**Step 1: JsonADDomainExtension** (Domain Join)
```powershell
# Microsoft-provided extension for domain join
# Computer account is created in: OU=AVD-SessionHosts,DC=avd,DC=local
# Duration: ~3-5 minutes per VM
```

**Step 2: DSC Extension** (AVD Agent)
```powershell
# Installs AVD agent and registers to host pool
# Uses registration token from AVD Core module
# Duration: ~2-3 minutes per VM
```

**Step 3: CustomScriptExtension** (FSLogix Configuration)
```powershell
# Configures FSLogix registry settings
# Sets VHDLocations to Azure Files UNC path
# Duration: ~1 minute per VM
```

### Organizational Unit (OU) Structure

```
DC=avd,DC=local
├── Domain Controllers
├── Users
├── Computers
└── AVD-SessionHosts (Created by domain_controller module)
    ├── dev-avd-sh-0
    ├── dev-avd-sh-1
    └── dev-avd-sh-2
```

**Why a Dedicated OU?**
- Apply AVD-specific GPOs only to session hosts
- Block GPO inheritance from domain root if needed
- Easy to identify and manage AVD machines
- Simplifies RBAC and delegated administration

## Session Host Image Strategies

This playbook supports **three image deployment strategies** for AVD session hosts, configured via the `session_host_image_strategy` variable:

### Image Strategy Overview

| Strategy | Source | Use Case | Deployment Speed | Maintenance | Flexibility |
|----------|--------|----------|------------------|-------------|-------------|
| **marketplace** | Azure Marketplace | Quick testing, POCs, simple environments | 15-20 min | Low (updates per VM) | Limited |
| **aib_gallery** | Azure Image Builder → Compute Gallery | Production, automated builds, CI/CD | 5-10 min | Medium (monthly rebuilds) | High |
| **manual_gallery** | Manual prep → Compute Gallery | Complex apps, legacy software, migrations | 5-10 min | High (manual process) | Highest |

### Strategy 1: Marketplace Images

**Configuration:**
```hcl
# In terraform.tfvars
session_host_image_strategy = "marketplace"
```

**How it works:**
```
Azure Marketplace (Windows 11 Multi-session + M365)
    ↓
Session Hosts deploy directly from marketplace
    ↓
Post-deployment: Domain join + AVD agent + FSLogix
```

**Pros:**
- Zero setup - works out of the box
- Always latest Microsoft-published images
- No additional infrastructure required
- Perfect for testing and development

**Cons:**
- Longer deployment time (15-20 minutes per host)
- No application pre-installation
- Updates required on each VM individually
- Inconsistent VM state until updates complete

**Best for:**
- Development/test environments
- Proof of concepts
- Quick demos
- Small deployments (<5 hosts)

### Strategy 2: Azure Image Builder → Compute Gallery (Recommended)

**Configuration:**
```hcl
# In terraform.tfvars
session_host_image_strategy = "aib_gallery"
enable_golden_image = true
pin_golden_image_version = true  # Pinned (prod) or false (latest)

# Golden image configuration
golden_image_version = "1.0.0"
golden_image_base_sku = "win11-22h2-avd-m365"
install_windows_updates = true
chocolatey_packages = ["googlechrome", "7zip", "adobereader"]
```

**How it works:**
```
1. Terraform creates AIB template
    ↓
2. Manually trigger build (30-90 min):
   az image builder run --name <template-name>
    ↓
3. AIB creates VM → Installs apps → Updates → Sysprep
    ↓
4. Publishes to Azure Compute Gallery as versioned image
    ↓
5. Session hosts deploy from gallery (5-10 min)
```

**Pros:**
- Fast deployment from gallery (5-10 minutes)
- Repeatable, versioned, automated builds
- Infrastructure as code (defined in Terraform)
- Multi-region replication
- Version pinning for production stability
- Easy rollback to previous versions

**Cons:**
- Initial build time (30-90 minutes)
- Requires manual trigger for each build
- Applications must support unattended installation
- Additional Azure costs (~$1-3 per build) (~€0.90-2.80 per build) (~£0.80-2.40 per build), (~$5-15/month storage) (~€4.70-14/month storage) (~£4-12/month storage)

**Best for:**
- Production environments
- Environments requiring frequent updates
- Applications with scripted installations
- Organizations with CI/CD pipelines
- Multi-region deployments

**Monthly maintenance workflow:**
```bash
# 1. Update image version in terraform.tfvars
golden_image_version = "1.1.0"

# 2. Apply Terraform (creates new AIB template)
terraform apply

# 3. Trigger build
az image builder run --resource-group <rg> --name <template-name>

# 4. Monitor build (30-90 minutes)
az image builder show --name <template> --query lastRunStatus

# 5. Roll out to session hosts (see rollout strategy below)
```

### Strategy 3: Manual Image → Compute Gallery

**Configuration:**
```hcl
# In terraform.tfvars
session_host_image_strategy = "manual_gallery"
enable_gallery_import = true
pin_image_version_id = true  # Pinned (prod) or false (latest)

# Manual image import configuration
image_source_type = "managed_image"  # or "vhd"
source_managed_image_id = "/subscriptions/.../Microsoft.Compute/images/my-golden-image"
gallery_image_version = "1.0.0"
```

**How it works:**
```
1. Manually create reference VM in Azure
    ↓
2. Install applications (GUI or scripts)
    ↓
3. Configure settings, apply security baselines
    ↓
4. Sysprep and generalize
    ↓
5. Capture as managed image or export VHD
    ↓
6. Terraform imports into Compute Gallery as versioned image
    ↓
7. Session hosts deploy from gallery (5-10 min)
```

**Pros:**
- Full control over every configuration step
- Support for complex GUI-based installations
- Legacy application compatibility
- One-time migration scenarios
- Manual verification before deployment
- Fast deployment once in gallery (5-10 minutes)

**Cons:**
- Manual process - not repeatable
- Requires RDP access and manual setup
- Time-consuming for frequent updates
- Prone to configuration drift
- No automation or version control

**Best for:**
- Complex applications requiring manual installation
- Legacy software without silent install options
- One-time migrations from on-premises
- Highly regulated environments requiring manual verification
- Applications with complex licensing (dongles, network licenses)

**Manual preparation workflow:**
```bash
# 1. Create reference VM
az vm create --name vm-golden-ref --image MicrosoftWindowsDesktop:windows-11:win11-22h2-avd:latest

# 2. RDP to VM and configure
# - Install applications
# - Apply settings
# - Run Windows Update

# 3. Sysprep
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown

# 4. Capture as managed image
az image create --name golden-image-v1 --source vm-golden-ref --os-type Windows

# 5. Update terraform.tfvars with image ID
source_managed_image_id = "/subscriptions/.../images/golden-image-v1"
gallery_image_version = "1.0.0"

# 6. Apply Terraform (imports to Compute Gallery)
terraform apply

# 7. Roll out to session hosts
```

---

## Gallery Image Rollout Strategy

When using **aib_gallery** or **manual_gallery** strategies, use version pinning for controlled rollouts.

### Production Rollout: Pinned Versions (Recommended)

**Step 1: Build and Test New Version**
```hcl
# terraform.tfvars
session_host_image_strategy = "aib_gallery"
golden_image_version = "1.1.0"  # New version
pin_golden_image_version = true  # Pin to specific version
```

**Step 2: Deploy to Pilot Session Hosts (10%)**
```hcl
# Deploy 1-2 hosts with new image for testing
session_host_count = 2
```

```bash
terraform apply
```

**Step 3: Validate Pilot Deployment**
- [ ] Session hosts deploy successfully
- [ ] Applications launch correctly
- [ ] User profiles load from FSLogix
- [ ] No errors in Event Viewer
- [ ] Performance metrics normal

**Step 4: Drain Old Session Hosts**
```bash
# Set drain mode on old hosts (stop new connections)
az desktopvirtualization sessionhost update \
  --resource-group <rg> \
  --host-pool-name <pool> \
  --name <host> \
  --allow-new-session false

# Wait for active sessions to complete
az desktopvirtualization sessionhost list \
  --resource-group <rg> \
  --host-pool-name <pool> \
  --query "[?allowNewSession==\`false\`].{Name:name, Sessions:session}"
```

**Step 5: Rolling Update (Blue-Green)**
```hcl
# Increment host count to create new hosts alongside old ones
session_host_count = 4  # Was 2, now 4 (2 old + 2 new)
```

```bash
terraform apply  # Creates 2 new hosts with v1.1.0
```

**Step 6: Decommission Old Hosts**
```bash
# After all users migrated to new hosts
# Delete old session hosts via Azure Portal or:
az vm delete --ids <old-vm-ids>

# Update Terraform state
terraform apply  # Reconciles state
```

### Alternative: Replace All Hosts (Downtime Method)

**For non-production or scheduled maintenance windows:**

```hcl
# Update to new image version
golden_image_version = "1.1.0"
```

```bash
# Destroy old hosts
terraform destroy -target=module.session_hosts

# Recreate with new image
terraform apply
```

**Downtime:** ~10-15 minutes while new hosts deploy

---

## Gallery Image Rollback Strategy

Version pinning enables instant rollback to previous working image.

### Immediate Rollback (Emergency)

**If new image version has critical issues:**

```hcl
# terraform.tfvars - Change version back
golden_image_version = "1.0.0"  # Previous working version
pin_golden_image_version = true
```

```bash
# Recreate hosts with old image
terraform destroy -target=module.session_hosts
terraform apply
```

**Recovery Time:** ~10 minutes

### Gradual Rollback (Controlled)

**If issues discovered after partial rollout:**

**Step 1: Stop New Deployments**
```hcl
# Keep current host count, don't scale up
session_host_count = 2  # Don't increase
```

**Step 2: Deploy Hosts with Previous Version**
```hcl
golden_image_version = "1.0.0"  # Rollback version
```

```bash
# Create new hosts with old image alongside problematic hosts
terraform apply
```

**Step 3: Drain Problematic Hosts**
```bash
# Set drain mode on v1.1.0 hosts
az desktopvirtualization sessionhost update \
  --name <v1.1.0-host> \
  --allow-new-session false
```

**Step 4: Remove Problematic Hosts**
```bash
# After sessions drained
az vm delete --ids <v1.1.0-host-ids>
```

### Testing Strategy Before Production

**Always test new image versions in non-production first:**

```hcl
# envs/dev/terraform.tfvars
session_host_image_strategy = "aib_gallery"
golden_image_version = "1.1.0"  # Test new version
pin_golden_image_version = true
session_host_count = 1
```

**Validation checklist:**
- [ ] VM deploys successfully and domain joins
- [ ] AVD agent registers to host pool
- [ ] All applications launch correctly
- [ ] FSLogix profile loads
- [ ] User can login via AVD
- [ ] Performance acceptable (CPU, memory, disk)
- [ ] No critical errors in Event Viewer

**After successful testing, promote to production:**
```hcl
# envs/prod/terraform.tfvars
golden_image_version = "1.1.0"
```

### Version Management Best Practices

**Semantic Versioning:**
- `1.0.0` - Initial production image
- `1.1.0` - Added new application (Chrome)
- `1.1.1` - Patched Chrome security issue
- `2.0.0` - Major OS upgrade (Win 11 23H2)

**Version Pinning Strategy:**
- **Production:** `pin_golden_image_version = true` (controlled updates)
- **Development:** `pin_golden_image_version = false` (auto-update to latest)

---

## Group Policy Strategy for AVD Session Hosts

### Recommended GPO Structure

Create the following Group Policy Objects and link them to `OU=AVD-SessionHosts`:

#### 1. **FSLogix Profile Container Settings**

**GPO Name:** `AVD-FSLogix-Configuration`

**Path:** `Computer Configuration > Policies > Administrative Templates > FSLogix > Profile Containers`

**Settings:**
```
Enabled = 1
VHD Locations = \\<storage-account>.file.core.windows.net\user-profiles
Size in MBs = 30000 (30GB)
IsDynamic = 1 (dynamic disk expansion)
Volume Type = VHDX
Delete local profile when VHD should apply = 1
Profile type = Try for read-write profile, fallback to read-only = 3
Prevent Login with Failure = 0 (allow login even if FSLogix fails)
Prevent Login with Temp Profile = 0
```

**Additional FSLogix Settings:**
```
Flip Flop Profile Directory Name = 1 (use SID for folder names)
VHD Name Pattern = %username%_%sid%
Log Level = 2 (warnings and errors)
Log Directory = C:\ProgramData\FSLogix\Logs
```

**Exclusions (Optimize profile size):**
```
Redirect downloads folder = 1
Redirect temp folder = 1
```

#### 2. **Windows Optimization for VDI**

**GPO Name:** `AVD-Windows-Optimization`

**Disable Consumer Experiences:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Cloud Content`
- Setting: `Turn off Microsoft consumer experiences` = **Enabled**

**Disable Windows Tips:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Cloud Content`
- Setting: `Do not show Windows tips` = **Enabled**

**Optimize Windows Search:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Search`
- Setting: `Allow Cortana` = **Disabled**
- Setting: `Don't search the web or display web results in Search` = **Enabled**

**Disable Telemetry:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Data Collection and Preview Builds`
- Setting: `Allow Telemetry` = **Enabled: 0 - Security**

**Disable Scheduled Tasks (Reduce CPU/Disk overhead):**
```powershell
# Create a GPO with Scheduled Task preferences to disable:
# - Disk Defragmentation
# - Windows Update (if using managed updates)
# - Maintenance tasks
```

**Power Settings:**
- Path: `Computer Configuration > Policies > Administrative Templates > System > Power Management`
- Setting: `Turn off hybrid sleep` = **Enabled**
- Setting: `Specify the system hibernate timeout` = **Enabled: 0** (never hibernate)

#### 3. **RDP and AVD Policy Settings**

**GPO Name:** `AVD-RDP-Configuration`

**Session Time Limits:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Session Time Limits`
- `Set time limit for disconnected sessions` = **Enabled: 1 hour**
- `Set time limit for active but idle sessions` = **Enabled: 30 minutes**
- `Set time limit for active sessions` = **Enabled: 8 hours**

**Drive Redirection:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Device and Resource Redirection`
- `Do not allow drive redirection` = **Disabled** (allow selective redirection)
- `Do not allow clipboard redirection` = **Disabled** (allow clipboard)

**Printer Redirection:**
- Path: Same as above
- `Do not allow client printer redirection` = **Enabled** (disable unless required)
- `Redirect only the default client printer` = **Enabled**

**RemoteFX:**
- Path: `Computer Configuration > Policies > Administrative Templates > Windows Components > Remote Desktop Services > Remote Desktop Session Host > Remote Session Environment`
- `Enable RemoteFX encoding for RemoteFX clients` = **Enabled**
- `Configure compression for RemoteFX data` = **Do not use RDP compression**

**Audio Redirection:**
- Path: Same as above
- `Allow audio and video playback redirection` = **Enabled**
- `Allow audio recording redirection` = **Enabled** (if needed)

#### 4. **Security Policies**

**GPO Name:** `AVD-Security-Baseline`

**Windows Firewall:**
- Path: `Computer Configuration > Policies > Windows Settings > Security Settings > Windows Defender Firewall`
- Enable firewall for all profiles
- Configure rules as needed

**User Rights Assignment:**
- Path: `Computer Configuration > Policies > Windows Settings > Security Settings > Local Policies > User Rights Assignment`
- `Allow log on through Remote Desktop Services` = **Domain Users** (or specific AVD group)
- `Deny log on locally` = **Guests**

**Audit Policies:**
- Path: `Computer Configuration > Policies > Windows Settings > Security Settings > Advanced Audit Policy Configuration`
- Enable logon/logoff auditing
- Enable object access auditing

#### 5. **Office 365 Optimization (if using)**

**GPO Name:** `AVD-Office365-Optimization`

**OneDrive:**
- Use OneDrive Files On-Demand
- Cache only frequently accessed files
- Exclude OneDrive from FSLogix profile

**Teams:**
- Enable media optimization for Teams in AVD
- Configure Teams registry keys for VDI mode

### GPO Application Order

Link GPOs to `OU=AVD-SessionHosts` in this order (lowest to highest priority):
1. AVD-Security-Baseline (base security)
2. AVD-Windows-Optimization (OS optimization)
3. AVD-RDP-Configuration (RDP settings)
4. AVD-FSLogix-Configuration (FSLogix - highest priority)

**Block Inheritance:** Consider blocking inheritance from domain root to prevent conflicts.

## Validation & Testing

### 1. Verify Domain Join

**From Session Host (RDP or Run Command):**
```powershell
# Check domain membership
systeminfo | findstr /B "Domain"
# Expected: Domain: avd.local

# Verify computer account location
$computer = Get-ADComputer -Identity $env:COMPUTERNAME
$computer.DistinguishedName
# Expected: CN=dev-avd-sh-0,OU=AVD-SessionHosts,DC=avd,DC=local

# Verify domain DNS resolution
nslookup avd.local
# Should resolve to DC IP (e.g., 10.0.1.4)
```

**From Domain Controller:**
```powershell
# List all session hosts in AVD OU
Get-ADComputer -Filter * -SearchBase "OU=AVD-SessionHosts,DC=avd,DC=local"

# Verify last logon time (check domain trust)
Get-ADComputer -Identity "dev-avd-sh-0" -Properties LastLogonDate | Select-Object Name, LastLogonDate
```

### 2. Verify OU Placement

**From Session Host:**
```powershell
# Show computer OU path
(Get-ADComputer -Identity $env:COMPUTERNAME).DistinguishedName
# Expected: CN=dev-avd-sh-0,OU=AVD-SessionHosts,DC=avd,DC=local
```

**From Domain Controller:** Use Active Directory Users and Computers (dsa.msc) to verify all session hosts appear in the AVD-SessionHosts OU.

### 3. Verify GPO Application

**From Session Host:**
```powershell
# Force GPO update
gpupdate /force

# View applied GPOs (detailed report)
gpresult /H C:\Temp\gpresult.html

# Or use command line version
gpresult /R /SCOPE:COMPUTER

# Expected output should show:
# - Applied Group Policy Objects from OU=AVD-SessionHosts
# - FSLogix policies
# - RDP configuration policies
# - Windows optimization policies

# Check specific FSLogix registry settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\FSLogix\Profiles"
# Verify: Enabled=1, VHDLocations=<Azure Files path>
```

**Key GPO Results to Verify:**
```
The computer is a part of the following security groups:
   BUILTIN\Administrators
   Domain Computers
   
The computer received Group Policy settings from these GPOs:
   AVD-FSLogix-Configuration
   AVD-Windows-Optimization
   AVD-RDP-Configuration
   AVD-Security-Baseline
   Default Domain Policy
```

### 4. Verify FSLogix Profile Creation

**Test User Login Process:**

1. **Log in to AVD as a test user** via https://client.wvd.microsoft.com/ 

2. **First login creates profile container:**
   - FSLogix creates VHDX file on Azure Files share
   - File name: `<username>_<SID>` or `<SID>_<username>` (depending on flip-flop setting)
   - Initial size: ~30-50MB, expands as needed

3. **Check Azure Files share from Domain Controller or session host:**
```powershell
# Mount Azure Files share
$storageAccount = "avddevfslogix"
$shareName = "user-profiles"

# Use domain credentials (Kerberos auth after AD DS join)
New-PSDrive -Name "Z" -PSProvider FileSystem `
  -Root "\\$storageAccount.file.core.windows.net\$shareName" -Persist

# List profile containers
Get-ChildItem -Path Z:\ | Select-Object Name, Length, LastWriteTime

# Expected output:
# Name                                     Length         LastWriteTime
# ----                                     ------         -------------
# john.doe_S-1-5-21-xxx                   52428800       1/25/2026 10:30:00 AM
# jane.smith_S-1-5-21-xxx                 41943040       1/25/2026 11:15:00 AM

# Check profile folder structure
Get-ChildItem -Path "Z:\john.doe_S-1-5-21-xxx"
# Should contain: Profile_john.doe.vhdx (or .vhd)
```

4. **Verify VHDX file properties:**
```powershell
# On session host, check FSLogix logs
Get-Content "C:\ProgramData\FSLogix\Logs\Profile\*.log" | Select-String "Successfully loaded"

# Expected log entries:
# [INFO] Successfully loaded profile from \\avddevfslogix.file.core.windows.net\user-profiles
# [INFO] VHD/VHDX mounted successfully
```

5. **Test profile persistence:**
   - Create a file on the desktop
   - Log off from AVD session
   - Log back in
   - Verify the file persists (profile is loading from VHDX)

### 5. Verify Azure Files Authentication

**Check AD DS integration for Azure Files:**

```powershell
# From domain-joined machine with AzFilesHybrid module
Import-Module AzFilesHybrid

# Verify storage account is domain-joined
Get-AzStorageAccount -ResourceGroupName "avd-dev-rg" -Name "avddevfslogix" | `
  Select-Object -ExpandProperty AzureFilesIdentityBasedAuth

# Expected output:
# DirectoryServiceOptions : AD
# ActiveDirectoryProperties : Microsoft.Azure.Management.Storage.Models.ActiveDirectoryProperties

# Test Kerberos ticket for file share
klist get cifs/avddevfslogix.file.core.windows.net

# Should return Kerberos ticket without prompting for credentials
```

**Verify NTFS Permissions:**
```powershell
# Check RBAC role assignments (Share-level permissions)
Get-AzRoleAssignment -Scope "/subscriptions/<sub-id>/resourceGroups/avd-dev-rg/providers/Microsoft.Storage/storageAccounts/avddevfslogix"

# Expected: "Storage File Data SMB Share Contributor" for AVD users group

# Check NTFS permissions (Directory-level permissions)
icacls "\\avddevfslogix.file.core.windows.net\user-profiles"

# Expected: 
# CREATOR OWNER:(OI)(CI)(IO)(F)
# Domain Users:(M)
```

### 6. End-to-End Validation Checklist

- [ ] Domain Controller is running and AD DS is healthy
- [ ] VNet DNS points to DC private IP (10.0.1.4)
- [ ] OU "AVD-SessionHosts" exists in Active Directory
- [ ] Session hosts appear in the AVD OU
- [ ] Session hosts can resolve domain name via `nslookup avd.local`
- [ ] GPOs are applied (`gpresult /R` shows AVD GPOs)
- [ ] FSLogix registry keys are configured correctly
- [ ] Azure Files share is domain-joined to AD DS
- [ ] Test user can log in to AVD via web client
- [ ] FSLogix creates profile container (VHDX) on first login
- [ ] User desktop settings persist across logons
- [ ] No errors in FSLogix logs (`C:\ProgramData\FSLogix\Logs`)

## Manual Golden Image Creation and Management

### Overview

In addition to automated golden image builds with Azure Image Builder (see `modules/golden_image/`), you can manually create and maintain custom images for your AVD session hosts. This approach is ideal for:

- **Complex applications** that require manual installation or configuration
- **Legacy software** that doesn't support unattended installation
- **One-time migrations** from on-premises or other cloud environments
- **Special compliance requirements** that require manual verification steps

This playbook provides the `manual_image_import` module to import your manually prepared images into Azure Compute Gallery, enabling versioning, replication, and easy deployment to session hosts.

**For detailed technical documentation**, see [modules/manual_image_import/README.md](modules/manual_image_import/README.md)

### When to Use Manual vs Automated Golden Images

| Approach | Best For | Pros | Cons |
|----------|----------|------|------|
| **Automated (Azure Image Builder)** | Production environments with frequent updates | Repeatable, versioned, automated | Requires scripted installation |
| **Manual (This guide)** | Complex apps, migrations, one-time setups | Full control, GUI installation | Manual process, not repeatable |

### Prerequisites

Before creating a manual golden image, ensure you have:

- [ ] Azure subscription with permissions to create VMs and images
- [ ] Windows license (Azure Marketplace or bring-your-own)
- [ ] List of applications and configurations needed
- [ ] Understanding of sysprep and Windows generalization
- [ ] Storage account (if using VHD export method)

---

## Step 1: Prepare Reference VM

Create and configure a "reference VM" that will become your golden image.

### 1.1 Create a Windows VM in Azure

```bash
# Create a resource group for temporary image build resources
az group create --name rg-image-build --location eastus

# Create a Windows 11 Multi-Session VM
az vm create \
  --resource-group rg-image-build \
  --name vm-avd-reference \
  --image MicrosoftWindowsDesktop:windows-11:win11-22h2-avd:latest \
  --size Standard_D4s_v5 \
  --admin-username azureuser \
  --admin-password 'YourSecurePassword123!' \
  --public-ip-sku Standard \
  --nic-delete-option Delete \
  --os-disk-delete-option Delete

# Get public IP to connect via RDP
az vm show -d --resource-group rg-image-build --name vm-avd-reference --query publicIps -o tsv
```

**Tip:** Use a larger VM size during build (D4s_v5) for faster installations, then deploy session hosts with smaller sizes.

### 1.2 Install Applications and Updates

Connect via RDP and install your applications:

1. **Install Windows Updates:**
   - Settings → Windows Update → Check for updates
   - Restart as needed until no updates remain

2. **Install Required Applications:**
   - Microsoft 365 Apps
   - Line-of-business applications
   - Browser extensions, certificates, fonts
   - Any other required software

3. **Configure Windows Settings:**
   - Time zone, regional settings
   - Default file associations
   - Windows features (enable/disable)

4. **Optimize Performance:**
   ```powershell
   # Disable unnecessary services
   Get-Service -Name "DiagTrack" | Set-Service -StartupType Disabled
   
   # Clear temporary files
   Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
   Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
   
   # Clear Windows Update cache
   Stop-Service -Name wuauserv
   Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
   Start-Service -Name wuauserv
   ```

### 1.3 Pre-Sysprep Cleanup

Before generalizing, clean up user-specific data:

```powershell
# Remove user profiles (except default and current)
Get-WmiObject -Class Win32_UserProfile | Where-Object { 
  $_.Special -eq $false -and $_.LocalPath -notlike "*azureuser*" 
} | Remove-WmiObject

# Clear event logs
Get-EventLog -LogName * | ForEach-Object { Clear-EventLog $_.Log }

# Clear browser cache/history (if applicable)
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue

# Compact OS disk (optional, saves space)
Optimize-Volume -DriveLetter C -Defrag -Verbose
```

---

## Step 2: Generalize with Sysprep

Sysprep removes machine-specific information and prepares the VM for imaging.

### 2.1 Run Sysprep

**CRITICAL:** Once you run sysprep, the VM will shut down and cannot be restarted. Ensure all configurations are complete!

```powershell
# Run sysprep from PowerShell (as Administrator)
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /mode:vm

# Alternative: Use unattend.xml for automated setup (optional)
# C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /unattend:C:\path\to\unattend.xml
```

**Parameter Explanation:**
- `/generalize` - Removes unique system information (SID, hardware IDs)
- `/oobe` - Boots to Windows Welcome screen on first start
- `/shutdown` - Shuts down VM after completion
- `/mode:vm` - Optimizes for VM deployment

### 2.2 Wait for Completion

The sysprep process takes 5-15 minutes. Monitor in Azure Portal:
- VM status will change to "Stopped"
- **DO NOT start the VM** after sysprep completes

### 2.3 Verify Sysprep Completion

Check sysprep logs (before running sysprep or via serial console):

```powershell
# Check sysprep logs for errors
Get-Content C:\Windows\System32\Sysprep\Panther\setupact.log | Select-String -Pattern "Error|Failed"

# Verify generalization state
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State" | Select-Object ImageState
# Should be "IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE"
```

### 2.4 Deallocate and Generalize in Azure

After sysprep shuts down the VM:

```bash
# Deallocate the VM
az vm deallocate --resource-group rg-image-build --name vm-avd-reference

# Mark the VM as generalized in Azure
az vm generalize --resource-group rg-image-build --name vm-avd-reference
```

**Important:** You MUST run `az vm generalize` before capturing. This marks the VM as generalized in Azure's metadata.

---

## Step 3: Capture Image

Choose one of two methods:

### **Option A: Managed Image → Compute Gallery (RECOMMENDED)**

This is the simplest method for most scenarios.

#### A.1 Create Managed Image

```bash
# Capture VM to managed image
az image create \
  --resource-group rg-image-build \
  --name img-win11-avd-custom-v1 \
  --source vm-avd-reference \
  --hyper-v-generation V2 \
  --tags "version=1.0.0" "os=Windows11" "type=AVD"

# Get the managed image ID
az image show \
  --resource-group rg-image-build \
  --name img-win11-avd-custom-v1 \
  --query id -o tsv
```

#### A.2 Import to Compute Gallery via Terraform

Update `envs/dev/terraform.tfvars`:

```hcl
# Enable manual image import
enable_manual_image_import = true

# Specify managed image as source
manual_image_source_type      = "managed_image"
manual_image_managed_image_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-image-build/providers/Microsoft.Compute/images/img-win11-avd-custom-v1"

# Image configuration
manual_image_version         = "1.0.0"
manual_image_definition_name = "windows11-avd-custom"
manual_image_publisher       = "MyCompany"
manual_image_offer           = "Windows11-AVD"
manual_image_sku             = "Custom"
manual_image_hyper_v_generation = "V2"
```

Run Terraform:

```bash
cd envs/dev
terraform init
terraform apply -target=module.manual_image_import  # Import image first
terraform apply                                      # Deploy session hosts with new image
```

---

### **Option B: VHD Export → Managed Image → Compute Gallery**

Use this method if you need to:
- Transfer images between Azure tenants
- Archive images to blob storage for backup
- Use images from on-premises Hyper-V

#### B.1 Export OS Disk to VHD

```bash
# Get the OS disk ID
DISK_ID=$(az vm show \
  --resource-group rg-image-build \
  --name vm-avd-reference \
  --query storageProfile.osDisk.managedDisk.id -o tsv)

# Grant temporary SAS access to the disk (valid for 1 hour)
SAS_URL=$(az disk grant-access \
  --resource-group rg-image-build \
  --name $(basename $DISK_ID) \
  --duration-in-seconds 3600 \
  --access-level Read \
  --query accessSas -o tsv)

# Create storage account for VHD (if needed)
az storage account create \
  --resource-group rg-image-build \
  --name stgavdimages$(date +%s | tail -c 8) \
  --location eastus \
  --sku Standard_LRS

STORAGE_ACCOUNT_NAME="<your-storage-account-name>"
STORAGE_KEY=$(az storage account keys list \
  --resource-group rg-image-build \
  --account-name $STORAGE_ACCOUNT_NAME \
  --query "[0].value" -o tsv)

# Create container
az storage container create \
  --name vhds \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_KEY

# Copy disk to VHD blob (this takes 15-30 minutes)
az storage blob copy start \
  --source-uri "$SAS_URL" \
  --destination-blob win11-avd-custom-v1.vhd \
  --destination-container vhds \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_KEY

# Monitor copy progress
az storage blob show \
  --container-name vhds \
  --name win11-avd-custom-v1.vhd \
  --account-name $STORAGE_ACCOUNT_NAME \
  --account-key $STORAGE_KEY \
  --query properties.copy.status -o tsv
```

#### B.2 Import VHD to Compute Gallery via Terraform

Update `envs/dev/terraform.tfvars`:

```hcl
# Enable manual image import
enable_manual_image_import = true

# Specify VHD as source
manual_image_source_type = "vhd"
manual_image_vhd_uri     = "https://stgavdimages12345678.blob.core.windows.net/vhds/win11-avd-custom-v1.vhd"

# Image configuration
manual_image_version         = "1.0.0"
manual_image_definition_name = "windows11-avd-custom"
manual_image_publisher       = "MyCompany"
manual_image_offer           = "Windows11-AVD"
manual_image_sku             = "Custom"
manual_image_hyper_v_generation = "V2"
```

Run Terraform:

```bash
cd envs/dev
terraform apply -target=module.manual_image_import
terraform apply
```

**Note:** The VHD method creates an intermediate managed image automatically, then imports to Compute Gallery.

---

## Step 4: Rolling Update to New Image Version

When you need to update session hosts with a new image version (e.g., v1.1.0 with updated apps):

### 4.1 Prepare New Image Version

Repeat Steps 1-3 with your updates:
1. Create new reference VM (or use snapshot of previous VM)
2. Install updates/new applications
3. Run sysprep and capture
4. Increment version number (e.g., `1.0.0` → `1.1.0`)

### 4.2 Set Existing Session Hosts to Drain Mode

Prevent new user sessions while allowing existing sessions to complete:

```bash
# Set all session hosts to drain mode (do not allow new sessions)
RESOURCE_GROUP="avd-dev-rg"
HOST_POOL_NAME="avd-dev-hostpool"

# Get all session hosts
SESSION_HOSTS=$(az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL_NAME \
  --query "[].name" -o tsv)

# Set each to drain mode
for HOST in $SESSION_HOSTS; do
  echo "Setting $HOST to drain mode..."
  az desktopvirtualization sessionhost update \
    --resource-group $RESOURCE_GROUP \
    --host-pool-name $HOST_POOL_NAME \
    --name $HOST \
    --allow-new-session false
done
```

### 4.3 Wait for User Sessions to Complete

```bash
# Monitor active sessions
az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL_NAME \
  --query "[].{Name:name, Sessions:session, Status:status}" -o table

# Wait until session count is 0 for all hosts (or force logoff after business hours)
```

### 4.4 Update Terraform Configuration

Update `envs/dev/terraform.tfvars` with new image version:

```hcl
# Increment version number
manual_image_version = "1.1.0"  # Changed from 1.0.0

# Optionally: Increment managed_image_id or vhd_uri if you created a new capture
manual_image_managed_image_id = "/subscriptions/.../images/img-win11-avd-custom-v2"
```

### 4.5 Apply Terraform Update

```bash
cd envs/dev

# Import new image version to gallery
terraform apply -target=module.manual_image_import

# Update session hosts (will recreate VMs with new image)
terraform apply -target=module.session_hosts

# Verify outputs
terraform output -json | jq '.session_hosts_info'
```

**Important:** Terraform will **recreate** session host VMs when the image changes. This is expected behavior.

### 4.6 Validate New Session Hosts

```bash
# Check new VMs are running
az vm list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'avd-dev-sh')].{Name:name, Status:powerState}" -o table

# Verify AVD registration
az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL_NAME \
  --query "[].{Name:name, Status:status, AgentVersion:agentVersion}" -o table

# Test user login
# Users should now connect to new session hosts automatically
```

### 4.7 Re-enable Session Hosts

After validation, allow new sessions:

```bash
# Enable all session hosts
for HOST in $(az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL_NAME \
  --query "[].name" -o tsv); do
  
  echo "Enabling $HOST..."
  az desktopvirtualization sessionhost update \
    --resource-group $RESOURCE_GROUP \
    --host-pool-name $HOST_POOL_NAME \
    --name $HOST \
    --allow-new-session true
done
```

---

## Step 5: Rollback to Previous Image Version

If issues are discovered after deploying a new image, rollback to the previous version:

### 5.1 Identify Previous Working Version

```bash
# List all image versions in gallery
az sig image-version list \
  --resource-group avd-dev-rg \
  --gallery-name avd_dev_manual_gallery \
  --gallery-image-definition windows11-avd-custom \
  --query "[].{Version:name, PublishingDate:publishingProfile.publishedDate}" -o table

# Output example:
# Version    PublishingDate
# ---------  ---------------------------
# 1.1.0      2025-01-15T10:30:00+00:00  ← Current (broken)
# 1.0.0      2025-01-01T14:20:00+00:00  ← Previous (working)
```

### 5.2 Update Terraform to Use Previous Version

Edit `envs/dev/terraform.tfvars`:

```hcl
# Rollback to previous working version
manual_image_version = "1.0.0"  # Changed from 1.1.0

# If you captured a new managed image, comment it out or revert:
# manual_image_managed_image_id = "/subscriptions/.../images/img-win11-avd-custom-v1"
```

### 5.3 Apply Rollback

```bash
cd envs/dev

# Set hosts to drain mode first (optional but recommended)
# ... (see Step 4.2)

# Apply rollback
terraform apply -target=module.session_hosts

# Verify
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, Status:status}" -o table
```

### 5.4 Emergency Rollback (Portal Method)

If Terraform is unavailable:

1. Go to Azure Portal → Host Pools → `avd-dev-hostpool`
2. Select **Session hosts** blade
3. Delete broken session hosts
4. Create new VMs manually:
   - Use previous image version from Compute Gallery
   - Join to domain
   - Install AVD agent manually

**Tip:** This is why versioning is critical! Always keep at least 2 previous versions in the gallery.

---

## Image Versioning Best Practices

### Semantic Versioning

Use semantic versioning for image versions:

```
MAJOR.MINOR.PATCH

Examples:
1.0.0 - Initial release
1.1.0 - Added Microsoft Teams, updated Edge
1.1.1 - Hotfix: Patched security vulnerability
2.0.0 - Upgraded to Windows 11 23H2
```

### Version Retention Policy

Configure in `terraform.tfvars`:

```hcl
# Keep last 3 versions
manual_image_version = "1.2.0"

# In main.tf or module, set:
# end_of_life_date = "2025-12-31T23:59:59Z"  # Retire old versions
```

### Tagging Strategy

Tag images with metadata:

```bash
az sig image-version create \
  --tags \
    "version=1.1.0" \
    "build_date=2025-01-15" \
    "os=Windows11-22H2" \
    "apps=Office365,Teams,Acrobat" \
    "tested_by=John Doe"
```

---

## Cleanup

After successful image capture and import:

```bash
# Delete the reference VM and associated resources
az group delete --name rg-image-build --yes --no-wait

# Optionally delete intermediate managed images (if using VHD method)
az image delete --resource-group avd-dev-rg --name img-win11-avd-custom-v1
```

**Keep managed images if:**
- You want a backup outside Compute Gallery
- You plan to import to multiple galleries
- You need to transfer to another subscription

---

## Troubleshooting

### Sysprep Fails with Error

**Error:** "Sysprep was not able to validate your Windows installation"

**Solutions:**
- Check `C:\Windows\System32\Sysprep\Panther\setuperr.log` for details
- Common cause: Modern apps (appx packages) installed per-user
  ```powershell
  # Remove appx packages before sysprep
  Get-AppxPackage -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
  ```
- Ensure Windows is fully updated
- Do not run sysprep more than 3 times on the same VM (Windows limitation)

### Image Import Takes Too Long

**VHD method timing:**
- Disk export SAS: 5-10 minutes
- VHD copy to blob: 15-30 minutes (depends on disk size)
- Managed image creation from VHD: 10-15 minutes
- Gallery version creation: 10-20 minutes
- **Total: 40-75 minutes**

**Managed image method timing:**
- Managed image capture: 5-10 minutes
- Gallery version creation: 10-20 minutes
- **Total: 15-30 minutes** (Faster!)

### Session Hosts Fail to Deploy with New Image

**Check:**
1. Image is in "Succeeded" provisioning state:
   ```bash
   az sig image-version show \
     --resource-group avd-dev-rg \
     --gallery-name avd_dev_manual_gallery \
     --gallery-image-definition windows11-avd-custom \
     --gallery-image-version 1.0.0 \
     --query provisioningState -o tsv
   ```
2. Hyper-V generation matches (`V2` vs `V1`)
3. Region replication is complete
4. Permissions: Ensure Terraform service principal can read from gallery

### AVD Agent Installation Fails

**Symptoms:** Session hosts appear in Azure but not in AVD portal

**Solutions:**
- Verify you ran sysprep `/generalize` before capture
- Check AVD agent can reach registration endpoint: `https://rdweb.wvd.microsoft.com`
- Verify NSG rules allow outbound HTTPS to AVD service endpoints
- Check domain join succeeded: `nltest /dsgetdc:avd.local`

---

## Additional Resources

- [Azure Compute Gallery Documentation](https://learn.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [Sysprep Documentation](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/sysprep--generalize--a-windows-installation)
- [AVD Image Management Best Practices](https://learn.microsoft.com/en-us/azure/virtual-desktop/set-up-golden-image)
- [FSLogix Profile Management](https://learn.microsoft.com/en-us/fslogix/overview)
- [Session Host Replacement Runbook](RUNBOOK_SESSION_HOST_REPLACEMENT.md) - Zero-downtime rolling updates

---

## Manual Golden Image → Compute Gallery Import (Terraform Workflow)

This section explains the **complete Terraform workflow** for importing manually prepared golden images into Azure Compute Gallery and deploying them to AVD session hosts.

### Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  Manual Golden Image → Terraform Import Workflow                    │
├─────────────────────────────────────────────────────────────────────┤
│  1. Build Reference VM (Azure Portal or CLI)                        │
│     ↓                                                               │
│  2. Install Apps & Customize                                        │
│     ↓                                                               │
│  3. Run Sysprep /generalize /oobe /shutdown                         │
│     ↓                                                               │
│  4. Capture as Managed Image OR Export to VHD                       │
│     ↓                                                               │
│  5. Configure Terraform (terraform.tfvars)                          │
│     ↓                                                               │
│  6. Terraform Import to Compute Gallery                             │
│     ↓                                                               │
│  7. Rolling Replacement of Session Hosts                            │
│     ↓                                                               │
│  8. Validate & Rollback if Needed                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Step 1: Build Reference VM

Create a Windows VM in Azure (Portal or CLI):

```bash
# Create temporary resource group for image building
az group create --name rg-image-build --location eastus

# Create Windows 11 Multi-Session VM
az vm create \
  --resource-group rg-image-build \
  --name vm-avd-golden-ref \
  --image MicrosoftWindowsDesktop:windows-11:win11-22h2-avd:latest \
  --size Standard_D4s_v5 \
  --admin-username imageadmin \
  --admin-password 'SecureP@ssw0rd!' \
  --public-ip-sku Standard

# Get IP for RDP
az vm show -d -g rg-image-build -n vm-avd-golden-ref --query publicIps -o tsv
```

**Important VM Settings:**
- **Hyper-V Generation**: Must be **V2** for Windows 11 (check before creating!)
- **VM Size**: Use larger size during build (D4s_v5) for faster installations
- **Region**: Same region as your AVD deployment for faster import

### Step 2: Install Applications & Configure

RDP to the VM and customize:

```powershell
# 1. Install Windows Updates
# Settings → Windows Update → Check for updates (repeat until none)

# 2. Install Applications (examples)
# - Microsoft 365 Apps
# - Google Chrome
# - Adobe Acrobat Reader
# - Line-of-business applications
# - Monitoring agents

# 3. Apply Group Policy settings (if not using domain GPO)
# Configure FSLogix, time zone, regional settings, etc.

# 4. Remove unnecessary apps (optional)
Get-AppxPackage *xbox* | Remove-AppxPackage
Get-AppxPackage *zune* | Remove-AppxPackage

# 5. Disk Cleanup
cleanmgr /sageset:1
cleanmgr /sagerun:1
```

### Step 3: Run Sysprep

**Critical Step:** Generalize the VM to remove machine-specific information.

```powershell
# Pre-Sysprep Cleanup
# 1. Clear temporary files
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# 2. Clear event logs
Get-EventLog -LogName * | ForEach-Object { Clear-EventLog $_.Log }

# 3. Run Sysprep (THIS WILL SHUT DOWN THE VM!)
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown /mode:vm
```

**CRITICAL:** After sysprep completes:
- VM will shut down automatically (5-15 minutes)
- **DO NOT start the VM** after shutdown
- Starting VM after sysprep invalidates the generalization

**Verify in Azure CLI:**
```bash
# Wait for VM to be deallocated
az vm show -g rg-image-build -n vm-avd-golden-ref --query powerState -o tsv
# Should show: VM deallocated

# Deallocate if still running (wait after sysprep)
az vm deallocate -g rg-image-build -n vm-avd-golden-ref

# Mark as generalized in Azure (REQUIRED!)
az vm generalize -g rg-image-build -n vm-avd-golden-ref
```

### Step 4: Capture Image

Choose **Option A (Recommended)** or **Option B**:

#### **Option A: Managed Image (Recommended)**

Faster and simpler for most scenarios:

```bash
# Capture VM to managed image
az image create \
  --resource-group rg-image-build \
  --name img-win11-avd-golden-v1 \
  --source vm-avd-golden-ref \
  --hyper-v-generation V2 \
  --tags "version=1.0.0" "os=Windows11" "created=$(date +%Y-%m-%d)"

# Get the managed image resource ID (needed for Terraform)
IMAGE_ID=$(az image show \
  --resource-group rg-image-build \
  --name img-win11-avd-golden-v1 \
  --query id -o tsv)

echo "Managed Image ID: $IMAGE_ID"
# Copy this ID for terraform.tfvars
```

#### **Option B: VHD Export**

Use for cross-tenant scenarios or archival:

```bash
# Get OS disk ID
DISK_ID=$(az vm show \
  --resource-group rg-image-build \
  --name vm-avd-golden-ref \
  --query storageProfile.osDisk.managedDisk.id -o tsv)

# Grant SAS access (1 hour)
SAS_URL=$(az disk grant-access \
  --resource-group rg-image-build \
  --name $(basename $DISK_ID) \
  --duration-in-seconds 3600 \
  --access-level Read \
  --query accessSas -o tsv)

# Create storage account and container
STORAGE_ACCOUNT="stgavdimages$(date +%s | tail -c 8)"
az storage account create \
  --resource-group rg-image-build \
  --name $STORAGE_ACCOUNT \
  --sku Standard_LRS

STORAGE_KEY=$(az storage account keys list \
  --resource-group rg-image-build \
  --account-name $STORAGE_ACCOUNT \
  --query "[0].value" -o tsv)

az storage container create \
  --name vhds \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY

# Copy disk to VHD (15-30 minutes)
az storage blob copy start \
  --source-uri "$SAS_URL" \
  --destination-blob win11-avd-golden-v1.vhd \
  --destination-container vhds \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY

# Get VHD URI (needed for Terraform)
VHD_URI="https://${STORAGE_ACCOUNT}.blob.core.windows.net/vhds/win11-avd-golden-v1.vhd"
echo "VHD URI: $VHD_URI"
# Copy this URI for terraform.tfvars
```

### Step 5: Configure Terraform

Edit `envs/dev/terraform.tfvars`:

```hcl
# ═══════════════════════════════════════════════════════════════════════════
# ENABLE GALLERY IMPORT
# ═══════════════════════════════════════════════════════════════════════════
enable_gallery_import = true

# ═══════════════════════════════════════════════════════════════════════════
# IMAGE SOURCE - Choose managed_image OR vhd
# ═══════════════════════════════════════════════════════════════════════════

# Option A: Managed Image (RECOMMENDED)
image_source_type       = "managed_image"
source_managed_image_id = "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-image-build/providers/Microsoft.Compute/images/img-win11-avd-golden-v1"

# Option B: VHD
# image_source_type = "vhd"
# source_vhd_uri    = "https://stgavdimages12345678.blob.core.windows.net/vhds/win11-avd-golden-v1.vhd"

# ═══════════════════════════════════════════════════════════════════════════
# VERSION & REPLICATION
# ═══════════════════════════════════════════════════════════════════════════
image_version = "1.0.0"  # Increment for each new image (1.0.0, 1.1.0, 2.0.0)

# PRODUCTION BEST PRACTICES
pin_image_version_id = true   # Pin to specific version (RECOMMENDED)
exclude_from_latest  = true   # Exclude from 'latest' queries (RECOMMENDED)

# Multi-region replication (if needed)
image_replication_regions = ["eastus"]  # Add: "westus2", "westeurope", etc.

# ═══════════════════════════════════════════════════════════════════════════
# IMAGE DEFINITION METADATA
# ═══════════════════════════════════════════════════════════════════════════
image_definition_name = "windows11-avd-custom"  # Unique name in gallery
image_publisher       = "MyCompany"             # Your organization
image_offer           = "Windows11-AVD"         # Product family
image_sku             = "22h2-custom"           # Variant identifier

# MUST MATCH SOURCE VM
hyper_v_generation = "V2"  # V2 for Windows 11, V1 for older Windows
os_type            = "Windows"

# Gallery configuration (optional - auto-generated if empty)
gallery_name    = ""  # Leave empty: auto-generates "avd_dev_gallery"
gallery_rg_name = ""  # Leave empty: uses main resource group
```

### Step 6: Terraform Import to Compute Gallery

Run Terraform to import the image:

```bash
cd envs/dev

# Review changes
terraform plan

# Import image to gallery (targeted apply)
terraform apply -target=module.gallery_import

# Expected output:
# module.gallery_import[0].azurerm_shared_image_gallery.gallery: Creating...
# module.gallery_import[0].azurerm_shared_image.definition: Creating...
# module.gallery_import[0].azurerm_shared_image_version.version: Creating...
# (This takes 10-30 minutes depending on source type)

# Verify gallery image version was created
terraform output -json | jq '.gallery_import_outputs'
```

**What Terraform Does:**
1. **Creates Azure Compute Gallery** (if not exists)
   - Name: `avd_dev_gallery` (or custom name)
   - Region: Same as deployment
   
2. **Creates Image Definition**
   - Publisher/Offer/SKU metadata
   - OS type and Hyper-V generation
   - VM size recommendations

3. **Creates Image Version**
   - Imports from managed image or VHD
   - Applies semantic version (1.0.0)
   - Replicates to specified regions
   - Sets `exclude_from_latest` flag

4. **Outputs Image Version ID**
   - Full resource ID for session host deployment
   - Used by session_hosts module automatically

### Step 7: Rolling Replacement of Session Hosts

Deploy session hosts with the new image (zero-downtime):

#### 7.1 Set Existing Hosts to Drain Mode

```bash
# Prevent new user sessions on existing hosts
RESOURCE_GROUP="avd-dev-rg"
HOST_POOL="avd-dev-hostpool"

# Get all session hosts
SESSION_HOSTS=$(az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL \
  --query "[].name" -o tsv)

# Set each to drain mode
for HOST in $SESSION_HOSTS; do
  echo "Setting $HOST to drain mode..."
  az desktopvirtualization sessionhost update \
    --resource-group $RESOURCE_GROUP \
    --host-pool-name $HOST_POOL \
    --name $HOST \
    --allow-new-session false
done
```

#### 7.2 Wait for Active Sessions to Complete

```bash
# Monitor active sessions
while true; do
  ACTIVE_SESSIONS=$(az desktopvirtualization sessionhost list \
    --resource-group $RESOURCE_GROUP \
    --host-pool-name $HOST_POOL \
    --query "sum([].session)" -o tsv)
  
  echo "Active sessions: $ACTIVE_SESSIONS"
  
  if [ "$ACTIVE_SESSIONS" -eq 0 ]; then
    echo "All sessions ended. Safe to proceed."
    break
  fi
  
  echo "Waiting 60 seconds..."
  sleep 60
done

# OR force logoff after business hours (use with caution)
# az desktopvirtualization usersession delete --force ...
```

#### 7.3 Deploy New Session Hosts

```bash
# Terraform will recreate session hosts with new image
terraform apply

# This will:
# 1. Destroy old session host VMs
# 2. Create new VMs with gallery image (gallery_image_version_id)
# 3. Domain join new VMs
# 4. Install AVD agent
# 5. Register to host pool

# Monitor deployment progress
terraform apply -auto-approve | tee deployment.log
```

#### 7.4 Validate New Session Hosts

```bash
# Check new VMs are running
az vm list \
  --resource-group $RESOURCE_GROUP \
  --query "[?contains(name, 'avd-dev-sh')].{Name:name, Status:powerState}" \
  -o table

# Verify AVD registration
az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL \
  --query "[].{Name:name, Status:status, AgentVersion:agentVersion}" \
  -o table

# Expected output:
# Name                Status      AgentVersion
# ──────────────────  ──────────  ─────────────
# avd-dev-sh-1        Available   1.0.5739.9800
# avd-dev-sh-2        Available   1.0.5739.9800

# Test user login
# Users should now connect to new session hosts automatically
```

#### 7.5 Re-enable Session Hosts

```bash
# Allow new sessions after validation
for HOST in $(az desktopvirtualization sessionhost list \
  --resource-group $RESOURCE_GROUP \
  --host-pool-name $HOST_POOL \
  --query "[].name" -o tsv); do
  
  echo "Enabling $HOST..."
  az desktopvirtualization sessionhost update \
    --resource-group $RESOURCE_GROUP \
    --host-pool-name $HOST_POOL \
    --name $HOST \
    --allow-new-session true
done
```

### Step 8: Rollback to Previous Version

If issues are discovered, rollback to the previous working image version:

#### 8.1 Identify Previous Version

```bash
# List all image versions in gallery
az sig image-version list \
  --resource-group avd-dev-rg \
  --gallery-name avd_dev_gallery \
  --gallery-image-definition windows11-avd-custom \
  --query "[].{Version:name, State:provisioningState, Date:publishingProfile.publishedDate}" \
  -o table

# Output:
# Version    State       Date
# ─────────  ──────────  ──────────────────────
# 1.1.0      Succeeded   2026-01-26T10:30:00Z  ← Current (broken)
# 1.0.0      Succeeded   2026-01-15T14:20:00Z  ← Previous (working)
```

#### 8.2 Update Terraform Configuration

Edit `envs/dev/terraform.tfvars`:

```hcl
# Rollback to previous working version
image_version = "1.0.0"  # Changed from 1.1.0

# If you captured a new image for 1.1.0, comment it out
# source_managed_image_id = "/subscriptions/.../images/img-win11-avd-golden-v2"

# Restore previous image ID
source_managed_image_id = "/subscriptions/.../images/img-win11-avd-golden-v1"
```

#### 8.3 Apply Rollback

```bash
cd envs/dev

# Optional: Set hosts to drain mode first (see Step 7.1)

# Apply rollback (recreates session hosts with v1.0.0)
terraform apply

# Verify rollback
az desktopvirtualization sessionhost list \
  --resource-group avd-dev-rg \
  --host-pool-name avd-dev-hostpool \
  --query "[].{Name:name, Status:status}" -o table
```

#### 8.4 Emergency Rollback (Without Terraform)

If Terraform is unavailable:

```bash
# Get previous image version ID
PREVIOUS_VERSION="/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/avd-dev-rg/providers/Microsoft.Compute/galleries/avd_dev_gallery/images/windows11-avd-custom/versions/1.0.0"

# Manually create session hosts with previous image
for i in {1..2}; do
  az vm create \
    --resource-group avd-dev-rg \
    --name "avd-dev-sh-rollback-$i" \
    --image "$PREVIOUS_VERSION" \
    --size Standard_D2s_v5 \
    --admin-username localadmin \
    --admin-password 'SecureP@ssw0rd!' \
    --vnet-name avd-dev-vnet \
    --subnet avd-subnet
done

# Then manually domain join and install AVD agent
# (This is why Terraform rollback is preferred!)
```

---

## Common Pitfalls and Solutions

### 1. Image Not Generalized

**Problem:**
```
Error: VM provisioning failed with error: "OSProvisioningClientError"
Message: "The operating system of the virtual machine has not been generalized."
```

**Cause:** VM was captured without running sysprep or `az vm generalize` command was not executed.

**Solution:**
```bash
# You MUST generalize the VM before capturing:

# 1. Run sysprep inside VM
C:\Windows\System32\Sysprep\sysprep.exe /generalize /oobe /shutdown

# 2. Wait for VM to be deallocated
az vm show -g rg-image-build -n vm-ref --query powerState

# 3. Run generalize command in Azure
az vm generalize -g rg-image-build -n vm-ref

# 4. Then capture image
az image create --source vm-ref ...
```

**Prevention:** Always follow the exact sequence: Sysprep → Deallocate → Generalize → Capture

### 2. Hyper-V Generation Mismatch

**Problem:**
```
Error: The image's Hyper-V generation (V1) does not match the VM size's generation (V2).
```

**Cause:** Source VM was Gen1 but terraform.tfvars specifies `hyper_v_generation = "V2"` (or vice versa).

**Solution:**
```hcl
# In terraform.tfvars, match the source VM's generation:

# Check source VM generation:
az vm show -g rg-image-build -n vm-ref --query "storageProfile.imageReference.sku"

# Windows 11 REQUIRES V2
hyper_v_generation = "V2"  # For Windows 11, Server 2022, modern Linux

# Windows 10, Server 2019, older OS can use V1
hyper_v_generation = "V1"  # For legacy compatibility
```

**Prevention:** 
- **Always use Gen2 VMs** for new deployments (Windows 11 requirement)
- Check source VM generation before capturing: `az vm show ... --query "storageProfile.osDisk.osType"`
- Terraform variable validation will catch this if properly configured

### 3. Missing Replication Region Permissions

**Problem:**
```
Error: Failed to replicate image version to region 'westus2'
Code: AuthorizationFailed
Message: The client does not have authorization to perform action 'Microsoft.Compute/galleries/images/versions/write' over scope '/subscriptions/.../westus2'
```

**Cause:** Service principal or user lacks permissions in target replication regions.

**Solution:**
```bash
# Grant Contributor role in each replication region
REGIONS=("eastus" "westus2" "westeurope")

for REGION in "${REGIONS[@]}"; do
  echo "Granting permissions in $REGION..."
  
  # Option 1: Subscription-level (simplest)
  az role assignment create \
    --assignee <service-principal-id> \
    --role "Contributor" \
    --scope "/subscriptions/<subscription-id>"
  
  # Option 2: Resource group level (more secure)
  az role assignment create \
    --assignee <service-principal-id> \
    --role "Contributor" \
    --scope "/subscriptions/<subscription-id>/resourceGroups/avd-${REGION}-rg"
done
```

**Prevention:**
- Start with single-region deployment: `image_replication_regions = ["eastus"]`
- Test replication permissions in non-prod first
- Use subscription-level Contributor for simplicity (production: scope to specific RGs)

### 4. Image Definition Publisher/Offer/SKU Inconsistency

**Problem:**
```
Error: Image definition with publisher 'MyCompany', offer 'Windows11', sku 'custom' 
already exists but has different os_type 'Linux' (expected 'Windows')
```

**Cause:** Trying to create/update image definition with conflicting metadata.

**Solution:**
```hcl
# IMPORTANT: These values CANNOT be changed once image definition is created!

# If you need to change publisher/offer/sku:
# Option 1: Create a NEW image definition with different name
image_definition_name = "windows11-avd-custom-v2"  # New definition

# Option 2: Delete existing definition and recreate
terraform destroy -target=module.gallery_import
# Then change metadata and reapply

# RECOMMENDED: Use consistent naming convention
image_publisher = "MyCompany"           # Never change (organization name)
image_offer     = "Windows11-AVD"       # Product family
image_sku       = "22h2-custom"         # Variant (can add new definitions)
```

**Prevention:**
- Document your publisher/offer/sku naming convention
- Use version numbers in `image_version` NOT in definition name
- Create new image definitions for major OS changes (Windows 10 → Windows 11)

### 5. VHD Import Timeout

**Problem:**
```
Error: Timeout waiting for image version to be created from VHD
```

**Cause:** Large VHD file (>100GB) or slow storage account upload.

**Solution:**
```bash
# Use Managed Image instead (MUCH faster)
az image create \
  --source vm-ref \
  --resource-group rg-image-build \
  --name img-win11-custom

# If you MUST use VHD:
# 1. Use Premium storage account for faster upload
az storage account create \
  --name stgavdimages \
  --sku Premium_LRS \
  --kind BlockBlobStorage

# 2. Use AzCopy for faster copy
azcopy copy "$SAS_URL" "https://stgavdimages.blob.core.windows.net/vhds/image.vhd"

# 3. Increase Terraform timeout (in module call)
# In envs/dev/main.tf:
# timeouts {
#   create = "90m"  # Default: 30m
# }
```

**Prevention:** Use managed image method (Option A) unless cross-tenant transfer required

### 6. Session Hosts Fail to Domain Join with New Image

**Problem:**
```
Error: Domain join failed. Error code: 0x00000035
Message: "The network path was not found."
```

**Cause:** New image doesn't have network drivers or DNS settings configured properly.

**Solution:**
```powershell
# Before running sysprep, ensure:

# 1. Check DNS settings
Get-DnsClientServerAddress

# 2. Test domain connectivity
Test-NetConnection -ComputerName avd.local -Port 389

# 3. Install Azure VM Agent (if missing)
# Download and install from: https://aka.ms/waavm

# 4. Ensure network drivers are installed
Get-NetAdapter | Select Name, Status, DriverVersion
```

**Prevention:**
- Use Azure Marketplace base images (have proper drivers)
- Test domain join on reference VM before sysprep
- Verify NSG rules allow Active Directory traffic (TCP 389, 636, 3268, 3269, 88, 53)

### 7. Image Version Already Exists

**Problem:**
```
Error: Image version '1.0.0' already exists in image definition 'windows11-avd-custom'
```

**Cause:** Trying to create duplicate version number.

**Solution:**
```hcl
# Option 1: Increment version number
image_version = "1.0.1"  # Changed from 1.0.0

# Option 2: Delete existing version first
az sig image-version delete \
  --resource-group avd-dev-rg \
  --gallery-name avd_dev_gallery \
  --gallery-image-definition windows11-avd-custom \
  --gallery-image-version 1.0.0

# Then reapply terraform
```

**Prevention:**
- Use semantic versioning: MAJOR.MINOR.PATCH
- Increment PATCH for fixes (1.0.0 → 1.0.1)
- Increment MINOR for features (1.0.1 → 1.1.0)
- Increment MAJOR for breaking changes (1.1.0 → 2.0.0)

### 8. Replication Takes Too Long

**Problem:** Image replication to multiple regions taking hours.

**Expected Timing:**
- Single region: 10-20 minutes
- 3 regions: 30-60 minutes
- 5+ regions: 60-120 minutes

**Solution:**
```hcl
# Start with single region in dev/test
image_replication_regions = ["eastus"]  # Primary region only

# For production, replicate only to regions where you deploy
image_replication_regions = [
  "eastus",      # Primary
  "westus2"      # DR region
]

# Don't replicate to unused regions (wastes time and money)
```

**Monitoring:**
```bash
# Check replication status
az sig image-version show \
  --resource-group avd-dev-rg \
  --gallery-name avd_dev_gallery \
  --gallery-image-definition windows11-avd-custom \
  --gallery-image-version 1.0.0 \
  --query "replicationStatus" -o json
```

---


### Cleanup Old Versions

After validating new version, optionally delete old versions:

```bash
# List versions
az sig image-version list \
  --resource-group avd-dev-rg \
  --gallery-name avd_dev_gallery \
  --gallery-image-definition windows11-avd-custom \
  --query "[].name" -o tsv

# Delete old version (keep at least 2 versions for rollback!)
az sig image-version delete \
  --resource-group avd-dev-rg \
  --gallery-name avd_dev_gallery \
  --gallery-image-definition windows11-avd-custom \
  --gallery-image-version 1.0.0

# Cost savings: ~$5/month per version removed
```

**Recommendation:** Keep at least 2-3 recent versions for rollback capability.

---

## Production Rollout Best Practices

1. **Test in Dev First**
   - Deploy to dev environment
   - Validate apps work correctly
   - Test user profiles and GPO application
   - Check performance and stability

2. **Staged Production Rollout**
   ```bash
   # Week 1: Pilot group (10% of hosts)
   vm_count = 2  # Start small
   
   # Week 2: Expand if successful (50% of hosts)
   vm_count = 10
   
   # Week 3: Full production rollout
   vm_count = 20
   ```

3. **Monitoring During Rollout**
   - Monitor AVD session host health
   - Check Azure Monitor for VM metrics
   - Review FSLogix profile creation logs
   - Monitor user feedback and support tickets

4. **Rollback Criteria**
   - Application failures (> 5%)
   - Performance degradation (> 20% slower)
   - Profile corruption issues
   - User complaints (> 10% of users)

5. **Post-Rollout Validation**
   - Verify all session hosts registered
   - Test representative user workflows
   - Check backup and monitoring
   - Document lessons learned

---

## Module Reference

This playbook uses modular Terraform components for flexible deployment. For detailed information about each module including:
- Module capabilities and features
- Configuration options and variables
- Outputs and dependencies
- Best practices and examples

**See [MODULES.md](MODULES.md) for the complete module reference guide.**

**Quick module overview:**
- **Core Modules**: Networking, Domain Controller, AVD Core, Session Hosts, FSLogix Storage
- **Security**: Key Vault, Conditional Access (MFA), Backup
- **Optimization**: Scaling Plan (60-80% cost savings), Cost Management
- **Custom Images**: Golden Image (Azure Image Builder), Manual Gallery Import
- **Operations**: Logging, Monitoring, Update Management

---

## Security Considerations

### For Production:
1. **Secrets Management:**
   - Use Azure Key Vault for storing passwords
   - Reference secrets via `azurerm_key_vault_secret` data source
   - Never commit passwords to version control

2. **Network Security:**
   - Implement Azure Bastion for secure RDP access
   - Remove public IPs from Domain Controller
   - Configure NSG rules to restrict traffic
   - Enable Azure Firewall for egress filtering

3. **Identity & Access:**
   - Use Azure AD DS instead of IaaS DC for production
   - Implement MFA for AVD users via Conditional Access module
   - Configure device compliance policies (requires Intune)
   - Block legacy authentication (Exchange ActiveSync, IMAP, POP3)
   - Use Azure RBAC for management access
   - See [modules/conditional_access/README.md](modules/conditional_access/README.md)

4. **Monitoring:**
   - Enable Azure Monitor for AVD
   - Configure Log Analytics workspace
   - Set up alerts for critical events
   - Implement diagnostic settings

## Testing

### Verify Domain Controller:
```bash
# RDP to DC
# Run in PowerShell:
Get-ADDomain
Get-ADForest
Get-DnsServerZone
```

### Verify AVD Host Pool:
```bash
# Check host pool registration
az desktopvirtualization hostpool show \
  --name <hostpool-name> \
  --resource-group <rg-name>

# List session hosts
az desktopvirtualization sessionhost list \
  --host-pool-name <hostpool-name> \
  --resource-group <rg-name>
```

---

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning:** This will delete all resources including the Domain Controller and any data stored in Azure Files.

---

## Cost Estimation

**Dev Environment (default configuration):**
- Domain Controller (B2ms): (~$60/month) (~€56/month) (~£48/month)
- 2x Session Hosts (D2s_v5): (~$140/month) (~€130/month) (~£112/month)
- Storage Account (100GB): (~$5/month) (~€4.70/month) (~£4/month)
- Networking: (~$5/month) (~€4.70/month) (~£4/month)
- **Total: (~$210/month) (~€195/month) (~£168/month)**

**Prod Environment:**
- Costs scale with session host count and VM sizes
- Consider Reserved Instances for cost savings
- Implement Scaling Plan module for 60-80% cost reduction

---

## Troubleshooting

### Domain Join Failures:
- Verify DC private IP in VNet DNS settings
- Check NSG rules allow ports 389, 636, 88, 53
- Ensure domain admin credentials are correct
- Check DC CustomScriptExtension completed successfully

### AVD Registration Failures:
- Verify host pool registration token is not expired
- Check session host VMs have internet connectivity
- Ensure domain join completed before AVD registration
- Review VM extension logs in Azure Portal

### FSLogix Profile Issues:
- Verify Azure Files share permissions
- Check storage account private endpoint connectivity
- Ensure session hosts have RBAC permissions
- Review FSLogix logs on session hosts

**For more troubleshooting:** See [Documentation/09_Troubleshooting/README.md](Documentation/09_Troubleshooting/README.md)

---

## Additional Resources

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [FSLogix Documentation](https://docs.microsoft.com/fslogix/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AVD Best Practices](https://docs.microsoft.com/azure/virtual-desktop/best-practices)
- [Module Reference Guide](MODULES.md) - Detailed module documentation

---

