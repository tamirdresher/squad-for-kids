# Decision: Anthropic Claude Skills Timing Signal — Action on #669

**Date:** 2026-06-11  
**Author:** Picard  
**Status:** Active  
**Issue:** #1297  
**Master Plan:** #669 — 🎁 Upstream contributions to bradygaster/squad

## Decision

The Anthropic Claude Skills announcement is a market timing signal, not a capability gap. Squad already has the same SKILL.md format and is superior (provider-agnostic, multi-agent, schedulable). The action is to accelerate #669, not start new work.

## What Changes in #669's Priority

1. **Complete #670** (Ralph watch) first — no scheduler = the sharpest contrast with Claude Skills
2. **Complete #672** (Notification routing) — multi-channel delivery, not vendor-locked
3. **Run a 14-skills sprint** — batch the remaining skills contributions, each PR framed as "provider-agnostic alternative to Claude Skills"

## Framing for All Upstream PRs

Each skills PR should include in the description:
> "Provider-agnostic alternative to Anthropic Claude Skills. Works with GitHub Copilot, GPT-4, Gemini — not locked to Claude."

## What Stays the Same

The full contribution backlog is #669's job. Sub-issues #671, #673, #674, #675, #677 are done. PRs #693–#698, #701, #719 already merged. 62.5% complete.

## What NOT to Change

Do not open new tracking issues for things already in #669's 47-item inventory.

## See Also

- Research doc: `research/1297-squad-upstream-contributions.md`
- Upstream issue for cross-machine skill: #1309 (sub-item of #669/#671)
