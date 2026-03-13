# DevBox Auto-Start Script
# Starts all Squad services on DevBox boot/wake/reconnect
# Registered as "SquadAutoStart" scheduled task (AtLogOn + SessionUnlock triggers)

$ErrorActionPreference = "Continue"
$logFile = "$env:USERPROFILE\.squad\devbox-autostart.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

function Log($msg) {
    $line = "[$timestamp] $msg"
    Write-Output $line
    Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
}

Log "=== DevBox Auto-Start BEGIN ==="
Log "Machine: $env:COMPUTERNAME"

# Ensure .squad directory exists
if (-not (Test-Path "$env:USERPROFILE\.squad")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\.squad" -Force | Out-Null
}

# --- 1. Production Ralph Watch ---
$prodRepo = "$env:USERPROFILE\tamresearch1"
$prodLock = "$prodRepo\.ralph-watch.lock"
if (-not (Test-Path $prodLock)) {
    Log "Starting Production Ralph Watch..."
    Start-Process pwsh.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$prodRepo\ralph-watch.ps1" -WorkingDirectory $prodRepo -WindowStyle Hidden
    Log "Production Ralph Watch started."
} else {
    Log "Production Ralph Watch already running (lock file exists)."
}

# --- 2. Research Ralph Watch ---
$researchRepo = "$env:USERPROFILE\tamresearch1-research"
if (Test-Path $researchRepo) {
    $researchLock = "$researchRepo\.ralph-watch.lock"
    if (-not (Test-Path $researchLock)) {
        Log "Pulling latest research repo..."
        Set-Location $researchRepo
        git pull --quiet 2>&1 | Out-Null
        Log "Starting Research Ralph Watch..."
        Start-Process pwsh.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$researchRepo\ralph-watch.ps1" -WorkingDirectory $researchRepo -WindowStyle Hidden
        Log "Research Ralph Watch started."
    } else {
        Log "Research Ralph Watch already running (lock file exists)."
    }
} else {
    Log "Research repo not found at $researchRepo — skipping."
}

# --- 3. GitHub Actions Runner ---
$runnerDir = "C:\actions-runner"
if (Test-Path "$runnerDir\run.cmd") {
    $runnerProc = Get-Process -Name "Runner.Listener" -ErrorAction SilentlyContinue
    if (-not $runnerProc) {
        Log "Starting GitHub Actions Runner..."
        Start-Process cmd.exe -ArgumentList "/c", "cd /d $runnerDir && run.cmd" -WorkingDirectory $runnerDir -WindowStyle Hidden
        Log "GitHub Actions Runner started."
    } else {
        Log "GitHub Actions Runner already running (PID: $($runnerProc.Id))."
    }
} else {
    Log "GitHub Actions Runner not installed at $runnerDir — skipping."
}

# --- 4. Agency Copilot Session ---
$agencyExe = "C:\.Tools\agency\CurrentVersion\agency.exe"
$copilotExe = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\copilot.exe"
if (Test-Path $copilotExe) {
    Log "Starting Agency Copilot session..."
    Start-Process $copilotExe -ArgumentList "--yolo" -WorkingDirectory $prodRepo -WindowStyle Hidden
    Log "Agency Copilot session started."
} elseif (Test-Path $agencyExe) {
    Log "Starting Agency Copilot session (via agency)..."
    Start-Process $agencyExe -ArgumentList "copilot", "--yolo" -WorkingDirectory $prodRepo -WindowStyle Hidden
    Log "Agency Copilot session started."
} else {
    Log "Neither copilot.exe nor agency.exe found — skipping."
}

Log "=== DevBox Auto-Start COMPLETE ==="
