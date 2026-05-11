# Private Logic App Standard (Terraform)

Terraform configuration that deploys an **Azure Logic App Standard** wired up for
private networking: storage access over Private Endpoints, outbound traffic via
VNet integration, and a User-Assigned Managed Identity (UAMI) used for storage
RBAC.

The project is intentionally small and opinionated — it targets a single
environment and assumes the surrounding network and identity primitives already
exist (VNet, subnets, Private DNS zones, UAMI).

---
## What gets deployed

All resources are created in the resource group provided via
`resource_group_name`.

| Resource | Terraform | Notes |
|---|---|---|
| App Service Plan (Windows, `WS1` by default) | `azurerm_service_plan.asp` | Hosts the Logic App Standard runtime. |
| Storage account (StorageV2, public access disabled) | `azurerm_storage_account.this` | Backing storage for the Logic App. `Deny` default network rule with `AzureServices` bypass. |
| Default file share (`<logic-app-name>-content`) | `azapi_resource.default_share` | Created via the management plane (AzAPI) because the data plane is private. Required by Terraform which otherwise would utilize direct calls to storage service. |
| Private Endpoints (blob / file / queue / table) | `azurerm_private_endpoint.this` (`for_each`) | Each PE is registered into the matching pre-existing `privatelink.*` DNS zone (can be in a different subscription/resource group). |
| Role assignments on the storage account | `azurerm_role_assignment.uami_storage` (`for_each`) | Grants the UAMI the roles needed by the Logic App runtime (see below). |
| Logic App Standard | `azurerm_logic_app_standard.logicapp` | VNet-integrated, `https_only`, identity-based storage wiring via `AzureWebJobsStorage__credential = ManagedIdentity`. |

### Storage RBAC granted to the UAMI
- Storage Account Contributor
- Storage Blob Data Owner
- Storage Queue Data Contributor
- Storage Table Data Contributor

### Networking model
```
                ┌────────────────────────┐
                │  Existing VNet         │
                │                        │
   Logic App ──►│  integration subnet    │──► Internet / Azure (egress)
  (outbound)    │  (delegated to         │
                │   Microsoft.Web/...    │
                │   serverFarms)         │
                │                        │
                │  PE subnet  ◄──────────┼── Private Endpoints (blob/file/queue/table)
                └────────────────────────┘
                            │
                            ▼
                Existing privatelink.* DNS zones
                (already linked to the VNet)
```

---

## Prerequisites

The configuration **does not** create networking, DNS, identity, or observability
resources. The following must exist before `terraform apply`:

1. **Azure subscription** with Owner/Contributor + User Access Administrator on
   the target resource group (role assignments are created here).
2. **Resource group** — `resource_group_name`.
3. **Virtual Network** — `vnet_name` in `vnet_resource_group`, containing:
   - A **Private Endpoint subnet** (`private_endpoint_subnet_name`).
   - An **integration subnet** (`integration_subnet_name`) delegated to
     `Microsoft.Web/serverFarms`.
4. **Private DNS zones** in `private_dns_zone_resource_group`, **already linked
   to the VNet**:
   - `privatelink.blob.core.windows.net`
   - `privatelink.file.core.windows.net`
   - `privatelink.queue.core.windows.net`
   - `privatelink.table.core.windows.net`
5. **User-Assigned Managed Identity** — `uami_name` in `uami_resource_group`.
6. **Log Analytics workspace** ID (used for diagnostic settings; can live in
   another subscription).
7. **Tooling**:
   - Terraform `>= 1.5.0`
   - Providers: `azurerm ~> 4.0`, `random ~> 3.6`, `azapi ~> 2.0`
   - Azure CLI (`az login`) for authentication, or any other mechanism the
     `azurerm` provider supports (env vars, OIDC, MSI, etc.).

---

## Usage

```powershell
cd terraform

# 1. Create your tfvars from the template
Copy-Item terraform.tfvars.example terraform.tfvars
# ...edit terraform.tfvars to match your environment

# 2. Authenticate
az login
$env:ARM_SUBSCRIPTION_ID = "<your-subscription-id>"

# 3. Initialize and validate
terraform init
terraform validate
terraform fmt

# 4. Plan and apply
terraform plan -out tfplan
terraform apply tfplan
```

### Inputs
See [`terraform/variables.tf`](terraform/variables.tf) for the full list and
[`terraform/terraform.tfvars.example`](terraform/terraform.tfvars.example) for a
filled-in template. Key inputs:

| Variable | Required | Description |
|---|---|---|
| `subscription_id` | yes | Target subscription. |
| `location` | yes | Azure region for created resources. |
| `resource_group_name` | yes | RG that holds the new resources. |
| `logic_app_base_name` / `app_service_plan_base_name` / `storage_account_base_name` | yes | Base names; a 4-char suffix is appended. |
| `vnet_resource_group` / `vnet_name` | yes | Existing VNet. |
| `private_endpoint_subnet_name` / `integration_subnet_name` | yes | Existing subnets. |
| `private_dns_zone_resource_group` | yes | RG holding the four `privatelink.*` zones. |
| `uami_resource_group` / `uami_name` | yes | Existing UAMI. |
| `log_analytics_workspace_id` | yes | Diagnostics destination. |
| `plan_sku` | no (`WS1`) | Logic App Standard plan SKU (`WS1`/`WS2`/`WS3`). |
| `storage_account_replication_type` | no (`LRS`) | Storage replication. |
| `name_suffix` | no | Pin the 4-char suffix instead of randomizing. |

### Cleanup
```powershell
terraform destroy
```

---

## Repository layout

```
.
├── README.md                  # This file
├── private_logic_app.azcli    # Equivalent shell-script deployment (az CLI)
├── ARM/                       # ARM-template equivalent
├── bicep/                     # Bicep equivalent
└── terraform/                 # ◄── primary deployment
    ├── providers.tf           # Provider + required_version pins
    ├── variables.tf           # Input variables
    ├── locals.tf              # Naming, network IDs, RBAC map
    ├── main.storage.tf        # Storage account, share, PEs, RBAC
    ├── main.logic.app.tf      # App Service Plan + Logic App Standard
    └── terraform.tfvars.example
```

---

## License

Released under the [MIT License](LICENSE). Use it freely; please retain the
copyright notice in derivative work.
