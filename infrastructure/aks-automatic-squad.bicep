// AKS Automatic Cluster for Squad Deployment
// Uses AKS Automatic mode with built-in KEDA, optimized node pools, and ACR integration

@description('Environment name (dev, stg, prod)')
@allowed([
  'dev'
  'stg'
  'prod'
])
param environment string = 'dev'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Kubernetes version')
param kubernetesVersion string = '1.29'

@description('Enable Azure Monitor for containers')
param enableMonitoring bool = true

@description('Enable Azure Policy for AKS')
param enableAzurePolicy bool = true

@description('Tags to apply to all resources')
param tags object = {
  Project: 'Squad'
  Component: 'AKS-Automatic'
  Environment: environment
  ManagedBy: 'Bicep'
}

// Naming conventions
var nameSuffix = '${environment}-${uniqueString(resourceGroup().id)}'
var aksClusterName = 'squad-aks-${nameSuffix}'
var acrName = 'squadacr${replace(nameSuffix, '-', '')}'
var vnetName = 'squad-vnet-${nameSuffix}'
var logAnalyticsName = 'squad-logs-${nameSuffix}'
var identityName = 'squad-aks-identity-${nameSuffix}'

// Log Analytics Workspace
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

// Virtual Network for AKS
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.240.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aks-subnet'
        properties: {
          addressPrefix: '10.240.0.0/22'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'acr-subnet'
        properties: {
          addressPrefix: '10.240.4.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Managed Identity for AKS
resource aksIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 30
      }
    }
  }
}

// AKS Cluster with Automatic Mode
resource aksCluster 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: aksClusterName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksIdentity.id}': {}
    }
  }
  sku: {
    name: 'Automatic'
    tier: 'Standard'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: '${aksClusterName}-dns'
    
    // Network profile for AKS Automatic
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '10.241.0.0/16'
      dnsServiceIP: '10.241.0.10'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }

    // Agent pool profiles (AKS Automatic manages system pool automatically)
    agentPoolProfiles: [
      {
        name: 'system'
        count: 3
        vmSize: 'Standard_D4s_v5'
        osType: 'Linux'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: '${vnet.id}/subnets/aks-subnet'
        enableAutoScaling: true
        minCount: 2
        maxCount: 5
        maxPods: 50
        osDiskType: 'Managed'
        osDiskSizeGB: 128
        kubeletDiskType: 'OS'
      }
      {
        name: 'workload'
        count: 3
        vmSize: 'Standard_D4s_v5'
        osType: 'Linux'
        mode: 'User'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: '${vnet.id}/subnets/aks-subnet'
        enableAutoScaling: true
        minCount: 1
        maxCount: 10
        maxPods: 50
        osDiskType: 'Managed'
        osDiskSizeGB: 128
        kubeletDiskType: 'OS'
        nodeTaints: []
        nodeLabels: {
          'workload': 'squad'
        }
      }
    ]

    // Security and add-ons
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }

    // Auto-scaler profile
    autoScalerProfile: {
      'scale-down-delay-after-add': '10m'
      'scale-down-unneeded-time': '10m'
      'scale-down-utilization-threshold': '0.5'
      'max-graceful-termination-sec': '600'
    }

    // Enable monitoring
    addonProfiles: {
      omsagent: {
        enabled: enableMonitoring
        config: {
          logAnalyticsWorkspaceResourceID: logAnalytics.id
        }
      }
      azurepolicy: {
        enabled: enableAzurePolicy
      }
    }

    // AKS Automatic features (KEDA is built-in)
    workloadAutoScalerProfile: {
      keda: {
        enabled: true
      }
    }

    // Security hardening
    apiServerAccessProfile: {
      enablePrivateCluster: false
    }

    enableRBAC: true
    disableLocalAccounts: true
  }
}

// Role assignment: AKS -> ACR (AcrPull)
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aksIdentity.id, 'acrpull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aksIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output aksClusterName string = aksCluster.name
output aksClusterId string = aksCluster.id
output aksFqdn string = aksCluster.properties.fqdn
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output vnetId string = vnet.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output identityId string = aksIdentity.id
output resourceGroupName string = resourceGroup().name
