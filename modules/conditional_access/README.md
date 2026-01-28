# Conditional Access Module for Azure Virtual Desktop

Manage Microsoft Entra Conditional Access policies for Azure Virtual Desktop (AVD) using Terraform. This module enforces security requirements like multi-factor authentication, device compliance, and legacy protocol blocking to protect AVD access.

---

## CRITICAL SAFETY WARNINGS

### LOCKOUT RISK

**Misconfigured Conditional Access policies can lock out ALL users including Global Administrators.** Always follow this checklist:

**BEFORE deploying:**
1.  Create 2 break-glass accounts (emergency admin access)
2.  Store passwords offline securely (physical safe or sealed envelope)
3.  Create break-glass exclusion group in Entra ID
4.  Add break-glass accounts to exclusion group
5.  Test break-glass account login monthly

**DURING deployment:**
1.  ALL policies default to **report-only mode** (logs only, no blocking)
2.  Monitor sign-in logs daily for 2-4 weeks
3.  Review any policy failures before enabling enforcement
4.  Module will **fail validation** if break_glass_group_ids not set

**AFTER deployment:**
1.  Enable policies gradually: Legacy auth (week 3) → MFA pilot (week 5) → MFA all users (week 7)
2.  Never enable device compliance without Intune setup
3.  Test break-glass account access monthly

### Built-In Safety Features

This module includes multiple safety protections:

- **Report-only defaults**: All policies default to audit mode (no blocking)
- **Required break-glass group**: Module validation fails if not set
- **Break-glass exclusions**: ALL policies exclude break-glass accounts
- **Staged rollout support**: Per-policy state control for gradual enablement
- **Clear documentation**: 900+ line README with rollback procedures

**If you get locked out:** Sign in with break-glass account → Entra ID → Security → Conditional Access → Disable problematic policy

---

## Overview

**Conditional Access** is Microsoft Entra ID's policy engine that evaluates signals (user, location, device, app) and enforces access controls (block, require MFA, require compliant device). For AVD, Conditional Access provides:

- **Multi-factor authentication** enforcement
- **Device compliance** verification (Intune-managed devices)
- **Legacy authentication** blocking (IMAP, POP3, SMTP, Exchange ActiveSync)
- **Approved client app** requirements for mobile access
- **Session controls** (sign-in frequency, persistent browser management)

## Variables

### Core Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enabled` | Enable Conditional Access policies | `bool` | `true` | No |
| `avd_users_group_id` | Primary Entra ID group object ID for AVD users | `string` | `""` | Yes |
| `additional_target_group_ids` | Additional Entra ID group object IDs to include | `list(string)` | `[]` | No |
| `break_glass_group_ids` | Break-glass/emergency access accounts group IDs (CRITICAL) | `list(string)` | `[]` | Yes |
| `avd_application_ids` | Cloud application IDs for AVD | `list(string)` | AVD + Windows Sign-In | No |

### MFA Policy

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `require_mfa` | Enable MFA requirement policy | `bool` | `true` | No |
| `mfa_policy_name` | Display name for MFA policy | `string` | `"AVD: Require Multi-Factor Authentication"` | No |
| `mfa_policy_state` | Policy state: enabled, enabledForReportingButNotEnforced, disabled | `string` | `"enabledForReportingButNotEnforced"` | No |
| `mfa_excluded_group_ids` | Additional groups to exclude from MFA policy | `list(string)` | `[]` | No |

### Device Compliance Policy

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `require_compliant_device` | Enable compliant/hybrid joined device requirement | `bool` | `false` | No |
| `device_policy_name` | Display name for device compliance policy | `string` | `"AVD: Require Compliant or Hybrid Joined Device"` | No |
| `device_policy_state` | Policy state: enabled, enabledForReportingButNotEnforced, disabled | `string` | `"enabledForReportingButNotEnforced"` | No |
| `require_compliant_or_hybrid` | Require compliant OR hybrid joined (true) vs AND (false) | `bool` | `true` | No |
| `device_excluded_group_ids` | Additional groups to exclude from device policy | `list(string)` | `[]` | No |

### Legacy Authentication Policy

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `block_legacy_auth` | Enable policy to block legacy authentication protocols | `bool` | `true` | No |
| `legacy_auth_policy_name` | Display name for legacy authentication blocking policy | `string` | `"AVD: Block Legacy Authentication"` | No |
| `legacy_auth_policy_state` | Policy state: enabled, enabledForReportingButNotEnforced, disabled | `string` | `"enabled"` | No |
| `legacy_auth_excluded_group_ids` | Additional groups to exclude from legacy auth policy | `list(string)` | `[]` | No |

## Prerequisites

### 1. **Licensing** (CRITICAL)

Conditional Access requires **Entra ID Premium P1 or P2** licensing:

- **P1**: ($6/user/month) (~€5.60/user/month) (~£4.80/user/month) - Includes Conditional Access, MFA, group-based access
- **P2**: ($9/user/month) (~€8.40/user/month) (~£7.20/user/month) - Adds Identity Protection, PIM, access reviews

**Check your license:**
```powershell
# PowerShell
Get-MgSubscribedSku | Where-Object {$_.SkuPartNumber -like "*AAD_PREMIUM*"} | Select-Object SkuPartNumber, ConsumedUnits, PrepaidUnits

# Azure CLI
az account show --query "user.name" -o tsv
```

### 2. **Break-Glass Accounts** (CRITICAL)

 **YOU MUST CREATE BREAK-GLASS ACCOUNTS BEFORE ENABLING POLICIES** 

