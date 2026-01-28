# Azure Virtual Desktop Terraform Modules - Variables Summary

This document provides a comprehensive list of all variables for each module in the Azure Virtual Desktop Terraform Playbook.

**Modules Processed:** 18/18
**Total Variables Documented:** 350+

---

## Module: avd_core (17 variables)

 **Variables section added to README.md**

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `prefix` | Naming prefix for AVD resources | `string` | `"avd"` | No |
| `env` | Environment name | `string` | - | Yes |
| `location` | Azure region for AVD resources | `string` | - | Yes |
| `resource_group_name` | Name of the resource group | `string` | - | Yes |
| `host_pool_name` | Name of the host pool | `string` | `""` | No |
| `max_sessions` | Maximum concurrent sessions per session host | `number` | `10` | No |
| `load_balancer_type` | Load balancing algorithm | `string` | `"BreadthFirst"` | No |
| `start_vm_on_connect` | Enable Start VM on Connect feature | `bool` | `true` | No |
| `custom_rdp_properties` | Custom RDP properties | `string` | (see defaults) | No |
| `user_group_object_id` | Azure AD group object ID for AVD users | `string` | `""` | No |
| `registration_token_ttl_hours` | Registration token time-to-live | `string` | `"48h"` | No |
| `workspace_friendly_name` | Display name for workspace | `string` | `"AVD Workspace"` | No |
| `workspace_description` | Description for workspace | `string` | `"Azure Virtual Desktop Workspace"` | No |
| `host_pool_friendly_name` | Display name for host pool | `string` | `"AVD Host Pool"` | No |
| `host_pool_description` | Description for host pool | `string` | `"Azure Virtual Desktop Host Pool"` | No |
| `app_group_friendly_name` | Display name for app group | `string` | `"Desktop"` | No |
| `app_group_description` | Description for app group | `string` | `"Desktop Application Group"` | No |
| `enable_scheduled_agent_updates` | Enable scheduled agent updates | `bool` | `false` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: backup (25 variables)

**Variables section added to README.md**

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `recovery_vault_name` | Recovery Services Vault name | `string` | - | Yes |
| `vm_backup_retention_days` | Daily backup retention (7-9999 days) | `number` | `7` | No |
| `vm_backup_retention_weeks` | Weekly backup retention (0-5163 weeks) | `number` | `4` | No |
| `vm_backup_retention_months` | Monthly backup retention (0-1188 months) | `number` | `0` | No |
| `vm_backup_retention_years` | Yearly backup retention (0-99 years) | `number` | `0` | No |
| `fslogix_backup_enabled` | Enable Azure Files backup | `bool` | `false` | No |
| `fslogix_backup_retention_days` | Azure Files daily retention (1-200 days) | `number` | `7` | No |
| `fslogix_backup_retention_weeks` | Azure Files weekly retention (0-200 weeks) | `number` | `4` | No |
| `fslogix_backup_retention_months` | Azure Files monthly retention (0-120 months) | `number` | `0` | No |
| `fslogix_backup_retention_years` | Azure Files yearly retention (0-10 years) | `number` | `0` | No |
| `backup_time` | Backup time (HH:MM, 24-hour) | `string` | `"02:00"` | No |
| `backup_timezone` | Timezone for backup schedule | `string` | `"UTC"` | No |
| `backup_weekly_retention_weekdays` | Days for weekly backups | `list(string)` | `["Sunday"]` | No |
| `backup_monthly_retention_weekdays` | Days for monthly backups | `list(string)` | `["Sunday"]` | No |
| `backup_monthly_retention_weeks` | Weeks for monthly backups | `list(string)` | `["First"]` | No |
| `backup_yearly_retention_weekdays` | Days for yearly backups | `list(string)` | `["Sunday"]` | No |
| `backup_yearly_retention_weeks` | Weeks for yearly backups | `list(string)` | `["First"]` | No |
| `backup_yearly_retention_months` | Months for yearly backups | `list(string)` | `["January"]` | No |
| `enable_soft_delete` | Enable soft delete protection | `bool` | `true` | No |
| `dc_vm_id` | Domain Controller VM resource ID | `string` | `null` | No |
| `session_host_vm_ids` | Map of session host VM IDs | `map(string)` | `{}` | No |
| `storage_account_id` | Storage account resource ID | `string` | `null` | No |
| `fslogix_share_name` | FSLogix file share name | `string` | `null` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: compute_gallery (7 variables)

