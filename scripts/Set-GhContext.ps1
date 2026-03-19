# Set-GhContext.ps1
# Per-directory GH_CONFIG_DIR auto-detection for PowerShell
#
# Purpose:
#   When repos are organized by account (EMU repos in one folder, public repos
#   in another), this script hooks into the PowerShell `prompt` function to
#   automatically set GH_CONFIG_DIR based on the current working directory —
#   zero manual switching required.
#
# Usage:
#   Dot-source this file from your $PROFILE:
#
#       . "C:\path\to\tamresearch1\scripts\Set-GhContext.ps1"
#
#   After dot-sourcing, the prompt hook is installed automatically.
#   See .squad/docs/powershell-profile-snippets.md for full setup instructions.
#
# Accounts:
#   EMU / Microsoft org repos  ->  $env:APPDATA\GitHub CLI
#   Public / personal repos    ->  GH_CONFIG_DIR removed (use GH default: ~/.config/gh)

<#
.SYNOPSIS
    Sets GH_CONFIG_DIR based on the current working directory.
.DESCRIPTION
    Detects whether the current path belongs to an EMU (enterprise-managed user)
    GitHub account or a public/personal account, and sets GH_CONFIG_DIR
    accordingly so that `gh` commands use the correct credential store.

    EMU paths   (--> $env:APPDATA\GitHub CLI):
      - paths containing 'tamresearch1'
      - paths containing 'tamirdresher_microsoft'
      - paths under a \emu\ or \emu-repos\ directory

    Public paths (--> GH_CONFIG_DIR removed, gh default: ~/.config/gh):
      - paths containing 'tamirdresher.github'
      - paths under a \public\ directory
      - paths containing 'squad-monitor-standalone'

    If the current path matches neither pattern, GH_CONFIG_DIR is left unchanged
    so an explicitly set value is not accidentally cleared.
.EXAMPLE
    Set-GhContext
    # Called automatically from the prompt hook; safe to call manually.
#>
function Set-GhContext {
    $path = (Get-Location).Path.ToLower()

    if ($path -match 'tamresearch1' -or
        $path -match 'tamirdresher_microsoft' -or
        $path -match '\\emu\\' -or
        $path -match '\\emu-repos\\') {
        # EMU / Microsoft org: point to the enterprise GH CLI config
        $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
    }
    elseif ($path -match 'tamirdresher\.github' -or
            $path -match '\\public\\' -or
            $path -match 'squad-monitor-standalone') {
        # Public / personal repos: remove override so gh uses its default config
        Remove-Item Env:\GH_CONFIG_DIR -ErrorAction SilentlyContinue
    }
    # else: leave GH_CONFIG_DIR as-is (no match = no change)
}

# ---------------------------------------------------------------------------
# Prompt hook — installed automatically when this file is dot-sourced.
# Wraps the existing prompt function so Set-GhContext runs on every cd/prompt.
# ---------------------------------------------------------------------------

$_ghCtx_originalPrompt = if (Test-Path Function:\prompt) {
    $function:prompt
} else {
    { "> " }
}

function prompt {
    Set-GhContext
    & $_ghCtx_originalPrompt
}
