# Subscription ID variable:
variable "azure-subscription-id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "<your_subscription_id>"
}

# Client ID variable:
variable "azure-client-id" {
  description = "Azure Client ID"
  type        = string
  default     = "<your_azure_client_id>"
}

# Client Secret variable:
variable "azure-client-secret" {
  description = "Azure Client Secret"
  type        = string
  default     = "<your_azure_client_secret>"
}

# Tenant ID variable:
variable "azure-tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  default     = "<your_azure_tenant_id>"
}

# Azure Databricks key ID self-signed:
variable "azure-databricks_id" {
  description = "Azure Databricks self-signed ID"
  type        = string
  default     = "<your_azure_databricks_id>"
}

# Local location variable:
variable "azure-location" {
  description = "Azure Location"
  type        = string
  default     = "West Europe"
}

# Local SQL Server admin user name:
variable "azure-sqlserver-admin-name" {
  description = "SQL Server adminitrator user name"
  type        = string
  default     = "sadmin"
}

# Local SQL Server admin user password:
variable "azure-sqlserver-admin-password" {
  description = "SQL Server adminitrator user password"
  type        = string
  default     = "!BsmwimGUH_33+09!"
}

# SQL Server version to use:
variable "sql_server_version" {
  description = "The version for the new server. Valid values are: 2.0 (for v11 server) and 12.0 (for v12 server)"
  type = string
  default = "12.0"
}

# Name of azure databriks workspace subdirectory to use:
variable "azure-databricks_notebook_subdirectory" {
  description = "A name for the subdirectory to store the notebook"
  type        = string
  default     = "/medallion-workspace"
}

# Name of azure databriks notebook to use:
variable "azure-databricks_notebook_filename" {
  description = "The notebook's filename"
  type        = string
  default     = "base-notebook.scala"
}

# Language of azure databriks to use:
variable "azure-databricks_notebook_language_scala" {
  description = "The language of the notebook"
  type        = string
  default     = "SCALA"
}

# Language of azure databriks to use:
variable "azure-databricks_notebook_language_python" {
  description = "The language of the notebook"
  type        = string
  default     = "PYTHON"
}

# Default admin user for azure databricks:
variable "azure-databricks_admin_user" {
  description = "The admin user of azure databricks"
  type        = string
  default = "user01@outlook.com"
}

# Spark version:
variable "azure-databricks_spark_version" {
  description = "The Spark version of databricks"
  type        = string
  default     = "9.1.x-scala2.12"
}

#------------------------------------------------------------------

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.91.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "1.36.3"
    }
  }
}

# Connect Azure:
provider "azurerm" {
  skip_provider_registration    = true
  subscription_id               = var.azure-subscription-id
  client_id                     = var.azure-client-id
  client_secret                 = var.azure-client-secret
  tenant_id                     = var.azure-tenant_id
  features {}
}

# Connect Azure Databricks:
provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.medallion-DB-W.id
}


# Access the configuration of the AzureRM provider:
data "azurerm_client_config" "current" {}


#------------------------------------------------------------------

# Create a resource group:
resource "azurerm_resource_group" "medallion-RG" {
  name = "medallion-spark-dbt-RG"
  location = var.azure-location
}

# Create a storage account (store for Bronze, Silver and Gold layer):
resource "azurerm_storage_account" "medallion-RG" {
  name                     = "medallionarchitecturesa"
  resource_group_name      = azurerm_resource_group.medallion-RG.name
  location                 = azurerm_resource_group.medallion-RG.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  is_hns_enabled = true
}

# Create a container Bronze layer:
resource "azurerm_storage_container" "medallion-bronze-DQ" {
  name                  = "bronze"
  storage_account_name  = azurerm_storage_account.medallion-RG.name
  container_access_type = "private"
}

# Create a container Silver layer:
resource "azurerm_storage_container" "medallion-silver-DQ" {
  name                  = "silver"
  storage_account_name  = azurerm_storage_account.medallion-RG.name
  container_access_type = "private"
}

