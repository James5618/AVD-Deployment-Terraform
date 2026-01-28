# ============================================================================
# Domain Controller Module - Minimal Windows Server VM with AD DS
# ============================================================================

# Network Interface for DC (no public IP)
resource "azurerm_network_interface" "dc" {
  name                = "${var.dc_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc_private_ip
  }

  tags = var.tags
}

# Domain Controller Virtual Machine - Minimal Spec
resource "azurerm_windows_virtual_machine" "dc" {
  name                  = var.dc_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.dc.id]
  size                  = var.dc_vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  timezone              = var.timezone

  os_disk {
    name                 = "${var.dc_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  tags = var.tags
}

# Custom Script Extension to install and configure AD DS
resource "azurerm_virtual_machine_extension" "dc_adds_install" {
  name                       = "InstallADDS"
  virtual_machine_id         = azurerm_windows_virtual_machine.dc.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"${local.adds_install_script}\""
  })

  tags = var.tags
}

# AD DS Installation and Configuration PowerShell Script
locals {
  # Calculate the OU DN from domain name
  # e.g., "contoso.local" -> "OU=AVD,DC=contoso,DC=local"
  domain_components = join(",", [for part in split(".", var.domain_name) : "DC=${part}"])
  avd_ou_dn         = "OU=${var.avd_ou_name},${local.domain_components}"

  adds_install_script = <<-EOT
    # ============================================================================
    # AD DS Installation and Configuration Script
    # ============================================================================
    
    $ErrorActionPreference = 'Stop'
    $VerbosePreference = 'Continue'
    
    # Log file for troubleshooting
    $LogFile = 'C:\Windows\Temp\ADDS-Install.log'
    Start-Transcript -Path $LogFile -Append
    
    Write-Output "Starting AD DS installation at $(Get-Date)"
    
    try {
        # Install AD DS role and management tools
        Write-Output "Installing AD DS Windows Feature..."
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools -Verbose
        
        # Import AD DS Deployment module
        Write-Output "Importing ADDSDeployment module..."
        Import-Module ADDSDeployment
        
        # Create secure string password for Safe Mode
        Write-Output "Preparing credentials..."
        $SecurePassword = ConvertTo-SecureString '${var.safe_mode_admin_password}' -AsPlainText -Force
        
        # Install new AD Forest
        Write-Output "Installing new AD Forest: ${var.domain_name}"
        Write-Output "NetBIOS Name: ${var.netbios_name}"
        
        Install-ADDSForest `
            -DomainName '${var.domain_name}' `
            -DomainNetbiosName '${var.netbios_name}' `
            -ForestMode 'WinThreshold' `
            -DomainMode 'WinThreshold' `
            -InstallDns:$true `
            -SafeModeAdministratorPassword $SecurePassword `
            -Force:$true `
            -NoRebootOnCompletion:$false `
            -Verbose
        
        # Note: The server will automatically reboot after AD DS installation
        # The OU creation will happen after reboot via scheduled task
        
        Write-Output "AD DS installation initiated successfully"
        
        # Create a scheduled task to run after reboot to create OU
        Write-Output "Creating post-reboot scheduled task for OU creation..."
        
        $OUCreationScript = @'
$ErrorActionPreference = 'Stop'
$LogFile = 'C:\Windows\Temp\OU-Creation.log'
Start-Transcript -Path $LogFile -Append

try {
    Write-Output "Starting OU creation at $(Get-Date)"
    
    # Wait for AD Web Services to be ready
    $maxRetries = 30
    $retryCount = 0
    
    while ($retryCount -lt $maxRetries) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            Get-ADDomain -ErrorAction Stop | Out-Null
            Write-Output "AD Web Services is ready"
            break
        }
        catch {
            $retryCount++
            Write-Output "Waiting for AD Web Services... (Attempt $retryCount/$maxRetries)"
            Start-Sleep -Seconds 10
        }
    }
    
    if ($retryCount -eq $maxRetries) {
        throw "AD Web Services did not become ready in time"
    }
    
    # Get the domain DN
    $DomainDN = (Get-ADDomain).DistinguishedName
    Write-Output "Domain DN: $DomainDN"
    
    # Create AVD OU if it doesn't exist
    $OUDN = "OU=${var.avd_ou_name},$DomainDN"
    Write-Output "Checking for OU: $OUDN"
    
    try {
        Get-ADOrganizationalUnit -Identity $OUDN -ErrorAction Stop | Out-Null
        Write-Output "OU already exists: $OUDN"
    }
    catch {
        Write-Output "Creating new OU: ${var.avd_ou_name}"
        New-ADOrganizationalUnit `
            -Name "${var.avd_ou_name}" `
            -Path $DomainDN `
            -Description "${var.avd_ou_description}" `
            -ProtectedFromAccidentalDeletion $true `
            -Verbose
        
        Write-Output "OU created successfully: $OUDN"
    }
    
    # Disable the scheduled task so it doesn't run again
    Write-Output "Disabling scheduled task..."
    Disable-ScheduledTask -TaskName "Create-AVD-OU" -ErrorAction SilentlyContinue
    
    Write-Output "OU creation completed successfully at $(Get-Date)"
}
catch {
    Write-Error "Error creating OU: $_"
    Write-Error $_.Exception.StackTrace
    exit 1
}
finally {
    Stop-Transcript
}
'@
        
        # Save the OU creation script
        $OUCreationScript | Out-File -FilePath 'C:\Windows\Temp\Create-OU.ps1' -Encoding UTF8 -Force
        
        # Create scheduled task to run after reboot
        $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-ExecutionPolicy Bypass -File C:\Windows\Temp\Create-OU.ps1'
        $Trigger = New-ScheduledTaskTrigger -AtStartup
        $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask `
            -TaskName "Create-AVD-OU" `
            -Action $Action `
            -Trigger $Trigger `
            -Principal $Principal `
            -Settings $Settings `
            -Description "Create AVD Organizational Unit after AD DS installation" `
            -Force
        
        Write-Output "Scheduled task created successfully"
        
    }
    catch {
        Write-Error "Error during AD DS installation: $_"
        Write-Error $_.Exception.StackTrace
        exit 1
    }
    finally {
        Stop-Transcript
    }
  EOT
}
