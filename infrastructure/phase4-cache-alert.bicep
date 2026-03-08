// FedRAMP Dashboard: Cache Hit Rate Alert
// Issue #106 - Post-merge monitoring for PR #102
// Owner: Data (Code Expert)

@description('Name of the existing Application Insights resource')
param appInsightsName string

@description('Resource ID of the Action Group for alert notifications')
param actionGroupId string

@description('Location for the alert rule')
param location string = resourceGroup().location

@description('Environment name (dev, stg, prod)')
param environment string

@description('Tags for resource organization')
param tags object = {
  Environment: environment
  Component: 'Monitoring'
  ManagedBy: 'Bicep'
  Owner: 'FedRAMP-Dashboard-Team'
}

// Reference existing Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

// Cache Hit Rate Alert: Triggers when hit rate < 70% for 15 minutes
// Updated to use explicit cache telemetry (Issue #115)
resource cacheHitRateAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'FedRAMP-Dashboard-Cache-Hit-Rate-Low-${environment}'
  location: location
  tags: tags
  properties: {
    displayName: 'FedRAMP Dashboard - Cache Hit Rate Below 70% (${environment})'
    description: 'Alert when API response cache hit rate falls below 70% for 15 minutes. Uses explicit cache telemetry (CacheHit/CacheMiss events) for precision. Indicates potential cache configuration issue or unexpected access patterns.'
    severity: 2  // Warning
    enabled: true
    evaluationFrequency: 'PT5M'   // Evaluate every 5 minutes
    windowSize: 'PT15M'           // 15-minute evaluation window
    scopes: [
      appInsights.id
    ]
    criteria: {
      allOf: [
        {
          query: '''
            // Updated query to use explicit cache telemetry (Issue #115)
            // Uses custom events (CacheHit/CacheMiss) instead of duration inference
            customEvents
            | where timestamp > ago(15m)
            | where name in ("CacheHit", "CacheMiss")
            | where customDimensions.Endpoint has "compliance"
            | extend IsCacheHit = iff(name == "CacheHit", 1, 0)
            | summarize 
                CacheHits = sum(IsCacheHit),
                TotalRequests = count()
            | extend CacheHitRate = (CacheHits * 100.0) / TotalRequests
            | where CacheHitRate < 70
            | project CacheHitRate, CacheHits, TotalRequests
          '''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroupId
      ]
      customProperties: {
        Runbook: 'https://github.com/tamirdresher_microsoft/tamresearch1/blob/main/docs/fedramp-dashboard-cache-sli.md#42-remediation-playbook'
        Severity: 'Warning'
        Team: 'FedRAMP-OnCall'
        SLO: 'CacheHitRate >= 70%'
        IssueRef: '#106'
      }
    }
  }
}

// Output for reference in deployment pipelines
output alertId string = cacheHitRateAlert.id
output alertName string = cacheHitRateAlert.name