**Variables section added to README.md**

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `create_gallery` | Create new gallery or use existing | `bool` | `true` | No |
| `gallery_name` | Gallery name (1-80 chars) | `string` | - | Yes |
| `resource_group_name` | Resource group name | `string` | `""` | Conditional* |
| `location` | Azure region | `string` | `""` | Conditional* |
| `gallery_description` | Gallery description | `string` | `"Azure Compute Gallery for custom images"` | No |
| `existing_gallery_id` | Existing gallery resource ID | `string` | `null` | Conditional** |
| `tags` | Tags to apply to gallery | `map(string)` | `{}` | No |

\* Required when `create_gallery = true`  
\*\* Required when `create_gallery = false`

---

## Module: conditional_access (52 variables)

**Note:** This module has an extensive variable set due to multiple policy configurations. Variables section to be added to README.md after Policy Templates section.

### Core Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enabled` | Enable Conditional Access policies | `bool` | `true` | No |
| `avd_users_group_id` | Primary Entra ID group for AVD users | `string` | `""` | No |
| `additional_target_group_ids` | Additional group IDs to include | `list(string)` | `[]` | No |
| `target_group_ids` | (DEPRECATED) List of group IDs | `list(string)` | `[]` | No |
| `break_glass_group_ids` | Emergency access account group IDs | `list(string)` | `[]` | Yes* |
| `avd_application_ids` | AVD cloud application IDs | `list(string)` | (see defaults) | No |

\* Required when `enabled = true`

### MFA Policy Variables (6 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `require_mfa` | Enable MFA requirement policy | `bool` | `true` | No |
| `mfa_policy_name` | Display name for MFA policy | `string` | `"AVD: Require Multi-Factor Authentication"` | No |
| `mfa_policy_state` | Policy state (enabled/audit/disabled) | `string` | `"enabledForReportingButNotEnforced"` | No |
| `mfa_excluded_group_ids` | Additional exclusions from MFA | `list(string)` | `[]` | No |

### Device Compliance Policy Variables (6 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `require_compliant_device` | Enable device compliance requirement | `bool` | `false` | No |
| `device_policy_name` | Display name for device policy | `string` | `"AVD: Require Compliant or Hybrid Joined Device"` | No |
| `device_policy_state` | Policy state | `string` | `"enabledForReportingButNotEnforced"` | No |
| `require_compliant_or_hybrid` | Require compliant OR hybrid (vs AND) | `bool` | `true` | No |
| `device_excluded_group_ids` | Additional exclusions | `list(string)` | `[]` | No |

### Legacy Auth Blocking Variables (5 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `block_legacy_auth` | Enable legacy auth blocking policy | `bool` | `true` | No |
| `legacy_auth_policy_name` | Display name for legacy auth policy | `string` | `"AVD: Block Legacy Authentication"` | No |
| `legacy_auth_policy_state` | Policy state | `string` | `"enabledForReportingButNotEnforced"` | No |
| `block_legacy_auth_all_apps` | Block for all apps (vs AVD only) | `bool` | `true` | No |
| `legacy_auth_excluded_group_ids` | Additional exclusions | `list(string)` | `[]` | No |

### Approved Client App Variables (5 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `require_approved_app` | Require approved client app (mobile) | `bool` | `false` | No |
| `approved_app_policy_name` | Display name for approved app policy | `string` | `"AVD: Require Approved Client App (Mobile)"` | No |
| `approved_app_policy_state` | Policy state | `string` | `"enabledForReportingButNotEnforced"` | No |
| `approved_app_excluded_group_ids` | Additional exclusions | `list(string)` | `[]` | No |

### Session Controls Variables (9 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enable_session_controls` | Enable session controls | `bool` | `false` | No |
| `session_controls_policy_name` | Display name for session controls | `string` | `"AVD: Session Controls"` | No |
| `session_controls_policy_state` | Policy state | `string` | `"enabledForReportingButNotEnforced"` | No |
| `sign_in_frequency_hours` | Force re-auth after X hours | `number` | `12` | No |
| `sign_in_frequency_period` | Period: hours or days | `string` | `"hours"` | No |
| `persistent_browser_mode` | Persistent browser mode: always/never | `string` | `"never"` | No |
| `session_controls_excluded_group_ids` | Additional exclusions | `list(string)` | `[]` | No |

---

