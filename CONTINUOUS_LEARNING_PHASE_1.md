# Continuous Learning Phase 1: Manual Channel Scan & Skill Promotion

**Issue:** #21 — Implement Continuous Learning Phase 1: Manual Channel Scan & Skill Promotion  
**Owner:** Seven (Research & Docs Expert)  
**Date:** 2026-03-09  
**Status:** Actionable Design  

---

## Executive Summary

Phase 1 is a **manual, human-driven process** for scanning Teams channels, extracting actionable insights, and promoting learnings into `.squad/skills/` entries. This approach prioritizes quality over automation:

1. **Manual Scan**: Agent identifies useful DK8S/infrastructure information in Teams channels
2. **Insight Extraction**: Patterns and learnings are documented in structured format
3. **Skill Promotion**: High-confidence, battle-tested patterns become `.squad/skills/` entries
4. **Team Feedback**: Loop findings back to decisions.md to inform future work

**Why Phase 1 is manual:** Automated scraping risks noise and false positives. By starting with careful human review, we train the system's signal quality before scaling to continuous learning in Phase 2.

---

## Problem Statement

The DK8S support channel contains **recurring, battle-tested patterns** that Squad agents should know:
- Pod scheduling / capacity starvation
- Node bootstrap failures (Karpenter + AKS)
- Azure platform issues misattributed to DK8S
- Identity / Key Vault coupling risks

Today, this knowledge lives in Slack/Teams threads. Tomorrow, it should live in agent memory (`.squad/skills/`). Phase 1 creates the bridge.

**Current state**: `dk8s-support-patterns` skill (learned from channel) is high-confidence and immediately useful to agents.

**Desired state**: Every agent can query `.squad/skills/` and find "here's what the DK8S community learned; apply it to my current problem."

---

## Phase 1: Manual Channel Scan & Skill Promotion Workflow

### Overview

```
┌──────────────────────────────────────┐
│ 1. IDENTIFY CHANNEL               │
│    (DK8S Support, ConfigGen, etc) │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│ 2. SCAN FOR PATTERNS               │
│    (What recurs 3+ times?)         │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│ 3. EXTRACT INSIGHTS                │
│    (Root causes, resolutions)      │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│ 4. DOCUMENT AS SKILL               │
│    (Follow SKILL.md template)      │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│ 5. VALIDATE & PROMOTE              │
│    (Team review, commit to repo)   │
└──────────────────────────────────────┘
                    ↓
┌──────────────────────────────────────┐
│ 6. LOOP BACK TO DECISIONS          │
│    (Update decisions.md if needed) │
└──────────────────────────────────────┘
```

---

## Step 1: Identify Target Channel

### Criteria for Channel Selection

Not all Teams channels are equal. Focus on channels that:

1. **Are domain-specific** (DK8S, ConfigGen, Fleet Manager, etc.)
2. **Have active, experienced participants** (community members solving real problems)
3. **Contain support/troubleshooting threads** (not just announcements or social)
4. **Surface recurring issues** (same problem appears multiple times per month)

### Recommended Starting Channels

| Channel | Domain | Learning Value | Why |
|---------|--------|-----------------|-----|
| **DK8S Clusters (Kubernetes) – Support** | Infrastructure | ⭐⭐⭐ High | Active troubleshooting; patterns directly applicable to agents |
| **ConfigGen Discussion** | Configuration | ⭐⭐⭐ High | Specific package; agents frequently encounter ConfigGen issues |
| **Fleet Manager** | Resource Management | ⭐⭐ Medium | Specialized domain; fewer cross-cutting patterns |
| **Infra Platform Team** | Infrastructure | ⭐⭐ Medium | Higher-level strategy; fewer actionable troubleshooting patterns |

### Finding Channels

1. **Use WorkIQ** to search for active channels related to Squad's domain:
   ```
   "What Teams channels contain messages about DK8S, ConfigGen, or infrastructure troubleshooting?"
   ```

