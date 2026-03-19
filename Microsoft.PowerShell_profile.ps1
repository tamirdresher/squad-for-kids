# Microsoft.PowerShell_profile.ps1
# PowerShell profile template for tamresearch1 development environment.
#
# INSTALLATION:
#   If your $PROFILE does not yet exist, you can copy this file directly:
#
#       Copy-Item "$env:USERPROFILE\tamresearch1\Microsoft.PowerShell_profile.ps1" $PROFILE
#
#   Or append the relevant sections to an existing profile:
#
#       Get-Content "$env:USERPROFILE\tamresearch1\Microsoft.PowerShell_profile.ps1" | Add-Content $PROFILE
#
# See .squad/docs/powershell-profile-snippets.md for full setup guide.

# ---------------------------------------------------------------------------
# GH_CONFIG_DIR auto-detection (issue #938)
# Automatically switches the GitHub CLI context based on the current directory:
#   - EMU / Microsoft org repos  →  $env:APPDATA\GitHub CLI
#   - Public / personal repos    →  GH_CONFIG_DIR cleared (gh default: ~/.config/gh)
# ---------------------------------------------------------------------------

$_ghCtxScript = Join-Path $PSScriptRoot "scripts\Set-GhContext.ps1"
if (Test-Path $_ghCtxScript) {
    . $_ghCtxScript
} else {
    # Fallback: inline minimal version if the repo isn't at $PSScriptRoot
    function Set-GhContext {
        $path = (Get-Location).Path.ToLower()
        if ($path -match 'tamresearch1' -or
            $path -match 'tamirdresher_microsoft' -or
            $path -match '\\emu\\' -or
            $path -match '\\emu-repos\\') {
            $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
        }
        elseif ($path -match 'tamirdresher\.github' -or
                $path -match '\\public\\' -or
                $path -match 'squad-monitor-standalone') {
            Remove-Item Env:\GH_CONFIG_DIR -ErrorAction SilentlyContinue
        }
    }

    $_ghCtx_originalPrompt = if (Test-Path Function:\prompt) { $function:prompt } else { { "> " } }
    function prompt {
        Set-GhContext
        & $_ghCtx_originalPrompt
    }
}

# Run once at startup to set the correct context for the current directory
Set-GhContext

# ---------------------------------------------------------------------------
# GitHub CLI account shortcuts (issue #936)
# gh-emu  : run gh against the EMU / Microsoft GitHub account
# gh-pub  : run gh against the public / personal GitHub account
# Usage:   gh-emu issue list --repo tamirdresher_microsoft/tamresearch1
#           gh-pub repo list
# ---------------------------------------------------------------------------
function gh-emu {
    $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
    gh @args
}

function gh-pub {
    $saved = $env:GH_CONFIG_DIR
    Remove-Item Env:\GH_CONFIG_DIR -ErrorAction SilentlyContinue
    try { gh @args }
    finally { if ($saved) { $env:GH_CONFIG_DIR = $saved } }
}
