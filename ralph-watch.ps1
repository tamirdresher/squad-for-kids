# Ralph Watch v3 - ACTUALLY DOES WORK, not just reports
# Scans every 5 minutes, triages untriaged issues, merges approved PRs
# To stop: Ctrl+C

$repo = "tamirdresher_microsoft/tamresearch1"

# Simple keyword-based triage mapping
$triageRules = @{
    "stability|tier|mitigation|infrastructure|helm|k8s|argocd" = "belanna"
    "security|fic|identity|worf|networking|auth" = "worf"
    "research|doc|analysis|article|learn|claw" = "seven"
    "code|cli|fix|bug|implement|workflow|build|test|ado" = "data"
    "architecture|design|plan|decision|rp |register|fleet" = "picard"
}

function Triage-Issue {
    param([int]$Number, [string]$Title)
    
    $assigned = $false
    foreach ($pattern in $triageRules.Keys) {
        if ($Title -imatch $pattern) {
            $member = $triageRules[$pattern]
            Write-Host "  >> Assigning #$Number to $member" -ForegroundColor Green
            gh issue edit $Number --repo $repo --add-label "squad:$member" 2>&1 | Out-Null
            gh issue comment $Number --repo $repo --body "Auto-triage (Ralph Watch): Assigned to squad:$member based on title keywords. @tamirdresher_microsoft" 2>&1 | Out-Null
            $assigned = $true
            break
        }
    }
    if (-not $assigned) {
        # Default to picard for triage
        Write-Host "  >> No keyword match, assigning #$Number to picard (default)" -ForegroundColor Yellow
        gh issue edit $Number --repo $repo --add-label "squad:picard" 2>&1 | Out-Null
        gh issue comment $Number --repo $repo --body "Auto-triage (Ralph Watch): No keyword match, assigned to squad:picard for manual triage. @tamirdresher_microsoft" 2>&1 | Out-Null
    }
}

