<#
.SYNOPSIS
    Bitwarden Squad Collection Setup — creates shadow access collections for squad agents.

.DESCRIPTION
    Sets up the Bitwarden multi-collection shadow access architecture described in
    docs/bitwarden-shadow-access.md (issue #1057).

    Creates and configures:
    - "Squad Ops" collection   → squad agents get READ-ONLY access
    - "Squad Secrets" collection → squad agents get READ/WRITE access

    Shows the manifest of items that should be shadowed to Squad Ops.
    Optionally shadows items interactively.

.PARAMETER SkipLogin
    Skip login (already authenticated via bw login --apikey)

.PARAMETER OrgId
    Bitwarden Organization ID (from vault.bitwarden.com > Org > Settings)

.PARAMETER ListItemsOnly
    Print the items-to-shadow manifest without making changes

.PARAMETER ShadowItems
    Interactively shadow items to the Squad Ops collection after setup

.EXAMPLE
    # Full setup:
    .\setup-bitwarden-squad-collection.ps1

    # Just list what needs to be shadowed:
    .\setup-bitwarden-squad-collection.ps1 -ListItemsOnly

    # Full setup + shadow items interactively:
    .\setup-bitwarden-squad-collection.ps1 -ShadowItems

.NOTES
    Run this in YOUR OWN terminal — not through the AI.

    Prerequisites:
    1. Bitwarden CLI:  winget install Bitwarden.CLI
    2. Bitwarden Organization "TAM Research" created at vault.bitwarden.com
    3. Your personal API key from:
       vault.bitwarden.com > Settings > Security > Keys > View API Key
#>

param(
    [switch]$SkipLogin,
    [string]$OrgId,
    [switch]$ListItemsOnly,
    [switch]$ShadowItems
)

$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────────────────────────────────────
# Shadow manifest — items that SHOULD be in Squad Ops
# Update this as new integrations are added
# ─────────────────────────────────────────────────────────────────────────────
$SHADOW_MANIFEST = @(
    [PSCustomObject]@{
        Pattern  = "GitHub PAT"
        Type     = "Login"
        Priority = "CRITICAL"
        Why      = "Create PRs, push commits, manage issues, label/triage"
    }
    [PSCustomObject]@{
        Pattern  = "Webhook - GitHub"
        Type     = "Secure Note"
        Priority = "HIGH"
        Why      = "Validate inbound GitHub webhook payloads"
    }
    [PSCustomObject]@{
        Pattern  = "Azure SP"
        Type     = "Login"
        Priority = "HIGH"
        Why      = "Deploy to Azure, manage resources"
    }
    [PSCustomObject]@{
        Pattern  = "OpenAI API Key"
        Type     = "Secure Note"
        Priority = "HIGH"
        Why      = "AI content generation: podcasts, blogs, summaries"
    }
    [PSCustomObject]@{
        Pattern  = "Teams Webhook"
        Type     = "Secure Note"
        Priority = "MEDIUM"
        Why      = "Post agent notifications to Teams channels"
    }
    [PSCustomObject]@{
        Pattern  = "Gumroad"
        Type     = "Login"
        Priority = "MEDIUM"
        Why      = "Revenue tracking, product management"
    }
    [PSCustomObject]@{
        Pattern  = "DevBox"
        Type     = "Secure Note"
        Priority = "LOW"
        Why      = "Provision and manage dev boxes"
    }
    [PSCustomObject]@{
        Pattern  = "YouTube API"
        Type     = "Secure Note"
        Priority = "MEDIUM"
        Why      = "Upload videos, manage channel via API"
    }
)

$NEVER_SHADOW = @(
    "Banking, credit cards, financial accounts"
    "Personal email (Gmail, Outlook personal)"
    "Medical / health portals"
    "Government / identity documents"
    "Vault master password, recovery codes"
    "Family / personal logins unrelated to TAM Research"
)

# ─────────────────────────────────────────────────────────────────────────────
# Banner
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Bitwarden Squad Collection Setup  (Issue #1057)           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Architecture: multi-collection shadow access" -ForegroundColor White
Write-Host "  Squad Ops     → agents get READ-ONLY access" -ForegroundColor Yellow
Write-Host "  Squad Secrets → agents get READ/WRITE access" -ForegroundColor Yellow
Write-Host "  One copy, two views — no duplication" -ForegroundColor Green
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# ListItemsOnly mode
# ─────────────────────────────────────────────────────────────────────────────
if ($ListItemsOnly) {
    Write-Host "Items to SHADOW to Squad Ops (agents need read access):" -ForegroundColor Cyan
    Write-Host ""
    foreach ($item in $SHADOW_MANIFEST) {
        $c = switch ($item.Priority) { "CRITICAL"{"Red"} "HIGH"{"Yellow"} "MEDIUM"{"White"} default{"Gray"} }
        Write-Host ("  [{0,-8}] {1} ({2})" -f $item.Priority, $item.Pattern, $item.Type) -ForegroundColor $c
        Write-Host "             $($item.Why)" -ForegroundColor Gray
        Write-Host ""
    }
    Write-Host "NEVER shadow these:" -ForegroundColor Red
    foreach ($item in $NEVER_SHADOW) { Write-Host "  x  $item" -ForegroundColor Red }
    Write-Host ""
    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Prerequisites check
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Checking prerequisites..." -ForegroundColor Cyan
if (-not (Get-Command bw -ErrorAction SilentlyContinue)) {
    Write-Host "  Bitwarden CLI not found." -ForegroundColor Red
    Write-Host "  Install: winget install Bitwarden.CLI" -ForegroundColor Yellow
    exit 1
}
$bwVer = bw --version 2>&1
Write-Host "  OK: bw $bwVer" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Login
# ─────────────────────────────────────────────────────────────────────────────
if (-not $SkipLogin) {
    Write-Host ""
    Write-Host "Step 1: API Key Login" -ForegroundColor Cyan
    Write-Host "  Get your key from: vault.bitwarden.com > Settings > Security > Keys" -ForegroundColor Gray
    Write-Host ""
    $env:BW_CLIENTID = Read-Host "  client_id"
    $ss = Read-Host "  client_secret" -AsSecureString
    $env:BW_CLIENTSECRET = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss))
    $result = bw login --apikey 2>&1
    if ($LASTEXITCODE -ne 0 -and $result -notmatch "already logged in") {
        Write-Host "  Login failed: $result" -ForegroundColor Red; exit 1
    }
    $env:BW_CLIENTSECRET = $null
    Write-Host "  OK: logged in" -ForegroundColor Green
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Unlock vault
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 2: Unlock Vault" -ForegroundColor Cyan
Write-Host "  Enter your MASTER PASSWORD below." -ForegroundColor Yellow
Write-Host "  (Stays in THIS terminal — AI never sees it)" -ForegroundColor Gray
Write-Host ""
$session = bw unlock --raw 2>&1
if ($LASTEXITCODE -ne 0) { Write-Host "  Unlock failed: $session" -ForegroundColor Red; exit 1 }
$env:BW_SESSION = $session
Write-Host "  OK: vault unlocked" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Find organization
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 3: Find Organization" -ForegroundColor Cyan
$orgs = bw list organizations --session $session 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $orgs) { $orgs = @() }

if ($orgs.Count -eq 0) {
    Write-Host "  No organizations found." -ForegroundColor Yellow
    Write-Host "  Create 'TAM Research' at vault.bitwarden.com > New Organization" -ForegroundColor Gray
    if (-not $OrgId) { $OrgId = Read-Host "  Enter Organization ID manually" }
    $selectedOrg = [PSCustomObject]@{ id = $OrgId; name = "TAM Research" }
} elseif ($orgs.Count -eq 1) {
    $selectedOrg = $orgs[0]
    Write-Host "  Using: $($selectedOrg.name) ($($selectedOrg.id))" -ForegroundColor Green
} else {
    for ($i = 0; $i -lt $orgs.Count; $i++) {
        Write-Host "  [$($i+1)] $($orgs[$i].name) ($($orgs[$i].id))"
    }
    $sel = [int](Read-Host "  Select organization number") - 1
    $selectedOrg = $orgs[$sel]
    Write-Host "  Selected: $($selectedOrg.name)" -ForegroundColor Green
}
$orgId = $selectedOrg.id

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Check existing collections
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 4: Collections" -ForegroundColor Cyan
$cols = bw list org-collections --organizationid $orgId --session $session 2>&1 |
        ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $cols) { $cols = @() }

