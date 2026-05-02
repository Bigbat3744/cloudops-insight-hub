terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group 
resource "azurerm_resource_group" "main" {
  name     = "rg-cloudops-insight-hub"
  location = "UK South"  

  tags = {
    Project     = "CloudOps Insight Hub"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Storage Account (required for Azure Functions)
resource "azurerm_storage_account" "function_storage" {
  name                     = "stcloudopsinsight${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # Locally redundant (cheapest)

  tags = {
    Project = "CloudOps Insight Hub"
  }
}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# App Service Plan (Azure Functions host)
resource "azurerm_service_plan" "function_plan" {
  name                = "asp-cloudops-collector"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"  # Consumption plan (pay-per-use, free tier eligible)

  tags = {
    Project = "CloudOps Insight Hub"
  }
}

# Azure Function App
resource "azurerm_linux_function_app" "cost_collector" {
  name                       = "func-cloudops-collector-${random_string.suffix.result}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.function_plan.id

  site_config {
    application_stack {
      python_version = "3.10"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "AzureWebJobsFeatureFlags"  = "EnableWorkerIndexing"
  }

  tags = {
    Project = "CloudOps Insight Hub"
  }
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-cloudops-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"  # Good balance of performance/consistency
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  # Free tier (1000 RU/s, 25 GB)
  capabilities {
    name = "EnableServerless"  # Serverless = free tier eligible
  }

  tags = {
    Project = "CloudOps Insight Hub"
  }
}

# Cosmos DB Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "cloudops-db"
  resource_group_name = azurerm_cosmosdb_account.main.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

# Cosmos DB Container (like DynamoDB table)
resource "azurerm_cosmosdb_sql_container" "usage" {
  name                = "usage"
  resource_group_name = azurerm_cosmosdb_account.main.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_path  = "/pk"  # Similar to DynamoDB partition key

  # Serverless (no provisioned throughput needed)
}

# Outputs
output "function_app_name" {
  value = azurerm_linux_function_app.cost_collector.name
}

output "function_app_url" {
  value = azurerm_linux_function_app.cost_collector.default_hostname
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.main.endpoint
}