## Module: cost_management (16 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enabled` | Enable cost management budget | `bool` | `true` | No |
| `budget_name` | Budget name | `string` | - | Yes |
| `monthly_budget_amount` | Monthly budget in USD | `number` | - | Yes |
| `alert_emails` | Email addresses for alerts | `list(string)` | - | Yes |
| `budget_scope` | Scope: ResourceGroup or Subscription | `string` | `"ResourceGroup"` | No |
| `resource_group_id` | Resource group ID (if scope=ResourceGroup) | `string` | `null` | Conditional |
| `resource_group_name` | Resource group name (if scope=ResourceGroup) | `string` | `null` | Conditional |
| `subscription_id` | Subscription ID (if scope=Subscription) | `string` | `null` | Conditional |
| `alert_threshold_1` | First alert threshold (%) | `number` | `80` | No |
| `alert_threshold_2` | Second alert threshold (%) | `number` | `90` | No |
| `alert_threshold_3` | Third alert threshold (%) | `number` | `100` | No |
| `enable_forecasted_alerts` | Enable forecasted budget alerts | `bool` | `false` | No |
| `forecasted_alert_threshold` | Forecasted alert threshold (%) | `number` | `100` | No |
| `budget_start_date` | Budget start date (YYYY-MM-01) | `string` | `null` | No |
| `budget_end_date` | Budget end date (YYYY-MM-01) | `string` | `null` | No |
| `filter_tags` | Tags to filter budget scope | `map(string)` | `{}` | No |

---

