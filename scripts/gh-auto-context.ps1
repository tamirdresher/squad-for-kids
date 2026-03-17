#Requires -Version 5.1
<#
.SYNOPSIS
    Automatically sets GH_CONFIG_DIR based on the current working directory.
.DESCRIPTION
    Provides Set-GhContext, Install-GhAutoContext, and Uninstall-GhAutoContext
    to integrate per-directory GitHub account selection into your PowerShell prompt.
.EXAMPLE
    . ./scripts/gh-auto-context.ps1
    Install-GhAutoContext
#>

# --- Configurable rules ---------------------------------------------------
# Each rule is evaluated top-to-bottom; the first match wins.
# Pattern  : regex applied to (Get-Location).Path
# ConfigDir: the GH_CONFIG_DIR value to set when the pattern matches
if (-not (Get-Variable -Name GH_CONTEXT_RULES -Scope Script -ErrorAction SilentlyContinue)) {
    $script:GH_CONTEXT_RULES = @(
        @{ Pattern = 'tamirdresher_microsoft'; ConfigDir = "$HOME\.config\gh-emu" }
        @{ Pattern = '\\work\\';              ConfigDir = "$HOME\.config\gh-emu" }
    )
}

# Fallback when no rule matches
$script:GH_CONTEXT_DEFAULT = "$HOME\.config\gh-public"

# --- Core function ---------------------------------------------------------
function Set-GhContext {
    <#
    .SYNOPSIS
        Evaluates GH_CONTEXT_RULES against the current directory and sets GH_CONFIG_DIR.
    #>
    $dir = (Get-Location).Path
    foreach ($rule in $script:GH_CONTEXT_RULES) {
        if ($dir -match $rule.Pattern) {
            $env:GH_CONFIG_DIR = $rule.ConfigDir
            return
        }
    }
    $env:GH_CONFIG_DIR = $script:GH_CONTEXT_DEFAULT
}

# --- Install / Uninstall ---------------------------------------------------
$script:GH_AUTO_CONTEXT_MARKER = '# >>> gh-auto-context'

function Install-GhAutoContext {
    <#
    .SYNOPSIS
        Patches the current prompt function to call Set-GhContext on every prompt.
    #>
    $currentPrompt = (Get-Item Function:\prompt -ErrorAction SilentlyContinue)
    if (-not $currentPrompt) { return }

    $body = $currentPrompt.ScriptBlock.ToString()
    if ($body -match [regex]::Escape($script:GH_AUTO_CONTEXT_MARKER)) {
        Write-Host 'gh-auto-context is already installed in the prompt.' -ForegroundColor Yellow
        return
    }

    $hook = @"
$($script:GH_AUTO_CONTEXT_MARKER)
Set-GhContext
# <<< gh-auto-context
"@

    $newBody = "$hook`n$body"
    Set-Item Function:\prompt -Value ([scriptblock]::Create($newBody))
    Write-Host 'gh-auto-context installed into prompt.' -ForegroundColor Green
}

function Uninstall-GhAutoContext {
    <#
    .SYNOPSIS
        Removes the gh-auto-context hook from the prompt function.
    #>
    $currentPrompt = (Get-Item Function:\prompt -ErrorAction SilentlyContinue)
    if (-not $currentPrompt) { return }

    $body = $currentPrompt.ScriptBlock.ToString()
    $pattern = "(?m)^$([regex]::Escape($script:GH_AUTO_CONTEXT_MARKER))[\s\S]*?# <<< gh-auto-context\r?\n?"
    $cleaned = $body -replace $pattern, ''
    Set-Item Function:\prompt -Value ([scriptblock]::Create($cleaned))
    Write-Host 'gh-auto-context removed from prompt.' -ForegroundColor Green
}
