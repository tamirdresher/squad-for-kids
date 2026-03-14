# Decision: Telegram Bot Token Storage Strategy

**Date:** 2026-07-18
**Author:** Data (Code Expert)
**Issue:** #543
**Status:** Implemented

## Context

Tamir created @tamir_squad_bot via BotFather. The token was provided in the issue body. We needed a secure storage strategy compatible with the existing bot script architecture.

## Decision

Store the token in three locations with a priority resolution chain:

1. `$env:TELEGRAM_BOT_TOKEN` — environment variable (CI/CD, ephemeral sessions)
2. `~/.squad/telegram-bot-token` — plain text file (simple, direct, new)
3. `~/.squad/telegram-config.json` — structured config (existing, includes `allowed_chat_ids`)
4. Windows Credential Manager — (existing fallback)

## Rationale

- The token file approach (#2) is simplest for humans to inspect/update
- The JSON config (#3) already existed and supports additional settings like `allowed_chat_ids`
- Both are in `~/.squad/` which is outside the repo — no risk of git commit
- Added `telegram-bot-token` to `.gitignore` as defense-in-depth

## Action Items

- [ ] Tamir: Consider `/revoke` via BotFather and re-issue token (it's in the issue body)
- [ ] Tamir: Send a message to @tamir_squad_bot to get your chat ID, then add it to `allowed_chat_ids` in `~/.squad/telegram-config.json`
