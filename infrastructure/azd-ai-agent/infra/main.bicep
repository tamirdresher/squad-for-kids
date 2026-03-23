// =============================================================================
// Squad — Azure AI Foundry Infrastructure
// Issue: #986 — Phase 1: Deploy Seven as first cloud-resident agent
// =============================================================================
// Resources:
//   - Log Analytics Workspace  (observability)
//   - Storage Account          (required by AI Hub)
//   - Key Vault                (required by AI Hub)
//   - Application Insights     (optional, recommended)
//   - Azure AI Hub             (Microsoft.MachineLearningServices/workspaces, kind: Hub)
//   - Azure AI Project         (Microsoft.MachineLearningServices/workspaces, kind: Project)
// =============================================================================

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Environment name — controls naming and SKU choices')
@allowed(['dev', 'stg', 'prod'])
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Model to use for Squad agents (must be available in selected region)')
@allowed([
  'gpt-4o'
  'gpt-4o-mini'
  'gpt-4'
  'gpt-35-turbo'
])
param agentModel string = 'gpt-4o'

@description('Model deployment capacity (thousands of tokens per minute)')
param modelCapacity int = 10

@description('Tags applied to all resources')
param tags object = {
  Project: 'Squad'
  Component: 'AzureAIFoundry'
  Environment: environment
  ManagedBy: 'Bicep'
  Issue: 'github-986'
}

// ---------------------------------------------------------------------------
// Naming — consistent with existing Squad infra conventions
// ---------------------------------------------------------------------------

var nameSuffix   = '${environment}-${uniqueString(resourceGroup().id)}'
var shortSuffix  = replace(nameSuffix, '-', '') // storage names: no hyphens, max 24 chars

var logAnalyticsName    = 'squad-logs-ai-${nameSuffix}'
var storageAccountName  = take('squadaistor${shortSuffix}', 24)
var keyVaultName        = take('squad-kv-ai-${nameSuffix}', 24)
var appInsightsName     = 'squad-appinsights-ai-${nameSuffix}'
var aiHubName           = 'squad-ai-hub-${nameSuffix}'
var aiProjectName       = 'squad-ai-project-${nameSuffix}'
var aiServicesName      = 'squad-ai-services-${nameSuffix}'

// ---------------------------------------------------------------------------
// Log Analytics Workspace — shared observability sink
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// ---------------------------------------------------------------------------
// Application Insights — agent run tracing
// ---------------------------------------------------------------------------

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    RetentionInDays: 30
  }
}

// ---------------------------------------------------------------------------
// Storage Account — required dependency for AI Hub
// ---------------------------------------------------------------------------

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  tags: tags
  sku: {
    name: 'Standard_LRS'  // cheapest tier; AI Hub only needs blob + table
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Allow'  // relaxed for Phase 1; tighten in Phase 3 with private endpoints
    }
  }
}

// ---------------------------------------------------------------------------
// Key Vault — required dependency for AI Hub
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true   // use RBAC, not access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7    // minimum; keeps costs/storage low
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// ---------------------------------------------------------------------------
// Azure AI Services — OpenAI + AI APIs (powers the agent model)
// ---------------------------------------------------------------------------

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: aiServicesName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'  // Standard tier — consumption-based billing
  }
  properties: {
    customSubDomainName: aiServicesName
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

// Model deployment — gpt-4o for Seven's research tasks
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = {
  parent: aiServices
  name: 'squad-${agentModel}'
  sku: {
    name: 'GlobalStandard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: agentModel
      version: 'latest'
    }
    versionUpgradeOption: 'OnceCurrentVersionExpired'
  }
}

// ---------------------------------------------------------------------------
// Azure AI Foundry Hub
// ---------------------------------------------------------------------------

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: aiHubName
  location: location
  kind: 'Hub'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'Squad AI Hub (${environment})'
    description: 'Azure AI Foundry Hub for Squad cloud-resident agents. Phase 1: Seven pilot.'
    storageAccount: storage.id
    keyVault: keyVault.id
    applicationInsights: appInsights.id
    publicNetworkAccess: 'Enabled'
  }
}

// Connect AI Services (OpenAI) to the Hub
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-07-01-preview' = {
  parent: aiHub
  name: 'squad-ai-services-connection'
  properties: {
    category: 'AIServices'
    target: aiServices.properties.endpoint
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: aiServices.listKeys().key1
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServices.id
    }
  }
}

// ---------------------------------------------------------------------------
// Azure AI Foundry Project — scoped workspace for Squad agents
// ---------------------------------------------------------------------------

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: aiProjectName
  location: location
  kind: 'Project'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: 'Squad Agents (${environment})'
    description: 'Squad AI Foundry Project. Phase 1 agent: Seven (Research & Docs).'
    hubResourceId: aiHub.id
    publicNetworkAccess: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// RBAC — allow the Project's managed identity to use AI Services
// ---------------------------------------------------------------------------

var cognitiveServicesUserRoleId = 'a97b65f3-24c7-4388-baec-2e87135dc908'

resource projectAiServicesRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiProject.id, aiServices.id, cognitiveServicesUserRoleId)
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesUserRoleId)
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs — consumed by azd and downstream workflows
// ---------------------------------------------------------------------------

@description('Azure AI Foundry Hub name')
output aiHubName string = aiHub.name

@description('Azure AI Foundry Hub resource ID')
output aiHubId string = aiHub.id

@description('Azure AI Foundry Project name')
output aiProjectName string = aiProject.name

@description('Azure AI Foundry Project resource ID')
output aiProjectId string = aiProject.id

@description('AI Services endpoint')
output aiServicesEndpoint string = aiServices.properties.endpoint

@description('Application Insights connection string (for agent tracing)')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalytics.id
