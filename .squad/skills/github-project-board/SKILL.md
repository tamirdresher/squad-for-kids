# Skill: GitHub Project Board Management

**Confidence:** medium
**Domain:** issue-lifecycle, project-management
**Last validated:** 2026-03-08

## Context

The team uses a GitHub Projects V2 board ("Squad Work Board", project #1, owner: tamirdresher_microsoft) to track issue status visually. Issues MUST be moved on the board when their status changes — labels alone are not sufficient.

## Board Columns

| Column | When to use |
|--------|------------|
| **Todo** | Issue is triaged and assigned but work hasn't started |
| **In Progress** | Agent is actively working on the issue (branch created, PR in draft) |
| **Done** | Issue is closed, PR merged |
| **Blocked** | Issue cannot proceed — dependency, CI issue, or technical blocker |
| **Pending User** | Waiting for Tamir's input — decision needed, clarification required, or review requested |

## How to Move Items

### 1. Add an issue to the board (if not already there)

```bash
gh project item-add 1 --owner tamirdresher_microsoft --url https://github.com/tamirdresher_microsoft/tamresearch1/issues/{NUMBER}
```

### 2. Get the item ID for an issue already on the board

```bash
gh project item-list 1 --owner tamirdresher_microsoft --format json | python -c "
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
- `0de780a1` → Todo
- `238ff87a` → In Progress
- `1807f788` → Review
- `4830e3e3` → Done
- `c6316ca6` → Blocked
- `c48a6815` → Pending User
- `52659e74` → Waiting for user review

### Shortcut: Combined add + set status

```bash
# Add to board and set status in one flow
ITEM_ID=$(gh project item-add 1 --owner tamirdresher_microsoft --url https://github.com/tamirdresher_microsoft/tamresearch1/issues/{NUMBER} --format json | python -c "import json,sys; print(json.load(sys.stdin)['id'])")
gh project item-edit --project-id PVT_kwHOC0L5c84BRG-P --id $ITEM_ID --field-id PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc --single-select-option-id {OPTION_ID}
```

## When to Update the Board

Agents MUST update the board in these situations:

1. **Triage:** When Picard triages an issue → set to `Todo` (0de780a1)
2. **Starting work:** When creating a branch/PR → set to `In Progress` (238ff87a)
3. **Blocked:** When encountering a blocker → set to `Blocked` (c6316ca6) + comment explaining why
4. **Needs user input:** When adding `status:pending-user` label → ALSO set to `Pending User` (c48a6815)
5. **Closing:** When closing an issue → set to `Done` (4830e3e3)
6. **Review:** When PR is open and ready for review → set to `Review` (1807f788)

## Important

- Always update the board AND the label together — they serve different audiences (board = visual, labels = automation)
- If `gh project` commands fail, log the failure but don't block the main work
- The project ID is `PVT_kwHOC0L5c84BRG-P` and the Status field ID is `PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc`
- **When closing ANY issue (including "not planned" / cancel), ALWAYS move it to Done (4830e3e3)**. The "Cancel" and "Postpone" columns are for OPEN issues only. Closed issues must be in Done regardless of how they were closed.
- The `squad-board-sync` GitHub Action auto-moves items to Done on issue close as a safety net, but agents should still update the board proactively.
