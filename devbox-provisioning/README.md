# DevBox Provisioning Infrastructure

> **Phase 1: Infrastructure as Code for Microsoft Dev Box automation**  
> Issue #35 — Automate provisioning of development environments

## Overview

This directory contains Infrastructure as Code (IaC) templates and automation scripts for provisioning Microsoft Dev Box instances. Designed to enable quick, reproducible cloning of development environments with consistent configuration.

## Architecture

- **Bicep Templates:** Declarative infrastructure definitions for Dev Box resources
- **PowerShell Scripts:** Automation wrappers for CLI-based provisioning workflows
- **Azure CLI Integration:** Uses `az devcenter` extension for Dev Box management

## Prerequisites

### Tools
- **Azure CLI** (`az`) version 2.50.0 or higher
  ```powershell
  az --version
  ```
- **Azure CLI Dev Center Extension**
  ```powershell
  az extension add --name devcenter
  az extension list --query "[?name=='devcenter']"
  ```
- **Bicep CLI** (optional, for template development)
  ```powershell
  az bicep version
  ```

### Azure Permissions
- **Dev Center User** or **Dev Center Project Admin** role on target Dev Center project
- **Read access** to Dev Center, Project, and Pool resources
- **Contributor** role for creating Dev Box instances

### Authentication
```powershell
# Login to Azure
az login

# Set subscription (if multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify access to Dev Center
az devcenter dev dev-box list
```

## Configuration

Before provisioning, you need to gather configuration from your current Dev Box:

### 1. Discover Current Dev Box Settings

```powershell
# List your Dev Boxes
az devcenter dev dev-box list --output table

# Get detailed info about a specific Dev Box
az devcenter dev dev-box show --name "YOUR_DEVBOX_NAME" --output json

# List available projects
az devcenter dev project list --output table

# List available pools in a project
az devcenter dev pool list --project-name "YOUR_PROJECT" --output table
```

### 2. Update Configuration Files

Edit the following files with your discovered values:

**`bicep/main.bicep`** — Update parameters section:
```bicep
param devCenterName string = 'your-dev-center-name'
param projectName string = 'your-project-name'
param poolName string = 'your-pool-name'
```

**`scripts/provision.ps1`** — Update variables section:
```powershell
$DevCenterName = "your-dev-center-name"
$ProjectName = "your-project-name"
$PoolName = "your-pool-name"
```

## Usage

### Natural Language Provisioning (Phase 2)

The Squad skill enables natural language DevBox provisioning. Use phrases like:

```
"Create 3 new devboxes like mine"
"Clone my devbox as feature-auth"
"Create a devbox named test-env in project research-lab using pool high-memory"
"What's my current devbox configuration?"
```

The skill is located at `.squad/skills/devbox-provisioning/SKILL.md` and provides:
- Pattern matching for common provisioning requests
- Auto-detection of current DevBox configuration
- Validation and error handling
- Bulk provisioning orchestration

For technical details, see the [SKILL.md](../.squad/skills/devbox-provisioning/SKILL.md) documentation.

### Quick Start: Clone Your Dev Box

The fastest way to create a new Dev Box with the same configuration as your current one:

```powershell
# Run the clone script
.\scripts\clone-devbox.ps1 -NewDevBoxName "my-new-devbox"
```

This script will:
1. Auto-detect your current Dev Box configuration
2. Create a new Dev Box with the same Dev Center, project, and pool
3. Wait for provisioning to complete
4. Display connection instructions

### Manual Provisioning

For more control over the provisioning process:

```powershell
# Option 1: Using the PowerShell script
.\scripts\provision.ps1 -DevBoxName "my-devbox" -ProjectName "MyProject" -PoolName "MyPool"

# Option 2: Using Azure CLI directly
az devcenter dev dev-box create `
  --dev-center-name "MyDevCenter" `
  --project-name "MyProject" `
  --pool-name "MyPool" `
  --name "my-devbox"
```

### Using Bicep Templates (Future)

Bicep deployment is scaffolded for future use when ARM templates are supported for Dev Box provisioning:

```powershell
# Deploy via Bicep (when ARM support is available)
az deployment group create `
  --resource-group "rg-devbox" `
  --template-file bicep/main.bicep `
  --parameters devBoxName="my-devbox"
