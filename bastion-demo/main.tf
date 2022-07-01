terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider Backend
terraform {
  backend "azurerm" {
    resource_group_name  = "storage-services"
    storage_account_name = "centralstoragegeerkens"
    container_name       = "terraformstate"
    key                  = "bastion.terraform.tfstate"
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "bastion-resource-group"
  location = "West Europe"
}

# Create Hub vNet

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "demo-hub"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["172.16.0.0/20"]

  tags = {
    environment = "hub-network"
  }
}

# Create Azure Bastion

resource "azurerm_subnet" "bastion-subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["172.16.1.0/24"]
}

resource "azurerm_public_ip" "bastionpip" {
  name                = "bastionpip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "demo-bastion" {
  name                = "demo-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  ip_connect_enabled  = true
  shareable_link_enabled = true
  tunneling_enabled = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.bastionpip.id
  }
}

# Create hub-node

resource "azurerm_subnet" "hubvm-subnet" {
  name                 = "Hubvm-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["172.16.2.0/24"]
}

resource "azurerm_network_interface" "hubnode-nic" {
  name                = "hubnode-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hubvm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "hubnode" {
  name                = "hubnode"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "useyourownusername"
  admin_password      = "useyouronwpassword"
  disable_password_authentication = false
  custom_data = filebase64("worker_config.sh")

  network_interface_ids = [
    azurerm_network_interface.hubnode-nic.id
  ]

  os_disk {
    name                 = "hubnode-disk01"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

# Create Azure Firewall

resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefixes     = ["172.16.3.0/24"]
}

resource "azurerm_public_ip" "firewall-pip" {
  name                = "firewall-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "firewall" {
  name                = "Firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name = "AZFW_VNet"
  sku_tier = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.firewall-pip.id
  }
}

# Allow all traffic from local subnets

resource "azurerm_firewall_network_rule_collection" "allow-all-trafffic" {
  name                = "allow-all-trafffic"
  azure_firewall_name = azurerm_firewall.firewall.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"
  rule {
    name                  = "local-subnets"
    source_addresses      = ["172.16.0.0/16"]
    destination_addresses = ["*"]
    destination_ports     = ["*"]
    protocols             = ["Any"]
  }
}

# Create Route Table to Azure Firewall
resource "azurerm_route_table" "hub-firewall-rt" {
    name                          = "hub-firewall-rt"
    location                      = azurerm_resource_group.rg.location
    resource_group_name           = azurerm_resource_group.rg.name
    disable_bgp_route_propagation = false

    route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "172.16.3.4"
    }
    route {
    name           = "to-spoke"
    address_prefix = "172.16.17.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "172.16.3.4"
    }
}

resource "azurerm_subnet_route_table_association" "hubvm-rt-firewall" {
    subnet_id      = azurerm_subnet.hubvm-subnet.id
    route_table_id = azurerm_route_table.hub-firewall-rt.id
    depends_on = [azurerm_subnet.hubvm-subnet]
}

# Create Spoke vNet

resource "azurerm_virtual_network" "spoke-vnet" {
  name                = "demo-spoke"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["172.16.16.0/20"]

  tags = {
    environment = "spoke-network"
  }
}

# Create Spoke Subnet
resource "azurerm_subnet" "spokevm-subnet" {
  name                 = "Spokevm-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke-vnet.name
  address_prefixes     = ["172.16.17.0/24"]
}

# Create Spoke Worker Node

resource "azurerm_network_interface" "spokenode-nic" {
  name                = "spokenode-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "workerinternal"
    subnet_id                     = azurerm_subnet.spokevm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "spokenode" {
  name                = "spokenode"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "useyourownusername"
  admin_password      = "useyouronwpassword"
  disable_password_authentication = false
  custom_data = filebase64("worker_config.sh")

  network_interface_ids = [
    azurerm_network_interface.spokenode-nic.id,
  ]

  os_disk {
    name                 = "worker-disk01"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

# Create vnet peering

resource "azurerm_virtual_network_peering" "hub-spoke-peer" {
  name                      = "hub-spoke-peer"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.spoke-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
  use_remote_gateways       = false
  depends_on = [azurerm_virtual_network.spoke-vnet, azurerm_virtual_network.hub-vnet]
}

resource "azurerm_virtual_network_peering" "spoke-hub-peer" {
  name                      = "spoke-hub-peer"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = false
  depends_on = [azurerm_virtual_network.spoke-vnet, azurerm_virtual_network.hub-vnet]
}

resource "azurerm_route_table" "spoke-firewall-rt" {
    name                          = "spoke-firewall-rt"
    location                      = azurerm_resource_group.rg.location
    resource_group_name           = azurerm_resource_group.rg.name
    disable_bgp_route_propagation = false

    route {
    name           = "default"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "172.16.3.4"
    }
    route {
    name           = "to-hub"
    address_prefix = "172.16.2.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "172.16.3.4"
    }
}


resource "azurerm_subnet_route_table_association" "spokevm-rt-firewall" {
    subnet_id      = azurerm_subnet.spokevm-subnet.id
    route_table_id = azurerm_route_table.spoke-firewall-rt.id
    depends_on = [azurerm_subnet.spokevm-subnet]
}

# Create Spoke Standalone Subnet
resource "azurerm_subnet" "spoke-standalone-subnet" {
  name                 = "Spoke-standalone-Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke-vnet.name
  address_prefixes     = ["172.16.18.0/24"]
}

# Create Spoke Standalone Node

resource "azurerm_public_ip" "standalonenode-pip" {
  name                = "standalonenode-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "standalonenode-nic" {
  name                = "standalonenode-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "workerinternal"
    subnet_id                     = azurerm_subnet.spoke-standalone-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.standalonenode-pip.id
  }
}

resource "azurerm_linux_virtual_machine" "standalonenode" {
  name                = "standalonenode"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "useyourownusername"
  admin_password      = "useyouronwpassword"
  disable_password_authentication = false
  custom_data = filebase64("worker_config.sh")

  network_interface_ids = [
    azurerm_network_interface.standalonenode-nic.id,
  ]

  os_disk {
    name                 = "standalonenode-disk01"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

# Create nsg for standalone node
resource "azurerm_network_security_group" "standalone-nsg" {
  name                = "standalone-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Bastion-Allowed"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "172.16.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Denu-All-Others"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsglink-standalone" {
  network_interface_id      = azurerm_network_interface.standalonenode-nic.id
  network_security_group_id = azurerm_network_security_group.standalone-nsg.id
}

