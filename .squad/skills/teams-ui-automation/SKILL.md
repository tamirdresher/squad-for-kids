---
name: teams-ui-automation
description: Self-healing Windows UI Automation for Microsoft Teams desktop app. Handles operations not available via Teams MCP/Graph API (app installation, tab management, connector setup) with dynamic element discovery and automatic recovery from UI changes.
triggers: ["teams ui", "install teams app", "add teams tab", "teams connector", "teams desktop", "teams automation", "ui automation teams"]
confidence: low
---

# Teams UI Automation Skill

## Overview

A self-healing, self-adjusting skill that uses Windows UI Automation (UIA) APIs via PowerShell to control the Microsoft Teams desktop application. Designed for operations that cannot be performed through the Teams MCP server or Microsoft Graph API.

**Key Innovation: Self-Healing Architecture**  
Unlike traditional UI automation that breaks when interfaces change, this skill dynamically discovers UI elements using multiple strategies and automatically adapts to Teams updates, localization changes, and UI layout modifications.

## When to Use

✅ **USE THIS SKILL FOR:**
- Installing Teams apps to specific teams/channels
- Adding tabs to channels (Wiki, Planner, custom apps, website tabs)
- Configuring connectors that lack Graph API support
- UI-based operations not exposed via API
- Navigating Teams UI programmatically
- Testing Teams UI workflows

❌ **DO NOT USE FOR:**
- Sending messages (use Teams MCP `PostMessage` instead)
- Reading messages (use Teams MCP `ListChatMessages` instead)
- Creating teams/channels (use Teams MCP `CreateChannel` instead)
- Managing members (use Teams MCP instead)
- Any operation where Graph API or Teams MCP provides a reliable alternative

## Prerequisites

- **Windows OS** (UI Automation is Windows-specific)
- **Microsoft Teams Desktop App** installed and running (not Teams web or PWA)
- **PowerShell 5.1 or later** with UI Automation assemblies
- **Teams must be signed in** before automation begins
- **User must have appropriate permissions** for the operations (e.g., team owner to install apps)

## Architecture: Self-Healing System

### Multi-Strategy Element Discovery

The skill uses a **fallback chain** when locating UI elements:

1. **AutomationID Match** (most stable) — Elements with unique IDs
2. **Name Pattern Match** (fuzzy/regex) — Handles localization and text variations  
3. **ControlType + Hierarchy** (structural) — Position in UI tree (e.g., "3rd button in sidebar")
4. **Spatial Heuristics** (last resort) — Relative positioning (e.g., "text box near bottom")

### Cached Mappings with Auto-Invalidation

```
.squad/skills/teams-ui-automation/element-cache.json
├── teamsVersion: "1.7.00.xxxxx" (auto-detects Teams version)
├── calibratedAt: "2025-01-15T14:30:00Z"
├── failureCount: 2 (incremented on each failure)
├── maxFailuresBeforeRecalibrate: 3
└── elements:
    ├── "AppStore": { "automationId": "...", "path": [...], "timestamp": "..." }
    ├── "ChannelList": { ... }
    └── "MessageCompose": { ... }
```

**Auto-Invalidation:** When an action fails, the cache entry is removed and element is re-discovered using the strategy chain.

### Self-Healing Flow

```
┌─────────────────────────────────────────────────────────────┐
│ User: Install-TeamsApp "Planner"                            │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
         ┌─────────────────────┐
         │ Find-TeamsElement   │
         │   "AppStore"        │
         └──────┬──────────────┘
                │
                ▼
        ┌───────────────┐
        │ Check Cache   │
        └───┬───────────┘
            │
    ┌───────┴────────┐
    │ CACHE HIT?     │
    └───┬────────┬───┘
        │        │
       YES      NO
        │        │
        ▼        ▼
    Verify   Strategy Chain:
    exists?  1. AutomationID
        │    2. Name regex
    ┌───┴──┐ 3. Structure
   YES    NO 4. Spatial
    │      │    │
    ▼      │    ▼
   Use ✅  │   Found?
          │    │
          │  ┌─┴──┐
          │ YES   NO
          │  │    │
          │  ▼    ▼
          │ Cache failureCount++
          │  │    │
          │  ▼    ▼
          │ Use  Over threshold?
          │      │
          │   ┌──┴───┐
          │  YES     NO
          │   │      │
          │   ▼      ▼
          │ Calibrate Report error
          │   │      with diagnostics
          │   ▼
          │ Retry once
          │   │
          └───┴──► Action succeeds or fails
```

