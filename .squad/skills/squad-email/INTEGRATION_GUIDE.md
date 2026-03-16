# Squad Email SMTP — Integration Guide for Agents

This document shows how different Squad agents and workflows can use the email SMTP capability.

## Quick Reference

**Script Location:** `C:\temp\tamresearch1\scripts\send-squad-email.ps1`

**Execution Pattern:**
```powershell
& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" -To "email@example.com" -Subject "Subject" -Body "Message"
```

---

## Integration Patterns

### 1. Ralph (Work Monitor) — Status Notifications
```powershell
# In Ralph's dashboard monitoring loop
if ($criticalIssueFound -and $alertUser) {
    & "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
        -To "tamir.dresher@gmail.com" `
        -Subject "⚠️ CRITICAL: $($issue.Title)" `
        -Body @"
Issue: $($issue.Title)
Severity: $($issue.Severity)
Affected: $($issue.AffectedComponent)
Action Required: $($issue.RecommendedAction)

Dashboard: $($dashboardLink)
"@
}
```

### 2. Seven (Docs & Analysis) — Report Delivery
```powershell
# Generate report, then email it
$reportPath = New-AnalysisReport -Topic "Q1 Performance"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "📊 Squad Analysis Report — $timestamp" `
    -Body "Your requested analysis is attached." `
    -Attachments @($reportPath)
```

### 3. Data (Code Expert) — Build Notifications
```powershell
# Notify on build completion
if ($buildSuccess) {
    $summary = Get-BuildSummary -BuildId $latestBuild
    
    & "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
        -To "tamir.dresher@gmail.com" `
        -Subject "✅ Build #$buildNumber Succeeded" `
        -Body "Build completed in $($summary.Duration). All tests passed."
} else {
    & "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
        -To "tamir.dresher@gmail.com" `
        -Subject "❌ Build #$buildNumber Failed" `
        -Body "Build failed at stage: $($summary.FailedStage). Check logs."
}
```

### 4. Neelix (News Reporter) — Daily Digest
```powershell
# Generate daily tech news digest
$today = Get-Date -Format "yyyy-MM-dd"
$newsItems = Get-TechNews -Category "AI", "Cloud", "DevOps" -Days 1

$emailBody = "📰 **Tech News Digest — $today**`n`n"
foreach ($item in $newsItems) {
    $emailBody += "• **$($item.Title)**`n  $($item.Summary)`n  🔗 $($item.Link)`n`n"
}

& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "📰 Tech News Digest — $today" `
    -Body $emailBody `
    -BodyAsHtml
```

### 5. Scribe (Session Logger) — Session Summaries
```powershell
# After completing a session task
$sessionSummary = Get-SessionSummary -SessionId $currentSession
$checkpointTime = Get-Date -Format "HH:mm"

& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "📝 Session Checkpoint — $checkpointTime" `
    -Body @"
Task: $($sessionSummary.TaskName)
Status: $($sessionSummary.Status)
Work Completed: $($sessionSummary.WorkDone)
Next Steps: $($sessionSummary.NextSteps)

Session ID: $currentSession
"@
```

### 6. Picard (Lead) — Decision Notifications
```powershell
# Notify when important decision logged
$decision = Get-LatestDecision
$decisionTime = $decision.Timestamp

& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "🎯 New Decision Logged: $($decision.Title)" `
    -Body @"
Decision: $($decision.Content)

Rationale: $($decision.Rationale)
Impact: $($decision.Impact)
Date Logged: $decisionTime

Review: .squad/decisions.md
"@
```

### 7. Troi (Blogger) — Publication Notifications
```powershell
# Notify when blog post published
$post = Get-LatestBlogPost
$publishDate = $post.PublishDate

& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "📝 New Blog Post: $($post.Title)" `
    -Body @"
Your blog post has been published!

Title: $($post.Title)
Published: $publishDate
Link: $($post.PublicUrl)

Topics: $($post.Topics -join ', ')
"@
```

---

## GitHub Actions Integration

### Example: Notify on Workflow Success
```yaml
name: Build & Notify

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Project
        run: dotnet build
      
      - name: Run Tests
        run: dotnet test
      
      - name: Send Success Notification
        if: success()
        shell: pwsh
        env:
          SQUAD_EMAIL_PASSWORD: ${{ secrets.SQUAD_EMAIL_PASSWORD }}
        run: |
          & "scripts/send-squad-email.ps1" `
            -To "tamir.dresher@gmail.com" `
            -Subject "✅ GitHub Workflow Completed: ${{ github.workflow }}" `
            -Body "Workflow succeeded on ${{ github.ref }} at $(Get-Date)"
      
      - name: Send Failure Notification
        if: failure()
        shell: pwsh
        env:
          SQUAD_EMAIL_PASSWORD: ${{ secrets.SQUAD_EMAIL_PASSWORD }}
        run: |
          & "scripts/send-squad-email.ps1" `
            -To "tamir.dresher@gmail.com" `
            -Subject "❌ GitHub Workflow Failed: ${{ github.workflow }}" `
            -Body @"
Workflow: ${{ github.workflow }}
Branch: ${{ github.ref }}
Failed Job: ${{ job.status }}
Run: https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}
"@
```

---

## Azure DevOps Pipeline Integration

### Example: Notify on Pipeline Completion
```yaml
# azure-pipelines.yml
trigger:
  - main

