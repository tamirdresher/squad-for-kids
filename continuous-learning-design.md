# Continuous Learning System — Design Document

> **Issue:** [#6](https://github.com/tamirdresher_microsoft/tamresearch1/issues/6) — Create mechanism for squad to continuously monitor DK8S and ConfigGen Teams channels  
> **Author:** Picard (Lead)  
> **Date:** 2026-07-04  
> **Status:** Proposed

---

## 1. Problem Statement

The squad operates in sessions — each session starts fresh with only `.squad/` history as context. Meanwhile, the DK8S and ConfigGen support channels generate continuous signal: production incidents, recurring failure patterns, architectural decisions, and cross-team coordination. Today, this knowledge is trapped in Teams threads and dies between sessions.

**The gap:** The squad has no mechanism to absorb real-time operational knowledge from Teams channels. Every session starts at the same knowledge baseline regardless of what happened yesterday.

**What we lose:**
- Recurring support patterns (capacity starvation, SFI enforcement breakages, ConfigGen modeling gaps) are re-discovered instead of pre-loaded
- Cross-team coordination context (BAND/DK8S ownership boundaries, provisioning governance) is invisible to the squad
- Emerging issues (Key Vault tenant migrations, Karpenter node bootstrap failures) can't be anticipated

---

## 2. Teams Channels to Monitor

| Channel | Team | Signal Type | Priority |
|---|---|---|---|
| **DK8S Clusters (Kubernetes) – Support** | Infra and Developer Platform Community | Production incidents, cluster failures, deployment issues | **P0** |
| **ConfigGen SDK – Support** | Infra and Developer Platform Community | Feature gaps, enforcement breakages, modeling questions | **P0** |
| **DK8S Platform Leads** | Infra and Developer Platform Community | Architecture decisions, governance, provisioning strategy | **P1** |
| **DK8S & BAND Platform Leads Collaboration** | Cross-team | Ownership boundaries, RBAC alignment, operational friction | **P2** |

---

## 3. Architecture

### 3.1 Data Flow

```
Teams Channels
     │
     ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│   WorkIQ    │────▶│  Digest Script   │────▶│  Squad Knowledge    │
│  (MCP Tool) │     │  (Session Start) │     │                     │
└─────────────┘     └──────────────────┘     │  .squad/digests/    │
                           │                  │  .squad/skills/     │
                           │                  │  .squad/history.md  │
                           ▼                  └─────────────────────┘
                    ┌──────────────────┐
                    │  Pattern Extractor│
                    │  (Skill Builder) │
                    └──────────────────┘
```

### 3.2 Core Components

#### A. Channel Scanner (WorkIQ Polling)

At the start of each squad session, a designated agent (Ralph or Picard) queries WorkIQ for recent activity:

```
workiq-ask_work_iq: "What are the most recent issues, decisions, and discussions 
in [channel name] over the last [N] days? Focus on: production incidents, 
recurring problems, architectural decisions, and cross-team coordination."
```

**Key constraint:** WorkIQ queries are scoped to the authenticated user's access. The user (Tamir) must have visibility into these channels for this to work.

#### B. Digest Generator

Transforms raw WorkIQ responses into structured digest files:

```
.squad/digests/
├── YYYY-MM-DD-dk8s-support.md
├── YYYY-MM-DD-configgen-support.md
├── YYYY-MM-DD-dk8s-leads.md
└── YYYY-MM-DD-band-collab.md
```

Each digest follows a standard format:
```markdown
# DK8S Support Digest — 2026-07-04
## Period: Last 7 days

### Active Incidents
- [Brief description, root cause, status]

### Recurring Patterns
- [Pattern name: frequency, impact, typical resolution]

### Decisions Made
- [Decision, who made it, implications]

### Open Questions
- [Unresolved items requiring follow-up]
```

#### C. Pattern Extractor (Skill Builder)

Analyzes digests over time to identify recurring patterns worth promoting to skills:

**Promotion criteria:**
1. Pattern appears in 3+ digests across 2+ weeks
2. Pattern has a clear trigger → diagnosis → resolution flow
3. Pattern is actionable by squad agents

**Output:** New entries in `.squad/skills/` following the SKILL.md format:

```yaml
---
name: "dk8s-capacity-starvation"
description: "DK8S pod scheduling failures caused by cluster capacity exhaustion"
domain: "dk8s-operations"
confidence: "high"
source: "teams-channel-learning"
learned_from: "DK8S Clusters (Kubernetes) – Support"
first_seen: "2026-06-15"
---
```

#### D. History Updater

Appends key findings to agent history files so context persists across sessions:
- New architectural decisions → `history.md` under "## Learnings"
- Cross-team coordination changes → relevant agent histories
- Emerging risks → Worf's security history

---

## 4. Recurring Patterns Already Identified

From the initial WorkIQ research, these patterns are already promotion-ready:

### DK8S Support Patterns
| Pattern | Frequency | Root Cause |
|---|---|---|
| Pod scheduling / capacity starvation | Weekly | Cluster-level capacity exhaustion, not workload misconfig |
| Node bootstrap failures (Karpenter + AKS) | Weekly | VM extension failures before kubelet registration |
| Azure platform issues misattributed to DK8S | Bi-weekly | CRP incidents surfacing as K8s reliability problems |
| Identity / Key Vault role coupling at cluster scope | Monthly | Service-level blast radius from cluster-scoped decisions |

### ConfigGen Support Patterns
| Pattern | Frequency | Root Cause |
|---|---|---|
| SFI enforcement breaking builds | Weekly | Permissive → enforced transitions without advance warning |
| Auto-generated config causing deployment failures | Weekly | Implicit defaults (e.g., duplicate role assignments) |
| Modeling gaps (Azure features ConfigGen can't express) | Ongoing | Edge cases beyond golden path coverage |
| CI/CD validation gaps | Bi-weekly | AppSettings not validated, config regressions reaching prod |
| PR review bottleneck | Daily | Narrow reviewer set for shared dependency |

---

## 5. Implementation Phases

### Phase 1: Manual Scan Protocol (Week 1)
**Effort:** Low — process only, no code

- Define a "Channel Scan" ceremony in `.squad/ceremonies.md`
- At the start of each session, Picard or Ralph runs 4 WorkIQ queries (one per channel)
- Manually write digest to `.squad/digests/`
- Promote the 9 patterns above to `.squad/skills/` immediately

**Deliverables:**
- `.squad/digests/` directory with digest template
- `.squad/skills/dk8s-support-patterns/SKILL.md`
- `.squad/skills/configgen-support-patterns/SKILL.md`
- Updated ceremonies.md with Channel Scan protocol

### Phase 2: Automated Digest Script (Week 2-3)
**Effort:** Medium — scripting required

- Create `.squad/scripts/channel-scan.md` — a prompt template that any agent can execute
- Standardize WorkIQ query templates per channel
- Define digest merging rules (deduplicate across days, mark resolved incidents)
- Add digest rotation (keep last 30 days, archive older)

**Deliverables:**
- `.squad/scripts/channel-scan.md` prompt template
- Digest rotation logic
- Agent-executable scan protocol

### Phase 3: Skill Accumulation Pipeline (Week 4-6)
**Effort:** Medium-High — pattern recognition

- Build pattern extraction logic: scan last N digests, identify recurring themes
- Auto-generate SKILL.md candidates in `.squad/skills/candidates/`
- Human review gate: Tamir or Picard approves promotion from `candidates/` to `skills/`
- Track pattern evolution (frequency trending, resolution drift)

**Deliverables:**
- Pattern extraction prompt template
- `.squad/skills/candidates/` staging area
- Promotion workflow documentation

### Phase 4: GitHub Actions Integration (Optional, Week 6+)
**Effort:** High — requires GitHub Actions + WorkIQ API access

- GitHub Actions cron job (daily) that:
  1. Invokes a Copilot session with channel-scan prompt
  2. Commits digest to `.squad/digests/`
  3. Opens PR if new skill candidates are identified
- **Blocker:** Requires WorkIQ/Graph API access from GitHub Actions runner, which may not be available

**Deliverables:**
- `.github/workflows/channel-scan.yml`
- Automated PR creation for skill candidates

---

## 6. Limitations and Constraints

### WorkIQ Access Constraints
- **User-scoped:** WorkIQ can only access channels the authenticated user (Tamir) is a member of
- **No real-time streaming:** WorkIQ is query-response, not event-driven. We poll, not subscribe
- **Recency bias:** WorkIQ retrieval quality may degrade for messages older than 30 days
- **Rate limits:** Unknown explicit limits, but excessive polling in a single session may hit throttling
- **No programmatic API:** WorkIQ is an MCP tool invoked within Copilot sessions — it cannot be called from GitHub Actions or cron jobs without a Copilot session wrapper

### Knowledge Staleness
- Digests are point-in-time snapshots. Between scans, new incidents may occur
- Skill promotion requires pattern repetition, so novel issues won't be captured as skills immediately
- Resolution of incidents may not be captured if the fix happens in a different channel or medium (email, ADO work items)

### Signal-to-Noise
- Support channels contain both high-signal (production incidents, architectural decisions) and low-signal (PR review pings, simple questions with known answers)
- The digest generator must filter aggressively — not every message is worth persisting
- Risk of digest bloat if filtering is too permissive

### Privacy and Compliance
- Per Decision 7 (Community Engagement Protocol), no confidential information from Teams channels should be exposed in public repositories
- Digests must be treated as internal artifacts — `.squad/digests/` should be in `.gitignore` if the repo is public
- Skill files should contain patterns and resolutions, not verbatim messages or people's names

---

## 7. Success Metrics

| Metric | Target | How to Measure |
|---|---|---|
| Session context freshness | < 7 days stale | Age of most recent digest at session start |
| Known pattern coverage | 80%+ of recurring issues pre-loaded | Compare support thread topics to existing skills |
| Time to first useful response | < 5 min on known patterns | Measure agent response time on previously-seen issues |
| Skill library growth | 2-3 new skills/month | Count `.squad/skills/` entries over time |
| False positive rate | < 20% of promoted skills | Track skills that are never referenced after promotion |

---

## 8. Recommended Approach

**Start with Phase 1 immediately.** The manual scan protocol requires zero infrastructure, uses existing WorkIQ access, and delivers value in the first session. The 9 patterns identified in this design doc are ready for skill promotion today.

**Phase 2 is the sweet spot** — it standardizes the process without requiring external infrastructure. A well-crafted prompt template that any agent can execute makes the scan reproducible and consistent.

**Phase 3 is the learning flywheel** — once digests accumulate, pattern extraction becomes the mechanism that turns operational noise into reusable squad intelligence.

**Phase 4 is aspirational** — GitHub Actions integration would make this fully autonomous, but the WorkIQ access constraint makes it uncertain. Defer until Phases 1-3 are proven.

---

## 9. Open Questions

1. **Digest privacy:** Should `.squad/digests/` be gitignored or committed? Committing enables cross-session persistence but exposes internal support content.
2. **Scan frequency:** Per-session scan vs. daily cadence? If sessions are infrequent, daily cron (Phase 4) becomes more valuable.
3. **Multi-agent scan:** Should each agent scan channels relevant to their expertise (Worf scans for security incidents, B'Elanna for infrastructure issues), or should one agent (Ralph) do all scanning?
4. **Digest retention:** How long to keep digests? 30 days? 90 days? Indefinite with archival?
5. **WorkIQ query optimization:** What's the optimal query structure to maximize signal extraction per call?
