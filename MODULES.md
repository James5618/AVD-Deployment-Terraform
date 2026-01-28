# Module Reference Guide

This document provides detailed information about each Terraform module used in the AVD deployment.

## Core Infrastructure Modules

### Networking Module
**Location:** `modules/networking/`

Creates the foundational network infrastructure for the AVD deployment:
- Virtual Network with /16 CIDR range
- Three dedicated subnets:
  - **DC Subnet**: Hosts the Domain Controller
  - **AVD Subnet**: Hosts session host VMs
  - **Storage Subnet**: Hosts private endpoints for Azure Files
- Network Security Groups with baseline rules
- DNS configuration pointing to Domain Controller
- VNet peering support (optional)

**Key Outputs:**
- VNet ID and name
- Subnet IDs for each subnet
- NSG IDs

**Documentation:** See [modules/networking/README.md](modules/networking/README.md) for detailed configuration options.

---

### Domain Controller Module
**Location:** `modules/domain-controller/`

Deploys and configures an Active Directory Domain Services environment:
- **VM Specification**: Windows Server 2022 Datacenter (default: Standard_B2ms)
- **AD DS Installation**: Automated via CustomScriptExtension
- **Configuration**:
  - Static private IP address
  - DNS server role configuration
  - Automatic domain and forest creation
  - Organizational Unit (OU) creation for AVD session hosts
- **Post-Deployment**: Fully functional AD DS ready for domain joins

**Key Outputs:**
- Domain Controller private IP
- Domain name (FQDN)
- Domain administrator credentials reference

**Documentation:** See [modules/domain-controller/README.md](modules/domain-controller/README.md) for AD DS configuration details.

---

### AVD Core Module
**Location:** `modules/avd_core/`

Provisions the Azure Virtual Desktop infrastructure:
- **AVD Workspace**: User-facing access point
- **Host Pool**: Pooled or Personal desktop deployment
- **Desktop Application Group**: Desktop publishing to users
- **Role Assignments**: RBAC for user access
- **Registration Token**: Automated token management for session host registration
- **Entra ID Integration**: User group assignment

**Key Outputs:**
- Workspace ID and name
- Host Pool ID and registration token
- Application Group ID
- User group ID

**Documentation:** See [modules/avd_core/README.md](modules/avd_core/README.md) for AVD-specific configurations.

---

### Session Hosts Module
**Location:** `modules/session-hosts/`

Deploys and configures AVD session host virtual machines:
- **Default Image**: Windows 11 Enterprise Multi-Session + Microsoft 365 Apps
- **Image Strategy Support**:
  - Marketplace images (default)
  - Azure Image Builder gallery images
  - Manually imported gallery images
- **Domain Join**: Automated via JsonADDomainExtension to specified AVD OU
- **AVD Agent**: Automatic installation and registration to host pool
- **FSLogix Configuration**: Pre-configured for user profile management
- **Scaling**: Configurable VM count and size

**Key Outputs:**
- Session host VM IDs
- Private IP addresses
- Computer names

**Documentation:** See [modules/session-hosts/README.md](modules/session-hosts/README.md) for detailed image selection and configuration.

---

### FSLogix Storage Module
**Location:** `modules/fslogix_storage/`

Creates storage infrastructure for user profile management:
- **Storage Account**: Premium or Standard performance tier
- **Azure Files Share**: Named "user-profiles" by default
- **AD DS Authentication**: Kerberos-based authentication support
- **Private Endpoint**: Secure connectivity from AVD subnet
- **RBAC Permissions**: Appropriate file share access for session hosts
- **Quota Management**: Configurable storage quotas

**Key Outputs:**
- Storage account name and ID
- File share name
- Private endpoint configuration

**Documentation:** See [modules/fslogix_storage/README.md](modules/fslogix_storage/README.md) for FSLogix integration details.

---

## Optional Enhancement Modules

### Key Vault Module
**Location:** `modules/key_vault/`

