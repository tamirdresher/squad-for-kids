// FedRAMP Dashboard Phase 1: Data Pipeline Infrastructure
// Deploys: Log Analytics, Azure Monitor, Cosmos DB, Storage, Functions

@description('Environment name (dev, stg, prod)')
@allowed([
  'dev'
  'stg'
  'prod'
])
param environment string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Cloud type (public or government)')
@allowed([
  'public'
  'government'
])
param cloudType string = 'public'

@description('Cosmos DB provisioned throughput (RU/s)')
@minValue(400)
@maxValue(10000)
param cosmosDbThroughput int = 1000

@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param logAnalyticsRetentionDays int = 90

@description('Enable reserved capacity for Cosmos DB (30% cost savings)')
param enableCosmosReservedCapacity bool = false

@description('Tags to apply to all resources')
param tags object = {
  Project: 'FedRAMP-Dashboard'
  Phase: 'Phase1-DataPipeline'
  Environment: environment
  ManagedBy: 'Bicep'
}

// Naming conventions
var nameSuffix = '${environment}${uniqueString(resourceGroup().id)}'
var logAnalyticsName = 'fedramp-logs-${nameSuffix}'
var cosmosDbAccountName = 'fedramp-cosmos-${nameSuffix}'
var storageAccountName = 'fedrampstore${replace(nameSuffix, '-', '')}'
var functionAppName = 'fedramp-pipeline-func-${nameSuffix}'
var appServicePlanName = 'fedramp-plan-${nameSuffix}'
var keyVaultName = 'fedramp-kv-${take(nameSuffix, 18)}'
var appInsightsName = 'fedramp-insights-${nameSuffix}'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logAnalyticsRetentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 10  // Prevent cost overrun
    }
  }
}

// Custom Log Analytics Table for validation results
resource customTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  parent: logAnalyticsWorkspace
  name: 'ControlValidationResults_CL'
  properties: {
    schema: {
      name: 'ControlValidationResults_CL'
      columns: [
        { name: 'TimeGenerated', type: 'datetime', description: 'Ingestion timestamp' }
        { name: 'Environment_s', type: 'string', description: 'Environment name' }
        { name: 'Cluster_s', type: 'string', description: 'Cluster name' }
        { name: 'ControlId_s', type: 'string', description: 'FedRAMP control ID' }
        { name: 'ControlName_s', type: 'string', description: 'Control description' }
        { name: 'TestCategory_s', type: 'string', description: 'Test category' }
        { name: 'TestName_s', type: 'string', description: 'Test name' }
        { name: 'Status_s', type: 'string', description: 'PASS or FAIL' }
        { name: 'ExecutionTimeMs_d', type: 'real', description: 'Execution time in ms' }
        { name: 'Details_s', type: 'string', description: 'JSON test details' }
        { name: 'PipelineId_s', type: 'string', description: 'CI/CD pipeline ID' }
        { name: 'CommitSha_s', type: 'string', description: 'Git commit SHA' }
      ]
    }
    retentionInDays: logAnalyticsRetentionDays
  }
}

// Cosmos DB Account
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: environment == 'prod'
      }
    ]
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'  // TODO: Disable in PROD with Private Endpoint
    networkAclBypass: 'AzureServices'
    capabilities: [
      {
        name: 'EnableServerless'  // Use serverless for dev/stg, provisioned for prod
      }
    ]
  }
}

// Cosmos DB Database
resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDbAccount
  name: 'SecurityDashboard'
  properties: {
    resource: {
      id: 'SecurityDashboard'
    }
  }
}

// Cosmos DB Container (with TTL and partitioning)
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: cosmosDb
  name: 'ControlValidationResults'
  properties: {
    resource: {
      id: 'ControlValidationResults'
      partitionKey: {
        paths: [
          '/environment'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        automatic: true
        indexingMode: 'Consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
          {
            path: '/details/*'  // Don't index detailed test output
          }
        ]
      }
      defaultTtl: 7776000  // 90 days in seconds
    }
    options: environment == 'prod' ? {
      throughput: cosmosDbThroughput
    } : {}
  }
}

// Storage Account (for cold archival)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Cool'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'  // TODO: Restrict in PROD
      bypass: 'AzureServices'
    }
  }
}

// Blob Container for archived validation results
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/validation-archive'
  properties: {
    publicAccess: 'None'
  }
}

// Lifecycle management policy (auto-move to Archive tier)
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'move-to-archive'
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
              prefixMatch: ['validation-archive/']
            }
            actions: {
              baseBlob: {
                tierToArchive: {
                  daysAfterModificationGreaterThan: 1  // Move to archive after 1 day
                }
                delete: {
                  daysAfterModificationGreaterThan: 730  // Delete after 2 years
                }
              }
            }
          }
        }
      ]
    }
  }
}

// Key Vault for secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true  // Use RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'  // TODO: Disable in PROD
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
  }
}

// App Service Plan (Consumption for dev/stg, Premium for prod)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: environment == 'prod' ? {
    name: 'EP1'  // Elastic Premium (supports VNet integration)
    tier: 'ElasticPremium'
  } : {
    name: 'Y1'  // Consumption
    tier: 'Dynamic'
  }
  properties: {
    reserved: true  // Linux
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${az.environment().suffixes.storage}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'CosmosDbEndpoint'
          value: cosmosDbAccount.properties.documentEndpoint
        }
        {
          name: 'CosmosDbDatabase'
          value: 'SecurityDashboard'
        }
        {
          name: 'CosmosDbContainer'
          value: 'ControlValidationResults'
        }
        {
          name: 'LogAnalyticsWorkspaceId'
          value: logAnalyticsWorkspace.properties.customerId
        }
        {
          name: 'StorageAccountName'
          value: storageAccount.name
        }
        {
          name: 'ArchiveContainerName'
          value: 'validation-archive'
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
    }
    httpsOnly: true
  }
}

// RBAC: Function App → Cosmos DB (Data Contributor)
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  parent: cosmosDbAccount
  name: guid(cosmosDbAccount.id, functionApp.id, 'CosmosDBDataContributor')
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'  // Cosmos DB Built-in Data Contributor
    principalId: functionApp.identity.principalId
    scope: cosmosDbAccount.id
  }
}

// RBAC: Function App → Storage (Blob Data Contributor)
resource storageBlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, functionApp.id, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')  // Storage Blob Data Contributor
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC: Function App → Log Analytics (Contributor)
resource logAnalyticsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: logAnalyticsWorkspace
  name: guid(logAnalyticsWorkspace.id, functionApp.id, 'LogAnalyticsContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '92aaf0da-9dab-42b6-94a3-d43ce8d16293')  // Log Analytics Contributor
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC: Function App → Key Vault (Secrets User)
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, functionApp.id, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')  // Key Vault Secrets User
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.properties.customerId
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output cosmosDbAccountName string = cosmosDbAccount.name
output storageAccountName string = storageAccount.name
output functionAppName string = functionApp.name
output functionAppPrincipalId string = functionApp.identity.principalId
output keyVaultName string = keyVault.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
