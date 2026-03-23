# Research: Anthropic Claude Skills — Squad's Superior Response
**Issue:** #1297  
**Parent Plan:** #669 — 🎁 Upstream contributions to bradygaster/squad — master plan  
**Researcher:** Picard  
**Date:** 2026-06-11  
**Status:** Complete — aligns with and extends #669

---

## Scope of This Document

Issue #1297 was triggered by a LinkedIn post about something Anthropic published. This document answers:
1. What exactly Anthropic published and why it matters
2. How Squad's existing work (tracked in master plan #669) is the better answer
3. Which specific items from #669's 47 innovations address this directly
4. What the next concrete action is

**This document does NOT re-audit the full upstream contribution backlog.** That work lives in #669 with its 47-item inventory, PRD, and 8 sub-issues. Read #669 first for the full picture.

---

## 1. What Anthropic Published

Anthropic released **"The Complete Guide to Building Skills for Claude"** — a formal specification for packaging reusable agent workflows as portable bundles. The format:

```
skill-name/
├── SKILL.md        # YAML frontmatter (trigger metadata) + Markdown instructions
├── scripts/        # Optional: executable code
├── references/     # Optional: documentation
└── assets/         # Optional: templates, icons
```

### The SKILL.md Format

```yaml
---
name: sprint-planner
description: >
  Manages project sprint workflows. Use when user mentions "sprint",
  "create tasks", or "backlog planning".
compatibility: claude-code, claude.ai
---
```

Claude uses **three-level progressive disclosure**: scan frontmatter on every message → load body only if relevant → load assets on demand. This optimizes context window usage.

### Why Anthropic Is Positioning This as Novel

- Published with full marketing around "reusable agent knowledge"
- Framed as the answer to "how do you make agent behavior consistent across projects"
- Presented as a new primitive for the AI ecosystem

---

## 2. The Reality: Squad Already Solved This

**Squad's `.squad/skills/` system is the exact same concept — and was built first, and works better.**

The upstream `bradygaster/squad` repo has the SKILL.md template at `.squad/skill.md` with identical structure: YAML frontmatter with `name`, `description`, `domain`, `confidence`, `source`, plus optional `tools` list. The format is live and deployed.

### Why Squad's Answer is Objectively Better

| Dimension | Anthropic Claude Skills | Squad Skills |
|-----------|------------------------|--------------|
| **Model lock-in** | Claude Code / Claude.ai only | Any LLM — Copilot, GPT, Gemini |
| **Cross-agent** | Single Claude instance | Multi-agent: coordinator + specialists |
| **Scheduling** | None — session-only | Ralph scheduler (cron-like background loop) |
| **Persistence** | Session-scoped | Git-backed, versioned, auditable |
| **Multi-machine** | None | Cross-machine task queue (git-based) |
| **Marketplace** | Anthropic-controlled | Open, community-extensible |
| **Trigger system** | YAML description | Same — `description:` field drives routing |
| **Progressive loading** | Three-level | Same — body loaded on-demand |
| **Production deployments** | Announced as new | Running daily for 6+ months in tamresearch1 |

**The problem isn't the format.** Squad's format is equivalent. The problem is **visibility**: upstream bradygaster/squad currently ships **7 skills**. Anthropic's launch shows the market wants a rich library. We have **50+ production-tested skills**.

---

## 3. Which Items in #669's 47 Address This Directly

