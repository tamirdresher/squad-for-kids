# Decision: Squad Skills Marketplace — Batch 2 Publication

**Author:** Seven
**Date:** 2026-03-14
**Issue:** #685

## Decision

Publish 7 generalized skills to `tamirdresher/squad-skills`:

1. session-recovery
2. blog-publishing
3. tts-conversion
4. birthday-celebration
5. upstream-monitor
6. notification-routing
7. voice-writing

## Key Choices

- All skills are AI-platform agnostic (Copilot, Claude, ChatGPT, any LLM)
- Squad-specific references fully scrubbed (no agent names, no internal projects, no personal accounts)
- Each skill has manifest.json + SKILL.md + README.md following existing repo convention
- Skills prepared locally at `docs/squad-skills-publish/` — no PR created yet pending review
- `news-broadcasting` and `reflect` already published in batch 1, not duplicated

## Impact

- Public marketplace grows from 11 → 18 plugins
- Any AI agent team can adopt these skills via the marketplace
- Our squad-specific versions in `.squad/skills/` remain untouched
