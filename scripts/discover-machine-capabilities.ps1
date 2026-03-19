<#
.SYNOPSIS
    Discovers machine capabilities for smart Ralph routing.
.DESCRIPTION
    Probes the local machine for available tools, accounts, and services,
    then writes a capability manifest to ~/.squad/machine-capabilities.json.
    Ralph uses this manifest to skip issues whose needs:* labels require
    capabilities this machine doesn't have.
.NOTES
    Issue #987 — Machine Capability Labels & Smart Routing
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'

$capabilities = [System.Collections.Generic.List[string]]::new()
$missing      = [System.Collections.Generic.List[string]]::new()
$details      = [ordered]@{}

# ── 1. GitHub accounts ──────────────────────────────────────────────────────
Write-Host "[discover] Checking GitHub accounts..." -ForegroundColor Cyan

# Check for personal GitHub account
$ghStatusPersonal = $null
try {
    $savedDir = $env:GH_CONFIG_DIR
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-public"
    $ghStatusPersonal = gh auth status 2>&1 | Out-String
    $env:GH_CONFIG_DIR = $savedDir
} catch {}

if ($ghStatusPersonal -match "tamirdresher[^_]|Logged in to github.com.*account tamirdresher\b") {
    $capabilities.Add("personal-gh")
    $details["personal-gh"] = "tamirdresher account available"
} else {
    # Fallback: check default config dir
    try {
        $savedDir = $env:GH_CONFIG_DIR
        $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
        $ghStatusAll = gh auth status 2>&1 | Out-String
        $env:GH_CONFIG_DIR = $savedDir
        if ($ghStatusAll -match "tamirdresher[^_]") {
            $capabilities.Add("personal-gh")
            $details["personal-gh"] = "tamirdresher account available (default config)"
        } else {
            $missing.Add("personal-gh")
        }
    } catch {
        $missing.Add("personal-gh")
    }
}

# Check for EMU GitHub account
$ghStatusEmu = $null
try {
    $savedDir = $env:GH_CONFIG_DIR
    $env:GH_CONFIG_DIR = "$HOME\.config\gh-emu"
    $ghStatusEmu = gh auth status 2>&1 | Out-String
    $env:GH_CONFIG_DIR = $savedDir
} catch {}

if ($ghStatusEmu -match "tamirdresher_microsoft") {
    $capabilities.Add("emu-gh")
    $details["emu-gh"] = "tamirdresher_microsoft EMU account available"
} else {
    try {
        $savedDir = $env:GH_CONFIG_DIR
        $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
        $ghStatusAll = gh auth status 2>&1 | Out-String
        $env:GH_CONFIG_DIR = $savedDir
        if ($ghStatusAll -match "tamirdresher_microsoft") {
            $capabilities.Add("emu-gh")
            $details["emu-gh"] = "tamirdresher_microsoft EMU account available (default config)"
        } else {
            $missing.Add("emu-gh")
        }
    } catch {
        $missing.Add("emu-gh")
    }
}

# ── 2. Playwright / browser ─────────────────────────────────────────────────
Write-Host "[discover] Checking Playwright/browser..." -ForegroundColor Cyan

$playwrightAvailable = $false
# Check for npx playwright
try {
    $pwVersion = npx playwright --version 2>&1 | Out-String
    if ($pwVersion -match '\d+\.\d+') { $playwrightAvailable = $true }
} catch {}

# Check for playwright-cli in PATH
if (-not $playwrightAvailable) {
    $pwCli = Get-Command playwright -ErrorAction SilentlyContinue
    if ($pwCli) { $playwrightAvailable = $true }
}

# Check for Playwright node_modules in common locations
if (-not $playwrightAvailable) {
    $searchDirs = @("$env:USERPROFILE\tamresearch1", "$env:USERPROFILE", ".")
    foreach ($dir in $searchDirs) {
        if (Test-Path (Join-Path $dir "node_modules\playwright")) {
            $playwrightAvailable = $true
            break
        }
    }
}

if ($playwrightAvailable) {
    $capabilities.Add("browser")
    $details["browser"] = "Playwright available"
} else {
    $missing.Add("browser")
}

# ── 3. WhatsApp Web session ──────────────────────────────────────────────────
Write-Host "[discover] Checking WhatsApp state files..." -ForegroundColor Cyan

$whatsappAvailable = $false
$searchPaths = @(
    "$env:USERPROFILE\tamresearch1\whatsapp-state.yaml",
    "$env:USERPROFILE\tamresearch1\whatsapp-qr.png",
    "$env:APPDATA\playwright\whatsapp-auth"
)
foreach ($p in $searchPaths) {
    if (Test-Path $p) { $whatsappAvailable = $true; break }
}

