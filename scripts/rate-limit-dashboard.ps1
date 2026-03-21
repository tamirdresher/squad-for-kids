#Requires -Version 7.0
<#
.SYNOPSIS
    Terminal dashboard for Squad rate-limit pool monitoring.

.DESCRIPTION
    Reads ~/.squad/rate-pool.json (maintained by rate-limit-manager.ps1) and
    renders a box-drawn terminal dashboard refreshed every N seconds.
    Also writes a JSON snapshot to .squad/monitoring/rate-limit-status.json
    on each refresh for programmatic consumers.

.PARAMETER RefreshSeconds
    Seconds between dashboard refreshes. Default: 10.

.PARAMETER PoolPath
    Path to the rate-pool JSON file. Default: ~/.squad/rate-pool.json.

.PARAMETER Once
    Print once and exit (no loop). Useful for scripting / CI.

.EXAMPLE
    .\scripts\rate-limit-dashboard.ps1
    .\scripts\rate-limit-dashboard.ps1 -RefreshSeconds 5
    .\scripts\rate-limit-dashboard.ps1 -Once
#>
param(
    [int]    $RefreshSeconds = 10,
    [string] $PoolPath       = (Join-Path $env:USERPROFILE '.squad\rate-pool.json'),
    [switch] $Once
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
$script:Width       = 56   # inner width (inside box borders)
$script:BarWidth    = 20   # width of progress bar in characters
$script:SnapshotDir = Join-Path $PSScriptRoot '..\\.squad\\monitoring'
$script:SnapshotPath = Join-Path $script:SnapshotDir 'rate-limit-status.json'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Format-BoxLine {
    param([string]$Content = '')
    $padded = $Content.PadRight($script:Width)
    if ($padded.Length -gt $script:Width) { $padded = $padded.Substring(0, $script:Width) }
    return "║ $padded ║"
}

function Format-Divider { return '╠' + ('═' * ($script:Width + 2)) + '╣' }
function Format-Top     { return '╔' + ('═' * ($script:Width + 2)) + '╗' }
function Format-Bottom  { return '╚' + ('═' * ($script:Width + 2)) + '╝' }

function Build-ProgressBar {
    param([double]$Remaining, [double]$Limit)
    if ($Limit -le 0) { return '░' * $script:BarWidth }
    $ratio  = [Math]::Min(1.0, $Remaining / $Limit)
    $filled = [int]($ratio * $script:BarWidth)
    $empty  = $script:BarWidth - $filled
    return ('█' * $filled) + ('░' * $empty)
}

function Format-RelativeTime {
    param([datetime]$Then)
    $diff = (Get-Date) - $Then
    if ($diff.TotalSeconds -lt 0)  { return '0s ago' }
    if ($diff.TotalSeconds -lt 60) { return "$([int]$diff.TotalSeconds)s ago" }
    if ($diff.TotalMinutes -lt 60) { return "$([int]$diff.TotalMinutes)m ago" }
    return "$([int]$diff.TotalHours)h ago"
}

function Format-ResetIn {
    param([string]$ResetAt)
    try {
        $reset = [datetime]::Parse($ResetAt).ToLocalTime()
        $diff  = $reset - (Get-Date)
        if ($diff.TotalSeconds -le 0) { return 'soon' }
        if ($diff.TotalMinutes -lt 1) { return "$([int]$diff.TotalSeconds)s" }
        return "$([int]$diff.TotalMinutes)m"
    } catch { return '?' }
}

function Get-ZoneEmoji {
    param([string]$Zone)
    switch ($Zone.ToUpper()) {
        'GREEN' { return '🟢' }
        'AMBER' { return '🟡' }
        'RED'   { return '🔴' }
        default { return '⚪' }
    }
}

function Write-ZoneLine {
    param([string]$Zone, [string]$ResetIn)
    $emoji   = Get-ZoneEmoji -Zone $Zone
    $content = "Zone: $emoji $($Zone.ToUpper())".PadRight(30) + "Reset in: $ResetIn"
    $padded  = $content.PadRight($script:Width)
    if ($padded.Length -gt $script:Width) { $padded = $padded.Substring(0, $script:Width) }
    $line    = "║ $padded ║"

    $color = switch ($Zone.ToUpper()) {
        'GREEN' { 'Green' }
        'AMBER' { 'Yellow' }
        'RED'   { 'Red' }
        default { 'White' }
    }
    Write-Host $line -ForegroundColor $color
}

function Save-Snapshot {
    param([object]$Pool)
    try {
        $dir = $script:SnapshotDir
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        $ghObj = if ($Pool.PSObject.Properties['github']) { $Pool.github } else { $null }
        $snapshot = @{
            timestamp        = (Get-Date -Format 'o')
            zone             = if ($Pool.PSObject.Properties['zone']) { $Pool.zone } else { 'UNKNOWN' }
            githubRemaining  = if ($ghObj -and $ghObj.PSObject.Properties['remaining']) { $ghObj.remaining } else { 0 }
            githubLimit      = if ($ghObj -and $ghObj.PSObject.Properties['limit'])     { $ghObj.limit }     else { 0 }
            githubResetAt    = if ($ghObj -and $ghObj.PSObject.Properties['resetAt'])   { $ghObj.resetAt }   else { $null }
            activeAgentCount = if ($Pool.PSObject.Properties['agents'])   { @($Pool.agents.PSObject.Properties).Count } else { 0 }
            incidentCount    = if ($Pool.PSObject.Properties['incidents']) { $Pool.incidents.Count } else { 0 }
        }
        $snapshot | ConvertTo-Json -Depth 3 | Set-Content -Path $script:SnapshotPath -Encoding UTF8
    } catch {
        # Non-fatal — dashboard still works without snapshot
    }
}

# ---------------------------------------------------------------------------
# Render single frame
# ---------------------------------------------------------------------------

function Render-Dashboard {
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm'

    # --- Header ---
    Write-Host (Format-Top)
    $title = "Squad Rate-Limit Monitor  $now"
    Write-Host (Format-BoxLine $title)
    Write-Host (Format-Divider)

    # --- Pool missing? ---
    if (-not (Test-Path $PoolPath)) {
        Write-Host (Format-BoxLine 'No rate-pool.json found — start a Squad agent first') -ForegroundColor DarkGray
        Write-Host (Format-Bottom)
        Write-Host ''
        Write-Host 'Press Ctrl+C to exit' -ForegroundColor DarkGray
        return
    }

    # --- Load pool ---
    try {
        $raw  = Get-Content $PoolPath -Raw -ErrorAction Stop
        $pool = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host (Format-BoxLine "Failed to read pool: $_") -ForegroundColor Red
        Write-Host (Format-Bottom)
        return
    }

    # --- Safe property helpers (pool may use old or new schema) ---
    $zone      = if ($pool.PSObject.Properties['zone'])     { $pool.zone }     else { 'UNKNOWN' }
    $ghObj     = if ($pool.PSObject.Properties['github'])   { $pool.github }   else { $null }
    $agentsObj = if ($pool.PSObject.Properties['agents'])   { $pool.agents }   else { $null }
    $incArr    = if ($pool.PSObject.Properties['incidents'])  { @($pool.incidents) } else { @() }

    $ghRemaining = if ($ghObj -and $ghObj.PSObject.Properties['remaining']) { [double]$ghObj.remaining } else { 0 }
    $ghLimit     = if ($ghObj -and $ghObj.PSObject.Properties['limit'])     { [double]$ghObj.limit }     else { 0 }
    $ghResetAt   = if ($ghObj -and $ghObj.PSObject.Properties['resetAt'])   { $ghObj.resetAt }           else { '' }

    # --- Zone row ---
    $resetIn = Format-ResetIn -ResetAt $ghResetAt
    Write-ZoneLine -Zone $zone -ResetIn $resetIn
    Write-Host (Format-Divider)

    # --- GitHub API bar ---
    $remaining = [int]$ghRemaining
    $limit     = [int]$ghLimit
    $pct       = if ($limit -gt 0) { [int](($remaining / $limit) * 100) } else { 0 }
    $bar       = Build-ProgressBar -Remaining $remaining -Limit $limit
    $ghLine    = "GitHub API    $bar  $remaining/$limit ($pct%)"
    Write-Host (Format-BoxLine $ghLine)
    Write-Host (Format-Divider)

    # --- Active agents ---
    $agents     = if ($agentsObj) { $agentsObj.PSObject.Properties } else { @() }
    $agentCount = @($agents).Count
    Write-Host (Format-BoxLine "Active Agents ($agentCount)")

    $now2 = Get-Date
    foreach ($prop in ($agents | Sort-Object { 
        $v = $agentsObj.($_.Name)
        if ($v -and $v.PSObject.Properties['priority']) { [int]$v.priority } else { 99 }
    })) {
        $agentId  = $prop.Name
        $info     = $prop.Value
        $priority = if ($info.PSObject.Properties['priority']) { "P$($info.priority)" } else { 'P?' }
        try {
            $lastSeen    = [datetime]::Parse($info.lastSeen).ToLocalTime()
            $lastSeenStr = Format-RelativeTime -Then $lastSeen
        } catch { $lastSeenStr = '?' }

        $agentPart = $agentId.PadRight(28)
        $priPart   = $priority.PadRight(5)
        $line      = "$agentPart $priPart last: $lastSeenStr"
        Write-Host (Format-BoxLine $line)
    }
    if ($agentCount -eq 0) {
        Write-Host (Format-BoxLine '  (none registered)')
    }
    Write-Host (Format-Divider)

    # --- Incidents ---
    Write-Host (Format-BoxLine 'Last 5 Incidents')
    $incidents = $incArr | Select-Object -Last 5
    if ($incidents.Count -eq 0) {
        Write-Host (Format-BoxLine '  (none)')
    } else {
        foreach ($inc in ($incidents | Sort-Object { $_.timestamp } -Descending)) {
            try {
                $ts   = [datetime]::Parse($inc.timestamp).ToLocalTime().ToString('HH:mm')
            } catch { $ts = '??' }
            $agent  = if ($inc.PSObject.Properties['agentId'])    { $inc.agentId }    else { '?' }
            $code   = if ($inc.PSObject.Properties['statusCode']) { $inc.statusCode } else { '?' }
            $retry  = if ($inc.PSObject.Properties['retryAfter']) { "retry: $($inc.retryAfter)s" } else { '' }
            $iLine  = "$ts  $($agent.PadRight(16)) $code  $retry"
            Write-Host (Format-BoxLine $iLine) -ForegroundColor Yellow
        }
    }

    Write-Host (Format-Bottom)
    Write-Host ''
    Write-Host 'Press Ctrl+C to exit' -ForegroundColor DarkGray

    # --- Snapshot ---
    Save-Snapshot -Pool $pool
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if ($Once) {
    Render-Dashboard
    exit 0
}

try {
    while ($true) {
        Clear-Host
        Render-Dashboard
        Start-Sleep -Seconds $RefreshSeconds
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    # Ctrl+C — clean exit
    Write-Host "`nDashboard stopped." -ForegroundColor DarkGray
}
