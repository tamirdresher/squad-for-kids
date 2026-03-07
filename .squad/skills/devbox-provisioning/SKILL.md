---
name: "devbox-provisioning"
description: "Natural language DevBox provisioning using Phase 1 templates"
domain: "infrastructure-automation"
confidence: "high"
source: "phase-2-feature"
created: "2026-03-07"
issue: "#63"
phase: "2"
---

## Context
Phase 2 of the DevBox provisioning automation project. This skill enables natural language interpretation of DevBox provisioning requests and maps them to the Phase 1 Bicep templates and PowerShell automation scripts. Built on top of the infrastructure in `devbox-provisioning/`.

## Natural Language Patterns

### Single DevBox Creation
**Trigger phrases:**
- "Create a new devbox called X"
- "Provision a devbox named X"
- "Set up a development environment X"
- "I need a devbox for X"

**Interpretation:**
- Extract the DevBox name from the request
- Use auto-detection to find source configuration (Dev Center, project, pool)
- Map to: `.\devbox-provisioning\scripts\provision.ps1 -DevBoxName "X"`

### Cloning Existing DevBox
**Trigger phrases:**
- "Clone my devbox"
- "Create a copy of my devbox called X"
- "Make a devbox like mine named X"
- "Duplicate my current environment as X"

**Interpretation:**
- Auto-detect current DevBox configuration
- Create new instance with same configuration
- Map to: `.\devbox-provisioning\scripts\clone-devbox.ps1 -NewDevBoxName "X"`

### Bulk Provisioning
**Trigger phrases:**
- "Create 3 devboxes like mine"
- "Provision N devboxes with names X, Y, Z"
- "Set up 5 environments for the team"
- "Clone my devbox N times"

**Interpretation:**
- Parse count (N) and naming pattern
- Generate unique names if not provided (e.g., "devbox-1", "devbox-2", etc.)
- Loop provisioning with clone-devbox.ps1
- Execute sequentially or in parallel based on Azure quota considerations

### Configuration Discovery
**Trigger phrases:**
- "What's my devbox configuration?"
- "Show me my current devbox settings"
- "List my devboxes"
- "What pools are available?"

**Interpretation:**
- Execute discovery commands
- Present configuration in human-readable format
- Map to Azure CLI commands:
  - `az devcenter dev dev-box list --output table`
  - `az devcenter dev dev-box show --name "X" --output json`
  - `az devcenter dev project list --output table`
  - `az devcenter dev pool list --project-name "X" --output table`

## Configuration Capture Patterns

### Auto-Detection Workflow
1. **List existing DevBoxes:**
   ```powershell
   az devcenter dev dev-box list --output json
   ```
2. **Select source:** If multiple DevBoxes exist, prompt user or use first available
3. **Extract configuration:**
   ```powershell
   az devcenter dev dev-box show --name "SOURCE_NAME" --output json
   ```
4. **Parse required fields:**
   - `devCenterName`
   - `projectName`
   - `poolName`
   - Optional: `hardwareProfile.skuName`, `imageReference.name`

### Validation Before Provisioning
Before creating any DevBox, validate:
1. **Authentication:** User is logged into Azure (`az account show`)
2. **Extension:** DevCenter extension is installed (`az extension list | grep devcenter`)
3. **Permissions:** User has access to target project (`az devcenter dev project list`)
4. **Naming:** DevBox name is valid (3-63 chars, alphanumeric + hyphens)
5. **Uniqueness:** Name doesn't conflict with existing DevBox
6. **Quota:** Sufficient quota available (check Azure portal or fail gracefully)

### Error Handling Patterns

#### Common Errors and Resolutions

**Authentication Failure:**
```
Error: "Please run 'az login' to authenticate"
Resolution: Prompt user to run az login, then retry
```

**Extension Missing:**
```
Error: "Azure CLI devcenter extension not found"
Resolution: Auto-install with: az extension add --name devcenter --yes
```

**Invalid Name:**
```
Error: "DevBox name must be 3-63 characters, alphanumeric and hyphens only"
Resolution: Suggest valid name pattern, prompt for correction
```

**Name Conflict:**
```
Error: "DevBox 'X' already exists"
Resolution: Suggest alternative name (append timestamp or counter)
```

**Quota Exceeded:**
```
Error: "Dev Box quota exceeded for pool 'X'"
Resolution: List existing DevBoxes, suggest cleanup or request quota increase
```

**Pool Not Available:**
```
Error: "Pool 'X' not found or not available"
Resolution: List available pools, prompt user to select valid pool
```

**Provisioning Timeout:**
```
Error: "Dev Box provisioning timed out after N minutes"
Resolution: Provide command to check status manually:
  az devcenter dev dev-box show --name "X"
```

## Implementation Workflow

### Step 1: Parse Request
- Extract action (create, clone, list, etc.)
- Extract parameters (name, count, source)
- Validate syntax of natural language request

### Step 2: Validate Preconditions
- Check Azure CLI availability
- Check authentication status
- Check extension installation
- Validate target configuration (Dev Center, project, pool)

### Step 3: Execute Provisioning
- For single DevBox: Call `provision.ps1` or `clone-devbox.ps1`
- For bulk: Loop with unique name generation
- For discovery: Execute Azure CLI commands directly

### Step 4: Monitor Progress
- For `-WaitForCompletion $true`: Poll status every 30 seconds
- Display provisioning state updates
- Handle timeouts gracefully

### Step 5: Report Results
- Success: Display connection instructions
  ```
  az devcenter dev dev-box show --name "X" --query "remoteConnectionUri" --output tsv
  ```
- Failure: Display error message and suggested remediation
- Partial success (bulk): Report which succeeded/failed

