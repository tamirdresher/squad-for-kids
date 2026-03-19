<#
.SYNOPSIS
    Bitwarden Squad Setup — Run this script yourself to grant AI access.
    
.DESCRIPTION
    This script:
    1. Logs into Bitwarden with your API key (no master password in AI terminal)
    2. Unlocks your vault (you type master password HERE, privately)
    3. Creates a "Squad Secrets" folder for AI-only access
    4. Exports the session key for the MCP server to use
    
    The AI ONLY sees items in the "Squad Secrets" folder.
    Your personal passwords are never accessible.

.NOTES
    Run this in YOUR OWN terminal — not through the AI.
    
    Prerequisites:
    1. Go to vault.bitwarden.com → Settings → Security → Keys → View API Key
    2. Copy your client_id and client_secret
    3. Run this script
#>

param(
    [switch]$SkipLogin
)

$ErrorActionPreference = "Stop"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Bitwarden Squad Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script grants your AI squad access to a" -ForegroundColor White
Write-Host "DEDICATED FOLDER in your Bitwarden vault." -ForegroundColor Yellow
Write-Host "Your personal passwords are NEVER accessible." -ForegroundColor Green
Write-Host ""

# Step 1: Login with API key
if (-not $SkipLogin) {
    Write-Host "Step 1: API Key Login" -ForegroundColor Cyan
    Write-Host "  Get your API key from: vault.bitwarden.com → Settings → Security → Keys" -ForegroundColor Gray
    Write-Host ""
    
    $clientId = Read-Host "  Enter client_id"
    $clientSecret = Read-Host "  Enter client_secret" -AsSecureString
    $clientSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($clientSecret)
    )
    
    $env:BW_CLIENTID = $clientId
    $env:BW_CLIENTSECRET = $clientSecretPlain
    
    Write-Host "  Logging in..." -ForegroundColor Yellow
    $loginResult = bw login --apikey 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Login failed: $loginResult" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ Logged in successfully" -ForegroundColor Green
    
    # Clear secrets from memory
    $env:BW_CLIENTSECRET = $null
    $clientSecretPlain = $null
}

# Step 2: Unlock vault
Write-Host ""
Write-Host "Step 2: Unlock Vault" -ForegroundColor Cyan
Write-Host "  Type your MASTER PASSWORD below." -ForegroundColor Yellow
Write-Host "  (This stays in THIS terminal only — the AI never sees it)" -ForegroundColor Gray
Write-Host ""

$session = bw unlock --raw 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Unlock failed: $session" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Vault unlocked" -ForegroundColor Green

# Set session for this process and child processes
$env:BW_SESSION = $session

# Step 3: Create Squad folder if it doesn't exist
Write-Host ""
Write-Host "Step 3: Setting up Squad folder..." -ForegroundColor Cyan

$folders = bw list folders --session $session 2>&1 | ConvertFrom-Json
$squadFolder = $folders | Where-Object { $_.name -eq "Squad Secrets" }

if (-not $squadFolder) {
    $folderJson = @{ name = "Squad Secrets" } | ConvertTo-Json
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($folderJson))
    $result = bw create folder $encoded --session $session 2>&1
    $squadFolder = $result | ConvertFrom-Json
    Write-Host "  ✅ Created 'Squad Secrets' folder (ID: $($squadFolder.id))" -ForegroundColor Green
} else {
    Write-Host "  ✅ 'Squad Secrets' folder exists (ID: $($squadFolder.id))" -ForegroundColor Green
}

# Step 4: Save config for MCP server
$configPath = Join-Path $env:USERPROFILE ".squad"
if (-not (Test-Path $configPath)) { New-Item -ItemType Directory -Path $configPath -Force | Out-Null }

$config = @{
    session = $session
    folderId = $squadFolder.id
    folderName = "Squad Secrets"
    setupDate = (Get-Date -Format "o")
    note = "Session key for Bitwarden MCP server. Re-run setup-bitwarden.ps1 to refresh."
} | ConvertTo-Json

$configFile = Join-Path $configPath "bitwarden-session.json"
Set-Content -Path $configFile -Value $config -Encoding UTF8
Write-Host ""
Write-Host "  ✅ Session config saved to: $configFile" -ForegroundColor Green

# Step 5: Set machine-wide env var for MCP server
[System.Environment]::SetEnvironmentVariable("BW_SESSION", $session, "User")
[System.Environment]::SetEnvironmentVariable("BW_SQUAD_FOLDER_ID", $squadFolder.id, "User")
Write-Host "  ✅ BW_SESSION and BW_SQUAD_FOLDER_ID set as user env vars" -ForegroundColor Green

# Step 6: Create a test item to verify
Write-Host ""
Write-Host "Step 4: Verification test..." -ForegroundColor Cyan

$testItem = @{
    type = 1
    name = "squad/setup-verification"
    folderId = $squadFolder.id
    notes = "Test item created during setup. Safe to delete.`nCreated: $(Get-Date -Format 'o')"
    login = @{
        username = "setup-test"
        password = "setup-verification-$(Get-Random -Maximum 9999)"
    }
} | ConvertTo-Json -Depth 5
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($testItem))
$createResult = bw create item $encoded --session $session 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Test item 'squad/setup-verification' created in Squad Secrets folder" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Test item creation failed (non-critical): $createResult" -ForegroundColor Yellow
}

# Done
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Your AI squad can now store and retrieve secrets" -ForegroundColor White
Write-Host "  in the 'Squad Secrets' folder ONLY." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Folder ID: $($squadFolder.id)" -ForegroundColor Gray
Write-Host "  Session expires when you lock the vault." -ForegroundColor Gray
Write-Host "  Re-run this script to refresh the session." -ForegroundColor Gray
Write-Host ""
Write-Host "  Go back to your AI session and say:" -ForegroundColor White
Write-Host '  "Bitwarden is set up, test it"' -ForegroundColor Cyan
Write-Host ""