# Create a container Gold layer:
resource "azurerm_storage_container" "medallion-gold-DQ" {
  name                  = "gold"
  storage_account_name  = azurerm_storage_account.medallion-RG.name
  container_access_type = "private"
}

# Create a data factory:
resource "azurerm_data_factory" "medallion-DF" {
  name                = "medallionarchitecture-DF"
  location            = azurerm_resource_group.medallion-RG.location
  resource_group_name = azurerm_resource_group.medallion-RG.name
}

# Create a key vault:
resource "azurerm_key_vault" "medallion-KV" {
  name                        = "medallionarchitecture-KV"
  location                    = azurerm_resource_group.medallion-RG.location
  resource_group_name         = azurerm_resource_group.medallion-RG.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = false

  sku_name = "standard"
}

# Create an access policy for key vault, with certain permissions:
resource "azurerm_key_vault_access_policy" "medallion-KV-AP" {
  key_vault_id = azurerm_key_vault.medallion-KV.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Update", "Create", "Import", "Delete", "Recover", "Backup", "Restore", "SetRotationPolicy", "GetRotationPolicy", "Rotate",
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore",
  ]

  certificate_permissions = [
    "Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers", "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover", "Restore", "SetIssuers", "Update",
  ]
}

# Create a sql server:
resource "azurerm_mssql_server" "medallion-DB-SRV" {
  name                         = "medallionarchitecure-db-srv"
  resource_group_name          = azurerm_resource_group.medallion-RG.name
  location                     = azurerm_resource_group.medallion-RG.location
  version                      = var.sql_server_version
  administrator_login          = var.azure-sqlserver-admin-name
  administrator_login_password = var.azure-sqlserver-admin-password
  minimum_tls_version          = "1.2"
}

# Create an "AdventureWorksLT" sample database in the previous sql server:
resource "azurerm_mssql_database" "medallion-DB" {
  name              = "AdventureWorksLT"
  server_id         = azurerm_mssql_server.medallion-DB-SRV.id
  collation         = "SQL_Latin1_General_CP1_CI_AS"
  sample_name       = "AdventureWorksLT"
}

# Create a firewall to secure the public connection to the sql server:
resource "azurerm_mssql_firewall_rule" "medallion-DB-SRV-F" {
  name             = "medallionarchitecure-rule-db"
  server_id        = azurerm_mssql_server.medallion-DB-SRV.id
  # When we set the start_ip_address  = "0.0.0.0" and end_ip_address  = "0.0.0.0" in the SQL server firewall, actually it set the Allow Azure services and resources to access this server to "Yes"
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"

  depends_on = [ azurerm_mssql_server.medallion-DB-SRV ]
}

# Create a connection from data factory to our sql database "AdventureWorksLT":
resource "azurerm_data_factory_linked_service_azure_sql_database" "medallion-DF-DB-SRV-C" {
  name              = "medallionarchitecuredatabaseconnection"
  data_factory_id   = azurerm_data_factory.medallion-DF.id
  connection_string = "data source=${azurerm_mssql_server.medallion-DB-SRV.name}.database.windows.net;initial catalog=${azurerm_mssql_database.medallion-DB.name};user id=${var.azure-sqlserver-admin-name};Password=${var.azure-sqlserver-admin-password};integrated security=False;encrypt=True;connection timeout=30"
}

# Create a connection from data factory to the data lake:
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "medallion-DF-DL-C" {
  name                  = "medallionarchitecuredatalakeconnection"
  data_factory_id       = azurerm_data_factory.medallion-DF.id
  storage_account_key   = azurerm_storage_account.medallion-RG.primary_access_key
  url                   = "https://medallionarchitecturesa.dfs.core.windows.net"
}

# Create a connection from databricks to the data factory:
resource "azurerm_data_factory_linked_service_azure_databricks" "medallion-DF-DB-C" {
  name                  = "medallionarchitecuredatabricksconnection"
  data_factory_id       = azurerm_data_factory.medallion-DF.id
  description           = "ADB Linked Service via Access Token"
  existing_cluster_id   = databricks_cluster.medallion-DB-C.id

  access_token          = databricks_token.medallion-DB-T.token_value
  adb_domain            = "https://${azurerm_databricks_workspace.medallion-DB-W.workspace_url}"
}

