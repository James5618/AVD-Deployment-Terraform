# Scaling Plan Module

Automatically scales Azure Virtual Desktop session hosts based on time-of-day schedules and user demand, reducing costs.

## Features

- **Time-Based Scaling**: 4 phases per day (ramp-up, peak, ramp-down, off-peak)
- **Weekday/Weekend Schedules**: Separate schedules for business days and weekends
- **Cost Optimization**: Automatically deallocates idle session hosts during off-peak hours
- **User-Friendly Configuration**: Simple time format (HH:MM) and percentage-based thresholds
- **Flexible Load Balancing**: BreadthFirst (spread users) or DepthFirst (consolidate users)
- **Graceful Shutdown**: Optional user notifications and wait times before forced logoff
- **Multi-Host Pool Support**: Single scaling plan can manage multiple host pools

## Quick Start

### Basic Configuration (Weekday 9-5 business hours)

```hcl
module "scaling_plan" {
  source = "../../modules/scaling_plan"
  
  scaling_plan_name   = "avd-scaling-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus"
  timezone            = "GMT Standard Time"  # Europe/London
  
  # Associate with AVD host pool
  host_pool_ids = [module.avd_core.host_pool_id]
  
  # Weekday schedule (Monday-Friday)
  weekday_ramp_up_start_time   = "07:00"  # 7 AM - start scaling up
  weekday_peak_start_time      = "09:00"  # 9 AM - business hours begin
  weekday_ramp_down_start_time = "17:00"  # 5 PM - business hours end
  weekday_off_peak_start_time  = "19:00"  # 7 PM - minimal capacity
  
  # Capacity settings
  weekday_ramp_up_min_hosts_percent           = 20  # Keep 20% online during ramp-up
  weekday_ramp_up_capacity_threshold_percent  = 60  # Scale when >60% utilized
  weekday_ramp_down_min_hosts_percent         = 10  # Keep 10% for late workers
  weekday_ramp_down_capacity_threshold_percent = 90  # Scale down when <90% utilized
  
  # Weekend schedule (optional)
  enable_weekend_schedule = true
}
```

### Production Configuration with User Notifications

```hcl
module "scaling_plan" {
  source = "../../modules/scaling_plan"
  
  scaling_plan_name   = "avd-prod-scaling-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "eastus"
  timezone            = "Eastern Standard Time"  # US East Coast
  
  host_pool_ids = [module.avd_core.host_pool_id]
  
  # Weekday schedule optimized for 8 AM - 6 PM business hours
  weekday_ramp_up_start_time   = "07:00"  # Start scaling 1 hour before users arrive
  weekday_peak_start_time      = "08:00"  # Peak hours 8 AM - 6 PM
  weekday_ramp_down_start_time = "18:00"  # Start wind-down after 6 PM
  weekday_off_peak_start_time  = "20:00"  # Minimal capacity after 8 PM
  
  # Aggressive scaling during business hours
  weekday_ramp_up_min_hosts_percent           = 25  # Always keep 25% online
  weekday_ramp_up_capacity_threshold_percent  = 50  # Scale aggressively (>50%)
  weekday_ramp_down_min_hosts_percent         = 15  # Keep 15% for late workers
  weekday_ramp_down_capacity_threshold_percent = 90  # Conservative ramp-down
  
  # User session management
  ramp_down_force_logoff_users    = true
  ramp_down_wait_time_minutes     = 60  # 1 hour grace period
  ramp_down_notification_message  = "System maintenance in 60 minutes. Please save your work and log off."
  ramp_down_stop_hosts_when       = "ZeroSessions"
  
  # Load balancing: DepthFirst to consolidate users for efficient scaling
  peak_load_balancing_algorithm     = "DepthFirst"
  ramp_down_load_balancing_algorithm = "DepthFirst"
  
  # Weekend: minimal capacity (for global teams or on-call staff)
  enable_weekend_schedule                      = true
  weekend_ramp_up_min_hosts_percent            = 10  # Keep 10% online
  weekend_ramp_up_capacity_threshold_percent   = 80  # Slower scaling on weekends
}
```

## Scaling Schedule Phases

### Phase 1: Ramp-Up (Morning Startup)

**Purpose:** Gradually start session hosts before users arrive

