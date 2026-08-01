variable "resource_group_name" {
  description = "Name of the resource group that will hold the virtual networks"
  type        = string
  default     = "rg-networking-demo"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}


# One entry per VNet you want created. Add/remove entries here to
# scale beyond 2 without touching main.tf.
variable "virtual_networks" {
  description = "Map of virtual networks to create"
  type = map(object({
    address_space = list(string)
    subnets = map(object({
      address_prefixes = list(string)
    }))
    tags = optional(map(string), {})
  }))

  default = {
    vnet-app = {
      address_space = ["10.10.0.0/16"]
      subnets = {
        snet-app-web = { address_prefixes = ["10.10.1.0/24"] }
        snet-app-db  = { address_prefixes = ["10.10.2.0/24"] }
      }
      tags = { workload = "app" }
    }
    vnet-hub = {
      address_space = ["10.20.0.0/16"]
      subnets = {
        snet-hub-shared = { address_prefixes = ["10.20.1.0/24"] }
      }
      tags = { workload = "hub" }
    }
  }
}


variable "ssh_public_key" {
  type      = string
  sensitive = true
}