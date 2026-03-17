---
name: github-account-switching
description: Use gh-personal (ghp) and gh-emu (ghe) wrappers with GH_CONFIG_DIR for process-safe account isolation. NEVER use bare `gh` for repo operations or `gh auth switch`.
confidence: high
---

# GitHub Account Switching — MANDATORY PATTERN

## The Problem
We have two GitHub accounts. Agents constantly fail by:
- Forgetting to switch accounts
- Switching but then switching back too early
- Running commands in the wrong account context
- Concurrent processes fighting over global `gh auth switch` state

## The Solution — GH_CONFIG_DIR Isolation

Each wrapper sets `GH_CONFIG_DIR` to a dedicated config directory before calling `gh`.
This is **process-local** — concurrent calls from different shells or agents never interfere.

| Wrapper | Config Dir | Account | Use For |
|---------|-----------|---------|---------|
| `ghp` / `gh-personal` | `~/.config/gh-public` | tamirdresher | squad-skills, squad-monitor, personal public repos |
| `ghe` / `gh-emu` | `~/.config/gh-emu` | tamirdresher_microsoft | tamresearch1, tamresearch1-research, all EMU/work repos |

## Rules

1. **NEVER** use bare `gh` for repo operations — always use `ghp` or `ghe`
2. **NEVER** use `gh auth switch` — it mutates global state and is not process-safe
3. Determine which wrapper by the repo:
   - `tamirdresher/*` repos → `ghp`
   - `tamirdresher_microsoft/*` repos → `ghe`
4. For operations that don’t target a repo (e.g., `gh auth status`), bare `gh` is OK

## How It Works

```powershell
# PowerShell wrappers (in scripts/gh-account-wrappers.ps1)
function ghe { $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"; gh @args }
function ghp { $env:GH_CONFIG_DIR = "$HOME\.config\gh-public"; gh @args }
```

```batch
:: CMD wrappers (gh-emu.cmd / gh-personal.cmd)
@echo off
set "GH_CONFIG_DIR=%USERPROFILE%\.config\gh-emu"
gh %*
```

Each config directory holds its own `hosts.yml`, tokens, and preferences — fully isolated.

## Examples

```powershell
# EMU work
ghe issue list                           # lists issues in current EMU repo
ghe pr create --title "fix" --body "..."  # creates PR in EMU repo
ghe repo view tamirdresher_microsoft/tamresearch1

# Personal work
ghp repo list                            # lists personal repos
ghp issue create --repo tamirdresher/squad-skills --title "new plugin"
ghp pr list --repo tamirdresher/squad-monitor

# Concurrent usage — safe because GH_CONFIG_DIR is process-local
ghe issue list --json number,title       # EMU
ghp repo list --json name               # personal — no conflict!
```

## Auto-Context (per-directory activation)

`scripts/gh-auto-context.ps1` automatically sets `GH_CONFIG_DIR` every time the
prompt renders, so `gh` (and by extension the aliases) pick the right config
directory without any manual intervention.

### Quick start

```powershell
. ./scripts/gh-auto-context.ps1   # dot-source the script
Install-GhAutoContext              # hook into the prompt
```

### How it works

1. `$GH_CONTEXT_RULES` — an ordered array of `@{ Pattern; ConfigDir }` hashtables.
   The first regex match against `(Get-Location).Path` wins.
2. Default rules:
   - Paths matching `tamirdresher_microsoft` → `~/.config/gh-emu`
   - Paths under `\work\` → `~/.config/gh-emu`
   - Everything else → `~/.config/gh-public`
3. Override before dot-sourcing to add custom rules:
   ```powershell
   $GH_CONTEXT_RULES = @(
       @{ Pattern = 'my-corp'; ConfigDir = "$HOME\.config\gh-corp" }
   )
   . ./scripts/gh-auto-context.ps1
   ```

### Functions

| Function | Purpose |
|----------|---------|
| `Set-GhContext` | Evaluate rules and set `GH_CONFIG_DIR` (call manually or via prompt hook) |
| `Install-GhAutoContext` | Patch `prompt` to call `Set-GhContext` on every prompt |
| `Uninstall-GhAutoContext` | Remove the hook from `prompt` |

## Setup

1. **One-time init**: Run `scripts/setup-gh-isolated-auth.ps1` to create config dirs and authenticate
2. **PowerShell**: Dot-source the wrappers in your profile:
   ```powershell
   . "C:\temp\tamresearch1\scripts\gh-account-wrappers.ps1"
   ```
3. **CMD**: Wrappers at `C:\temp\bin\gh-personal.cmd` and `C:\temp\bin\gh-emu.cmd` (ensure `C:\temp\bin` is in PATH)

## Deprecated

> ⚠️ **`gh auth switch` is deprecated for multi-account use.**
> It mutates global state (`~/.config/gh/hosts.yml`) and is not safe when
> multiple processes run concurrently. Use `GH_CONFIG_DIR` wrappers instead.
> See `.squad/skills/gh-auth-isolation/SKILL.md` for the full rationale.
