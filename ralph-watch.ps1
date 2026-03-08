# Ralph Watch v6 - Runs agency copilot with Squad agent every interval
# Launches a full Copilot session that can do actual work
# To stop: Ctrl+C

$intervalMinutes = 5
$round = 0

$prompt = 'Ralph, Go! make sure the PR comments are also taken care of and then merge the PRs when they are ready and open new issues if needed. IMPORTANT: Only send a Teams message if there are important changes that require my attention — such as new issues needing my decision, PRs ready for review or merged, CI failures, completed work I should know about, or items requiring user action. Do NOT send a Teams message for routine board status checks with no actionable changes.'

while ($true) {
    $round++
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "[$timestamp] Ralph Round $round - launching agency" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    # Step 1: Update the repo to ensure we have the latest code
    Write-Host "[$timestamp] Pulling latest changes..." -ForegroundColor Yellow
    try {
        # Fetch latest changes
        git fetch 2>&1 | Out-Null
        
        # Check if there are uncommitted changes
        $status = git status --porcelain
        if ($status) {
            Write-Host "[$timestamp] Local changes detected, stashing..." -ForegroundColor Yellow
            git stash save "ralph-watch-auto-stash-$timestamp" 2>&1 | Out-Null
            $stashed = $true
        } else {
            $stashed = $false
        }
        
        # Pull latest changes
        $pullResult = git pull 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[$timestamp] Repository updated successfully" -ForegroundColor Green
        } else {
            Write-Host "[$timestamp] Warning: git pull failed: $pullResult" -ForegroundColor Yellow
        }
        
        # Restore stashed changes if any
        if ($stashed) {
            Write-Host "[$timestamp] Restoring local changes..." -ForegroundColor Yellow
            $popResult = git stash pop 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[$timestamp] Warning: Could not restore stashed changes. Use 'git stash list' to recover." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[$timestamp] Warning: Failed to update repository: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "[$timestamp] Continuing with existing code..." -ForegroundColor Yellow
    }
    
    # Step 2: Run the agency copilot
    try {
        agency copilot --yolo --autopilot --agent squad -p $prompt
        Write-Host "[$timestamp] Round $round completed" -ForegroundColor Green
    } catch {
        Write-Host "[$timestamp] Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "[$timestamp] Next round in $intervalMinutes minutes..." -ForegroundColor DarkGray
    Start-Sleep -Seconds ($intervalMinutes * 60)
}
