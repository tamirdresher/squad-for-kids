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

## Setup
Aliases are defined in:
- PowerShell profile: `$PROFILE.CurrentUserAllHosts`
- CMD scripts: `C:\temp\bin\gh-personal.cmd` and `C:\temp\bin\gh-emu.cmd`
