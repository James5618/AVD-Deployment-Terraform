# ============================================================================
# AVD QUICKSTART - Single-File POC Deployment
# ============================================================================
# PROOF OF CONCEPT ONLY - Not for production use
# 
# This single file deploys a complete AVD environment:
# - Virtual Network with 3 subnets (DC, AVD, Storage)
# - 1 Domain Controller (AD DS with AVD OU)
# - AVD Workspace, Host Pool, Desktop App Group
# - 2 Session Hosts (domain-joined)
# - Storage Account with Azure Files "user-profiles" share
#
# QUICK START:
# 1. Copy terraform.tfvars.example to terraform.tfvars
# 2. Edit USER CONFIG section below (lines 20-70)
# 3. Run: terraform init && terraform plan && terraform apply
# ============================================================================

# ============================================================================
# USER CONFIG - EDIT THESE SETTINGS
# ============================================================================
locals {
  # ─────────────────────────────────────────────────────────────────────────
  # BASIC SETTINGS
  # ─────────────────────────────────────────────────────────────────────────
  project_name   = "avdquickstart"  # Short name (lowercase, no spaces)
  environment    = "poc"             # Environment identifier
  location       = "East US"         # Azure region
  location_short = "eus"             # Short code for naming

  # ─────────────────────────────────────────────────────────────────────────
  # DOMAIN CONFIGURATION
  # ─────────────────────────────────────────────────────────────────────────
  domain_name             = "avd.local"           # FQDN for AD domain
  domain_netbios_name     = "AVD"                 # NetBIOS name
  domain_admin_username   = "avdadmin"            # Domain admin username
  domain_admin_password   = "ChangeMe123!"        # Use terraform.tfvars!
  dc_private_ip           = "10.0.1.4"            # Static IP for DC
  avd_ou_name             = "AVD"                 # OU name for session hosts

  # ─────────────────────────────────────────────────────────────────────────
  # NETWORK CONFIGURATION
  # ─────────────────────────────────────────────────────────────────────────
  vnet_address_space    = ["10.0.0.0/16"]
  dc_subnet_prefix      = "10.0.1.0/24"
  avd_subnet_prefix     = "10.0.2.0/24"
  storage_subnet_prefix = "10.0.3.0/24"

  # ─────────────────────────────────────────────────────────────────────────
  # VM SIZING (Minimal specs for POC)
  # ─────────────────────────────────────────────────────────────────────────
  dc_vm_size           = "Standard_B2ms"    # DC: 2vCPU, 8GB RAM
  session_host_vm_size = "Standard_D4s_v5"  # Session hosts: 4vCPU, 16GB RAM
  session_host_count   = 2                  # Number of session hosts

  # ─────────────────────────────────────────────────────────────────────────
  # AVD CONFIGURATION
  # ─────────────────────────────────────────────────────────────────────────
  hostpool_type            = "Pooled"       # Pooled or Personal
  load_balancer_type       = "BreadthFirst" # BreadthFirst or DepthFirst
  maximum_sessions_allowed = 10             # Max users per session host
  
  # AVD Users - Add user UPNs who need access (must exist in Entra ID)
  avd_users = [
    "user1@yourdomain.com",
    "user2@yourdomain.com"
  ]

  # ─────────────────────────────────────────────────────────────────────────
  # STORAGE CONFIGURATION
  # ─────────────────────────────────────────────────────────────────────────
  storage_account_tier     = "Standard"  # Standard or Premium
  storage_replication_type = "LRS"       # LRS, GRS, RAGRS
  fslogix_share_quota_gb   = 100         # Profile share quota in GB

  # ─────────────────────────────────────────────────────────────────────────
  # COMPUTED VALUES - Don't edit below this line
  # ─────────────────────────────────────────────────────────────────────────
  resource_group_name  = "${local.project_name}-${local.environment}-rg"
  vnet_name            = "${local.project_name}-${local.environment}-vnet"
  dc_name              = "${upper(local.environment)}-DC01"
  workspace_name       = "${local.project_name}-${local.environment}-ws"
  hostpool_name        = "${local.project_name}-${local.environment}-hp"
  app_group_name       = "${local.project_name}-${local.environment}-dag"
  session_host_prefix  = "${local.environment}-sh"
  storage_account_name = "${replace(lower(local.project_name), "-", "")}${lower(local.environment)}fs"
  
  common_tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "Terraform"
    Purpose     = "POC"
  }
}

# ============================================================================
# TERRAFORM & PROVIDER CONFIGURATION
# ============================================================================
terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "azurerm_client_config" "current" {}

# Get AVD user objects from Entra ID
data "azuread_user" "avd_users" {
  for_each            = toset(local.avd_users)
  user_principal_name = each.value
}

# ============================================================================
# RESOURCE GROUP
# ============================================================================

resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags
}

# ============================================================================
# STEP 1: NETWORKING
# ============================================================================

resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = local.vnet_address_space
  dns_servers         = []  # Initially empty, updated after DC deployment
  tags                = local.common_tags
}

resource "azurerm_subnet" "dc_subnet" {
  name                 = "snet-dc"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.dc_subnet_prefix]
}

resource "azurerm_subnet" "avd_subnet" {
  name                 = "snet-avd"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.avd_subnet_prefix]
}

resource "azurerm_subnet" "storage_subnet" {
  name                 = "snet-storage"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [local.storage_subnet_prefix]
}

# Network Security Group for DC Subnet
resource "azurerm_network_security_group" "dc_nsg" {
  name                = "${local.dc_name}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowDNS"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowKerberos"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLDAP"
    priority                   = 1030
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowLDAPSSL"
    priority                   = 1040
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "dc_nsg_assoc" {
  subnet_id                 = azurerm_subnet.dc_subnet.id
  network_security_group_id = azurerm_network_security_group.dc_nsg.id
}

# Network Security Group for AVD Subnet
resource "azurerm_network_security_group" "avd_nsg" {
  name                = "nsg-avd"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowRDPFromVNet"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "avd_nsg_assoc" {
  subnet_id                 = azurerm_subnet.avd_subnet.id
  network_security_group_id = azurerm_network_security_group.avd_nsg.id
}

# ============================================================================
# STEP 2: DOMAIN CONTROLLER
# ============================================================================

resource "azurerm_network_interface" "dc_nic" {
  name                = "${local.dc_name}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.dc_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.dc_private_ip
  }
}

resource "azurerm_windows_virtual_machine" "dc" {
  name                = local.dc_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = local.dc_vm_size
  admin_username      = local.domain_admin_username
  admin_password      = local.domain_admin_password
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.dc_nic.id
  ]

  os_disk {
    name                 = "${local.dc_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Install AD DS and create AVD OU
resource "azurerm_virtual_machine_extension" "dc_adds" {
  name                       = "InstallADDS"
  virtual_machine_id         = azurerm_windows_virtual_machine.dc.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = <<-EOT
      powershell -ExecutionPolicy Unrestricted -Command "
        Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools;
        Import-Module ADDSDeployment;
        Install-ADDSForest `
          -DomainName '${local.domain_name}' `
          -DomainNetbiosName '${local.domain_netbios_name}' `
          -SafeModeAdministratorPassword (ConvertTo-SecureString '${local.domain_admin_password}' -AsPlainText -Force) `
          -InstallDns `
          -Force `
          -NoRebootOnCompletion;
        Start-Sleep -Seconds 30;
        Restart-Computer -Force;
      "
    EOT
  })
}

# Wait for DC reboot and create OU
resource "azurerm_virtual_machine_extension" "dc_create_ou" {
  name                       = "CreateAVDOU"
  virtual_machine_id         = azurerm_windows_virtual_machine.dc.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = <<-EOT
      powershell -ExecutionPolicy Unrestricted -Command "
        Start-Sleep -Seconds 120;
        Import-Module ActiveDirectory;
        $domainDN = (Get-ADDomain).DistinguishedName;
        $ouPath = 'OU=${local.avd_ou_name},' + $domainDN;
        if (-not (Get-ADOrganizationalUnit -Filter 'Name -eq \"${local.avd_ou_name}\"' -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name '${local.avd_ou_name}' -Path $domainDN -Description 'AVD Session Hosts' -ProtectedFromAccidentalDeletion `$false;
        }
      "
    EOT
  })

  depends_on = [azurerm_virtual_machine_extension.dc_adds]
}

# ============================================================================
# STEP 3: UPDATE VNET DNS TO POINT TO DC
# ============================================================================

resource "null_resource" "update_vnet_dns" {
  triggers = {
    dc_id = azurerm_windows_virtual_machine.dc.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      az network vnet update `
        --resource-group ${azurerm_resource_group.rg.name} `
        --name ${azurerm_virtual_network.vnet.name} `
        --dns-servers ${local.dc_private_ip}
    EOT
  }

  depends_on = [azurerm_virtual_machine_extension.dc_create_ou]
}

# ============================================================================
# STEP 4: AVD WORKSPACE, HOST POOL, APP GROUP
# ============================================================================

resource "azurerm_virtual_desktop_workspace" "workspace" {
  name                = local.workspace_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  friendly_name       = "AVD Workspace"
  description         = "AVD Quickstart POC Workspace"
  tags                = local.common_tags
}

resource "azurerm_virtual_desktop_host_pool" "hostpool" {
  name                     = local.hostpool_name
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  type                     = local.hostpool_type
  load_balancer_type       = local.load_balancer_type
  maximum_sessions_allowed = local.maximum_sessions_allowed
  friendly_name            = "AVD Host Pool"
  description              = "AVD Quickstart POC Host Pool"
  validate_environment     = false
  start_vm_on_connect      = false
  tags                     = local.common_tags
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "registration" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.hostpool.id
  expiration_date = timeadd(timestamp(), "48h")
}

resource "azurerm_virtual_desktop_application_group" "app_group" {
  name                = local.app_group_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  type                = "Desktop"
  host_pool_id        = azurerm_virtual_desktop_host_pool.hostpool.id
  friendly_name       = "Desktop App Group"
  description         = "Default desktop application group"
  tags                = local.common_tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "ws_app_group" {
  workspace_id         = azurerm_virtual_desktop_workspace.workspace.id
  application_group_id = azurerm_virtual_desktop_application_group.app_group.id
}

# Assign AVD users to the desktop app group
resource "azurerm_role_assignment" "avd_user_assignment" {
  for_each             = data.azuread_user.avd_users
  scope                = azurerm_virtual_desktop_application_group.app_group.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = each.value.object_id
}

# ============================================================================
# STEP 5: STORAGE ACCOUNT & AZURE FILES SHARE
# ============================================================================

resource "azurerm_storage_account" "fslogix" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = local.storage_account_tier
  account_replication_type = local.storage_replication_type
  account_kind             = "StorageV2"
  
  azure_files_authentication {
    directory_type = "AADDS"  # Use AD DS for domain integration
  }

  tags = local.common_tags

  depends_on = [null_resource.update_vnet_dns]
}

resource "azurerm_storage_share" "profiles" {
  name                 = "user-profiles"
  storage_account_name = azurerm_storage_account.fslogix.name
  quota                = local.fslogix_share_quota_gb
}

# ============================================================================
# STEP 6: SESSION HOSTS
# ============================================================================

resource "azurerm_network_interface" "session_host_nic" {
  count               = local.session_host_count
  name                = "${local.session_host_prefix}-${count.index + 1}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.avd_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "session_host" {
  count               = local.session_host_count
  name                = "${local.session_host_prefix}-${count.index + 1}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = local.session_host_vm_size
  admin_username      = local.domain_admin_username
  admin_password      = local.domain_admin_password
  tags                = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.session_host_nic[count.index].id
  ]

  os_disk {
    name                 = "${local.session_host_prefix}-${count.index + 1}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-11"
    sku       = "win11-23h2-avd"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    null_resource.update_vnet_dns,
    azurerm_virtual_machine_extension.dc_create_ou
  ]
}