Misconfigured Conditional Access policies can **lock out ALL users including Global Admins**. Break-glass accounts provide emergency access.

**How to create break-glass accounts:**

1. **Create dedicated admin account:**
   ```bash
   # Azure CLI
   az ad user create \
     --display-name "Break Glass Admin 1" \
     --user-principal-name breakglass1@yourdomain.com \
     --password "SuperSecurePassword123!" \
     --force-change-password-next-sign-in false
   ```

2. **Assign Global Administrator role:**
   ```bash
   # Get role definition ID
   ROLE_ID=$(az ad sp list --display-name "Microsoft Graph" --query "[0].appRoles[?value=='RoleManagement.ReadWrite.Directory'].id" -o tsv)
   
   # Assign role
   az ad user update --id breakglass1@yourdomain.com --force-change-password-next-sign-in false
   ```

3. **Create Entra ID group for break-glass accounts:**
   ```bash
   # Create group
   az ad group create \
     --display-name "Break-Glass Accounts" \
     --mail-nickname "BreakGlass" \
     --description "Emergency access accounts excluded from Conditional Access policies"
   
   # Add break-glass user to group
   GROUP_ID=$(az ad group show --group "Break-Glass Accounts" --query id -o tsv)
   USER_ID=$(az ad user show --id breakglass1@yourdomain.com --query id -o tsv)
   az ad group member add --group $GROUP_ID --member-id $USER_ID
   ```

4. **Secure the password:**
   - Store password in physical safe or sealed envelope
   - Split password across multiple executives
   - Use Azure Key Vault with restricted access
   - **NEVER** store in LastPass, 1Password, or any password manager

5. **Test monthly:**
   - Sign in as break-glass account monthly
   - Verify access to Entra portal
   - Verify Global Admin permissions
   - Document test results

### 3. **AVD Users Group**

Create an Entra ID group containing all AVD users:

```bash
# Create AVD users group
az ad group create \
  --display-name "AVD Users" \
  --mail-nickname "AVDUsers" \
  --description "Users with access to Azure Virtual Desktop"

# Add users
az ad group member add --group "AVD Users" --member-id <user-object-id>
```

### 4. **Intune Setup** (if using device compliance)

Device compliance policies require **Microsoft Intune**:

1. Enable Intune in Azure portal
2. Create compliance policy for Windows 10/11:
   - Require BitLocker
   - Require firewall enabled
   - Require antivirus up-to-date
   - Require OS version (e.g., Windows 11 22H2+)
3. Assign policy to AVD users
4. Enroll devices in Intune (Hybrid Azure AD Join or Azure AD Join)

---

## Quick Start

### Basic Configuration (MFA + Legacy Auth Blocking)

** RECOMMENDED: Automatic Integration with avd_core Module**

The module automatically uses the same Entra ID group from `avd_core` for consistent access control:

```hcl
# Step 1: AVD Core with user group
module "avd_core" {
  source = "../../modules/avd_core"
  # ... other config ...
  user_group_object_id = "12345678-1234-1234-1234-123456789012"  # AVD Users group
}

# Step 2: Conditional Access (automatically targets same group!)
module "conditional_access" {
  source = "../../modules/conditional_access"

  enabled = true

  # Enable policies
  require_mfa       = true
  block_legacy_auth = true

  # PRIMARY GROUP: Automatically wired from avd_core (no manual config!)
  avd_users_group_id = module.avd_core.user_group_object_id

  # CRITICAL: Break-glass accounts (emergency access)
  break_glass_group_ids = [
    "87654321-4321-4321-4321-210987654321"  # Break-Glass Accounts group
  ]

  # AVD application IDs (default, can be customized)
  avd_application_ids = [
    "9cdead84-a844-4324-93f2-b2e6bb768d07",  # Azure Virtual Desktop
    "38aa3b87-a06d-4817-b275-7a316988d93b"   # Windows Sign-In
  ]

  # Policy states (use report-only initially!)
  mfa_policy_state         = "enabledForReportingButNotEnforced"  # AUDIT MODE
  legacy_auth_policy_state = "enabledForReportingButNotEnforced"  # AUDIT MODE
}
```

** Key Benefits:**
-  Same group for AVD app access AND Conditional Access policies
-  No duplicate group configuration
-  Consistent access control across AVD infrastructure

---

### Advanced: Pilot Rollout with Additional Groups

For gradual MFA rollout, use `additional_target_group_ids`:

```hcl
module "conditional_access" {
  source = "../../modules/conditional_access"

  enabled = true

  # Primary AVD users group (from avd_core)
  avd_users_group_id = module.avd_core.user_group_object_id

  # Additional groups for pilot users
  additional_target_group_ids = [
    "11111111-2222-3333-4444-555555555555"  # AVD Pilot Users group
  ]

  # Break-glass accounts
  break_glass_group_ids = [
    "87654321-4321-4321-4321-210987654321"
  ]

  # Enable MFA for pilot group only
  require_mfa       = true
  block_legacy_auth = true

  mfa_policy_state         = "enabledForReportingButNotEnforced"
  legacy_auth_policy_state = "enabledForReportingButNotEnforced"
}
```

**Use cases for additional groups:**
- Pilot users for gradual rollout
- Power users needing different policies
- Temporary access for contractors

---

### Legacy Configuration (Manual Group Targeting)

 **Deprecated**: Use `avd_users_group_id` instead for consistency.