Provides secure secrets management for the deployment:
- **Secrets Storage**: Domain admin and local admin passwords
- **Auto-generation**: Optional automatic password generation
- **Access Policies**: Controlled access via RBAC
- **Integration**: Seamless reference from Terraform configurations
- **Purge Protection**: Optional soft-delete and purge protection

**Use Cases:**
- Production password management
- Certificate storage
- API key management

**Documentation:** See [modules/key_vault/README.md](modules/key_vault/README.md)

---

### Scaling Plan Module
**Location:** `modules/scaling_plan/`

Implements auto-scaling for cost optimization:
- **Cost Savings**: 60-80% reduction in VM costs
- **Schedules**: Customizable ramp-up, peak, ramp-down, and off-peak periods
- **Capacity Management**: Dynamic host allocation based on demand
- **User Management**: Optional forced logoff during ramp-down
- **Multi-timezone Support**: Configure per business hours

**Typical Savings Example:**
- Without scaling: (~$276/month) (~€257/month) (~£220/month) (24/7 operation)
- With scaling: (~$110/month) (~€102/month) (~£88/month) (14 hours/day deallocated)
- **Savings: (~$166/month) (~€155/month) (~£132/month) (60% reduction)**

**Documentation:** See [modules/scaling_plan/README.md](modules/scaling_plan/README.md) for detailed configuration examples.

---

### Conditional Access Module
**Location:** `modules/conditional_access/`

Implements zero-trust security controls for AVD access:
- **MFA Enforcement**: Require multi-factor authentication
- **Device Compliance**: Require managed/compliant devices (with Intune)
- **Legacy Auth Blocking**: Block IMAP, POP3, SMTP, Exchange ActiveSync
- **Break-glass Accounts**: Emergency access protection
- **Policy States**: Report-only mode for testing before enforcement

**Requirements:**
- Entra ID Premium P1 or P2 licensing ($6-9/user/month, ~€5.60-8.40/user/month, ~£4.80-7.20/user/month)
- Break-glass accounts configured BEFORE enabling policies

**Documentation:** See [modules/conditional_access/README.md](modules/conditional_access/README.md) for critical safety procedures.

---

### Compute Gallery Module
**Location:** `modules/compute_gallery/`

Manages Azure Compute Gallery for custom image storage:
- **Gallery Creation**: Shared image gallery infrastructure
- **Image Definitions**: Support for multiple OS types and generations
- **Versioning**: Semantic versioning support (1.0.0, 1.1.0, etc.)
- **Replication**: Multi-region image distribution
- **RBAC**: Controlled access to gallery resources

**Documentation:** See [modules/compute_gallery/README.md](modules/compute_gallery/README.md)

---

### Golden Image Module (Azure Image Builder)
**Location:** `modules/golden_image/`

Automates custom image creation using Azure Image Builder:
- **Base Images**: Start from Azure Marketplace images
- **Customization**: 
  - Install Windows updates
  - Install Chocolatey packages
  - Run custom PowerShell scripts
  - Apply registry settings
- **Build Process**: Infrastructure-as-code repeatable builds
- **Gallery Integration**: Automatic versioning and publishing
- **Multi-region**: Replicate to multiple Azure regions

**Build Time:** 30-90 minutes (one-time manual trigger)  
**Cost:** ~$1-3 per build + $5-15/month storage

**Documentation:** See [modules/golden_image/README.md](modules/golden_image/README.md)

---

### Manual Gallery Import Modules
**Locations:** 
- `modules/manual_gallery_import/`
- `modules/manual_image_import/`

Support for importing manually prepared custom images:
- **Import from Managed Image**: Recommended approach
- **Import from VHD**: Legacy support
- **Use Cases**:
  - Migrating existing customized VMs to AVD
  - Complex GUI-based application installations
  - One-time imports before switching to automated builds
- **Workflow**: Prepare VM → Sysprep → Capture → Import to Gallery

