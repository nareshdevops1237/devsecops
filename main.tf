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
        vnet_key          = vnet_key
        subnet_name       = subnet_key
        address_prefixes  = subnet.address_prefixes
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
