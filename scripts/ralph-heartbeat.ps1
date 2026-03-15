<#
.SYNOPSIS
    Writes a Ralph heartbeat file for cross-machine monitoring.

.DESCRIPTION
    Writes a JSON heartbeat to ~/.squad/heartbeats/{COMPUTERNAME}.json
    so the Telegram bot /status command can show all active Ralphs.

    Designed to be called periodically by Ralph during each round.
    Heartbeats older than 10 minutes are considered stale by the bot.

.PARAMETER Round
    The current Ralph round number.

.PARAMETER Status
    Current status: idle, running, error. Defaults to "running".

.PARAMETER Repo
    Repository path Ralph is working in. Defaults to current directory.

.PARAMETER Failures
    Number of recent failures. Defaults to 0.

.EXAMPLE
    # Called by Ralph each round:
    .\scripts\ralph-heartbeat.ps1 -Round 5 -Status running

    # Mark idle:
    .\scripts\ralph-heartbeat.ps1 -Round 5 -Status idle
#>

param(
    [Parameter(Mandatory = $false)]
    [int]$Round = 0,

    [Parameter(Mandatory = $false)]
    [ValidateSet("idle", "running", "error")]
    [string]$Status = "running",

    [Parameter(Mandatory = $false)]
    [string]$Repo = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [int]$Failures = 0
)

$heartbeatDir = Join-Path $HOME ".squad" "heartbeats"
if (-not (Test-Path $heartbeatDir)) {
    New-Item -ItemType Directory -Path $heartbeatDir -Force | Out-Null
}

$machineName = $env:COMPUTERNAME
if (-not $machineName) { $machineName = hostname }

$heartbeat = @{
    machine       = $machineName
    repo          = $Repo
    round         = $Round
    last_activity = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    status        = $Status
    failures      = $Failures
}

$filePath = Join-Path $heartbeatDir "$machineName.json"
$heartbeat | ConvertTo-Json -Depth 3 | Set-Content -Path $filePath -Encoding UTF8

Write-Host "Heartbeat written: $filePath (round $Round, status $Status)"
