# Design Document: Squad Skills Marketplace Publication

**Issue:** #685 — Publish Squad skills to tamirdresher/squad-skills marketplace
**Author:** Seven (Research & Docs)
**Date:** 2026-03-14
**Status:** Ready for Review

---

## Executive Summary

Publish 7 generalized skills from `.squad/skills/` to the public [tamirdresher/squad-skills](https://github.com/tamirdresher/squad-skills) marketplace. These skills are AI-platform agnostic — they work with GitHub Copilot, Claude, ChatGPT, or any LLM-based agent.

The marketplace currently has **11 plugins**. This batch adds 7 new skills, bringing the total to **18 plugins**.

---

## Current State

### Already Published (11 plugins)

| Plugin | Status |
|--------|--------|
| cross-machine-coordination | ✅ Published |
| fact-checking | ✅ Published |
| github-distributed-coordination | ✅ Published |
| github-multi-account | ✅ Published |
| github-project-board | ✅ Published |
| news-broadcasting | ✅ Published |
| outlook-automation | ✅ Published |
| reflect | ✅ Published |
| squad-email-headless | ✅ Published |
| teams-monitor | ✅ Published |
| teams-ui-automation | ✅ Published |

### New Skills to Publish (7 skills)

| # | Skill | Source | Generalization Effort |
|---|-------|--------|----------------------|
| 1 | **session-recovery** | `.squad/skills/session-recovery/` | Low — remove Ralph references, parameterize paths |
| 2 | **blog-publishing** | `.squad/skills/blog-publishing/` | Medium — remove specific accounts, generalize workflow |
| 3 | **tts-conversion** | `.squad/skills/tts-conversion/` | Low — already mostly generic, remove issue refs |
| 4 | **birthday-celebration** | `.squad/team-birthdays.json` + ceremonies | High — extract pattern from team data, build from scratch |
| 5 | **upstream-monitor** | `.squad/upstream.json` + `_upstream_repos/` | High — extract pattern from config, build from scratch |
| 6 | **notification-routing** | `.squad/routing.md` | Medium — generalize routing table, remove agent names |
| 7 | **voice-writing** | `.squad/skills/voice-writing/` | Medium — parameterize author identity, remove personal refs |

---

## Generalization Strategy

### What Was Removed

Every skill was scrubbed of squad-specific references:

| Original Reference | Generalized To |
|-------------------|----------------|
| `Ralph` (work monitor agent) | "background/monitoring sessions" |
| `Neelix`, `Troi`, `Scribe`, `Picard` | Generic role descriptions |
| `tamirdresher` / `tamirdresher_microsoft` | `{publishing_account}` / `{work_account}` |
| `tamirdresher.github.io` | `{blog_repo}` |
| `DK8S`, `Distributed Kubernetes`, `FedRAMP` | Removed entirely |
| `.squad/` paths | `{config_root}/` or `{project_root}/` |
| `workiq-ask_work_iq` tool | Generic "collaboration platform query" |
| `nano-banana` (Gemini) | Generic "image generation tool" |
| Issue/PR numbers (#214, #224, etc.) | Removed |
| Microsoft-specific email addresses | `user@example.com` |

### What Was Kept

- Core algorithms and patterns (FTS5 queries, routing logic, etc.)
- Technology choices with alternatives (edge-tts with Azure upgrade path)
- Error recovery procedures
- Anti-patterns and gotchas from real-world use

---

## Skill Package Structure

Each skill follows the established marketplace convention:

```
plugins/
  {skill-name}/
    manifest.json     # Machine-readable metadata
    SKILL.md          # Agent-consumable knowledge (the core)
    README.md         # Human-readable documentation
```

### Manifest Format

All manifests follow the existing pattern:

```json
{
  "name": "{skill-name}",
  "version": "1.0.0",
  "description": "One-line description",
  "author": "tamirdresher",
  "license": "MIT",
  "platforms": ["github-copilot", "claude", "chatgpt", "any-llm"],
  "triggers": ["keyword1", "keyword2"],
  "tags": ["category1", "category2"],
  "capabilities": ["What it can do 1", "What it can do 2"]
}
```

---

## Skill Details

### 1. Session Recovery

**Purpose:** Find and resume recently closed AI agent sessions.

**Key features:**
- 6 ready-to-use SQL queries (recent sessions, topic search, directory filter, etc.)
- Background session exclusion filter (configurable keywords)
- FTS5 query expansion guidance
- Resume workflow template

**Triggers:** `recover session`, `find session`, `resume session`, `lost session`, `recent sessions`

---

### 2. Blog Publishing

**Purpose:** Multi-account GitHub workflow for publishing blog content.

**Key features:**
- Step-by-step publishing workflow with safety checks
- Account switching guard (always switch back to work account)
- Configuration template for multi-account setup
- Error recovery table
- Automation script template

**Triggers:** `publish blog`, `deploy blog`, `push to blog`, `blog workflow`

---

### 3. TTS Conversion

**Purpose:** Convert markdown documents to audio using Text-to-Speech.

**Key features:**
- Complete markdown-to-plaintext stripping pipeline (Python)
- Three TTS engine options (edge-tts free, Azure paid, generic)
- Batch conversion support
- Voice selection table
- Verification step for output quality

**Triggers:** `convert to audio`, `text to speech`, `generate podcast`, `audio summary`

---

### 4. Birthday Celebration

**Purpose:** Automated team birthday and celebration tracking.

**Key features:**
- Privacy-safe JSON registry format (MM-DD only, no birth year)
- Upcoming birthday checker in PowerShell and Python
- Message templates for birthdays, anniversaries, milestones
- Multi-channel delivery (webhooks, email, GitHub issues)
- Schedule configuration for automated checks

**Triggers:** `birthday`, `team birthday`, `upcoming birthdays`, `celebration`

---

### 5. Upstream Monitor

**Purpose:** Track changes in upstream/dependency repositories.

**Key features:**
- Registry format with configurable watch filters (commits, releases, PRs)
- Git mirror-based sync workflow
- Breaking change detection via commit message keywords
- Change digest generator with markdown output
- PowerShell sync script

**Triggers:** `check upstream`, `upstream changes`, `dependency updates`, `sync upstream`

---

### 6. Notification Routing

**Purpose:** Route work to the right handler using domain expertise matching.

**Key features:**
- JSON routing table with keyword/label matching
- Scoring algorithm for handler selection
- Label-based issue triage workflow
- AI agent fitness evaluation (🟢/🟡/🔴 assessment)
- Urgency-based notification delivery (critical → low)
- Multi-agent routing patterns (primary/secondary/escalation)

**Triggers:** `route work`, `assign task`, `triage issue`, `who handles`

---

### 7. Voice Writing

**Purpose:** Maintain consistent author voice across AI-generated content.

**Key features:**
- Structured voice profile format (JSON)
- 7-point writing style checklist
- Content type adaptation table (blog, docs, social, email, presentation)
- Automated voice consistency checker (Python)
- Series continuity guidelines
- Sensitive content handling rules

**Triggers:** `write in voice`, `match voice`, `writing style`, `author voice`

---

## Publication Plan

### Phase 1: Review (Current)

- [x] Examine existing skills in `.squad/skills/`
- [x] Audit squad-skills repo structure and conventions
- [x] Prepare all 7 skill packages locally
- [x] Create this design document
- [x] Comment plan on issue #685

### Phase 2: Publish (After Review)

1. Switch to `tamirdresher` account (`gh auth switch --user tamirdresher`)
2. Create feature branch on `squad-skills` repo
3. Copy 7 skill packages to `plugins/` directory
4. Update root `README.md` — add 7 new entries to the plugin table
5. Update plugin count badge from 10 to 18 (note: current count may be 11)
6. Open PR with all changes
7. Switch back to `tamirdresher_microsoft` account

### Phase 3: Post-Publication

- Update issue #685 with PR link
- Verify all SKILL.md files render correctly on GitHub
- Test that manifest.json files are valid JSON
- Cross-reference "See Also" links between skills

---

## Updated README Plugin Table (Preview)

After publication, the plugin table will include these new entries:

```markdown
| [🔄 session-recovery](plugins/session-recovery/) | Find and resume recently closed AI agent sessions | `recover session`, `find session`, `resume session` |
| [📝 blog-publishing](plugins/blog-publishing/) | Multi-account GitHub workflow for publishing blog posts | `publish blog`, `deploy blog`, `blog workflow` |
| [🎙️ tts-conversion](plugins/tts-conversion/) | Convert markdown documents to audio using TTS | `convert to audio`, `text to speech`, `generate podcast` |
| [🎂 birthday-celebration](plugins/birthday-celebration/) | Automated team birthday tracking with notifications | `birthday`, `celebration`, `upcoming birthdays` |
| [📡 upstream-monitor](plugins/upstream-monitor/) | Track changes in upstream/dependency repositories | `check upstream`, `dependency updates`, `sync upstream` |
| [🔀 notification-routing](plugins/notification-routing/) | Route work to handlers by domain expertise | `route work`, `triage issue`, `who handles` |
| [✍️ voice-writing](plugins/voice-writing/) | Maintain consistent writing voice for AI content | `write in voice`, `match voice`, `writing style` |
```

---

## Files Prepared

All skill packages are ready at:

```
docs/squad-skills-publish/
├── session-recovery/
│   ├── manifest.json
│   ├── SKILL.md
│   └── README.md
├── blog-publishing/
│   ├── manifest.json
│   ├── SKILL.md
│   └── README.md
├── tts-conversion/
│   ├── manifest.json
│   ├── SKILL.md
│   └── README.md
├── birthday-celebration/
│   ├── manifest.json
│   ├── SKILL.md
│   └── README.md
├── upstream-monitor/
│   ├── manifest.json
│   ├── SKILL.md
│   └── README.md
├── notification-routing/
│   ├── manifest.json
│   ├── SKILL.md
│   └── README.md
└── voice-writing/
    ├── manifest.json
    ├── SKILL.md
    └── README.md
```

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Squad-specific references leak into public repo | All skills scrubbed; no internal names, accounts, or project refs remain |
| Manifest format mismatch | All manifests follow exact pattern of existing plugins (reflect, news-broadcasting) |
| Broken cross-references | All "See Also" links use relative paths matching marketplace structure |
| Skills too niche | Every skill is parameterized — users configure their own accounts, teams, webhooks |
| Version conflicts | All skills start at v1.0.0 with clear upgrade path |
