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

---

## Recommended Solution: GH_CONFIG_DIR (Isolated Config Directories)

> **This is the correct isolation primitive.** Unlike `GH_TOKEN` (which isolates only the token), `GH_CONFIG_DIR` isolates all config: auth tokens, host settings, preferences, and API cache. No extraction step, no format checking, no fallback logic.

Reference: [jongio/gh-public-gh-emu-setup](https://github.com/jongio/gh-public-gh-emu-setup)

### How It Works

By default, `gh` stores all configuration in a single directory (`~/.config/gh` on Linux/macOS, `%APPDATA%\GitHub CLI` on Windows). The `GH_CONFIG_DIR` environment variable overrides this location. When two processes point to different config directories, they operate with completely independent credentials.

### Setup

Run the setup script once per machine:

```powershell
./scripts/setup-gh-isolated-auth.ps1
```

This creates two isolated directories and authenticates each:

| Directory | Account | Purpose |
|---|---|---|
| `~/.config/gh-emu` | `tamirdresher_microsoft` | EMU/work repos |
| `~/.config/gh-public` | `tamirdresher` | Personal repos |

Options:
- `-Verify` — Check existing auth without modifying anything
- `-SkipLogin` — Create directories but skip interactive login

### Usage in Scripts

Set `GH_CONFIG_DIR` before any `gh` command:

```powershell
# Use EMU account
$env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"
gh pr list --repo tamirdresher_microsoft/tamresearch1

# Use personal account
$env:GH_CONFIG_DIR = "$HOME\.config\gh-public"
gh pr list --repo tamirdresher/some-repo
```

### Auto-Detection by Remote URL

For Ralph and similar automation, detect the correct config dir from the repo's remote:

```powershell
$remoteUrl = git remote get-url origin 2>$null
if ($remoteUrl -match 'tamirdresher_microsoft') {
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"
} else {
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-public"
}
```

### Shell Functions (add to $PROFILE)

```powershell
function gh-emu { $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"; gh @args }
function gh-pub { $env:GH_CONFIG_DIR = "$HOME\.config\gh-public"; gh @args }
```

### Why GH_CONFIG_DIR > GH_TOKEN

| | `GH_CONFIG_DIR` | `GH_TOKEN` |
|---|---|---|
| Isolates tokens | ✓ | ✓ |
| Isolates host settings | ✓ | ✗ |
| Isolates preferences | ✓ | ✗ |
| Isolates API cache | ✓ | ✗ |
| Needs token extraction | ✗ | ✓ |
| Token format validation | ✗ | ✓ (`gho_` prefix check) |
| Fallback logic needed | ✗ | ✓ |

### Verification

```powershell
# Quick check
./scripts/setup-gh-isolated-auth.ps1 -Verify

# Manual check
$env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"; gh auth status
$env:GH_CONFIG_DIR = "$HOME\.config\gh-public"; gh auth status
```

---

## Legacy Approach: Per-Process GH_TOKEN

> **Superseded by GH_CONFIG_DIR above.** Kept for reference and as a fallback for environments where config-dir isolation isn't practical.

Extract the token for the required account and set it as a process-local environment variable:

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

### Integration with ralph-watch.ps1 (Legacy)

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

---

## When to Use
- Multiple Ralph instances across repos with different GitHub accounts
- CI/CD environments where multiple gh-authenticated processes run concurrently
- DevBox/Cloud PC setups where personal and work repos coexist

## Key Insight
This is a classic distributed systems problem — shared mutable state (global auth) accessed by concurrent processes. The fix is the same as any concurrent programming fix: eliminate shared mutable state by making it process-local. `GH_CONFIG_DIR` is the cleanest solution because it isolates the entire config surface, not just the token.
