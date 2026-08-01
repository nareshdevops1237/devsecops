output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "virtual_network_ids" {
  description = "Map of VNet name -> resource ID"
  value       = { for k, v in azurerm_virtual_network.this : k => v.id }
}

output "virtual_network_address_spaces" {
  value = { for k, v in azurerm_virtual_network.this : k => v.address_space }
}

output "app_public_ip" {
  value = azurerm_public_ip.app_pip.ip_address
}

output "db_public_ip" {
  value = azurerm_public_ip.db_pip.ip_address
}