variable "demoname" {
    description = "The name of the demo for resource creation, etc."
    default = "pluralsightdemo"  
}

variable "region" {
  description = "The region to create the sample apps in"
  default = "eastus2"
}

provider "azurerm" {
  version = "~> 2.11"
  features {} # This is required to prevent some issues around nullability
}

provider "random" {
  version = "~> 2.2"
}

resource "random_string" "demoid" {
  keepers = {
    # Generate a new lowercase string value each time we switch to a new demo id
    # This is so resource groups, etc. will be unique
    demoID = var.demoname
  }
  length=8
  lower = true
  upper = false
  number = false
  special = false
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "${var.demoname}-${random_string.demoid.result}"
  location = var.region
}


resource "azurerm_storage_account" "example" {
  name                     = "${var.demoname}${random_string.demoid.result}"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = azurerm_resource_group.example.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "example" {
  name                = "function-app-service-plan"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_application_insights" "example" {
  name                = "appinsights-${random_string.demoid.result}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  application_type    = "web"
}

resource "azurerm_function_app" "example" {
  name                       = "my-function-app-${random_string.demoid.result}"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  app_service_plan_id        = azurerm_app_service_plan.example.id

  storage_connection_string  = azurerm_storage_account.example.primary_connection_string

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.example.instrumentation_key
  }


}


resource "azurerm_key_vault" "example" {
  name                        = "my-key-vault-${random_string.demoid.result}"
  location                    = azurerm_resource_group.example.location
  resource_group_name         = azurerm_resource_group.example.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = true
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
      "set",
      "list"
    ]

    storage_permissions = [
      "get",
      "set"
    ]
  }
  network_acls {
    default_action = "Allow" # NOTE: This would not be suitable for production
    bypass         = "AzureServices"
  }

}