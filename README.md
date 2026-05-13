# Secured Logic App Deployment
Many environments have strict requirements around Azure PaaS services and how they must be configured from a network availability perspective. Specifically, they enforce that any PaaS resource, whether it be Storage or Key Vault or App Services, to have `Public Access` = `Disabled`.  

While this provides an excellent security posture by limiting public exposure, it does cause some friction in environments where users may be deploying resources in various manners (e.g. as code or via portal).

The purpose of this repository is to provide IaC templates that allow customers to deploy the following:

- A fully private Logic App
    - Public access disabled
    - Private Endpoint enabled on selected vnet/subnet
    - vNet injection for outbound communications (all outbound)
- User Assigned Managed Identity
    - Associated to Logic App for accessing dependent resource (storage) 
    - Granted specific RBAC roles on storage (blob, queue, table, file)
- A fully private Storage Account (dependent resource for standard Logic App)
    - Public access disabled
    - Private Endpoint enabled on selected vnet/subnet
- Integrates with existing resources

> [!WARNING]
> Due to current limitations with the Files service, which Logic App uses, the storage account must still have Access Keys enabled. Improvements are being made to allow for the use of Managed Identity with the Files service and once that is a supported pattern, Access Keys can be fully disabled.

# Prerequisites
Below are the prereqs for the templates:
- A virtual network with 2 subnets for the following:
    - Private Endpoints
    - Logic App vNet injection (**ensure appropriate sizing!**)
- Private Link DNS Zones for the following:
    - `privatelink.azurewebsites.net`
    - `privatelink.blob.core.windows.net`
    - `privatelink.file.core.windows.net`
    - `privatelink.queue.core.windows.net`
    - `privatelink.table.core.windows.net`
- Ensure vNet DNS configuration is configured to point to appropriate resolver service so that the aforementioned zones can successfully be resolved

# Current IaC Templates Available
Here is the list of available/planned IaC templates. Note that these are opinionated approaches to deploying the resources so please use these as a base and customize or integrate them into existing templates as needed.

- [Terraform](terraform/README.md)
- [Bicep](bicep/README.md)
- [ARM](arm/README.md)

