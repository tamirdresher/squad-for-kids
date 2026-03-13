# Skill: Outlook Web Workflows
**Confidence:** low
**Domain:** communication, automation
**Last validated:** 2026-03-13

## Context
Extracted from Kes's charter. Playwright-based workflows for Outlook web when COM automation is unavailable. Prefer Outlook COM (see `.squad/skills/outlook-automation/SKILL.md`) when Outlook is installed.

## Pattern

### Creating Meetings via Playwright
1. Navigate to https://outlook.office.com/calendar
2. Click "New event"
3. Fill title, date, time, attendees (search by name)
4. Add description/agenda
5. Enable Teams meeting
6. Send

### Sending Emails via Playwright
1. Navigate to https://outlook.office.com/mail
2. Click "New mail"
3. Add recipients (search by name)
4. Fill subject and body
5. Send

## Decision Tree

- **Outlook installed on Windows?** → Use Outlook COM (`.squad/skills/outlook-automation/SKILL.md`)
- **No Outlook / macOS / Linux?** → Use these Playwright workflows
- **WorkIQ available?** → Use for people lookup and calendar checks before creating events