# Domain join session hosts
resource "azurerm_virtual_machine_extension" "domain_join" {
  count                      = local.session_host_count
  name                       = "DomainJoin"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "JsonADDomainExtension"
  type_handler_version       = "1.3"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    Name    = local.domain_name
    OUPath  = "OU=${local.avd_ou_name},DC=${split(".", local.domain_name)[0]},DC=${split(".", local.domain_name)[1]}"
    User    = "${local.domain_netbios_name}\\${local.domain_admin_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = local.domain_admin_password
  })
}

# Install AVD Agent
resource "azurerm_virtual_machine_extension" "avd_agent" {
  count                      = local.session_host_count
  name                       = "AVDAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.session_host[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  protected_settings = jsonencode({
    commandToExecute = <<-EOT
      powershell -ExecutionPolicy Unrestricted -Command "
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
        $agentUrl = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Microsoft_Azure_VirtualDesktop-Agent/Microsoft.RDInfra.RDAgent_1.0.8668.2300.zip';
        $bootloaderUrl = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Microsoft_Azure_VirtualDesktop-Agent-BootLoader/Microsoft.RDInfra.RDAgentBootLoader_1.0.8001.2300.zip';
        Invoke-WebRequest -Uri $agentUrl -OutFile 'C:\\AVDAgent.zip';
        Expand-Archive -Path 'C:\\AVDAgent.zip' -DestinationPath 'C:\\AVDAgent' -Force;
        Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i C:\\AVDAgent\\Microsoft.RDInfra.RDAgent.Installer-x64.msi /quiet REGISTRATIONTOKEN=${azurerm_virtual_desktop_host_pool_registration_info.registration.token}' -Wait;
        Invoke-WebRequest -Uri $bootloaderUrl -OutFile 'C:\\AVDBootloader.zip';
        Expand-Archive -Path 'C:\\AVDBootloader.zip' -DestinationPath 'C:\\AVDBootloader' -Force;
        Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i C:\\AVDBootloader\\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi /quiet' -Wait;
      "
    EOT
  })

  depends_on = [azurerm_virtual_machine_extension.domain_join]
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "workspace_id" {
  value = azurerm_virtual_desktop_workspace.workspace.id
}

output "hostpool_name" {
  value = azurerm_virtual_desktop_host_pool.hostpool.name
}

output "dc_private_ip" {
  value = local.dc_private_ip
}

output "storage_account_name" {
  value = azurerm_storage_account.fslogix.name
}

output "profiles_share_name" {
  value = azurerm_storage_share.profiles.name
}

output "session_host_names" {
  value = [for vm in azurerm_windows_virtual_machine.session_host : vm.name]
}