| **Ramp-Up Phase** | **Details** |
|-------------------|-------------|
| **Time** | 7:00 AM - 9:00 AM |
| **Behavior** | - Start session hosts proactively<br>- Maintain minimum 20% capacity<br>- Scale when load exceeds 60%<br>- BreadthFirst load balancing (spread users) |
| **Example** | **10 total hosts:**<br>- 07:00: Start 2 hosts (20% minimum)<br>- 07:30: Load reaches 65% → Start 2 more hosts<br>- 08:00: Load reaches 70% → Start 2 more hosts<br>- 08:30: 6 hosts running, ready for peak hours |

**Configuration Variables:**
- `weekday_ramp_up_start_time`: When to begin (e.g., `"07:00"`)
- `weekday_ramp_up_min_hosts_percent`: Minimum capacity (e.g., `20`)
- `weekday_ramp_up_capacity_threshold_percent`: Scale trigger (e.g., `60`)

### Phase 2: Peak (Business Hours)

**Purpose:** Maintain high capacity for active users

| **Peak Phase** | **Details** |
|----------------|-------------|
| **Time** | 9:00 AM - 5:00 PM |
| **Behavior** | - Maximum capacity mode<br>- Aggressive scaling to handle demand<br>- DepthFirst load balancing (fill hosts efficiently)<br>- No automatic deallocation |
| **Example** | **10 total hosts:**<br>- 09:00: 6 hosts running from ramp-up<br>- 10:00: Load increases → Scale to 8 hosts<br>- 11:00: Peak demand → All 10 hosts running<br>- 12:00-17:00: Maintain capacity based on load |

**Configuration Variables:**
- `weekday_peak_start_time`: When peak hours begin (e.g., `"09:00"`)
- `peak_load_balancing_algorithm`: `BreadthFirst` or `DepthFirst`

### Phase 3: Ramp-Down (Evening Wind-Down)

**Purpose:** Gradually reduce capacity as users log off

| **Ramp-Down Phase** | **Details** |
|---------------------|-------------|
| **Time** | 5:00 PM - 7:00 PM |
| **Behavior** | - Consolidate users to fewer hosts (DepthFirst)<br>- Deallocate empty hosts<br>- Maintain minimum 10% capacity<br>- Optional: Notify users and force logoff |
| **Example** | **10 total hosts:**<br>- 17:00: 10 hosts running, users logging off<br>- 17:30: Users consolidated to 8 hosts → Stop 2 hosts<br>- 18:00: Users consolidated to 6 hosts → Stop 2 hosts<br>- 18:30: Users consolidated to 2 hosts → Stop 4 hosts<br>- 19:00: Minimum 1 host (10%) remains for late workers |

**Configuration Variables:**
- `weekday_ramp_down_start_time`: When to begin wind-down (e.g., `"17:00"`)
- `weekday_ramp_down_min_hosts_percent`: Minimum capacity (e.g., `10`)
- `weekday_ramp_down_capacity_threshold_percent`: Scale down trigger (e.g., `90`)
- `ramp_down_force_logoff_users`: Force logoff after wait time (default: `false`)
- `ramp_down_wait_time_minutes`: Grace period before forced logoff (default: `30`)
- `ramp_down_notification_message`: Message to users before logoff

### Phase 4: Off-Peak (Overnight/Weekend)

**Purpose:** Minimal capacity for after-hours workers or global teams

| **Off-Peak Phase** | **Details** |
|--------------------|-------------|
| **Time** | 7:00 PM - 7:00 AM (next day) |
| **Behavior** | - Minimal capacity (1-2 hosts for on-call staff)<br>- Aggressive deallocation of idle hosts<br>- DepthFirst load balancing (consolidate users)<br>- Start hosts on-demand if needed |
| **Example** | **10 total hosts:**<br>- 19:00: Only 1 host running (10% minimum from ramp-down)<br>- 20:00: If user connects → Keep 1 host<br>- 22:00: If 2nd user connects → Start 2nd host<br>- 03:00: All users disconnected → Deallocate to 0 hosts<br>- 07:00: Ramp-up phase begins for next day |

**Configuration Variables:**
- `weekday_off_peak_start_time`: When off-peak begins (e.g., `"19:00"`)
- `off_peak_load_balancing_algorithm`: `DepthFirst` recommended

## Timezone Configuration

Common timezone values (Windows timezone format):

