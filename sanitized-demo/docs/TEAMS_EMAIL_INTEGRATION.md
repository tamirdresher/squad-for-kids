# Teams & Email Integration

## Overview

The Squad system integrates with Microsoft Teams and Outlook to monitor workplace communications and convert them into actionable GitHub issues.

## Architecture

```
Microsoft 365 (Teams/Outlook)
    ↓
WorkIQ Skill (Microsoft 365 Copilot)
    ↓
Ralph Watch Script
    ↓
GitHub Issues / Squad Agents
```

## Components

### 1. WorkIQ Skill

**What is WorkIQ?**

WorkIQ is a Microsoft 365 Copilot skill that queries your workplace data (emails, Teams messages, meetings, documents) to extract relevant information.

**Capabilities:**
- Search Teams messages by channel, date, or keyword
- Query emails by sender, subject, or time range
- Extract meeting notes and action items
- Find documents and their summaries

**Usage in Squad:**
The Ralph watch script uses WorkIQ to:
- Monitor specific Teams channels for requests
- Check emails for squad-related keywords
- Extract action items from meetings
- Surface high-priority communications

### 2. Teams Monitor Skill

**Location:** `.squad/skills/teams-monitor/`

Custom Squad skill that bridges Teams messages to GitHub issues.

**How it Works:**
1. WorkIQ queries Teams channels for new messages
2. Teams Monitor skill filters for actionable content
3. Creates GitHub issues with proper squad labels
4. Notifies requesting user with issue link

**Configuration:**
Edit `.squad/skills/teams-monitor/teams-monitor/SKILL.md` to customize:
- Monitored channels
- Keyword filters
- Issue creation rules
- Notification templates

### 3. Setup Script

**Location:** `scripts/setup-github-teams.ps1`

Automated setup script for configuring the Teams integration.

**What it Does:**
1. Creates GitHub repository secrets for Teams webhook
2. Configures WorkIQ skill permissions
3. Sets up Teams incoming webhook
4. Tests the integration end-to-end

**Usage:**
```powershell
.\scripts\setup-github-teams.ps1 `
    -TeamsWebhookUrl "https://your-org.webhook.office.com/webhookb2/..." `
    -GitHubToken "ghp_..." `
    -Repository "your-org/your-repo"
```

## Setup Instructions

### Prerequisites

1. **Microsoft 365 Account** with access to:
   - Microsoft Teams
   - Outlook
   - Microsoft 365 Copilot with WorkIQ skill

2. **GitHub Repository** with:
   - Admin access
   - GitHub Actions enabled
   - Secrets management permissions

3. **Tools:**
   - PowerShell 7+ (cross-platform)
   - GitHub CLI (`gh`)
   - Azure CLI (`az`) - optional for advanced configuration

### Step 1: Enable WorkIQ Skill

1. Open Microsoft 365 Copilot
2. Navigate to Skills settings
3. Enable "WorkIQ" skill
4. Grant permissions:
   - Read Teams messages
   - Read emails
   - Read calendar events
   - Read documents

### Step 2: Create Teams Webhook

1. Open the Teams channel where Squad should monitor
2. Click "..." → "Connectors" → "Incoming Webhook"
3. Name: "Squad Notifications"
4. Icon: Upload Squad logo (optional)
5. Click "Create"
6. **Copy the webhook URL** - you'll need this for setup

### Step 3: Run Setup Script

```powershell
# Clone the repository
git clone https://github.com/your-org/squad-demo.git
cd squad-demo

# Run setup script
.\scripts\setup-github-teams.ps1 `
    -TeamsWebhookUrl "https://your-org.webhook.office.com/webhookb2/abc123..." `
    -GitHubToken "ghp_yourgithubtoken" `
    -Repository "your-org/squad-demo"
```

The script will:
- Store Teams webhook URL in GitHub Secrets
- Configure WorkIQ integration
- Test the connection
- Create a test issue and Teams notification

### Step 4: Configure Monitoring

Edit `.squad/schedule.json` to customize monitoring frequency:

```json
{
  "tasks": [
    {
      "id": "teams-monitor",
      "name": "Teams Message Monitor",
      "schedule": "*/20 * * * *",
      "command": "gh copilot squad teams-monitor",
      "enabled": true
    }
  ]
}
```

**Recommended frequency:** Every 15-20 minutes

### Step 5: Test Integration

1. Post a message in your Teams channel:
   ```
   @Squad Create an issue to review the new API design
   ```

2. Wait for the next monitoring cycle (up to 20 minutes)

3. Check GitHub issues:
   ```bash
   gh issue list --label squad
   ```

4. You should see:
   - New issue created from Teams message
   - Issue assigned to appropriate agent
   - Teams notification confirming issue creation

## Configuration

### Monitored Channels

Edit `.squad/skills/teams-monitor/config.json`:

```json
{
  "monitored_channels": [
    {
      "team": "Engineering",
      "channel": "squad-requests",
      "enabled": true
    },
    {
      "team": "Product",
      "channel": "feature-requests",
      "enabled": true
    }
  ],
  "keywords": [
    "@squad",
    "@ai-team",
    "create issue",
    "assign to squad"
  ],
  "auto_close_phrases": [
    "issue resolved",
    "never mind",
    "false alarm"
  ]
}
```

### Email Monitoring

Configure email monitoring in Ralph watch script:

