<#
.SYNOPSIS
    GH_CONFIG_DIR-based wrappers for multi-account GitHub CLI usage.
.DESCRIPTION
    Provides ghp/ghe functions that isolate GitHub CLI config per-account
    using GH_CONFIG_DIR, enabling safe concurrent usage across processes.
.NOTES
    Dot-source from your PowerShell profile:
        . "$PSScriptRoot\scripts\gh-account-wrappers.ps1"
    or
        . "C:\temp\tamresearch1\scripts\gh-account-wrappers.ps1"

    Prerequisites: Run scripts/setup-gh-isolated-auth.ps1 first to create
    the isolated config directories and authenticate each account.
#>

function ghe {
    <#
    .SYNOPSIS
        Run gh commands as the EMU account (tamirdresher_microsoft).
    #>
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"
    gh @args
}

function ghp {
    <#
    .SYNOPSIS
        Run gh commands as the personal account (tamirdresher).
    #>
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-public"
    gh @args
}

Set-Alias -Name gh-emu -Value ghe
Set-Alias -Name gh-personal -Value ghp
