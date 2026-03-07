// ============================================================================
// Microsoft Dev Box Provisioning - Bicep Template
// ============================================================================
// Issue #35 - Phase 1: Infrastructure as Code for Dev Box automation
//
// NOTE: As of March 2026, Azure Dev Box does not support direct ARM/Bicep 
// provisioning of Dev Box instances. This template is scaffolded for future 
// use when ARM support is added. Current provisioning relies on Azure CLI.
//
// References:
// - https://learn.microsoft.com/azure/dev-box/
// - https://learn.microsoft.com/cli/azure/devcenter/dev/dev-box
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Dev Box instance to create')
@minLength(3)
@maxLength(63)
param devBoxName string

@description('Name of the Dev Center resource')
param devCenterName string

@description('Name of the Dev Center Project')
param projectName string

@description('Name of the Dev Box Pool to provision from')
param poolName string

@description('Location for the Dev Box resources')
@allowed([
  'eastus'
  'eastus2'
  'westus2'
  'westus3'
  'centralus'
  'northcentralus'
  'southcentralus'
  'westcentralus'
  'canadacentral'
  'canadaeast'
  'brazilsouth'
  'northeurope'
  'westeurope'
  'uksouth'
  'ukwest'
  'francecentral'
  'germanywestcentral'
  'norwayeast'
  'switzerlandnorth'
  'swedencentral'
  'australiaeast'
  'australiasoutheast'
  'eastasia'
  'southeastasia'
  'japaneast'
  'japanwest'
  'koreacentral'
  'koreasouth'
  'centralindia'
  'southindia'
  'westindia'
])
param location string = 'eastus'

@description('Tags to apply to resources')
param tags object = {
  Environment: 'Development'
  Purpose: 'DevBox'
  ManagedBy: 'IaC-Bicep'
  Squad: 'tamresearch1'
  Issue: '#35'
}

@description('Optional: Custom network configuration for the Dev Box')
param networkConnectionName string = ''

@description('Optional: Hibernation schedule for cost optimization')
param enableHibernation bool = false

@description('Optional: Auto-shutdown configuration')
param autoShutdownEnabled bool = false
param autoShutdownTime string = '19:00'
param autoShutdownTimeZone string = 'UTC'

// ============================================================================
// Variables
// ============================================================================

var devBoxNameSanitized = toLower(replace(devBoxName, ' ', '-'))
var devBoxFullName = '${devBoxNameSanitized}-${uniqueString(resourceGroup().id)}'

// ============================================================================
// Resources
// ============================================================================

// NOTE: The following resource definitions are placeholders for when Azure
// Dev Box supports ARM/Bicep deployments. Currently, use Azure CLI or REST API.

// PLACEHOLDER: Dev Box Instance
// When ARM support is available, this will create the Dev Box instance
// using Microsoft.DevCenter/devboxes or similar resource type

// Current workaround: Use deployment script to invoke Azure CLI
resource devBoxProvisioningScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${devBoxName}-provision-script'
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      // PLACEHOLDER: Add managed identity resource ID
      // Required for deployment script authentication
    }
  }
  properties: {
    azPowerShellVersion: '10.0'
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      param(
        [string]$DevBoxName,
        [string]$DevCenterName,
        [string]$ProjectName,
        [string]$PoolName
      )

      # Install Azure CLI devcenter extension
      Write-Output "Installing Azure CLI devcenter extension..."
      az extension add --name devcenter --yes

      # Create Dev Box
      Write-Output "Creating Dev Box: $DevBoxName"
      az devcenter dev dev-box create `
        --dev-center-name $DevCenterName `
        --project-name $ProjectName `
        --pool-name $PoolName `
        --name $DevBoxName `
        --output json

      # Wait for provisioning
      Write-Output "Waiting for Dev Box provisioning..."
      $maxAttempts = 60
      $attempt = 0
      $status = "Provisioning"

      while ($status -ne "Running" -and $attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 30
        $devBox = az devcenter dev dev-box show --name $DevBoxName --output json | ConvertFrom-Json
        $status = $devBox.provisioningState
        $attempt++
        Write-Output "Attempt $attempt/$maxAttempts - Status: $status"
      }

      if ($status -eq "Running") {
        Write-Output "Dev Box provisioned successfully!"
        $output = @{
          devBoxName = $DevBoxName
          status = $status
          provisioningState = $status
        }
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['result'] = $output
      } else {
        Write-Error "Dev Box provisioning failed or timed out. Status: $status"
        exit 1
      }
    '''
    arguments: '-DevBoxName "${devBoxName}" -DevCenterName "${devCenterName}" -ProjectName "${projectName}" -PoolName "${poolName}"'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Name of the created Dev Box')
output devBoxName string = devBoxName

@description('Provisioning state')
output provisioningState string = devBoxProvisioningScript.properties.outputs.result.provisioningState

@description('Resource location')
output location string = location

@description('Resource tags')
output tags object = tags

@description('Connection command (Azure CLI)')
output connectionCommand string = 'az devcenter dev dev-box show --name ${devBoxName} --query "remoteConnectionUri" --output tsv'

// ============================================================================
// Notes for Future Enhancement
// ============================================================================

// TODO: When ARM support is added for Dev Box:
// 1. Replace deployment script with native resource type
// 2. Add network connection resource definition
// 3. Add schedule resource for auto-shutdown/hibernation
// 4. Add custom image support
// 5. Add RBAC assignments for Dev Box access
//
// Example future resource structure:
//
// resource devBox 'Microsoft.DevCenter/devboxes@2024-XX-XX' = {
//   name: devBoxFullName
//   location: location
//   tags: tags
//   properties: {
//     devCenterName: devCenterName
//     projectName: projectName
//     poolName: poolName
//     networkConnectionName: networkConnectionName
//     hibernationSchedule: enableHibernation ? {
//       enabled: true
//     } : null
//     autoShutdown: autoShutdownEnabled ? {
//       enabled: true
//       time: autoShutdownTime
//       timeZone: autoShutdownTimeZone
//     } : null
//   }
// }
