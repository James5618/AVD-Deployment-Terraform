# Logging Module

Centralized logging and monitoring for Azure Virtual Desktop environments.

## Overview

This module provisions a Log Analytics workspace and configures comprehensive diagnostic settings for all AVD components, storage, networking, and virtual machines.

## Features

### Log Analytics Workspace
- Configurable retention period (7-730 days, default: 30)
- Pay-as-you-go pricing (PerGB2018 SKU)
- Centralized log aggregation

### Diagnostic Settings
Automatically configured for:
- **AVD Workspace** - Checkpoint, Error, Management, Feed logs
- **AVD Host Pool** - Connection, HostRegistration, AgentHealthStatus logs
- **AVD Application Groups** - Checkpoint, Error, Management logs
- **Storage Account** - Transaction metrics for Azure Files
- **Azure Files Service** - StorageRead, StorageWrite, StorageDelete logs
- **Network Security Groups** - Security events and rule counters

### VM Insights
Installs and configures VM Insights on:
- Domain Controller
- All Session Hosts

**Installed Agents:**
- Azure Monitor Agent (AMA) - Latest generation monitoring
- Dependency Agent - Service Map and application dependencies

**Collected Metrics:**
- Performance counters (CPU, Memory, Disk, Network)
- Process and service dependencies
- Network connections and traffic

## Usage

```hcl
module "logging" {
  source = "../../modules/logging"

  # Basic Configuration
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  log_analytics_workspace_name = "avd-prod-logs"
  
  # Retention Settings
  log_analytics_retention_days = 30  # 30-90 days typical for production
  
  # AVD Diagnostic Settings
  avd_workspace_id  = module.avd_core.workspace_id
  avd_hostpool_id   = module.avd_core.hostpool_id
  avd_app_group_ids = {
    desktop = module.avd_core.desktop_app_group_id
  }
  
  # Storage Diagnostic Settings
  storage_account_id = module.fslogix_storage.storage_account_id
  
  # Network Diagnostic Settings
  nsg_ids = {
    dc  = module.networking.dc_nsg_id
    avd = module.networking.avd_nsg_id
  }
  
  # VM Insights
  enable_vm_insights    = true
  dc_vm_id              = module.domain_controller.dc_vm_id
  session_host_vm_ids   = module.session_hosts.vm_ids
  
  tags = local.common_tags
}
```

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `resource_group_name` | string | Resource group for Log Analytics workspace |
| `location` | string | Azure region |
| `log_analytics_workspace_name` | string | Workspace name |

### Optional Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `log_analytics_sku` | string | `"PerGB2018"` | Pricing SKU |
| `log_analytics_retention_days` | number | `30` | Log retention (7-730 days) |
| `enable_vm_insights` | bool | `true` | Install VM Insights agents |

### Resource IDs (Optional)

Set to `null` to skip diagnostic settings for specific resources:

| Variable | Type | Description |
|----------|------|-------------|
| `avd_workspace_id` | string | AVD workspace resource ID |
| `avd_hostpool_id` | string | AVD host pool resource ID |
| `avd_app_group_ids` | map(string) | Map of app group IDs |
| `storage_account_id` | string | Storage account resource ID |
| `nsg_ids` | map(string) | Map of NSG resource IDs |
| `dc_vm_id` | string | Domain Controller VM ID |
| `session_host_vm_ids` | map(string) | Map of session host VM IDs |

## Outputs

| Output | Description |
|--------|-------------|
| `log_analytics_workspace_id` | Workspace resource ID |
| `log_analytics_workspace_name` | Workspace name |
| `log_analytics_workspace_key` | Primary shared key (sensitive) |
| `data_collection_rule_id` | VM Insights DCR ID |

## Cost Considerations

### Log Analytics Pricing (Pay-as-you-go)

**Data Ingestion:**
- First 5 GB/month: Free
- $2.30 per GB (typically)

**Typical AVD Environment (2 session hosts, 1 DC):**
- VM Insights: ~2-4 GB/month per VM = 6-12 GB/month
- AVD logs: ~1-2 GB/month
- Storage/NSG logs: ~0.5-1 GB/month
- **Total**: ~8-15 GB/month = $7-$23/month

**Data Retention:**
- First 31 days: Included
- Days 32-730: $0.12 per GB/month

### Cost Optimization Tips

