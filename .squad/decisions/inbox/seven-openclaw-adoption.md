# Decision Record: OpenCLAW Adoption Three-Tier Memory Architecture

**Date:** 2026-03-11  
**Issue:** #66 — OpenCLAW Adoption: Integrate QMD, Dream Routine, Issue-Triager  
**Decision Maker:** Seven (Research & Docs)  
**Status:** PENDING APPROVAL (Ready for team review)

---

## Context

Issue #66 requires integrating four production-ready OpenCLAW templates (QMD, Dream Routine, Issue-Triager, Memory Separation) from PR #57 into Squad's operational workflows. The implementation plan (commit c1e922e) establishes a three-phase roadmap (Memory Separation → QMD/Issue-Triager → Monitoring) with acceptance criteria: "At least 2 weeks of QMD digests collected."

## Decision: Three-Tier Memory Architecture with Git-Based Enforcement

### What We're Deciding

How to organize Squad's memory (digests, reports, decisions, skills) to support scalable pattern analysis without drowning signal in noise.

**The Three Tiers:**

| Tier | Purpose | Examples | Git | Retention | Access |
|------|---------|----------|-----|-----------|--------|
| **Tier 1: Transaction** | Ephemeral raw data | Daily raw digests, per-channel scans, triage logs, session transcripts | ❌ GITIGNORED | 30 days | Current week only |
| **Tier 2: Operational** | Curated signal | QMD archives, Dream reports, decision records | ✅ COMMITTED | Forever | Dream Routine, search, trend analysis |
| **Tier 3: Permanent** | Durable knowledge | Skills, playbooks, validated patterns | ✅ COMMITTED | Forever | All agents, every session |

### Enforcement Mechanism

1. **`.squad/.gitignore`** — Prevents Tier 1 raw files from being committed
2. **`git check-ignore` verification scripts** — Monthly audit to verify tier boundaries
3. **CI/CD rule** — Reject commits containing Tier 1 files
4. **Human oversight** — Monthly audit identifies edge cases automation misses

### Why This Tier Separation

**Problem:** Without explicit separation, all operational data has equal weight in git history. This makes Dream Routine analysis unreliable (signal-to-noise ratio too high) and bloats the repository with ephemeral data.

**Solution:** Separate raw (temporary) from curated (permanent). Let QMD extraction compress Tier 1 → Tier 2 weekly. Only feed Tier 2 data to Dream Routine for pattern analysis.

**Effect:** Pattern analysis becomes more accurate, git history remains searchable, raw data can be cleaned on 30-day rotation without losing institutional knowledge.

## Rationale

### Why Three Tiers (Not Two)?

**Two-tier alternative:** Committed vs. Gitignored
- **Problem:** Committed data includes both raw and curated, mixing signal with noise
- **Impact:** Dream Routine operates on dirty data; hard to distinguish permanent from temporary

**Three-tier solution:** Tier 1 (raw, gitignored) → Tier 2 (curated, committed) → Tier 3 (permanent, human-approved)
- **Benefit:** Clear separation of concern; each tier has explicit retention policy and access pattern
- **Cost:** Added operational rules (which files go where, audit procedures)

### Why Git-Based Enforcement?

**Alternative:** Database + retention policies
- **Problem:** Additional infrastructure to maintain; requires custom scripts
- **Impact:** Higher operational burden; single point of failure

**Git-based solution:** Leverage `.gitignore` + standard git tools
- **Benefit:** Simple, auditable, uses existing infrastructure
- **Cost:** Requires discipline (CI rule + monthly audit)

### Why 30-Day Tier 1 Retention?

**Rationale:**
- Long enough to capture full sprint cycle + post-mortem investigations
- Short enough to not bloat local disk/backups
- Aligns with incident response SLA (most incidents resolved within 1 week, investigations within 2 weeks)

**Rule:** Raw files deleted after 30 days of inactivity. Curated versions (Tier 2) retained forever.

## Trade-Offs

| Trade-Off | Decision | Rationale |
|-----------|----------|-----------|
| Complexity vs. Signal Quality | Accept added complexity | Clear tiers = accurate pattern analysis (Dream Routine reliability) |
| Storage (raw in git) vs. Cleanliness | Keep raw out of git | Gitignored files can be cleaned without losing history (QMD archives retained) |
| Automated cleanup vs. Manual | Monthly human audit | Monthly is sufficient; automation adds fragility for rare edge cases |
| Infrastructure investment | Use git + .gitignore | Leverages existing tools; no new infrastructure needed |

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| **Tier 1 files accidentally committed** | CI rule: Reject commits with Tier 1 files; monthly `git check-ignore` audit |
| **Tier 2/3 files gitignored** | Monthly verification; fix .gitignore rules if issues detected |
| **30-day retention too short** | Tier 2 (QMD archives) retain everything permanently; only raw data rotates |
| **Raw files contain PII** | Gitignored = safe from git history; sanitize before promoting to Tier 2 |
| **Audit not performed** | Calendar reminder (first Monday of month); documented procedure in .squad/.gitignore-rules.md |

## Approval Checklist

- [ ] **Picard** (Lead): Confirms architecture aligns with Squad governance model
- [ ] **Ralph**: Confirms automation requirements understood for QMD/Dream workflows
- [ ] **B'Elanna**: Confirms infrastructure (directories, .gitignore) is implementable
- [ ] **Scribe**: Confirms raw digest generation (Tier 1) will include proper metadata
- [ ] **Team**: No objections after 48-hour review period

## Implementation Status

**Committed artifacts:**
- ✅ `.squad/implementations/66-openclaw-adoption.md` — Full plan (commit c1e922e)
- ✅ `.squad/.gitignore-rules.md` — Architecture & verification procedures
- ✅ `.squad/.gitignore` — Tier 1 enforcement rules
- ✅ `.squad/monitoring/66-metrics.jsonl` — Baseline for metrics

**Pending implementation:**
- 🚧 `.squad/scripts/qmd-extract.ps1` — LLM-powered KEEP/DROP extraction
- 🚧 `.squad/scripts/dream-routine.ps1` — Cross-digest analysis
- 🚧 `.squad/scripts/issue-triager.ps1` — Priority classification
- 🚧 `.github/workflows/qmd-weekly.yml` — Automation trigger
- 🚧 `.github/workflows/dream-routine.yml` — Automation trigger

## Related Decisions

- **Issue #23** — OpenCLAW template initial implementation
- **Issue #22** — Continuous Learning Phase 2 (channel-scan foundation)
- **PR #57** — OpenCLAW template delivery (QMD, Dream Routine, Issue-Triager, Memory Separation)

## References

- `.squad/.gitignore-rules.md` — Detailed tier architecture and enforcement procedures
- `.squad/implementations/66-openclaw-adoption.md` — Full implementation plan with phased rollout
- `.squad/templates/memory-separation.md` — Original template definition
