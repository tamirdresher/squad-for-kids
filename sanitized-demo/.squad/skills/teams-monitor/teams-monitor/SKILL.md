---
name: "teams-monitor"
description: "Monitor Microsoft Teams channels via WorkIQ for actionable messages directed at the squad, and bridge them into GitHub issues"
domain: "communication-bridge"
confidence: "low"
source: "manual"
---

## Context

The squad has two-way Teams communication:
- **READ**: WorkIQ (`workiq-ask_work_iq`) reads Teams messages
- **SEND**: Teams Incoming Webhook sends messages to Teams

The webhook URL is stored as an environment variable `TEAMS_WEBHOOK_URL` or can be invoked directly via `Invoke-RestMethod`.

### Sending Messages to Teams

The webhook URL is stored at `C:\Users\YourNamedresher\.squad\teams-webhook.url` (NOT in the repo — it's a secret).

To send a message to Teams, read the URL from that file and POST:

```powershell
$webhookUrl = Get-Content "$env:USERPROFILE\.squad\teams-webhook.url" -Raw
$body = @{ text = "Your message here" } | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl.Trim() -Method Post -ContentType "application/json" -Body $body
```

**IMPORTANT**: Never hardcode the webhook URL. Always read from `~\.squad\teams-webhook.url`.

## Trigger

- **Scheduled (Primary)**: Runs every 20 minutes via Ralph's loop using `.squad/schedule.json` and Squad Scheduler (task ID: `teams-message-monitor`)
- **Session start**: Any agent session can run the Teams check as part of initialization
- **On-demand**: Any agent can invoke this skill when asked to "check Teams"

The scheduled check uses the script at `.squad/scripts/teams-monitor-check.ps1` which is dispatched by the Squad Scheduler engine.

## Workflow

### Step 1: Query WorkIQ for Recent Messages

Run targeted WorkIQ queries to find messages relevant to the squad. Use the `workiq-ask_work_iq` tool with questions like:

```
"What messages were sent in the last 24 hours in Teams channels related to DK8S, idk8s, or Defender Kubernetes?"
```

```
"Are there any recent Teams messages from YourName Dresher or the DK8S team mentioning squad, AI agents, research, or action items?"
```

```
"What are the most recent Teams messages in channels I'm part of that mention infrastructure analysis, Aurora, ConfigGen, or fleet management?"
```

**Adapt queries to the squad's active work.** Check `decisions.md` and open GitHub issues for current topics, then query for those topics specifically.

### Step 2: Filter for Actionable Content

Not every Teams message is actionable. Look for:

- **Direct requests**: "Can you look into...", "We need...", "Please investigate..."
- **Questions awaiting answers**: "Has anyone figured out...", "What's the status of..."
- **Decisions or announcements** that affect squad work: policy changes, priority shifts, new requirements
- **Mentions of squad-related keywords**: squad, agent, Picard, research, analysis
- **Escalations or incidents**: Sev2, outage, breaking change, urgent

Ignore:
- Social/casual messages
- Messages the squad has already processed (check existing GitHub issues for duplicates)
- Automated notifications (build results, PR notifications — these are already in GitHub/ADO)

### Step 3: Create GitHub Issues

For each actionable item, create a GitHub issue with:

- **Title**: `[Teams Bridge] <concise summary of the request>`
- **Labels**: `teams-bridge`, plus any relevant domain labels
- **Body** must include:
  - Source: who said it, approximate when, which channel/thread (as reported by WorkIQ)
  - The actual request or question, quoted
  - Any context or urgency indicators
  - `---`
  - `🔗 Bridged from Teams via WorkIQ by teams-monitor skill`
  - `📅 Detected: <timestamp>`

### Step 4: Deduplicate

Before creating an issue, search existing GitHub issues for:
- Similar title text
- The `teams-bridge` label
- Recent issues (last 7 days) covering the same topic

If a match is found, add a comment to the existing issue instead of creating a duplicate.

### Step 5: Log Activity

After each check, log what was found (or that nothing was found) so the team knows monitoring is active. This can be a brief note in the orchestration log or session output.

## Queries Reference

These are starting-point queries. Agents should adapt based on current squad context:

| Purpose | WorkIQ Query |
|---------|-------------|
| General channel check | "What recent Teams messages mention DK8S, squad, or AI agents?" |
| YourName's directives | "What did YourName Dresher say recently in Teams about priorities or action items?" |
| Incident awareness | "Are there any recent Teams messages about outages, Sev2 incidents, or urgent issues related to Kubernetes or DK8S?" |
| Meeting follow-ups | "What action items came out of recent DK8S team meetings?" |
| Topic-specific | "Any recent Teams discussion about [current topic from decisions.md]?" |

## Limitations

- **Read-only**: WorkIQ cannot post to Teams. Responses must go through GitHub issues/comments
- **Query freshness**: WorkIQ results may have indexing delay (typically minutes, occasionally hours)
- **No real-time streaming**: This is poll-based, not event-driven. Messages may be picked up with delay
- **Channel visibility**: WorkIQ can only see channels the authenticated user has access to
- **No thread-level precision**: WorkIQ may not distinguish individual thread replies — treat results as approximate
- **First implementation**: Confidence is LOW. Expect iteration on query patterns, filtering heuristics, and deduplication logic

## Anti-Patterns

- **Spamming WorkIQ**: Don't run queries more than once per session or per Ralph cycle. Rate-limit yourself
- **Creating issues for everything**: Be selective. Not every Teams message is an action item
- **Ignoring duplicates**: Always check for existing issues before creating new ones
- **Hardcoding channel names**: Channels change. Use topic-based queries, not channel-name queries
- **Treating WorkIQ as real-time**: It's indexed search, not a live feed. Design for eventual consistency

## Future Evolution

1. **Confidence → medium**: After 2-4 weeks of operation, tune queries and filters based on false positive/negative rates
2. **Bidirectional bridge**: When Teams bot or webhook becomes available, extend to push GitHub activity summaries to Teams
3. **Smart prioritization**: Use message sentiment, sender role, and keyword urgency to auto-prioritize bridged issues
4. **Channel-specific profiles**: Build per-channel query templates as the team learns which channels matter most