1. **Reduce retention for dev/test:**
   ```hcl
   log_analytics_retention_days = 7  # Minimum retention
   ```

2. **Disable VM Insights in non-prod:**
   ```hcl
   enable_vm_insights = false  # Saves ~6-12 GB/month
   ```

3. **Selective diagnostic settings:**
   ```hcl
   # Only enable for production resources
   avd_workspace_id = var.environment == "prod" ? module.avd_core.workspace_id : null
   ```

4. **Sample performance data:**
   - VM Insights samples every 60 seconds by default
   - Consider 5-minute intervals for non-production

## Monitoring Queries

### KQL Query Examples

**AVD Connection Success Rate:**
```kql
WVDConnections
| where TimeGenerated > ago(24h)
| summarize 
    Total = count(),
    Successful = countif(State == "Connected"),
    Failed = countif(State == "Failed")
| extend SuccessRate = (Successful * 100.0) / Total
```

**Session Host Performance:**
```kql
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCPU = avg(CounterValue) by Computer
| where AvgCPU > 80  // High CPU usage
```

**FSLogix Profile Load Times:**
```kql
StorageFileLogs
| where TimeGenerated > ago(24h)
| where OperationName == "GetFile"
| summarize AvgLatencyMs = avg(DurationMs) by bin(TimeGenerated, 1h)
```

**NSG Denied Traffic:**
```kql
AzureDiagnostics
| where Category == "NetworkSecurityGroupEvent"
| where type_s == "block"
| summarize Count = count() by SourceIP = callerIpAddress_s, DestPort = destinationPort_d
| order by Count desc
```

## VM Insights Capabilities

### Performance Monitoring
- CPU utilization per process
- Memory usage and available memory
- Disk IOPS and throughput
- Network bytes sent/received

### Service Map
- Visualize application dependencies
- Identify process connections
- Track network traffic between VMs
- Discover external dependencies

### Alerts (Configure in Azure Portal)
- High CPU usage (>80% for 10 minutes)
- Low memory (<10% available)
- Disk space warnings (<10% free)
- VM availability drops

## Troubleshooting

### VM Insights Not Showing Data

**Check agent installation:**
```powershell
# On VM, check if agents are installed
Get-Service -Name "AzureMonitorWindowsAgent"
Get-Service -Name "DependencyAgent"

# Check agent logs
Get-EventLog -LogName "Azure Monitor Agent" -Newest 50
```

**Verify DCR association:**
```bash
# Azure CLI
az monitor data-collection rule association list \
  --resource <VM_RESOURCE_ID>
```

### Diagnostic Settings Not Collecting Logs

**Verify diagnostic setting exists:**
```bash
az monitor diagnostic-settings show \
  --resource <RESOURCE_ID> \
  --name diag-avd-workspace
```

**Check Log Analytics workspace permissions:**
- Workspace must have "Log Analytics Contributor" or higher
- VM managed identities need read access to workspace

### High Costs

**Query top data consumers:**
```kql
Usage
| where TimeGenerated > ago(30d)
| summarize TotalGB = sum(Quantity) / 1000 by DataType
| order by TotalGB desc
```

**Disable non-essential logs:**
- Reduce VM Insights sampling frequency
- Disable Storage read logs (keep write/delete only)
- Reduce NSG logging to blocked traffic only

## Integration with Azure Monitor

This module creates the foundation for:
- **Azure Monitor Workbooks** - Custom dashboards
- **Azure Monitor Alerts** - Automated alerting
- **Azure Monitor Insights** - AVD Insights integration
- **Azure Sentinel** - Security analytics (separate deployment)

## Security Best Practices

1. **Workspace access control:**
   - Use RBAC to limit access to logs
   - Separate workspaces for prod/non-prod

2. **Sensitive data:**
   - Logs may contain usernames and IP addresses
   - Comply with data retention policies
   - Use workspace access mode for granular control

3. **Shared keys:**
   - Rotate workspace keys regularly
   - Use managed identities instead of keys when possible

## References

- [Azure Monitor for AVD](https://learn.microsoft.com/azure/virtual-desktop/azure-monitor)
- [VM Insights Overview](https://learn.microsoft.com/azure/azure-monitor/vm/vminsights-overview)
- [Log Analytics Pricing](https://azure.microsoft.com/pricing/details/monitor/)
- [Diagnostic Settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
