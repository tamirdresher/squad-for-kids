// Parameters file for AKS Automatic Squad deployment

using './aks-automatic-squad.bicep'

param environment = 'dev'
param location = 'eastus'
param kubernetesVersion = '1.29'
param enableMonitoring = true
param enableAzurePolicy = true

param tags = {
  Project: 'Squad'
  Component: 'AKS-Automatic'
  Environment: 'dev'
  ManagedBy: 'Bicep'
  Owner: 'Squad-Team'
}
