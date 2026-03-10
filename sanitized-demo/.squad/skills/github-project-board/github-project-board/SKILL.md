# Skill: GitHub Project Board Management

**Confidence:** medium
**Domain:** issue-lifecycle, project-management
**Last validated:** 2026-03-08

## Context

The team uses a GitHub Projects V2 board ("Squad Work Board", project #1, owner: your-org) to track issue status visually. Issues MUST be moved on the board when their status changes — labels alone are not sufficient.

## Board Columns

| Column | When to use |
|--------|------------|
| **Todo** | Issue is triaged and assigned but work hasn't started |
| **In Progress** | Agent is actively working on the issue (branch created, PR in draft) |
| **Done** | Issue is closed, PR merged |
| **Blocked** | Issue cannot proceed — dependency, CI issue, or technical blocker |
| **Pending User** | Waiting for YourName's input — decision needed, clarification required, or review requested |

## How to Move Items

### 1. Add an issue to the board (if not already there)

```bash
gh project item-add 1 --owner your-org --url https://github.com/your-org/your-repo/issues/{NUMBER}
```

### 2. Get the item ID for an issue already on the board

```bash
gh project item-list 1 --owner your-org --format json | python -c "
import json,sys
items = json.load(sys.stdin)['items']
for item in items:
    if 'content' in item and item['content'].get('number') == {NUMBER}:
        print(item['id'])
        break
"
```

### 3. Move an item to a column

```bash
gh project item-edit --project-id PVT_kwHOC0L5c84BRG-P --id {ITEM_ID} --field-id PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc --single-select-option-id {OPTION_ID}
```

**Column option IDs:**
- `YOUR_OPTION_ID` → Todo
- `YOUR_OPTION_ID` → In Progress
- `YOUR_OPTION_ID` → Review
- `YOUR_OPTION_ID` → Done
- `YOUR_OPTION_ID` → Blocked
- `YOUR_OPTION_ID` → Pending User
- `YOUR_OPTION_ID` → Waiting for user review

### Shortcut: Combined add + set status

```bash
# Add to board and set status in one flow
ITEM_ID=$(gh project item-add 1 --owner your-org --url https://github.com/your-org/your-repo/issues/{NUMBER} --format json | python -c "import json,sys; print(json.load(sys.stdin)['id'])")
gh project item-edit --project-id PVT_kwHOC0L5c84BRG-P --id $ITEM_ID --field-id PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc --single-select-option-id {OPTION_ID}
```

## When to Update the Board

Agents MUST update the board in these situations:

1. **Triage:** When Picard triages an issue → set to `Todo` (YOUR_OPTION_ID)
2. **Starting work:** When creating a branch/PR → set to `In Progress` (YOUR_OPTION_ID)
3. **Blocked:** When encountering a blocker → set to `Blocked` (YOUR_OPTION_ID) + comment explaining why
4. **Needs user input:** When adding `status:pending-user` label → ALSO set to `Pending User` (YOUR_OPTION_ID)
5. **Closing:** When closing an issue → set to `Done` (YOUR_OPTION_ID)
6. **Review:** When PR is open and ready for review → set to `Review` (YOUR_OPTION_ID)

## Important

- Always update the board AND the label together — they serve different audiences (board = visual, labels = automation)
- If `gh project` commands fail, log the failure but don't block the main work
- The project ID is `PVT_kwHOC0L5c84BRG-P` and the Status field ID is `PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc`

