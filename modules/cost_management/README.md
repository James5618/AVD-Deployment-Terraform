# Cost Management Module

Azure Budget with configurable alert thresholds for cost monitoring and control.

## Overview

This module provisions Azure Budgets to monitor and alert on spending for resource groups or subscriptions, helping prevent unexpected cost overruns.

## Features

### Azure Budget
- **Monthly budget tracking** with configurable amount
- **Resource Group or Subscription scope** for flexibility
- **Multiple alert thresholds** (default: 80%, 90%, 100%)
- **Email notifications** to specified recipients

### Alert Levels
- **Warning (80%)** - Early warning that spending is approaching budget
- **Critical (90%)** - Urgent alert that budget will be exceeded
- **Exceeded (100%)** - Budget limit reached or exceeded
- **Forecasted (Optional)** - Predicted budget overrun based on trends

### Flexible Scoping
- **Resource Group** - Budget specific AVD environment (dev/prod)
- **Subscription** - Budget entire subscription across all resource groups
- **Tag Filtering** - Further refine scope with tags

## Usage

### Resource Group Scoped Budget

```hcl
module "cost_management" {
  source = "../../modules/cost_management"

  enabled              = true
  budget_name          = "avd-prod-budget"
  monthly_budget_amount = 500  # $500/month
  
  # Resource Group Scope
  budget_scope        = "ResourceGroup"
  resource_group_id   = azurerm_resource_group.rg.id
  resource_group_name = azurerm_resource_group.rg.name
  
  # Alert Configuration
  alert_emails = [
    "ops-team@company.com",
    "finance@company.com"
  ]
  
  alert_threshold_1 = 80   # Warning at 80% ($400)
  alert_threshold_2 = 90   # Critical at 90% ($450)
  alert_threshold_3 = 100  # Exceeded at 100% ($500)
  
  # Optional: Forecasted alerts
  enable_forecasted_alerts   = true
  forecasted_alert_threshold = 100
  
  # Time Period
  budget_start_date = "2026-01-01"
  budget_end_date   = null  # Indefinite
}
```

### Subscription Scoped Budget

```hcl
module "cost_management" {
  source = "../../modules/cost_management"

  enabled              = true
  budget_name          = "azure-subscription-budget"
  monthly_budget_amount = 2000  # $2000/month for entire subscription
  
  # Subscription Scope
  budget_scope    = "Subscription"
  subscription_id = data.azurerm_client_config.current.subscription_id
  
  # Alert Configuration
  alert_emails = ["finance-team@company.com"]
  
  # Optional: Filter by tags
  filter_tags = {
    CostCenter = "IT"
    Department = "Engineering"
  }
}
```

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `budget_name` | string | Name of the Azure Budget |
| `monthly_budget_amount` | number | Monthly budget in USD (or subscription currency) |
| `alert_emails` | list(string) | Email addresses for alerts |

