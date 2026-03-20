<#
.SYNOPSIS
    Resets the Squad for Kids demo environment to a clean state.

.DESCRIPTION
    Removes all generated files from a demo run so the next demo
    starts fresh. Alias for: .\demos\run-demo.ps1 -Mode Reset

.EXAMPLE
    .\demos\reset-demo.ps1
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

& (Join-Path $repoRoot "demos\run-demo.ps1") -Mode Reset
