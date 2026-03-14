#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Squad Model Monitor — Checks current agent model assignments against available models.

.DESCRIPTION
    Reads each squad agent's charter.md and the model-assignments-snapshot.md to determine
    current model usage, compares against the known set of available models, and outputs
    recommendations for model updates.

    Designed to be run periodically (e.g., weekly via Ralph's monitoring).

.EXAMPLE
    ./scripts/model-monitor.ps1
    ./scripts/model-monitor.ps1 -Verbose
    ./scripts/model-monitor.ps1 -OutputMarkdown

.NOTES
    Created: 2026-03-14 (Issue #509)
    Author: Seven (Research & Docs)
#>

[CmdletBinding()]
param(
    [switch]$OutputMarkdown,
    [string]$TeamRoot = (git rev-parse --show-toplevel 2>$null) ?? $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

# ─── Model Registry ───────────────────────────────────────────────────────────
# Available models in the platform (update when new models ship)
# Last updated: 2026-03-14
$AvailableModels = @(
    @{ Id = 'claude-opus-4.6';       Tier = 'Premium';  Provider = 'Anthropic'; Released = '2026-02'; Notes = 'Highest quality, 1M context, top SWE-bench' }
    @{ Id = 'claude-opus-4.6-1m';    Tier = 'Premium';  Provider = 'Anthropic'; Released = '2026-02'; Notes = 'Opus 4.6 with 1M context (internal only)' }
    @{ Id = 'claude-opus-4.5';       Tier = 'Premium';  Provider = 'Anthropic'; Released = '2025-Q4'; Notes = 'Previous flagship' }
    @{ Id = 'claude-sonnet-4.6';     Tier = 'Standard'; Provider = 'Anthropic'; Released = '2026-03'; Notes = 'NEW — latest standard tier' }
    @{ Id = 'claude-sonnet-4.5';     Tier = 'Standard'; Provider = 'Anthropic'; Released = '2025-Q3'; Notes = 'Current squad primary' }
    @{ Id = 'claude-sonnet-4';       Tier = 'Standard'; Provider = 'Anthropic'; Released = '2025-Q1'; Notes = 'Previous generation' }
    @{ Id = 'claude-haiku-4.5';      Tier = 'Fast';     Provider = 'Anthropic'; Released = '2025-Q3'; Notes = 'Current squad fast tier' }
    @{ Id = 'gemini-3-pro-preview';  Tier = 'Standard'; Provider = 'Google';    Released = '2026-02'; Notes = 'Multimodal, large context' }
    @{ Id = 'gpt-5.4';              Tier = 'Standard'; Provider = 'OpenAI';    Released = '2026-03'; Notes = 'NEW — 1M context, native computer-use' }
    @{ Id = 'gpt-5.3-codex';        Tier = 'Standard'; Provider = 'OpenAI';    Released = '2026-02'; Notes = 'Code-specialized' }
    @{ Id = 'gpt-5.2-codex';        Tier = 'Standard'; Provider = 'OpenAI';    Released = '2025-Q4'; Notes = 'Stable code model' }
    @{ Id = 'gpt-5.2';              Tier = 'Standard'; Provider = 'OpenAI';    Released = '2025-Q4'; Notes = 'Stable general model' }
    @{ Id = 'gpt-5.1-codex-max';    Tier = 'Standard'; Provider = 'OpenAI';    Released = '2025-Q3'; Notes = 'Max code context' }
    @{ Id = 'gpt-5.1-codex';        Tier = 'Standard'; Provider = 'OpenAI';    Released = '2025-Q3'; Notes = 'Standard code model' }
    @{ Id = 'gpt-5.1';              Tier = 'Standard'; Provider = 'OpenAI';    Released = '2025-Q3'; Notes = 'Standard general model' }
    @{ Id = 'gpt-5.1-codex-mini';   Tier = 'Fast';     Provider = 'OpenAI';    Released = '2025-Q3'; Notes = 'Budget code option' }
    @{ Id = 'gpt-5-mini';           Tier = 'Fast';     Provider = 'OpenAI';    Released = '2025-Q2'; Notes = 'Budget general option' }
    @{ Id = 'gpt-4.1';              Tier = 'Fast';     Provider = 'OpenAI';    Released = '2025-Q1'; Notes = 'Legacy fast option' }
)

# ─── Read Agent Charters ──────────────────────────────────────────────────────
function Get-AgentModelAssignments {
    param([string]$Root)

    $agentsDir = Join-Path $Root '.squad' 'agents'
    $agents = @()

    foreach ($dir in Get-ChildItem -Path $agentsDir -Directory | Where-Object { $_.Name -notmatch '^_' }) {
        $charterPath = Join-Path $dir.FullName 'charter.md'
        if (-not (Test-Path $charterPath)) { continue }

        $content = Get-Content $charterPath -Raw
        $agentName = $dir.Name

        # Extract model preference
        $model = 'auto'
        if ($content -match '(?m)^\*\*Preferred:\*\*\s*(.+)$') {
            $model = $Matches[1].Trim()
        }

        # Extract role
        $role = 'Unknown'
        if ($content -match '(?m)^\*\*Role:\*\*\s*(.+)$') {
            $role = $Matches[1].Trim()
        }

        $agents += @{
            Name    = $agentName
            Role    = $role
            Model   = $model
            Charter = $charterPath
        }
    }

    return $agents
}

# ─── Read Snapshot File ───────────────────────────────────────────────────────
function Get-SnapshotAssignments {
    param([string]$Root)

    $snapshotPath = Join-Path $Root '.squad' 'model-assignments-snapshot.md'
    if (-not (Test-Path $snapshotPath)) {
        Write-Warning "No model-assignments-snapshot.md found"
        return @()
    }

    $content = Get-Content $snapshotPath -Raw
    $assignments = @()

    # Parse the table rows: | Agent | Model | Tier | ...
    $lines = $content -split "`n"
    foreach ($line in $lines) {
        if ($line -match '^\|\s*(\w[\w'']+)\s*\|\s*([\w\-\.]+)\s*\|\s*(\w+)\s*\|') {
            $name = $Matches[1].Trim()
            $model = $Matches[2].Trim()
            $tier = $Matches[3].Trim()
            if ($name -in @('Agent', '---')) { continue }
            $assignments += @{
                Name  = $name.ToLower()
                Model = $model
                Tier  = $tier
            }
        }
    }

    return $assignments
}

# ─── Generate Recommendations ─────────────────────────────────────────────────
function Get-ModelRecommendations {
    param(
        [array]$Agents,
        [array]$Snapshot,
        [array]$Models
    )

    $recommendations = @()
    $newStandardModels = $Models | Where-Object { $_.Tier -eq 'Standard' -and $_.Released -match '2026-0[23]' }
    $newFastModels     = $Models | Where-Object { $_.Tier -eq 'Fast' -and $_.Released -match '2026' }

    foreach ($snap in $Snapshot) {
        $currentModel = $snap.Model
        $agentName = $snap.Name
        $tier = $snap.Tier

        # Check if agent is on an older model when newer is available
        if ($currentModel -eq 'claude-sonnet-4.5' -and ($newStandardModels | Where-Object { $_.Id -eq 'claude-sonnet-4.6' })) {
            $recommendations += @{
                Agent       = $agentName
                Current     = $currentModel
                Suggested   = 'claude-sonnet-4.6'
                Reason      = 'Sonnet 4.6 now available — successor to current Sonnet 4.5'
                Priority    = 'Medium'
            }
        }
    }

    # Flag new models not assigned to anyone
    foreach ($model in $newStandardModels) {
        if ($model.Id -notin $Snapshot.Model) {
            $recommendations += @{
                Agent    = '(unassigned)'
                Current  = 'N/A'
                Suggested = $model.Id
                Reason    = "New model released ($($model.Released)): $($model.Notes)"
                Priority  = 'Info'
            }
        }
    }

    return $recommendations
}

# ─── Main ──────────────────────────────────────────────────────────────────────
Write-Host "`n=== Squad Model Monitor ===" -ForegroundColor Cyan
Write-Host "Scan Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor DarkGray
Write-Host ""

# Resolve team root
if (-not $TeamRoot -or -not (Test-Path (Join-Path $TeamRoot '.squad'))) {
    $TeamRoot = $PSScriptRoot | Split-Path
}

$agents = Get-AgentModelAssignments -Root $TeamRoot
$snapshot = Get-SnapshotAssignments -Root $TeamRoot
$recommendations = Get-ModelRecommendations -Agents $agents -Snapshot $snapshot -Models $AvailableModels

# ─── Display Current Assignments ──────────────────────────────────────────────
Write-Host "── Current Agent Model Assignments ──" -ForegroundColor Yellow
Write-Host ""
Write-Host ("{0,-12} {1,-25} {2,-10} {3}" -f "Agent", "Model (snapshot)", "Tier", "Charter Override")
Write-Host ("{0,-12} {1,-25} {2,-10} {3}" -f "─────", "───────────────", "────", "────────────────")

foreach ($snap in $snapshot) {
    $charter = $agents | Where-Object { $_.Name -eq $snap.Name }
    $override = if ($charter -and $charter.Model -ne 'auto') { $charter.Model } else { '-' }
    Write-Host ("{0,-12} {1,-25} {2,-10} {3}" -f $snap.Name, $snap.Model, $snap.Tier, $override)
}

# ─── Display Available Models ─────────────────────────────────────────────────
Write-Host ""
Write-Host "── Available Models (Platform) ──" -ForegroundColor Yellow
Write-Host ""
Write-Host ("{0,-25} {1,-10} {2,-12} {3}" -f "Model", "Tier", "Provider", "Released")
Write-Host ("{0,-25} {1,-10} {2,-12} {3}" -f "─────", "────", "────────", "────────")

foreach ($model in $AvailableModels | Sort-Object { $_.Provider }, { $_.Tier }) {
    $marker = if ($model.Released -match '2026-03') { ' ★ NEW' } else { '' }
    Write-Host ("{0,-25} {1,-10} {2,-12} {3}{4}" -f $model.Id, $model.Tier, $model.Provider, $model.Released, $marker)
}

# ─── Display Recommendations ─────────────────────────────────────────────────
Write-Host ""
Write-Host "── Recommendations ──" -ForegroundColor Yellow
Write-Host ""

if ($recommendations.Count -eq 0) {
    Write-Host "  ✅ No model changes recommended at this time." -ForegroundColor Green
} else {
    foreach ($rec in $recommendations) {
        $color = switch ($rec.Priority) {
            'High'   { 'Red' }
            'Medium' { 'Yellow' }
            default  { 'DarkGray' }
        }
        Write-Host ("  [{0}] {1}: {2} → {3}" -f $rec.Priority, $rec.Agent, $rec.Current, $rec.Suggested) -ForegroundColor $color
        Write-Host ("         Reason: {0}" -f $rec.Reason) -ForegroundColor DarkGray
    }
}

# ─── Markdown Output ──────────────────────────────────────────────────────────
if ($OutputMarkdown) {
    $md = @"
# Model Monitor Report — $(Get-Date -Format 'yyyy-MM-dd')

## Current Assignments

| Agent | Model | Tier |
|-------|-------|------|
$(($snapshot | ForEach-Object { "| $($_.Name) | $($_.Model) | $($_.Tier) |" }) -join "`n")

## New Models (March 2026)

| Model | Tier | Provider | Notes |
|-------|------|----------|-------|
$(($AvailableModels | Where-Object { $_.Released -match '2026-0[23]' } | ForEach-Object { "| $($_.Id) | $($_.Tier) | $($_.Provider) | $($_.Notes) |" }) -join "`n")

## Recommendations

$(if ($recommendations.Count -eq 0) { "✅ No changes recommended." } else { ($recommendations | ForEach-Object { "- **[$($_.Priority)]** $($_.Agent): ``$($_.Current)`` → ``$($_.Suggested)`` — $($_.Reason)" }) -join "`n" })
"@
    Write-Output $md
}

Write-Host ""
Write-Host "Done. Run with -OutputMarkdown for report output." -ForegroundColor DarkGray
