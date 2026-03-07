# WorkIQ Query Template — DK8S Support Channel

> Channel: DK8S Support Queue (Teams)
> Signal priority: HIGH — Primary incident and support channel
> Scan order: 1 (first)

## Query Templates

### Template 1: Recent Support Activity

```
What messages were posted in the DK8S Support channel between {{DATE_FROM}} and {{DATE_TO}}? Include the sender name, timestamp, and full message content. Focus on support requests, incident reports, and resolution updates.
```

### Template 2: Escalations and Blockers

```
What escalations, blockers, or urgent requests were discussed in the DK8S Support channel between {{DATE_FROM}} and {{DATE_TO}}? Include who escalated, what was blocked, and any resolution provided.
```

### Template 3: Decisions and Action Items

```
What decisions were made or action items assigned in the DK8S Support channel between {{DATE_FROM}} and {{DATE_TO}}? Include who decided, what was decided, and any follow-up actions.
```

---

## Signal Patterns

Items from this channel are high-signal for these QMD categories:

| QMD Category | Likelihood | Typical Patterns |
|-------------|-----------|-----------------|
| Blockers & Resolutions | **High** | Incident reports, troubleshooting threads, resolution confirmations |
| Decisions | **Medium** | Triage decisions, escalation routing, workaround approvals |
| Contacts & Relationships | **Medium** | New team members asking questions, SME escalation targets |
| Commitments | **Low** | SLA promises, fix timelines |
| Pattern Changes | **Low** | Recurring incident patterns, new failure modes |

## Dedup Notes

- High overlap with `incidents` channel — many incidents cross-posted
- Use fingerprint dedup to avoid counting the same incident twice
- Support threads often span multiple messages — group by thread ID when available

## Noise Filters

Drop these patterns before QMD classification:

- Bot notifications (e.g., "Pipeline build succeeded")
- Auto-generated ticket acknowledgments
- Simple "thanks" or emoji-only responses
- Repeated status pings with no new information
