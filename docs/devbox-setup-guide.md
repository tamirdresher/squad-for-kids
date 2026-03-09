# Dev Box Setup Guide for Tamir Dresher

> **Issue #103** - Infrastructure automation for Microsoft Dev Box provisioning  
> **Created by:** B'Elanna (Infrastructure Expert)  
> **Date:** 2026-03-09

## Executive Summary

This guide documents the existing Dev Box infrastructure in this repository and provides step-by-step instructions for creating and managing Dev Boxes. The repository includes complete automation tooling (scripts, Squad skills, MCP server integration) ready for use once the Azure CLI extension is properly configured.

## Current Infrastructure Status

### ✅ Available Assets

1. **Provisioning Scripts** (`devbox-provisioning/scripts/`)
   - `clone-devbox.ps1` - Auto-detects and clones existing Dev Box configurations
   - `provision.ps1` - Creates Dev Boxes with specified parameters
   - Fully documented PowerShell automation

2. **Squad Skill** (`.squad/skills/devbox-provisioning/`)
   - Natural language Dev Box provisioning
   - Patterns: "Create a devbox called X", "Clone my devbox", "Create 3 devboxes"
   - Auto-detection of configuration
   - Error handling and validation

3. **MCP Server Integration** (`devbox-provisioning/mcp-server/`)
   - Phase 3 complete
   - `@microsoft/devbox-mcp-server` package
   - Standard Model Context Protocol interface
   - 7 core tools: list, create, clone, show, status, delete, bulk operations

4. **Documentation**
   - Comprehensive README: `devbox-provisioning/README.md`
   - Skill patterns: `.squad/skills/devbox-provisioning/SKILL.md`
   - Clone script inline documentation

5. **Screenshots** (Repository Root)
   - `devbox-after-create.png` - Post-provisioning state
   - `devbox-browser-connected.png` - Browser connection successful
   - `devbox-browser-connection-settings.png` - Connection configuration
   - `devbox-clicked.png` - Portal navigation
   - `devbox-dashboard.png` - Dev Box dashboard view
   - `devbox-desktop-loaded.png` - Desktop environment
   - `devbox-details-panel.png` - Configuration details
   - `devbox-details-scrolled.png` - Extended configuration
   - `devbox-home.png` - Portal home page
   - `devbox-landing.png` - Initial landing page
   - `devbox-moreinfo.png` - Additional information

### ⚠️ Prerequisite Issue

**Azure CLI Dev Center Extension**: Installation failed due to pip error

```
ERROR: An error occurred. Pip failed with status code 1.
```

**Current Environment:**
- Azure CLI: v2.69.0 ✅
- Authentication: tamirdresher@microsoft.com ✅
- Subscription: WCD_MicroServices_Staging_LBI ✅
- Dev Center Extension: Not installed ❌

## How to Create a Dev Box

### Option 1: Azure Portal (Recommended for Manual Creation)

**Fastest path for immediate results:**

1. Navigate to https://devportal.microsoft.com
2. Sign in with your Microsoft account (tamirdresher@microsoft.com)
3. Click **"New Dev Box"** or **"+"** button
4. Select your Dev Center and Project from dropdowns
5. Choose a Pool (defines hardware specs and OS image)
6. Enter a Dev Box name (3-63 characters, alphanumeric + hyphens)
7. Click **"Create"**
8. Wait 15-30 minutes for provisioning

**Connection:**
- Once provisioning completes, click **"Connect"** in the portal
- Choose connection method: Browser, Remote Desktop, Windows App
- For browser connection: Click **"Connect via browser"**

### Option 2: PowerShell Script (After Extension Fix)

**Automated cloning of existing configuration:**

```powershell
# Step 1: Fix the extension installation
# Try manual install with --upgrade flag
az extension add --name devcenter --upgrade

# If that fails, install manually from wheel file:
# Download from: https://github.com/Azure/azure-cli-extensions/tree/main/src/devcenter
# Then: az extension add --source <path-to-wheel-file>

# Step 2: Verify extension is working
az devcenter dev dev-box list --output table

# Step 3: Clone your existing Dev Box
cd C:\temp\tamresearch1\devbox-provisioning\scripts
.\clone-devbox.ps1 -NewDevBoxName "my-new-devbox"
```

