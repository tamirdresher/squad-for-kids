# Decision: Kids Squad "Fork and Go" Design

- **Author:** Picard
- **Date:** 2025-07-17
- **Status:** 🟡 PROPOSED
- **Requested by:** Tamir Dresher

## Problem

Tamir wants his kids (and other Israeli school kids) to have a zero-config path to getting their own AI Squad team. Current setup requires PowerShell scripts and manual configuration — too much friction for an 8-year-old.

## Solution

Design a `tamirdresher/kids-squad-setup` repo where:
1. Kid forks the repo
2. Opens Codespace (or VS Code with Copilot)
3. Types "שלום" in Copilot Chat
4. AI responds in Hebrew, guides setup interactively
5. Kid gets a working age-appropriate Squad team

## Key Design Decisions

1. **Hebrew-first UX** — copilot-instructions.md triggers Hebrew on greeting
2. **Age-adaptive** — 3 tiers: young (8-10), builder (11-13), advanced (14+)
3. **Hebrew agent names** — מורה, מתכנת, בודק, חוקר, מעצב, מזכיר
4. **Discord for notifications** (simplest webhook API for kids)
5. **Copilot free tier mitigation** — 4-layer strategy: tracking → coaching → fallback AI links → offline scripts
6. **Zero-install via Codespace** — devcontainer with Node.js, Python, Hebrew extensions
7. **Safety rules** — No homework copying, age-appropriate content, no personal data collection

## Full Design

See: `kids-squad-onboarding-design.md` (written to session state)

## Open Questions for Tamir

1. Public or private repo?
2. Hebrew-only or bilingual agent names?
3. Discord or Telegram primary?
4. Copilot Pro for Shira?
5. Include Ralph (autonomous monitor)?
6. Blog series tie-in?

## Consequences

- Enables any Israeli kid to get a working AI team in 5 minutes
- Requires Copilot instructions file to be very carefully written (it IS the UX)
- Free tier limits are real — offline mode is essential, not optional
- Testing with all 3 kids (ages 8, 13, 15) is required before public launch
