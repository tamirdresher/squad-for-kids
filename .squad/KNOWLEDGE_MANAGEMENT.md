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

### For Humans & Agents

**Option 1: GitHub Code Search (Recommended for now)**
```
site:github.com/tamirdresher_microsoft/tamresearch1/blob/main/.squad
path:.squad/decisions.md  "memory management"
```

**Option 2: Local grep/ripgrep**
```bash
rg "vector database" .squad/agents/  # Fast full-text search
rg "Issue #321" .squad/decisions.md
```

**Option 3: GitHub CLI**
```bash
gh search code --repo tamirdresher_microsoft/tamresearch1 "knowledge base" --match path -- .squad/
```

### For Future: Vector Database Index (Phase 2)
When Phase 2 is implemented:
- Markdown source stays in git (source of truth)
- Vector index (`ChromaDB`) regenerated on `git pull` (pre-commit hook)
- Agents query: `vector_search("memory management")` → returns top results
- See **Phase 2** section below

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
- [ ] **Create INDEX.md files** in each major directory (TBD next sprint)
- [ ] **Add GitHub saved searches** for common queries (TBD)
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

## 🔮 Phase 2: Vector Database (Future, If Needed)

**When to activate:** When markdown corpus > 50MB OR semantic search becomes valuable

**Implementation:**
1. Add ChromaDB indexing script (50 lines Python)
2. Add pre-commit hook to regenerate index from markdown
3. Agents query vector DB: `similar_to("memory optimization")` → context
4. Index stored in `.squad/.db/` (gitignored, regenerated on pull)

**Benefits:**
- Semantic search: "agent memory" finds discussions about caching, context windows, etc.
- No reliance on GitHub search UI
- Scalable to large corpora

**Trade-offs:**
- Requires Python environment
- Index rebuild takes ~30s on large repo
- Additional complexity

See research findings in `.squad/decisions.md` → "Decision: Knowledge Management Strategy" for full technical analysis.

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
