# Decision: Family Request Pipeline — Email + WhatsApp

**Date:** 2026-06-23  
**Author:** Kes (Communications & Scheduling)  
**Issue:** #259  
**Status:** Implemented

## Context

Tamir wants his wife Gabi to be able to send requests (print jobs, calendar reminders, shopping lists, todos) that the squad automatically processes. Two input channels were established.

## Decision

### Email Pipeline (td-squad-ai-team@outlook.com)
- Inbox rules auto-route based on content
- Print requests → Dresherhome@hpeprint.com
- Calendar/reminder → GitHub issue with `squad,family-request` labels

### WhatsApp Pipeline (new)
- Ralph monitors WhatsApp Web every 3rd round via Playwright
- Watches for messages from contact "gabi"
- Keywords: print, calendar, reminder, buy, todo
- Creates GitHub issues with `squad,family-request` labels
- Print requests forwarded to HP printer email
- Graceful degradation: skips if WhatsApp Web needs QR reconnection

## Implementation

- Added `WHATSAPP FAMILY MONITORING` section to Ralph prompt in `ralph-watch.ps1`
- Frequency: every 3rd round (to avoid excessive WhatsApp checks)
- Deduplication: checks existing open `family-request` issues before creating new ones
- Notification: Teams message to Tamir after processing family requests

## Risks & Mitigations

- **WhatsApp Web session expiry:** Ralph logs a warning and skips — doesn't block the round
- **Duplicate issues:** Explicit dedup check against open `family-request` labeled issues
- **False positives:** Keyword matching is simple; may trigger on casual messages containing "buy" or "print" — acceptable for family context
