# ============================================================================
# Session Hosts Module - AVD Session Host VMs with Domain Join and AVD Registration
# ============================================================================

locals {
  # Determine if using custom gallery image or marketplace fallback
  use_custom_image = var.gallery_image_version_id != null
}

# Network Interface for each Session Host
resource "azurerm_network_interface" "session_host" {
  count               = var.vm_count
  name                = "${var.vm_name_prefix}-${count.index + 1}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  # Use VNet DNS servers (which point to DC) instead of Azure default
  dns_servers = var.vnet_dns_servers

  tags = var.tags
}

# Session Host Virtual Machines - Windows 11 Multi-Session
resource "azurerm_windows_virtual_machine" "session_host" {
  count                 = var.vm_count
  name                  = "${var.vm_name_prefix}-${count.index + 1}"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.session_host[count.index].id]
  size                  = var.vm_size
  admin_username        = var.local_admin_username
  admin_password        = var.local_admin_password
  license_type          = "Windows_Client"
  timezone              = var.timezone

  os_disk {
    name                 = "${var.vm_name_prefix}-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # ═══════════════════════════════════════════════════════════════════════
  # IMAGE SOURCE SELECTION - Simplified
  # ═══════════════════════════════════════════════════════════════════════
  # When gallery_image_version_id is provided:
  #   → Use custom image from Azure Compute Gallery (source_image_id)
  # When gallery_image_version_id is null:
  #   → Use default Azure Marketplace image (source_image_reference)
  #
  # This simplified approach eliminates multiple image source variables
  # and makes it clear: custom image OR marketplace fallback.
  # ═══════════════════════════════════════════════════════════════════════

  # Use gallery image if provided, otherwise use marketplace
  source_image_id = local.use_custom_image ? var.gallery_image_version_id : null

  # Marketplace image fallback (only when gallery_image_version_id is null)
  dynamic "source_image_reference" {
    for_each = local.use_custom_image ? [] : [1]
    content {
      publisher = var.marketplace_image_reference.publisher
      offer     = var.marketplace_image_reference.offer
      sku       = var.marketplace_image_reference.sku
      version   = var.marketplace_image_reference.version
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_network_interface.session_host
  ]
}

# Domain Join Extension - Join session hosts to AD domain
resource "azurerm_virtual_machine_extension" "domain_join" {
  count                      = var.vm_count
  name                       = "JsonADDomainExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    Name    = var.domain_name
    OUPath  = var.domain_ou_path
    User    = "${var.domain_netbios_name}\\${var.domain_admin_username}"
    Restart = "true"
    Options = "3"  # Join domain and create computer account
  })

  protected_settings = jsonencode({
    Password = var.domain_admin_password
  })

  tags = var.tags

  depends_on = [
    azurerm_windows_virtual_machine.session_host
  ]

  # Lifecycle to handle re-running if needed
  lifecycle {
    ignore_changes = [
      settings,
      protected_settings
    ]
  }
}

# AVD Agent Extension - Install and register session hosts to AVD host pool
resource "azurerm_virtual_machine_extension" "avd_agent" {
  count                      = var.vm_count
  name                       = "AVDAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"
    properties = {
      hostPoolName          = var.hostpool_name
      registrationInfoToken = var.hostpool_registration_token
      aadJoin               = false
    }
  })

  tags = var.tags

  depends_on = [
    azurerm_virtual_machine_extension.domain_join
  ]

  # Lifecycle to prevent re-registration issues
  lifecycle {
    ignore_changes = [
      settings
    ]
  }
}

# FSLogix Configuration Extension - Configure profile containers
resource "azurerm_virtual_machine_extension" "fslogix_config" {
  count                      = var.vm_count
  name                       = "FSLogixConfig"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${local.fslogix_config_script}\""
  })

  tags = var.tags

  depends_on = [
    azurerm_virtual_machine_extension.avd_agent
  ]
}

# FSLogix Configuration Script
locals {
  fslogix_config_script = <<-EOT
    # ============================================================================
    # FSLogix Profile Container Configuration
    # ============================================================================
    
    $ErrorActionPreference = 'Stop'
    $LogFile = 'C:\\Windows\\Temp\\FSLogix-Config.log'
    Start-Transcript -Path $LogFile -Append
    
    try {
        Write-Output "Starting FSLogix configuration at $(Get-Date)"
        Write-Output "Profile share path: ${var.fslogix_share_path}"
        
        # Create registry path if it doesn't exist
        $RegistryPath = 'HKLM:\\SOFTWARE\\FSLogix\\Profiles'
        
        if (!(Test-Path $RegistryPath)) {
            Write-Output "Creating FSLogix registry path..."
            New-Item -Path $RegistryPath -Force | Out-Null
        }
        
        # Enable FSLogix Profile Containers
        Write-Output "Enabling FSLogix Profile Containers..."
        Set-ItemProperty -Path $RegistryPath -Name 'Enabled' -Value 1 -Type DWord -Force
        
        # Set VHD location (Azure Files share)
        Write-Output "Setting VHD location to Azure Files share..."
        Set-ItemProperty -Path $RegistryPath -Name 'VHDLocations' -Value '${var.fslogix_share_path}' -Type String -Force
        
        # Delete local profile when FSLogix profile should be used
        Set-ItemProperty -Path $RegistryPath -Name 'DeleteLocalProfileWhenVHDShouldApply' -Value 1 -Type DWord -Force
        
        # Set profile type to use VHD
        Set-ItemProperty -Path $RegistryPath -Name 'ProfileType' -Value 0 -Type DWord -Force
        
        # Prevent concurrent sessions (recommended for pooled)
        Set-ItemProperty -Path $RegistryPath -Name 'ConcurrentUserSessions' -Value 0 -Type DWord -Force
        
        # Set VHD size (in MB) - 30GB default
        Set-ItemProperty -Path $RegistryPath -Name 'SizeInMBs' -Value 30720 -Type DWord -Force
        
        # Dynamic disk type
        Set-ItemProperty -Path $RegistryPath -Name 'IsDynamic' -Value 1 -Type DWord -Force
        
        # Volume type (VHDX)
        Set-ItemProperty -Path $RegistryPath -Name 'VolumeType' -Value 'VHDX' -Type String -Force
        
        # Flip Flop Profile Directory Name
        Set-ItemProperty -Path $RegistryPath -Name 'FlipFlopProfileDirectoryName' -Value 1 -Type DWord -Force
        
        # Access network as computer object (for Azure Files AD integration)
        Set-ItemProperty -Path $RegistryPath -Name 'AccessNetworkAsComputerObject' -Value 1 -Type DWord -Force
        
        Write-Output "FSLogix configuration completed successfully"
        
        # Verify configuration
        Write-Output "Verifying FSLogix settings..."
        Get-ItemProperty -Path $RegistryPath | Format-List
        
    }
    catch {
        Write-Error "Error configuring FSLogix: $_"
        Write-Error $_.Exception.StackTrace
        exit 1
    }
    finally {
        Stop-Transcript
    }
  EOT
}
