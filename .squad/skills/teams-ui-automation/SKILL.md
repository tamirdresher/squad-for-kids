---
name: teams-ui-automation
description: Hybrid Teams automation using Playwright MCP (primary), keyboard shortcuts (secondary), and UIA window management (tertiary). Handles Teams operations not available via Graph API - app installation, tab management, connector setup, UI navigation.
triggers: ["teams ui", "install teams app", "add teams tab", "teams connector", "teams desktop", "teams automation", "ui automation teams", "teams playwright"]
confidence: medium
---

# Teams UI Automation Skill (Hybrid Approach)

## Overview

A **hybrid three-layer automation skill** designed to overcome the limitation that new Microsoft Teams (ms-teams.exe) runs inside an Edge WebView, making traditional UI Automation unable to access the actual Teams UI elements.

### Architecture: Three Layers

**Layer 1 (Primary): Playwright MCP on teams.microsoft.com**  
- Agents use existing Playwright MCP tools to automate teams.microsoft.com
- Full DOM access with self-healing selectors (data-tid, aria-label, CSS, text)
- Web version has identical features to desktop
- Most reliable approach for complex operations

**Layer 2 (Secondary): Keyboard Shortcuts via PowerShell**  
- Quick navigation using documented Teams shortcuts
- SendInput API for reliable keyboard input
- PowerShell functions in Teams-UIA.ps1
- Good for simple navigation when Playwright overhead is unnecessary

**Layer 3 (Tertiary): UIA for Window Management**  
- Process detection and window handle retrieval
- Window state (minimized, maximized, focused)
- Version detection for cache validation
- NOT used for in-app element discovery (proven not to work with WebView)

## When to Use

✅ **USE THIS SKILL FOR:**
- Installing Teams apps to specific teams/channels
- Adding tabs to channels (Wiki, Planner, custom apps, website tabs)
- Configuring connectors that lack Graph API support
- UI-based operations not exposed via API
- Navigating Teams UI programmatically
- Testing Teams UI workflows

❌ **DO NOT USE FOR:**
- Sending messages (use Teams MCP `PostMessage`)
- Reading messages (use Teams MCP `ListChatMessages`)
- Creating teams/channels (use Teams MCP `CreateChannel`)
- Managing members (use Teams MCP)
- Any operation where Graph API or Teams MCP provides a reliable alternative

## Prerequisites

- **Windows OS** (for Layer 2 & 3 - keyboard shortcuts and window management)
- **Microsoft Teams Desktop App** OR **Web Browser** (for Layer 1 - Playwright)
- **PowerShell 5.1 or later** (for Layer 2 & 3)
- **Teams must be signed in** before automation begins
- **User must have appropriate permissions** for operations (e.g., team owner to install apps)
- **Playwright MCP tools** available in agent's toolset

---

## Layer 1: Playwright MCP Automation (Primary)

### How Agents Use This Layer

Agents have access to Playwright MCP tools and should call them directly to automate teams.microsoft.com. Below are proven recipes for common operations.

### Known Selectors & Fallback Patterns

Teams uses multiple selector strategies. Always try in this order:

1. **`data-tid` attributes** (most stable - test IDs)
2. **`aria-label` attributes** (accessibility - stable)
3. **CSS structural selectors** (position-based)
4. **Text content matching** (least stable - localization issues)

### Recipe: Navigate to teams.microsoft.com and Login

```
1. playwright-browser_navigate
   url: https://teams.microsoft.com

2. Wait for login redirect or Teams UI to load
   playwright-browser_wait_for
   text: "Teams"  # or wait for known element
   
3. If login required, handle Microsoft auth flow
   (user may need to complete MFA manually)
   
4. Wait for main Teams UI
   playwright-browser_snapshot  # verify loaded state
```

### Recipe: Install App to a Team