2. **Check recent decisions.md** for current focus areas (Squad's work priorities)

3. **Ask Tamir** which channels matter most to current investigations

---

## Step 2: Scan for Recurring Patterns

### Query Strategy

Instead of reading every message, **search strategically** for patterns:

#### Sample WorkIQ Queries

```
"What are the most common questions or problems people report in the DK8S Clusters channel?"

"What errors, exceptions, or symptoms appear multiple times in recent DK8S channel messages?"

"When DK8S team members troubleshoot issues, what's their typical diagnostic approach?"

"What misunderstandings or false diagnoses do people commonly make when debugging DK8S issues?"
```

#### Manual Scan (If Channel Access Exists)

If you have direct access to the Teams channel:

1. **Scan last 2-4 weeks** of messages (not the entire history)
2. **Look for threads with:**
   - Multiple replies (indicates ongoing troubleshooting)
   - Red/warning reactions or escalations
   - Follow-ups saying "I had this same problem last month"
   - Resolution threads (ending with "ah, it was X all along")

3. **Mark candidates** that appear 3+ times or involve multiple people

### Pattern Recognition Checklist

For each candidate, ask:

- [ ] Does this problem have a **clear root cause**? (vs. random/environmental)
- [ ] Is the **resolution reproducible**? (will work next time, not one-time fix)
- [ ] Would **agents benefit from knowing this**? (relevant to Squad's work)
- [ ] Is it **documented clearly** in the thread? (didn't require reverse-engineering)

---

## Step 3: Extract Insights

### Information to Capture

For each pattern, document:

| Field | Example | Notes |
|-------|---------|-------|
| **Pattern Name** | Pod Scheduling / Capacity Starvation | Concise, memorable |
| **Trigger** | Pods drop below min replicas, FailedScheduling events | Observable signal |
| **Common Misdiagnosis** | Assumes HPA/PDB/affinity misconfiguration | What people get wrong |
| **Actual Root Cause** | Cluster-level capacity exhaustion | True underlying issue |
| **Resolution** | Check node pool capacity and autoscaler status | Step-by-step fix |
| **Example** | CANE-23 incident — pods stuck at 1 replica | Real case from channel |
| **Frequency** | Bi-weekly occurrence | How often does this appear? |
| **Confidence** | High | Based on how many people confirmed it |

### Extraction Exercise

**Example from DK8S Support Channel:**

**Raw thread:**
```
@user1: We're seeing pods drop to 1 replica. HPA says min=2. We've checked affinity constraints, node selectors, everything looks OK. What's happening?

@user2: Check your cluster nodes. Bet you've run out of capacity.

@user1: OH. We have 2 nodes at 99% utilization. Created new nodes and it's fixed.

@user3: This happened to us too last month. Took us 3 days to figure out it was node capacity.
```

**Extracted as insight:**
```
Pattern: Pod Scheduling / Capacity Starvation
Trigger: Pods drop below min replicas, latency spikes, FailedScheduling events storm
Common misdiagnosis: Teams assume HPA/PDB/affinity misconfiguration
Actual root cause: Cluster-level capacity exhaustion — not enough schedulable nodes
Resolution: Check node pool capacity and autoscaler status BEFORE investigating workload config
Example: CANE-23 incident — pods stuck at 1 replica despite min=2, thousands of FailedScheduling events
```

---

## Step 4: Document as Skill

### Skill Template

Each pattern becomes a `.squad/skills/{skill-name}/SKILL.md` entry:

```yaml
---
name: "{skill-name}"
description: "{what this skill teaches agents}"
domain: "{infrastructure|configuration|operations|etc}"
confidence: "{low|medium|high}"
source: "teams-channel-learning"
learned_from: "{channel name}"
first_seen: "{YYYY-MM-DD}"
---

## Context
{When and why this skill applies; background for agents}

## Patterns
{Specific, actionable patterns agents should know}

### Pattern 1: {Name}
**Trigger:** {Observable signal that indicates this pattern is at play}  
**Common misdiagnosis:** {What people get wrong}  
**Actual root cause:** {True underlying issue}  
**Resolution:** {Step-by-step fix or diagnostic approach}  
**Example:** {Real case from the channel}  

### Pattern 2: {Name}
...

## Anti-Patterns
{What to avoid}

## Limitations
{When this pattern might not apply; caveats}

## Future Iteration
{Known unknowns; what we'd like to learn next}
```

### Example: `dk8s-support-patterns`

See `.squad/skills/dk8s-support-patterns/SKILL.md` — this is a Phase 1 skill ready for agent use.

### Directory Structure

```
.squad/skills/
├── dk8s-support-patterns/
│   └── SKILL.md
├── configgen-support-patterns/
│   └── SKILL.md
├── squad-conventions/
│   └── SKILL.md
└── teams-monitor/
    └── SKILL.md
```

**Naming convention:** `{domain}-{learning-source}`
- `dk8s-support-patterns` — DK8S domain, learned from support channel
- `configgen-support-patterns` — ConfigGen domain, learned from support channel
- `squad-conventions` — Squad domain, manually documented

---

## Step 5: Validate & Promote

### Pre-Commit Checklist

Before committing a skill to the repo:

- [ ] **Is it actionable?** Can an agent apply this to make a better decision?
- [ ] **Is it supported by evidence?** Does the channel have 2+ examples?
- [ ] **Is it specific?** (Not too vague like "things can break")
- [ ] **Is it timely?** (Not obsolete — channel activity is recent, within last 2 weeks)
- [ ] **Does it fit a real squad need?** (Agents will actually encounter this)
- [ ] **Tone is neutral?** (Not opinionated; facts + reasoning, not criticism)

### Confidence Levels

| Confidence | Criteria | Example |
|------------|----------|---------|
| **High** | 3+ independent channel confirmations; community consensus; battle-tested | Pod scheduling patterns (seen in 5+ separate threads) |
| **Medium** | 2 confirmations; emerging pattern; awaiting more data | ConfigGen upgrade migration steps (seen in 3 threads) |
| **Low** | 1 confirmation; early observation; needs validation | New Azure service behavior (one thread, needs cross-team confirmation) |

Set confidence to what you observe, not what you hope for. It's fine to publish LOW-confidence skills if they're useful signals; agents will adjust accordingly.

### Validation Workflow

1. **Create GitHub issue** with the skill proposal:
   - Title: `[Skill] {skill-name} — Phase 1 Extraction`
   - Label: `skill-proposal`, `phase-1-learning`
   - Body: Include the SKILL.md content, channel evidence, confidence level

2. **Share with team** for feedback:
   - Post in `.squad/decisions/inbox/` or mention Tamir/Picard
   - Ask: "Does this match what you've seen? Missing anything?"
   - Collect feedback (2-3 days max)

3. **Iterate if needed**:
   - Refine based on feedback
   - Add/remove patterns if community input suggests better accuracy

4. **Commit to repo**:
   - Create `.squad/skills/{skill-name}/SKILL.md`
   - Commit message: `docs: Add {skill-name} skill (Phase 1, learned from {channel})`
   - Include issue reference: `Closes #21` or similar

---

## Step 6: Loop Back to Decisions

### Update Decisions.md

If the skill reveals a broader organizational insight, loop it back to `decisions.md`:

**Example:**
```
## Decision 20: DK8S Capacity Planning Anti-Pattern

**Date:** 2026-03-09
**Author:** Seven (Research & Docs)
**Status:** Proposed
**Source:** dk8s-support-patterns skill extraction

**Finding:** Teams repeatedly misdiagnose pod scheduling failures as workload misconfig 
when the actual cause is cluster capacity exhaustion.

**Implication:** DK8S platform docs should highlight capacity checking as the first 
diagnostic step in troubleshooting guides.

**Action:** Update DK8S troubleshooting docs; add capacity check to on-call runbooks.
```

### When to Loop Back

Create a decision when the skill reveals:
- A **systemic problem** (not just a one-off edge case)
- A **gap in existing docs** or processes
- A **training opportunity** for the broader team
- A **policy change** that should be adopted

---

## Implementation: Phase 1 Hands-On

### Week 1: DK8S Channels

**Task:** Extract 2–3 high-confidence skills from DK8S channels

1. Use WorkIQ to scan DK8S support channel (last 2 weeks)
2. Identify 5+ recurring patterns
3. Document top 3 as SKILL.md files
4. Create GitHub issue for validation
5. Iterate based on feedback
6. Commit to repo

**Expected output:** 2–3 `.squad/skills/` entries, 1 decision update

### Week 2: ConfigGen & Other Domains

**Task:** Expand to related domains

1. Scan ConfigGen discussion channel
2. Extract 1–2 high-confidence skills
3. Validate + commit
4. Light documentation update

**Expected output:** 1–2 additional `.squad/skills/` entries

### Success Metrics

- [ ] At least **2 Phase 1 skills committed** to `.squad/skills/`
- [ ] **Team feedback incorporated** (issue comments, discussion)
- [ ] **Decision.md updated** with at least **1 finding** from extractions
- [ ] **Confidence levels appropriate** (not inflated; honest about limitations)
- [ ] **Agents can use these skills** (tested by querying in a real agent session)

---

## Skill Extraction Template (Copy & Paste)

Use this when extracting a new skill:

```markdown
# {Skill Name} — Phase 1 Extraction

## Channel Scan Summary
- **Source channel:** {Channel Name}
- **Period:** {Date Range}
- **Scan method:** {WorkIQ queries used / manual thread review}
- **Patterns identified:** {Count}
- **High-confidence patterns:** {Count}

## Patterns Extracted

### Pattern 1: {Name}
- **Evidence threads:** {Number and IDs/dates}
- **Frequency:** {How often observed}
- **Confidence:** {High|Medium|Low}
- **Trigger:** {Observable signal}
- **Root cause:** {Actual underlying issue}
- **Resolution:** {Step-by-step fix}
- **Example:** {Real case}

### Pattern 2: {Name}
...

## Validation Checklist
- [ ] Actionable for agents?
- [ ] Supported by 2+ examples?
- [ ] Specific and concrete?
- [ ] Recent (last 2 weeks)?
- [ ] Fits squad needs?
- [ ] Tone neutral?

## Draft SKILL.md

[SKILL.md content here]

## Team Feedback Needed
- [ ] Does this match your experience?
- [ ] Missing any patterns?
- [ ] Confidence level accurate?
```

---

## Anti-Patterns: What NOT to Do

### ❌ Over-Automation
Don't try to auto-scrape Teams and create skills without human review. **Phase 1 is manual** for a reason—it trains quality.

### ❌ Vague Patterns
❌ "Things sometimes break"  
✅ "Pod eviction fails when PDB prevents node drain"

### ❌ Out-of-Date Info
Don't promote patterns observed 6+ months ago. Recency matters in fast-moving infrastructure.

### ❌ Mix Personal Opinion
❌ "This is a stupid way to configure things"  
✅ "Teams commonly misconfig this; here's why it fails and how to fix it"

### ❌ Duplicate Effort
Before extracting a skill, check if it already exists in `.squad/skills/`. Consolidate rather than duplicate.

### ❌ Low-Confidence Claims
Don't publish a skill with 1 example and claim confidence=high. Be honest: "This is early data; needs validation."

### ❌ Forget to Update Decisions
If a skill reveals a systemic insight, loop it back to decisions.md so the team benefits.

---

## Frequently Asked Questions

### Q: What if a pattern has conflicting advice in the channel?

**A:** Document both approaches, note the disagreement, and explain the tradeoff. Example:
```
Resolution (Approach A): Increase node pool size
  - Pro: Immediate scaling, no redesign
  - Con: Higher costs; may paper over deeper efficiency issues
  
Resolution (Approach B): Re-optimize workload placement
  - Pro: Fixes root cause; lower long-term costs
  - Con: Requires app changes; higher effort
```

### Q: Can we extract skills from other Teams (e.g., Product, Security)?

**A:** Yes! Phase 1 is channel-agnostic. Start with infra/DK8S because that's Squad's focus, but once the process is proven, expand to any domain where patterns exist.

### Q: How often should we re-scan a channel?

**A:** Phase 1 is quarterly minimum, monthly ideal. Pick a pattern: "Every Monday, scan last 2 weeks of DK8S channel; extract new patterns." This becomes a Squad ceremony or Ralph task in Phase 2.

### Q: What happens when a skill becomes outdated?

**A:** Add a note in the SKILL.md:
```yaml
deprecated: true
deprecated_reason: "Azure changed behavior in April 2026; pattern no longer applies"
successor_skill: "new-azure-behavior"
```

### Q: Can agents contribute skills directly?

**A:** Not in Phase 1. Human review is required for quality. Phase 2 might allow agent-proposed skills with human validation.

### Q: How do we know if a skill is actually useful?

**A:** During agent sessions, log which skills were queried/applied:
```
Session: Issue #47
Agent: B'Elanna (Infrastructure)
Skills queried: dk8s-support-patterns
Skills applied: [pod-scheduling section]
Outcome: Saved 30 min debugging time
```

Accumulate these logs to measure skill value.

---

## Success Story Example

### Scenario: B'Elanna Solving an Issue

**Agent session:** B'Elanna investigates cluster capacity issue.

**Without Phase 1 skill:** Spends 2 hours reverse-engineering logs, checking workload configs, eventually checking node capacity.

**With Phase 1 skill:**
1. B'Elanna reads issue: "Pods stuck at 1 replica"
2. Queries `.squad/skills/dk8s-support-patterns`
3. Finds: Pod Scheduling / Capacity Starvation pattern
4. Immediately checks node capacity → finds root cause
5. Proposes fix; agent moves on
6. **Time saved:** 1.5 hours

This is Phase 1 working.

---

## Next: Phase 2 (Future)

Phase 1 ends when:
- [ ] 5+ skills committed to `.squad/skills/`
- [ ] Team validates workflow + iterates twice
- [ ] Agents actively query and apply skills in real sessions
- [ ] Pattern for regular channel scans established

**Phase 2 preview:**
- **Automated skill proposal:** Ralph periodically scans channels, flags patterns, proposes skills
- **Agent validation:** Agents review proposals before commit
- **Cross-skill synthesis:** Detect themes across multiple skills (e.g., "identity coupling is a recurring class of problems")
- **Skill versioning:** Track skill evolution over time

---

## References & Related Work

- `.squad/skills/` — Existing skill structure and examples
- `.squad/decisions.md` — Decision 15 on OpenCLAW patterns + continuous learning
- `.squad/skills/teams-monitor/SKILL.md` — How to query Teams for actionable content
- `.squad/skills/dk8s-support-patterns/SKILL.md` — Example Phase 1 skill
- `blog-draft-ai-squad-productivity.md` — Continuous learning context (Section 3)

---

## Appendix: Skill Directory Quick Reference

### Using Skills in Agent Sessions

Agents access skills like this:

```
"I'm debugging a pod scheduling issue. Let me query the DK8S support patterns skill."
→ Review .squad/skills/dk8s-support-patterns/SKILL.md
→ Find: Pod Scheduling / Capacity Starvation pattern
→ Apply: "First, check node capacity"
→ Log: "Skill applied; saved time"
```

### Creating a New Skill Directory

```bash
mkdir -p .squad/skills/{skill-name}
cat > .squad/skills/{skill-name}/SKILL.md << 'EOF'
---
name: "{skill-name}"
description: "{description}"
domain: "{domain}"
confidence: "high"
source: "teams-channel-learning"
learned_from: "{channel}"
first_seen: "{date}"
---

## Context
...

## Patterns
...

## Examples
...

## Anti-Patterns
...
EOF
```

---

**Prepared by:** Seven (Research & Docs Expert)  
**Status:** Ready for Phase 1 Implementation  
**Next Steps:** Tamir confirmation → Begin Week 1 DK8S channel scans
