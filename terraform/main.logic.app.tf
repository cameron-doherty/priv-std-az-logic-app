# 4-char lowercase suffix appended to resource names.
# (Variable definition lives in variables.tf.)
resource "random_string" "suffix" {
  length  = 4
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_user_assigned_identity" "uami" {
  name                = var.uami_name
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_service_plan" "asp" {
  name                = local.asp_name
  location            = local.storage_location
  resource_group_name = local.storage_rg_name
  os_type             = "Windows"
  sku_name            = var.plan_sku

  depends_on = [azurerm_role_assignment.uami_storage]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on      = [azurerm_role_assignment.uami_storage, azurerm_private_endpoint.this]
  create_duration = "60s"
}

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
    #AzureWebJobsStorage__managedIdentityResourceId = local.uami_resource_id
    AzureWebJobsStorage__managedIdentityResourceId = azurerm_user_assigned_identity.uami.id
    WEBSITE_VNET_ROUTE_ALL                         = "1"
    WEBSITE_CONTENTOVERVNET                        = "1"
    #WEBSITE_DNS_SERVER                             = "168.63.129.16"

    FUNCTIONS_INPROC_NET8_ENABLED = "1"
    LOGIC_APPS_POWERSHELL_VERSION = "7.4"
    #WEBSITE_NODE_DEFAULT_VERSION = "~20"

    #FUNCTIONS_EXTENSION_VERSION          = "~4"
    #AzureFunctionsJobHost__extensionBundle__id = "Microsoft.Azure.Functions.ExtensionBundle.Workflows"
    #AzureFunctionsJobHost__extensionBundle__version = "[1.*, 2.0.0)"
    #APP_KIND = "functionapp,workflowapp"
  }
}