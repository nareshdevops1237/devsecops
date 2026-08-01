resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "this" {
  for_each = var.virtual_networks

  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = each.value.address_space
  tags                = each.value.tags
}


# Flatten vnet -> subnet map so each subnet is its own resource instance
locals {
  subnets = merge([
    for vnet_key, vnet in var.virtual_networks : {
      for subnet_key, subnet in vnet.subnets :
      "${vnet_key}.${subnet_key}" => {
        vnet_key         = vnet_key
        subnet_name      = subnet_key
        address_prefixes = subnet.address_prefixes
      }
    }
  ]...)
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = each.value.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[each.value.vnet_key].name
  address_prefixes     = each.value.address_prefixes
}

resource "azurerm_public_ip" "app_pip" {
  name                = "app-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_public_ip" "db_pip" {
  name                = "db-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  allocation_method = "Static"
  sku               = "Standard"
}
resource "azurerm_network_interface" "app_nic" {
  name                = "app-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name


  ip_configuration {
    name                          = "app-ip"
    subnet_id                     = azurerm_subnet.this["vnet-app.snet-app-web"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_pip.id
  }

}

resource "azurerm_network_interface" "db_nic" {
  name                = "db-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "db-ip"
    subnet_id                     = azurerm_subnet.this["vnet-app.snet-app-db"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.db_pip.id
  }

}

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "app-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = "Standard_D4ls_v7"

  admin_username = "azureuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  network_interface_ids = [
    azurerm_network_interface.app_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"  # <--- Matches the Gen2 x64 SKU from your output
    version   = "20.04.202505200" # <--- Matches the exact version you found, or use "latest
  }
}


resource "azurerm_linux_virtual_machine" "db_vm" {
  name                = "db-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  size                = "Standard_D4ls_v7"

  admin_username = "azureuser"

  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  network_interface_ids = [
    azurerm_network_interface.db_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"  # <--- Matches the Gen2 x64 SKU from your output
    version   = "20.04.202505200" # <--- Matches the exact version you found, or use "latest"
  }
}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_network_security_rule" "allow_ssh" {
  name                       = "allow-ssh"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app_nsg.name
}

resource "azurerm_network_security_rule" "allow_app" {
  name      = "allow-app"
  priority  = 110
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  destination_port_range = "8080"

  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app_nsg.name
}

resource "azurerm_network_security_rule" "allow_postgres" {
  name      = "allow-postgres"
  priority  = 120
  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range      = "*"
  destination_port_range = "5432"

  source_address_prefix      = "*"
  destination_address_prefix = "*"

  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.app_nsg.name
}
resource "azurerm_subnet_network_security_group_association" "app_assoc" {
  subnet_id                 = azurerm_subnet.this["vnet-app.snet-app-web"].id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}
resource "azurerm_subnet_network_security_group_association" "db_assoc" {
  subnet_id                 = azurerm_subnet.this["vnet-app.snet-app-db"].id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}