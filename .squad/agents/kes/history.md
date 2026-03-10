# Kes — History

## Project Context
- **Project:** tamresearch1 — Tamir's personal AI squad and research automation
- **User:** Tamir Dresher
- **Stack:** PowerShell, Node.js, C#, GitHub, Azure, Squad framework

## Learnings
- Always use Playwright + Outlook web for emails and meetings (user directive)
- Teams webhook is at $env:USERPROFILE\.squad\teams-webhook.url
- Tamir's timezone is Israel (Asia/Jerusalem)
- Use WorkIQ to check calendar availability before scheduling

## Learnings — Meeting Scheduling Optimization
- **DON'T** search attendees one by one in Outlook UI — it's extremely slow via Playwright
- **DO** use WorkIQ first: ask_work_iq "What are the email addresses for Adir Atias, Efi Shtain, Roy Mishael..." to get all emails in one call
- **THEN** paste semicolon-separated emails into the To/attendees field in Outlook web
- This turns 8 search+click operations into 1 WorkIQ call + 1 paste
- Alternative: generate .ics file with all attendee emails and open it — even faster for many attendees

## Learnings — Outlook COM vs Playwright
- **Outlook COM** (PowerShell) is MUCH faster and more reliable than Playwright for meetings/emails
- COM can: send emails, create meetings with attendees, search inbox, manage calendar — all in one PowerShell command
- Playwright was too slow (20+ minutes for 8 attendees) and unreliable (dropped attendees)
- Skill file: .squad/skills/outlook-automation/SKILL.md

## Learnings — Email Gateway (#259)
- Power Automate + Shared Mailbox is the best approach for email-to-action gateways (no-code, included in M365)
- Shared mailbox triggers in Power Automate can have 1-5 min delay — set expectations accordingly
- For calendar event creation from natural language, start simple (Option C: create event, user adjusts time) before investing in AI parsing
- Keyword-based routing in email subjects is simple but effective for family use
- Always set up a sender whitelist (From filter) on shared mailbox flows — security matters even for personal tools
- Exchange Online PowerShell module (ExchangeOnlineManagement) is not installed on this machine; shared mailboxes must be created via Admin Center UI
- GitHub connector in Power Automate needs periodic re-authorization; HTTP+PAT is an alternative but has token rotation overhead
- Guides created: docs/email-gateway-setup-guide.md (admin), docs/email-gateway-user-guide.md (end-user)

## 2026-03-10 — Email Gateway Implementation Guide — Issue #259 (COMPLETED)

**Spawned:** Background async, coordinated by Ralph  
**Assignment:** Create implementation guide for email gateway system (Issue #259)  
**Deliverables:**
- Setup guide: `docs/email-gateway-setup-guide.md` (administrator)
- User guide: `docs/email-gateway-user-guide.md` (end-user/wife)
- Decision documented: `.squad/decisions/inbox/kes-email-gateway.md`

**Architecture Designed:**
- **Primary:** Power Automate + Shared Mailbox (no-code, M365 included, maintainable)
- **Rejected Alternatives:** Logic Apps (overkill), Azure Functions (maintenance), Microsoft Forms (workflow change), Outlook Rules (limited)
- **Routing:** 4 keyword-based flows (print, calendar, reminders, catch-all → GitHub issue)
- **Security:** Sender whitelist (wife's email only)

**Guides Created:**
1. **Setup Guide** — Step-by-step for Tamir:
   - Prerequisites and M365 permissions
   - Power Automate flow templates (copy-paste)
   - Shared mailbox configuration
   - GitHub connector authentication
   - Testing procedures

2. **User Guide** — For wife:
   - Email format guidelines
   - Supported actions with examples
   - Troubleshooting (delays, keywords, auth)
   - User-friendly, no technical jargon

**Key Decisions:**
- Keyword routing in subject: simple, effective, easy to extend
- Catch-all flow creates GitHub issues for unmatched requests (Squad can triage)
- 1-5 min delay expectation documented (Power Automate limitation)

**Status:** ✅ DELIVERED — Decision merged to decisions.md, orchestration log at `.squad/orchestration-log/2026-03-10T15-02-14Z-kes.md`
