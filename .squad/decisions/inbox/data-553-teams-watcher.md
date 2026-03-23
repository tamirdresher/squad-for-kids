# Decision: Teams Conversation Watcher — Design Adopted (#553)

**Date:** 2026-03-23  
**Author:** Data  
**Status:** Active

## Summary

Implemented a Teams message queue watcher for Ralph (Issue #553).

- **Queue file:** `research/active/teams-queue.json`
- **Watcher script:** `scripts/teams-conversation-watcher.ps1`
- **Design doc:** `research/active/teams-conversation-watcher/README.md`

## Integration Notes

The watcher module exposes three public functions:
- `Add-TeamsMessageToQueue` — call from Ralph's WorkIQ scan phase
- `Invoke-TeamsConversationWatcher` — call once per patrol round
- `Complete-QueueItem` — mark a conversation done

Wire into `ralph-watch.ps1` prompt as described in Phase 2 of the README.

## Trigger Words

`keep going`, `continue`, `track this`, `remember this`, `follow up on this`, `action:`, `keep this`, `queue this`
