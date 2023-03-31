# Terraform configuration

## Terraform modules  

- Azure App Service configuration [Terraform Azure App Service reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service)
- Azure Application Insights configuration [Terraform Azure Application Insights reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights)
- Azure Key Vault configuration [Terraform Azure Key Vault reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault)
- Azure SQL Server database configuration [Terraform Azure SQL reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/mssql_database)
- Azure Blob storage configuration [Terraform Azure SQL reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob) 
- Azure Virtual Networking configuration [Terraform Azure Virtual Network reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
## Running Terraform

[Terraform](https://www.terraform.io/) is used to automate infrastructure configuration.

- Installs [Terraform](https://www.terraform.io/) for your platform.
- Installs Azure CLI authenticates using `az login`
- In the bundle directory, initialize Terraform: `terraform init`
- Apply the current Terraform configuration: `terraform apply`

## Resources

### Terraform documentation

- [Terraform Azure provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Azure naming conventions

- [Recommended abbreviations for Azure resource types](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations?WT.mc_id=java-26679-cxa)
