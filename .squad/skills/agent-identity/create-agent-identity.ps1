#!/usr/bin/env pwsh
# Squad Agent Identity Blueprint Creator
# Run this script in a VISIBLE terminal window — it opens a browser for auth.
#
# Prerequisites:
#   Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
#   Install-Module MSIdentityTools -Scope CurrentUser -Force
#
# Usage:
#   pwsh -File create-agent-identity.ps1

param(
    [string]$TenantId = "72f988bf-86f1-41af-91ab-2d7cd011db47",
    [string]$BlueprintName = "Squad Agent Blueprint",
    [string]$SponsorUserId = "fa18be61-fb41-4500-b142-bfdabb1baf1a"  # Tamir Dresher
)

$ErrorActionPreference = "Stop"
Import-Module Microsoft.Graph.Authentication -Force

Write-Host "`n=== Squad Agent Identity Blueprint Creator ===" -ForegroundColor Cyan
Write-Host "This script creates an Entra Agent Identity Blueprint for Squad agents.`n"

# Step 1: Authenticate with the right scopes (NO Directory.AccessAsUser.All!)
Write-Host "[1/5] Authenticating to Microsoft Graph..." -ForegroundColor Yellow
Write-Host "  A browser window will open — sign in with your Microsoft account.`n"

Connect-MgGraph -Scopes @(
    "AgentIdentityBlueprint.Create",
    "AgentIdentityBlueprintPrincipal.Create",
    "AppRoleAssignment.ReadWrite.All",
    "Application.ReadWrite.All",
    "User.ReadWrite.All"
) -TenantId $TenantId -NoWelcome

$ctx = Get-MgContext
if (-not $ctx) { throw "Failed to connect to Graph" }
Write-Host "  Connected as: $($ctx.Account)" -ForegroundColor Green

# Step 2: Create the Blueprint
Write-Host "`n[2/5] Creating Agent Identity Blueprint: $BlueprintName" -ForegroundColor Yellow

$body = @{
    displayName = $BlueprintName
    serviceManagementReference = "caa72385-03f7-4120-a02f-611c40d6d140"
    "sponsors@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$SponsorUserId")
    "owners@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$SponsorUserId")
} | ConvertTo-Json -Depth 5

$blueprint = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/applications/graph.agentIdentityBlueprint" `
    -Body $body -ContentType "application/json" -OutputType PSObject

$blueprintAppId = $blueprint.appId
$blueprintObjectId = $blueprint.id
Write-Host "  Blueprint created!" -ForegroundColor Green
Write-Host "  App ID: $blueprintAppId"
Write-Host "  Object ID: $blueprintObjectId"

# Step 3: Create Service Principal for the Blueprint
Write-Host "`n[3/5] Creating Blueprint Service Principal..." -ForegroundColor Yellow

$spBody = @{ appId = $blueprintAppId } | ConvertTo-Json
$sp = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/servicePrincipals/graph.agentIdentityBlueprintPrincipal" `
    -Body $spBody -ContentType "application/json" -OutputType PSObject

Write-Host "  Service Principal created: $($sp.id)" -ForegroundColor Green

# Step 4: Add Client Secret
Write-Host "`n[4/5] Adding client secret to Blueprint..." -ForegroundColor Yellow

$secretBody = @{
    passwordCredential = @{
        displayName = "squad-blueprint-secret"
        endDateTime = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
} | ConvertTo-Json -Depth 5

$secret = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/v1.0/applications/$blueprintObjectId/addPassword" `
    -Body $secretBody -ContentType "application/json" -OutputType PSObject

Write-Host "  Secret created (save this!):" -ForegroundColor Green
Write-Host "  Secret Value: $($secret.secretText)" -ForegroundColor Red
Write-Host "  Secret ID: $($secret.keyId)"
Write-Host "  Expires: $($secret.endDateTime)"

# Step 5: Create first Agent Identity
Write-Host "`n[5/5] Creating first agent identity: squad-picard" -ForegroundColor Yellow

$agentBody = @{
    displayName = "squad-picard"
    "sponsors@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$SponsorUserId")
} | ConvertTo-Json -Depth 5

try {
    $agent = Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/beta/applications/$blueprintObjectId/graph.agentIdentityBlueprint/agentIdentities" `
        -Body $agentBody -ContentType "application/json" -OutputType PSObject
    Write-Host "  Agent Identity created!" -ForegroundColor Green
    Write-Host "  Agent App ID: $($agent.appId)"
    Write-Host "  Agent Object ID: $($agent.id)"
} catch {
    Write-Host "  Agent creation failed (may need different API path): $($_.Exception.Message)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Blueprint App ID:     $blueprintAppId"
Write-Host "Blueprint Object ID:  $blueprintObjectId"
Write-Host "Service Principal ID: $($sp.id)"
Write-Host "Client Secret:        $($secret.secretText)" -ForegroundColor Red
Write-Host "`nSave these values! Store the secret in Windows Credential Manager:"
Write-Host "  cmdkey /generic:SQUAD_BLUEPRINT_SECRET /user:$blueprintAppId /pass:`"$($secret.secretText)`""

# Save to file
$outputFile = "$PSScriptRoot\agent-identity-output.json"
@{
    blueprintAppId = $blueprintAppId
    blueprintObjectId = $blueprintObjectId
    servicePrincipalId = $sp.id
    tenantId = $TenantId
    sponsorUserId = $SponsorUserId
    createdAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
} | ConvertTo-Json | Set-Content $outputFile
Write-Host "`nOutput saved to: $outputFile" -ForegroundColor Gray
Write-Host "`nDone! You can close this window." -ForegroundColor Green