# Also check if any whatsapp state files exist in current repo
$whatsappFiles = Get-ChildItem -Path . -Filter "whatsapp-state*" -ErrorAction SilentlyContinue
if ($whatsappFiles) { $whatsappAvailable = $true }

if ($whatsappAvailable) {
    $capabilities.Add("whatsapp")
    $details["whatsapp"] = "WhatsApp state files found"
} else {
    $missing.Add("whatsapp")
}

# ── 4. GPU (nvidia-smi) ─────────────────────────────────────────────────────
Write-Host "[discover] Checking GPU availability..." -ForegroundColor Cyan

$gpuAvailable = $false
try {
    $nvidiaSmi = nvidia-smi --query-gpu=name --format=csv,noheader 2>&1 | Out-String
    if ($nvidiaSmi -and $nvidiaSmi -notmatch "not recognized|not found|FAILED" -and $nvidiaSmi.Trim().Length -gt 0) {
        $gpuAvailable = $true
        $details["gpu"] = "GPU: $($nvidiaSmi.Trim())"
    }
} catch {}

if ($gpuAvailable) {
    $capabilities.Add("gpu")
} else {
    $missing.Add("gpu")
}

# ── 5. OneDrive folders ─────────────────────────────────────────────────────
Write-Host "[discover] Checking OneDrive..." -ForegroundColor Cyan

$onedrivePaths = Get-ChildItem -Path $env:USERPROFILE -Filter "OneDrive*" -Directory -ErrorAction SilentlyContinue
if ($onedrivePaths -and $onedrivePaths.Count -gt 0) {
    $capabilities.Add("onedrive")
    $details["onedrive"] = "OneDrive folders: $($onedrivePaths.Name -join ', ')"
} else {
    $missing.Add("onedrive")
}

# ── 6. Azure Speech SDK ─────────────────────────────────────────────────────
Write-Host "[discover] Checking Azure Speech SDK..." -ForegroundColor Cyan

$azureSpeechAvailable = $false

# Check pip package
try {
    $pipShow = pip show azure-cognitiveservices-speech 2>&1 | Out-String
    if ($pipShow -match "Version:") { $azureSpeechAvailable = $true }
} catch {}

# Check environment variables
if (-not $azureSpeechAvailable) {
    if ($env:SPEECH_KEY -or $env:AZURE_SPEECH_KEY -or $env:SPEECH_REGION) {
        $azureSpeechAvailable = $true
    }
}

if ($azureSpeechAvailable) {
    $capabilities.Add("azure-speech")
    $details["azure-speech"] = "Azure Speech SDK available"
} else {
    $missing.Add("azure-speech")
}

# ── 7. Teams MCP tools ──────────────────────────────────────────────────────
Write-Host "[discover] Checking Teams MCP availability..." -ForegroundColor Cyan

$teamsMcpAvailable = $false

# Check if agency / MCP processes are running that include Teams
$agencyProcs = Get-Process -Name "agency" -ErrorAction SilentlyContinue
if ($agencyProcs) { $teamsMcpAvailable = $true }

# Check for MCP config with Teams tools
$mcpConfigs = @(
    "$env:APPDATA\GitHub CLI\mcp-config.json",
    "$env:USERPROFILE\.copilot\mcp-config.json",
    "$env:USERPROFILE\.config\gh-emu\mcp-config.json"
)
foreach ($cfg in $mcpConfigs) {
    if (Test-Path $cfg) {
        try {
            $content = Get-Content $cfg -Raw
            if ($content -match "teams" -or $content -match "workiq") {
                $teamsMcpAvailable = $true
                break
            }
        } catch {}
    }
}

if ($teamsMcpAvailable) {
    $capabilities.Add("teams-mcp")
    $details["teams-mcp"] = "Teams MCP tools available"
} else {
    $missing.Add("teams-mcp")
}

# ── Build & write manifest ──────────────────────────────────────────────────
$squadDir = Join-Path $env:USERPROFILE ".squad"
if (-not (Test-Path $squadDir)) {
    New-Item -Path $squadDir -ItemType Directory -Force | Out-Null
}

$manifest = [ordered]@{
    machine      = $env:COMPUTERNAME
    capabilities = @($capabilities)
    missing      = @($missing)
    details      = $details
    last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
}

$outputPath = Join-Path $squadDir "machine-capabilities.json"
$manifest | ConvertTo-Json -Depth 3 | Out-File -FilePath $outputPath -Encoding utf8 -Force

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "[discover] Machine capability scan complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Machine:      $($manifest.machine)"
Write-Host "  Capabilities: $($capabilities -join ', ')" -ForegroundColor Green
Write-Host "  Missing:      $($missing -join ', ')" -ForegroundColor Yellow
Write-Host "  Manifest:     $outputPath"
Write-Host ""

# Return the manifest for callers that capture output
$manifest
