# bootstrap-new-machine.ps1
# Run this on any new machine to get squad credentials for JellyBolt / tdsquadAI
# Prerequisites: gh CLI installed, authenticated as tamirdresher
#   gh auth login --hostname github.com

param([switch]$SetGitHubSecrets)

$GIST_ID = "754ebf2820b181b53bddf8372dccbe58"

Write-Host "Fetching squad credentials from private gist..."
$rawJson = gh gist view $GIST_ID --raw 2>&1 | Select-String -Pattern "^\s*$" -NotMatch | Out-String
# Skip the first line (description) and parse JSON
$lines = $rawJson -split "`n"
$jsonStart = ($lines | Select-String "^\{" -List | Select-Object -First 1).LineNumber - 1
$json = $lines[$jsonStart..($lines.Length-1)] -join "`n"
$creds = $json | ConvertFrom-Json

Write-Host "✅ Credentials loaded:"
Write-Host "   expo_username:  $($creds.expo_username)"
Write-Host "   expo_token:     expo_**** (hidden)"
Write-Host "   butler_api_key: butler_**** (hidden)"
Write-Host "   tdsquadai_pat:  ghp_**** (hidden)"

# Save to local squad credentials
$dir = "$env:USERPROFILE\.squad\credentials"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$creds | ConvertTo-Json | Set-Content "$dir\tdsquadAI.json"
Write-Host "✅ Saved to $dir\tdsquadAI.json"

if ($SetGitHubSecrets) {
    Write-Host ""
    Write-Host "Setting GitHub secrets for all repos..."
    foreach ($repo in @("tamirdresher/bounce-blitz","tamirdresher/idle-critter-farm","tamirdresher/brainrot-quiz-battle")) {
        echo $creds.expo_token      | gh secret set EXPO_TOKEN    --repo $repo
        echo $creds.butler_api_key  | gh secret set BUTLER_API_KEY --repo $repo
        Write-Host "  ✅ $repo"
    }
    $env:GH_TOKEN = $creds.tdsquadai_pat
    echo $creds.expo_token | gh secret set EXPO_TOKEN --repo tdsquadAI/brainrot-quiz-battle
    $env:GH_TOKEN = $null
    Write-Host "  ✅ tdsquadAI/brainrot-quiz-battle"
}

Write-Host ""
Write-Host "Done! Run with -SetGitHubSecrets to also set secrets in all repos."
