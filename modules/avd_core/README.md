# AVD Core Module

Simplified module for deploying Azure Virtual Desktop core infrastructure including workspace, host pool, desktop application group, and user access assignments.

## Features

- **AVD Workspace** - User access portal
- **Pooled Host Pool** - Shared session host pool with configurable load balancing
- **Desktop Application Group** - Full desktop access for users
- **Automatic Association** - Workspace and app group linked automatically
- **User Access Management** - Role assignment for Azure AD groups
- **Registration Token** - Automatic generation with configurable TTL
- **Start VM on Connect** - Optional cost-saving feature

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ AVD Workspace                                       │
│ - User access portal                                │
│ - https://client.wvd.microsoft.com/                 │
└─────────────────┬───────────────────────────────────┘
                  │
                  │ Association
                  ▼
┌─────────────────────────────────────────────────────┐
│ Desktop Application Group                           │
│ - Type: Desktop                                     │
│ - Users: Azure AD Group (via RBAC)                 │
└─────────────────┬───────────────────────────────────┘
                  │
                  │ Linked to
                  ▼
┌─────────────────────────────────────────────────────┐
│ Host Pool (Pooled)                                  │
│ - Load Balancing: BreadthFirst/DepthFirst          │
│ - Max Sessions: Configurable                       │
│ - Start VM on Connect: Optional                    │
│ - Registration Token: 48h TTL (configurable)       │
└─────────────────────────────────────────────────────┘
```

## Usage

### Basic Example

```hcl
module "avd_core" {
  source = "../../modules/avd_core"

  # Core Configuration
  prefix              = "avd"
  env                 = "dev"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.rg.name

  # Host Pool Configuration
  host_pool_name      = ""  # Auto-generated: avd-dev-hp
  max_sessions        = 10
  load_balancer_type  = "BreadthFirst"
  start_vm_on_connect = true

  # User Access
  user_group_object_id = azuread_group.avd_users.object_id

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
```

### Complete Example with Custom Names

```hcl
# Get Azure AD group for AVD users
data "azuread_group" "avd_users" {
  display_name = "AVD-Users"
}

module "avd_core" {
  source = "../../modules/avd_core"

  # Core Configuration
  prefix              = "company"
  env                 = "prod"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.rg.name

  # Host Pool Configuration
  host_pool_name             = "company-prod-hostpool"
  max_sessions               = 15
  load_balancer_type         = "DepthFirst"
  start_vm_on_connect        = true
  enable_scheduled_agent_updates = true

  # User Access
  user_group_object_id = data.azuread_group.avd_users.object_id

  # Registration Token
  registration_token_ttl_hours = "720h"  # 30 days

  # Friendly Names
  workspace_friendly_name    = "Company Production Workspace"
  host_pool_friendly_name    = "Production Host Pool"
  app_group_friendly_name    = "Production Desktop"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
    CostCenter  = "IT"
  }
}

# Use the registration token for session hosts
output "registration_token" {
  value     = module.avd_core.registration_token
  sensitive = true
}
```

### Using with Session Hosts

```hcl
module "avd_core" {
  source = "../../modules/avd_core"
  # ... configuration
}

module "session_hosts" {
  source = "../../modules/session-hosts"
  
  # Use outputs from avd_core
  hostpool_name               = module.avd_core.host_pool_name
  hostpool_registration_token = module.avd_core.registration_token
  
  # ... other session host configuration
  
