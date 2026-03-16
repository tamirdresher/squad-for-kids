---
name: gh-auth-isolation
description: Prevent gh auth race conditions when multiple Ralphs run across repos by using per-process GH_TOKEN instead of global `gh auth switch`.
confidence: high
---

# GH Auth Isolation — Per-Process Token Pattern

## The Problem

When multiple Ralph instances run simultaneously across different repos (tamresearch1, jellybolt, devtools-pro, etc.), they share a single global `gh` CLI auth state. Each Ralph calls `gh auth switch --user <account>` to authenticate, which mutates global state in `~/.config/gh/hosts.yml`. This creates a race condition:

1. Ralph-A switches to `tamirdresher_microsoft`
2. Ralph-B switches to `tamirdresher` (overwriting Ralph-A's context)
3. Ralph-A runs `gh pr create` — **fails** because global auth is now `tamirdresher`

The more Ralphs running, the worse the problem. With 3+ concurrent instances, auth failures become near-constant.

## Root Cause

`gh auth switch` is a **global mutation** — it writes to a shared config file on disk. The `gh` CLI reads the "active account" from this file on every invocation. There is no built-in per-process or per-session auth isolation.

```
~/.config/gh/hosts.yml   ← shared by ALL gh processes
├── github.com:
│   ├── user: tamirdresher_microsoft   ← last `gh auth switch` wins
│   ├── oauth_token: gho_...
│   └── ...
```

When two processes race on `gh auth switch`, the loser's subsequent `gh` commands run under the wrong account.

## The Fix: Per-Process `GH_TOKEN`

The `gh` CLI respects the `GH_TOKEN` environment variable. When set, it **overrides** the global auth state entirely — no disk read, no race.

The key insight: `gh auth token --user <account>` returns the stored OAuth token for a specific account **without switching global state**. Combine these:

```powershell
# Set per-process token — does NOT mutate global state
$env:GH_TOKEN = $(gh auth token --user tamirdresher_microsoft)

# All subsequent gh commands in THIS process use this token
gh pr list          # ✅ runs as tamirdresher_microsoft
gh issue create ... # ✅ runs as tamirdresher_microsoft
```

Other processes are completely unaffected. No file lock, no race.

## Example Usage in Ralph Scripts

### Basic: Single-Account Ralph

```powershell
# At the top of any Ralph script targeting an EMU repo
$env:GH_TOKEN = $(gh auth token --user tamirdresher_microsoft)

# All gh commands now safely use the EMU account
gh pr list --repo tamirdresher_microsoft/tamresearch1
gh issue list --repo tamirdresher_microsoft/tamresearch1
```

### Multi-Account: Cross-Repo Operations

```powershell
# Save tokens once at script start
$emuToken = gh auth token --user tamirdresher_microsoft
$personalToken = gh auth token --user tamirdresher

# EMU operations
$env:GH_TOKEN = $emuToken
gh pr list --repo tamirdresher_microsoft/tamresearch1

# Personal operations — just swap the env var
$env:GH_TOKEN = $personalToken
gh issue list --repo tamirdresher/squad-skills

# Back to EMU — no global state touched at any point
$env:GH_TOKEN = $emuToken
gh pr create --title "fix" --body "..."
```

### Ralph Watch Loop Integration

```powershell
# ralph-watch.ps1 — each cycle is auth-safe
function Start-RalphCycle {
    param([string]$Account, [string]$Repo)

    # Lock auth for this process at cycle start
    $env:GH_TOKEN = $(gh auth token --user $Account)

    # All operations in this cycle are safe
    $issues = gh issue list --repo $Repo --json number,title | ConvertFrom-Json
    foreach ($issue in $issues) {
        # Process issue... gh commands all use $Account
    }
}

# Multiple Ralphs can run these simultaneously — zero conflicts
Start-RalphCycle -Account "tamirdresher_microsoft" -Repo "tamirdresher_microsoft/tamresearch1"
```

## When to Use This Pattern

| Scenario | Use This Pattern? |
|----------|:-----------------:|
| Multiple Ralphs across repos running simultaneously | ✅ **Yes** |
| Any script that runs `gh` commands in background/scheduled tasks | ✅ **Yes** |
| Single interactive `gh` command in a terminal | ❌ No — `ghp`/`ghe` aliases are fine |
| CI/CD pipelines (GitHub Actions) | ❌ No — use `GITHUB_TOKEN` secret instead |
| One-off manual scripts | ⚠️ Optional but recommended |

**Rule of thumb:** If the script might run concurrently with other `gh`-using processes, use `GH_TOKEN` isolation.

## Relationship to `ghp`/`ghe` Aliases

The `ghp` and `ghe` aliases (see `github-account-switching` skill) wrap `gh auth switch` before each command. They are convenient for interactive use but still mutate global state, making them unsafe for concurrent processes.

- **Interactive terminal work** → use `ghp`/`ghe` aliases
- **Automated/concurrent scripts** → use `$env:GH_TOKEN` pattern from this skill

## Validation

This pattern has been validated in production:
- ✅ Multiple Ralphs running across 3+ repos simultaneously
- ✅ Zero auth race failures after adopting `GH_TOKEN` isolation
- ✅ No interference with `ghp`/`ghe` aliases for interactive use
- ✅ Token retrieval via `gh auth token` does not require re-authentication
