variable "demoname" {
    description = "The name of the demo for resource creation, etc."
    default = "pluralsightdemo"  
}

provider "azurerm" {
  version = "=2.0.0"
  features {} # This is required to prevent some issues around nullability
}

resource "random_string" "demoid" {
  keepers = {
    # Generate a new lowercase string value each time we switch to a new demo id
    # This is so resource groups, etc. will be unique
    demoID = "${var.demoname}"
  }
  length=8
  lower = true
  upper = false
  number = false
  special = false
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "example" {
  name     = "pluralsightdemo-${random_string.demoid..result}"
  location = "eastus2"
}


resource "azurerm_storage_account" "example" {
  name                     = "pluralsightdemo${random_string.demoid..result}"
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

resource "azurerm_function_app" "example" {
  name                       = "my-function-app-${random_string.demoid..result}"
  location                   = azurerm_resource_group.example.location
  resource_group_name        = azurerm_resource_group.example.name
  app_service_plan_id        = azurerm_app_service_plan.example.id
  storage_connection_string  = azurerm_storage_account.example.primary_connection_string
}

resource "azurerm_key_vault" "example" {
  name                        = "my-key-vault-${random_string.demoid..result}"
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
    ]

    storage_permissions = [
      "get",
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

#   tags = {
#     environment = "Testing"
#   }
}

data "azurerm_key_vault" "example" {
  name                = "my-key-vault"
  resource_group_name = azurerm_resource_group.example.name
}

output "vault_uri" {
  value = data.azurerm_key_vault.example.vault_uri
}

resource "azurerm_key_vault_secret" "example" {
  name         = "secret-sauce"
  value        = "szechuan"
  key_vault_id = azurerm_key_vault.example.id

}

# data "azurerm_key_vault_secret" "example" {
#   name         = "secret-sauce"
#   key_vault_id = data.azurerm_key_vault.existing.id
# }

# output "secret_value" {
#   value = data.azurerm_key_vault_secret.example.value
# }