#Requires -Version 7
<#
.SYNOPSIS
    Ralph Email Monitor: Checks for GitHub error notification emails and takes automated action.

.DESCRIPTION
    Uses WorkIQ patterns to check email for GitHub error notifications every Ralph round.
    Detects: Failed CI/CD, security alerts, dependency vulnerabilities, failed deployments.
    Parses errors, creates issues if needed, attempts automated remediation.
    Only notifies via Teams when human decision is needed.

.PARAMETER LookbackMinutes
    How far back to check for emails. Default: 60 minutes.

.PARAMETER DryRun
    If set, logs what would happen but doesn't create issues or take actions.

.PARAMETER Repo
    Repository to check alerts for. Default: tamirdresher_microsoft/tamresearch1.

.EXAMPLE
    .\scripts\ralph-email-monitor.ps1
    .\scripts\ralph-email-monitor.ps1 -LookbackMinutes 120 -DryRun
#>
param(
    [int]$LookbackMinutes = 60,
    [switch]$DryRun,
    [string]$Repo = "tamirdresher_microsoft/tamresearch1"
)

$ErrorActionPreference = "Stop"
# Ensure gh uses the EMU account (tamirdresher_microsoft) — required for squad repo access
$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
$script:LogPrefix = "[ralph-email-monitor]"
$script:LogFile = Join-Path $env:USERPROFILE ".squad\ralph-email-monitor.log"

function Write-MonitorLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $entry = "$ts | $Level | $Message"
    Write-Host "$script:LogPrefix $entry" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "OK"    { "Green" }
            default { "Cyan" }
        }
    )
    $logDir = Split-Path $script:LogFile -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    Add-Content -Path $script:LogFile -Value $entry -Encoding utf8 -ErrorAction SilentlyContinue
}

# GitHub error notification patterns to search for in emails
$script:GitHubAlertPatterns = @(
    @{
        Name        = "workflow_failure"
        SearchQuery = "GitHub Actions workflow run failed OR workflow run failure"
        Keywords    = @("workflow", "failed", "Actions", "CI", "build failed")
        Severity    = "high"
        AutoRemediate = $true
        Label       = "ci-failure"
    },
    @{
        Name        = "dependabot_alert"
        SearchQuery = "Dependabot alert OR dependency vulnerability OR security advisory"
        Keywords    = @("Dependabot", "vulnerability", "dependency", "CVE", "security advisory")
        Severity    = "high"
        AutoRemediate = $false
        Label       = "dependency-vuln"
    },
    @{
        Name        = "security_alert"
        SearchQuery = "GitHub security vulnerability OR code scanning alert OR secret scanning"
        Keywords    = @("security", "vulnerability", "code scanning", "secret scanning", "CodeQL")
        Severity    = "critical"
        AutoRemediate = $false
        Label       = "security-alert"
    },
    @{
        Name        = "deployment_failure"
        SearchQuery = "deployment failed OR deploy failure OR release failed"
        Keywords    = @("deployment", "failed", "deploy", "release")
        Severity    = "high"
        AutoRemediate = $true
        Label       = "deploy-failure"
    },
    @{
        Name        = "branch_protection"
        SearchQuery = "branch protection OR required status check OR review required"
        Keywords    = @("branch protection", "status check", "review required", "merge blocked")
        Severity    = "medium"
        AutoRemediate = $false
        Label       = "branch-protection"
    }
)

function Get-AlertPromptForWorkIQ {
    <#
    .SYNOPSIS
        Generates a WorkIQ query prompt to check for GitHub alert emails.
    #>
    param([int]$LookbackMinutes)

    $timeRange = if ($LookbackMinutes -le 60) { "the last hour" }
                 elseif ($LookbackMinutes -le 120) { "the last 2 hours" }
                 else { "the last $([math]::Round($LookbackMinutes / 60)) hours" }

    return @"
Check Tamir's emails from $timeRange for any of these GitHub notifications:
1. GitHub Actions workflow run failures or errors
2. Dependabot security alerts or dependency vulnerability warnings
3. GitHub security vulnerability alerts, code scanning alerts, or secret scanning alerts
4. Deployment failures or release errors
5. Branch protection violations or merge blocks

For each alert found, provide:
- The email subject line
- Which repository it's about
- What type of alert it is (CI failure, security, dependency, deployment)
- A brief summary of the issue
- When it was received

If no GitHub alert emails were found, just say "No GitHub alert emails found."
"@
}