## Advanced Scenarios

### Custom Configuration Override
**Trigger:** "Create a devbox named X in project Y using pool Z"
**Interpretation:**
- Parse custom Dev Center, project, pool from request
- Pass as parameters to provision.ps1:
  ```powershell
  .\provision.ps1 -DevBoxName "X" -ProjectName "Y" -PoolName "Z"
  ```

### Conditional Waiting
**Trigger:** "Create devbox X and don't wait"
**Interpretation:**
- Set `-WaitForCompletion $false`
- Return immediately after initiating provisioning
- Provide status check command

### Team Provisioning with Naming Convention
**Trigger:** "Create 5 devboxes for sprint-42"
**Interpretation:**
- Generate names: "sprint-42-dev1", "sprint-42-dev2", etc.
- Execute clone-devbox.ps1 in loop
- Report progress after each completion

## Script References

### Phase 1 Scripts (Backend)
- **`devbox-provisioning/scripts/provision.ps1`**
  - Creates new DevBox with specified config
  - Parameters: DevBoxName, DevCenterName, ProjectName, PoolName, WaitForCompletion, TimeoutMinutes
  
- **`devbox-provisioning/scripts/clone-devbox.ps1`**
  - Auto-detects config from existing DevBox
  - Parameters: NewDevBoxName, SourceDevBoxName, WaitForCompletion, TimeoutMinutes

### Phase 1 Templates (Future)
- **`devbox-provisioning/bicep/main.bicep`**
  - Scaffolded for future ARM template support
  - Currently uses deployment script to invoke Azure CLI

## Examples

### Example 1: Simple Clone Request
```
User: "Create a new devbox called feature-auth"

Interpretation:
1. Parse: action=clone, name="feature-auth"
2. Validate: Check Azure CLI, auth, extension
3. Execute: .\clone-devbox.ps1 -NewDevBoxName "feature-auth"
4. Monitor: Wait for provisioning (default 30 min timeout)
5. Report: "DevBox 'feature-auth' is ready! Connect with: [command]"
```

### Example 2: Bulk Provisioning
```
User: "Create 3 devboxes like mine"

Interpretation:
1. Parse: action=bulk_clone, count=3, naming=auto
2. Generate names: "devbox-001", "devbox-002", "devbox-003"
3. Validate: Check Azure CLI, auth, extension, quota
4. Execute loop:
   - .\clone-devbox.ps1 -NewDevBoxName "devbox-001"
   - .\clone-devbox.ps1 -NewDevBoxName "devbox-002"
   - .\clone-devbox.ps1 -NewDevBoxName "devbox-003"
5. Monitor: Track each provisioning operation
6. Report: "Successfully created 3 DevBoxes: devbox-001, devbox-002, devbox-003"
```

### Example 3: Configuration Discovery
```
User: "What's my current devbox setup?"

Interpretation:
1. Parse: action=discover
2. Execute: az devcenter dev dev-box list --output json
3. Execute: az devcenter dev dev-box show --name "CURRENT" --output json
4. Format output:
   - Name: my-devbox
   - Dev Center: contoso-devcenter
   - Project: platform-engineering
   - Pool: general-purpose-pool
   - Hardware: Standard_D4s_v3
   - Image: vs2022-win11-ent
   - Status: Running
5. Report: Display human-readable configuration
```

### Example 4: Custom Configuration
```
User: "Create a devbox named test-env in project research-lab using pool high-memory"

Interpretation:
1. Parse: action=create, name="test-env", project="research-lab", pool="high-memory"
2. Validate: Check project and pool exist
3. Detect Dev Center: Auto-detect from available projects
4. Execute: .\provision.ps1 -DevBoxName "test-env" -ProjectName "research-lab" -PoolName "high-memory"
5. Monitor: Wait for completion
6. Report: Success with connection instructions
```

## Anti-Patterns

### Don't Guess Configuration
- **Wrong:** Assume default Dev Center name "devcenter" if not found
- **Right:** Always discover actual Dev Center name via Azure CLI or prompt user

### Don't Silently Fail
- **Wrong:** Skip failed DevBox in bulk operation without reporting
- **Right:** Report each failure with specific error message and continue or halt based on severity

### Don't Overwrite Existing
- **Wrong:** Delete existing DevBox with same name and recreate
- **Right:** Error if name conflicts, suggest alternative name

### Don't Hardcode Timeouts
- **Wrong:** Always wait 30 minutes regardless of operation
- **Right:** Allow user to specify timeout or skip waiting entirely

### Don't Bypass Validation
- **Wrong:** Attempt provisioning without checking auth or extension
- **Right:** Validate all preconditions before executing scripts

## Integration with Squad

This skill is designed to be invoked by the Squad coordinator when users request DevBox provisioning in natural language. The coordinator should:

1. Identify provisioning intent from user message
2. Invoke this skill with the raw user request
3. The skill agent interprets the request and executes Phase 1 scripts
4. Results are reported back to the user in human terms

The skill bridges natural language understanding and the technical DevBox provisioning infrastructure, abstracting Azure CLI complexity from the end user.

## Future Enhancements

### Phase 3 Considerations
- **MCP Server Integration:** Connect to `@microsoft/devbox-mcp` when available
- **Advanced Templating:** Support custom images, network configs, security policies
- **Multi-DevBox Orchestration:** Coordinate environments for entire teams
- **Cost Optimization:** Auto-hibernation schedules, shutdown policies
- **CI/CD Integration:** Ephemeral DevBoxes triggered by PR creation

---

**Maintained by:** B'Elanna (Infrastructure Expert)  
**Issue:** #63  
**Phase:** 2  
**Status:** Active
