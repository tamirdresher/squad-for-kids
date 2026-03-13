# Squad Knowledge Management — Q2 2026 Strategy

> "Keep it in GitHub, keep it queryable, keep it growing."

## 📋 Overview

This document describes how Squad manages its growing knowledge base (agents, decisions, research) while staying within GitHub constraints and maintaining searchability.

**Current Status (2026-Q2):**
- Total `.squad/` size: ~33.5 MB (and growing)
- Core knowledge: ~3.5 MB of actionable markdown
- Build artifacts: Excluded from repo (saves ~29.5 MB)
- Active history files: Rotated quarterly to prevent bloat

---

## 🔄 Quarterly History Rotation (IMPLEMENTED Q2 2026)

### What Rotates
- **Agent history files** (`.squad/agents/*/history.md`)
- **Decisions archive** (older decisions)
- **Orchestration logs** (transaction-level detail)

### When
- **Every 3 months** (Q1 = Jan-Mar, Q2 = Apr-Jun, etc.)
- Triggered by Ralph work monitor or manual trigger

### How
```bash
# Example: Rotate Seven's history at end of Q1
cd .squad/agents/seven/
mv history.md history-2026-Q1.md
echo "# Seven — History\n\n## Current Quarter (2026-Q2)" > history.md
```

### Result
- Active `history.md` stays < 200 KB
- Archives preserved at `history-2026-Q1.md`, `history-2026-Q2.md`, etc.
- Full history available by browsing archives
- Faster diff/grep operations on active files

---

## 🔍 Search & Discovery

### Option 1: Copilot Space (RECOMMENDED — Implemented Q2 2026)

