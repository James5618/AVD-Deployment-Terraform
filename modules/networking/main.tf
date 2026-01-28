# ============================================================================
# Networking Module - Virtual Network, Subnets, NSGs
# ============================================================================

# Optional Resource Group (if create_resource_group = true)
resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Determine which resource group to use
locals {
  resource_group_name = var.create_resource_group ? azurerm_resource_group.rg[0].name : var.resource_group_name
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = local.resource_group_name
  address_space       = [var.vnet_address_space]
  
  # DNS servers - can be updated after DC deployment without recreating VNet
  dns_servers = var.dns_servers

  tags = var.tags

  # Allow DNS servers to be updated without recreating the VNet
  lifecycle {
    ignore_changes = [
      # Don't recreate VNet when DNS servers are added/updated
      tags["DeployedOn"],
    ]
  }

  depends_on = [
    azurerm_resource_group.rg
  ]
}

# Domain Controller Subnet
resource "azurerm_subnet" "dc" {
  name                 = var.dc_subnet_name
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.dc_subnet_prefix]
}

# AVD Session Hosts Subnet
resource "azurerm_subnet" "avd_hosts" {
  name                 = var.avd_subnet_name
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.avd_subnet_prefix]
}

# Storage Subnet (for Azure Files private endpoint)
resource "azurerm_subnet" "storage" {
  name                 = var.storage_subnet_name
  resource_group_name  = local.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.storage_subnet_prefix]
}

# Network Security Group for Domain Controller
resource "azurerm_network_security_group" "dc" {
  name                = "${var.dc_subnet_name}-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name

  # Allow RDP from VNet
  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow AD DS Authentication (Kerberos, LDAP)
  security_rule {
    name                       = "AllowADDS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["88", "389", "636", "3268", "3269"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow DNS
  security_rule {
    name                       = "AllowDNS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow Kerberos Password Change
  security_rule {
    name                       = "AllowKerberosPwdChange"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "464"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow SMB for SYSVOL/NETLOGON
  security_rule {
    name                       = "AllowSMB"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Network Security Group for AVD Session Hosts
resource "azurerm_network_security_group" "avd_hosts" {
  name                = "${var.avd_subnet_name}-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name

  # Allow RDP from VNet
  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow outbound to internet for AVD service connectivity
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = var.tags
}

# Network Security Group for Storage Subnet
resource "azurerm_network_security_group" "storage" {
  name                = "${var.storage_subnet_name}-nsg"
  location            = var.location
  resource_group_name = local.resource_group_name

  # Allow SMB from AVD subnet
  security_rule {
    name                       = "AllowSMB"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = var.avd_subnet_prefix
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "dc" {
  subnet_id                 = azurerm_subnet.dc.id
  network_security_group_id = azurerm_network_security_group.dc.id
}

resource "azurerm_subnet_network_security_group_association" "avd_hosts" {
  subnet_id                 = azurerm_subnet.avd_hosts.id
  network_security_group_id = azurerm_network_security_group.avd_hosts.id
}

resource "azurerm_subnet_network_security_group_association" "storage" {
  subnet_id                 = azurerm_subnet.storage.id
  network_security_group_id = azurerm_network_security_group.storage.id
}
