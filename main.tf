terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# --- Variables for VM Credentials ---
variable "admin_username" {
  default = "azureadmin"
}
variable "admin_password" {
  default = "Password1234!" # CHANGE BEFORE DEPLOYING
}

# --- 1. Resource Group ---
resource "azurerm_resource_group" "rg" {
  name     = "RG-HubSpoke-Lab"
  location = "West US"
}

# --- 2. Virtual Networks ---
resource "azurerm_virtual_network" "hub" {
  name                = "VN-Hub"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/24"]
}

resource "azurerm_virtual_network" "spoke_hr" {
  name                = "VN-HR"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.1.0/24"]
}

resource "azurerm_virtual_network" "spoke_finance" {
  name                = "VN-Finance"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.2.0/24"]
}

resource "azurerm_virtual_network" "spoke_it" {
  name                = "VN-IT"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.3.0/24"]
}

# --- 3. Subnets ---
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.64/26"]
}

resource "azurerm_subnet" "hr_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke_hr.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "finance_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke_finance.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "it_default" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.spoke_it.name
  address_prefixes     = ["10.0.3.0/24"]
}

# --- 4. Public IPs for Core Services ---
resource "azurerm_public_ip" "bastion_pip" {
  name                = "vn-hub-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "firewall_pip" {
  name                = "vn-hub-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- 5. Core Services (Bastion & Firewall) ---
resource "azurerm_bastion_host" "bastion" {
  name                = "VN-Hub-Bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }
}

resource "azurerm_firewall" "firewall" {
  name                = "VN-Hub-Firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.firewall_pip.id
  }
}

# --- 6. VNet Peering (Hub <-> Spokes) ---
# Hub to HR
resource "azurerm_virtual_network_peering" "hub_to_hr" {
  name                      = "Peer-Hub-to-HR"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_hr.id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "hr_to_hub" {
  name                      = "Peer-HR-to-Hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_hr.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# Hub to Finance
resource "azurerm_virtual_network_peering" "hub_to_finance" {
  name                      = "Peer-Hub-to-Finance"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_finance.id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "finance_to_hub" {
  name                      = "Peer-Finance-to-Hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_finance.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# Hub to IT
resource "azurerm_virtual_network_peering" "hub_to_it" {
  name                      = "Peer-Hub-to-IT"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_it.id
  allow_forwarded_traffic   = true
}
resource "azurerm_virtual_network_peering" "it_to_hub" {
  name                      = "Peer-IT-to-Hub"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_it.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}

# --- 7. Route Table & Routing ---
resource "azurerm_route_table" "spoke_routes" {
  name                = "RT-Spokes-To-Firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  route {
    name                   = "Route-Internal-To-Firewall"
    address_prefix         = "10.0.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "hr_assoc" {
  subnet_id      = azurerm_subnet.hr_default.id
  route_table_id = azurerm_route_table.spoke_routes.id
}
resource "azurerm_subnet_route_table_association" "finance_assoc" {
  subnet_id      = azurerm_subnet.finance_default.id
  route_table_id = azurerm_route_table.spoke_routes.id
}
resource "azurerm_subnet_route_table_association" "it_assoc" {
  subnet_id      = azurerm_subnet.it_default.id
  route_table_id = azurerm_route_table.spoke_routes.id
}

# --- 8. Virtual Machines (No Public IPs) ---

# VM-HR
resource "azurerm_network_interface" "nic_hr" {
  name                = "nic-hr"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.hr_default.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "vm_hr" {
  name                = "VM-HR"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_hr.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# VM-Finance
resource "azurerm_network_interface" "nic_finance" {
  name                = "nic-finance"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.finance_default.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "vm_finance" {
  name                = "VM-Finance"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_finance.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# VM-IT
resource "azurerm_network_interface" "nic_it" {
  name                = "nic-it"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.it_default.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_windows_virtual_machine" "vm_it" {
  name                = "VM-IT"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic_it.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}