**GitHub Copilot Space: "Research Squad"**
- **Location:** https://github.com/copilot/spaces (search for "Research Squad")
- **Owner:** `tamirdresher_microsoft` organization
- **Status:** ✅ Active (Issue #416)

**What it contains:**
- Core `.squad/` files (team.md, routing.md, charter.md, copilot-instructions.md)
- All agent charters (13 active agents)
- Decision log (decisions.md — semantic search enabled)
- Cross-repo research (from tamresearch1-dk8s-investigations, tamresearch1-agent-analysis)

**How to use:**
1. **For humans:** Open Space in GitHub web UI → ask questions naturally
   - Example: "Who handles infrastructure work?"
   - Example: "What decisions were made about memory management?"
2. **For agents:** Reference Space in spawn prompts via MCP server
   - Tool: `github-mcp-server-get_copilot_space` (owner: "tamirdresher_microsoft", name: "Research Squad")
   - Semantic search across all Space content automatically
3. **Auto-sync:** Files linked from GitHub repos stay synced with main branch

**Advantages over file-based search:**
- Cross-repo context (spans multiple repos in one place)
- Semantic search (finds conceptually related content, not just keywords)
- No size limits on search (858KB decisions.md fully searchable)
- Accessible from any GitHub Copilot interface (IDE, web, CLI)

**Limitations:**
- Read-only for agents (can't update Space content directly)
- Curated content (~50 files) to stay within quota
- IDE integration limited (repo-wide search only in web UI)

> **Supplement, don't replace:** `.squad/` files remain source of truth. Space is the **read layer** for cross-repo discovery.

---

### Option 2: GitHub Code Search (Fallback)
```
site:github.com/tamirdresher_microsoft/tamresearch1/blob/main/.squad
path:.squad/decisions.md  "memory management"
```

### Option 3: Local grep/ripgrep
```bash
rg "vector database" .squad/agents/  # Fast full-text search
rg "Issue #321" .squad/decisions.md
```

### Option 4: GitHub CLI
```bash
gh search code --repo tamirdresher_microsoft/tamresearch1 "knowledge base" --match path -- .squad/
```

---

## 📁 Directory Structure & Responsibilities

### Tier 1: Transaction Memory (GITIGNORED)
```
.squad/
├── orchestration-log/  ← Work orchestration records
├── log/                ← Session logs (detailed activity)
├── sessions/           ← Copilot session state
└── raw-agent-output.md ← Raw AI generation output
```
**Rationale:** High volume, short-lived, may contain PII. Regenerated per session.

### Tier 2 & 3: Permanent Knowledge (COMMITTED)
```
.squad/
├── agents/             ← Agent context & history (quarterly rotate)
├── decisions.md        ← Team decision log
├── decisions/archive/  ← Resolved decisions
├── skills/             ← Permanent skills (never delete)
├── templates/          ← Reusable templates
├── roster.md           ← Team member info
├── charter.md          ← Mission & governance
└── KNOWLEDGE_MANAGEMENT.md ← THIS FILE
```
**Rationale:** Actionable, collaborative, historical value. Always versioned.

---

## 🚀 Implementation Checklist (Q2 2026)

- [x] **Rotate Q1 agent histories** to `history-2026-Q1.md`
- [x] **Create fresh Q2 history files** with current-quarter header
- [x] **Update `.gitignore`** to exclude build artifacts + future vector DB
- [x] **Create this guide** (KNOWLEDGE_MANAGEMENT.md)
- [x] **Create Copilot Space** "Research Squad" for cross-repo knowledge (Issue #416)
- [x] **Add core .squad/ files to Space** (~20 curated files)
- [ ] **Create INDEX.md files** in each major directory (TBD next sprint)
- [ ] **Monitor growth:** Check `.squad/` size monthly; alert if >50MB

---

## 📊 Growth Monitoring

**Manual check (run monthly):**
```bash
du -sh .squad/  # macOS/Linux
ls -d .squad -h  # Windows PowerShell: (gci .squad -r | measure -p length -sum).sum / 1mb
```

**Alert Conditions:**
- Total `.squad/` > 50MB → Consider splitting decisions.md
- Any single file > 5MB → Likely needs archival
- Build artifacts in git → Re-check .gitignore

---

## 📦 Copilot Space Integration Details

### Files Included in Space (Curated for Quota)

**Core Team Structure (4 files):**
- `.squad/team.md` — Squad roster & capability profile
- `.squad/routing.md` — Work routing rules & label system
- `.squad/charter.md` — Mission & governance
- `.squad/copilot-instructions.md` — Agent behavior guidelines

**Agent Charters (13 files):**
- `.squad/agents/picard/charter.md` — Lead
- `.squad/agents/belanna/charter.md` — Infrastructure Expert
- `.squad/agents/worf/charter.md` — Security & Cloud
- `.squad/agents/data/charter.md` — Code Expert
- `.squad/agents/seven/charter.md` — Research & Docs
- `.squad/agents/podcaster/charter.md` — Audio Content
- `.squad/agents/q/charter.md` — Devil's Advocate
- `.squad/agents/scribe/charter.md` — Session Logger
- `.squad/agents/kes/charter.md` — Communications
- `.squad/agents/ralph/charter.md` — Work Monitor
- `.squad/agents/troi/charter.md` — Blogger
- `.squad/agents/neelix/charter.md` — News Reporter
- `.squad/agents/@copilot/capability-profile.md` (if exists)

**Knowledge & Decisions (3 files):**
- `.squad/KNOWLEDGE_MANAGEMENT.md` — This file
- `.squad/decisions.md` — Decision log (large, 858KB, high value)
- `.squad/research-repos.md` — Research repo catalog

**Total: ~20 files, ~3 MB** (well within Space quotas)

### Custom Instructions (Configured in Space)
```
You are assisting the Research Squad — an AI agent team using Star Trek TNG/Voyager
personas. The team includes Picard (Lead), Seven (Research & Docs), B'Elanna (Infrastructure),
Worf (Security & Cloud), Data (Code), and others.

Context files describe agent charters, routing rules, and team decisions. When answering:
- Respect agent boundaries and routing rules in routing.md
- Reference decisions.md for past team decisions
- Use team.md roster for current member capabilities
- Follow copilot-instructions.md for agent behavior standards

This Space supplements the .squad/ file system in the repository — files here are read-only
context. The source of truth for editable content remains in the git repository.
```

### Maintenance Protocol

**When to update Space content:**
1. **Major agent roster changes** (new agent added/removed) → update team.md in Space
2. **Routing rule changes** → update routing.md in Space
3. **Charter updates** → update relevant charter files in Space
4. **Quarterly history rotation** → No action (Space excludes history files)

**How to update:**
- GitHub automatically syncs linked files from main branch
- No manual refresh needed for files linked from repos
- For uploaded files, re-upload via Space UI

**Space lifecycle:**
- **Created:** 2026-Q2 (Issue #416)
- **Review cadence:** Quarterly (aligned with history rotation)
- **Ownership:** Seven (Research & Docs)

---

## 🔮 Phase 3: Vector Database (Future, Deferred)

**Status:** DEFERRED — Copilot Space semantic search (Phase 1, implemented) addresses the core need

**Original Phase 2 plan (now Phase 3, if needed later):**
- Add ChromaDB indexing for local/offline semantic search
- Useful if: Space quotas become limiting OR offline access needed
- See research findings in `.squad/decisions.md` → "Decision: Knowledge Management Strategy"

---

## ✅ Best Practices

1. **Keep active history.md lean** (<200 KB target)
   - Archive quarterly, don't delete
   
2. **Decisions.md stays focused**
   - Only active/recent decisions
   - Resolved decisions → `decisions/archive/YYYY-QQ.md`

3. **Always search before duplicating**
   - Use GitHub search or local grep before starting new work
   - Link to previous related decisions

4. **Index new major sections**
   - Create `INDEX.md` in directories > 10 files
   - Format: bullet list with brief description

5. **Git history is your friend**
   - `git log --follow .squad/agents/seven/history*.md` → see all Seven's rotations
   - `git blame .squad/decisions.md` → see who made each decision

---

## 🆘 Troubleshooting

**Q: My history file is 500KB+, is that a problem?**
A: Not yet, but it means we're due for rotation. Rotate to `history-YYYY-QQ.md` and start fresh.

**Q: Can I delete old history files?**
A: No — they're permanent record. Move to `/archive/` if truly obsolete, but keep searchable.

**Q: How do agents access this?**
A: Currently: file-based (read markdown). Phase 2 will add vector DB query API.

**Q: Why not just use a wiki?**
A: We could, but: (1) Wiki duplicates work, (2) loses git history, (3) violates "keep it in GitHub" constraint.

---

## 📚 Further Reading

- **Research Report:** `.squad/decisions.md` → "Decision: Knowledge Management Strategy for Squad Knowledge Base (Issue #321)"
- **Agent Onboarding:** `.squad/charter.md`, `.squad/roster.md`
- **GitHub Code Search Docs:** https://docs.github.com/en/search-github/searching-on-github/searching-code

---

**Last Updated:** 2026-Q2 (Phase 1 Implementation)  
**Owned By:** Seven (Research & Docs)  
**Review Cadence:** Monthly growth check, quarterly rotation