**Script Features:**
- Auto-detects your current Dev Box configuration
- Validates naming and prerequisites
- Waits for provisioning completion (optional)
- Reports connection instructions

**Parameters:**
```powershell
.\clone-devbox.ps1 `
  -NewDevBoxName "feature-branch-env" `
  -SourceDevBoxName "my-existing-devbox" `  # Optional, auto-detected if omitted
  -WaitForCompletion $true `                 # Default: $true
  -TimeoutMinutes 30                         # Default: 30
```

### Option 3: Natural Language via Squad Skill

**After extension is working, use natural language:**

Say to the Squad:
- "Create a new devbox called feature-auth"
- "Clone my devbox as test-environment"
- "Create 3 devboxes for the team"
- "What's my devbox configuration?"
- "Provision a devbox named hotfix-env"

The skill will:
1. Parse your request
2. Auto-detect configuration
3. Validate prerequisites
4. Execute provisioning
5. Report results

## Configuration Discovery

To automate Dev Box creation, you need these parameters:

### Required Information

1. **Dev Center Name** - Example: `contoso-devcenter`
2. **Project Name** - Example: `platform-engineering`
3. **Pool Name** - Example: `general-purpose-pool`
4. **Dev Box Name** - 3-63 characters, alphanumeric + hyphens

### How to Find Your Configuration

**Method 1: Azure Portal**
- Go to https://devportal.microsoft.com
- Your current Dev Box will show Project and Pool in the details panel
- Dev Center is visible in the portal header or settings

**Method 2: Azure CLI** (once extension is working)
```powershell
# List all your Dev Boxes
az devcenter dev dev-box list --output table

# Get details of a specific Dev Box
az devcenter dev dev-box show --name "YOUR_DEVBOX_NAME" --output json

# List available projects
az devcenter dev project list --output table

# List pools in a project
az devcenter dev pool list --project-name "YOUR_PROJECT" --output table
```

**Method 3: Screenshots**
- Check the repository screenshots in the root directory
- `devbox-details-panel.png` shows configuration details
- `devbox-dashboard.png` shows project/pool information

## Troubleshooting

### Extension Installation Failed

**Problem:** `az extension add --name devcenter` fails with pip error

**Solution 1: Upgrade pip**
```powershell
python -m pip install --upgrade pip
az extension add --name devcenter --upgrade
```

**Solution 2: Manual Installation**
1. Download the latest devcenter wheel from:
   https://github.com/Azure/azure-cli-extensions/releases
2. Install manually:
   ```powershell
   az extension add --source "path\to\devcenter-X.Y.Z-py3-none-any.whl"
   ```

**Solution 3: Use REST API**
The provisioning scripts have fallback REST API support if CLI extension isn't available.

### Dev Box Creation Fails

**Error: "Resource not found" or "Access denied"**
- Verify Dev Center User role or higher
- Check Dev Center, Project, and Pool names are correct
- Confirm subscription is active

**Error: "Quota exceeded"**
- Check quota limits in Azure Portal → Dev Centers → Quotas
- Request increase if needed
- Delete unused Dev Boxes to free capacity

**Error: "Pool not available"**
- Verify pool exists: `az devcenter dev pool list --project-name "PROJECT"`
- Check pool health status in portal
- Confirm pool has capacity

### Connection Issues

**Cannot connect to provisioned Dev Box:**
1. Verify status: `az devcenter dev dev-box show --name "NAME"`
2. Confirm state is "Running" (not "Provisioning" or "Stopped")
3. Check network connectivity and firewall rules
4. Try browser connection first (most reliable)
5. For RDP: Ensure Remote Desktop client is installed

## Advanced Usage

### Bulk Provisioning

Create multiple Dev Boxes for team:

```powershell
# Create 5 Dev Boxes with auto-generated names
.\bulk-provision.ps1 -Count 5 -NamePrefix "sprint-42"

# Create Dev Boxes with explicit names
.\bulk-provision.ps1 -Names @("alice-dev", "bob-dev", "charlie-dev")
```

### Custom Configuration

Override Dev Center/Project/Pool:

```powershell
.\provision.ps1 `
  -DevBoxName "custom-env" `
  -DevCenterName "my-devcenter" `
  -ProjectName "research-lab" `
  -PoolName "high-memory-pool"
```

