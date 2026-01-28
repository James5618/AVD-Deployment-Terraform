# ============================================================================
# Scaling Plan Module - AVD Auto-Scaling for Cost Optimization
# ============================================================================
# Automatically scales session hosts based on time-of-day and user demand:
# - Ramp-up: Morning startup (gradually increase capacity)
# - Peak: Business hours (maintain high capacity)
# - Ramp-down: Evening wind-down (gradually decrease capacity)
# - Off-peak: Overnight/weekends (minimal capacity)
#
# Cost Savings: Automatically deallocates idle session hosts (save 60-80%)
# ============================================================================

resource "azurerm_virtual_desktop_scaling_plan" "scaling_plan" {
  count               = var.enabled ? 1 : 0
  name                = var.scaling_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  friendly_name       = var.friendly_name
  description         = var.description
  time_zone           = var.timezone
  
  # ──────────────────────────────────────────────────────────────────────────
  # WEEKDAY SCHEDULE - Monday through Friday business hours
  # ──────────────────────────────────────────────────────────────────────────
  schedule {
    name                                 = "Weekday_Schedule"
    days_of_week                         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    
    # ─────────────────────────────────────────────────────────────────────
    # RAMP-UP PHASE - Morning startup (e.g., 7:00 AM - 9:00 AM)
    # ─────────────────────────────────────────────────────────────────────
    # Gradually start session hosts before users arrive
    # - Start time: When to begin scaling up
    # - Capacity threshold: Start new hosts when load exceeds this %
    # - Min hosts %: Minimum % of host pool to keep online
    # ─────────────────────────────────────────────────────────────────────
    ramp_up_start_time                   = var.weekday_ramp_up_start_time
    ramp_up_load_balancing_algorithm     = var.ramp_up_load_balancing_algorithm
    ramp_up_minimum_hosts_percent        = var.weekday_ramp_up_min_hosts_percent
    ramp_up_capacity_threshold_percent   = var.weekday_ramp_up_capacity_threshold_percent
    
    # ─────────────────────────────────────────────────────────────────────
    # PEAK PHASE - Business hours (e.g., 9:00 AM - 5:00 PM)
    # ─────────────────────────────────────────────────────────────────────
    # Maintain high capacity for active users
    # - Load balancing: Breadth-first spreads users, Depth-first fills hosts
    # - Capacity threshold: Aggressive scaling to handle demand
    # ─────────────────────────────────────────────────────────────────────
    peak_start_time                      = var.weekday_peak_start_time
    peak_load_balancing_algorithm        = var.peak_load_balancing_algorithm
    
    # ─────────────────────────────────────────────────────────────────────
    # RAMP-DOWN PHASE - Evening wind-down (e.g., 5:00 PM - 7:00 PM)
    # ─────────────────────────────────────────────────────────────────────
    # Gradually reduce capacity as users log off
    # - Min hosts %: Keep minimum capacity for late workers
    # - Capacity threshold: Higher threshold = slower scaling
    # - Wait time: Minutes to wait before logging off idle users
    # ─────────────────────────────────────────────────────────────────────
    ramp_down_start_time                 = var.weekday_ramp_down_start_time
    ramp_down_load_balancing_algorithm   = var.ramp_down_load_balancing_algorithm
    ramp_down_minimum_hosts_percent      = var.weekday_ramp_down_min_hosts_percent
    ramp_down_capacity_threshold_percent = var.weekday_ramp_down_capacity_threshold_percent
    ramp_down_force_logoff_users         = var.ramp_down_force_logoff_users
    ramp_down_wait_time_minutes          = var.ramp_down_wait_time_minutes
    ramp_down_notification_message       = var.ramp_down_notification_message
    ramp_down_stop_hosts_when            = var.ramp_down_stop_hosts_when
    
    # ─────────────────────────────────────────────────────────────────────
    # OFF-PEAK PHASE - Overnight (e.g., 7:00 PM - 7:00 AM next day)
    # ─────────────────────────────────────────────────────────────────────
    # Minimal capacity for after-hours workers or global teams
    # - Lower capacity threshold = aggressive deallocation
    # ─────────────────────────────────────────────────────────────────────
    off_peak_start_time                  = var.weekday_off_peak_start_time
    off_peak_load_balancing_algorithm    = var.off_peak_load_balancing_algorithm
  }
  
  # ──────────────────────────────────────────────────────────────────────────
  # WEEKEND SCHEDULE - Saturday and Sunday (optional)
  # ──────────────────────────────────────────────────────────────────────────
  dynamic "schedule" {
    for_each = var.enable_weekend_schedule ? [1] : []
    content {
      name                                 = "Weekend_Schedule"
      days_of_week                         = ["Saturday", "Sunday"]
      
      # Weekends typically use off-peak settings all day
      # Can be customized for 24x7 operations or global teams
      ramp_up_start_time                   = var.weekend_ramp_up_start_time
      ramp_up_load_balancing_algorithm     = var.ramp_up_load_balancing_algorithm
      ramp_up_minimum_hosts_percent        = var.weekend_ramp_up_min_hosts_percent
      ramp_up_capacity_threshold_percent   = var.weekend_ramp_up_capacity_threshold_percent
      
      peak_start_time                      = var.weekend_peak_start_time
      peak_load_balancing_algorithm        = var.peak_load_balancing_algorithm
      
      ramp_down_start_time                 = var.weekend_ramp_down_start_time
      ramp_down_load_balancing_algorithm   = var.ramp_down_load_balancing_algorithm
      ramp_down_minimum_hosts_percent      = var.weekend_ramp_down_min_hosts_percent
      ramp_down_capacity_threshold_percent = var.weekend_ramp_down_capacity_threshold_percent
      ramp_down_force_logoff_users         = var.ramp_down_force_logoff_users
      ramp_down_wait_time_minutes          = var.ramp_down_wait_time_minutes
      ramp_down_notification_message       = var.ramp_down_notification_message
      ramp_down_stop_hosts_when            = var.ramp_down_stop_hosts_when
      
      off_peak_start_time                  = var.weekend_off_peak_start_time
      off_peak_load_balancing_algorithm    = var.off_peak_load_balancing_algorithm
    }
  }
  
  # Associate scaling plan to host pool(s)
  dynamic "host_pool" {
    for_each = var.host_pool_ids
    content {
      hostpool_id          = host_pool.value
      scaling_plan_enabled = true
    }
  }
  
  tags = var.tags
}