```hcl
module "conditional_access" {
  source = "../../modules/conditional_access"

  enabled = true

  # Legacy: Manual group targeting (not recommended)
  target_group_ids = [
    "12345678-1234-1234-1234-123456789012"  # AVD Users group
  ]

  break_glass_group_ids = [
    "87654321-4321-4321-4321-210987654321"
  ]
```

### Production Configuration (All Policies)

```hcl
module "conditional_access" {
  source = "../../modules/conditional_access"

  enabled = true

  # Enable all policies
  require_mfa              = true
  require_compliant_device = true   # Requires Intune
  block_legacy_auth        = true
  require_approved_app     = true   # Mobile devices only
  enable_session_controls  = true

  # Targeting (automatic integration with avd_core)
  avd_users_group_id    = module.avd_core.user_group_object_id
  break_glass_group_ids = ["<break-glass-group-id>"]

  # Device policy: OR (flexible) vs AND (strict)
  require_compliant_or_hybrid = true  # Compliant OR Hybrid joined

  # Legacy auth: block all apps or just AVD
  block_legacy_auth_all_apps = true  # Recommended

  # Session controls
  sign_in_frequency_hours = 12        # Re-auth every 12 hours
  sign_in_frequency_period = "hours"
  persistent_browser_mode  = "never"  # Disable "Stay signed in"

  # Policy states (after testing in report-only mode)
  mfa_policy_state                = "enabled"
  device_policy_state             = "enabled"
  legacy_auth_policy_state        = "enabled"
  approved_app_policy_state       = "enabled"
  session_controls_policy_state   = "enabled"
}
```

---

## Policy Templates

### Policy 1: Require Multi-Factor Authentication

**Purpose:** Force MFA for all AVD access (web portal + RDP connections).

**Conditions:**
- **Users:** Members of `avd_users_group_id` + `additional_target_group_ids` (automatically from avd_core)
- **Applications:** AVD cloud app (9cdead84-a844-4324-93f2-b2e6bb768d07)
- **Platforms:** All (Windows, macOS, iOS, Android, Linux)
- **Client app types:** Browser, mobile apps and desktop clients (modern auth only)

**Grant Control:** Require multi-factor authentication

**Exclusions:** Break-glass accounts + `mfa_excluded_group_ids`

**Variables:**
```hcl
require_mfa              = true   # Enable policy
mfa_policy_name          = "AVD: Require Multi-Factor Authentication"
mfa_policy_state         = "enabledForReportingButNotEnforced"  # Start with audit
mfa_excluded_group_ids   = []     # Additional exclusions (e.g., service accounts)
```

**User Experience:**
1. User navigates to AVD web client or launches Remote Desktop
2. Prompted for username/password
3. **Prompted for MFA** (Microsoft Authenticator, SMS, phone call)
4. After MFA, granted access to AVD session

---

### Policy 2: Require Compliant or Hybrid Joined Device

**Purpose:** Only allow access from managed devices (Intune-compliant or Hybrid Azure AD joined).

**Conditions:**
- **Users:** Members of `avd_users_group_id` + `additional_target_group_ids`
- **Applications:** AVD cloud app
- **Platforms:** Windows only (device compliance typically Windows-specific)
- **Client app types:** Browser, mobile apps and desktop clients

**Grant Control:** 
- **Option A (OR):** Require device to be marked as compliant **OR** require Hybrid Azure AD joined device (flexible)
- **Option B (AND):** Require **BOTH** compliant and Hybrid joined (strict)

**Exclusions:** Break-glass accounts + `device_excluded_group_ids`

**Variables:**
```hcl
require_compliant_device     = true    # Enable policy (requires Intune!)
device_policy_name           = "AVD: Require Compliant or Hybrid Joined Device"
device_policy_state          = "enabledForReportingButNotEnforced"
require_compliant_or_hybrid  = true    # OR (true) vs AND (false)
device_excluded_group_ids    = []      # E.g., pilot users with unmanaged devices
```

**Prerequisites:**
- Microsoft Intune subscription
- Device compliance policies configured
- Devices enrolled in Intune or Hybrid Azure AD joined

**User Experience:**
1. User attempts AVD access from non-compliant device
2. **Blocked** with error: "You can't get there from here"
3. Directed to Intune company portal to remediate compliance issues
4. Once compliant, access granted

---

### Policy 3: Block Legacy Authentication

**Purpose:** Prevent credential theft by blocking legacy protocols (IMAP, POP3, SMTP, Exchange ActiveSync).

**Conditions:**
- **Users:** Members of `avd_users_group_id` + `additional_target_group_ids`
- **Applications:** 
  - **Option A:** All cloud apps (recommended)
  - **Option B:** AVD apps only
- **Client app types:** 
  - `exchangeActiveSync` (Exchange ActiveSync)
  - `other` (IMAP, POP3, SMTP, legacy MAPI)

**Grant Control:** Block access

**Exclusions:** Break-glass accounts + `legacy_auth_excluded_group_ids`

**Variables:**
```hcl
block_legacy_auth             = true   # Enable policy
legacy_auth_policy_name       = "AVD: Block Legacy Authentication"
legacy_auth_policy_state      = "enabled"  # Safe to enable immediately
block_legacy_auth_all_apps    = true   # Block for all apps (recommended)
legacy_auth_excluded_group_ids = []    # Service accounts needing legacy auth
```

**Why Enable Immediately?**
- Legacy protocols don't support MFA (security risk)
- AVD uses modern authentication (Remote Desktop Protocol with Azure AD auth)
- Safe to block without impacting AVD users

**User Experience:**
- Modern AVD clients: **No impact** (uses modern auth)
- Legacy protocols: **Blocked** (intended behavior)