```
1. Navigate to Apps
   Primary: playwright-browser_click
     ref: [data-tid="app-bar-apps"]
     element: "Apps button in sidebar"
   Fallback 1: [aria-label="Apps"]
   Fallback 2: button:has-text("Apps")
   
2. Wait for Apps marketplace to load
   playwright-browser_wait_for
   text: "Built for your org"  # or "Apps" heading
   
3. Search for the app
   playwright-browser_type
     ref: [data-tid="search-input"] or input[placeholder*="Search"]
     text: "Planner"
     element: "App search box"
     
4. Click the app card from results
   playwright-browser_click
     ref: [data-tid*="app-card"] or [aria-label*="Planner"]
     element: "Planner app card"
     
5. Click "Add to a team" button
   playwright-browser_click
     ref: button:has-text("Add to a team")
     element: "Add to a team button"
     
6. Select team from dropdown
   playwright-browser_click
     ref: [data-tid="team-picker"] or [role="combobox"]
     element: "Team selection dropdown"
   Then type team name or click from list
   
7. Click confirm/install button
   playwright-browser_click
     ref: button:has-text("Set up") or button:has-text("Install")
     element: "Install confirmation button"
     
8. Wait for success confirmation
   playwright-browser_wait_for
   text: "added"  # or success message
```

**Fallback Selectors for Each Step:**

**Apps Button:**
- `[data-tid="app-bar-apps"]` 
- `[aria-label="Apps"]`
- `button:has-text("Apps")`
- `.app-bar button:nth-of-type(6)` (position-based)

**Search Box:**
- `[data-tid="search-input"]`
- `input[placeholder*="Search"]`
- `.search-box input`

**App Card:**
- `[data-tid*="app-card-{appname}"]`
- `[aria-label*="{AppName}"]`
- `button:has-text("{AppName}")`

**Add Button:**
- `button:has-text("Add to a team")`
- `button:has-text("Add")`
- `[data-tid="add-button"]`

### Recipe: Add Tab to a Channel

```
1. Navigate to the team (use Teams MCP or Playwright navigation)
   playwright-browser_click
     ref: [data-tid="team-{teamId}"] or button:has-text("{TeamName}")
     element: "Team in sidebar"
     
2. Navigate to the channel
   playwright-browser_click
     ref: [data-tid="channel-{channelId}"] or [aria-label*="{ChannelName}"]
     element: "Channel in team list"
     
3. Click the "+" button to add a tab
   playwright-browser_click
     ref: [data-tid="add-tab-button"] or button:has-text("+")
     element: "Add tab button in channel tabs bar"
     
4. Search for tab type (e.g., Wiki, Planner, Website)
   playwright-browser_type
     ref: input[placeholder*="Search"]
     text: "Wiki"
     element: "Tab type search"
     
5. Click the tab type from results
   playwright-browser_click
     ref: [data-tid*="app-{tabtype}"] or button:has-text("Wiki")
     element: "Wiki tab type"
     
6. Configure tab settings (varies by tab type)
   For Wiki:
     - Enter tab name
     - Click Save/Add
   For Website:
     - Enter tab name
     - Enter URL
     - Click Save
     
7. Click Add/Save button
   playwright-browser_click
     ref: button:has-text("Add") or button:has-text("Save")
     element: "Add tab confirmation"
     
8. Verify tab appears in tabs bar
   playwright-browser_snapshot  # check for new tab
```

**Fallback Selectors:**

**Add Tab Button:**
- `[data-tid="add-tab-button"]`
- `button[aria-label="Add a tab"]`
- `button:has-text("+")`
- `.tabs-container button:last-of-type`

**Tab Type Card:**
- `[data-tid*="app-wiki"]`
- `[aria-label*="Wiki"]`
- `button:has-text("Wiki")`

**Tab Name Input:**
- `[data-tid="tab-name-input"]`
- `input[placeholder*="Tab name"]`
- `input[type="text"]:visible`

### Recipe: Navigate to Team/Channel

```
1. Click the Teams icon (Ctrl+3 shortcut or Playwright)
   playwright-browser_click
     ref: [data-tid="app-bar-teams"] or [aria-label="Teams"]
     element: "Teams button in sidebar"
     
2. Locate team in list
   playwright-browser_click
     ref: [data-tid="team-{teamId}"] or button:has-text("{TeamName}")
     element: "Team: {TeamName}"
     
3. If team is collapsed, expand it
   playwright-browser_click
     ref: [data-tid="team-expand-{teamId}"]
     element: "Expand team button"
     
4. Click channel
   playwright-browser_click
     ref: [data-tid="channel-{channelId}"] or [aria-label*="{ChannelName}"]
     element: "Channel: {ChannelName}"
     
5. Wait for channel to load
   playwright-browser_wait_for
   text: "{ChannelName}"  # or channel content loads
```