### Budget Scope

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enabled` | bool | `true` | Enable/disable budget |
| `budget_scope` | string | `"ResourceGroup"` | Scope: ResourceGroup or Subscription |
| `resource_group_id` | string | `null` | RG ID (required if ResourceGroup scope) |
| `subscription_id` | string | `null` | Subscription ID (required if Subscription scope) |

### Alert Thresholds

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `alert_threshold_1` | number | `80` | First alert percentage (warning) |
| `alert_threshold_2` | number | `90` | Second alert percentage (critical) |
| `alert_threshold_3` | number | `100` | Third alert percentage (exceeded) |
| `enable_forecasted_alerts` | bool | `false` | Enable forecasted budget alerts |
| `forecasted_alert_threshold` | number | `100` | Forecasted alert percentage |

### Time Period

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `budget_start_date` | string | `null` | Start date (YYYY-MM-01, defaults to current month) |
| `budget_end_date` | string | `null` | End date (YYYY-MM-01, null = indefinite) |

### Filtering

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `filter_tags` | map(string) | `{}` | Tags to filter budget scope |

## Outputs

| Output | Description |
|--------|-------------|
| `budget_id` | Azure Budget resource ID |
| `budget_name` | Budget name |
| `budget_amount` | Monthly budget amount |
| `alert_thresholds` | Configured thresholds (warning/critical/exceeded) |
| `alert_recipients` | Email addresses (sensitive) |
| `budget_scope` | Budget scope (ResourceGroup or Subscription) |

## Setting Budget Amounts

### Estimating AVD Costs

**Typical AVD Environment Costs (per month):**

| Component | Small (2 hosts) | Medium (5 hosts) | Large (10 hosts) |
|-----------|-----------------|------------------|------------------|
| Compute (VMs) | $140-280 | $350-700 | $700-1,400 |
| Storage (Files) | $10-20 | $20-40 | $40-80 |
| Networking | $10-20 | $20-40 | $40-80 |
| Domain Controller | $55-70 | $55-70 | $110-140 |
| Backup (optional) | $50-100 | $100-200 | $200-400 |
| Logging (optional) | $15-30 | $30-60 | $60-120 |
| **Total Estimate** | **$280-520** | **$575-1,110** | **$1,150-2,220** |

### Budget Recommendations

**Development Environment:**
```hcl
monthly_budget_amount = 500   # $500/month with 20% buffer
alert_threshold_1     = 80    # Alert at $400
alert_threshold_2     = 90    # Alert at $450
alert_threshold_3     = 100   # Alert at $500
```

**Production Environment:**
```hcl
monthly_budget_amount = 1500  # $1,500/month with 30% buffer
alert_threshold_1     = 75    # Alert at $1,125 (earlier warning)
alert_threshold_2     = 85    # Alert at $1,275
alert_threshold_3     = 95    # Alert at $1,425 (before exceeding)
```

**Multi-Environment Subscription:**
```hcl
monthly_budget_amount = 3000  # $3,000/month total
# Use tag filtering to separate dev/prod
filter_tags = {
  Environment = "production"
  CostCenter  = "AVD"
}
```

## Alert Threshold Strategies

### Conservative Strategy (Early Warnings)
```hcl
alert_threshold_1 = 50   # Alert at 50% - plenty of time to react
alert_threshold_2 = 75   # Alert at 75% - take action soon
alert_threshold_3 = 90   # Alert at 90% - urgent action needed
```
**Use When**: High budget sensitivity, unpredictable workloads

### Standard Strategy (Balanced)
```hcl
alert_threshold_1 = 80   # Alert at 80% - warning
alert_threshold_2 = 90   # Alert at 90% - critical
alert_threshold_3 = 100  # Alert at 100% - exceeded
```
**Use When**: Normal operations, predictable spending

### Aggressive Strategy (Cost Optimization Focus)
```hcl
alert_threshold_1 = 70   # Alert at 70% - early intervention
alert_threshold_2 = 80   # Alert at 80% - review spending
alert_threshold_3 = 90   # Alert at 90% - freeze non-essential resources
```
**Use When**: Strict budget constraints, cost reduction initiatives

## Forecasted Alerts

### How Forecasted Alerts Work

Forecasted alerts use **Azure's machine learning** to predict spending:
- Analyzes current spending trends
- Predicts when budget will be exceeded
- Alerts **before** budget is actually exceeded

**Example:**
```
Current spending (Day 20 of month): $350
Trend: Spending $17.50/day
Forecast: Will reach $525 by end of month (exceeds $500 budget)
Alert: Sent on Day 20 (10 days before month ends)
```

### Configuration

```hcl
enable_forecasted_alerts   = true
forecasted_alert_threshold = 100  # Alert when forecast predicts 100% budget usage

# Or alert earlier
forecasted_alert_threshold = 90   # Alert when forecast predicts 90% usage
```

**Benefits:**
-  Proactive alerts before overspending
-  More time to take corrective action
-  Better cost predictability

**Considerations:**
-  Requires 30+ days of spending data for accuracy
-  May have false positives early in month
-  Best for stable, predictable workloads

## Email Alert Examples

### Alert at 80% (Warning)
```
Subject: Azure Budget Alert - Warning (80% of budget)
Budget: avd-prod-budget
Scope: Resource Group 'avd-prod-rg'
Amount: $400 of $500 budget used
Threshold: 80%
Status: Warning - approaching budget limit
```

### Alert at 100% (Exceeded)
```
Subject: Azure Budget Alert - EXCEEDED (100% of budget)
Budget: avd-prod-budget
Scope: Resource Group 'avd-prod-rg'
Amount: $500 of $500 budget used
Threshold: 100%
Status: EXCEEDED - budget limit reached
Action Required: Review spending immediately
```

### Forecasted Alert
```
Subject: Azure Budget Alert - Forecasted to Exceed
Budget: avd-prod-budget
Scope: Resource Group 'avd-prod-rg'
Current: $350 of $500 budget used (70%)
Forecast: Projected to reach $525 (105%) by end of month
Action Required: Review and optimize spending
```

## Multiple Recipients

### Team-Based Alerts

```hcl
alert_emails = [
  "ops-team@company.com",      # Operations team
  "finance@company.com",        # Finance department
  "avd-admin@company.com"       # AVD administrators
]
```

### Role-Based Alerts (Advanced)

For different alerts to different teams, create multiple budgets:

```hcl
# Budget 1: Early warning for ops team
module "cost_management_ops" {
  source                = "../../modules/cost_management"
  budget_name           = "avd-prod-budget-ops"
  monthly_budget_amount = 500
  alert_threshold_1     = 50  # Early alert
  alert_emails          = ["ops-team@company.com"]
}