---

### Policy 4: Require Approved Client App (Optional)

**Purpose:** On mobile devices (iOS/Android), require Microsoft Remote Desktop app (prevents unapproved third-party clients).

**Conditions:**
- **Users:** Members of `target_group_ids`
- **Applications:** AVD cloud app
- **Platforms:** iOS, Android only (excludes Windows/macOS)
- **Client app types:** Mobile apps and desktop clients

**Grant Control:** Require approved client application

**Exclusions:** Break-glass accounts + `approved_app_excluded_group_ids`

**Variables:**
```hcl
require_approved_app          = true   # Enable policy
approved_app_policy_name      = "AVD: Require Approved Client App (Mobile)"
approved_app_policy_state     = "enabledForReportingButNotEnforced"
approved_app_excluded_group_ids = []
```

**Approved Apps:**
- **Microsoft Remote Desktop** (iOS/Android)
- Microsoft-published clients only

**User Experience:**
1. User attempts AVD access from iOS/Android device
2. If using unapproved app: **Blocked**
3. Directed to install Microsoft Remote Desktop from App Store/Play Store
4. Once installed, access granted

** Note:** This policy is **optional** and may cause friction. Many organizations skip this policy.

---

### Policy 5: Session Controls (Optional)

**Purpose:** Enforce sign-in frequency and disable persistent browser sessions.

**Conditions:**
- **Users:** Members of `target_group_ids`
- **Applications:** AVD cloud app
- **Platforms:** All

**Session Controls:**
- **Sign-in frequency:** Force re-authentication every X hours/days
- **Persistent browser:** Disable "Stay signed in?" prompt

**Exclusions:** Break-glass accounts + `session_controls_excluded_group_ids`

**Variables:**
```hcl
enable_session_controls         = true     # Enable policy
session_controls_policy_name    = "AVD: Session Controls"
session_controls_policy_state   = "enabledForReportingButNotEnforced"
sign_in_frequency_hours         = 12       # Re-auth every 12 hours
sign_in_frequency_period        = "hours"  # Or "days"
persistent_browser_mode         = "never"  # Disable "Stay signed in"
session_controls_excluded_group_ids = []
```

**Recommended Values:**
| Use Case | Sign-In Frequency | Persistent Browser |
|----------|-------------------|--------------------|
| High security | 4 hours | never |
| Standard | 12 hours | never |
| Convenience | 24 hours | always |

**User Experience:**
- User signs in to AVD web client
- After 12 hours (configurable), forced to re-authenticate
- "Stay signed in?" prompt disabled (if persistent_browser_mode = never)

---

## Validation Procedures

### 1. Verify Policies Created

**Entra Portal:**
1. Navigate to **Entra ID** → **Security** → **Conditional Access**
2. Verify policies appear with correct names:
   - `AVD: Require Multi-Factor Authentication`
   - `AVD: Require Compliant or Hybrid Joined Device`
   - `AVD: Block Legacy Authentication`
   - `AVD: Require Approved Client App (Mobile)`
   - `AVD: Session Controls`
3. Check policy state (Report-only vs Enabled)

**Azure CLI:**
```bash
# List all Conditional Access policies
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
  --query "value[?contains(displayName, 'AVD')].{Name:displayName, State:state, ID:id}" \
  --output table
```

**PowerShell:**
```powershell
# Install module
Install-Module Microsoft.Graph.Identity.SignIns -Scope CurrentUser

# Connect
Connect-MgGraph -Scopes "Policy.Read.All"

# List policies
Get-MgIdentityConditionalAccessPolicy | Where-Object {$_.DisplayName -like "AVD*"} | 
  Select-Object DisplayName, State, Id | Format-Table
```

---

### 2. Validate Sign-In Logs

**Entra Portal (Recommended for Beginners):**

1. Navigate to **Entra ID** → **Monitoring** → **Sign-in logs**
2. Add filters:
   - **Application**: Azure Virtual Desktop (9cdead84-a844-4324-93f2-b2e6bb768d07)
   - **Date**: Last 24 hours
3. Click on any sign-in event
4. Select **Conditional Access** tab
5. Review:
   - **Policies applied**: Which policies evaluated this sign-in
   - **Result**: Success, Failure, Not applied
   - **Controls**: MFA required, Compliant device required, etc.

**Azure CLI:**
```bash
# Get recent AVD sign-ins
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/auditLogs/signIns?\$filter=appId eq '9cdead84-a844-4324-93f2-b2e6bb768d07'&\$top=50" \
  --query "value[].{User:userPrincipalName, Status:status.errorCode, CA_Status:conditionalAccessStatus, Time:createdDateTime}" \
  --output table

# Get sign-ins with CA applied
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/auditLogs/signIns?\$filter=conditionalAccessStatus eq 'success' or conditionalAccessStatus eq 'failure'" \
  --query "value[?appId=='9cdead84-a844-4324-93f2-b2e6bb768d07'].{User:userPrincipalName, CA_Status:conditionalAccessStatus, Policies:appliedConditionalAccessPolicies[*].displayName}" \
  --output json
```