### Calibration Mode

`Calibrate-TeamsUI` performs a full UI tree scan:
- Walks entire Teams window hierarchy
- Identifies landmarks: app bar, team list, channel list, chat compose, search bar
- Extracts multiple properties per element (AutomationId, Name, ControlType, position)
- Saves versioned mapping with Teams version string
- Resets failure counter

**Triggers:**
- Manual: Call `Calibrate-TeamsUI -Force`
- Automatic: When `failureCount >= maxFailuresBeforeRecalibrate`
- Version change: When detected Teams version differs from cached version

## Available Functions

### Core Infrastructure

**`Initialize-TeamsUIA`**  
Load UI Automation assemblies, find Teams window, load element cache.

```powershell
Initialize-TeamsUIA -Verbose
```

**`Find-TeamsElement`**  
Multi-strategy element finder with self-healing. Tries cache first, then fallback chain.

```powershell
$element = Find-TeamsElement -ElementKey "AppStore" -RetryCount 2
```

**`Calibrate-TeamsUI`**  
Full UI scan to rebuild element map. Run after Teams updates or on persistent failures.

```powershell
Calibrate-TeamsUI -Force -Verbose
```

**`Invoke-TeamsAction`**  
Wrapper for actions with automatic retry and self-healing on failure.

```powershell
Invoke-TeamsAction -Action { Install-TeamsApp "Planner" } -MaxRetries 2
```

### Element Cache Management

**`Get-ElementCache`**  
Load element cache from JSON.

**`Save-ElementCache`**  
Persist cache to JSON with current Teams version.

**`Invalidate-CacheEntry`**  
Remove specific cached path when element is no longer valid.

```powershell
Invalidate-CacheEntry -ElementKey "AppStore"
```

**`Test-CacheValidity`**  
Check if cached element still exists at expected location.

### Teams Actions

**`Install-TeamsApp`**  
Navigate to app store, search for app, and install to team/channel.

```powershell
Install-TeamsApp -AppName "Planner" -TeamName "Engineering" -Verbose
```

**`Add-TeamsTab`**  
Add a tab to a channel (Wiki, Planner, website, custom app).

```powershell
Add-TeamsTab -TeamName "Engineering" -ChannelName "General" -TabType "Wiki" -TabName "Team Wiki"
```

**`Navigate-ToTeam`**  
Navigate to a specific team in Teams UI.

```powershell
Navigate-ToTeam -TeamName "Engineering"
```

**`Navigate-ToChannel`**  
Navigate to a specific channel within current team.

```powershell
Navigate-ToChannel -ChannelName "General"
```

**`Open-TeamsSettings`**  
Open Teams settings dialog.

```powershell
Open-TeamsSettings
```

**`Open-TeamsAppStore`**  
Open the Teams app marketplace.

```powershell
Open-TeamsAppStore
```

**`Get-TeamsUISnapshot`**  
Dump current UI tree to file for debugging and manual inspection.

```powershell
Get-TeamsUISnapshot -OutputPath "C:\temp\teams-ui-snapshot.json"
```

### Utilities

**`Wait-ForElement`**  
Wait for element to appear with configurable timeout (handles async UI rendering).

```powershell
Wait-ForElement -Element $searchBar -TimeoutSeconds 10
```

**`Click-Element`**  
Click element with retry logic and verification.

```powershell
Click-Element -Element $button -VerifyClickable $true
```

**`Type-InElement`**  
Type text into element with retry and verification.

```powershell
Type-InElement -Element $textBox -Text "Planner" -ClearFirst $true
```

**`Get-TeamsVersion`**  
Get current Teams version for cache versioning.

```powershell
$version = Get-TeamsVersion
```

## Examples

### Example 1: Install Planner App

```powershell
# Load the module
. .squad\skills\teams-ui-automation\Teams-UIA.ps1

# Initialize (finds Teams window, loads cache)
Initialize-TeamsUIA -Verbose

# Install Planner to the Engineering team
Install-TeamsApp -AppName "Planner" -TeamName "Engineering" -Verbose

# The skill will:
# 1. Check if AppStore element is cached
# 2. If cache miss, discover AppStore button using multi-strategy search
# 3. Click AppStore, wait for marketplace to load
# 4. Search for "Planner"
# 5. Click install button
# 6. Select team from dropdown
# 7. Confirm installation
# 8. Cache all discovered elements for future use
```

