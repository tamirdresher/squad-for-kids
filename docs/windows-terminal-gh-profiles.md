# Windows Terminal Profiles for GitHub Accounts

Switch between GitHub EMU (work) and GitHub Public (personal) accounts instantly
using dedicated Windows Terminal profiles. Each profile sets `GH_CONFIG_DIR` so
the GitHub CLI (`gh`) uses the correct credential store.

## Quick Install (Automated)

```powershell
# From the repo root
.\scripts\install-wt-profiles.ps1

# Preview changes without writing
.\scripts\install-wt-profiles.ps1 -DryRun
```

The script is **idempotent** — running it again will not duplicate profiles.
A timestamped backup of `settings.json` is created before any changes.

## Manual Install

Open **Windows Terminal → Settings → Open JSON file** (or press `Ctrl+Shift+,`)
and add the following entries inside `profiles.list`:

```jsonc
{
  "profiles": {
    "list": [
      // ... existing profiles ...

      {
        "guid": "{a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d}",
        "name": "GitHub EMU (Work)",
        "commandline": "pwsh -NoExit -Command \"$env:GH_CONFIG_DIR = '$HOME\\.config\\gh-emu'; Write-Host '🏢 GitHub EMU account active' -ForegroundColor Yellow; gh auth status\"",
        "tabTitle": "GH EMU",
        "tabColor": "#FFB900",
        "icon": "ms-appx:///ProfileIcons/pwsh.png",
        "hidden": false
      },
      {
        "guid": "{d5c4b3a2-1f0e-4d9c-8b7a-6e5f4d3c2b1a}",
        "name": "GitHub Public (Personal)",
        "commandline": "pwsh -NoExit -Command \"$env:GH_CONFIG_DIR = '$HOME\\.config\\gh-public'; Write-Host '🌐 GitHub Public account active' -ForegroundColor Green; gh auth status\"",
        "tabTitle": "GH Public",
        "tabColor": "#16C60C",
        "icon": "ms-appx:///ProfileIcons/pwsh.png",
        "hidden": false
      }
    ]
  }
}
```

## One-Time Setup per Account

Before using the profiles, authenticate each account once:

```powershell
# EMU account
$env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"
gh auth login --hostname github.yourcompany.com

# Public account
$env:GH_CONFIG_DIR = "$HOME\.config\gh-public"
gh auth login --hostname github.com
```

## How It Works

| Profile | Config Dir | Tab Color | Banner |
|---------|-----------|-----------|--------|
| GitHub EMU (Work) | `~/.config/gh-emu` | 🟡 Yellow (`#FFB900`) | 🏢 GitHub EMU account active |
| GitHub Public (Personal) | `~/.config/gh-public` | 🟢 Green (`#16C60C`) | 🌐 GitHub Public account active |

Each profile launches `pwsh` with `-NoExit` and:
1. Sets `GH_CONFIG_DIR` to an isolated credential directory
2. Prints a **colored banner** so you always know which account is active
3. Runs `gh auth status` to confirm authentication

## Troubleshooting

**Profiles don't appear after install:**
Close all Windows Terminal windows and reopen. The settings file is read on launch.

**`gh auth status` shows "not logged in":**
Run the one-time setup above for the relevant account.

**Settings path not found:**
The script expects the Microsoft Store edition of Windows Terminal.
For other installations, pass the correct path or edit `settings.json` manually.