**PowerShell:**
```powershell
# Get recent sign-ins for AVD
Get-MgAuditLogSignIn -Filter "appId eq '9cdead84-a844-4324-93f2-b2e6bb768d07'" -Top 50 | 
  Select-Object UserPrincipalName, ConditionalAccessStatus, CreatedDateTime, @{
    Name='Policies'; Expression={$_.AppliedConditionalAccessPolicies.DisplayName -join ', '}
  } | Format-Table

# Get failed CA policy evaluations
Get-MgAuditLogSignIn -Filter "conditionalAccessStatus eq 'failure'" | 
  Where-Object {$_.AppId -eq '9cdead84-a844-4324-93f2-b2e6bb768d07'} |
  Select-Object UserPrincipalName, CreatedDateTime, @{
    Name='FailedPolicies'; Expression={
      ($_.AppliedConditionalAccessPolicies | Where-Object {$_.Result -eq 'failure'}).DisplayName -join ', '
    }
  } | Format-Table
```

---

### 3. Log Analytics Queries (Advanced)

If you have Azure Monitor + Log Analytics configured, use KQL queries:

**Query 1: CA Policy Evaluation Summary**
```kql
SigninLogs
| where AppId == "9cdead84-a844-4324-93f2-b2e6bb768d07"  // AVD app
| where ConditionalAccessStatus != "notApplied"
| summarize Count = count() by ConditionalAccessStatus, bin(TimeGenerated, 1h)
| render timechart
```

**Query 2: MFA Enforcement Rate**
```kql
SigninLogs
| where AppId == "9cdead84-a844-4324-93f2-b2e6bb768d07"
| extend MFARequired = iff(
    array_length(parse_json(AuthenticationRequirement)) > 1, "Yes", "No"
  )
| summarize MFA_Count = countif(MFARequired == "Yes"), Total = count()
| extend MFA_Rate = round(100.0 * MFA_Count / Total, 2)
| project MFA_Rate, MFA_Count, Total
```

**Query 3: Failed CA Policies**
```kql
SigninLogs
| where AppId == "9cdead84-a844-4324-93f2-b2e6bb768d07"
| where ConditionalAccessStatus == "failure"
| mv-expand CAPolicy = ConditionalAccessPolicies
| where CAPolicy.result == "failure"
| summarize FailureCount = count() by tostring(CAPolicy.displayName), UserPrincipalName
| order by FailureCount desc
```

**Query 4: Break-Glass Account Usage**
```kql
SigninLogs
| where UserPrincipalName startswith "breakglass"
| project TimeGenerated, UserPrincipalName, AppDisplayName, IPAddress, Location, ResultType
| order by TimeGenerated desc
```

---

### 4. Test Sign-Ins

**Test Scenario 1: MFA Policy**

1. **Setup:**
   - User in AVD Users group
   - User NOT in break-glass group
   - Policy state: `enabled`

2. **Test:**
   - Navigate to https://client.wvd.microsoft.com
   - Sign in with username/password
   - **Expected:** MFA prompt (Authenticator app, SMS, phone call)
   - After MFA, AVD session should launch

3. **Validation:**
   - Check sign-in logs (Entra portal)
   - Verify "MFA requirement" in Conditional Access tab
   - **Result:** Success with MFA completed

**Test Scenario 2: Device Compliance Policy**

1. **Setup:**
   - User in AVD Users group
   - Policy state: `enabled`
   - Test from non-compliant device

2. **Test:**
   - Attempt sign-in from unmanaged laptop
   - **Expected:** Blocked with error
     ```
     You can't get there from here
     Your organization requires your device to meet specific requirements
     Contact your IT admin for more information
     ```

3. **Remediation:**
   - Enroll device in Intune
   - Ensure device meets compliance policy
   - Retry sign-in
   - **Expected:** Access granted

**Test Scenario 3: Legacy Auth Blocking**

1. **Setup:**
   - Policy state: `enabled`

2. **Test:**
   - Attempt connection using legacy protocol (e.g., Exchange ActiveSync)
   - **Expected:** Connection blocked

3. **Modern client test:**
   - Use Microsoft Remote Desktop app
   - **Expected:** Connection succeeds (modern auth allowed)

---

### 5. Report-Only Mode Testing

**CRITICAL: Always test in report-only mode first!**

**Enable report-only mode:**
```hcl
mfa_policy_state         = "enabledForReportingButNotEnforced"
device_policy_state      = "enabledForReportingButNotEnforced"
legacy_auth_policy_state = "enabledForReportingButNotEnforced"
```

