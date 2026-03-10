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