# Budget 2: Critical alerts for finance
module "cost_management_finance" {
  source                = "../../modules/cost_management"
  budget_name           = "avd-prod-budget-finance"
  monthly_budget_amount = 500
  alert_threshold_1     = 90   # Only critical alerts
  alert_threshold_2     = 100
  alert_emails          = ["finance@company.com"]
}
```

## Time Period Configuration

### Current Month Start (Default)
```hcl
budget_start_date = null  # Automatically uses current month
budget_end_date   = null  # Indefinite (continues every month)
```

### Fiscal Year Budget
```hcl
budget_start_date = "2026-04-01"  # Fiscal year starts April
budget_end_date   = "2027-03-01"  # Ends March next year
```

### Project-Based Budget
```hcl
budget_start_date = "2026-02-01"  # Project start
budget_end_date   = "2026-08-01"  # Project end (6 months)
```

### Important: Date Format

**Must use first day of month:**
```hcl
budget_start_date = "2026-02-01"  #  Correct
budget_start_date = "2026-02-15"  #  Invalid - must be 01
```

## Tag Filtering

### Filter by Environment

```hcl
budget_scope = "Subscription"
filter_tags = {
  Environment = "production"
}
# Only resources tagged with Environment=production count toward budget
```

### Filter by Multiple Tags

```hcl
filter_tags = {
  Environment = "production"
  Project     = "AVD"
  CostCenter  = "IT-12345"
}
# Only resources matching ALL tags count toward budget
```

### Use Case: Separate Dev/Prod Budgets

```hcl
# Production budget
module "cost_prod" {
  source                = "../../modules/cost_management"
  budget_name           = "avd-prod-budget"
  monthly_budget_amount = 1500
  budget_scope          = "Subscription"
  filter_tags = {
    Environment = "prod"
  }
  alert_emails = ["prod-ops@company.com"]
}

# Development budget
module "cost_dev" {
  source                = "../../modules/cost_management"
  budget_name           = "avd-dev-budget"
  monthly_budget_amount = 500
  budget_scope          = "Subscription"
  filter_tags = {
    Environment = "dev"
  }
  alert_emails = ["dev-team@company.com"]
}
```

## Monitoring Budget Compliance

### Azure Portal

**View Budget Status:**
1. Navigate to: Cost Management + Billing → Budgets
2. Select your budget
3. View current spending vs. budget
4. Check alert history

**Cost Analysis:**
1. Navigate to: Cost Management + Billing → Cost Analysis
2. Filter by resource group or tags
3. View spending trends
4. Export reports

### Azure CLI

**Check Budget Status:**
```bash
az consumption budget list \
  --resource-group avd-prod-rg

az consumption budget show \
  --resource-group avd-prod-rg \
  --budget-name avd-prod-budget
```

**View Current Spending:**
```bash
az consumption usage list \
  --start-date 2026-02-01 \
  --end-date 2026-02-28 \
  --query "[?contains(instanceId, 'avd-prod-rg')]"
```

### PowerShell

**Get Budget Details:**
```powershell
Get-AzConsumptionBudget `
  -ResourceGroupName "avd-prod-rg" `
  -Name "avd-prod-budget"
```

## Taking Action on Budget Alerts

### When Alert is Received

**1. Investigate Spending (Immediate):**
```bash
# View top cost resources
az consumption usage list \
  --start-date 2026-02-01 \
  --end-date 2026-02-28 \
  --query "sort_by([].{resource: instanceId, cost: pretaxCost}, &cost)[::-1][:10]"