# ============================================================================
# MONITORING ALERTS - Optional alerts for scaling health and cost anomalies
# ============================================================================

# Action Group for Alert Notifications (email/SMS)
resource "azurerm_monitor_action_group" "scaling_alerts" {
  count               = var.enable_monitoring_alerts && length(var.alert_emails) > 0 ? 1 : 0
  name                = "${var.scaling_plan_name}-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "ScaleAlerts"
  
  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "Email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
  
  tags = var.tags
}

# Alert 1: No Available Session Hosts During Business Hours
# ────────────────────────────────────────────────────────────────────────────
# Triggers when all session hosts are unavailable during peak hours (9 AM - 5 PM)
# This indicates a critical capacity issue or scaling failure
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "no_available_hosts" {
  count               = var.enable_monitoring_alerts && var.log_analytics_workspace_id != null ? 1 : 0
  name                = "${var.scaling_plan_name}-no-available-hosts"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  evaluation_frequency = "PT15M"  # Check every 15 minutes
  window_duration      = "PT15M"  # Look back 15 minutes
  scopes               = [var.log_analytics_workspace_id]
  severity             = 1  # Critical (0=Critical, 1=Error, 2=Warning, 3=Informational)
  
  criteria {
    query = <<-QUERY
      WVDConnections
      | where TimeGenerated > ago(15m)
      | where State == "Connected"
      | summarize ActiveConnections = dcount(CorrelationId) by bin(TimeGenerated, 5m)
      | join kind=leftouter (
          WVDAgentHealthStatus
          | where TimeGenerated > ago(15m)
          | where Status == "Available"
          | summarize AvailableHosts = dcount(SessionHostName) by bin(TimeGenerated, 5m)
      ) on TimeGenerated
      | where AvailableHosts == 0 or isnull(AvailableHosts)
      | where hourofday(TimeGenerated) >= 9 and hourofday(TimeGenerated) < 17  // Business hours: 9 AM - 5 PM
      | summarize NoHostsCount = count()
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1  # Alert if any occurrence
    operator                = "GreaterThan"
    
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }
  
  description = "No available session hosts detected during business hours (9 AM - 5 PM). This may indicate a scaling failure or capacity issue."
  enabled     = true
  
  action {
    action_groups = [azurerm_monitor_action_group.scaling_alerts[0].id]
  }
  
  tags = var.tags
}