### Recipe: Open Teams Settings

```
1. Click profile/settings menu (top right)
   playwright-browser_click
     ref: [data-tid="profile-menu"] or button[aria-label*="Profile"]
     element: "Profile menu button"
     
2. Click Settings from dropdown
   playwright-browser_click
     ref: button:has-text("Settings") or [data-tid="settings-button"]
     element: "Settings menu item"
     
3. Navigate to desired settings section
   playwright-browser_click
     ref: button:has-text("General") or button:has-text("Privacy")
     element: "Settings section"
     
4. Interact with settings controls as needed
```

**Fallback Selectors:**

**Profile Menu:**
- `[data-tid="profile-menu"]`
- `button[aria-label*="Profile"]`
- `.top-bar button:last-of-type`

**Settings Item:**
- `button:has-text("Settings")`
- `[data-tid="settings-menu-item"]`
- `[aria-label="Settings"]`

### Recipe: Manage Connectors / Workflows

```
1. Navigate to team and channel (see recipe above)

2. Click channel options menu (three dots)
   playwright-browser_click
     ref: [data-tid="channel-options"] or button[aria-label="More options"]
     element: "Channel options menu"
     
3. Click "Connectors" or "Workflows"
   playwright-browser_click
     ref: button:has-text("Connectors") or button:has-text("Workflows")
     element: "Connectors menu item"
     
4. Search for connector (e.g., "GitHub", "Trello")
   playwright-browser_type
     ref: input[placeholder*="Search"]
     text: "GitHub"
     element: "Connector search box"
     
5. Click Configure on desired connector
   playwright-browser_click
     ref: button:has-text("Configure")
     element: "Configure connector button"
     
6. Follow connector-specific setup flow
   (varies by connector - may require external auth)
   
7. Save configuration
   playwright-browser_click
     ref: button:has-text("Save") or button:has-text("Done")
     element: "Save connector button"
```

### Self-Healing Strategy

When a Playwright selector fails:

1. **Try next fallback in chain** (data-tid → aria-label → CSS → text)
2. **Use `playwright-browser_snapshot`** to inspect current page state
3. **Update selector based on snapshot** and retry
4. **Cache successful selector** in element-cache.json for future use
5. **Log failure** in cache.failureLog with context

Example cache entry after successful operation:
```json
{
  "recipes": {
    "openApps": {
      "lastSuccess": "2025-01-15T10:30:00Z",
      "workingSelector": "[data-tid='app-bar-apps']",
      "fallbacksAttempted": 0
    }
  }
}
```

---

## Layer 2: Keyboard Shortcuts (Secondary)

PowerShell functions for quick navigation. Load the script first:

```powershell
. C:\temp\tamresearch1\.squad\skills\teams-ui-automation\Teams-UIA.ps1
Initialize-TeamsAutomation -Verbose
```

### Available Functions

**Navigation:**
- `Open-TeamsApps` - Ctrl+Shift+6 - Opens Apps marketplace
- `Open-TeamsChat` - Ctrl+2 - Opens Chat view
- `Open-TeamsTeams` - Ctrl+3 - Opens Teams view
- `Open-TeamsCalendar` - Ctrl+4 - Opens Calendar
- `Open-TeamsActivity` - Ctrl+1 - Opens Activity feed
- `Open-TeamsSearch` - Ctrl+E - Opens search bar
- `Open-TeamsSettings` - Ctrl+, - Opens Settings dialog
- `Start-TeamsNewChat` - Ctrl+N - Starts new chat
- `Open-TeamsNotifications` - Ctrl+Shift+O - Opens notification panel

**Custom Shortcuts:**
- `Send-TeamsShortcut` - Send any key combination

### Example: Quick Navigation

```powershell
# Navigate to Teams view
Open-TeamsTeams

# Wait for view to load
Start-Sleep -Seconds 1

# Open search
Open-TeamsSearch

# Now use Playwright to interact with search box
```

### When to Use Keyboard Shortcuts

✅ **Good for:**
- Quick view switching (Chat ↔ Teams ↔ Calendar)
- Opening search/settings dialogs
- Complementing Playwright workflows (e.g., switch to Apps view, then use Playwright to interact)

