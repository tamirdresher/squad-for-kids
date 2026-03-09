# WorkIQ Query Template — IDP ADR Notifications Channel

> Channel: IDP ADR Notifications (Teams)
> Signal priority: HIGH — Architecture Decision Records for IDP platform
> Scan order: N/A (dedicated daily check, not part of general digest pipeline)
> Owner: Picard (Lead)
> Issue: #198

## ⚠️ CRITICAL CONSTRAINT

**READ-ONLY MONITORING ONLY.**
- NEVER comment on the ADR channel
- NEVER comment on any ADR document
- NEVER post replies or reactions
- Only observe, summarize, and report to Tamir privately via Teams webhook

## Channel Details

- **Channel Name:** IDP ADR Notifications
- **Teams URL:** https://teams.microsoft.com/l/channel/19%3A6d7865cdcaab4446a800c51dfc76cbb0%40thread.tacv2/IDP%20ADR%20Notifications?groupId=25cc215a-8287-4155-a51d-833837db2864&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47
- **Group ID:** 25cc215a-8287-4155-a51d-833837db2864

## Query Templates

### Template 1: New and Updated ADRs (Primary)

```
What new messages or notifications were posted in the IDP ADR Notifications channel in the last 24 hours? Include the sender name, timestamp, and full message content. Focus on new ADR proposals, ADR status changes, review requests, and decisions made.
```

### Template 2: Pending Reviews and Decisions

```
Are there any ADR review requests, pending decisions, or calls for feedback in the IDP ADR Notifications channel from the last 24 hours? Who is being asked to review, what is the deadline, and what is the ADR about?
```

### Template 3: Blockers and Escalations

```
Were there any blockers, concerns, escalations, or objections raised about any ADRs in the IDP ADR Notifications channel in the last 24 hours? Include who raised the concern, which ADR it relates to, and what the issue is.
```

---

## Signal Patterns

Items from this channel are high-signal for these categories:

| Category | Likelihood | Typical Patterns |
|----------|-----------|-----------------|
| New ADR Proposals | **High** | "New ADR:", "Proposed:", "RFC:", "ADR-NNN" |
| Review Requests | **High** | "Please review", "Feedback requested", "Review by", "@mentions" |
| Decisions | **High** | "Approved", "Accepted", "Rejected", "Superseded", "Decided" |
| Blockers | **Medium** | "Blocked", "Concern:", "Objection:", "Cannot proceed" |
| Status Changes | **Medium** | "Status changed", "Moved to", "Updated", "Draft → Review" |
| Deadlines | **Medium** | "Due by", "Deadline:", "Review period ends" |

## Items Needing Tamir's Attention

Flag these for Tamir's immediate attention:
1. **New ADRs** that affect IDP platform architecture
2. **Review requests** where Tamir is mentioned or where his input as Lead would be valuable
3. **Decisions made** that could impact Squad's work or platform direction
4. **Blockers** that require leadership input to resolve
5. **Deadlines approaching** for reviews or decisions
6. **Controversial ADRs** with objections or significant discussion

## Noise Filters

Drop these patterns before reporting:
- Bot-generated notifications with no new content
- Simple acknowledgment messages ("Got it", "Thanks", thumbs-up)
- Duplicate notifications for the same ADR state change
- Automated CI/CD status updates related to ADR docs
