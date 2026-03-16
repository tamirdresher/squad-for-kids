---
name: gh-auth-isolation
description: Prevent multiple Squad/Ralph instances from fighting over global gh auth state when running across repos with different GitHub accounts (personal vs EMU/enterprise).
---

# GitHub Auth Isolation for Multi-Repo Squad

## Problem
When multiple Ralphs run across repos (e.g., personal repos on `tamirdresher` + work repos on `tamirdresher_microsoft`), they fight over the global `gh auth switch` state. Each Ralph switches to its required account, causing the others to fail on the next round.

Symptoms:
- Consecutive Ralph failures (exit code 1) across repos
- `gh api user` returns wrong account intermittently
- Failures are timing-dependent — works when only one Ralph runs

## Root Cause
`gh auth switch --user X` mutates GLOBAL state in the gh CLI keyring. All processes on the machine share this state. When process A switches to account X and process B switches to account Y, process A's next API call uses account Y.

## Solution: Per-Process GH_TOKEN

Instead of switching global auth, extract the token for the required account and set it as a process-local environment variable:

```powershell
# Detect required account from git remote
$remoteUrl = git remote get-url origin
$requiredAccount = if ($remoteUrl -match "orgname") { "user_orgname" } else { "user_personal" }

# Get token without switching global state
$token = gh auth token --user $requiredAccount
$env:GH_TOKEN = $token.Trim()

# All subsequent gh commands in THIS process use the correct account
# Other processes are unaffected
```

## Integration with ralph-watch.ps1

Add this at the start of each Ralph round (before any gh commands):

```powershell
try {
    $remoteUrl = & git remote get-url origin 2>&1 | Out-String
    $requiredAccount = if ($remoteUrl -match "your_org") { "your_emu_account" } else { "your_personal_account" }
    $token = & gh auth token --user $requiredAccount 2>&1 | Out-String
    $token = $token.Trim()
    if ($token -and $token.StartsWith("gho_")) {
        $env:GH_TOKEN = $token
    } else {
        # Fallback to global switch (single-Ralph scenarios)
        & gh auth switch --user $requiredAccount 2>&1 | Out-Null
    }
} catch {
    Write-Warning "gh auth isolation failed: $_"
}
```

## When to Use
- Multiple Ralph instances across repos with different GitHub accounts
- CI/CD environments where multiple gh-authenticated processes run concurrently
- DevBox/Cloud PC setups where personal and work repos coexist

## Key Insight
This is a classic distributed systems problem — shared mutable state (global auth) accessed by concurrent processes. The fix is the same as any concurrent programming fix: eliminate shared mutable state by making it process-local.
