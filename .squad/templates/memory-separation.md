# Memory Separation — Transaction vs. Operational vs. Skills

> Rules and directory structure for three-tier memory architecture.
> Separates raw noise from curated signal from permanent knowledge.
> Source: OpenCLAW production pattern (https://trilogyai.substack.com/p/openclaw-in-the-real-world)
> Adopted for Squad: Issue #23

## Purpose

OpenCLAW's default behavior treats all memory the same — everything goes into daily logs. The result: transaction noise drowns out operational signal. Memory separation creates three tiers with different retention policies, access patterns, and version control rules.

---

## Three-Tier Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    TIER 3: SKILLS                       │
│           Permanent • Committed • High-Signal           │
│         .squad/skills/{skill-name}/SKILL.md             │
│                                                         │
│  Retention: Forever                                     │
│  Git: ✅ Always committed                               │
│  Access: All agents, every session                      │
│  Update: Human-approved promotion only                  │
├─────────────────────────────────────────────────────────┤
│                TIER 2: OPERATIONAL (QMD)                │
│          Curated • Committed • Medium-Signal            │
│     .squad/digests/archive/{date}.qmd.md                │
│     .squad/digests/dream/dream-{date}.md                │
│     .squad/decisions/                                   │
│                                                         │
│  Retention: Forever (compressed weekly via QMD)         │
│  Git: ✅ Always committed                               │
│  Access: Dream Routine, trend analysis, search          │
│  Update: QMD extraction process (weekly)                │
├─────────────────────────────────────────────────────────┤
│               TIER 1: TRANSACTION (RAW)                 │
│         Raw • Gitignored • High-Volume                  │
│     .squad/digests/{date}.md (daily raw)                │
│     .squad/digests/triage/triage-{month}.jsonl          │
│     .squad/log/ (raw agent output)                      │
│     .squad/sessions/ (session transcripts)              │
│                                                         │
│  Retention: 30 days, then archive/delete                │
│  Git: ❌ Gitignored (too noisy, may contain PII)       │
│  Access: Current week only (QMD extracts the rest)      │
│  Update: Continuous (every agent run)                   │
└─────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
.squad/
├── skills/                          # TIER 3 — Permanent skills
│   ├── squad-conventions/
│   │   └── SKILL.md
│   ├── dk8s-support-patterns/
│   │   └── SKILL.md
│   └── {new-skill}/
│       └── SKILL.md
│
├── digests/                         # Mixed tiers
│   ├── 2026-03-10.md               # TIER 1 — Raw daily (gitignored)
│   ├── 2026-03-11.md               # TIER 1 — Raw daily (gitignored)
│   ├── archive/                     # TIER 2 — QMD curated (committed)
│   │   ├── 2026-02-24-to-03-02.qmd.md
│   │   └── 2026-03-03-to-09.qmd.md
│   ├── dream/                       # TIER 2 — Dream reports (committed)
│   │   └── dream-2026-03-09.md
│   └── triage/                      # TIER 1 — Triage audit (gitignored)
│       └── triage-2026-03.jsonl
│
├── decisions/                       # TIER 2 — Team decisions (committed)
│   ├── inbox/
│   └── adopted/
│
├── log/                             # TIER 1 — Raw agent output (gitignored)
├── sessions/                        # TIER 1 — Session transcripts (gitignored)
├── orchestration-log/               # TIER 1 — Orchestration logs (gitignored)
│
├── templates/                       # TIER 2 — Templates (committed)
│   ├── qmd-extraction.md
│   ├── dream-routine.md
│   ├── issue-triager.md
│   └── memory-separation.md
│
└── agents/                          # TIER 2 — Agent config (committed)
    └── {agent}/
        ├── charter.md
        └── history.md
```

---

## Retention Rules

| Tier | Content | Retention | Git Status | Cleanup Method |
|------|---------|-----------|------------|----------------|
| **Tier 1: Transaction** | Raw daily digests | 30 days | `.gitignore` | Auto-delete after QMD extraction + 30 days |
| **Tier 1: Transaction** | Triage JSONL | 90 days | `.gitignore` | Archive to compressed file quarterly |
| **Tier 1: Transaction** | Agent logs | 14 days | `.gitignore` | Auto-delete |
| **Tier 1: Transaction** | Session transcripts | 30 days | `.gitignore` | Auto-delete |
| **Tier 2: Operational** | QMD digests | Forever | Committed | Never delete |
| **Tier 2: Operational** | Dream reports | Forever | Committed | Never delete |
| **Tier 2: Operational** | Decisions | Forever | Committed | Never delete |
| **Tier 2: Operational** | Templates | Forever | Committed | Update in place |
| **Tier 3: Skills** | SKILL.md files | Forever | Committed | Archive deprecated skills |

---

## .gitignore Rules

Add these entries to the project `.gitignore` (or `.squad/.gitignore`):

```gitignore
# Tier 1: Transaction memory (raw, high-volume, may contain PII)
.squad/digests/[0-9]*.md
.squad/digests/triage/*.jsonl
.squad/log/
.squad/sessions/
.squad/orchestration-log/
.squad/raw-agent-output.md
.squad/run-output.md

# Do NOT ignore (Tier 2 & 3):
# .squad/digests/archive/     — QMD digests (committed)
# .squad/digests/dream/       — Dream reports (committed)
# .squad/decisions/            — Team decisions (committed)
# .squad/skills/               — Permanent skills (committed)
# .squad/templates/            — Templates (committed)
# .squad/agents/               — Agent config (committed)
```

---

## Data Flow

```
Agent Activity
    │
    ▼
Tier 1: Raw Logs (daily, gitignored)
    │
    ├── After 7 days ──▶ QMD Extraction ──▶ Tier 2: QMD Digest (committed)
    │
    ├── After 30 days ──▶ Auto-delete raw logs
    │
    └── Issue-Triager ──▶ Triage JSONL (Tier 1, 90-day retention)

Tier 2: QMD Digests
    │
    ├── Weekly ──▶ Dream Routine ──▶ Dream Report (Tier 2, committed)
    │
    └── Skill candidates flagged ──▶ Human review ──▶ Tier 3: Skills (committed)

Tier 3: Skills
    │
    └── Consumed by all agents, every session
```

---

## Migration Plan (Existing Squad Data)

To adopt memory separation on existing Squad infrastructure:

### Step 1: Classify Existing Files
- `.squad/digests/*.md` → Tier 1 (gitignore going forward)
- `.squad/digests/archive/*.qmd.md` → Tier 2 (keep committed)
- `.squad/skills/*/SKILL.md` → Tier 3 (keep committed)
- `.squad/log/`, `.squad/sessions/` → Tier 1 (gitignore)

### Step 2: Update .gitignore
Add the gitignore rules listed above.

### Step 3: Create Missing Directories
```bash
mkdir -p .squad/digests/archive
mkdir -p .squad/digests/dream
mkdir -p .squad/digests/triage
```

### Step 4: Begin QMD Extraction
Run the first QMD extraction on existing daily digests to populate `.squad/digests/archive/`.

### Step 5: Validate
- Verify committed files are only Tier 2 and Tier 3
- Verify Tier 1 files are gitignored
- Verify agents can still access current-week raw digests

---

## Principles

1. **Signal rises, noise sinks.** Every tier transition (1→2→3) increases signal density.
2. **Committed = curated.** If it's in Git, a human (or QMD process) reviewed it.
3. **Raw is disposable.** Tier 1 data can always be regenerated. Losing it hurts for a week, not forever.
4. **Skills are permanent.** Tier 3 is institutional knowledge. Deprecate, don't delete.
5. **Privacy by design.** Tier 1 (gitignored) may contain PII. Tier 2/3 (committed) must not.
