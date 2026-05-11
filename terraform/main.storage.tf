############################################
# Storage account + private endpoints
#
# Pre-existing resources expected:
#   - Subnet for private endpoints
#   - Private DNS zones for blob/file/queue/table
############################################

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = local.storage_rg_name
  location                 = local.storage_location
  account_tier             = "Standard"
  account_replication_type = var.storage_account_replication_type
  account_kind             = "StorageV2"

  tags = var.tags

  # Disable public network access entirely.
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = true
  default_to_oauth_authentication = true
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

# Initial empty file share. Created via the management plane (AzAPI) so it works
# even though the storage account has public network access disabled.
resource "azapi_resource" "default_share" {
  type      = "Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01"
  name      = "${local.logic_app_name}-content" # Name of the file share important and must match Logic App resource name with "-content" suffix.
  parent_id = "${azurerm_storage_account.this.id}/fileServices/default"

  body = {
    properties = {
      shareQuota       = 100
      enabledProtocols = "SMB"
      accessTier       = "TransactionOptimized"
    }
  }
}

############################################
# Private endpoints (blob / file / queue / table)
############################################

resource "azurerm_private_endpoint" "this" {
  for_each = local.private_dns_zone_ids

  name                = "pe-${local.storage_account_name}-${each.key}"
  location            = local.storage_location
  resource_group_name = local.storage_rg_name
  subnet_id           = data.azurerm_subnet.subnet_pe.id

  private_service_connection {
    name                           = "psc-${local.storage_account_name}-${each.key}"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [each.value]
  }
}

############################################
# RBAC: assign roles on the storage account to the UAMI
############################################

resource "azurerm_role_assignment" "uami_storage" {
  for_each = local.storage_role_assignments

  scope                = azurerm_storage_account.this.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.uami.principal_id
  principal_type       = "ServicePrincipal"
}

