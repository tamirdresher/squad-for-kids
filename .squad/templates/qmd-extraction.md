# QMD (Quality Memory Digest) — 5-Category Extraction Framework

> Template for weekly digest compaction. Converts 7 days of raw operational logs into one curated summary.
> Source: OpenCLAW production pattern (https://trilogyai.substack.com/p/openclaw-in-the-real-world)
> Adopted for Squad: Issue #23

## Purpose

90% of what agents log is transactional noise. 5% is operational context. The final 5% — decisions, commitments, pattern changes — is institutional knowledge that should be available forever. QMD separates signal from noise.

## When to Run

- **Frequency:** Weekly (Sunday night / end of sprint)
- **Input:** Raw daily digests from the past 7 days (`.squad/digests/YYYY-MM-DD.md`)
- **Output:** One QMD digest (`.squad/digests/archive/YYYY-MM-DD-to-DD.qmd.md`)

---

## 5-Category Extraction — KEEP

Scan raw digests for these five categories. Each extracted item must include the source date and context.

### Category 1: Decisions Made

Items where the team chose a direction, adopted a standard, or resolved an ambiguity.

**Signal words:** decided, agreed, chose, adopted, approved, rejected, confirmed, standardized, deprecated

**Template:**
```
### Decisions
- [YYYY-MM-DD] {Decision description} — Context: {why}, Impact: {who/what affected}
```

**Example:**
```
- [2026-03-05] Decided to use QMD framework for digest compaction — Context: digest volume drowning signal, Impact: all agents consume cleaner digests
```

### Category 2: Commitments Created

Promises, deadlines, deliverables agreed to — internal or external.

**Signal words:** promised, committed, deadline, due by, will deliver, agreed to, ETA, SLA

**Template:**
```
### Commitments
- [YYYY-MM-DD] {Commitment} — Owner: {who}, Due: {when}, Status: {open/met/missed}
```

**Example:**
```
- [2026-03-06] Committed to delivering Channel Scanner Phase 2 spec by March 20 — Owner: Seven, Due: 2026-03-20, Status: open
```

### Category 3: Pattern Changes

Shifts in behavior, performance, workflow, or external dependencies. Things that used to work one way and now work differently.

**Signal words:** changed, shifted, increased, decreased, started, stopped, new behavior, regression, improvement, trend

**Template:**
```
### Pattern Changes
- [YYYY-MM-DD] {What changed} — Before: {old pattern}, After: {new pattern}, Significance: {high/medium/low}
```

**Example:**
```
- [2026-03-04] Pipeline failure rate increased from 2% to 15% — Before: stable CI, After: flaky node pool tests, Significance: high
```

### Category 4: Blockers & Resolutions

Items that blocked progress and how (or whether) they were resolved.

**Signal words:** blocked, waiting on, dependency, unblocked, resolved, workaround, escalated, stuck

**Template:**
```
### Blockers & Resolutions
- [YYYY-MM-DD] BLOCKED: {description} — Waiting on: {who/what}
- [YYYY-MM-DD] RESOLVED: {description} — Resolution: {how}
```

**Example:**
```
- [2026-03-03] BLOCKED: Cannot test Dream Routine without 5+ QMD digests — Waiting on: data accumulation (ETA week 5)
- [2026-03-07] RESOLVED: ConfigGen version conflict — Resolution: pinned to v4.2.1 across all projects
```

### Category 5: Contacts & Relationships

New people, teams, or external stakeholders encountered. Context that helps future interactions.

**Signal words:** met, introduced, contacted, escalated to, new stakeholder, point of contact, SME

**Template:**
```
### Contacts & Relationships
- [YYYY-MM-DD] {Name} ({role/org}) — Context: {how encountered}, Relevance: {why they matter}
```

**Example:**
```
- [2026-03-05] Jack Chen (DK8S Platform Lead) — Context: escalated node health issue, Relevance: approves infra changes
```

---

## 5-Category Extraction — DROP

The following categories are noise. Do NOT carry them forward into QMD digests.

### Drop 1: Routine Operations

Day-to-day actions with no lasting significance.

**Examples to drop:**
- "Checked email at 3:15 PM, no urgent items"
- "Ran daily standup, no blockers"
- "Merged PR #45 (routine dependency update)"
- "Responded to ping in Teams"

### Drop 2: Ephemeral Context

Temporary information that loses relevance after the action completes.

**Examples to drop:**
- "User mentioned needing to update config file"
- "Waiting for CI to finish (takes ~10 min)"
- "Downloaded logs for debugging session"

### Drop 3: Repeated Information

Same status update appearing across multiple days without change.

**Examples to drop:**
- Same blocker reported 3 days in a row with no new information
- Same decision restated in different meetings
- Duplicate PR review comments

### Drop 4: Simple Q&A

Questions asked and answered that don't reveal patterns or decisions.

**Examples to drop:**
- "Q: What's the repo URL? A: github.com/..."
- "Q: When's the meeting? A: 2pm"
- "Q: Who owns this service? A: Team X"

### Drop 5: PR Pings & Mechanical Updates

Automated notifications with no analytical value.

**Examples to drop:**
- "PR #123 approved by reviewer"
- "Build succeeded on branch feature/x"
- "Dependabot opened PR for lodash update"

---

## Output Format

The final QMD digest file should follow this structure:

```markdown
# QMD Digest: {start_date} to {end_date}

> Auto-generated from {N} daily digests. Signal-to-noise ratio: {kept_items}/{total_items_scanned}.

## Decisions
{extracted items}

## Commitments
{extracted items}

## Pattern Changes
{extracted items}

## Blockers & Resolutions
{extracted items}

## Contacts & Relationships
{extracted items}

## Summary
{2-3 sentence narrative of the week's key themes}

## Skill Promotion Candidates
{Items that appeared 3+ times or represent durable patterns — flag for Dream Routine review}
```

---

## Quality Checklist

Before finalizing a QMD digest, verify:

- [ ] Every KEEP item has a source date
- [ ] No DROP items leaked through
- [ ] Decisions include "why" context, not just "what"
- [ ] Commitments have owners and due dates
- [ ] Blockers that were resolved are marked RESOLVED
- [ ] Skill promotion candidates are flagged (items appearing 3+ times)
- [ ] Signal-to-noise ratio is reported in header

## Integration with Squad

- **Scribe** generates raw daily digests → QMD extracts weekly
- **Dream Routine** consumes QMD digests for trend detection
- **Skill promotion** uses QMD "Skill Promotion Candidates" section as input
- Raw daily digests can be archived/gitignored after QMD extraction