| Region | Timezone Value | UTC Offset |
|--------|---------------|------------|
| UK/Ireland | `GMT Standard Time` | UTC+0 (UTC+1 DST) |
| Central Europe | `Central Europe Standard Time` | UTC+1 (UTC+2 DST) |
| US East Coast | `Eastern Standard Time` | UTC-5 (UTC-4 DST) |
| US West Coast | `Pacific Standard Time` | UTC-8 (UTC-7 DST) |
| US Central | `Central Standard Time` | UTC-6 (UTC-5 DST) |
| Australia (Sydney) | `AUS Eastern Standard Time` | UTC+10 (UTC+11 DST) |
| Japan | `Tokyo Standard Time` | UTC+9 |
| India | `India Standard Time` | UTC+5:30 |
| UTC | `UTC` | UTC+0 |

**Full list:** [Microsoft Time Zones Documentation](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-time-zones)

## Load Balancing Algorithms

### BreadthFirst (Spread Users)

**When to use:** Ramp-up phase, initial user connections

**Behavior:** Distributes new user sessions across all available session hosts evenly

**Advantages:**
- Better performance (lower per-host resource usage)
- More redundancy (users spread across hosts)
- Easier troubleshooting (fewer users affected by host issues)

**Disadvantages:**
- Higher costs (keeps more hosts running)
- Slower scaling down (users on many hosts)

**Example:**
```
10 users connecting to 4 session hosts:
Host 1: Users 1, 5, 9     (3 users)
Host 2: Users 2, 6, 10    (3 users)
Host 3: Users 3, 7        (2 users)
Host 4: Users 4, 8        (2 users)
```

### DepthFirst (Consolidate Users)

**When to use:** Peak hours, ramp-down, off-peak phases

**Behavior:** Fills each session host to capacity before starting new hosts

**Advantages:**
- Lower costs (fewer hosts running)
- Faster scaling down (empty hosts deallocated quickly)
- Efficient resource utilization

**Disadvantages:**
- Higher per-host resource usage
- Single host failure affects more users
- Potential performance bottlenecks on full hosts

**Example:**
```
10 users connecting to 4 session hosts (max 5 users/host):
Host 1: Users 1, 2, 3, 4, 5     (5 users - FULL)
Host 2: Users 6, 7, 8, 9, 10    (5 users - FULL)
Host 3: Empty                   (0 users - DEALLOCATED)
Host 4: Empty                   (0 users - DEALLOCATED)
```

### Recommended Configuration

```hcl
# Ramp-up: BreadthFirst (prepare capacity)
ramp_up_load_balancing_algorithm = "BreadthFirst"

# Peak: DepthFirst (efficient utilization)
peak_load_balancing_algorithm = "DepthFirst"

# Ramp-down: DepthFirst (fast deallocation)
ramp_down_load_balancing_algorithm = "DepthFirst"

# Off-peak: DepthFirst (minimal hosts)
off_peak_load_balancing_algorithm = "DepthFirst"
```

## Cost Savings Calculation

### Example: 4 Session Hosts (Standard_D2s_v5)

**Without Scaling:**
- 4 VMs × $0.096/hour × 24 hours × 30 days = **($276.48/month) (~€258/month) (~£221/month)**

**With Scaling (60% savings):**

| Period | Hours/Day | Hosts Running | Daily Cost |
|--------|-----------|---------------|------------|
| Ramp-up (7-9 AM) | 2 hours | 2-4 hosts (avg 3) | ($0.58) (€0.54) (£0.46) |
| Peak (9 AM-5 PM) | 8 hours | 4 hosts | ($3.07) (€2.86) (£2.45) |
| Ramp-down (5-7 PM) | 2 hours | 2-4 hosts (avg 3) | ($0.58) (€0.54) (£0.46) |
| Off-peak (7 PM-7 AM) | 14 hours | 0-1 hosts (avg 0.5) | ($0.67) (€0.62) (£0.53) |
| **Weekday Total** | 24 hours | Variable | **($4.90/day) (€4.56/day) (£3.92/day)** |

**Weekend (minimal usage):**
- 48 hours × 0.5 hosts (avg) × $0.096/hour = **($2.30/weekend) (€2.14/weekend) (£1.84/weekend)**

**Monthly Total:**
- Weekdays: $4.90 × 22 days = ($107.80) (€100.40) (£86.10)
- Weekends: $2.30 × 8 days = ($18.40) (€17.15) (£14.70)
- **Total: ($126.20/month) (€117.55/month) (£100.80/month)**

**Savings: $276.48 - $126.20 = ($150.28/month) (~€140/month) (~£120/month) (54% reduction)**