**What happens in report-only mode:**
- Policies evaluate sign-ins
- Results logged to sign-in logs
- **Users NOT blocked** (policies don't enforce)
- Allows monitoring without impact

**Testing process:**
1. Deploy policies in report-only mode
2. Monitor for 2-4 weeks
3. Review sign-in logs daily
4. Identify:
   - Users who would be blocked
   - Unexpected policy applications
   - Break-glass account exclusions working correctly
5. Adjust policies/exclusions as needed
6. Switch to `enabled` state

---

## Rollback Procedures

### Emergency Rollback: Admin Locked Out

**Scenario:** You deployed policies and now admins can't sign in (including yourself).

**Solution 1: Use Break-Glass Account**

1. **Sign in with break-glass account:**
   - URL: https://portal.azure.com
   - Username: `breakglass1@yourdomain.com`
   - Password: (retrieve from secure storage)

2. **Disable problematic policy:**
   - Navigate: **Entra ID** → **Security** → **Conditional Access**
   - Find policy blocking access
   - Click **Edit**
   - Change **State** to **Disabled**
   - Click **Save**

3. **Verify access restored:**
   - Sign out as break-glass account
   - Sign in as regular admin
   - Verify access restored

4. **Investigate root cause:**
   - Review sign-in logs
   - Identify why policy blocked admins
   - Adjust exclusions or policy configuration

**Solution 2: Azure CLI/PowerShell (if available)**

```bash
# Azure CLI - Disable policy
az rest --method PATCH \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/{policy-id}" \
  --headers "Content-Type=application/json" \
  --body '{"state":"disabled"}'
```

```powershell
# PowerShell - Disable policy
Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId "<policy-id>" -State "disabled"
```

---

### Rollback Option 1: Disable Policy (Temporary)

**When to use:** Testing/troubleshooting, want to keep policy configuration.

**Method 1: Entra Portal**
1. Navigate to **Entra ID** → **Security** → **Conditional Access**
2. Select policy
3. Click **Edit**
4. Change **State** to **Disabled**
5. Click **Save**

**Method 2: Azure CLI**
```bash
# Get policy ID
POLICY_ID=$(az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
  --query "value[?displayName=='AVD: Require Multi-Factor Authentication'].id" -o tsv)

# Disable policy
az rest --method PATCH \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$POLICY_ID" \
  --headers "Content-Type=application/json" \
  --body '{"state":"disabled"}'
```

**Method 3: Terraform**
```hcl
# Change policy state in terraform.tfvars or main.tf
mfa_policy_state = "disabled"

# Apply
terraform apply -auto-approve
```

---

### Rollback Option 2: Change to Report-Only Mode

**When to use:** Want to monitor without enforcement.

**Method 1: Entra Portal**
1. Navigate to **Entra ID** → **Security** → **Conditional Access**
2. Select policy
3. Click **Edit**
4. Change **State** to **Report-only**
5. Click **Save**

**Method 2: Terraform**
```hcl
# Change policy state
mfa_policy_state = "enabledForReportingButNotEnforced"

# Apply
terraform apply -auto-approve
```

**Result:**
- Policy evaluates sign-ins
- Results logged
- Users NOT blocked

---

### Rollback Option 3: Add User to Exclusion Group

**When to use:** Temporarily exclude specific user from policies.

**Azure CLI:**
```bash
# Get user ID
USER_ID=$(az ad user show --id user@domain.com --query id -o tsv)

# Get break-glass group ID
GROUP_ID=$(az ad group show --group "Break-Glass Accounts" --query id -o tsv)

# Add user to group
az ad group member add --group $GROUP_ID --member-id $USER_ID

# Verify
az ad group member list --group $GROUP_ID --query "[].userPrincipalName" -o table
```

**Entra Portal:**
1. Navigate to **Entra ID** → **Groups**
2. Select **Break-Glass Accounts** group
3. Click **Members** → **Add members**
4. Search for user
5. Click **Select**

** Important:**
- This bypasses ALL policies for that user
- Use sparingly (security risk)
- Document reason for exclusion
- Remove after troubleshooting

---

### Rollback Option 4: Destroy Policies (Permanent)

**When to use:** Policies no longer needed, complete removal.

**Method 1: Terraform**
```bash
# Option A: Disable module
# In envs/dev/main.tf, change:
enable_conditional_access = false

# Apply (module won't be created)
terraform apply -auto-approve

# Option B: Destroy specific module
terraform destroy -target='module.conditional_access' -auto-approve

# Option C: Disable individual policies
# In terraform.tfvars:
require_mfa = false
block_legacy_auth = false
# ... apply
```

**Method 2: Azure CLI**
```bash
# Get policy ID
POLICY_ID=$(az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
  --query "value[?displayName=='AVD: Require Multi-Factor Authentication'].id" -o tsv)

# Delete policy
az rest --method DELETE \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$POLICY_ID"
```

**Method 3: Entra Portal**
1. Navigate to **Entra ID** → **Security** → **Conditional Access**
2. Select policy
3. Click **Delete**
4. Confirm deletion

---

### Rollback Option 5: Restore from Backup

**When to use:** Accidentally deleted policies, need to restore configuration.

**Terraform State:**
```bash
# If you destroyed policies but want them back, simply re-apply
terraform apply -auto-approve

# Terraform state contains policy configuration
# Re-applying recreates policies
```

**Azure Backup (if configured):**
- Conditional Access policies are NOT backed up automatically
- Must export policy JSON manually before changes

**Export policy (for backup):**
```bash
# Export all CA policies
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies" \
  --output json > ca_policies_backup_$(date +%Y%m%d).json

# Import later if needed
# (manual process, requires parsing JSON and recreating policies)
```

---

## Break-Glass Account Management

### Creating Break-Glass Accounts

**Why 2 accounts?**
- Redundancy (if one is locked/compromised)
- Separation of duties (require 2 people for emergency access)

**Account 1:**
```bash
# Create user
az ad user create \
  --display-name "Break Glass Admin 1" \
  --user-principal-name breakglass1@yourdomain.com \
  --password "$(openssl rand -base64 32)" \
  --force-change-password-next-sign-in false

# Assign Global Administrator
az role assignment create \
  --assignee breakglass1@yourdomain.com \
  --role "Global Administrator"
```

**Account 2:**
```bash
az ad user create \
  --display-name "Break Glass Admin 2" \
  --user-principal-name breakglass2@yourdomain.com \
  --password "$(openssl rand -base64 32)" \
  --force-change-password-next-sign-in false

az role assignment create \
  --assignee breakglass2@yourdomain.com \
  --role "Global Administrator"
```

### Securing Break-Glass Passwords

**Option 1: Physical Safe**
- Print password on paper
- Store in physical safe (multiple locations)
- Require 2 keys/combinations (separation of duties)

**Option 2: Azure Key Vault (restricted access)**
```bash
# Store password in Key Vault
az keyvault secret set \
  --vault-name <vault-name> \
  --name "BreakGlass1-Password" \
  --value "<password>"

# Grant access to emergency responders only
az keyvault set-policy \
  --name <vault-name> \
  --object-id <user-object-id> \
  --secret-permissions get list
```

**Option 3: Split Password (highest security)**
- Split password into 3 parts
- Give each part to different executive
- Require 2 of 3 parts to reconstruct password

### Testing Break-Glass Accounts

**Monthly test procedure:**

1. **Sign in:**
   - URL: https://portal.azure.com
   - Use break-glass account credentials

2. **Verify permissions:**
   ```bash
   # Check role assignment
   az role assignment list --assignee breakglass1@yourdomain.com --query "[].roleDefinitionName" -o table
   
   # Should show "Global Administrator"
   ```

3. **Verify CA exclusion:**
   - Navigate to **Entra ID** → **Security** → **Conditional Access**
   - Open any AVD policy
   - Check **Excluded users and groups**
   - Verify break-glass group present

4. **Test access to critical resources:**
   - Entra ID (can view users/groups)
   - Conditional Access (can edit policies)
   - Azure subscriptions (can view resources)

5. **Document test:**
   ```
   Date: 2024-01-15
   Tester: John Doe
   Account: breakglass1@yourdomain.com
   Result: Success - Full access verified
   Issues: None
   ```

6. **Sign out:**
   - Always sign out completely
   - Clear browser cache/cookies

---

## Troubleshooting

### Issue 1: Admin Locked Out (Can't Sign In)

**Symptoms:**
- Admin attempts sign-in
- Blocked by Conditional Access policy
- Error: "You don't meet the criteria to access this resource"

**Root Cause:**
- Admin not in exclusion group
- Break-glass group misconfigured
- Policy targeting too broad

**Solution:**
1. Use break-glass account to sign in
2. Navigate to **Entra ID** → **Security** → **Conditional Access**
3. Open problematic policy
4. Check **Excluded users and groups**:
   - Add break-glass group if missing
   - Add admin group if needed
5. Save policy
6. Retry sign-in as admin

**Prevention:**
- Always exclude break-glass group from ALL policies
- Test exclusions before enabling policies
- Maintain at least 2 break-glass accounts

---

### Issue 2: Device Compliance Not Working

**Symptoms:**
- Users with compliant devices blocked
- Error: "Your device doesn't meet requirements"
- Intune shows device as compliant

**Root Cause:**
- Device not Hybrid Azure AD joined
- Compliance policy not assigned
- Sync delay (Intune → Entra ID)

**Solution:**

**Check device status:**
```bash
# Get device compliance status
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/devices?\$filter=displayName eq '<device-name>'" \
  --query "value[].{Name:displayName, Compliant:isCompliant, Joined:trustType}" -o table
```

**Verify Hybrid Azure AD Join:**
1. On device, open Command Prompt:
   ```cmd
   dsregcmd /status
   ```
2. Check:
   - `AzureAdJoined : YES` (or)
   - `DomainJoined : YES` + `AzureAdJoined : YES` (Hybrid)

**Check Intune compliance:**
1. Sign in to Intune portal (endpoint.microsoft.com)
2. Navigate: **Devices** → **All devices**
3. Find device
4. Check **Compliance state**: Should be "Compliant"

**Force sync:**
```bash
# Sync device compliance to Entra ID
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/<device-id>/syncDevice"
```

**Temporary workaround:**
- Add user to `device_excluded_group_ids` temporarily
- Investigate compliance issue
- Remove from exclusion after fix

---

### Issue 3: Approved Client App Not Working

**Symptoms:**
- Users with Microsoft Remote Desktop blocked
- Error: "This app isn't approved for access"
- iOS/Android users can't connect

**Root Cause:**
- Microsoft Remote Desktop not marked as approved app
- App protection policy not configured
- Client app version outdated

**Solution:**

**Verify app registration:**
```bash
# Check if Remote Desktop is an approved app
az ad sp list --filter "displayName eq 'Microsoft Remote Desktop'" --query "[].appId" -o tsv
```

**Update client app:**
1. On iOS: Open App Store → Search "Microsoft Remote Desktop" → Update
2. On Android: Open Play Store → Search "Microsoft Remote Desktop" → Update

**Check app protection policy:**
1. Sign in to Intune portal
2. Navigate: **Apps** → **App protection policies**
3. Verify policy exists for iOS/Android
4. Ensure Microsoft Remote Desktop is included

**Alternative: Disable policy temporarily**
```hcl
# In terraform.tfvars
require_approved_app = false

# Apply
terraform apply -auto-approve
```

---

### Issue 4: Sign-In Logs Not Showing CA Evaluation

**Symptoms:**
- Sign-in logs show `conditionalAccessStatus: notApplied`
- Policies enabled but not evaluating

**Root Cause:**
- User not in target group
- Application not targeted by policy
- Policy disabled

**Solution:**

**Check user membership:**
```bash
# Verify user in AVD Users group
GROUP_ID=$(az ad group show --group "AVD Users" --query id -o tsv)
az ad group member list --group $GROUP_ID --query "[?userPrincipalName=='user@domain.com']" -o table
```

**Check policy targeting:**
1. Navigate to **Entra ID** → **Security** → **Conditional Access**
2. Open policy
3. Verify:
   - **Users:** Target group selected
   - **Cloud apps:** AVD app selected (9cdead84-a844-4324-93f2-b2e6bb768d07)
   - **State:** Enabled or Report-only

**Check application:**
```bash
# Verify sign-in used AVD app
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/auditLogs/signIns?\$filter=userPrincipalName eq 'user@domain.com'&\$top=10" \
  --query "value[].{App:appDisplayName, AppId:appId, CA:conditionalAccessStatus}" -o table
```

---

## Best Practices

### 1. Always Start with Report-Only Mode

**Why?**
- No user impact while testing
- Identify unexpected policy applications
- Verify exclusions working correctly

**Process:**
1. Deploy policies in report-only: `enabledForReportingButNotEnforced`
2. Monitor sign-in logs for 2-4 weeks
3. Review logs daily (look for failures, unexpected blocks)
4. Adjust exclusions as needed
5. Switch to `enabled` after validation

---

### 2. Use Pilot Groups for Gradual Rollout

**Strategy:**
```hcl
# Week 1: IT team only
target_group_ids = ["<it-team-group-id>"]

# Week 2: Add pilot users
target_group_ids = ["<it-team-group-id>", "<pilot-users-group-id>"]

# Week 3: Add all users
target_group_ids = ["<avd-users-group-id>"]
```

**Benefits:**
- Catch issues early (small blast radius)
- Build confidence in policies
- Collect feedback from pilot users

---

### 3. Test Break-Glass Accounts Monthly

**Procedure:**
- Sign in with break-glass account
- Verify Global Admin access
- Check CA policy exclusions
- Document test results
- Sign out and clear cookies

**Why?**
- Passwords may expire (if not configured correctly)
- Accounts may be disabled by accident
- Exclusions may be removed during policy updates
- Practice for real emergency

---

### 4. Document All Exclusions

**Create a register:**
| User/Group | Policy Excluded | Reason | Added By | Date | Review Date |
|------------|-----------------|--------|----------|------|-------------|
| ServiceAccount1 | Legacy Auth | Legacy app requires SMTP | John Doe | 2024-01-15 | 2024-07-15 |
| Pilot-Group-1 | Device Compliance | Testing phase | Jane Smith | 2024-01-20 | 2024-02-20 |

**Why?**
- Audit trail for security compliance
- Regular review of exclusions (remove when no longer needed)
- Prevent exclusion sprawl

---

### 5. Regular Policy Reviews

**Quarterly review checklist:**
- [ ] Review sign-in logs (any policy failures?)
- [ ] Check exclusion groups (still needed?)
- [ ] Test break-glass accounts
- [ ] Update policy states (report-only → enabled)
- [ ] Review new CA features from Microsoft
- [ ] Document any changes

---

## Monitoring and Alerting

### Azure Monitor Alerts

**Alert 1: Break-Glass Account Used**

```bash
# Log Analytics query
SigninLogs
| where UserPrincipalName startswith "breakglass"
| project TimeGenerated, UserPrincipalName, IPAddress, Location, AppDisplayName
```

**Alert configuration:**
- **Severity:** Critical (Sev 0)
- **Frequency:** Real-time
- **Action:** Email/SMS to security team immediately

---

**Alert 2: High CA Policy Failure Rate**

```kql
SigninLogs
| where AppId == "9cdead84-a844-4324-93f2-b2e6bb768d07"
| where ConditionalAccessStatus == "failure"
| summarize FailureCount = count() by bin(TimeGenerated, 1h)
| where FailureCount > 10  // Threshold
```

**Alert configuration:**
- **Severity:** High (Sev 1)
- **Frequency:** Every 15 minutes
- **Action:** Email to IT team

---

**Alert 3: User Added to Break-Glass Group**

```kql
AuditLogs
| where OperationName == "Add member to group"
| where TargetResources[0].displayName == "Break-Glass Accounts"
| project TimeGenerated, InitiatedBy.user.userPrincipalName, TargetResources[0].userPrincipalName
```

**Alert configuration:**
- **Severity:** Medium (Sev 2)
- **Frequency:** Real-time
- **Action:** Email to security team

---

## Related Resources

- [Microsoft Entra Conditional Access Documentation](https://learn.microsoft.com/entra/identity/conditional-access/)
- [Plan a Conditional Access Deployment](https://learn.microsoft.com/entra/identity/conditional-access/plan-conditional-access)
- [Conditional Access Templates](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-policy-common)
- [Manage Break-Glass Accounts](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)
- [AVD Security Best Practices](https://learn.microsoft.com/azure/virtual-desktop/security-guide)

---

## License Requirements Summary

| Feature | License Required |
|---------|------------------|
| Conditional Access | Entra ID Premium P1 or P2 |
| MFA | Included in P1/P2 |
| Device Compliance | Microsoft Intune |
| Approved Client Apps | Intune App Protection |
| Identity Protection | Entra ID Premium P2 |
| Access Reviews | Entra ID Premium P2 |

**Cost estimate (per user/month):**
- Entra ID Premium P1: ($6/user/month) (~€5.60/user/month) (~£4.80/user/month)
- Entra ID Premium P2: ($9/user/month) (~€8.40/user/month) (~£7.20/user/month)
- Microsoft Intune: ($6/user/month) (~€5.60/user/month) (~£4.80/user/month) (included in Microsoft 365 E3/E5)

---

## Support

For issues with this module:
1. Check [Troubleshooting](#-troubleshooting) section
2. Review [Sign-in logs](#2-validate-sign-in-logs)
3. Test with break-glass account
4. If locked out: Use emergency access procedures
5. For persistent issues: Contact your organization's Azure admin

**Emergency contact:** Ensure you have phone numbers for:
- Azure support: Your organization's support contract
- Microsoft Premier Support: Available 24/7 for P1/P2 customers
- Internal IT security team: For break-glass password access
