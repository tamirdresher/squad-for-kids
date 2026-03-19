# PowerShell Profile Snippets

This document covers per-directory `GH_CONFIG_DIR` auto-detection — the feature
implemented in [issue #938](https://github.com/tamirdresher_microsoft/tamresearch1/issues/938).

## Background

This repo (and related Microsoft org repos) require `GH_CONFIG_DIR` to point at
`$env:APPDATA\GitHub CLI` (the EMU / enterprise-managed account config).  Public
or personal repos should use the `gh` default (`~/.config/gh`).  Manually
exporting `GH_CONFIG_DIR` before every `gh` command is error-prone; the prompt
hook below eliminates that.

## Quick Start

1. **Install** — add one line to your `$PROFILE`:

       . "$env:USERPROFILE\tamresearch1\scripts\Set-GhContext.ps1"

2. **Verify** — open a new shell, `cd` into this repo, then run:

       $env:GH_CONFIG_DIR   # should be: C:\Users\<you>\AppData\Roaming\GitHub CLI

3. **Switch** — `cd` somewhere outside the repo and run the same check:

       $env:GH_CONFIG_DIR   # should be empty / default

## How it Works

`scripts/Set-GhContext.ps1` exports two things when dot-sourced:

| Name | What it does |
|------|-------------|
| `Set-GhContext` | Inspects `(Get-Location).Path` against regex rules and sets (or clears) `GH_CONFIG_DIR`. |
| `prompt` wrapper | Calls `Set-GhContext` on every prompt so the correct context is active as soon as you `cd`. |

### Path rules (first match wins)

| Pattern | Action |
|---------|--------|
| `tamresearch1` | Set EMU config |
| `tamirdresher_microsoft` | Set EMU config |
| `\emu\` or `\emu-repos\` | Set EMU config |
| `tamirdresher.github` | Clear GH_CONFIG_DIR (public default) |
| `\public\` | Clear GH_CONFIG_DIR (public default) |
| `squad-monitor-standalone` | Clear GH_CONFIG_DIR (public default) |
| *(no match)* | Leave GH_CONFIG_DIR unchanged |

### Config paths

| Context | GH_CONFIG_DIR value |
|---------|---------------------|
| EMU / Microsoft | `$env:APPDATA\GitHub CLI` |
| Public / personal | *(cleared — gh reads `~/.config/gh`)* |

## Full Profile Example

If you do not yet have a `$PROFILE`, copy the template at the repo root:

    Copy-Item "$env:USERPROFILE\tamresearch1\Microsoft.PowerShell_profile.ps1" $PROFILE

The template dot-sources `Set-GhContext.ps1` and calls `Set-GhContext` once at
startup so the correct context is active from the moment the shell opens.

## Troubleshooting

**GH_CONFIG_DIR is still wrong after cd**

Make sure the file is dot-sourced in your profile (`. .\scripts\...` not just
called as a script).  Check with:

    Get-Command Set-GhContext -ErrorAction SilentlyContinue

**I need to override temporarily**

Set `GH_CONFIG_DIR` explicitly — `Set-GhContext` only changes the value when a
pattern matches and never clears a value in unmatched directories.

    $env:GH_CONFIG_DIR = "C:\some\other\config"

## References

- jongio/gh-public-gh-emu-setup — original inspiration
- Issue #938 — implementation tracking
- Issue #778 — predecessor / related
