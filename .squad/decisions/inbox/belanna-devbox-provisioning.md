# Decision: DevBox Provisioning Architecture (Issue #35)

**Date:** 2026-03-11  
**Author:** B'Elanna (Infrastructure Expert)  
**Status:** ✅ Implemented (Phase 1)  
**Scope:** Infrastructure / Automation

## Context

Tamir requested automation for spinning up clones of his current devbox. Requirements:
- Reproducible devbox provisioning
- Easy cloning of existing configurations
- Reusable for future team automation
- Dedicated repo + Squad skill

## Decision

**Two-Phase Architecture:**

### Phase 1: IaC Foundation (COMPLETE)
- **Location:** `devbox-provisioning/` directory in tamresearch1 repo
- **Strategy:** Azure CLI-based provisioning (not ARM) until ARM support is available
- **Components:**
  - PowerShell provisioning script with prerequisite validation
  - Clone script with auto-detection of existing devboxes
  - Bicep template scaffolding for future ARM migration
  - Comprehensive documentation and troubleshooting

### Phase 2: AI-Native Automation (PLANNED)
- Squad skill for natural language provisioning
- MCP Server integration (`@microsoft/devbox-mcp`)
- Advanced templating and orchestration

## Rationale

1. **CLI Over ARM:** Microsoft Dev Box does not support ARM/Bicep provisioning yet (as of March 2026). Azure CLI `devcenter` extension is the official provisioning method.

2. **Auto-Detection Pattern:** Clone script discovers existing devbox configurations automatically via `az devcenter dev dev-box list`, eliminating manual config gathering.

3. **Phase Split:** Phase 1 delivers working manual automation first. Phase 2 adds natural language layer. This ensures robust foundation before adding AI abstraction.

4. **Fallback Guidance:** Comprehensive troubleshooting for Azure CLI extension install failures (pip issues, manual download, REST API fallback).

## Key Architectural Patterns

### 1. Prerequisites Validation
```powershell
Test-AzureCLI → Test-DevCenterExtension → Test-AzureAuth → Provision
```
Fail fast with actionable error messages at each gate.

### 2. Auto-Detection Flow
```
List DevBoxes → Select Source → Get Details → Clone Config → Provision
```
Zero-config cloning when only one devbox exists; interactive selection for multiple.

### 3. Wait-for-Completion Strategy
- Poll every 30 seconds
- Display status: "Attempt X/Y - Status: Provisioning (Elapsed: N min)"
- Configurable timeout (default 30 min)
- Final status: Succeeded/Running/Failed

### 4. Configuration Defaults with Overrides
```powershell
# Script has defaults (lines 47-49)
$DefaultDevCenterName = "YOUR-DEVCENTER-NAME"
$DefaultProjectName = "YOUR-PROJECT-NAME"
$DefaultPoolName = "YOUR-POOL-NAME"

# Parameters override defaults
provision.ps1 -DevBoxName "new-box" -ProjectName "OverrideProject"
```

## Implementation

**Files Created:**
- `devbox-provisioning/README.md` (7KB)
- `devbox-provisioning/bicep/main.bicep` (7.5KB)
- `devbox-provisioning/scripts/provision.ps1` (11.7KB)
- `devbox-provisioning/scripts/clone-devbox.ps1` (10.4KB)

**Pull Request:** #61  
**Branch:** `squad/35-devbox-provisioning`

## Known Limitations

1. **Azure CLI Extension:** `az extension add --name devcenter` failed with pip error on current machine
   - Documented workarounds in README
   - Scripts validate extension presence and provide guidance

2. **ARM Support Gap:** Dev Box does not support ARM/Bicep provisioning
   - Bicep template uses deployment script workaround
   - Ready for migration when ARM support lands

3. **Authentication Scope:** Azure CLI requires authenticated user principal (not service principals)
   - Documented in prerequisites section

## Success Criteria

Phase 1:
- ✅ Scripts created with comprehensive error handling
- ✅ Documentation covers all workflows
- ✅ Auto-detection working (via CLI)
- ✅ Fallback guidance for extension install failures
- ⏳ End-to-end testing blocked by extension install issue

Phase 2:
- ⏳ Squad skill accepts natural language requests
- ⏳ MCP Server integration working
- ⏳ Multi-devbox orchestration

## Open Questions

1. Should Phase 1 repo become a separate GitHub repository, or stay in tamresearch1?
2. What custom images/network configs does Tamir need for Phase 2?
3. Should we add CI/CD pipeline for validation in Phase 1?

## Next Steps

1. Tamir installs devcenter extension: `az extension add --name devcenter`
2. Tamir runs discovery: `az devcenter dev dev-box list`
3. Tamir updates defaults in provision.ps1 (lines 47-49)
4. Tamir tests clone: `.\scripts\clone-devbox.ps1 -NewDevBoxName "test-clone"`
5. If successful, close Issue #35 Phase 1; plan Phase 2 skill work

## Related

- **Issue #35:** Creating another devbox
- **Pull Request #61:** Phase 1 implementation
- **Microsoft Dev Box MCP Server:** `@microsoft/devbox-mcp` npm package
- **Azure CLI Extension:** `az extension add --name devcenter`
