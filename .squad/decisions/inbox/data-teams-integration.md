# Decision: GitHub-Teams Integration Approach

**Date:** 2026-03-07  
**Author:** Data  
**Issue:** #33  
**Status:** Recommended

## Context

Tamir requested automation of GitHub-Teams integration setup, asking specifically about:
1. Using Playwright CLI with Edge browser
2. Alternative Windows automation tools for Teams desktop app
3. Avoiding manual browser steps

## Investigation

Researched three approaches:
1. **Microsoft Graph API** - ✅ Best option
2. **Playwright browser automation** - ❌ Not applicable (Teams is native app)
3. **Windows UI automation** - ❌ Fragile, complex, security concerns

## Key Findings

### What CAN Be Automated (Graph API)
- **App Installation**: GitHub app installation to Teams via `New-MgTeamInstalledApp` cmdlet
- **Team/Channel Discovery**: Programmatic team and channel enumeration
- **Permissions**: Requires `TeamsAppInstallation.ReadWriteForTeam` scope

**GitHub App ID**: `0d820ecd-def2-4297-adad-78056cde7c78` (verified from Microsoft docs)

### What CANNOT Be Automated
- **`@GitHub signin`**: Initiates GitHub OAuth flow requiring user consent
- **`@GitHub subscribe`**: Bot command that needs authenticated context
- **Reason**: Security by design - OAuth flows must have user interaction

## Recommended Solution

**Hybrid Approach**:
1. **Automated** (PowerShell + Graph API): Install GitHub app to team
2. **Manual** (< 2 min): User completes OAuth signin and subscription in Teams

## Implementation

Created `setup-github-teams-integration.ps1`:
- Authenticates with Microsoft Graph
- Lists available teams
- Installs GitHub app programmatically
- Provides clear manual step instructions

**Time Savings**: Reduces setup from ~5 minutes to ~2 minutes (60% reduction)

## Alternative Considered: Windows UI Automation

Evaluated tools:
- **UI Automation API** (C#/.NET)
- **Power Automate Desktop**
- **AutoHotkey**

**Why Rejected**:
- Teams desktop UI changes frequently (brittle)
- No reliable element selectors for bot interactions
- Security context issues (user must be signed in)
- Complexity >> benefit

## Security Notes

- Graph API requires admin consent for team-level permissions
- OAuth flows correctly require interactive user consent (can't be bypassed)
- Script uses delegated permissions (runs as user, not app-only)

## References

- [Microsoft Graph: Install app to team](https://learn.microsoft.com/en-us/graph/api/team-post-installedapps)
- [GitHub Teams Integration](https://github.com/integrations/microsoft-teams)
- PowerShell module: `Microsoft.Graph.Teams` v2.26.1