function ConvertTo-AlertFindings {
    <#
    .SYNOPSIS
        Parses WorkIQ response text into structured alert findings.
    .DESCRIPTION
        Extracts patterns from the free-text WorkIQ response to identify GitHub alerts.
    #>
    param([string]$WorkIQResponse)

    $findings = @()

    if ([string]::IsNullOrWhiteSpace($WorkIQResponse)) {
        return $findings
    }

    # Quick check: if no alerts found
    $noAlertPatterns = @(
        "no github alert",
        "no alert emails",
        "no notifications found",
        "didn't find any",
        "no relevant emails",
        "no github notification"
    )
    foreach ($pattern in $noAlertPatterns) {
        if ($WorkIQResponse -imatch [regex]::Escape($pattern)) {
            return $findings
        }
    }

    # Check each alert pattern
    foreach ($alertPattern in $script:GitHubAlertPatterns) {
        $matched = $false
        foreach ($keyword in $alertPattern.Keywords) {
            if ($WorkIQResponse -imatch [regex]::Escape($keyword)) {
                $matched = $true
                break
            }
        }

        if ($matched) {
            $findings += @{
                Type        = $alertPattern.Name
                Severity    = $alertPattern.Severity
                Label       = $alertPattern.Label
                CanAutoRemediate = $alertPattern.AutoRemediate
                RawMatch    = $WorkIQResponse
            }
        }
    }

    return $findings
}

function Test-IssueAlreadyExists {
    <#
    .SYNOPSIS
        Checks if a GitHub issue with the given label and similar title already exists.
    #>
    param(
        [string]$Label,
        [string]$TitlePattern,
        [string]$Repo
    )

    try {
        $existingIssues = gh issue list --repo $Repo --label "squad,github-alert,$Label" --state open --json number,title --limit 10 2>$null | ConvertFrom-Json
        foreach ($issue in $existingIssues) {
            if ($issue.title -imatch [regex]::Escape($TitlePattern)) {
                return $issue.number
            }
        }
    }
    catch {
        Write-MonitorLog "Error checking existing issues: $_" "WARN"
    }

    return $null
}

function New-GitHubAlertIssue {
    <#
    .SYNOPSIS
        Creates a GitHub issue for a detected alert.
    #>
    param(
        [hashtable]$Finding,
        [string]$Repo,
        [string]$Summary
    )

    $typeLabel = switch ($Finding.Type) {
        "workflow_failure"   { "CI/CD Workflow Failure" }
        "dependabot_alert"   { "Dependabot Security Alert" }
        "security_alert"     { "Security Vulnerability Alert" }
        "deployment_failure" { "Deployment Failure" }
        "branch_protection"  { "Branch Protection Alert" }
        default              { "GitHub Alert" }
    }

    $dateStr = Get-Date -Format "yyyy-MM-dd"
    $title = "[$typeLabel] $dateStr — Detected by Ralph Email Monitor"

    # Check for duplicates
    $existing = Test-IssueAlreadyExists -Label $Finding.Label -TitlePattern $typeLabel -Repo $Repo
    if ($existing) {
        Write-MonitorLog "Issue already exists (#$existing) for $typeLabel — adding comment instead" "INFO"
        $commentBody = @"
🔄 **Ralph Email Monitor Update** ($dateStr)

Another alert of this type was detected in email.
Severity: **$($Finding.Severity)**

Details from email scan:
$Summary
"@
        if (-not $DryRun) {
            gh issue comment $existing --repo $Repo --body $commentBody 2>$null | Out-Null
        }
        Write-MonitorLog "Updated existing issue #$existing with new finding" "OK"
        return $existing
    }

    $body = @"
## GitHub Alert Detected by Ralph Email Monitor

**Type:** $typeLabel
**Severity:** $($Finding.Severity)
**Detected:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Auto-remediation possible:** $($Finding.CanAutoRemediate)

### Summary
$Summary

### Recommended Actions
$(if ($Finding.CanAutoRemediate) {
    "- [ ] Ralph will attempt automated remediation`n- [ ] Verify the fix was successful"
} else {
    "- [ ] **Human review required** — this alert needs manual assessment`n- [ ] Review the alert details in the GitHub notification email`n- [ ] Take appropriate action based on severity"
})

### Source
Detected from GitHub notification email via Ralph's WorkIQ email monitor.

---
*Auto-created by Ralph Email Monitor — [scripts/ralph-email-monitor.ps1]*
"@

    $labels = "squad,github-alert,$($Finding.Label)"

    if ($DryRun) {
        Write-MonitorLog "[DRY RUN] Would create issue: $title with labels: $labels" "INFO"
        return -1
    }

    try {
        $issueResult = gh issue create --repo $Repo --title $title --body $body --label $labels 2>&1 | Out-String
        if ($issueResult -match "#(\d+)") {
            $issueNum = $Matches[1]
            Write-MonitorLog "Created issue #$issueNum: $title" "OK"
            return [int]$issueNum
        }
        else {
            Write-MonitorLog "Issue creation output: $issueResult" "WARN"
            return $null
        }
    }
    catch {
        Write-MonitorLog "Failed to create issue: $_" "ERROR"
        return $null
    }
}