### Scaling Factors

Cost savings depend on:
1. **Off-peak hours** - More off-peak time = greater savings
2. **User behavior** - Consistent logout times improve savings
3. **Min hosts percent** - Lower minimum = higher savings (but slower response)
4. **Capacity threshold** - Higher threshold = fewer hosts running (more savings)

## Force Logoff Configuration

```hcl
# Disable force logoff (wait for users to log off naturally)
ramp_down_force_logoff_users = false
ramp_down_stop_hosts_when    = "ZeroSessions"

# Enable force logoff with grace period
ramp_down_force_logoff_users       = true
ramp_down_wait_time_minutes        = 30
ramp_down_notification_message     = "You will be logged off in 30 minutes. Please save your work."
ramp_down_stop_hosts_when          = "ZeroSessions"  # or "ZeroActiveSessions"
```

## Troubleshooting

### Issue: Hosts not scaling down during ramp-down

**Symptoms:**
- All hosts remain running even during off-peak hours
- No deallocation occurring

**Causes:**
1. Users not logging off (disconnected sessions count as active)
2. `ramp_down_stop_hosts_when = "ZeroSessions"` waiting for all sessions
3. Capacity threshold too high (e.g., 100% = never scale down)
4. Minimum hosts percent too high (e.g., 100% = keep all hosts)

**Solution:**
```bash
# Check active sessions
az desktopvirtualization sessionhost list \
  --resource-group <rg> \
  --host-pool-name <hostpool> \
  --query "[].{Name:name, Sessions:sessions, Status:status}" \
  --output table

# If users disconnected (not logged off), either:
# Option 1: Change to ZeroActiveSessions
ramp_down_stop_hosts_when = "ZeroActiveSessions"

# Option 2: Enable force logoff
ramp_down_force_logoff_users = true
ramp_down_wait_time_minutes  = 30
```

### Issue: Scaling plan not applying to host pool

**Symptoms:**
- Scaling plan exists but hosts not scaling
- No errors in Azure Portal

**Causes:**
1. Scaling plan not associated with host pool
2. Host pool type is "Personal" (scaling plans only work with "Pooled")
3. Scaling plan disabled in configuration

**Solution:**
```bash
# Verify host pool type
az desktopvirtualization hostpool show \
  --resource-group <rg> \
  --name <hostpool> \
  --query "hostPoolType" -o tsv
# Expected: "Pooled"

# Verify scaling plan association
az desktopvirtualization scaling-plan show \
  --resource-group <rg> \
  --name <scaling-plan> \
  --query "hostPoolReferences" -o table

# Check if scaling enabled on host pool
az desktopvirtualization scaling-plan show \
  --resource-group <rg> \
  --name <scaling-plan> \
  --query "hostPoolReferences[].scalingPlanEnabled" -o tsv
# Expected: "True"
```

### Issue: Incorrect timezone causing wrong schedule times

**Symptoms:**
- Scaling occurs at wrong times (e.g., 2 hours off)
- Ramp-up starts too early or too late

**Causes:**
1. Incorrect timezone format (must be Windows timezone name)
2. Timezone doesn't match user location
3. Daylight saving time not accounted for

**Solution:**
```bash
# List valid Windows timezones
tzutil /l

# Verify scaling plan timezone
az desktopvirtualization scaling-plan show \
  --resource-group <rg> \
  --name <scaling-plan> \
  --query "timeZone" -o tsv

# Update timezone if incorrect (via Terraform)
# variables.tf: timezone = "GMT Standard Time"
terraform apply -target=module.scaling_plan
```

### Issue: Users complaining about forced logoff

**Symptoms:**
- User sessions terminated unexpectedly
- Data loss or unsaved work

**Causes:**
1. Force logoff enabled without user awareness
2. Wait time too short (e.g., 5 minutes)
3. Notification message not displayed

**Solution:**
```hcl
# Increase wait time
ramp_down_wait_time_minutes = 60  # 1 hour grace period

# Clear notification message
ramp_down_notification_message = "System maintenance in 60 minutes. Please save your work and log off. You can reconnect immediately."

# Consider disabling force logoff
ramp_down_force_logoff_users = false  # Wait indefinitely

# Or use ZeroActiveSessions (allows disconnected sessions)
ramp_down_stop_hosts_when = "ZeroActiveSessions"
```

## Variables

