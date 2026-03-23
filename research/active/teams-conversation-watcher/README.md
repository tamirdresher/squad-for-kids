# Teams Conversation Watcher — Design Doc

> **Issue:** #553  
> **Status:** Phase 1 — Shipped  
> **Branch:** `squad/553-teams-watcher-CPC-tamir-3H7BI`

---

## Problem

Ralph runs on a 5-minute patrol cycle. Teams messages received between rounds were silently ignored — there was no mechanism for Tamir to say "keep this going" and have Ralph act on it continuously.

---

## Solution Overview

A **Teams message queue** persisted as a JSON file (`research/active/teams-queue.json`) that Ralph checks on every patrol round. When Tamir sends a Teams message containing a trigger word, Ralph adds it to the queue. On each subsequent round, Ralph iterates active queue items and checks for replies or follow-ups.

---

## Architecture

```
ralph-watch.ps1 (patrol loop, every 5 min)
       │
       ├─► [existing] WorkIQ Teams scan (TEAMS & EMAIL MONITORING phase)
       │          │
       │          └─► if message contains trigger word ──► Add-TeamsMessageToQueue
       │
       └─► Invoke-TeamsConversationWatcher
                  │
                  ├─► Load  research/active/teams-queue.json
                  ├─► Check active items for new replies
                  └─► Save updated queue
```

---

## Files

| File | Purpose |
|------|---------|
| `scripts/teams-conversation-watcher.ps1` | Main watcher module |
| `research/active/teams-queue.json` | Persistent queue storage |
| `research/active/teams-conversation-watcher/README.md` | This document |

---

## Trigger Words

When any Teams message sent to Tamir contains one of these phrases, it is added to the queue:

- `keep going`
- `continue`
- `track this`
- `remember this`
- `follow up on this`
- `action:`
- `keep this`
- `queue this`

---

## Queue Schema

```json
{
  "version": 1,
  "created": "<ISO timestamp>",
  "updated": "<ISO timestamp>",
  "items": [
    {
      "id":              "<UUID>",
      "messageId":       "<Teams message ID>",
      "threadId":        "<Teams thread/channel ID>",
      "channelId":       "<Teams channel ID>",
      "originalMessage": "The full message text",
      "author":          "Display name",
      "triggeredBy":     "track this",
      "status":          "active",
      "addedAt":         "<ISO timestamp>",
      "lastChecked":     "<ISO timestamp or null>",
      "lastAction":      "checked",
      "checkCount":      3,
      "history": [
        { "timestamp": "...", "action": "added",   "note": "..." },
        { "timestamp": "...", "action": "checked", "note": "..." }
      ]
    }
  ]
}
```

**Status values:** `active` | `paused` | `done`

---

## Ralph Integration

### Automatic (ralph-watch.ps1 prompt)

Ralph's existing prompt already includes a "TEAMS & EMAIL MONITORING" phase that runs WorkIQ every round. The watcher hooks into this naturally:

1. WorkIQ returns Teams messages.
2. For each message with a trigger word, call `Add-TeamsMessageToQueue`.
3. After the WorkIQ scan, call `Invoke-TeamsConversationWatcher`.

To wire this into ralph-watch.ps1, add to the `$prompt` string (after the existing TEAMS & EMAIL MONITORING block):

```
TEAMS CONVERSATION WATCHER (Issue #553):
1. Dot-source scripts/teams-conversation-watcher.ps1 at the start of each round.
2. When WorkIQ returns Teams messages, check each for trigger words using Test-HasTriggerWord.
   Trigger words: "keep going", "continue", "track this", "remember this",
                  "follow up on this", "action:", "keep this", "queue this"
3. For each message with a trigger word: call Add-TeamsMessageToQueue with the message details.
4. After processing new messages, call Invoke-TeamsConversationWatcher to check existing queue items.
5. For each active queue item, check WorkIQ for new messages in that thread:
   workiq-ask_work_iq: "Any new Teams messages in thread {threadId} in the last 10 minutes?"
   If new messages are found — determine if action is needed (create issue, reply, summarise).
6. Log a summary line: "[teams-watcher] added=N checked=N errors=N"
```

### Manual / Standalone

```powershell
# Add a message manually:
. .\scripts\teams-conversation-watcher.ps1
Add-TeamsMessageToQueue `
    -MessageId "1234567890" `
    -ThreadId  "19:abc@thread.tacv2" `
    -Text      "track this — the rate limiter discussion" `
    -Author    "Tamir Dresher"

# Run a watcher round:
Invoke-TeamsConversationWatcher

# Mark a conversation done:
Complete-QueueItem -ThreadId "19:abc@thread.tacv2"
```

---

## Phase 1 (Shipped — this PR)

- [x] Persistent queue (`research/active/teams-queue.json`)
- [x] `Add-TeamsMessageToQueue` — adds messages with trigger words to the queue
- [x] `Invoke-TeamsConversationWatcher` — checks active items each patrol round
- [x] `Complete-QueueItem` — marks a conversation done
- [x] Deduplication by `threadId`
- [x] History tracking per item
- [x] Standalone CLI mode for testing

## Phase 2 (Future)

- [ ] Wire `Invoke-TeamsConversationWatcher` call into `ralph-watch.ps1` patrol loop
- [ ] Use WorkIQ to check each active thread for new messages
- [ ] Auto-create GitHub issues for actionable follow-ups
- [ ] `paused` state with resume-on-keyword
- [ ] Max-age auto-expiry (e.g., items older than 7 days → auto-done)
- [ ] Teams notification when an item is queued or completed

---

## Decision Log

Written to `.squad/decisions/inbox/data-553-teams-watcher.md` after merge.