```

**2. Common Cost Drivers:**
- Running VMs 24/7 (implement start/stop automation)
- Oversized VMs (right-size to smaller SKUs)
- Unused storage accounts or disks
- High bandwidth usage
- Unnecessary backups or snapshots

**3. Quick Cost Reductions:**
```hcl
# Reduce session host count
session_host_count = 1  # Was: 2

# Downsize VMs
session_host_vm_size = "Standard_D2s_v5"  # Was: Standard_D4s_v5

# Disable expensive features
enable_backup        = false
enable_vm_insights   = false
fslogix_backup_enabled = false
```

**4. Long-Term Optimization:**
- Implement auto-scaling
- Use Azure Reservations (1-3 year commitment)
- Optimize storage tiers
- Review and clean up unused resources

## Best Practices

### 1. Set Realistic Budgets
- Start with actual costs + 20-30% buffer
- Review and adjust monthly for first 3 months
- Account for seasonal variations

### 2. Multiple Alert Levels
```hcl
# Good: Multiple progressive alerts
alert_threshold_1 = 80   # Warning - monitor
alert_threshold_2 = 90   # Critical - take action
alert_threshold_3 = 100  # Exceeded - urgent action

# Bad: Only one alert at 100%
alert_threshold_1 = 100  # Too late to react
```

### 3. Appropriate Recipients
```hcl
# Good: Include operations and finance
alert_emails = [
  "ops@company.com",      # Can take technical action
  "finance@company.com"   # Budget oversight
]

# Bad: Only personal email
alert_emails = ["personal@gmail.com"]  # No backup, may miss alerts
```

### 4. Regular Review
- **Weekly**: Check spending trends
- **Monthly**: Review budget vs. actual
- **Quarterly**: Adjust budgets based on usage patterns
- **Annually**: Evaluate cost optimization opportunities

### 5. Environment-Specific Budgets
```hcl
# Development: Lower budget, less aggressive alerts
monthly_budget_amount = 300
alert_threshold_1     = 90

# Production: Higher budget, more aggressive alerts
monthly_budget_amount = 1500
alert_threshold_1     = 70  # Earlier warning
```

## Troubleshooting

### No Alerts Received

**Cause**: Email addresses not verified or blocked.
**Solution**:
- Check spam/junk folders
- Verify email addresses are correct
- Add azure-noreply@microsoft.com to safe senders
- Check Azure Service Health for notification issues

### Budget Not Tracking Correctly

**Cause**: Incorrect scope or tag filtering.
**Solution**:
```bash
# Verify resources are in scope
az resource list \
  --resource-group avd-prod-rg \
  --query "[].{name:name, type:type, tags:tags}"

# Check budget configuration
az consumption budget show \
  --resource-group avd-prod-rg \
  --budget-name avd-prod-budget
```

### Forecasted Alerts Not Working

**Cause**: Insufficient data or new subscription.
**Solution**:
- Wait 30+ days for accurate forecasts
- Use actual alerts initially
- Enable forecasted alerts after stable spending pattern

### Budget Shows 0% Used

**Cause**: Costs not yet processed (24-48 hour delay).
**Solution**:
- Wait 24-48 hours for cost data to populate
- Check Cost Analysis for real-time estimates
- Budget shows finalized costs, not real-time

## Cost Optimization Tips

### 1. Right-Size VMs
```hcl
# Before: Oversized VMs
dc_vm_size = "Standard_D4s_v3"  # $140/month
session_host_vm_size = "Standard_D8s_v5"  # $280/month each

# After: Right-sized VMs
dc_vm_size = "Standard_B2ms"  # $55/month (60% savings)
session_host_vm_size = "Standard_D4s_v5"  # $140/month each (50% savings)
```

### 2. Implement Auto-Shutdown
```hcl
# Stop non-production VMs outside business hours
# Potential savings: 50-70% on compute costs
```

### 3. Use Azure Hybrid Benefit
- Apply existing Windows licenses
- Save up to 40% on Windows VMs

### 4. Reserved Instances
- 1-year commitment: 20-40% savings
- 3-year commitment: 40-60% savings

### 5. Storage Optimization
```hcl
# Use appropriate storage tier
storage_account_tier = "Standard"  # Not Premium unless needed
storage_replication_type = "LRS"   # Not GRS unless required
```

## References

- [Azure Budgets Documentation](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Cost Management Best Practices](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-mgt-best-practices)
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Cost Optimization Checklist](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-optimization-checklist)