❌ **Not good for:**
- Complex interactions requiring element inspection
- Operations that need verification of results
- When precise element targeting is needed

---

## Layer 3: UIA Window Management (Tertiary)

PowerShell functions for window-level operations only.

### Available Functions

**Window Detection:**
- `Get-TeamsWindow` - Find Teams window handle and process info
- `Test-TeamsRunning` - Check if Teams process is running
- `Focus-TeamsWindow` - Bring Teams to foreground (required for keyboard shortcuts)

**Version Info:**
- `Get-TeamsVersion` - Get Teams version from process

**Cache Management:**
- `Get-ElementCache` - Load element cache
- `Save-ElementCache` - Persist cache to disk

### Example: Check Teams Status

```powershell
# Load module
. C:\temp\tamresearch1\.squad\skills\teams-ui-automation\Teams-UIA.ps1

# Check if Teams is running
if (Test-TeamsRunning) {
    $teams = Get-TeamsWindow
    Write-Host "Teams found: $($teams.Title)"
    Write-Host "Version: $(Get-TeamsVersion)"
} else {
    Write-Host "Teams is not running"
}

# Focus Teams before sending shortcuts
Focus-TeamsWindow
```

### When to Use UIA

✅ **Good for:**
- Verifying Teams is running before automation
- Getting Teams version for cache validation
- Bringing Teams window to foreground
- Process management

❌ **Not good for:**
- Element discovery within Teams UI (WebView blocks UIA)
- Clicking buttons or typing in Teams UI
- Reading content from Teams

---

## Complete Workflow Example: Install App

This example shows how to combine all three layers:

```powershell
# === Layer 3: Verify Teams is Running ===
. C:\temp\tamresearch1\.squad\skills\teams-ui-automation\Teams-UIA.ps1

if (-not (Test-TeamsRunning)) {
    Write-Error "Teams is not running. Please start Teams first."
    exit
}

Initialize-TeamsAutomation -Verbose

# === Layer 2: Navigate to Apps (optional - can use Playwright instead) ===
# Focus window and use keyboard shortcut
Open-TeamsApps
Start-Sleep -Seconds 2  # Wait for Apps view to load

# === Layer 1: Use Playwright MCP to Install App ===
# Now agent calls Playwright MCP tools:

# 1. Take snapshot to verify we're in Apps view
#    playwright-browser_snapshot

# 2. Search for app
#    playwright-browser_type
#      ref: [data-tid="search-input"]
#      text: "Planner"

# 3. Click app card
#    playwright-browser_click
#      ref: [aria-label*="Planner"]

# 4. Click Add to Team
#    playwright-browser_click
#      ref: button:has-text("Add to a team")

# 5. Select team and confirm
#    (continue with Playwright recipe from Layer 1 section)

# === Update Cache with Success ===
# Cache is automatically updated by keyboard shortcut functions
# For Playwright selectors, manually update if needed:

$cache = Get-ElementCache
$cache.recipes["installApp"] = @{
    lastSuccess = Get-Date -Format "o"
    workingSelector = "[data-tid='search-input']"
}
Save-ElementCache
```

---

## Cache Structure

**File:** `.squad/skills/teams-ui-automation/element-cache.json`

```json
{
  "version": "2.0",
  "teamsVersion": "26043.2011.4461.9586",
  "approach": "hybrid",
  "layers": {
    "playwright": {
      "baseUrl": "https://teams.microsoft.com",
      "selectors": {
        "appsButton": "[data-tid='app-bar-apps']",
        "searchBox": "[data-tid='search-input']",
        "addTabButton": "[data-tid='add-tab-button']"
      }
    },
    "keyboard": {
      "shortcuts": {
        "OpenApps": {
          "shortcut": "Ctrl+Shift+6",
          "successCount": 15,
          "failureCount": 0,
          "lastUsed": "2025-01-15T14:30:00Z"
        },
        "OpenChat": {
          "shortcut": "Ctrl+2",
          "successCount": 23,
          "failureCount": 1,
          "lastUsed": "2025-01-15T12:15:00Z"
        }
      }
    },
    "uia": {
      "windowClass": "TeamsWebView",
      "processName": "ms-teams"
    }
  },
  "recipes": {
    "installApp": {
      "lastSuccess": "2025-01-15T10:30:00Z",
      "workingSelectors": [
        "[data-tid='app-bar-apps']",
        "[data-tid='search-input']",
        "[aria-label*='Add to a team']"
      ],
      "failureCount": 0
    }
  },
  "failureLog": [
    {
      "timestamp": "2025-01-14T09:00:00Z",
      "operation": "addTab",
      "selector": "[data-tid='old-add-button']",
      "error": "Element not found",
      "resolved": true,
      "resolution": "Updated to button:has-text('+')"
    }
  ]
}
```

