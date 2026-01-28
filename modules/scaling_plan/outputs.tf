# ============================================================================
# Scaling Plan Module - Outputs
# ============================================================================

output "scaling_plan_id" {
  description = "ID of the AVD scaling plan"
  value       = var.enabled ? azurerm_virtual_desktop_scaling_plan.scaling_plan[0].id : null
}

output "scaling_plan_name" {
  description = "Name of the AVD scaling plan"
  value       = var.enabled ? azurerm_virtual_desktop_scaling_plan.scaling_plan[0].name : null
}

output "scaling_plan_location" {
  description = "Azure region of the scaling plan"
  value       = var.enabled ? azurerm_virtual_desktop_scaling_plan.scaling_plan[0].location : null
}

output "timezone" {
  description = "Timezone configured for the scaling plan"
  value       = var.timezone
}

output "weekday_schedule_summary" {
  description = "Summary of weekday scaling schedule"
  value = var.enabled ? {
    ramp_up_start   = var.weekday_ramp_up_start_time
    peak_start      = var.weekday_peak_start_time
    ramp_down_start = var.weekday_ramp_down_start_time
    off_peak_start  = var.weekday_off_peak_start_time
  } : null
}

output "weekend_schedule_enabled" {
  description = "Whether weekend schedule is enabled"
  value       = var.enable_weekend_schedule
}

output "cost_savings_estimate" {
  description = "Estimated cost savings information"
  value = var.enabled ? {
    description             = "Auto-scaling can reduce VM costs by 60-80% by deallocating idle session hosts"
    weekday_off_peak_hours  = "~14 hours per weekday (7 PM - 7 AM)"
    weekend_hours           = var.enable_weekend_schedule ? "~48 hours per weekend" : "Not configured"
    monthly_savings_example = "Example: 4 VMs @ $0.096/hour × 14 off-peak hours × 22 weekdays + 48 weekend hours = ~$147/month savings"
  } : null
}

output "configuration_summary" {
  description = "Complete scaling plan configuration summary for documentation"
  value = var.enabled ? {
    name        = azurerm_virtual_desktop_scaling_plan.scaling_plan[0].name
    timezone    = var.timezone
    host_pools  = length(var.host_pool_ids)
    
    weekday = {
      ramp_up = {
        start_time          = var.weekday_ramp_up_start_time
        min_hosts_percent   = var.weekday_ramp_up_min_hosts_percent
        capacity_threshold  = var.weekday_ramp_up_capacity_threshold_percent
        load_balancing      = var.ramp_up_load_balancing_algorithm
      }
      peak = {
        start_time     = var.weekday_peak_start_time
        load_balancing = var.peak_load_balancing_algorithm
      }
      ramp_down = {
        start_time          = var.weekday_ramp_down_start_time
        min_hosts_percent   = var.weekday_ramp_down_min_hosts_percent
        capacity_threshold  = var.weekday_ramp_down_capacity_threshold_percent
        load_balancing      = var.ramp_down_load_balancing_algorithm
        force_logoff        = var.ramp_down_force_logoff_users
        wait_time_minutes   = var.ramp_down_wait_time_minutes
      }
      off_peak = {
        start_time     = var.weekday_off_peak_start_time
        load_balancing = var.off_peak_load_balancing_algorithm
      }
    }
    
    weekend_enabled = var.enable_weekend_schedule
  } : null
}