# As terraform not support yet a dataset from sql database, we create an custom dataset:
resource "azurerm_data_factory_custom_dataset" "medallion-DF-DB-D" {
  name            = "medallionarchitecturedatasetquery"
  data_factory_id = azurerm_data_factory.medallion-DF.id
  type            = "AzureSqlTable"

  linked_service {
    name = azurerm_data_factory_linked_service_azure_sql_database.medallion-DF-DB-SRV-C.name
  }

  type_properties_json = <<JSON
{
}
JSON
}

# Create a input sql database dataset, with two parameters (SchemaName and TableName):
resource "azurerm_data_factory_custom_dataset" "medallion-DF-DB-D-I" {
  name            = "medallionarchitecturedatasetqueryinput"
  data_factory_id = azurerm_data_factory.medallion-DF.id
  type            = "AzureSqlTable"

  linked_service {
    name = azurerm_data_factory_linked_service_azure_sql_database.medallion-DF-DB-SRV-C.name
  }

  schema_json = jsonencode([])
 
  type_properties_json = jsonencode({
    "schema": {
        "value": "@dataset().SchemaName",
        "type": "Expression"
    },
    "table": {
        "value": "@dataset().TableName",
        "type": "Expression"
    }
  })

  parameters = {
    SchemaName = ""
    TableName  = ""
  }
}

# Create a pipeline into data factory, with activities:
resource "azurerm_data_factory_pipeline" "medallion-DF-P" {
  name            = "medallionarchitecturepipeline"
  data_factory_id = azurerm_data_factory.medallion-DF.id
  variables = {
    "bob" = "item1"
  }
  activities_json = <<JSON
[
    {
        "name": "fetch-all-tables",
        "type": "Lookup",
        "dependsOn": [],
        "policy": {
            "retry": 0,
            "retryIntervalInSeconds": 30,
            "secureOutput": false,
            "secureInput": false
        },
        "userProperties": [],
        "typeProperties": {
            "source": {
                "type": "AzureSqlSource",
                "sqlReaderQuery": "SELECT * FROM [AdventureWorksLT].information_schema.tables\nWHERE TABLE_SCHEMA LIKE 'SalesLT' AND TABLE_TYPE LIKE 'BASE TABLE'",
                "queryTimeout": "02:00:00",
                "partitionOption": "None"
            },
            "dataset": {
                "referenceName": "${azurerm_data_factory_custom_dataset.medallion-DF-DB-D.name}",
                "type": "DatasetReference"
            },
            "firstRowOnly": false
        }
    },
    {
        "name": "ForEach",
        "type": "ForEach",
        "dependsOn": [
            {
                "activity": "fetch-all-tables",
                "dependencyConditions": [
                    "Succeeded"
                ]
            }
        ],
        "userProperties": [],
        "typeProperties": {
            "items": {
                "value": "@activity('fetch-all-tables').output.value",
                "type": "Expression"
            },
            "activities": [
                {
                    "name": "copy-data",
                    "type": "Copy",
                    "dependsOn": [],
                    "policy": {
                        "timeout": "0.12:00:00",
                        "retry": 0,
                        "retryIntervalInSeconds": 30,
                        "secureOutput": false,
                        "secureInput": false
                    },
                    "userProperties": [],
                    "typeProperties": {
                        "source": {
                            "type": "AzureSqlSource",
                            "queryTimeout": "02:00:00",
                            "partitionOption": "None"
                        },
                        "sink": {
                            "type": "ParquetSink",
                            "storeSettings": {
                                "type": "AzureBlobFSWriteSettings"
                            },
                            "formatSettings": {
                                "type": "ParquetWriteSettings"
                            }
                        },
                        "enableStaging": false,
                        "translator": {
                            "type": "TabularTranslator",
                            "typeConversion": true,
                            "typeConversionSettings": {
                                "allowDataTruncation": true,
                                "treatBooleanAsNumber": false
                            }
                        }
                    },
                    "inputs": [
                        {
                            "referenceName": "${azurerm_data_factory_custom_dataset.medallion-DF-DB-D-I.name}",
                            "type": "DatasetReference",
                            "parameters": {
                                "SchemaName": {
                                    "value": "@item().table_schema",
                                    "type": "Expression"
                                },
                                "TableName": {
                                    "value": "@item().table_name",
                                    "type": "Expression"
                                }
                            }
                        }
                    ],
                    "outputs": [
                        {
                            "referenceName": "${azurerm_data_factory_custom_dataset.medallion-DF-DL-O.name}",
                            "type": "DatasetReference",
                            "parameters": {
                                "FileName": {
                                    "value": "@concat(item().table_schema,'.',item().table_name,'.parquet')",
                                    "type": "Expression"
                                },
                                "FolderName": {
                                    "value": "@formatDateTime(utcNow(),'yyyy-MM-dd')",
                                    "type": "Expression"
                                }
                            }
                        }
                    ]
                },
                {
                    "name": "notebook",
                    "type": "DatabricksNotebook",
                    "dependsOn": [
                        {
                            "activity": "copy-data",
                            "dependencyConditions": [
                                "Succeeded"
                            ]
                        }
                    ],
                    "policy": {
                        "timeout": "0.12:00:00",
                        "retry": 0,
                        "retryIntervalInSeconds": 30,
                        "secureOutput": false,
                        "secureInput": false
                    },
                    "userProperties": [],
                    "typeProperties": {
                        "notebookPath": "/Shared/base-notebook-spark",
                        "baseParameters": {
                            "table_schema": {
                                "value": "@item().table_schema",
                                "type": "Expression"
                            },
                            "table_name": {
                                "value": "@item().table_name",
                                "type": "Expression"
                            },
                            "fileName": {
                                "value": "@formatDateTime(utcNow(),'yyyy-MM-dd')",
                                "type": "Expression"
                            }
                        }
                    },
                    "linkedServiceName": {
                        "referenceName": "AzureDatabricks1",
                        "type": "LinkedServiceReference"
                    }
                }
            ]
        }
    }
]
  JSON
}

