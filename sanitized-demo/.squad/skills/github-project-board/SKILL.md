# Skill: GitHub Project Board Management

**Confidence:** high  
**Domain:** issue-lifecycle, automation  
**Last Updated:** 2026-03-25  
**Used by:** Ralph, Picard, all agents

## Context

Use this skill when you need to update the GitHub Projects V2 board status for issues. This keeps the board synchronized with actual work state.

**When to use:**
- Before starting work on an issue → Move to "In Progress"
- After completing work → Move to "Done"
- When blocked → Move to "Blocked"
- When waiting for user input → Move to "Pending User"

Per Decision #6: "Project Board Status Must Stay Synchronized"

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Access to the project board
- Project ID and Field IDs configured

## Configuration

You need these IDs from your GitHub Project:

### Get Project ID
```bash
# List projects for your org
gh project list --owner <your-org>

# Output shows:
# NUMBER  TITLE           STATE  ID
# 1       My Squad Board  OPEN   PVT_kwHOC0L5c84BRG-P
```

### Get Field IDs
```bash
# List fields in your project
gh project field-list <project-number> --owner <your-org>

# Output shows field IDs like:
# NAME    ID                              TYPE
# Status  PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc SingleSelect
```

### Get Option IDs for Status Field
```bash
# View the status field to get option IDs
gh api graphql -f query='
query {
  node(id: "<PROJECT_ID>") {
    ... on ProjectV2 {
      field(name: "Status") {
        ... on ProjectV2SingleSelectField {
          options {
            id
            name
          }
        }
      }
    }
  }
}'
```

### Example Configuration
```bash
PROJECT_ID="PVT_kwHOC0L5c84BRG-P"
STATUS_FIELD_ID="PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc"

# Status option IDs:
TODO_OPTION_ID="f75ad846"
IN_PROGRESS_OPTION_ID="238ff87a"
DONE_OPTION_ID="4830e3e3"
BLOCKED_OPTION_ID="c6316ca6"
PENDING_USER_OPTION_ID="da2e1f33"
```

**⚠️ IMPORTANT:** Replace these placeholder IDs with your actual project IDs!

## Procedure

### Step 1: Get Item ID for an Issue

Before updating status, you need the project item ID (not the same as issue number):

```bash
# Add issue to project (if not already added) and get item ID
gh project item-add <project-number> --owner <your-org> --url https://github.com/<your-org>/<your-repo>/issues/<issue-number>

# This returns the item ID, e.g., PVTI_lAHOC0L5c84BRG-PzgsAbcd
```

### Step 2: Update Status

```bash
# Move to "In Progress"
gh project item-edit \
  --id <ITEM_ID> \
  --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> \
  --option-id <IN_PROGRESS_OPTION_ID>

# Move to "Done"
gh project item-edit \
  --id <ITEM_ID> \
  --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> \
  --option-id <DONE_OPTION_ID>

# Move to "Blocked"
gh project item-edit \
  --id <ITEM_ID> \
  --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> \
  --option-id <BLOCKED_OPTION_ID>

# Move to "Pending User"
gh project item-edit \
  --id <ITEM_ID> \
  --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> \
  --option-id <PENDING_USER_OPTION_ID>
```

### Step 3: Verify Update

```bash
# List items in the project to verify
gh project item-list <project-number> --owner <your-org> --format json
```

## Examples

### Example 1: Ralph Starting Work on Issue #42

```powershell
# Ralph identifies issue #42 as actionable

# Step 1: Add issue to project and get item ID
$itemId = gh project item-add 1 --owner demo-org --url https://github.com/demo-org/squad-demo/issues/42

# Step 2: Move to "In Progress"
gh project item-edit `
  --id $itemId `
  --project-id "PVT_kwHOC0L5c84BRG-P" `
  --field-id "PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc" `
  --option-id "238ff87a"

# Step 3: Spawn agent to work on issue
gh copilot "@data, handle issue #42" --mode async

# When agent completes, move to "Done"
gh project item-edit `
  --id $itemId `
  --project-id "PVT_kwHOC0L5c84BRG-P" `
  --field-id "PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc" `
  --option-id "4830e3e3"
```

### Example 2: Agent Encountering a Blocker

```bash
# Agent realizes they need user input

# Move issue to "Pending User"
gh project item-edit \
  --id PVTI_lAHOC0L5c84BRG-PzgsAbcd \
  --project-id PVT_kwHOC0L5c84BRG-P \
  --field-id PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc \
  --option-id da2e1f33

# Add comment explaining what's needed
gh issue comment 42 --repo demo-org/squad-demo --body "@ProjectOwner: Need your input on which approach to take. See options above."
```

### Example 3: Archiving Completed Items (Ralph)

```bash
# Find items in "Done" status for 3+ days
# (This requires querying the project via GraphQL or gh CLI)

# For each old done item:
# 1. Close the issue if still open
gh issue close 42 --repo demo-org/squad-demo --comment "Completed 3 days ago. Archiving."

# The issue stays on the board but is marked closed
```

## Workflow Integration

### Ralph's Board Update Workflow

```
Every round:
1. Query open issues
2. For each actionable issue:
   a. Add to project (if not already)
   b. Move to "In Progress"
   c. Spawn agent
3. For each completed issue:
   a. Move to "Done"
4. For blocked issues:
   a. Move to "Blocked"
5. Archive old done items (3+ days)
```

### Agent Workflow

```
When starting work:
1. Read issue description
2. Update board to "In Progress" (use this skill)
3. Do the work
4. Update board to "Done" or "Pending User"
5. Comment on issue with status
```

## Common Issues

### Issue: "Resource not accessible by integration"
**Cause:** GitHub CLI doesn't have project permissions  
**Solution:** Re-authenticate with additional scopes:
```bash
gh auth refresh --scopes project
```

### Issue: "Field or option not found"
**Cause:** Wrong field ID or option ID  
**Solution:** Re-query your project to get correct IDs (see Configuration section)

### Issue: "Item not found"
**Cause:** Issue not added to project yet  
**Solution:** Use `gh project item-add` first

## Confidence Level

**High** - This skill has been used in 50+ issues across multiple agents. Commands are stable and reliable.

## Related Resources

- GitHub Projects V2 docs: https://docs.github.com/en/issues/planning-and-tracking-with-projects
- GitHub CLI project commands: `gh project --help`
- Squad Decision #6: Project Board Status Must Stay Synchronized

## Maintenance Notes

- If project field structure changes, update field/option IDs
- If new status columns added, update this skill with new option IDs
- Test commands in dry-run mode when making changes
