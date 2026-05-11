############################################
# Input variables
############################################

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID for the deployment provider."
}

variable "location" {
  type        = string
  description = "Azure region for all created resources."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that will hold the Logic App, plan, storage account, and private endpoints."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources."
}

# --- Naming -----------------------------------------------------------------

variable "logic_app_base_name" {
  type        = string
  description = "Base name for the Logic App. The 4-char suffix is appended."
}

variable "app_service_plan_base_name" {
  type        = string
  description = "Base name for the App Service Plan. The 4-char suffix is appended."
}

variable "storage_account_base_name" {
  type        = string
  description = "Base name for the storage account (lowercase, <=20 chars before suffix). The 4-char suffix is appended."
}

variable "storage_account_replication_type" {
  type        = string
  default     = "LRS"
  description = "Replication type for the storage account (e.g., LRS, GRS, ZRS)."
}

variable "plan_sku" {
  type        = string
  default     = "WS1"
  description = "App Service Plan SKU (Logic App Standard requires WS1/WS2/WS3)."
}

# --- Networking (existing resources) ----------------------------------------

variable "vnet_resource_group" {
  type        = string
  description = "Resource group of the pre-existing virtual network."
}

variable "vnet_name" {
  type        = string
  description = "Name of the pre-existing virtual network."
}

variable "private_endpoint_subnet_name" {
  type        = string
  description = "Name of the existing subnet used for inbound storage private endpoints."
}

variable "integration_subnet_name" {
  type        = string
  description = "Name of the existing subnet (delegated to Microsoft.Web/serverFarms) used for Logic App outbound VNet integration."
}

variable "private_dns_zone_resource_group" {
  type        = string
  description = "Resource group of the pre-existing privatelink.* DNS zones. If null or empty, defaults to the deployment resource group."
}

variable "private_dns_zone_subscription_id" {
  type        = string
  description = "Subscription ID of the pre-existing privatelink.* DNS zones. If null or empty, defaults to the deployment subscription."
  default     = null
}
# --- Identity (UAMI) -----------------------------------------------

variable "uami_name" {
  type        = string
  description = "Name of the pre-existing User Assigned Managed Identity."
}

# --- Suffix -----------------------------------------------------------------

variable "name_suffix" {
  type        = string
  default     = ""
  description = "Optional 4-char lowercase suffix appended to resource names. If empty, a random one is generated."

  validation {
    condition     = var.name_suffix == "" || can(regex("^[a-z0-9]{4}$", var.name_suffix))
    error_message = "name_suffix must be exactly 4 lowercase alphanumeric characters, or empty."
  }
}
