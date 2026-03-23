# Squad Secrets & Credentials Reference

## How to Retrieve Secrets

### From Windows Credential Manager (local machine)
```powershell
# ADC API Key
$cred = New-Object System.Management.Automation.PSCredential("x", (cmdkey /list:ADC_API_KEY | Out-Null; [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Read-Host -AsSecureString)))))
# Simpler: use the PowerShell helper
$key = (cmdkey /list:ADC_API_KEY 2>$null) -match "User" # verify it exists
```

### From GitHub Secrets (CI/CD workflows)
Access via `${{ secrets.SECRET_NAME }}` in GitHub Actions workflows.

### From GitHub Variables (non-sensitive config)
Access via `${{ vars.VARIABLE_NAME }}` in workflows, or:
```powershell
gh variable get ADC_MCP_ENDPOINT --repo tamirdresher_microsoft/tamresearch1
```

## Secret Inventory

| Secret | Location(s) | Purpose | Expires |
|--------|-------------|---------|---------|
| `ADC_API_KEY` | GH Secret (tamresearch1, adc-research) + Win CredMgr | ADC MCP endpoint auth | 2026-06-15 |
| `AGENT_IDENTITY_APP_ID` | GH Secret (tamresearch1) | Entra helper app for Agent ID | N/A |
| `SQUAD_EMAIL_PASSWORD` | GH Secret (tamresearch1) | Email automation | ? |
| `SQUAD_EMAIL_REFRESH_TOKEN` | GH Secret (tamresearch1) | OAuth email refresh | ? |
| `SQUAD_GMAIL_PASSWORD` | GH Secret (tamresearch1) | Gmail app password | ? |
| `SQUAD_WEBHOOK_*` | GH Secret (tamresearch1) | Teams webhook URLs (6 channels) | ? |
| `TEAMS_WEBHOOK_URL` | GH Secret (tamresearch1) | Primary Teams webhook | ? |
| `TELEGRAM_BOT_TOKEN` | GH Secret (tamresearch1) | Telegram bot | ? |
| `WA_MONITOR_SESSION` | GH Secret (tamresearch1) | WhatsApp monitor session | ? |

## Variable Inventory (non-sensitive)

| Variable | Value | Purpose |
|----------|-------|---------|
| `ADC_MCP_ENDPOINT` | `https://management.agentdevcompute.io/mcp` | ADC MCP server URL |
| `ADC_UPLOAD_ENDPOINT` | `https://management.azuredevcompute.io/contentpackages/upload` | Content package upload URL |
| `AGENT_IDENTITY_HELPER_APP_ID` | `a0ae7a27-1cde-47b2-a3f5-cb37669f39c1` | Entra app for Agent Identity ops |
| `ADC_API_KEY_NAME` | `squad-tamresearch1` | API key name in ADC portal |
| `ADC_API_KEY_EXPIRES` | `2026-06-15` | API key expiry date |

## For Squad Agents: How to Use

### ADC MCP calls
```powershell
# Get API key from credential manager
$adcKey = "7eca89a390a20a447e76f79a609299b88d042ad7139b3f5df41346cc751b41d7"
# Or from env if set by workflow
$adcKey = $env:ADC_API_KEY

# Use with ADC skill
. .squad/skills/adc-sandbox/adc-mcp.ps1
$env:ADC_API_KEY = $adcKey
Get-AdcSandboxes
```

### Agent Identity
```powershell
# Helper app ID (for auth without Directory.AccessAsUser.All)
$appId = "a0ae7a27-1cde-47b2-a3f5-cb37669f39c1"
# See .squad/skills/agent-identity/SKILL.md for full instructions
```

## Adding New Secrets
```powershell
# GitHub Secret
echo "secret-value" | gh secret set SECRET_NAME --repo tamirdresher_microsoft/tamresearch1

# Windows Credential Manager
cmdkey /generic:SECRET_NAME /user:squad-tamresearch1 /pass:"secret-value"

# GitHub Variable (non-sensitive)
gh variable set VAR_NAME --body "value" --repo tamirdresher_microsoft/tamresearch1
```