function Invoke-AutoRemediation {
    <#
    .SYNOPSIS
        Attempts automated remediation for alerts that support it.
    #>
    param(
        [hashtable]$Finding,
        [string]$Repo
    )

    if (-not $Finding.CanAutoRemediate) {
        Write-MonitorLog "Alert type $($Finding.Type) does not support auto-remediation" "INFO"
        return $false
    }

    Write-MonitorLog "Attempting auto-remediation for: $($Finding.Type)" "INFO"

    switch ($Finding.Type) {
        "workflow_failure" {
            # Re-run the most recent failed workflow
            try {
                $failedRuns = gh run list --repo $Repo --status failure --limit 1 --json databaseId 2>$null | ConvertFrom-Json
                if ($failedRuns -and $failedRuns.Count -gt 0) {
                    $runId = $failedRuns[0].databaseId
                    if (-not $DryRun) {
                        gh run rerun $runId --repo $Repo 2>$null | Out-Null
                        Write-MonitorLog "Re-ran failed workflow run #$runId" "OK"
                    }
                    else {
                        Write-MonitorLog "[DRY RUN] Would re-run workflow run #$runId" "INFO"
                    }
                    return $true
                }
            }
            catch {
                Write-MonitorLog "Auto-remediation failed for workflow: $_" "ERROR"
            }
        }
        "deployment_failure" {
            # For deployment failures, we log but don't auto-retry (too risky)
            Write-MonitorLog "Deployment failure detected — logged for review, not auto-retrying" "WARN"
            return $false
        }
    }

    return $false
}

function Invoke-EmailMonitor {
    <#
    .SYNOPSIS
        Main email monitoring entry point. Designed to be called from Ralph's round loop.
    .OUTPUTS
        Hashtable: AlertsFound (int), IssuesCreated (int), RemediationsAttempted (int), Details (string)
    #>
    param(
        [int]$LookbackMinutes = 60,
        [string]$Repo = "tamirdresher_microsoft/tamresearch1"
    )

    $result = @{
        AlertsFound = 0
        IssuesCreated = 0
        RemediationsAttempted = 0
        NeedsHumanAttention = $false
        Details = ""
    }

    Write-MonitorLog "=== Email monitor check started (lookback: ${LookbackMinutes}m) ===" "INFO"

    # Generate the WorkIQ prompt
    $workiqPrompt = Get-AlertPromptForWorkIQ -LookbackMinutes $LookbackMinutes

    # The actual WorkIQ call needs to happen inside a Copilot session
    # When run standalone, we output the prompt for the caller to execute via WorkIQ
    # When sourced into ralph-watch, the prompt is embedded in the Ralph round prompt

    Write-MonitorLog "WorkIQ query prompt generated" "INFO"
    Write-MonitorLog "Prompt: $($workiqPrompt.Substring(0, [Math]::Min(200, $workiqPrompt.Length)))..." "INFO"

    # Return the prompt and pattern info for the caller to use
    $result.Details = $workiqPrompt

    Write-MonitorLog "=== Email monitor check completed ===" "INFO"
    return $result
}

# Export the WorkIQ prompt additions for ralph-watch.ps1 to embed
function Get-EmailMonitorPromptAddition {
    <#
    .SYNOPSIS
        Returns the prompt text to add to Ralph's round prompt for email monitoring.
    #>

    return @"

GITHUB ERROR EMAIL MONITORING (do this EVERY round):
1. Use workiq-ask_work_iq to check: "Any emails to Tamir in the last hour from GitHub about: workflow failures, Dependabot alerts, security vulnerabilities, code scanning alerts, secret scanning, deployment failures, or branch protection violations?"
2. For each GitHub alert email found:
   a. Determine the alert type: ci-failure, dependency-vuln, security-alert, deploy-failure, or branch-protection
   b. Check if a GitHub issue with labels 'squad,github-alert,{type}' already exists (use gh issue list --label)
   c. If NO existing issue: create one with title '[Alert Type] YYYY-MM-DD — Detected by Ralph Email Monitor' and labels 'squad,github-alert,{type}'
   d. If existing issue: add a comment with the new alert details
3. For ci-failure alerts: attempt auto-remediation by re-running the failed workflow (gh run rerun)
4. For security-alert or dependency-vuln: these need human review — mention in Teams notification that human decision is needed
5. Log all findings to the console with prefix [email-monitor]
6. Do NOT create duplicate issues — always check for existing ones first
"@
}

# --- Main execution ---
if ($MyInvocation.InvocationName -ne '.') {
    $monitorResult = Invoke-EmailMonitor -LookbackMinutes $LookbackMinutes -Repo $Repo
    Write-MonitorLog "Result: Alerts=$($monitorResult.AlertsFound), Issues=$($monitorResult.IssuesCreated), Remediations=$($monitorResult.RemediationsAttempted)" "INFO"
    return $monitorResult
}