### Basic Configuration

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enabled` | Enable AVD auto-scaling | `bool` | `true` | No |
| `scaling_plan_name` | Scaling plan name | `string` | - | Yes |
| `location` | Azure region | `string` | - | Yes |
| `resource_group_name` | Resource group name | `string` | - | Yes |
| `friendly_name` | Friendly name for portal display | `string` | `""` | No |
| `description` | Scaling plan description | `string` | Auto-generated | No |
| `timezone` | Timezone for schedules | `string` | `"GMT Standard Time"` | No |
| `host_pool_ids` | List of host pool IDs to scale | `list(string)` | - | Yes |
| `tags` | Resource tags | `map(string)` | `{}` | No |

### Weekday Schedule - Ramp-Up Phase

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `weekday_ramp_up_start_time` | Start time in HH:MM format (24-hour) | `string` | `"07:00"` | No |
| `weekday_ramp_up_min_hosts_percent` | Minimum % of capacity to keep online | `number` | `20` | No |
| `weekday_ramp_up_capacity_threshold_percent` | Start hosts when load exceeds this % | `number` | `60` | No |
| `weekday_ramp_up_load_balancing` | Load balancing: BreadthFirst or DepthFirst | `string` | `"BreadthFirst"` | No |

### Weekday Schedule - Peak Phase

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `weekday_peak_start_time` | Peak hours start time in HH:MM format | `string` | `"09:00"` | No |
| `weekday_peak_min_hosts_percent` | Minimum % of capacity during peak | `number` | `90` | No |
| `weekday_peak_capacity_threshold_percent` | Start hosts when load exceeds this % | `number` | `80` | No |
| `weekday_peak_load_balancing` | Load balancing algorithm | `string` | `"DepthFirst"` | No |

### Weekday Schedule - Ramp-Down Phase

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `weekday_ramp_down_start_time` | Ramp-down start time in HH:MM format | `string` | `"17:00"` | No |
| `weekday_ramp_down_min_hosts_percent` | Minimum % of capacity for late workers | `number` | `10` | No |
| `weekday_ramp_down_capacity_threshold_percent` | Stop hosts when load falls below this % | `number` | `90` | No |
| `weekday_ramp_down_load_balancing` | Load balancing algorithm | `string` | `"DepthFirst"` | No |
| `weekday_ramp_down_force_logoff_enabled` | Enable forced logoff during ramp-down | `bool` | `false` | No |
| `weekday_ramp_down_notification_message` | Message shown before forced logoff | `string` | Default message | No |
| `weekday_ramp_down_wait_time_minutes` | Minutes to wait before forcing logoff | `number` | `30` | No |
| `weekday_ramp_down_stop_hosts_when` | When to stop hosts: ZeroSessions or ZeroActiveSessions | `string` | `"ZeroSessions"` | No |

### Weekday Schedule - Off-Peak Phase

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `weekday_off_peak_start_time` | Off-peak start time in HH:MM format | `string` | `"19:00"` | No |
| `weekday_off_peak_min_hosts_percent` | Minimum % of capacity overnight | `number` | `10` | No |
| `weekday_off_peak_capacity_threshold_percent` | Start hosts when load exceeds this % | `number` | `90` | No |
| `weekday_off_peak_load_balancing` | Load balancing algorithm | `string` | `"DepthFirst"` | No |

### Weekend Schedule (Optional)

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `enable_weekend_schedule` | Enable separate weekend schedule | `bool` | `false` | No |
| `weekend_ramp_up_start_time` | Weekend ramp-up start time | `string` | `"09:00"` | No |
| `weekend_peak_start_time` | Weekend peak start time | `string` | `"10:00"` | No |
| `weekend_ramp_down_start_time` | Weekend ramp-down start time | `string` | `"16:00"` | No |
| `weekend_off_peak_start_time` | Weekend off-peak start time | `string` | `"18:00"` | No |

*Note: Weekend schedule variables mirror weekday settings. See [variables.tf](variables.tf) for complete list.*

## Outputs

See [outputs.tf](outputs.tf) for complete list of output values.

## Related Documentation

- [Azure Virtual Desktop Scaling Plans](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scaling-plan)
- [Autoscale Best Practices](https://learn.microsoft.com/azure/virtual-desktop/autoscale-scaling-plan#best-practices)
- [Start VM on Connect](https://learn.microsoft.com/azure/virtual-desktop/start-virtual-machine-connect)
- [AVD Core Module README](../avd_core/README.md)
