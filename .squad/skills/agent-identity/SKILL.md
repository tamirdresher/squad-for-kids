# Agent Identity Skill

## Overview
Creates and manages Entra Agent Identity Blueprints for Squad agents.
Agent Identity gives each AI agent its own Entra ID identity (like a service account but purpose-built for agents).

## Prerequisites
- `Microsoft.Graph.Authentication` PowerShell module
- `MSIdentityTools` PowerShell module (optional, provides convenience cmdlets)
- User with `Application.ReadWrite.All` + `AgentIdentityBlueprint.Create` delegated permissions
- **IMPORTANT**: Token must NOT contain `Directory.AccessAsUser.All` — use Graph SDK auth, NOT `az` CLI

## Quick Start

### Create Blueprint (requires interactive auth)
```powershell
# Run in a VISIBLE terminal window (needs browser for auth)
pwsh -File .squad/skills/agent-identity/create-agent-identity.ps1
```

### Why Not `az` CLI?
The `az` CLI app registration (`04b07795`) includes `Directory.AccessAsUser.All` as a static permission.
Agent Identity APIs explicitly reject tokens containing this permission.
You MUST use `Connect-MgGraph` (Graph SDK client `14d82eec`) which can request
`AgentIdentityBlueprint.Create` without `Directory.AccessAsUser.All`.

### Key API Endpoints
| Operation | Method | URI |
|-----------|--------|-----|
| Create Blueprint | POST | `graph.microsoft.com/beta/applications/graph.agentIdentityBlueprint` |
| Create BP Service Principal | POST | `graph.microsoft.com/beta/servicePrincipals/graph.agentIdentityBlueprintPrincipal` |
| Create Agent Identity | POST | `graph.microsoft.com/beta/applications/{blueprintId}/graph.agentIdentityBlueprint/agentIdentities` |
| Create Agent User | POST | TBD (via MSIdentityTools `New-MsIdAgentIDUserForAgentId`) |
| Get Agent Token | GET | Via MSIdentityTools `Get-MsIdAgentIdentityToken` |

### Required Scopes (Delegated)
- `AgentIdentityBlueprint.Create`
- `AgentIdentityBlueprintPrincipal.Create`
- `AppRoleAssignment.ReadWrite.All`
- `Application.ReadWrite.All`
- `User.ReadWrite.All`

### Required Body Fields (MSFT Tenant)
- `displayName`: Name for the blueprint
- `serviceManagementReference`: Valid Service Tree GUID (e.g., `caa72385-03f7-4120-a02f-611c40d6d140`)
- `sponsors@odata.bind`: Array of user URIs (required for MSFT tenant)

### Application Permissions (for admin-consented apps)
These app-level permissions exist but require tenant admin consent:
- `AgentIdentityBlueprint.Create` (`ea4b2453-ad2d-4d94-9155-10d5d9493ce9`)
- `AgentIdentityBlueprintPrincipal.Create` (`8959696d-d07e-4916-9b1e-3ba9ce459161`)
- `AgentIdentity.Create.All` (`ad25cc1d-84d8-47df-a08e-b34c2e800819`)

### Helper App (pre-created)
- App Name: `squad-agent-identity-helper`
- App ID: `a0ae7a27-1cde-47b2-a3f5-cb37669f39c1`
- Object ID: `98613f74-b730-4c45-aa5b-f7e79a93f138`
- Redirect URI: `http://localhost`
- Status: Created, needs admin consent for application permissions

## Architecture
See GitHub Issue #2 in `tamirdresher_microsoft/adc-research` for full analysis.

### Two Models
1. **ADC-Owned Shared Blueprint** — Quick start, requires server-side config (AGENT_BLUEPRINT_* env vars on management server)
2. **BYOAI (Bring Your Own Agent Identity)** — Create own blueprint in Entra, reference `{tenantId, agentId, blueprintAppId}` when creating sandbox

### ADC Integration
Once blueprint is created:
```powershell
# Assign to ADC sandbox via BYOAI
Invoke-AdcMcp -Tool "create_sandbox" -Arguments @{
    agentIdentity = @{
        tenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47"
        agentId = "<agent-app-id>"
        blueprintAppId = "<blueprint-app-id>"
    }
    # ... other sandbox params
}
```

## Status
- [x] MSIdentityTools module installed
- [x] Application permissions identified (30+ agent-related permissions in Graph)
- [x] Helper app registration created
- [x] Self-contained creation script ready
- [ ] **BLOCKED**: Needs interactive browser auth (device code times out without human)
- [ ] **BLOCKED**: App permissions need tenant admin consent