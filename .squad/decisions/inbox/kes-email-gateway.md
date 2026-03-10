# Decision: Email Gateway Architecture

**Date:** 2025-07-24  
**Author:** Kes (Communications & Scheduling)  
**Issue:** #259  
**Status:** Approved by Tamir

## Decision

Use **Power Automate + Shared Mailbox** to create an email-to-action gateway for Tamir's wife.

## Architecture

- **Shared Mailbox** in Exchange Online as the single entry point
- **4 Power Automate flows** watching the mailbox, routing by keyword:
  - `print` → forward to HP ePrint (`Dresherhome@hpeprint.com`)
  - `calendar/meeting/schedule/event` → create Outlook calendar event
  - `remind/todo/task/remember` → create Microsoft To Do task
  - Catch-all (no keyword match) → create GitHub issue with `squad` + `email-gateway` labels
- **Sender whitelist** restricts processing to wife's email only

## Alternatives Considered

1. **Azure Logic Apps** — More powerful but overkill and costs more
2. **Custom code (Azure Functions)** — Too much maintenance for a personal tool
3. **Microsoft Forms** — Not email-based, changes wife's workflow
4. **Direct Outlook rules** — Can't create To Do tasks or GitHub issues

## Why Power Automate

- Included in M365 license (no extra cost)
- Low-code, easy to maintain and extend
- Native connectors for Outlook, To Do, GitHub
- Shared mailbox trigger is reliable
- Tamir can modify flows without coding

## Team Impact

- Catch-all flow creates GitHub issues labeled `email-gateway` — Squad should watch for these
- Issues are labeled `squad` so they appear in normal triage
- No infrastructure to maintain (fully SaaS)

## Risks

- Power Automate shared mailbox triggers can have 1-5 min delay
- Date parsing for calendar events is imperfect — may need manual adjustment
- GitHub connector requires auth renewal periodically
