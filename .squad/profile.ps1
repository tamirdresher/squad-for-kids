# Squad PowerShell Profile
# Dot-source this file from your $PROFILE to get all squad helper functions.
#
# Add to $PROFILE:
#   . "C:\path\to\tamresearch1\.squad\profile.ps1"
#
# Or run once in a session:
#   . $env:SQUAD_ROOT\.squad\profile.ps1

$_squadRoot = Split-Path -Parent $PSScriptRoot

# ── GitHub CLI account helpers ──────────────────────────────────────────────
# Provides gh-emu (EMU / Microsoft enterprise) and gh-pub (public GitHub).
$_ghHelpers = Join-Path $_squadRoot "scripts\gh-account-helpers.ps1"
if (Test-Path $_ghHelpers) {
    . $_ghHelpers
} else {
    Write-Warning "Squad profile: gh-account-helpers.ps1 not found at $_ghHelpers"
}