### Non-Blocking Provisioning

Create Dev Box without waiting:

```powershell
.\clone-devbox.ps1 `
  -NewDevBoxName "async-box" `
  -WaitForCompletion $false
```

Then check status later:
```powershell
az devcenter dev dev-box show --name "async-box" --query "provisioningState"
```

## Integration Points

### Teams Webhook

Dev Box status notifications can be sent to Teams:

**Webhook Location:** `C:\Users\tamirdresher\.squad\teams-webhook.url`

**Send Notification:**
```powershell
$webhookUrl = Get-Content "$env:USERPROFILE\.squad\teams-webhook.url" -Raw
$message = @{ text = "Dev Box 'feature-xyz' is ready!" } | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl.Trim() -Method Post -ContentType "application/json" -Body $message
```

### GitHub Actions

Repository has workflows that can be extended for Dev Box automation:
- `.github/workflows/squad-daily-digest.yml`
- `.github/workflows/squad-issue-notify.yml`

Add Dev Box provisioning status to daily digest or trigger provisioning on issue labels.

### MCP Server

For programmatic access from AI agents:

```json
{
  "mcpServers": {
    "devbox": {
      "command": "npx",
      "args": ["-y", "@microsoft/devbox-mcp-server"]
    }
  }
}
```

Available tools:
- `devbox_list` - List all Dev Boxes
- `devbox_create` - Create new Dev Box
- `devbox_clone` - Clone existing Dev Box
- `devbox_show` - Get Dev Box details
- `devbox_status` - Check provisioning status
- `devbox_delete` - Delete Dev Box
- `devbox_bulk_create` - Create multiple Dev Boxes

## Next Steps

### Immediate (Manual)

1. **Create via Portal** - Fastest path to get a Dev Box running today
   - Go to https://devportal.microsoft.com
   - Follow Option 1 instructions above

2. **Document Configuration** - Once created, note your:
   - Dev Center name
   - Project name
   - Pool name
   - Hardware specs
   - OS image

### Short-Term (Fix Automation)

1. **Fix Extension** - Resolve pip/extension installation issue
   - Try upgrade pip approach
   - Or use manual wheel installation
   - Validate with `az devcenter dev dev-box list`

2. **Test Clone Script** - Once extension works
   - Run `.\clone-devbox.ps1 -NewDevBoxName "test-clone"`
   - Verify auto-detection and provisioning
   - Document any issues

### Long-Term (Full Automation)

1. **Integrate with Squad** - Enable natural language provisioning
   - Squad skill already exists
   - Just needs working extension
   - Test with "Create a devbox called X"

2. **CI/CD Integration** - Ephemeral environments
   - Provision Dev Box on PR creation
   - Auto-delete on PR merge/close
   - Reduces manual environment management

3. **Cost Optimization** - Auto-hibernation
   - Schedule nightly shutdown
   - Start on-demand
   - Track usage and costs

## References

### Repository Documentation
- **Full provisioning guide:** `devbox-provisioning/README.md`
- **Squad skill patterns:** `.squad/skills/devbox-provisioning/SKILL.md`
- **Clone script source:** `devbox-provisioning/scripts/clone-devbox.ps1`
- **Provision script source:** `devbox-provisioning/scripts/provision.ps1`
- **MCP server docs:** `devbox-provisioning/mcp-server/README.md`

### Microsoft Documentation
- **Dev Box Overview:** https://learn.microsoft.com/azure/dev-box/
- **Azure CLI Extension:** https://learn.microsoft.com/cli/azure/devcenter
- **Dev Box Portal:** https://devportal.microsoft.com
- **MCP Server Tutorial:** https://learn.microsoft.com/azure/dev-box/tutorial-get-started-dev-box-mcp-server

### Related Issues
- **Issue #35** - Phase 1: Infrastructure provisioning scripts
- **Issue #63** - Phase 2: Squad skill for natural language provisioning
- **Issue #65** - Phase 3: MCP Server integration
- **Issue #103** - This guide: Dev Box creation and documentation

---

**Maintained by:** B'Elanna (Infrastructure Expert)  
**Status:** Complete - Awaiting Azure CLI extension fix for full automation  
**Last Updated:** 2026-03-09