**Auto-Invalidation:**
- Cache is version-checked on initialization
- If Teams version changes, cache is preserved but flagged for validation
- Failed selectors are logged and alternative selectors are tried
- Successful fallbacks update the cache

---

## Troubleshooting

### Playwright Selector Not Found

1. **Take snapshot**: `playwright-browser_snapshot` to see current page state
2. **Try fallback selectors** in order (data-tid → aria-label → CSS → text)
3. **Check if Teams UI changed**: Microsoft updates Teams frequently
4. **Update cache** with new working selector
5. **Report issue** if all fallbacks fail

### Keyboard Shortcut Not Working

1. **Verify Teams is focused**: Call `Focus-TeamsWindow` explicitly
2. **Check shortcut is enabled**: Some shortcuts may be disabled by admin policy
3. **Try Playwright instead**: More reliable for complex operations

### Teams Not Detected

1. **Check process name**: Verify it's "ms-teams" (not old "Teams" process)
2. **Restart Teams**: Close from system tray and reopen
3. **Check window state**: Teams may be minimized to system tray

### UIA Can't See Elements

This is **expected behavior**. New Teams runs in a WebView that UIA cannot access. Use Playwright (Layer 1) instead.

---

## Performance Notes

**Playwright Operations:**
- Navigation: ~500-1000ms
- Element interaction: ~100-300ms
- Search/type: ~200-500ms
- **Total for complex operation (install app): ~5-10 seconds**

**Keyboard Shortcuts:**
- Focus window: ~300-500ms
- Send shortcut: ~100-200ms
- **Total: ~500-700ms per shortcut**

**UIA Window Management:**
- Process detection: ~50-100ms
- Window focus: ~300-500ms
- Version check: ~100ms

**Recommendation:** Use Layer 2 (keyboard) for quick navigation, then Layer 1 (Playwright) for interaction.

---

## Limitations

- **Playwright requires web login**: If using desktop Teams, Playwright automates teams.microsoft.com separately
- **Keyboard shortcuts require focus**: May fail if another app steals focus mid-operation
- **UIA doesn't work for in-app elements**: Only for window management
- **Timing-dependent**: Async UI rendering requires waits between operations
- **Language-dependent**: Text-based selectors may fail in non-English Teams
- **Admin restrictions**: Some operations may be blocked by organization policies

---

## Best Practices

1. **Prefer Playwright for complex operations** - Most reliable and inspectable
2. **Use keyboard shortcuts for quick navigation** - Faster than Playwright for simple view changes
3. **Always verify state with snapshots** - Check page loaded before interacting
4. **Use fallback selector chains** - Don't rely on a single selector
5. **Cache successful selectors** - Improves performance on repeated operations
6. **Log failures with context** - Helps identify patterns and update selectors
7. **Combine layers strategically** - e.g., keyboard to Apps view, then Playwright to install
8. **Handle waits appropriately** - Teams UI animations take 500-1000ms

---

## Confidence Level

**Medium (Proven Hybrid Approach)**

This hybrid approach is based on:
- **Proven limitation**: UIA cannot access Teams WebView (confirmed via testing)
- **Working solution**: Playwright successfully automates teams.microsoft.com
- **Stable shortcuts**: Teams keyboard shortcuts are well-documented and rarely change
- **Production use**: Similar hybrid approaches used in enterprise Teams automation

Confidence will increase as:
- More operations are tested and recipes are refined
- Selector patterns are validated across Teams updates
- Cache effectiveness is measured over time

---

**Version:** 2.0  
**Created:** 2025  
**Last Updated:** 2025  
**Maintainer:** Data (Code Expert)