**Documentation:** 
- [modules/manual_gallery_import/README.md](modules/manual_gallery_import/README.md)
- [modules/manual_image_import/README.md](modules/manual_image_import/README.md)

---

### Backup Module
**Location:** `modules/backup/`

Implements Azure Backup for VM protection:
- **Recovery Services Vault**: Centralized backup management
- **Backup Policies**: Customizable retention and schedules
- **VM Protection**: Automated backup for Domain Controller and session hosts
- **Restore Options**: File-level and full VM recovery

**Documentation:** See [modules/backup/README.md](modules/backup/README.md)

---

### Logging Module
**Location:** `modules/logging/`

Centralized logging and monitoring infrastructure:
- **Log Analytics Workspace**: Central log aggregation
- **Diagnostic Settings**: AVD resource logging
- **Workbooks**: Pre-built AVD monitoring dashboards
- **Alerts**: Configurable alerting rules

**Documentation:** See [modules/logging/README.md](modules/logging/README.md)

---

### Cost Management Module
**Location:** `modules/cost_management/`

Budget and cost control implementation:
- **Budget Creation**: Set spending limits
- **Alert Rules**: Notification thresholds
- **Cost Analysis**: Resource tagging for tracking
- **Recommendations**: Azure Advisor integration

**Documentation:** See [modules/cost_management/README.md](modules/cost_management/README.md)

---

## Module Dependency Map

| Component | Depends On | Provides To |
|-----------|------------|-------------|
| **Networking Module** | None | All other modules |
| **Domain Controller Module** | Networking | Session Hosts (domain join) |
| **AVD Core Module** | Networking | Session Hosts (registration) |
| **Session Hosts Module** | Networking, Domain Controller, AVD Core | FSLogix Storage |
| **FSLogix Storage Module** | Networking, Session Hosts | User profiles |

**Deployment Order:**
1. Networking (VNet, Subnets, NSGs)
2. Key Vault (Optional - for secure password storage)
3. Domain Controller (AD DS installation)
4. Compute Gallery (If using custom images)
5. Golden Image / Manual Import (If using custom images)
6. AVD Core (Workspace, Host Pool, App Group)
7. Session Hosts (Domain join + AVD registration)
8. FSLogix Storage (User profiles)
9. Scaling Plan (Optional - for auto-scaling)
10. Conditional Access (Optional - for MFA/security)
11. Monitoring & Backup (Optional - for operations)

---

## Quick Module Selection Guide

| Deployment Type | Required Modules | Optional Modules |
|-----------------|------------------|------------------|
| **Minimal (Dev/Test)** | Networking<br>Domain Controller<br>AVD Core<br>Session Hosts<br>FSLogix Storage | None |
| **Production** | All Minimal modules plus:<br>Key Vault | Scaling Plan (60-80% cost savings)<br>Conditional Access (security)<br>Logging (monitoring)<br>Backup (DR) |
| **Custom Images** | Minimal modules plus:<br>Compute Gallery | Golden Image (Azure Image Builder)<br>*or* Manual Gallery Import |

---

## Module Configuration Pattern

All modules follow a consistent interface pattern:

```hcl
module "example_module" {
  source = "../../modules/example_module"
  
  # Required inputs
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  
  # Optional inputs with defaults
  tags = var.tags
  
  # Module-specific inputs
  # ... (documented in each module's README.md)
}
```

**Key Principles:**
- All modules accept common inputs (RG, location, tags)
- Modules expose outputs for cross-module dependencies
- Each module has comprehensive README.md documentation
- Variables have sensible defaults where possible
- Sensitive values use `sensitive = true` attribute

---

## Additional Resources

- **[Main README](README.md)** - Quick start and overview
- **[Configuration Guide](CONFIGURATION_GUIDE.md)** - Where to find settings
- **[Quick Reference Card](QUICK_REFERENCE.md)** - Cheat sheet

For module-specific questions, refer to the README.md in each module's directory.