```powershell
# Edit ralph-watch.ps1
$EmailMonitoring = @{
    Enabled = $true
    FromAddresses = @(
        "product@company.com",
        "stakeholders@company.com"
    )
    SubjectKeywords = @(
        "[SQUAD]",
        "[AI-TEAM]",
        "Action Required"
    )
    CheckInterval = "30 minutes"
}
```

### WorkIQ Query Examples

**Check Teams messages:**
```powershell
gh copilot squad workiq "what messages mentioned squad in the last 24 hours?"
```

**Check emails:**
```powershell
gh copilot squad workiq "show me emails about API changes from the last week"
```

**Extract action items:**
```powershell
gh copilot squad workiq "what action items were assigned to me in recent meetings?"
```

## Workflow Integration

### Automatic Issue Creation

When Ralph detects a Teams message or email:

1. **Extract context:**
   - Sender name and email
   - Message content
   - Timestamp
   - Channel/thread context

2. **Create GitHub issue:**
   - Title from message subject/first line
   - Body with full message content
   - Labels: `squad`, appropriate domain label
   - Assign to Picard for triage

3. **Notify Teams:**
   - Post reply with issue link
   - Include assigned agent
   - Provide estimated response time

### Issue Updates to Teams

When issues are updated, notify Teams:

**Workflow:** `.github/workflows/squad-issue-notify.yml`

Sends Teams message when:
- Issue is assigned to an agent
- Issue status changes
- Issue is closed
- Agent leaves a comment

**Example notification:**
```
🤖 Issue Update: #42 Review API Design

Status: ✅ Closed
Agent: Data (Code Expert)
Time: 2 hours

View issue: https://github.com/your-org/repo/issues/42
```

## Advanced Features

### Smart Routing

Automatically route Teams messages to the right agent based on content:

```json
{
  "routing_rules": [
    {
      "keywords": ["infrastructure", "kubernetes", "helm"],
      "agent": "belanna",
      "priority": "high"
    },
    {
      "keywords": ["security", "compliance", "fedramp"],
      "agent": "worf",
      "priority": "high"
    },
    {
      "keywords": ["documentation", "readme", "guide"],
      "agent": "seven",
      "priority": "medium"
    }
  ]
}
```

### Sentiment Analysis

Use WorkIQ to detect urgency:

```powershell
# High priority indicators
$HighPriorityPhrases = @(
    "urgent",
    "asap",
    "critical",
    "production down",
    "customer impact"
)

# Auto-escalate to Picard
if ($message -match ($HighPriorityPhrases -join '|')) {
    $Labels += "priority:high"
    $AssignedAgent = "picard"
}
```

### Meeting Notes Integration

Automatically extract action items from meeting notes:

```powershell
# Query recent meetings
$ActionItems = gh copilot squad workiq @"
What action items were assigned to the engineering team in meetings this week?
"@

# Create issues for each action item
foreach ($item in $ActionItems) {
    gh issue create `
        --title "$($item.Title)" `
        --body "From meeting: $($item.MeetingTitle) on $($item.Date)`n`n$($item.Description)" `
        --label "squad,from-meeting"
}
```

## Troubleshooting

### Teams Notifications Not Posting

**Check webhook URL:**
```powershell
# Test webhook directly
$Body = @{ text = "Test notification" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri $WebhookUrl -Body $Body -ContentType "application/json"
```

**Check GitHub Secret:**
```bash
gh secret list | grep TEAMS_WEBHOOK
```

### WorkIQ Queries Failing

**Verify permissions:**
1. Open Microsoft 365 Copilot
2. Check WorkIQ skill is enabled
3. Verify all required permissions are granted

**Test WorkIQ directly:**
```bash
gh copilot squad workiq "test query"
```

### Messages Not Being Detected

**Check monitoring frequency:**
```bash
# View recent Ralph runs
gh run list --workflow=squad-heartbeat.yml --limit 10
```

**Verify channel configuration:**
```json
// Check .squad/skills/teams-monitor/config.json
{
  "monitored_channels": [...]
}
```

**Test keyword matching:**
Post test message with configured keywords and verify it appears in WorkIQ query.

## Security Considerations

### Webhook Security

- Never commit webhook URLs to Git
- Store webhooks in GitHub Secrets
- Rotate webhook URLs quarterly
- Use HTTPS for all webhooks

### WorkIQ Permissions

- Grant minimum required permissions
- Review WorkIQ access logs regularly
- Disable WorkIQ when not needed
- Use service account for automation

### Data Privacy

- Be mindful of sensitive information in Teams/email
- Don't automatically create issues for private channels
- Sanitize message content before creating issues
- Follow your organization's data retention policies

## Best Practices

1. **Start with one channel** - Test thoroughly before expanding
2. **Use clear keywords** - Make it obvious how to trigger Squad
3. **Set expectations** - Document response times in Teams channel description
4. **Monitor false positives** - Adjust keywords if too many non-issues are created
5. **Provide feedback loop** - Let users close auto-created issues easily
6. **Regular reviews** - Weekly review of Teams-to-issue conversion accuracy

## Support

For integration issues:
1. Check workflow logs: `gh run list --workflow=squad-issue-notify.yml`
2. Review Ralph logs: `.squad/logs/ralph-watch.log`
3. Test webhook: Use curl to verify Teams webhook is responsive
4. Create issue with label `squad:picard` for help

## Future Enhancements

- Bidirectional sync (update Teams when issue status changes)
- Rich message formatting (adaptive cards)
- Thread-based conversations (track issue progress in Teams thread)
- Slack integration (similar bridge for Slack channels)
- Email digest (daily summary of new issues)
