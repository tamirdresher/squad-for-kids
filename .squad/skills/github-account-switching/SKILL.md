---
name: github-account-switching
description: Use gh-personal (ghp) and gh-emu (ghe) aliases to avoid account context errors. NEVER use bare `gh` followed by `gh auth switch`.
confidence: high
---

# GitHub Account Switching — MANDATORY PATTERN

## The Problem
We have two GitHub accounts. Agents constantly fail by:
- Forgetting to switch accounts
- Switching but then switching back too early
- Running commands in the wrong account context

## The Solution — Account-Locked Aliases

| Alias | Account | Use For |
|-------|---------|---------|
| `ghp` / `gh-personal` | tamirdresher | squad-skills, squad-monitor, personal public repos |
| `ghe` / `gh-emu` | tamirdresher_microsoft | tamresearch1, tamresearch1-research, all EMU/work repos |

Each alias switches to the correct account BEFORE running the command. No manual `gh auth switch` needed.

## Rules

1. **NEVER** use bare `gh` for repo operations — always use `ghp` or `ghe`
2. **NEVER** manually run `gh auth switch` — the aliases handle it
3. Determine which alias by the repo:
   - `tamirdresher/*` repos → `ghp`
   - `tamirdresher_microsoft/*` repos → `ghe`
4. For operations that don't target a repo (e.g., `gh auth status`), bare `gh` is OK

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

# Cross-account in one script — safe because each call locks its own context
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
Aliases are defined in:
- PowerShell profile: `$PROFILE.CurrentUserAllHosts`
- CMD scripts: `C:\temp\bin\gh-personal.cmd` and `C:\temp\bin\gh-emu.cmd`
