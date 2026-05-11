data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

data "azurerm_subnet" "subnet_pe" {
  name                 = var.private_endpoint_subnet_name
  resource_group_name  = var.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}

data "azurerm_subnet" "subnet_integration" {
  name                 = var.integration_subnet_name
  resource_group_name  = var.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.vnet.name
}