# Alert 2: High Session Host CPU/Memory - Under-Scaling Detected
# ────────────────────────────────────────────────────────────────────────────
# Triggers when average CPU or memory exceeds threshold across multiple hosts
# This indicates insufficient capacity (need to scale up faster or adjust thresholds)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "high_resource_usage" {
  count               = var.enable_monitoring_alerts && var.log_analytics_workspace_id != null ? 1 : 0
  name                = "${var.scaling_plan_name}-high-resource-usage"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  evaluation_frequency = "PT15M"  # Check every 15 minutes
  window_duration      = "PT30M"  # Look back 30 minutes
  scopes               = [var.log_analytics_workspace_id]
  severity             = 2  # Warning (can be adjusted to 1 for Error)
  
  criteria {
    query = <<-QUERY
      // Get CPU and Memory metrics from VM Insights (InsightsMetrics table)
      InsightsMetrics
      | where TimeGenerated > ago(30m)
      | where Namespace == "Processor" and Name == "UtilizationPercentage"
         or Namespace == "Memory" and Name == "AvailableMB"
      | extend ComputerName = tostring(split(Computer, ".")[0])
      | extend ResourceType = iif(Computer contains "avd-sh" or Computer contains "sessionhost", "SessionHost", "Other")
      | where ResourceType == "SessionHost"
      | summarize 
          AvgCPU = avgif(Val, Namespace == "Processor"),
          AvgMemoryMB = avgif(Val, Namespace == "Memory"),
          HostCount = dcount(Computer)
        by bin(TimeGenerated, 5m), Computer
      | extend MemoryUsagePercent = 100 - (AvgMemoryMB / 8192 * 100)  // Assuming 8GB RAM, adjust as needed
      | where AvgCPU > ${var.high_cpu_threshold_percent} or MemoryUsagePercent > ${var.high_memory_threshold_percent}
      | summarize 
          HighUsageHosts = dcount(Computer),
          MaxCPU = max(AvgCPU),
          MaxMemory = max(MemoryUsagePercent)
      | where HighUsageHosts >= ${var.min_hosts_for_alert}  // Alert only if multiple hosts affected
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1  # Alert if any occurrence
    operator                = "GreaterThan"
    
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 2  # Require 2 consecutive periods (30 min)
      number_of_evaluation_periods             = 2
    }
  }
  
  description = "High CPU (>${var.high_cpu_threshold_percent}%) or Memory (>${var.high_memory_threshold_percent}%) usage detected on ${var.min_hosts_for_alert}+ session hosts. Scaling plan may need adjustment to scale up faster."
  enabled     = true
  
  action {
    action_groups = [azurerm_monitor_action_group.scaling_alerts[0].id]
  }
  
  tags = var.tags
}

