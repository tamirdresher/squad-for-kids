# Ralph persistent polling loop - scans every 5 minutes
# Detects new/changed issues and PR comments, posts updates
# To stop: Ctrl+C

$repo = "tamirdresher_microsoft/tamresearch1"

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    Write-Host "[$timestamp] Ralph scanning..." -ForegroundColor Cyan
    
    try {
        # 1. Check for untriaged issues (squad label but no squad:member)
        $rawIssues = gh issue list --repo $repo --label "squad" --state open --json number,title,labels 2>&1
        $issues = $rawIssues | ConvertFrom-Json
        $untriaged = @()
        $assigned = @()
        foreach ($issue in $issues) {
            $labelNames = $issue.labels | ForEach-Object { $_.name }
            $hasMember = $false
            foreach ($l in $labelNames) {
                if ($l -match "^squad:") { $hasMember = $true; break }
            }
            if (-not $hasMember) { $untriaged += $issue }
            else { $assigned += $issue }
        }
        
        # 2. Check for open PRs
        $rawPrs = gh pr list --repo $repo --state open --json number,title 2>&1
        $prs = $rawPrs | ConvertFrom-Json
        
        # 3. Report
        $issueCount = $issues.Count
        $untriagedCount = $untriaged.Count
        $prCount = $prs.Count
        
        Write-Host "[$timestamp] Issues: $issueCount open ($untriagedCount untriaged) | PRs: $prCount open" -ForegroundColor White
        
        if ($untriagedCount -gt 0) {
            Write-Host "[$timestamp] UNTRIAGED ISSUES:" -ForegroundColor Red
            foreach ($i in $untriaged) {
                Write-Host "  #$($i.number): $($i.title)" -ForegroundColor Yellow
            }
            Write-Host "[$timestamp] >> Open ghcs and say 'Ralph, go' to process" -ForegroundColor Green
        }
        
        if ($prCount -gt 0) {
            Write-Host "[$timestamp] OPEN PRs:" -ForegroundColor Magenta
            foreach ($pr in $prs) {
                Write-Host "  PR #$($pr.number): $($pr.title)" -ForegroundColor Yellow
            }
        }
        
        if ($untriagedCount -eq 0 -and $prCount -eq 0 -and $issueCount -eq 0) {
            Write-Host "[$timestamp] Board clear." -ForegroundColor Green
        }
    } catch {
        Write-Host "[$timestamp] Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "[$timestamp] Next check in 5 minutes...`n" -ForegroundColor DarkGray
    Start-Sleep -Seconds 300
}