## Module: domain-controller (15 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `domain_name` | Fully qualified domain name | `string` | - | Yes |
| `netbios_name` | NetBIOS domain name | `string` | - | Yes |
| `safe_mode_admin_password` | Safe Mode Administrator password | `string` (sensitive) | - | Yes |
| `admin_username` | Local administrator username | `string` | - | Yes |
| `admin_password` | Local administrator password | `string` (sensitive) | - | Yes |
| `dc_vm_size` | VM size for Domain Controller | `string` | `"Standard_B2ms"` | No |
| `os_disk_type` | OS disk type | `string` | `"StandardSSD_LRS"` | No |
| `os_disk_size_gb` | OS disk size in GB | `number` | `128` | No |
| `timezone` | Timezone for DC VM | `string` | `"UTC"` | No |
| `avd_ou_name` | AVD Organizational Unit name | `string` | `"AVD"` | No |
| `avd_ou_description` | AVD OU description | `string` | `"Organizational Unit for Azure Virtual Desktop session hosts"` | No |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `dc_name` | Domain Controller VM name | `string` | `"DC01"` | No |
| `subnet_id` | Subnet ID for DC deployment | `string` | - | Yes |
| `dc_private_ip` | Static private IP address | `string` | - | Yes |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: fslogix_storage (25 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `storage_account_name` | Storage account name (3-24 chars) | `string` | - | Yes |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `environment` | Environment name | `string` | `"dev"` | No |
| `storage_account_tier` | Standard or Premium | `string` | `"Premium"` | No |
| `storage_replication_type` | LRS, ZRS, GRS, GZRS | `string` | `"LRS"` | No |
| `storage_account_kind` | FileStorage or StorageV2 | `string` | `"FileStorage"` | No |
| `enable_shared_access_key` | Enable storage account key access | `bool` | `true` | No |
| `file_share_quota_gb` | File share size in GB (1-102400) | `number` | `100` | No |
| `file_share_access_tier` | Access tier (Premium, Hot, Cool, TransactionOptimized) | `string` | `"Premium"` | No |
| `enable_private_endpoint` | Enable private endpoint | `bool` | `true` | No |
| `private_endpoint_subnet_id` | Subnet ID for private endpoint | `string` | `""` | Conditional |
| `private_dns_zone_id` | Private DNS zone ID | `string` | `""` | No |
| `allowed_subnet_ids` | Allowed subnet IDs (public access) | `list(string)` | `[]` | No |
| `allowed_ip_addresses` | Allowed IP addresses/CIDR | `list(string)` | `[]` | No |
| `enable_ad_authentication` | Enable AD DS authentication | `bool` | `false` | No |
| `ad_domain_name` | AD domain FQDN | `string` | `""` | Conditional |
| `ad_domain_guid` | AD domain GUID | `string` | `""` | Conditional |
| `ad_domain_sid` | AD domain SID | `string` | `""` | Conditional |
| `ad_forest_name` | AD forest name | `string` | `""` | No |
| `ad_netbios_domain_name` | AD NetBIOS name | `string` | `""` | Conditional |
| `enable_diagnostics` | Enable Log Analytics diagnostics | `bool` | `true` | No |
| `log_analytics_workspace_id` | Log Analytics workspace ID | `string` | `""` | Conditional |
| `session_host_principal_ids` | Session host identity principal IDs | `list(string)` | `[]` | No |
| `avd_users_group_id` | AVD users group object ID | `string` | `""` | No |
| `additional_contributor_principal_ids` | Additional principal IDs | `list(string)` | `[]` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: gallery_image_definition (28 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `gallery_name` | Azure Compute Gallery name | `string` | `""` | Conditional* |
| `gallery_resource_group_name` | Gallery resource group name | `string` | `""` | Conditional* |
| `gallery_id` | Gallery resource ID | `string` | `null` | Conditional** |
| `image_definition_name` | Image definition name (1-80 chars) | `string` | - | Yes |
| `image_definition_description` | Image description | `string` | `""` | No |
| `location` | Azure region | `string` | - | Yes |
| `os_type` | Operating system: Windows or Linux | `string` | `"Windows"` | No |
| `os_state` | OS state: Generalized or Specialized | `string` | `"Generalized"` | No |
| `hyper_v_generation` | Hyper-V generation: V1 or V2 | `string` | `"V2"` | No |
| `publisher` | Publisher name | `string` | `"MyCompany"` | No |
| `offer` | Offer name | `string` | `"Windows-CustomImage"` | No |
| `sku` | SKU identifier | `string` | `"custom"` | No |
| `eula` | End-User License Agreement | `string` | `""` | No |
| `privacy_statement_uri` | Privacy statement URI | `string` | `""` | No |
| `release_note_uri` | Release notes URI | `string` | `""` | No |
| `end_of_life_date` | End-of-life date (ISO 8601) | `string` | `null` | No |
| `specialized` | (DEPRECATED) Use os_state instead | `bool` | `null` | No |
| `trusted_launch_enabled` | Enable Trusted Launch (Gen2 only) | `bool` | `false` | No |
| `trusted_launch_supported` | Trusted Launch supported | `bool` | `false` | No |
| `accelerated_network_supported` | Accelerated networking support | `bool` | `true` | No |
| `architecture` | CPU architecture: x64 or Arm64 | `string` | `"x64"` | No |
| `disk_types_not_allowed` | Restricted disk types | `list(string)` | `[]` | No |
| `max_recommended_vcpu_count` | Maximum recommended vCPUs | `number` | `null` | No |
| `min_recommended_vcpu_count` | Minimum recommended vCPUs | `number` | `null` | No |
| `max_recommended_memory_in_gb` | Maximum recommended memory (GB) | `number` | `null` | No |
| `min_recommended_memory_in_gb` | Minimum recommended memory (GB) | `number` | `null` | No |
| `tags` | Tags to apply to resource | `map(string)` | `{}` | No |

\* Required when `gallery_id` is not provided  
\*\* Required when `gallery_name` is not provided

---

## Module: golden_image (31 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `gallery_name` | Azure Compute Gallery name | `string` | - | Yes |
| `image_definition_name` | Image definition name | `string` | - | Yes |
| `image_template_name` | Image Builder template name | `string` | - | Yes |
| `image_version` | Semantic version (e.g., 1.0.0) | `string` | `"1.0.0"` | No |
| `base_image_publisher` | Marketplace image publisher | `string` | `"MicrosoftWindowsDesktop"` | No |
| `base_image_offer` | Marketplace image offer | `string` | `"office-365"` | No |
| `base_image_sku` | Marketplace image SKU | `string` | `"win11-22h2-avd-m365"` | No |
| `base_image_version` | Marketplace image version | `string` | `"latest"` | No |
| `image_publisher` | Custom image publisher name | `string` | `"MyCompany"` | No |
| `image_offer` | Custom image offer name | `string` | `"AVD-GoldenImage"` | No |
| `image_sku` | Custom image SKU name | `string` | `"Win11-M365-Custom"` | No |
| `hyper_v_generation` | Hyper-V generation: V1 or V2 | `string` | `"V2"` | No |
| `install_windows_updates` | Install latest Windows updates | `bool` | `true` | No |
| `powershell_modules` | PowerShell modules to install | `list(string)` | `[]` | No |
| `inline_scripts` | Map of inline PowerShell scripts | `map(list(string))` | `{}` | No |
| `script_uris` | Map of script URIs to execute | `map(string)` | `{}` | No |
| `chocolatey_packages` | Chocolatey packages to install | `list(string)` | `[]` | No |
| `restart_after_customization` | Restart after customizations | `bool` | `false` | No |
| `run_cleanup_script` | Run cleanup script | `bool` | `true` | No |
| `build_vm_size` | VM size for build VM | `string` | `"Standard_D4s_v5"` | No |
| `build_timeout_minutes` | Maximum build time (60-960 minutes) | `number` | `240` | No |
| `replication_regions` | Regions to replicate image to | `list(string)` | `[]` | No |
| `gallery_image_storage_account_type` | Storage type for replicas | `string` | `"Standard_LRS"` | No |
| `exclude_from_latest` | Exclude from 'latest' queries | `bool` | `false` | No |
| `enabled` | Enable golden image deployment | `bool` | `true` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: key_vault (13 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `key_vault_name` | Key Vault name (3-24 chars) | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `auto_generate_passwords` | Auto-generate secure passwords | `bool` | `true` | No |
| `domain_admin_password` | Domain admin password (if not auto-gen) | `string` (sensitive) | `""` | Conditional |
| `local_admin_password` | Local admin password (if not auto-gen) | `string` (sensitive) | `""` | Conditional |
| `domain_admin_password_secret_name` | Domain admin secret name | `string` | `"domain-admin-password"` | No |
| `local_admin_password_secret_name` | Local admin secret name | `string` | `"local-admin-password"` | No |
| `purge_protection_enabled` | Enable purge protection | `bool` | `false` | No |
| `public_network_access_enabled` | Allow public network access | `bool` | `true` | No |
| `network_default_action` | Firewall default action: Allow or Deny | `string` | `"Allow"` | No |
| `allowed_ip_ranges` | Allowed IP ranges (CIDR notation) | `list(string)` | `[]` | No |
| `additional_secrets` | Additional secrets to store | `map(string)` (sensitive) | `{}` | No |
| `enabled` | Enable Key Vault deployment | `bool` | `true` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: logging (13 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `log_analytics_workspace_name` | Workspace name | `string` | - | Yes |
| `log_analytics_sku` | Pricing SKU | `string` | `"PerGB2018"` | No |
| `log_analytics_retention_days` | Log retention (7-730 days) | `number` | `30` | No |
| `avd_workspace_id` | AVD workspace resource ID | `string` | `null` | No |
| `avd_hostpool_id` | AVD host pool resource ID | `string` | `null` | No |
| `avd_app_group_ids` | Map of app group IDs | `map(string)` | `{}` | No |
| `storage_account_id` | Storage account resource ID | `string` | `null` | No |
| `nsg_ids` | Map of NSG resource IDs | `map(string)` | `{}` | No |
| `enable_vm_insights` | Enable VM Insights | `bool` | `true` | No |
| `dc_vm_id` | Domain Controller VM ID | `string` | `null` | No |
| `session_host_vm_ids` | Map of session host VM IDs | `map(string)` | `{}` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: manual_gallery_import (17 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `gallery_name` | EXISTING gallery name | `string` | - | Yes |
| `image_definition_name` | EXISTING image definition name | `string` | - | Yes |
| `source_type` | Source type: managed_image or vhd | `string` | - | Yes |
| `managed_image_id` | Managed image resource ID | `string` | `null` | Conditional* |
| `source_vhd_uri` | VHD file URI in Azure Storage | `string` | `null` | Conditional** |
| `vhd_managed_image_name` | Name for intermediate managed image | `string` | `""` | No |
| `os_type` | OS type: Windows or Linux | `string` | `"Windows"` | No |
| `hyper_v_generation` | Hyper-V generation: V1 or V2 | `string` | `"V2"` | No |
| `image_version` | Semantic version (e.g., 1.0.0) | `string` | - | Yes |
| `exclude_from_latest` | Exclude from 'latest' queries | `bool` | `true` | No |
| `replication_regions` | Additional regions to replicate to | `list(string)` | `[]` | No |
| `replica_count` | Number of replicas per region (1-10) | `number` | `1` | No |
| `storage_account_type` | Storage type for replicas | `string` | `"Standard_LRS"` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

\* Required when `source_type = "managed_image"`  
\*\* Required when `source_type = "vhd"`

---

## Module: manual_image_import (27 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `import_enabled` | Enable manual image import | `bool` | `false` | No |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `create_gallery` | Create new gallery or use existing | `bool` | `true` | No |
| `gallery_name` | Gallery name (1-80 chars) | `string` | - | Yes |
| `gallery_description` | Gallery description | `string` | `"Gallery for manually imported AVD images"` | No |
| `existing_gallery_id` | Existing gallery resource ID | `string` | `null` | Conditional* |
| `image_definition_name` | Image definition name (1-80 chars) | `string` | - | Yes |
| `image_definition_description` | Image definition description | `string` | `"Manually imported custom AVD image"` | No |
| `image_publisher` | Publisher name | `string` | `"MyCompany"` | No |
| `image_offer` | Offer name | `string` | `"Windows-AVD-Custom"` | No |
| `image_sku` | SKU name | `string` | `"custom"` | No |
| `os_type` | OS type: Windows or Linux | `string` | `"Windows"` | No |
| `hyper_v_generation` | Hyper-V generation: V1 or V2 | `string` | `"V2"` | No |
| `os_state` | OS state: Generalized or Specialized | `string` | `"Generalized"` | No |
| `source_type` | Source type: managed_image or vhd | `string` | - | Yes |
| `managed_image_id` | Managed image resource ID | `string` | `null` | Conditional** |
| `source_vhd_uri` | VHD file URI | `string` | `null` | Conditional*** |
| `vhd_managed_image_name` | Intermediate managed image name | `string` | `""` | No |
| `image_version` | Semantic version (e.g., 1.0.0) | `string` | - | Yes |
| `exclude_from_latest` | Exclude from 'latest' queries | `bool` | `false` | No |
| `replication_regions` | Additional regions to replicate to | `list(string)` | `[]` | No |
| `replica_count` | Replicas per region (1-3) | `number` | `1` | No |
| `storage_account_type` | Storage type for replicas | `string` | `"Standard_LRS"` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

\* Required when `create_gallery = false`  
\*\* Required when `source_type = "managed_image"`  
\*\*\* Required when `source_type = "vhd"`

---

## Module: networking (11 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `create_resource_group` | Create new resource group | `bool` | `false` | No |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `vnet_name` | Virtual network name | `string` | - | Yes |
| `vnet_address_space` | VNet address space (CIDR) | `string` | `"10.0.0.0/16"` | No |
| `dc_subnet_name` | Domain Controller subnet name | `string` | `"snet-dc"` | No |
| `dc_subnet_prefix` | DC subnet prefix (CIDR) | `string` | `"10.0.1.0/24"` | No |
| `avd_subnet_name` | AVD session hosts subnet name | `string` | `"snet-avd"` | No |
| `avd_subnet_prefix` | AVD subnet prefix (CIDR) | `string` | `"10.0.2.0/24"` | No |
| `storage_subnet_name` | Storage subnet name | `string` | `"snet-storage"` | No |
| `storage_subnet_prefix` | Storage subnet prefix (CIDR) | `string` | `"10.0.3.0/24"` | No |
| `dns_servers` | List of DNS server IPs | `list(string)` | `[]` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: scaling_plan (51 variables)

### Core Configuration (6 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enabled` | Enable AVD auto-scaling | `bool` | `true` | No |
| `scaling_plan_name` | Scaling plan name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `friendly_name` | Friendly name for display | `string` | `""` | No |
| `description` | Scaling plan description | `string` | (see defaults) | No |
| `timezone` | Timezone for schedules | `string` | `"GMT Standard Time"` | No |
| `host_pool_ids` | List of host pool IDs | `list(string)` | - | Yes |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

### Weekday Schedule Variables (10 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `weekday_ramp_up_start_time` | Ramp-up start time (HH:MM) | `string` | `"07:00"` | No |
| `weekday_ramp_up_min_hosts_percent` | Minimum hosts % during ramp-up | `number` | `20` | No |
| `weekday_ramp_up_capacity_threshold_percent` | Capacity threshold for scaling | `number` | `60` | No |
| `weekday_peak_start_time` | Peak hours start time (HH:MM) | `string` | `"09:00"` | No |
| `weekday_ramp_down_start_time` | Ramp-down start time (HH:MM) | `string` | `"17:00"` | No |
| `weekday_ramp_down_min_hosts_percent` | Minimum hosts % during ramp-down | `number` | `10` | No |
| `weekday_ramp_down_capacity_threshold_percent` | Capacity threshold for scale-down | `number` | `90` | No |
| `weekday_off_peak_start_time` | Off-peak start time (HH:MM) | `string` | `"19:00"` | No |

### Weekend Schedule Variables (11 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enable_weekend_schedule` | Enable separate weekend schedule | `bool` | `true` | No |
| `weekend_ramp_up_start_time` | Weekend ramp-up start (HH:MM) | `string` | `"10:00"` | No |
| `weekend_ramp_up_min_hosts_percent` | Min hosts % weekend ramp-up | `number` | `10` | No |
| `weekend_ramp_up_capacity_threshold_percent` | Weekend capacity threshold | `number` | `80` | No |
| `weekend_peak_start_time` | Weekend peak start (HH:MM) | `string` | `"12:00"` | No |
| `weekend_ramp_down_start_time` | Weekend ramp-down start (HH:MM) | `string` | `"16:00"` | No |
| `weekend_ramp_down_min_hosts_percent` | Min hosts % weekend ramp-down | `number` | `0` | No |
| `weekend_ramp_down_capacity_threshold_percent` | Weekend scale-down threshold | `number` | `90` | No |
| `weekend_off_peak_start_time` | Weekend off-peak start (HH:MM) | `string` | `"18:00"` | No |

### Load Balancing Variables (4 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `ramp_up_load_balancing_algorithm` | Ramp-up algorithm: BreadthFirst or DepthFirst | `string` | `"BreadthFirst"` | No |
| `peak_load_balancing_algorithm` | Peak hours algorithm | `string` | `"DepthFirst"` | No |
| `ramp_down_load_balancing_algorithm` | Ramp-down algorithm | `string` | `"DepthFirst"` | No |
| `off_peak_load_balancing_algorithm` | Off-peak algorithm | `string` | `"DepthFirst"` | No |

### Ramp-Down Behavior Variables (4 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `ramp_down_force_logoff_users` | Force logoff after wait time | `bool` | `false` | No |
| `ramp_down_wait_time_minutes` | Wait time before force logoff (0-480 min) | `number` | `30` | No |
| `ramp_down_notification_message` | Message to users before logoff | `string` | `"You will be logged off in 30 minutes. Please save your work."` | No |
| `ramp_down_stop_hosts_when` | When to stop: ZeroSessions or ZeroActiveSessions | `string` | `"ZeroSessions"` | No |

### Monitoring Alert Variables (8 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enable_monitoring_alerts` | Enable Azure Monitor alerts | `bool` | `false` | No |
| `log_analytics_workspace_id` | Log Analytics workspace ID | `string` | `null` | Conditional |
| `alert_emails` | Email addresses for alerts | `list(string)` | `[]` | No |
| `high_cpu_threshold_percent` | CPU threshold for under-scaling (50-100%) | `number` | `85` | No |
| `high_memory_threshold_percent` | Memory threshold for under-scaling (50-100%) | `number` | `85` | No |
| `min_hosts_for_alert` | Min hosts exceeding threshold (1-10) | `number` | `2` | No |
| `max_off_peak_hosts` | Max hosts expected off-peak (0-50) | `number` | `2` | No |
| `enable_scaling_stuck_alert` | Enable stuck scaling diagnostic | `bool` | `false` | No |

---

## Module: session-hosts (26 variables)

### VM Configuration Variables (7 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `vm_count` | Number of session host VMs (1-100) | `number` | `2` | No |
| `vm_name_prefix` | Prefix for VM names | `string` | `"avd-sh"` | No |
| `vm_size` | VM SKU | `string` | `"Standard_D2s_v5"` | No |
| `timezone` | Timezone for VMs | `string` | `"UTC"` | No |
| `os_disk_type` | OS disk type | `string` | `"Premium_LRS"` | No |
| `os_disk_size_gb` | OS disk size in GB | `number` | `null` | No |

### Image Source Variables (9 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `gallery_image_version_id` | Azure Compute Gallery image version ID | `string` | `null` | No |
| `marketplace_image_reference` | Marketplace image reference object | `object` | (Win11 defaults) | No |
| `managed_image_id` | Managed Image resource ID | `string` | `null` | No |
| `use_golden_image` | (DEPRECATED) Use session_host_image_source | `bool` | `false` | No |
| `image_publisher` | (DEPRECATED) Use marketplace_image_reference | `string` | `"MicrosoftWindowsDesktop"` | No |
| `image_offer` | (DEPRECATED) Use marketplace_image_reference | `string` | `"windows-11"` | No |
| `image_sku` | (DEPRECATED) Use marketplace_image_reference | `string` | `"win11-22h2-avd"` | No |
| `image_version` | (DEPRECATED) Use marketplace_image_reference | `string` | `"latest"` | No |

### Credentials Variables (2 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `local_admin_username` | Local administrator username | `string` | - | Yes |
| `local_admin_password` | Local administrator password (sensitive) | `string` | - | Yes |

### Domain Join Variables (5 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `domain_name` | Fully qualified domain name | `string` | - | Yes |
| `domain_netbios_name` | NetBIOS domain name | `string` | - | Yes |
| `domain_admin_username` | Domain admin username | `string` | - | Yes |
| `domain_admin_password` | Domain admin password (sensitive) | `string` | - | Yes |
| `domain_ou_path` | OU Distinguished Name | `string` | `""` | No |

### AVD Configuration Variables (2 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `hostpool_name` | AVD host pool name | `string` | - | Yes |
| `hostpool_registration_token` | Registration token (sensitive) | `string` | - | Yes |

### FSLogix Variables (1 variable)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `fslogix_share_path` | UNC path to FSLogix share | `string` | - | Yes |

### Azure Resources Variables (4 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `subnet_id` | Subnet ID for deployment | `string` | - | Yes |
| `vnet_dns_servers` | List of DNS server IPs | `list(string)` | `[]` | No |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: storage (7 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `storage_account_name` | Storage account name (3-24 chars) | `string` | - | Yes |
| `share_name` | Azure Files share name | `string` | `"user-profiles"` | No |
| `share_quota_gb` | Share quota size in GB | `number` | `100` | No |
| `subnet_id` | Subnet ID for private endpoint | `string` | - | Yes |
| `vnet_id` | Virtual network ID for DNS zone link | `string` | - | Yes |
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Module: update_management (25 variables)

### Required Variables (3 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `maintenance_config_name_prefix` | Prefix for maintenance config names | `string` | - | Yes |

### Domain Controller Maintenance Variables (5 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `dc_maintenance_start_datetime` | DC window start (RFC3339 format) | `string` | - | Yes |
| `dc_maintenance_duration` | DC window duration (HH:MM, 01:30-06:00) | `string` | `"03:00"` | No |
| `dc_maintenance_recurrence` | DC recurrence pattern | `string` | `"1Month"` | No |
| `dc_reboot_setting` | DC reboot behavior | `string` | `"IfRequired"` | No |
| `dc_patch_classifications` | DC patch classifications | `list(string)` | (see defaults) | No |

### Session Host Maintenance Variables (5 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `session_host_maintenance_start_datetime` | Session host window start (RFC3339) | `string` | - | Yes |
| `session_host_maintenance_duration` | Session host window duration (HH:MM) | `string` | `"04:00"` | No |
| `session_host_maintenance_recurrence` | Session host recurrence pattern | `string` | `"1Week"` | No |
| `session_host_reboot_setting` | Session host reboot behavior | `string` | `"IfRequired"` | No |
| `session_host_patch_classifications` | Session host patch classifications | `list(string)` | (see defaults) | No |

### Shared Maintenance Settings (5 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `maintenance_timezone` | Timezone for maintenance windows | `string` | `"UTC"` | No |
| `maintenance_expiration_datetime` | Expiration date/time (RFC3339) | `string` | `null` | No |
| `kb_numbers_to_exclude` | KB articles to exclude | `list(string)` | `[]` | No |
| `kb_numbers_to_include` | Specific KB articles to include | `list(string)` | `[]` | No |

### Emergency Patching Variables (2 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enable_emergency_patching` | Create emergency maintenance config | `bool` | `false` | No |
| `emergency_maintenance_start_datetime` | Emergency window start (RFC3339) | `string` | `"2026-01-01T00:00:00+00:00"` | No |

### VM Resource IDs (2 variables)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `dc_vm_id` | Domain Controller VM resource ID | `string` | `null` | No |
| `session_host_vm_ids` | Map of session host VM IDs | `map(string)` | `{}` | No |

### Tags (1 variable)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `tags` | Tags to apply to resources | `map(string)` | `{}` | No |

---

## Summary Statistics

| Module | Total Variables | Required | Optional | Conditional |
|--------|----------------|----------|----------|-------------|
| avd_core | 17 | 3 | 14 | 0 |
| backup | 25 | 3 | 20 | 2 |
| compute_gallery | 7 | 1 | 4 | 2 |
| conditional_access | 52 | 2 | 49 | 1 |
| cost_management | 16 | 3 | 10 | 3 |
| domain-controller | 15 | 8 | 7 | 0 |
| fslogix_storage | 25 | 3 | 18 | 4 |
| gallery_image_definition | 28 | 2 | 24 | 2 |
| golden_image | 31 | 5 | 26 | 0 |
| key_vault | 13 | 3 | 8 | 2 |
| logging | 13 | 3 | 10 | 0 |
| manual_gallery_import | 17 | 5 | 10 | 2 |
| manual_image_import | 27 | 5 | 19 | 3 |
| networking | 11 | 4 | 7 | 0 |
| scaling_plan | 51 | 5 | 45 | 1 |
| session-hosts | 26 | 13 | 13 | 0 |
| storage | 7 | 5 | 2 | 0 |
| update_management | 25 | 5 | 20 | 0 |
| **TOTAL** | **406** | **78** | **306** | **22** |

---

## Notes

- **Required**: Variables that must be explicitly set by the user
- **Optional**: Variables with default values that can be overridden
- **Conditional**: Variables required only in specific configurations (e.g., when another variable is set to a specific value)

All variables are documented with:
- Full descriptions
- Data types
- Default values (where applicable)
- Required/Optional status
- Validation rules (where applicable)
- Sensitive markers for passwords and secrets