  depends_on = [module.avd_core]
}
```

## Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `prefix` | Naming prefix for AVD resources (e.g., 'avd', 'vdi') | `string` | `"avd"` | No |
| `env` | Environment name (e.g., 'dev', 'prod', 'staging') | `string` | - | Yes |
| `location` | Azure region for AVD resources | `string` | - | Yes |
| `resource_group_name` | Name of the resource group for AVD resources | `string` | - | Yes |
| `host_pool_name` | Name of the host pool (leave empty for auto-generated name based on prefix-env-hp) | `string` | `""` | No |
| `max_sessions` | Maximum number of concurrent sessions per session host | `number` | `10` | No |
| `load_balancer_type` | Load balancing algorithm: 'BreadthFirst' (spread users) or 'DepthFirst' (fill hosts) | `string` | `"BreadthFirst"` | No |
| `start_vm_on_connect` | Enable Start VM on Connect feature (requires Azure Power Management permissions) | `bool` | `true` | No |
| `custom_rdp_properties` | Custom RDP properties for the host pool | `string` | `"audiocapturemode:i:1;audiomode:i:0;drivestoredirect:s:;redirectclipboard:i:1;redirectcomports:i:0;redirectprinters:i:1;redirectsmartcards:i:1;screen mode id:i:2"` | No |
| `user_group_object_id` | Azure AD group object ID for AVD users (leave empty to skip role assignment) | `string` | `""` | No |
| `registration_token_ttl_hours` | Registration token time-to-live in hours (e.g., '48h', '720h') | `string` | `"48h"` | No |
| `workspace_friendly_name` | Display name for the AVD workspace | `string` | `"AVD Workspace"` | No |
| `workspace_description` | Description for the AVD workspace | `string` | `"Azure Virtual Desktop Workspace"` | No |
| `host_pool_friendly_name` | Display name for the AVD host pool | `string` | `"AVD Host Pool"` | No |
| `host_pool_description` | Description for the AVD host pool | `string` | `"Azure Virtual Desktop Host Pool"` | No |
| `app_group_friendly_name` | Display name for the desktop application group | `string` | `"Desktop"` | No |
| `app_group_description` | Description for the desktop application group | `string` | `"Desktop Application Group"` | No |
| `enable_scheduled_agent_updates` | Enable scheduled agent updates (updates on Sundays at 2 AM) | `bool` | `false` | No |
| `tags` | Tags to apply to all AVD resources | `map(string)` | `{}` | No |

### Core Variables

| Name | Description | Type | Default |  
|------|-------------|------|---------|
| `prefix` | Naming prefix | `string` | `"avd"` |
| `host_pool_name` | Host pool name (auto-generated if empty) | `string` | `""` |
| `max_sessions` | Max concurrent sessions per host | `number` | `10` |
| `load_balancer_type` | BreadthFirst or DepthFirst | `string` | `"BreadthFirst"` |
| `start_vm_on_connect` | Enable Start VM on Connect | `bool` | `true` |
| `user_group_object_id` | Azure AD group object ID | `string` | `""` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `registration_token_ttl_hours` | Token TTL (e.g., "48h", "720h") | `string` | `"48h"` |
| `workspace_friendly_name` | Workspace display name | `string` | `"AVD Workspace"` |
| `host_pool_friendly_name` | Host pool display name | `string` | `"AVD Host Pool"` |
| `app_group_friendly_name` | App group display name | `string` | `"Desktop"` |
| `enable_scheduled_agent_updates` | Schedule updates Sunday 2 AM | `bool` | `false` |
| `custom_rdp_properties` | Custom RDP properties | `string` | See default |
| `tags` | Resource tags | `map(string)` | `{}` |

## Outputs

| Name | Description |
|------|-------------|
| `workspace_id` | AVD workspace resource ID |
| `workspace_name` | AVD workspace name |
| `host_pool_id` | AVD host pool resource ID |
| `host_pool_name` | AVD host pool name |
| `app_group_id` | Desktop app group resource ID |
| `app_group_name` | Desktop app group name |
| `registration_token` | Host pool registration token (sensitive) |
| `registration_token_expiration` | Token expiration date/time |
| `registration_token_ttl` | Token TTL configuration |
| `connection_info` | User connection information |

## Load Balancer Types

### BreadthFirst (Default)
Distributes new user sessions evenly across all available session hosts. Best for:
- Development and testing
- Ensuring all VMs are utilized
- Even resource distribution

### DepthFirst
Fills up each session host to max capacity before moving to the next. Best for:
- Production environments
- Cost optimization (allows shutting down underutilized VMs)
- Maximizing VM utilization

## Start VM on Connect

When enabled, automatically starts deallocated VMs when users connect. 

**Benefits:**
- Significant cost savings (only pay for running VMs)
- Automatic scaling based on demand

**Requirements:**
- Azure subscription with proper permissions
- Session hosts must support Start VM on Connect
- May have startup delay for users

**Cost Example:**
- 5 session hosts running 24/7: ~$700/month
- 5 session hosts with Start VM on Connect (8 hours/day): ~$235/month
- **Savings: ~66%**

## Registration Token

The registration token is required for session hosts to join the host pool.

**TTL Configuration:**
- Default: 48 hours
- Minimum: 1 hour
- Maximum: 30 days (720 hours)
- Format: "24h", "48h", "168h", "720h"

**Best Practices:**
- Development: 48-72 hours
- Production: 2-4 hours (generate fresh token for each deployment)
- Never store tokens in source control

**Regenerating Token:**
```bash
# Token automatically regenerates on each Terraform apply
terraform apply

