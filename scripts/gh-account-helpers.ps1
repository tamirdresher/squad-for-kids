# GitHub CLI account isolation helpers
# Source this file (or add to $PROFILE) so any terminal can target either
# GitHub account with a simple command prefix.
#
# Usage:
#   gh-emu issue list --repo tamirdresher_microsoft/tamresearch1
#   gh-pub  repo list --limit 10
#
# To load automatically, add to your $PROFILE:
#   . "$PSScriptRoot\scripts\gh-account-helpers.ps1"
# or dot-source from the squad profile:
#   . "$env:SQUAD_ROOT\.squad\profile.ps1"

function gh-emu {
    <#
    .SYNOPSIS
    Run gh CLI commands targeting the EMU (Microsoft enterprise) account.
    .DESCRIPTION
    Sets GH_CONFIG_DIR to the Windows GitHub CLI config directory used by
    the EMU account (tamirdresher_microsoft) before delegating to gh.
    .EXAMPLE
    gh-emu issue list --state open --repo tamirdresher_microsoft/tamresearch1
    gh-emu pr create --title "My PR" --body ""
    #>
    $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
    gh @args
}

function gh-pub {
    <#
    .SYNOPSIS
    Run gh CLI commands targeting the public GitHub account.
    .DESCRIPTION
    Clears GH_CONFIG_DIR so gh falls back to its default config location,
    which is configured for the public account (tamirdresher).
    .EXAMPLE
    gh-pub repo list --limit 10
    gh-pub issue list --repo tamirdresher/some-public-repo
    #>
    $env:GH_CONFIG_DIR = ""
    gh @args
}

# Make functions available when this file is dot-sourced as a module fragment
Export-ModuleMember -Function gh-emu, gh-pub -ErrorAction SilentlyContinue