The master plan (#669) already identified and prioritized the full contribution backlog. The Anthropic announcement is a **timing signal** — it makes certain items more urgent.

### Tier 1: Direct Response to Claude Skills (most relevant)

These items from #669 are Squad's concrete answer to Anthropic's format:

| Item from #669 | Category | Status | Why It Responds to Anthropic |
|----------------|----------|--------|-------------------------------|
| **Session recovery skill** | Skills | ✅ Done (#675) | Already contributed — proof Squad skills work |
| **Directive capture skill** | Skills | ✅ Done (#677) | Decisions inbox = persistent agent memory |
| **Neelix news reporter** | Prompt Patterns | ✅ Done (#673) | Shows multi-agent skill specialization |
| **Team celebrations** | Plugins | ✅ Done (#674) | Shows installable plugin model |
| **Fact-checking skill** | Skills | In inventory | Direct parallel to Claude's reasoning skills |
| **News broadcasting skill** | Skills | In inventory | Rich media output capability |
| **Project board skill** | Skills | In inventory | Workflow automation capability |
| **Notification routing** | Infrastructure | 🔄 Open (#672) | Shows multi-channel delivery (not Teams-locked) |

### Tier 2: Where Squad's Superiority is Most Visible

These are the items where Squad demonstrably **beats** Anthropic's model:

| Item from #669 | Category | Why It Goes Beyond Claude Skills |
|----------------|----------|----------------------------------|
| **Ralph persistent watch** | Infrastructure | 🔄 Open (#670) — Claude Skills have no scheduler. Ralph runs 24/7. |
| **Multi-machine coordination** | Infrastructure | ✅ Done (#671) — Claude Skills can't dispatch GPU tasks to another machine |
| **Cross-machine task queue** | Infrastructure | Done — git-based, no additional infra needed |
| **Schedule system (schedule.json)** | Templates | Done — cron-like background agent invocation |
| **Upstream monitor** | Plugins | 🔄 Open (#676) — squads that watch their own dependencies |

### Tier 3: Narrative Assets (what tells the story)

| Item from #669 | Category | Role |
|----------------|----------|------|
| **14 Skills contributions** | Skills | The library that makes "Squad > Claude Skills" visible |
| **Plugin marketplace pattern** | Templates | The extensibility model Claude's closed marketplace can't match |
| **Ceremonies** (design review, retro) | Ceremonies | Process primitives that don't exist in Claude Skills at all |

---

## 4. What #1297 Adds to the Master Plan

The master plan (#669) focuses on **what to build and contribute**. Issue #1297 adds:

1. **Timing:** Anthropic's launch makes this urgent. The window to position Squad as the better answer is now, not in Phase 4.
2. **Framing:** We need explicit language in the upstream PRs and README that positions Squad's skills as provider-agnostic alternatives to Claude Skills.
3. **Priority shift:** The 14 skills contributions (currently scattered across phases) should be front-loaded.

### The Gap in #669 That #1297 Identifies

Looking at #669's phase plan:
- Phase 1: Foundation (Ralph watch, schedule, ceremonies, foundational skills)
- Phase 4: Advanced (multi-machine, RFC needed)

The **skills library contributions** (14 skills) don't have a dedicated phase — they're spread across phases and sub-issues. Given Anthropic's launch, we should:
1. Group all skill contributions into a single "Skills Sprint"
2. Add explicit "why this beats Claude Skills" language to each PR description
3. Publish a comparison document in the Squad docs

---

## 5. Recommended Actions

### Immediate (this week)
1. **Prioritize #672** (Notification routing) and **#670** (Ralph watch) — the two remaining infrastructure items. These show capabilities Claude Skills literally cannot match (multi-channel, scheduled).
2. **Add framing language** to pending upstream PRs: "provider-agnostic alternative to Claude Skills"

### Near-term (next 2 weeks)
3. **Skills Sprint**: Batch the 14 skills contributions into sequential small PRs. Each shows a concrete use case Claude Skills can't replicate cross-vendor.
4. **Comparison doc**: Add `docs/skills-vs-claude-skills.md` to upstream PR — not combative, just honest about the architecture differences.

### Strategic
5. **Blog post / LinkedIn thread**: Once 20+ skills are upstream, Tamir writes "We built Claude Skills before Anthropic did — and ours works with any LLM." References the bradygaster/squad skills directory as evidence.

---

## 6. Status of Remaining #669 Sub-Issues

From the Ralph status update in #669 (2026-03-16):

| Issue | Title | Status |
|-------|-------|--------|
| #670 | Ralph persistent watch | 🔄 In Progress |
| #671 | Multi-machine coordination | ✅ Done |
| #672 | Notification routing | 🔄 In Progress |
| #673 | Neelix news reporter | ✅ Done |
| #674 | Team celebrations | ✅ Done |
| #675 | Session recovery | ✅ Done |
| #676 | Upstream monitor | 🔄 In Progress |
| #677 | Directive capture | ✅ Done |

**62.5% complete on sub-issues.** Plus PR #719 and PRs #693–#698, #701 already merged upstream.

---

## 7. Conclusion

The LinkedIn post Tamir shared is a **market signal**, not a technical gap. Anthropic published a format. Squad already has that format — and more. The action is:

1. Complete the 3 remaining sub-issues in #669 (especially #670 + #672 — they show what Anthropic *can't* do)
2. Accelerate the 14 skills contributions with explicit provider-agnostic framing
3. Turn the library size disparity (50+ vs 7) into a public narrative

See #669 for the full contribution plan. This research scopes the specific Anthropic angle.

---

## References

- **Master plan:** #669 — 🎁 Upstream contributions to bradygaster/squad  
- **Sub-issues:** #670, #671, #672, #673, #674, #675, #676, #677  
- **Upstream PRs already merged:** #693–#698, #701, #719 (bradygaster/squad)  
- **Anthropic source:** https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf  
- **Upstream skill.md template:** `bradygaster/squad/.squad/skill.md`  
- **Local skills (50+):** `tamresearch1/.squad/skills/`