# Create a azure data lake storage gen2, with parquet format with two parameters:
resource "azurerm_data_factory_custom_dataset" "medallion-DF-DL-O" {
  name            = "medallionarchitectureoutput"
  data_factory_id = azurerm_data_factory.medallion-DF.id
  type            = "Parquet"

  linked_service {
    name = azurerm_data_factory_linked_service_data_lake_storage_gen2.medallion-DF-DL-C.name
  }

  type_properties_json = jsonencode({
    "location": {
        "type": "AzureBlobFSLocation",
        "fileName": {
            "value": "@dataset().FileName",
            "type": "Expression"
        },
        "folderPath": {
            "value": "@dataset().FolderName",
            "type": "Expression"
        },
        "fileSystem": {
            "value": "bronze",
            "type": "Expression"
        }
    },
    "compressionCodec": "snappy"
  })

  parameters = {
    FolderName = ""
    FileName  = ""
  }
}

# Create azure databricks workspace:
resource "azurerm_databricks_workspace" "medallion-DB-W" {
  name                = "medallionarchitecture-databricks-workspace"
  location            = azurerm_resource_group.medallion-RG.location
  resource_group_name = azurerm_resource_group.medallion-RG.name
  sku                 = "standard"
}

# Declare a new user:
resource "databricks_user" "medallion-DB-W-U" {
  user_name     = var.azure-databricks_admin_user
  display_name  = "Admin User"
}