$round = 0
while ($true) {
    $round++
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Write-Host "[$timestamp] Ralph Round $round scanning..." -ForegroundColor Cyan
    
    $actionsThisRound = 0
    
    try {
        # 1. Get all open squad issues
        $rawIssues = gh issue list --repo $repo --label "squad" --state open --json number,title,labels 2>&1
        $issues = $rawIssues | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $issues) { $issues = @() }
        
        # Categorize
        $untriaged = @()
        $assigned = @()
        foreach ($issue in $issues) {
            $labelNames = @()
            foreach ($l in $issue.labels) { $labelNames += $l.name }
            $hasMember = $false
            foreach ($ln in $labelNames) {
                if ($ln -match "^squad:") { $hasMember = $true; break }
            }
            if ($hasMember) { $assigned += $issue } else { $untriaged += $issue }
        }
        
        # 2. Check for issues with new comments since last check
        # Simple approach: track comment count changes
        $stateFile = Join-Path $PSScriptRoot ".ralph-state.json"
        $lastState = @{}
        if (Test-Path $stateFile) {
            $jsonObj = Get-Content $stateFile -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($jsonObj) {
                $jsonObj.PSObject.Properties | ForEach-Object { $lastState[$_.Name] = [int]$_.Value }
            }
        }
        $needsResponse = @()
        $newState = @{}
        foreach ($issue in $assigned) {
            $commentCount = (gh issue view $issue.number --repo $repo --json comments --jq '.comments | length' 2>$null)
            $key = "issue_$($issue.number)"
            $newState[$key] = [int]$commentCount
            $lastCount = if ($lastState.ContainsKey($key)) { [int]$lastState[$key] } else { [int]$commentCount }
            if ([int]$commentCount -gt $lastCount) {
                $needsResponse += $issue
            }
        }
        $newState | ConvertTo-Json | Set-Content $stateFile -Force
        
        # 3. Get open PRs
        $rawPrs = gh pr list --repo $repo --state open --json number,title,reviewDecision 2>&1
        $prs = $rawPrs | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $prs) { $prs = @() }
        
        # 3b. Check PRs for new comments since last check
        $prsNeedResponse = @()
        foreach ($pr in $prs) {
            $prCommentCount = (gh pr view $pr.number --repo $repo --json comments --jq '.comments | length' 2>$null)
            $prKey = "pr_$($pr.number)"
            $newState[$prKey] = [int]$prCommentCount
            $lastPrCount = if ($lastState.ContainsKey($prKey)) { [int]$lastState[$prKey] } else { [int]$prCommentCount }
            if ([int]$prCommentCount -gt $lastPrCount) {
                $prsNeedResponse += $pr
            }
        }
        # Update state file with PR counts too
        $newState | ConvertTo-Json | Set-Content $stateFile -Force
        
        # Report
        Write-Host "[$timestamp] Issues: $($issues.Count) open ($($untriaged.Count) untriaged, $($needsResponse.Count) need response) | PRs: $($prs.Count) open ($($prsNeedResponse.Count) need response)" -ForegroundColor White
        
        # 4. ACTION: Triage untriaged issues
        if ($untriaged.Count -gt 0) {
            Write-Host "[$timestamp] TRIAGING $($untriaged.Count) issues:" -ForegroundColor Red
            foreach ($i in $untriaged) {
                Write-Host "  #$($i.number): $($i.title)" -ForegroundColor Yellow
                Triage-Issue -Number $i.number -Title $i.title
                $actionsThisRound++
            }
        }
        
        # 5. ACTION: Flag issues needing response
        if ($needsResponse.Count -gt 0) {
            Write-Host "[$timestamp] ISSUES WITH UNANSWERED OWNER COMMENTS:" -ForegroundColor Magenta
            foreach ($i in $needsResponse) {
                Write-Host "  #$($i.number): $($i.title)" -ForegroundColor Yellow
            }
            Write-Host "[$timestamp] >> Open ghcs and say 'Ralph, go' to respond to these" -ForegroundColor Green
        }
        
        # 5b. ACTION: Flag PRs needing response
        if ($prsNeedResponse.Count -gt 0) {
            Write-Host "[$timestamp] PRs WITH UNANSWERED OWNER COMMENTS:" -ForegroundColor Magenta
            foreach ($pr in $prsNeedResponse) {
                Write-Host "  PR #$($pr.number): $($pr.title)" -ForegroundColor Yellow
            }
            Write-Host "[$timestamp] >> Open ghcs and say 'Ralph, go' to respond" -ForegroundColor Green
        }
        
        # 6. ACTION: Merge approved PRs
        foreach ($pr in $prs) {
            if ($pr.reviewDecision -eq "APPROVED") {
                Write-Host "[$timestamp] MERGING PR #$($pr.number): $($pr.title)" -ForegroundColor Green
                $mergeResult = gh pr merge $pr.number --repo $repo --merge 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  >> Merged successfully" -ForegroundColor Green
                    $actionsThisRound++
                } else {
                    Write-Host "  >> Merge failed: $mergeResult" -ForegroundColor Red
                }
            }
        }
        
        # 5. Summary
        if ($actionsThisRound -gt 0) {
            Write-Host "[$timestamp] Round ${round} - ${actionsThisRound} actions taken" -ForegroundColor Green
        } else {
            Write-Host "[$timestamp] Round ${round} - no actions needed" -ForegroundColor DarkGray
        }
        
        # 6. Periodic summary every 6 rounds (30 min)
        if ($round % 6 -eq 0) {
            Write-Host ""
            Write-Host "=== Ralph 30-min checkpoint (Round $round) ===" -ForegroundColor Magenta
            Write-Host "  Open issues: $($issues.Count) | Untriaged: $($untriaged.Count) | Open PRs: $($prs.Count)" -ForegroundColor Magenta
            Write-Host "  For complex work, open ghcs and say 'Ralph, go'" -ForegroundColor Magenta
            Write-Host "================================================" -ForegroundColor Magenta
            Write-Host ""
        }
        
    } catch {
        Write-Host "[$timestamp] Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "[$timestamp] Next check in 5 minutes...`n" -ForegroundColor DarkGray
    Start-Sleep -Seconds 300
}
