# ============================================================================
# Logging Module - Log Analytics and Diagnostic Settings
# ============================================================================
# Provisions centralized logging for AVD environment:
# - Log Analytics Workspace with configurable retention
# - Diagnostic settings for AVD resources (workspace, host pool, app groups)
# - Diagnostic settings for storage account (Azure Files)
# - Diagnostic settings for NSGs
# - VM Insights for Domain Controller and Session Hosts
# ============================================================================

# ============================================================================
# LOG ANALYTICS WORKSPACE
# ============================================================================

resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  
  tags = var.tags
}

# ============================================================================
# DIAGNOSTIC SETTINGS - AVD WORKSPACE
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "avd_workspace" {
  count                      = var.avd_workspace_id != null ? 1 : 0
  name                       = "diag-avd-workspace"
  target_resource_id         = var.avd_workspace_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Checkpoint"
  }

  enabled_log {
    category = "Error"
  }

  enabled_log {
    category = "Management"
  }

  enabled_log {
    category = "Feed"
  }
}

# ============================================================================
# DIAGNOSTIC SETTINGS - AVD HOST POOL
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "avd_hostpool" {
  count                      = var.avd_hostpool_id != null ? 1 : 0
  name                       = "diag-avd-hostpool"
  target_resource_id         = var.avd_hostpool_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Checkpoint"
  }

  enabled_log {
    category = "Error"
  }

  enabled_log {
    category = "Management"
  }

  enabled_log {
    category = "Connection"
  }

  enabled_log {
    category = "HostRegistration"
  }

  enabled_log {
    category = "AgentHealthStatus"
  }
}

# ============================================================================
# DIAGNOSTIC SETTINGS - AVD APPLICATION GROUPS
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "avd_app_group" {
  for_each                   = var.avd_app_group_ids
  name                       = "diag-avd-appgroup-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Checkpoint"
  }

  enabled_log {
    category = "Error"
  }

  enabled_log {
    category = "Management"
  }
}

# ============================================================================
# DIAGNOSTIC SETTINGS - STORAGE ACCOUNT
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "storage_account" {
  count                      = var.storage_account_id != null ? 1 : 0
  name                       = "diag-storage"
  target_resource_id         = var.storage_account_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = false
  }
}

# Diagnostic settings for Azure Files service specifically
resource "azurerm_monitor_diagnostic_setting" "storage_files" {
  count                      = var.storage_account_id != null ? 1 : 0
  name                       = "diag-storage-files"
  target_resource_id         = "${var.storage_account_id}/fileServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = false
  }
}

# ============================================================================
# DIAGNOSTIC SETTINGS - NETWORK SECURITY GROUPS
# ============================================================================

resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each                   = var.nsg_ids
  name                       = "diag-nsg-${each.key}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

# ============================================================================
# VM INSIGHTS - DATA COLLECTION RULE
# ============================================================================

resource "azurerm_monitor_data_collection_rule" "vminsights" {
  count               = var.enable_vm_insights ? 1 : 0
  name                = "${var.log_analytics_workspace_name}-dcr"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.main.id
      name                  = "VMInsightsPerf-Logs-Dest"
    }
  }

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["VMInsightsPerf-Logs-Dest"]
  }

  data_flow {
    streams      = ["Microsoft-ServiceMap"]
    destinations = ["VMInsightsPerf-Logs-Dest"]
  }

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\VmInsights\\DetailedMetrics"
      ]
      name = "VMInsightsPerfCounters"
    }

    extension {
      streams        = ["Microsoft-ServiceMap"]
      extension_name = "DependencyAgent"
      name           = "DependencyAgentDataSource"
    }
  }
}

# ============================================================================
# VM INSIGHTS - DOMAIN CONTROLLER
# ============================================================================

# Install Azure Monitor Agent on DC
resource "azurerm_virtual_machine_extension" "dc_ama" {
  count                      = var.enable_vm_insights && var.dc_vm_id != null ? 1 : 0
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = var.dc_vm_id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  tags = var.tags
}

# Install Dependency Agent on DC
resource "azurerm_virtual_machine_extension" "dc_dependency" {
  count                      = var.enable_vm_insights && var.dc_vm_id != null ? 1 : 0
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = var.dc_vm_id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  tags = var.tags

  depends_on = [azurerm_virtual_machine_extension.dc_ama]
}

# Associate DC with Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "dc" {
  count                   = var.enable_vm_insights && var.dc_vm_id != null ? 1 : 0
  name                    = "dc-vminsights-dcr-association"
  target_resource_id      = var.dc_vm_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights[0].id
}

# ============================================================================
# VM INSIGHTS - SESSION HOSTS
# ============================================================================

# Install Azure Monitor Agent on Session Hosts
resource "azurerm_virtual_machine_extension" "session_host_ama" {
  for_each                   = var.enable_vm_insights ? var.session_host_vm_ids : {}
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = each.value
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  tags = var.tags
}

# Install Dependency Agent on Session Hosts
resource "azurerm_virtual_machine_extension" "session_host_dependency" {
  for_each                   = var.enable_vm_insights ? var.session_host_vm_ids : {}
  name                       = "DependencyAgentWindows"
  virtual_machine_id         = each.value
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.10"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  tags = var.tags

  depends_on = [azurerm_virtual_machine_extension.session_host_ama]
}

# Associate Session Hosts with Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "session_hosts" {
  for_each                = var.enable_vm_insights ? var.session_host_vm_ids : {}
  name                    = "sh-${each.key}-vminsights-dcr-association"
  target_resource_id      = each.value
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vminsights[0].id
}