# Create one cluster:
resource "databricks_cluster" "medallion-DB-C" {
  cluster_name            = "Single Node"
  spark_version           = var.azure-databricks_spark_version
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 10

  spark_conf = {
    # Single-node
    "spark.databricks.cluster.profile" : "singleNode"
    "spark.master" : "local[*]"
  }

  custom_tags = {
    "ResourceClass" = "SingleNode"
  }

  depends_on = [
    azurerm_databricks_workspace.medallion-DB-W
  ]
}

# Create a notebook:
resource "databricks_notebook" "medallion-DB-W-NI" {
  path            = "/hello-world"
  content_base64  = base64encode("println('Hello world')")
  depends_on      = [azurerm_databricks_workspace.medallion-DB-W]
  language        = "SCALA"
}

# Create a notebook:
resource "databricks_notebook" "medallion-DB-W-NB" {
  path            = "/Shared/base-notebook"
  content_base64  = base64encode(<<-EOT
    %scala
    dbutils.fs.mount(
      source="wasbs://bronze@medallionarchitecturesa.blob.core.windows.net",
      mountPoint="/mnt/bronze",
      extraConfigs=Map("fs.azure.account.key.medallionarchitecturesa.blob.core.windows.net" -> dbutils.secrets.get("medallionarchitecture-databricks-scope", "medallionarchitecturesakey"))
    )

    dbutils.fs.mount(
      source="wasbs://silver@medallionarchitecturesa.blob.core.windows.net",
      mountPoint="/mnt/silver",
      extraConfigs=Map("fs.azure.account.key.medallionarchitecturesa.blob.core.windows.net" -> dbutils.secrets.get("medallionarchitecture-databricks-scope", "medallionarchitecturesakey"))
    )

    dbutils.fs.mount(
      source="wasbs://gold@medallionarchitecturesa.blob.core.windows.net",
      mountPoint="/mnt/gold",
      extraConfigs=Map("fs.azure.account.key.medallionarchitecturesa.blob.core.windows.net" -> dbutils.secrets.get("medallionarchitecture-databricks-scope", "medallionarchitecturesakey"))
    )
  EOT
  )
  
  depends_on      = [azurerm_databricks_workspace.medallion-DB-W]
  language        = "SCALA"
}

# Create a notebook:
resource "databricks_notebook" "medallion-DB-W-NBS" {
  path            = "/Shared/base-notebook-spark"
  content_base64  = base64encode(<<-EOT
    %scala
    val fileName = dbutils.widgets.get("fileName")
    val tableSchema = dbutils.widgets.get("table_schema")
    val tableName = dbutils.widgets.get("table_name")

    // Crear una base de datos si no existe:
    spark.sql(s"CREATE DATABASE IF NOT EXISTS $tableSchema")

    // Si la tabla no existe en la base de datos, entonces crearla:
    spark.sql(s"""CREATE TABLE IF NOT EXISTS $tableSchema.$tableName 
              USING PARQUET 
              LOCATION '/mnt/bronze/$fileName/$tableSchema.$tableName.parquet'""")
  EOT
  )
  
  depends_on      = [azurerm_databricks_workspace.medallion-DB-W]
  language        = "SCALA"
}

# Create azure key vault secret:
resource "azurerm_key_vault_secret" "medallion-KV-S" {
  name         = "medallionarchitecturesakey"
  value        = azurerm_storage_account.medallion-RG.primary_access_key
  key_vault_id = azurerm_key_vault.medallion-KV.id
  
}

# Create azure databricks secret scope:
resource "databricks_secret_scope" "medallion-DB-SS" {
  name                      = "medallionarchitecture-databricks-scope"
  initial_manage_principal  = "users"

  keyvault_metadata {
    resource_id             = azurerm_key_vault.medallion-KV.id
    dns_name                = azurerm_key_vault.medallion-KV.vault_uri
  }
}

# Create PAT token to provision entities within workspace:
resource "databricks_token" "medallion-DB-T" {
  comment  = "Terraform Provisioning"
  # 100 day token
  lifetime_seconds = 8640000
}

# Give away azure databricks token:
output "databricks_token" {
  value     = databricks_token.medallion-DB-T.token_value
  sensitive = true
}