# View token (sensitive output)
terraform output -raw registration_token
```

## User Access Management

### Using Azure AD Group (Recommended)

```hcl
# Get existing Azure AD group
data "azuread_group" "avd_users" {
  display_name = "AVD-Users"
}

module "avd_core" {
  source = "../../modules/avd_core"
  # ...
  user_group_object_id = data.azuread_group.avd_users.object_id
}
```

### Creating New Azure AD Group

```hcl
resource "azuread_group" "avd_users" {
  display_name     = "AVD-Users-${var.env}"
  security_enabled = true
  description      = "Users with access to AVD ${var.env} environment"
}

module "avd_core" {
  source = "../../modules/avd_core"
  # ...
  user_group_object_id = azuread_group.avd_users.object_id
}
```

### Adding Users to Group

```bash
# Add user to AVD group
az ad group member add \
  --group "AVD-Users" \
  --member-id <user-object-id>

# List group members
az ad group member list \
  --group "AVD-Users" \
  --output table
```

## Monitoring and Management

### View Host Pool Status

```bash
# List host pools
az desktopvirtualization hostpool list \
  --resource-group <rg-name> \
  --output table

# Show host pool details
az desktopvirtualization hostpool show \
  --name <hostpool-name> \
  --resource-group <rg-name>

# List session hosts
az desktopvirtualization sessionhost list \
  --host-pool-name <hostpool-name> \
  --resource-group <rg-name> \
  --output table
```

### Monitor User Sessions

```bash
# List active sessions
az desktopvirtualization usersession list \
  --host-pool-name <hostpool-name> \
  --resource-group <rg-name> \
  --output table
```

## Custom RDP Properties

Default RDP properties provide a balanced experience:

```
audiocapturemode:i:1          # Enable audio capture (microphone)
audiomode:i:0                 # Play sounds on local computer
drivestoredirect:s:           # No drive redirection
redirectclipboard:i:1         # Enable clipboard redirection
redirectcomports:i:0          # Disable COM port redirection
redirectprinters:i:1          # Enable printer redirection
redirectsmartcards:i:1        # Enable smart card redirection
screen mode id:i:2            # Full screen mode
```

### Custom Examples

**Minimal Resources:**
```hcl
custom_rdp_properties = "audiocapturemode:i:0;audiomode:i:0;redirectclipboard:i:0;redirectprinters:i:0"
```

**High Performance:**
```hcl
custom_rdp_properties = "audiocapturemode:i:1;audiomode:i:0;redirectclipboard:i:1;redirectprinters:i:1;screen mode id:i:2;use multimon:i:1;maximizetocurrentdisplays:i:1"
```

## Troubleshooting

### Users Cannot Connect

1. **Check user group membership:**
   ```bash
   az ad group member list --group "AVD-Users"
   ```

2. **Verify role assignment:**
   ```bash
   az role assignment list --scope <app-group-id>
   ```

3. **Check session host registration:**
   ```bash
   az desktopvirtualization sessionhost list \
     --host-pool-name <hostpool-name> \
     --resource-group <rg-name>
   ```

### Registration Token Expired

```hcl
# Regenerate by applying Terraform
terraform apply

# Or update TTL and apply
registration_token_ttl_hours = "72h"
```

### Start VM on Connect Not Working

1. Check Azure permissions (requires Power Management)
2. Verify session hosts are properly deallocated
3. Check host pool configuration
4. Review Azure Activity Log for errors

## Best Practices

### Development
- Use BreadthFirst load balancing
- Enable Start VM on Connect for cost savings
- Short token TTL (48 hours)
- Single session host for testing

### Production
- Use DepthFirst load balancing
- Consider Start VM on Connect for cost optimization
- Short token TTL (2-4 hours)
- Multiple session hosts for redundancy
- Enable scheduled agent updates
- Use Azure Monitor for observability

## License

Part of the Azure Virtual Desktop Terraform Playbook.
