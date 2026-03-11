# Decision: Email-to-Action Pipeline for Family Requests

**Author:** Picard  
**Date:** 2026-07-14  
**Issue:** #259  
**Status:** Proposed (pending Tamir approval)

## Context

Tamir wants his wife (Gabi) to be able to send requests that the squad can act on — printing documents, adding calendar events, setting reminders, and general tasks.

## Decision

Recommend **M365 Shared Mailbox + Power Automate** as the email-to-action pipeline:

1. **Print requests** → Forward to `Dresherhome@hpeprint.com`
2. **Calendar requests** → Create Outlook calendar event
3. **Reminders** → Create Outlook Task/To-Do
4. **General requests** → Create GitHub issue with `source:family` label

## Rationale

- Power Automate is native to M365 (no extra cost, no infrastructure)
- Shared mailbox is free with existing M365 license
- WhatsApp automation is fragile and violates ToS — email is more reliable
- Security: sender validation ensures only Gabi's email triggers actions

## Impact

- New label `source:family` for family-originated issues
- Squad may receive non-technical issues (household tasks) — routing rules needed
- No infrastructure changes to existing squad setup

## Team Relevance

All squad members should know that `source:family` labeled issues are household/personal tasks from Tamir's family, not technical work items.
