#!/bin/bash
# WAF/OPA False Positive Measurement - WAF Policy Deployment
# Owner: Worf (Security & Cloud)
# Purpose: Deploy WAF policies in Detection mode (non-blocking) with full telemetry

set -euo pipefail

# Load configuration
if [ ! -f measurement-config.env ]; then
  echo "❌ Error: measurement-config.env not found. Run 01-setup-telemetry.sh first."
  exit 1
fi
source measurement-config.env

# Configuration
FRONTDOOR_NAME="${FRONTDOOR_NAME:-dk8s-frontdoor-dev}"
WAF_POLICY_NAME="${WAF_POLICY_NAME:-dk8s-waf-measurement}"
ENVIRONMENT="${ENVIRONMENT:-dev-eus2}"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deploying WAF policy: $WAF_POLICY_NAME"

# 1. Create WAF policy in Detection mode (non-blocking)
cat > /tmp/waf-policy.json <<'EOF_WAF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "policyName": { "type": "string" },
    "workspaceId": { "type": "string" },
    "environment": { "type": "string" }
  },
  "resources": [
    {
      "type": "Microsoft.Network/FrontDoorWebApplicationFirewallPolicies",
      "apiVersion": "2022-05-01",
      "name": "[parameters('policyName')]",
      "location": "Global",
      "sku": {
        "name": "Premium_AzureFrontDoor"
      },
      "properties": {
        "policySettings": {
          "enabledState": "Enabled",
          "mode": "Detection",
          "requestBodyCheck": "Enabled",
          "maxRequestBodySizeInKb": 128,
          "fileUploadEnforcement": "Enabled",
          "fileUploadLimitInMb": 100
        },
        "customRules": {
          "rules": [
            {
              "name": "nginxConfigInjectionBlock",
              "priority": 100,
              "ruleType": "MatchRule",
              "action": "Log",
              "matchConditions": [
                {
                  "matchVariable": "RequestUri",
                  "operator": "RegEx",
                  "negateCondition": false,
                  "matchValue": [
                    ";.*proxy_pass",
                    ";.*lua_",
                    "`.*\\$\\(",
                    "\\$\\{.*\\}"
                  ],
                  "transforms": [
                    "Lowercase",
                    "UrlDecode"
                  ]
                }
              ]
            },
            {
              "name": "annotationAbuseBlock",
              "priority": 110,
              "ruleType": "MatchRule",
              "action": "Log",
              "matchConditions": [
                {
                  "matchVariable": "RequestBody",
                  "operator": "Contains",
                  "negateCondition": false,
                  "matchValue": [
                    "configuration-snippet",
                    "server-snippet",
                    "stream-snippet"
                  ],
                  "transforms": [
                    "Lowercase"
                  ]
                }
              ]
            },
            {
              "name": "heartbeatDdosRatelimit",
              "priority": 120,
              "ruleType": "RateLimitRule",
              "rateLimitThreshold": 100,
              "rateLimitDurationInMinutes": 1,
              "action": "Log",
              "matchConditions": [
                {
                  "matchVariable": "RequestUri",
                  "operator": "Contains",
                  "negateCondition": false,
                  "matchValue": [
                    "/healthz",
                    "/health",
                    "/ping"
                  ],
                  "transforms": [
                    "Lowercase"
                  ]
                }
              ]
            }
          ]
        },
        "managedRules": {
          "managedRuleSets": [
            {
              "ruleSetType": "Microsoft_DefaultRuleSet",
              "ruleSetVersion": "2.1",
              "ruleSetAction": "Log",
              "ruleGroupOverrides": [
                {
                  "ruleGroupName": "SQLI",
                  "rules": [
                    {
                      "ruleId": "942100",
                      "enabledState": "Enabled",
                      "action": "Log"
                    },
                    {
                      "ruleId": "942110",
                      "enabledState": "Enabled",
                      "action": "Log"
                    }
                  ]
                }
              ],
              "exclusions": [
                {
                  "matchVariable": "RequestBodyJsonArgNames",
                  "selectorMatchOperator": "Equals",
                  "selector": "query",
                  "exclusionManagedRuleSets": [
                    {
                      "ruleSetType": "Microsoft_DefaultRuleSet",
                      "ruleSetVersion": "2.1",
                      "ruleGroups": [
                        {
                          "ruleGroupName": "SQLI",
                          "rules": []
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      }
    }
  ]
}
EOF_WAF

# Deploy WAF policy
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deploying WAF policy with ARM template"
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file /tmp/waf-policy.json \
  --parameters \
    policyName="$WAF_POLICY_NAME" \
    workspaceId="$WORKSPACE_ID" \
    environment="$ENVIRONMENT"

WAF_POLICY_ID=$(az network front-door waf-policy show \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

echo "✅ WAF policy deployed: $WAF_POLICY_ID"

# 2. Configure diagnostic settings for WAF logs
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Configuring diagnostic settings"
az monitor diagnostic-settings create \
  --name "waf-measurement-telemetry" \
  --resource "$WAF_POLICY_ID" \
  --workspace "$WORKSPACE_ID" \
  --logs '[
    {
      "category": "FrontdoorWebApplicationFirewallLog",
      "enabled": true,
      "retentionPolicy": {
        "enabled": true,
        "days": 30
      }
    }
  ]'

echo "✅ Diagnostic settings configured"

# 3. Associate WAF policy with Front Door endpoint
if [ -n "${FRONTDOOR_NAME:-}" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Associating WAF policy with Front Door: $FRONTDOOR_NAME"
  
  az afd security-policy create \
    --profile-name "$FRONTDOOR_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --security-policy-name "waf-measurement-policy" \
    --domains "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Cdn/profiles/$FRONTDOOR_NAME/afdEndpoints/*" \
    --waf-policy "$WAF_POLICY_ID"
  
  echo "✅ WAF policy associated with Front Door"
else
  echo "⚠️  FRONTDOOR_NAME not set, skipping association"
fi

# 4. Verify WAF policy status
echo ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Verifying WAF policy configuration"
az network front-door waf-policy show \
  --name "$WAF_POLICY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "{name:name, mode:policySettings.mode, enabledState:policySettings.enabledState, customRules:length(customRules.rules), managedRuleSets:length(managedRules.managedRuleSets)}" \
  -o table

echo ""
echo "✅ WAF policy deployment complete!"
echo ""
echo "Policy Details:"
echo "  - Name: $WAF_POLICY_NAME"
echo "  - Mode: Detection (non-blocking)"
echo "  - Custom Rules: 3 (nginx-config-injection, annotation-abuse, heartbeat-ratelimit)"
echo "  - Managed Rules: OWASP DRS 2.1"
echo "  - Logs: Streaming to Log Analytics workspace $WORKSPACE_NAME"
echo ""
echo "Next steps:"
echo "  1. Deploy OPA policies: ./03-deploy-opa-policies.sh"
echo "  2. Start measurement: ./04-start-measurement.sh"
echo ""
