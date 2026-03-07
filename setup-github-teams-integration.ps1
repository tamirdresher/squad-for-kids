# GitHub Teams Integration Setup Script
# This script automates PART of the GitHub-Teams integration setup
# Some steps still require manual interaction due to OAuth security requirements

param(
    [Parameter(Mandatory=$false)]
    [string]$TeamName,
    
    [Parameter(Mandatory=$false)]
    [string]$ChannelName = "General"
)

Write-Host "=== GitHub Teams Integration Setup ===" -ForegroundColor Cyan
Write-Host ""

# GitHub app ID in Teams App Catalog (verified from Microsoft docs)
$githubAppId = "0d820ecd-def2-4297-adad-78056cde7c78"

# Step 1: Check if already authenticated
Write-Host "Checking Microsoft Graph authentication..." -ForegroundColor Yellow
$context = Get-MgContext
if (-not $context) {
    Write-Host "Not authenticated. Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Write-Host "Required scopes: Team.ReadBasic.All, TeamsAppInstallation.ReadWriteForTeam" -ForegroundColor Gray
    
    # Connect with required permissions
    Connect-MgGraph -Scopes "Team.ReadBasic.All", "TeamsAppInstallation.ReadWriteForTeam", "Channel.ReadBasic.All" -NoWelcome
    
    $context = Get-MgContext
    if (-not $context) {
        Write-Error "Failed to authenticate with Microsoft Graph"
        exit 1
    }
}

Write-Host "✓ Authenticated as: $($context.Account)" -ForegroundColor Green
Write-Host ""

# Step 2: List available teams if team not specified
if (-not $TeamName) {
    Write-Host "Available Teams:" -ForegroundColor Yellow
    $teams = Get-MgTeam
    $teams | ForEach-Object { 
        Write-Host "  - $($_.DisplayName) (ID: $($_.Id))" 
    }
    Write-Host ""
    
    $TeamName = Read-Host "Enter the Team name to configure"
}

# Step 3: Find the team
Write-Host "Finding team '$TeamName'..." -ForegroundColor Yellow
$team = Get-MgTeam -All | Where-Object { $_.DisplayName -eq $TeamName }

if (-not $team) {
    Write-Error "Team '$TeamName' not found"
    exit 1
}

Write-Host "✓ Found team: $($team.DisplayName) (ID: $($team.Id))" -ForegroundColor Green
Write-Host ""

# Step 4: Check if GitHub app is already installed
Write-Host "Checking if GitHub app is already installed..." -ForegroundColor Yellow
$installedApps = Get-MgTeamInstalledApp -TeamId $team.Id -ExpandProperty "teamsAppDefinition"

$githubInstalled = $installedApps | Where-Object { 
    $_.TeamsAppDefinition.TeamsAppId -eq $githubAppId 
}

if ($githubInstalled) {
    Write-Host "✓ GitHub app is already installed in this team" -ForegroundColor Green
    Write-Host "  Installation ID: $($githubInstalled.Id)" -ForegroundColor Gray
} else {
    Write-Host "GitHub app not found. Installing..." -ForegroundColor Yellow
    
    try {
        # Install GitHub app to the team
        $params = @{
            "TeamsApp@odata.bind" = "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps/$githubAppId"
        }
        
        $installation = New-MgTeamInstalledApp -TeamId $team.Id -BodyParameter $params
        Write-Host "✓ GitHub app installed successfully!" -ForegroundColor Green
        Write-Host "  Installation ID: $($installation.Id)" -ForegroundColor Gray
    } catch {
        Write-Error "Failed to install GitHub app: $_"
        Write-Host "This may require Teams admin permissions." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "=== AUTOMATED SETUP COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  MANUAL STEPS REQUIRED:" -ForegroundColor Yellow
Write-Host "The following steps require manual interaction in Microsoft Teams due to OAuth security requirements:" -ForegroundColor Gray
Write-Host ""
Write-Host "1. Open Microsoft Teams and go to team: '$($team.DisplayName)'" -ForegroundColor White
Write-Host "2. Navigate to channel: '$ChannelName'" -ForegroundColor White
Write-Host "3. Type: @GitHub signin" -ForegroundColor White
Write-Host "   - This will prompt you to authenticate with GitHub (OAuth flow)" -ForegroundColor Gray
Write-Host "   - Follow the prompts to link your GitHub account" -ForegroundColor Gray
Write-Host ""
Write-Host "4. After signing in, type: @GitHub subscribe tamirdresher_microsoft/tamresearch1" -ForegroundColor White
Write-Host "   - This subscribes the channel to notifications from your repository" -ForegroundColor Gray
Write-Host ""
Write-Host "5. (Optional) Configure notification preferences:" -ForegroundColor White
Write-Host "   - Type: @GitHub notifications on" -ForegroundColor Gray
Write-Host "   - Customize with: @GitHub unsubscribe <event-type> to reduce noise" -ForegroundColor Gray
Write-Host ""
Write-Host "⏱️  Estimated time for manual steps: < 2 minutes" -ForegroundColor Cyan
Write-Host ""
Write-Host "For more info: https://github.com/integrations/microsoft-teams" -ForegroundColor Gray
