@description('Environment name (dev, stg, prod)')
param environment string

@description('Location for resources')
param location string = resourceGroup().location

@description('Log Analytics Workspace ID from Phase 1')
param logAnalyticsWorkspaceId string

@description('Cosmos DB connection string from Phase 1')
@secure()
param cosmosDbConnectionString string

@description('PagerDuty routing key')
@secure()
param pagerDutyRoutingKey string

@description('Teams webhook URLs')
@secure()
param teamsWebhookUrlCritical string

@secure()
param teamsWebhookUrlMedium string

@secure()
param teamsWebhookUrlLow string

// Redis Cache for deduplication
resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: 'fedramp-redis-${environment}'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0  // 250 MB
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    redisConfiguration: {
      'maxmemory-policy': 'allkeys-lru'
    }
  }
}

// Storage Account for function app
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'fedrampalert${environment}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// App Service Plan for Function App
resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'fedramp-alerts-plan-${environment}'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {}
}

// Function App for alert processing
resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'fedramp-alerts-func-${environment}'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${az.environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('fedramp-alerts-func-${environment}')
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
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'RedisConnectionString'
          value: '${redisCache.name}.redis.cache.windows.net:6380,password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
        }
        {
          name: 'PagerDutyRoutingKey'
          value: pagerDutyRoutingKey
        }
        {
          name: 'TeamsWebhookUrl-Critical'
          value: teamsWebhookUrlCritical
        }
        {
          name: 'TeamsWebhookUrl-Medium'
          value: teamsWebhookUrlMedium
        }
        {
          name: 'TeamsWebhookUrl-Low'
          value: teamsWebhookUrlLow
        }
        {
          name: 'CosmosDBConnection'
          value: cosmosDbConnectionString
        }
      ]
      netFrameworkVersion: 'v8.0'
      use32BitWorkerProcess: false
    }
    httpsOnly: true
  }
}

// Application Insights for monitoring
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'fedramp-alerts-ai-${environment}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

// Action Group for alert routing
resource alertActionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'fedramp-alert-action-group-${environment}'
  location: 'global'
  properties: {
    groupShortName: 'FedRAMP'
    enabled: true
    azureFunctionReceivers: [
      {
        name: 'AlertProcessor'
        functionAppResourceId: functionApp.id
        functionName: 'AlertProcessor'
        httpTriggerUrl: 'https://${functionApp.properties.defaultHostName}/api/AlertProcessor'
        useCommonAlertSchema: true
      }
    ]
  }
}

// Alert Rules Module
module alertRules 'phase4-alert-rules.bicep' = {
  name: 'alert-rules-deployment'
  params: {
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    actionGroupId: alertActionGroup.id
    environment: environment
  }
}

// Outputs
output redisCacheName string = redisCache.name
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output actionGroupId string = alertActionGroup.id
output appInsightsId string = appInsights.id
