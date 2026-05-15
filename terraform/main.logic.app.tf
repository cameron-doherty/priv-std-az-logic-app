# 4-char lowercase suffix appended to resource names.
# (Variable definition lives in variables.tf.)
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

##########################################################
# Create User Assigned Managed Identity (UAMI)
##########################################################
resource "azurerm_user_assigned_identity" "uami" {
  name                = var.uami_name
  resource_group_name = var.resource_group_name
  location            = var.location
}


##########################################################
# Create App Service Plan (ASP)
##########################################################
resource "azurerm_service_plan" "asp" {
  name                = local.asp_name
  location            = local.storage_location
  resource_group_name = local.storage_rg_name
  os_type             = "Windows"
  sku_name            = var.plan_sku

  depends_on = [azurerm_role_assignment.uami_storage]
}


################################################################################################################
# Sleep resource used to introduce a delay after creating the role assignments and private endpoints, 
# to ensure that permissions and network configurations are fully propagated before the Logic App is 
# created. This helps avoid potential issues during Logic App provisioning related to RBAC or network access.
################################################################################################################

resource "time_sleep" "wait_30_seconds" {
  depends_on      = [azurerm_role_assignment.uami_storage, azurerm_private_endpoint.this]
  create_duration = "60s"
}


##########################################################
# Create Standard Workflow Logic App with vNet integration
##########################################################
resource "azurerm_logic_app_standard" "logicapp" {
  name                       = local.logic_app_name
  location                   = local.storage_location
  resource_group_name        = local.storage_rg_name
  app_service_plan_id        = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  public_network_access      = "Disabled"
  virtual_network_subnet_id  = data.azurerm_subnet.subnet_integration.id
  vnet_content_share_enabled = true
  enabled                    = true
  https_only                 = true
  version                    = "~4"

  tags = var.tags

  depends_on = [time_sleep.wait_30_seconds]


  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uami.id]
  }

  site_config {}

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "dotnet"
    AzureWebJobsStorage__credential      = "ManagedIdentity"
    AzureWebJobsStorage__blobServiceUri  = azurerm_storage_account.this.primary_blob_endpoint
    AzureWebJobsStorage__queueServiceUri = azurerm_storage_account.this.primary_queue_endpoint
    AzureWebJobsStorage__tableServiceUri = azurerm_storage_account.this.primary_table_endpoint
    AzureWebJobsStorage__managedIdentityResourceId = azurerm_user_assigned_identity.uami.id
    WEBSITE_VNET_ROUTE_ALL                         = "1"
    WEBSITE_CONTENTOVERVNET                        = "1"
    FUNCTIONS_INPROC_NET8_ENABLED = "1"
    LOGIC_APPS_POWERSHELL_VERSION = "7.4"
  }
}


####################################################################################
# Create private endpoint for the Logic App (connect to existing Private DNS zone)
####################################################################################
resource "azurerm_private_endpoint" "pe_logic_app" {

  name                = "pe-${azurerm_logic_app_standard.logicapp.name}"
  location            = azurerm_logic_app_standard.logicapp.location
  resource_group_name = azurerm_logic_app_standard.logicapp.resource_group_name
  subnet_id           = data.azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "psc-${azurerm_logic_app_standard.logicapp.name}"
    private_connection_resource_id = azurerm_logic_app_standard.logicapp.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [local.private_dns_zone_ids["logicapp"]]
  }
}