############################################
# Consolidated locals
############################################

locals {
  # --- Naming -------------------------------------------------------------
  name_suffix    = var.name_suffix != "" ? var.name_suffix : random_string.suffix.result
  logic_app_name = "${var.logic_app_base_name}-${local.name_suffix}"
  asp_name       = "${var.app_service_plan_base_name}-${local.name_suffix}"

  # --- Storage ------------------------------------------------------------
  storage_account_name = "${var.storage_account_base_name}${local.name_suffix}"
  storage_rg_name      = var.resource_group_name
  storage_location     = var.location

  # --- Networking ---------------------------------------------------------
  private_dns_zone_base = "/subscriptions/${coalesce(var.private_dns_zone_subscription_id, var.subscription_id)}/resourceGroups/${coalesce(var.private_dns_zone_resource_group, var.resource_group_name)}/providers/Microsoft.Network/privateDnsZones"

  # Existing Private DNS zones (already linked to the VNet).
  private_dns_zone_ids = {
    blob  = "${local.private_dns_zone_base}/privatelink.blob.core.windows.net"
    file  = "${local.private_dns_zone_base}/privatelink.file.core.windows.net"
    queue = "${local.private_dns_zone_base}/privatelink.queue.core.windows.net"
    table = "${local.private_dns_zone_base}/privatelink.table.core.windows.net"
  }

  # RBAC roles to assign to the UAMI on the storage account.
  storage_role_assignments = {
    account_contributor = "Storage Account Contributor"
    blob_data_owner     = "Storage Blob Data Owner"
    queue_data          = "Storage Queue Data Contributor"
    table_data          = "Storage Table Data Contributor"
  }
}
