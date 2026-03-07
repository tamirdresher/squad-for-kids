# Issue-Triager — Classification Taxonomy & Sub-Agent Pattern

> Template for channel scanner classification, priority scoring, and escalation.
> Transforms channel scanning from passive capture to active triage.
> Source: OpenCLAW sub-agent pattern (https://trilogyai.substack.com/p/openclaw-in-the-real-world)
> Adopted for Squad: Issue #23

## Purpose

The Channel Scanner currently captures messages but doesn't classify them. The Issue-Triager adds a classification layer that categorizes every captured item, assigns priority, applies escalation rules, and maintains a JSONL audit trail. This turns channel data from "a pile of messages" into "a prioritized, searchable, auditable queue."

---

## Classification Taxonomy

Every captured item is classified into exactly one category.

### Category 1: Incident 🔴

An active or developing problem affecting production systems, user experience, or SLA compliance.

**Signal words:** down, broken, failing, outage, incident, degraded, crash, error rate, alert firing, pages, SEV, P0, P1, urgent

**Examples:**
- "Node pool in eastus2 is not scheduling pods"
- "Pipeline failures spiked to 40% in the last hour"
- "Customer-facing API returning 503s"

**Default priority:** P0 or P1 (based on blast radius)

### Category 2: Decision 🟡

A choice being made, discussed, or needing input. Architectural decisions, process changes, tool adoptions.

**Signal words:** decided, proposing, should we, option A vs B, ADR, RFC, approve, vote, consensus, tradeoff

**Examples:**
- "Proposing we switch from Helm 3.12 to 3.14 for all clusters"
- "ADR-0015: Should we adopt Karpenter for node autoscaling?"
- "Team agreed to deprecate v1 API by end of Q2"

**Default priority:** P2 (unless blocking other work → P1)

### Category 3: Question ❓

A request for information, clarification, or guidance. Someone needs help understanding something.

**Signal words:** how do I, what is, where can I find, anyone know, help with, documentation for, confused about

**Examples:**
- "How do I configure KEDA for our custom metrics?"
- "What's the process for adding a new cluster to inventory?"
- "Where are the runbooks for certificate rotation?"

**Default priority:** P3 (unless blocking incident response → P1)

### Category 4: Coordination 🔵

Scheduling, handoffs, status updates, team logistics. Operational glue that keeps work moving.

**Signal words:** meeting, standup, handoff, status update, FYI, heads up, OOO, sprint, retro, planning

**Examples:**
- "I'll be OOO next week, B'Elanna is covering on-call"
- "Sprint review moved to Thursday 2pm"
- "FYI: deploying ConfigGen v4.3 to PPE tonight"

**Default priority:** P3 (unless time-sensitive coordination → P2)

---

## Priority Labels

| Priority | Label | SLA (Response) | SLA (Resolution) | Description |
|----------|-------|----------------|-------------------|-------------|
| **P0** | 🔴 Critical | 15 minutes | 4 hours | Production down, data loss risk, security breach |
| **P1** | 🟠 High | 1 hour | 24 hours | Degraded service, blocked deployments, SLA at risk |
| **P2** | 🟡 Medium | 4 hours | 1 week | Decisions needed, non-urgent bugs, process improvements |
| **P3** | 🔵 Low | 24 hours | Best effort | Questions, coordination, informational items |

### Priority Scoring Rules

Score each item on three dimensions (1-3 scale), sum for priority:

| Dimension | 1 (Low) | 2 (Medium) | 3 (High) |
|-----------|---------|------------|----------|
| **Blast Radius** | Single user/team | Multiple teams | Customer-facing / org-wide |
| **Time Sensitivity** | Can wait days | Should handle today | Must handle now |
| **Reversibility** | Easily reversed | Recoverable with effort | Irreversible / data loss |

**Score mapping:**
- **7-9 → P0** (Critical)
- **5-6 → P1** (High)
- **3-4 → P2** (Medium)
- **1-2 → P3** (Low)

---

## Escalation Criteria

### Auto-Escalate to P0

Trigger immediate escalation (notify Picard + on-call) when ANY of these conditions are met:

1. **Keywords detected:** "production down", "data loss", "security breach", "SEV1", "customer impact"
2. **Multiple related incidents:** 2+ incidents on the same component within 1 hour
3. **SLA breach imminent:** P1 item unresolved for >20 hours (approaching 24h SLA)
4. **Explicit escalation:** Message contains "escalate", "need help now", "paging"

### Auto-Escalate to P1

1. **Blocked deployment:** Any message indicating deployment is blocked
2. **Repeated question:** Same question asked 3+ times without resolution (indicates documentation gap)
3. **Cross-team dependency:** Blocker involving multiple teams with no owner

### Do Not Escalate

1. Routine status updates
2. FYI messages with no action required
3. Questions already answered in thread
4. Coordination messages about future events (>48h away)

---

## JSONL Audit Trail

Every triaged item is appended to a JSONL file for searchability and compliance.

**File location:** `.squad/digests/triage/triage-YYYY-MM.jsonl`

**Schema:**

```json
{
  "id": "triage-2026-03-05-001",
  "timestamp": "2026-03-05T14:23:00Z",
  "source_channel": "#dk8s-support",
  "source_message_id": "msg-abc123",
  "category": "incident",
  "priority": "P1",
  "priority_score": {
    "blast_radius": 2,
    "time_sensitivity": 3,
    "reversibility": 1
  },
  "title": "Pipeline failures spiked to 40% in eastus2",
  "summary": "CI pipeline failure rate increased from 2% to 40% in the last hour. Affecting 3 teams. No deployment impact yet.",
  "escalated": false,
  "escalation_reason": null,
  "assigned_to": null,
  "status": "open",
  "resolved_at": null,
  "resolution": null,
  "tags": ["pipeline", "eastus2", "ci-cd"],
  "raw_text_hash": "sha256:abc123..."
}
```

**Field rules:**
- `id`: Format `triage-{date}-{sequence}`, auto-incrementing per day
- `raw_text_hash`: SHA-256 of original message text (for deduplication, not storing raw PII)
- `status`: `open` → `in_progress` → `resolved` | `wont_fix` | `duplicate`
- `tags`: Auto-extracted keywords for searchability

---

## Sub-Agent Configuration

The Issue-Triager runs as a sub-agent of the Channel Scanner. It inherits the parent's context but has a focused scope.

```yaml
name: issue-triager
parent: channel-scanner
authority:
  - classify items using taxonomy above
  - assign priority labels (P0-P3)
  - append to JSONL audit trail
  - escalate P0/P1 items (notify Picard + on-call)
restrictions:
  - cannot modify channel messages
  - cannot close/resolve items without human confirmation
  - cannot change priority after human override
  - P0 escalations require confirmation within 5 minutes
schedule:
  - trigger: on new channel message captured
  - fallback: batch process every 15 minutes
output:
  - append to .squad/digests/triage/triage-YYYY-MM.jsonl
  - P0/P1: immediate notification
  - P2/P3: included in daily digest
```

---

## Querying the Audit Trail

The JSONL format enables fast querying without a database:

```bash
# All P0 incidents this month
cat triage-2026-03.jsonl | jq 'select(.priority == "P0")'

# Unresolved items older than 24 hours
cat triage-2026-03.jsonl | jq 'select(.status == "open" and .timestamp < "2026-03-04T00:00:00Z")'

# Items by category
cat triage-2026-03.jsonl | jq 'select(.category == "decision")'

# Escalation audit
cat triage-2026-03.jsonl | jq 'select(.escalated == true)'

# Tag frequency (what topics dominate?)
cat triage-2026-03.jsonl | jq '.tags[]' | sort | uniq -c | sort -rn
```

---

## Integration with Squad

```
Channel Messages → Channel Scanner → Issue-Triager → Triage JSONL
                                         ↓                  ↓
                                    P0/P1: Alert       QMD Extraction
                                    P2/P3: Digest      Dream Routine
```

- **Channel Scanner** captures raw messages → passes to Issue-Triager
- **Issue-Triager** classifies, prioritizes, writes audit trail
- **P0/P1 items** trigger immediate notification to Picard + on-call
- **P2/P3 items** flow into daily digest → QMD extraction → Dream Routine
- **Audit trail** enables compliance review, pattern analysis, and calibration

## Calibration Process

Weeks 1-2 after adoption:
1. Human reviews every P0/P1 classification (catch false positives)
2. Weekly calibration meeting: review 10 random triage decisions
3. Adjust signal words and scoring rules based on false positive/negative rate
4. Target: <10% false positive rate on P0/P1 by week 3
