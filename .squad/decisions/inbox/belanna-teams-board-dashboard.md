# Decision: Teams Board Dashboard Integration

**Date:** 2025-01-27  
**Author:** B'Elanna  
**Status:** Implemented  
**Issue:** #535

## Context

Tamir requested a way to view GitHub Project Board status directly in Microsoft Teams without manual checking. Requirements:
- Visual board representation in Teams
- No manual involvement from Tamir
- Automated solution ready to use upon completion

## Decision

Implemented a PowerShell script (`scripts/teams-board-dashboard.ps1`) that:
1. Fetches GitHub Project Board state using `gh` CLI
2. Transforms data into Teams Adaptive Card format
3. Posts to existing Teams webhook
4. Groups issues by status column with emoji indicators
5. Provides clickable links to GitHub issues

## Architecture

```
GitHub Project Board
   ↓ (gh CLI)
PowerShell Script
   ↓ (Adaptive Card JSON)
Teams Webhook
   ↓
Teams Channel (Visual Dashboard)
```

**Key Components:**
- **Script:** `scripts/teams-board-dashboard.ps1`
- **Webhook URL:** Stored at `$env:USERPROFILE\.squad\teams-webhook.url`
- **Data source:** GitHub Projects API via gh CLI
- **Output format:** Adaptive Card v1.4

**Design Choices:**
- **Point-in-time snapshot:** Not real-time sync; run periodically
- **Standalone script:** No dependencies beyond gh CLI and PowerShell
- **Rich formatting:** Emoji indicators, clickable links, timestamp
- **Automation-ready:** Can be triggered manually or via Ralph monitoring

## Implementation Details

**Column Status Mapping:**
- 📋 Todo
- 🔨 In Progress
- 👀 Review
- ✅ Done
- 🚫 Blocked
- ⏳ Pending User

**Card Structure:**
- Header: Board title + timestamp
- Refresh note: Point-in-time snapshot
- Columns: Grouped issues by status
- Footer: "View Full Board" action button

## Testing

Successfully tested with live data:
- Retrieved 1 board item
- Generated valid Adaptive Card JSON
- Posted to Teams webhook without errors
- Card rendered correctly in Teams

## Future Enhancements

- Integration with Ralph's monitoring loop for periodic auto-posting
- Filtering options (e.g., only open issues)
- Issue age/staleness indicators
- Assignment summaries

## References

- Issue: #535
- Branch: squad/535-teams-board-dashboard
- Commit: 92349290
- Script: scripts/teams-board-dashboard.ps1