```

## Scripts Reference

### `provision.ps1`
**Purpose:** Create a new Dev Box with specified configuration  
**Parameters:**
- `-DevBoxName` (required): Name for the new Dev Box
- `-DevCenterName` (optional): Override default Dev Center
- `-ProjectName` (optional): Override default project
- `-PoolName` (optional): Override default pool
- `-WaitForCompletion` (optional): Wait for provisioning to finish (default: true)

**Example:**
```powershell
.\scripts\provision.ps1 -DevBoxName "feature-branch-env" -WaitForCompletion
```

### `clone-devbox.ps1`
**Purpose:** Auto-detect current Dev Box and clone it  
**Parameters:**
- `-NewDevBoxName` (required): Name for the cloned Dev Box
- `-SourceDevBoxName` (optional): Source Dev Box to clone (auto-detected if omitted)

**Example:**
```powershell
.\scripts\clone-devbox.ps1 -NewDevBoxName "hotfix-env"
```

### `bulk-provision.ps1` (Phase 2)
**Purpose:** Create multiple Dev Boxes for team environments  
**Parameters:**
- `-Count` (optional): Number of Dev Boxes to create (default: 3)
- `-NamePrefix` (optional): Prefix for generated names (default: "devbox")
- `-Names` (optional): Explicit array of names
- `-Sequential` (optional): Create one at a time (default: parallel)
- `-MaxConcurrent` (optional): Max parallel operations (default: 5)

**Example:**
```powershell
# Create 5 Dev Boxes with auto-generated names
.\scripts\bulk-provision.ps1 -Count 5 -NamePrefix "sprint-42"

# Create Dev Boxes with explicit names
.\scripts\bulk-provision.ps1 -Names @("alice-dev", "bob-dev", "charlie-dev")
```

## Troubleshooting

### Extension Installation Fails

If `az extension add --name devcenter` fails with pip errors:

1. **Check Python environment:**
   ```powershell
   # Verify Azure CLI Python
   az --version
   ```

2. **Manual extension download:**
   - Download the latest `devcenter` extension from [Azure CLI Extensions](https://github.com/Azure/azure-cli-extensions)
   - Install manually: `az extension add --source <path-to-whl>`

3. **Alternative: Use REST API directly:**
   The scripts fall back to REST API if the extension is unavailable.

### Dev Box Creation Fails

**Error:** "Resource not found" or "Access denied"
- Verify you have the correct permissions (Dev Center User role)
- Check that Dev Center, project, and pool names are correct
- Confirm your Azure subscription is active

**Error:** "Quota exceeded"
- Check your Dev Box quota limits in the Azure Portal
- Request quota increase if needed

**Error:** "Pool not available"
- Verify the pool exists: `az devcenter dev pool list --project-name "YOUR_PROJECT"`
- Check pool capacity and health status

### Connection Issues

If you cannot connect to a provisioned Dev Box:
1. Verify the Dev Box status: `az devcenter dev dev-box show --name "YOUR_DEVBOX"`
2. Check that provisioning completed successfully (status: `Running`)
3. Ensure you have RDP/SSH access configured
4. Verify network connectivity and firewall rules

## Roadmap

### Phase 1 (Complete) ✅
- ✅ Bicep template scaffolding
- ✅ PowerShell provisioning scripts
- ✅ Auto-detection and cloning capabilities
- ✅ Documentation and troubleshooting guides

### Phase 2 (Complete) ✅
- ✅ Squad Skill: Natural language Dev Box provisioning
- ✅ Bulk provisioning script for team environments
- ✅ Natural language pattern matching and interpretation
- ✅ Error handling and validation patterns

### Phase 3 (Planned)
- 🔲 MCP Server integration (`@microsoft/devbox-mcp`)
- 🔲 Advanced templating: custom images, network configs
- 🔲 Cost optimization: auto-hibernation schedules
- 🔲 CI/CD integration: ephemeral DevBoxes for PRs

## Contributing

To add features or fix issues:
1. Create a feature branch: `git checkout -b devbox/feature-name`
2. Test your changes locally
3. Update documentation
4. Submit a pull request

## References

- [Microsoft Dev Box Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Azure CLI Dev Center Extension](https://learn.microsoft.com/cli/azure/devcenter)
- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Dev Box MCP Server](https://github.com/microsoft/devbox-mcp)

---

**Maintained by:** B'Elanna (Infrastructure Expert)  
**Issues:** #35 (Phase 1), #63 (Phase 2)  
**Status:** Phase 2 Complete