### Example 2: Add Wiki Tab

```powershell
. .squad\skills\teams-ui-automation\Teams-UIA.ps1
Initialize-TeamsUIA

# Navigate to specific channel and add Wiki tab
Navigate-ToTeam -TeamName "Engineering"
Navigate-ToChannel -ChannelName "Documentation"
Add-TeamsTab -TabType "Wiki" -TabName "Team Knowledge Base"
```

### Example 3: Manual Calibration After Teams Update

```powershell
. .squad\skills\teams-ui-automation\Teams-UIA.ps1
Initialize-TeamsUIA

# Force full recalibration
Calibrate-TeamsUI -Force -Verbose

# Check what was discovered
Get-ElementCache | ConvertTo-Json -Depth 5
```

### Example 4: Debug UI Changes

```powershell
. .squad\skills\teams-ui-automation\Teams-UIA.ps1
Initialize-TeamsUIA

# Dump current UI tree for inspection
Get-TeamsUISnapshot -OutputPath "C:\temp\teams-ui-debug.json"

# Review the JSON to find new element IDs after Teams UI change
```

## Troubleshooting

### "Element not found" errors
1. Run `Calibrate-TeamsUI -Force -Verbose` to rebuild element map
2. Check Teams is fully loaded and signed in
3. Run `Get-TeamsUISnapshot` and inspect the UI tree manually
4. Ensure you have permissions for the operation (e.g., team owner for app install)

### Cache invalidation loop
- If failureCount keeps increasing, Teams UI has changed significantly
- Manual intervention: Inspect UI snapshot, update element discovery logic if needed
- Temporary fix: Delete `element-cache.json` to force clean recalibration

### Teams version mismatch
- Cache auto-invalidates on version change
- First operation after update will be slower (full discovery)
- Subsequent operations use fresh cache

### Localization issues
- Name pattern matching uses regex to handle text variations
- If your Teams is in a different language, first run with `-Verbose` to see discovered names
- Update regex patterns in `Find-TeamsElement` if needed

## Technical Details

**UI Automation Namespace:** `System.Windows.Automation`  
**Primary Classes:**
- `AutomationElement` — Represents UI elements
- `TreeWalker` — Traverses UI tree
- `InvokePattern`, `ValuePattern`, `SelectionItemPattern` — Interaction patterns

**Cache Structure:**
- File: `.squad/skills/teams-ui-automation/element-cache.json`
- Format: JSON with version metadata and element mappings
- Auto-versioned: Includes Teams version string, auto-invalidates on mismatch

**Failure Recovery:**
1. Attempt 1: Use cached path
2. Attempt 2: Strategy chain discovery
3. Attempt 3: Full calibration + retry
4. Attempt 4: Report failure with diagnostics

**Performance:**
- Cached operations: ~100-200ms
- Discovery operations: ~1-3 seconds
- Full calibration: ~5-10 seconds
- Wait times configurable (default 500ms between actions)

## Limitations

- **Windows-only** — UI Automation is a Windows technology
- **Desktop app required** — Does not work with Teams web or PWA
- **UI must be visible** — Teams window must not be minimized
- **English UI assumed** — Name patterns may need adjustment for other languages
- **Timing-dependent** — Async UI rendering requires waits; may need tuning
- **Not headless** — Requires active desktop session (not suitable for server automation)

## Future Enhancements

- **Visual AI** — Use image recognition as fallback strategy
- **Machine Learning** — Learn from past failures to improve discovery heuristics
- **Multi-language support** — Detect Teams language and adjust patterns
- **Headless mode** — Explore virtual desktop or accessibility tree APIs
- **Performance optimization** — Parallel element discovery
- **Telemetry** — Track success rates per element type

## Confidence Level

**Low (First Observation)**  
This is the initial implementation. Confidence will increase as the skill is tested across:
- Different Teams versions
- Different Windows versions
- Different locales/languages
- Various UI states (light/dark theme, accessibility settings)

Expect refinement needed after initial deployment. Report issues with UI snapshots for analysis.

---

**Version:** 1.0  
**Created:** 2025  
**Last Updated:** 2025  
**Maintainer:** Data (Code Expert)