$required = @("Tamir Admin", "Squad Ops", "Squad Secrets")
$colMap   = @{}

foreach ($name in $required) {
    $existing = $cols | Where-Object { $_.name -eq $name }
    if ($existing) {
        $colMap[$name] = $existing.id
        Write-Host ("  OK: '{0}' ({1})" -f $name, $existing.id) -ForegroundColor Green
    } else {
        Write-Host ("  Missing: '{0}'" -f $name) -ForegroundColor Red
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: Guide creation of missing collections
# ─────────────────────────────────────────────────────────────────────────────
$missing = $required | Where-Object { -not $colMap.ContainsKey($_) }
if ($missing.Count -gt 0) {
    Write-Host ""
    Write-Host "  The Bitwarden CLI cannot create org collections directly." -ForegroundColor Yellow
    Write-Host "  Please create these at:" -ForegroundColor White
    Write-Host "  vault.bitwarden.com > Organization > Collections > New Collection" -ForegroundColor Gray
    Write-Host ""
    foreach ($m in $missing) {
        Write-Host "    > $m" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Permissions to set:" -ForegroundColor White
    Write-Host "  'Tamir Admin'   — your account: Can Manage" -ForegroundColor Gray
    Write-Host "  'Squad Ops'     — your account: Can Manage" -ForegroundColor Gray
    Write-Host "  'Squad Secrets' — your account: Can Manage" -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Press ENTER when done"

    # Re-fetch
    $cols = bw list org-collections --organizationid $orgId --session $session 2>&1 |
            ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $cols) { $cols = @() }
    foreach ($name in $required) {
        $existing = $cols | Where-Object { $_.name -eq $name }
        if ($existing) {
            $colMap[$name] = $existing.id
            Write-Host ("  OK: '{0}' ({1})" -f $name, $existing.id) -ForegroundColor Green
        } else {
            Write-Host ("  Still missing: '{0}' — add later" -f $name) -ForegroundColor Yellow
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 6: Service account guidance
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 5: Service Accounts (requires web UI)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Go to: vault.bitwarden.com > Organization > Service Accounts" -ForegroundColor White
Write-Host ""
Write-Host "  [1] squad-ops-readonly" -ForegroundColor Cyan
Write-Host "      Collection : Squad Ops" -ForegroundColor Gray
Write-Host "      Permission : Read-Only" -ForegroundColor Gray
Write-Host "      Env vars   : BW_SQUAD_OPS_CLIENT_ID" -ForegroundColor Gray
Write-Host "                   BW_SQUAD_OPS_CLIENT_SECRET" -ForegroundColor Gray
Write-Host ""
Write-Host "  [2] squad-secrets-readwrite" -ForegroundColor Cyan
Write-Host "      Collection : Squad Secrets" -ForegroundColor Gray
Write-Host "      Permission : Read/Write" -ForegroundColor Gray
Write-Host "      Env vars   : BW_SQUAD_SECRETS_CLIENT_ID" -ForegroundColor Gray
Write-Host "                   BW_SQUAD_SECRETS_CLIENT_SECRET" -ForegroundColor Gray
Write-Host ""
Write-Host "  NOTE: Service Accounts require Bitwarden Secrets Manager (business plan)." -ForegroundColor Yellow
Write-Host "  On free plan: use Organization API key (broader — for testing only)." -ForegroundColor Gray

# ─────────────────────────────────────────────────────────────────────────────
# Step 7: Print items to shadow
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Step 6: Items to Shadow to Squad Ops" -ForegroundColor Cyan
Write-Host ""
foreach ($item in $SHADOW_MANIFEST) {
    $c = switch ($item.Priority) { "CRITICAL"{"Red"} "HIGH"{"Yellow"} "MEDIUM"{"White"} default{"Gray"} }
    Write-Host ("  [{0,-8}] {1} ({2})" -f $item.Priority, $item.Pattern, $item.Type) -ForegroundColor $c
    Write-Host "             $($item.Why)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "  NEVER shadow:" -ForegroundColor Red
foreach ($item in $NEVER_SHADOW) { Write-Host "    x  $item" -ForegroundColor Red }

# ─────────────────────────────────────────────────────────────────────────────
# Step 8: Interactive shadow (optional)
# ─────────────────────────────────────────────────────────────────────────────
if ($ShadowItems -and $colMap.ContainsKey("Squad Ops")) {
    Write-Host ""
    Write-Host "Step 7: Shadow Items Interactively" -ForegroundColor Cyan
    $squadOpsId = $colMap["Squad Ops"]

    foreach ($manifest in $SHADOW_MANIFEST) {
        Write-Host ""
        Write-Host "  Searching: '$($manifest.Pattern)'..." -ForegroundColor White

        $items = bw list items --search $manifest.Pattern --organizationid $orgId --session $session 2>&1 |
                 ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $items) { $items = @() }

        if ($items.Count -eq 0) {
            Write-Host "  Not found in org vault — ensure item is moved from personal vault first" -ForegroundColor Yellow
            continue
        }

        foreach ($bwItem in $items) {
            if ($bwItem.collectionIds -contains $squadOpsId) {
                Write-Host "  Already shadowed: $($bwItem.name)" -ForegroundColor Green
                continue
            }
            if (-not $bwItem.organizationId) {
                Write-Host ("  '{0}' is in personal vault — move to org first:" -f $bwItem.name) -ForegroundColor Yellow
                Write-Host "  vault.bitwarden.com > item > Edit > Organization > TAM Research" -ForegroundColor Gray
                continue
            }
            $confirm = Read-Host "  Shadow '$($bwItem.name)' to Squad Ops? [y/N]"
            if ($confirm -in "y","Y") {
                $r = bw share $bwItem.id $orgId $squadOpsId --session $session 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  Shadowed: $($bwItem.name)" -ForegroundColor Green
                } else {
                    Write-Host "  CLI shadow failed: $r" -ForegroundColor Yellow
                    Write-Host "  Manual: item > Edit > Collections > Add 'Squad Ops'" -ForegroundColor Gray
                }
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Save configuration
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Saving configuration..." -ForegroundColor Cyan

$configDir = Join-Path $env:USERPROFILE ".squad"
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }

@{
    bitwarden = @{
        orgId       = $orgId
        orgName     = $selectedOrg.name
        setupDate   = (Get-Date -Format "o")
        collections = $colMap
        note        = "Re-run setup-bitwarden-squad-collection.ps1 to refresh session"
    }
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $configDir "bitwarden-squad-config.json") -Encoding UTF8

Write-Host "  Config saved: $configDir\bitwarden-squad-config.json" -ForegroundColor Green

[System.Environment]::SetEnvironmentVariable("BW_SESSION",                    $session,           "User")
[System.Environment]::SetEnvironmentVariable("BW_ORG_ID",                     $orgId,             "User")
if ($colMap["Squad Ops"])     { [System.Environment]::SetEnvironmentVariable("BW_SQUAD_OPS_COLLECTION_ID",      $colMap["Squad Ops"],     "User") }
if ($colMap["Squad Secrets"]) { [System.Environment]::SetEnvironmentVariable("BW_SQUAD_SECRETS_COLLECTION_ID",  $colMap["Squad Secrets"], "User") }

Write-Host "  Env vars set: BW_SESSION, BW_ORG_ID, BW_SQUAD_OPS_COLLECTION_ID, BW_SQUAD_SECRETS_COLLECTION_ID" -ForegroundColor Green

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Setup Complete!                                             ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Organization : $($selectedOrg.name) ($orgId)" -ForegroundColor White
foreach ($col in $colMap.GetEnumerator()) {
    Write-Host ("  Collection   : '{0}' = {1}" -f $col.Key, $col.Value) -ForegroundColor Gray
}
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. Create service accounts (Step 5 instructions above)" -ForegroundColor Yellow
Write-Host "  2. Set BW_SQUAD_OPS_CLIENT_ID / BW_SQUAD_OPS_CLIENT_SECRET" -ForegroundColor Yellow
Write-Host "  3. Shadow items: re-run with -ShadowItems, or use shadow_item MCP tool (#1058)" -ForegroundColor Yellow
Write-Host "  4. Build bitwarden-shadow MCP server: mcp-servers/bitwarden-shadow/" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Design doc : docs/bitwarden-shadow-access.md" -ForegroundColor Cyan
Write-Host "  Issue #1057: https://github.com/tamirdresher_microsoft/tamresearch1/issues/1057" -ForegroundColor Cyan
Write-Host "  Issue #1058: https://github.com/tamirdresher_microsoft/tamresearch1/issues/1058" -ForegroundColor Cyan
Write-Host ""