# Alert 3: Too Many Hosts Running Off-Peak - Cost Anomaly
# ────────────────────────────────────────────────────────────────────────────
# Triggers when more than expected hosts are running during off-peak hours
# This indicates scaling plan not working correctly (cost waste)
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "off_peak_cost_anomaly" {
  count               = var.enable_monitoring_alerts && var.log_analytics_workspace_id != null ? 1 : 0
  name                = "${var.scaling_plan_name}-off-peak-cost-anomaly"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  evaluation_frequency = "PT1H"   # Check every hour
  window_duration      = "PT1H"   # Look back 1 hour
  scopes               = [var.log_analytics_workspace_id]
  severity             = 3  # Informational (cost issue, not availability)
  
  criteria {
    query = <<-QUERY
      // Count running session hosts during off-peak hours (7 PM - 7 AM, weekends)
      WVDAgentHealthStatus
      | where TimeGenerated > ago(1h)
      | where Status in ("Available", "NeedsAssistance")  // Running states
      | extend HourOfDay = hourofday(TimeGenerated)
      | extend DayOfWeek = dayofweek(TimeGenerated)
      | extend IsOffPeak = (HourOfDay >= 19 or HourOfDay < 7) or (DayOfWeek == 0d or DayOfWeek == 6d)  // 7 PM - 7 AM or Sat/Sun
      | where IsOffPeak
      | summarize RunningHosts = dcount(SessionHostName) by bin(TimeGenerated, 15m)
      | summarize AvgRunningHosts = avg(RunningHosts), MaxRunningHosts = max(RunningHosts)
      | where AvgRunningHosts > ${var.max_off_peak_hosts}  // Alert if exceeds threshold
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1  # Alert if any occurrence
    operator                = "GreaterThan"
    
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }
  
  description = "More than ${var.max_off_peak_hosts} session hosts running during off-peak hours (7 PM - 7 AM or weekends). Scaling plan may not be deallocating hosts correctly. Expected monthly cost waste: ~$${var.max_off_peak_hosts * 14 * 30 * 0.096}"
  enabled     = true
  
  action {
    action_groups = [azurerm_monitor_action_group.scaling_alerts[0].id]
  }
  
  tags = var.tags
}

# Alert 4: Scaling Plan Not Responding (Optional Diagnostic)
# ────────────────────────────────────────────────────────────────────────────
# Triggers when host count hasn't changed during expected scaling transitions
# This helps diagnose if scaling plan is stuck or not processing schedules
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "scaling_plan_stuck" {
  count               = var.enable_monitoring_alerts && var.enable_scaling_stuck_alert && var.log_analytics_workspace_id != null ? 1 : 0
  name                = "${var.scaling_plan_name}-not-responding"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  evaluation_frequency = "PT1H"   # Check every hour
  window_duration      = "PT3H"   # Look back 3 hours
  scopes               = [var.log_analytics_workspace_id]
  severity             = 2  # Warning
  
  criteria {
    query = <<-QUERY
      // Detect if session host count hasn't changed during scaling transitions
      WVDAgentHealthStatus
      | where TimeGenerated > ago(3h)
      | where Status in ("Available", "NeedsAssistance", "Shutdown")
      | extend HourOfDay = hourofday(TimeGenerated)
      | extend IsScalingTransition = (HourOfDay >= 7 and HourOfDay <= 9)   // Ramp-up
                                    or (HourOfDay >= 17 and HourOfDay <= 19) // Ramp-down
      | where IsScalingTransition
      | summarize 
          HostCount = dcount(SessionHostName),
          StartTime = min(TimeGenerated),
          EndTime = max(TimeGenerated)
        by bin(TimeGenerated, 30m)
      | summarize 
          MinHosts = min(HostCount),
          MaxHosts = max(HostCount),
          TransitionPeriods = count()
      | where MinHosts == MaxHosts and TransitionPeriods >= 4  // No change for 2+ hours during transition
    QUERY
    
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThan"
    
    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }
  
  description = "Scaling plan may not be responding. Session host count unchanged during expected scaling transitions (ramp-up/ramp-down). Check scaling plan configuration and host pool association."
  enabled     = true
  
  action {
    action_groups = [azurerm_monitor_action_group.scaling_alerts[0].id]
  }
  
  tags = var.tags
}