jobs:
  - job: Build
    pool:
      vmImage: 'windows-latest'
    steps:
      - task: DotNetCoreCLI@2
        inputs:
          command: 'build'
          arguments: '--configuration Release'
      
      - task: DotNetCoreCLI@2
        inputs:
          command: 'test'
          arguments: '--configuration Release'
      
      - task: PowerShell@2
        condition: succeeded()
        displayName: 'Send Success Email'
        env:
          SQUAD_EMAIL_PASSWORD: $(SQUAD_EMAIL_PASSWORD)
        inputs:
          targetType: 'inline'
          script: |
            & "$(System.DefaultWorkingDirectory)\scripts\send-squad-email.ps1" `
              -To "tamir.dresher@gmail.com" `
              -Subject "✅ ADO Pipeline Succeeded: $(Build.DefinitionName)" `
              -Body "Build $(Build.BuildNumber) completed successfully."
      
      - task: PowerShell@2
        condition: failed()
        displayName: 'Send Failure Email'
        env:
          SQUAD_EMAIL_PASSWORD: $(SQUAD_EMAIL_PASSWORD)
        inputs:
          targetType: 'inline'
          script: |
            & "$(System.DefaultWorkingDirectory)\scripts\send-squad-email.ps1" `
              -To "tamir.dresher@gmail.com" `
              -Subject "❌ ADO Pipeline Failed: $(Build.DefinitionName)" `
              -Body "Build $(Build.BuildNumber) failed. Review logs: $(System.CollectionUri)$(System.TeamProject)/_build/results?buildId=$(Build.BuildId)"
```

---

## Scheduled Task Integration

### Example: Daily Report Email (Windows Task Scheduler)
```powershell
# daily-report.ps1
# Run daily via Task Scheduler

$reportDate = Get-Date -Format "yyyy-MM-dd"
$report = @"
DAILY SQUAD REPORT — $reportDate

WORK COMPLETED:
- $(Get-CompletedTasks -Date $reportDate | Select-Object -ExpandProperty Name | Join-String -Separator "`n- ")

ISSUES DETECTED:
$(Get-OpenIssues | Select-Object Title, Severity | Format-Table -AutoSize | Out-String)

UPCOMING DEADLINES:
- $(Get-UpcomingDeadlines -Days 7 | Select-Object -ExpandProperty Name | Join-String -Separator "`n- ")

Generated: $(Get-Date -Format "HH:mm:ss")
"@

& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "📊 Daily Squad Report — $reportDate" `
    -Body $report
```

**Task Scheduler Setup:**
```powershell
# Create task to run daily at 9 AM
$taskName = "Squad-Daily-Report"
$taskPath = "\Squad\"
$scriptPath = "C:\temp\tamresearch1\scripts\daily-report.ps1"
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $scriptPath"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger
```

---

## Testing & Development

### Quick Manual Test
```powershell
# Load script into memory
. "C:\temp\tamresearch1\scripts\send-squad-email.ps1"

# Test with environment variable
$env:SQUAD_EMAIL_PASSWORD = "test-password"

# Send test email
& "C:\temp\tamresearch1\scripts\send-squad-email.ps1" `
    -To "tamir.dresher@gmail.com" `
    -Subject "🧪 Test Email from Squad" `
    -Body "This is a test of the Squad email system." `
    -Verbose
```

### Verify Credential Manager
```powershell
# Check if credential exists
cmdkey /list:squad-email-outlook

# Update credential
cmdkey /generic:squad-email-outlook /user:td-squad-ai-team@outlook.com /pass:YOUR_PASSWORD

# Delete credential (if needed)
cmdkey /delete:squad-email-outlook
```

---

## Error Handling

### Example: Graceful Failure Handling
```powershell
$emailParams = @{
    To = "tamir.dresher@gmail.com"
    Subject = "Squad Report"
    Body = "Your report is ready."
}

try {
    & "C:\temp\tamresearch1\scripts\send-squad-email.ps1" @emailParams
    Write-Host "✓ Email sent successfully"
} catch {
    Write-Warning "Email failed: $_"
    # Fallback: Log to file
    $_ | Out-File "C:\temp\email-error-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    # Don't fail the overall task, just log
}
```

---

## Best Practices

✅ **DO:**
- Always use `-Verbose` during testing
- Include timestamp in email subjects
- Use emoji for quick visual scanning (✅, ❌, ⚠️, 📊, etc.)
- Store passwords in Credential Manager, not variables
- Include action links in email body
- Test emails with your own address first

❌ **DON'T:**
- Hardcode passwords in scripts
- Send test emails to production mailboxes repeatedly
- Include sensitive data in email subjects
- Use email for high-volume notifications (> 100/day)
- Send without error handling

---

## Troubleshooting

See: `C:\temp\tamresearch1\scripts\SQUAD_EMAIL_SETUP.md` (Troubleshooting section)

**Common Issues:**
- **"Failed to retrieve password"** → Set `$env:SQUAD_EMAIL_PASSWORD` or update Credential Manager
- **"Connection timeout"** → Check firewall, test: `Test-NetConnection -ComputerName smtp-mail.outlook.com -Port 587`
- **"SMTP error 550"** → Verify recipient email is valid
- **"Authentication failed"** → Verify password hasn't expired

---

## Reference

- **Main Skill:** `.squad/skills/squad-email/SKILL.md`
- **Implementation:** `.squad/skills/squad-email/README.md`
- **Setup Guide:** `scripts/SQUAD_EMAIL_SETUP.md`
- **Script:** `scripts/send-squad-email.ps1`
