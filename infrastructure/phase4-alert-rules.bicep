param location string = resourceGroup().location
param logAnalyticsWorkspaceId string
param actionGroupId string
param environment string

// Extract workspace name from full resource ID
var workspaceName = last(split(logAnalyticsWorkspaceId, '/'))

// Alert Rule 1: Control Drift Detection
resource controlDriftAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'fedramp-control-drift-${environment}'
  location: location
  properties: {
    displayName: 'FedRAMP Control Drift Detection'
    description: 'Detects when control failure rate increases > 10% vs prior period'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT1H'
    windowSize: 'PT168H'  // 7 days
    scopes: [
      logAnalyticsWorkspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: '''
            let lookback_hours = 168;
            let comparison_period_hours = 336;
            let drift_threshold = 0.10;
            let current_period = ControlValidationResults_CL
            | where TimeGenerated between (ago(lookback_hours * 1h) .. now())
            | summarize 
                current_total = count(),
                current_failures = countif(Status_s == "FAIL")
              by ControlId_s, Environment_s
            | extend current_fail_rate = todouble(current_failures) / current_total;
            let prior_period = ControlValidationResults_CL
            | where TimeGenerated between (ago(comparison_period_hours * 1h) .. ago(lookback_hours * 1h))
            | summarize 
                prior_total = count(),
                prior_failures = countif(Status_s == "FAIL")
              by ControlId_s, Environment_s
            | extend prior_fail_rate = todouble(prior_failures) / prior_total;
            current_period
            | join kind=inner prior_period on ControlId_s, Environment_s
            | extend drift_pct = (current_fail_rate - prior_fail_rate) * 100
            | where drift_pct > (drift_threshold * 100)
            | project ControlId_s, Environment_s, drift_pct
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
    }
  }
}

// Alert Rule 2: Control Regression
resource controlRegressionAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'fedramp-control-regression-${environment}'
  location: location
  properties: {
    displayName: 'FedRAMP Control Regression Detection'
    description: 'Detects when previously passing control begins failing (3+ consecutive)'
    severity: 0  // P0 severity
    enabled: true
    evaluationFrequency: 'PT15M'
    windowSize: 'PT1H'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: '''
            let lookback_hours = 1;
            let prior_baseline_hours = 24;
            let consecutive_failures_threshold = 3;
            let recent_failures = ControlValidationResults_CL
            | where TimeGenerated > ago(lookback_hours * 1h)
            | where Status_s == "FAIL"
            | summarize failure_count = count() by ControlId_s, Environment_s
            | where failure_count >= consecutive_failures_threshold;
            let prior_passing = ControlValidationResults_CL
            | where TimeGenerated between (ago(prior_baseline_hours * 1h) .. ago(lookback_hours * 1h))
            | where Status_s == "PASS"
            | summarize pass_count = count() by ControlId_s, Environment_s
            | where pass_count > 0;
            recent_failures
            | join kind=inner prior_passing on ControlId_s, Environment_s
            | project ControlId_s, Environment_s, failure_count
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
    }
  }
}

// Alert Rule 3: Compliance Threshold Breach (KQL-based metric)
resource thresholdBreachAlert 'Microsoft.Insights/scheduledQueryRules@2021-08-01' = {
  name: 'fedramp-threshold-breach-${environment}'
  location: location
  properties: {
    displayName: 'FedRAMP Compliance Threshold Breach'
    description: 'Alert when compliance rate falls below 95%'
    severity: 1
    enabled: true
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    scopes: [
      logAnalyticsWorkspaceId
    ]
    targetResourceTypes: [
      'Microsoft.OperationalInsights/workspaces'
    ]
    criteria: {
      allOf: [
        {
          query: '''
            ControlValidationResults_CL
            | where TimeGenerated > ago(15m)
            | summarize 
                total = count(),
                passes = countif(Status_s == "PASS")
              by Environment_s
            | extend compliance_rate = (todouble(passes) / total) * 100
            | where compliance_rate < 95.0
            | project Environment_s, compliance_rate
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
    }
  }
}

output controlDriftAlertId string = controlDriftAlert.id
output controlRegressionAlertId string = controlRegressionAlert.id
output thresholdBreachAlertId string = thresholdBreachAlert.id
