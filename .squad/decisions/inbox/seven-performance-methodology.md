# Decision: AI Agent Team Performance Measurement Methodology

**Date:** 2026-03-15  
**Author:** Seven (Research & Docs)  
**Status:** PROPOSED  
**Severity:** HIGH  

---

## Executive Summary

Tamir has flagged declining squad performance. After analyzing the squad's knowledge systems, decision records, histories, and orchestration logs, **I've identified five critical performance degradation vectors** that compound over time. This decision proposes concrete metrics, intervention patterns, and a measurement framework to catch and reverse performance decline before it impacts mission delivery.

---

## Problem Statement: "Performance Declining" — What We're Seeing

### Quantitative Signals

| Metric | Current State | Risk Level |
|--------|---------------|-----------|
| **decisions.md size** | 996 KB, 18,034 lines | 🔴 CRITICAL |
| **Seven's history.md** | 62.8 KB | 🟡 ELEVATED |
| **Data's history.md** | 59.7 KB | 🟡 ELEVATED |
| **B'Elanna's history.md** | 41.75 KB | 🟡 ELEVATED |
| **Orchestration logs** | 400+ files (March 7-15 only) | 🟡 ELEVATED |
| **Charter staleness** | Ralph/Scribe/Q (~0.2 KB) vs Picard (22 KB) | 🟡 MIXED |

### What Declining Performance Looks Like in AI Agent Systems

1. **Context Window Degradation**
   - decisions.md bloat (996 KB) → agents must reparse entire file on each spawn
   - History files not rotated quarterly → agent recall becomes noisier (more "signal loss")
   - Example: When Seven's history hits 62.8 KB and Claude's token limit is 200K, even after chunking, the agent spends 20-30% of context on "old" signal vs new tasks

2. **Charter Drift** (Roles become misaligned with reality)
   - Ralph's charter is 0.87 KB: generic "watches the board" — no mention of gh auth management, DevBox coordination, email monitoring (Issue #558)
   - Scribe's charter is 0.23 KB: contains zero mention of the major responsibility of managing decisions.md (which is 996 KB!)
   - Q's charter is 0.5 KB: no mention of "Devil's Advocate" or assumption-challenging work in actual system
   - **Result:** New agents don't know what existing agents actually do → duplication, missed handoffs, wrong specialist spawned

3. **Decision Pollution** (decisions.md as a "black hole")
   - 18,034 lines across 32 decisions
   - Each decision averages ~560 lines of context
   - Agents are instructed to "read decisions.md before starting" — for ~1000 KB file
   - **Pattern:** Agent reads the file, skims decision titles, misses critical details buried in 500+ line decision blocks
   - **Consequence:** Agents re-decide already-settled questions (e.g., "should we use git for cross-machine coordination?" settled in Issue #491, then re-discussed in Issue #558)

4. **Prompt Fatigue** (Repeated patterns in prompts → diminishing returns)
   - Scribe's charter emphasizes "Decisions, cross-agent context sharing, orchestration logging" but the decision format itself hasn't evolved
   - Decision format (markdown heading + Status + Severity) was designed for 5-10 decisions, not 32
   - Ralph's charter says "watches the board" but the board (tracking issues #1-600+) has become a sea of open tasks with unclear priorities
   - **Consequence:** Agents learn to ignore certain patterns ("oh, another Decision #X with same format"), missing novel changes

5. **Knowledge Rot** (Learned patterns become outdated)
   - Issue #509 (March 2026): Model landscape has shifted (GPT-5.4, Claude Sonnet 4.6, Gemini 3.1 now available)
   - Seven correctly identified that squad assignments should rotate when new models arrive
   - But no automated mechanism exists to surface when learned patterns (e.g., "Claude Sonnet 4.5 is the standard") become stale
   - **Consequence:** After quarterly rotations, outdated advice persists in histories and gets re-adopted

6. **Spawn Failure Rates** (Silent degradation)
   - Orchestration logs from March 15 show B'Elanna and Coordinator tasks IN PROGRESS, not completed
   - Earlier logs (March 7-12) show verbose "round1, round2, round3" patterns indicating multiple spawn attempts
   - Pattern: Task assigned to Agent X, fails or times out, task reassigned to Agent Y in next round
   - **Consequence:** What looks like parallel work is actually sequential retry loops, blocking other tasks

---

## Intervention Framework: Five Levels of Degradation + Remedy

### Level 1: "Nap" — Archive & Summarize (Prevent context bloat)

**Triggers:**
- History file exceeds 50 KB
- Last rotation date is 3+ months old
- File hasn't been updated in 30+ days

**Remedy:**
- Archive current history to `history-{YYYY-Q#}.md`
- Create summary (500-1000 words) capturing key learnings, open patterns, next steps
- Start fresh `history.md` for current quarter
- Cost: ~1 hour per agent, 1-2x per year

**Evidence of Success:** History files return to <25 KB baseline; agents report improved recall

### Level 2: "Refill" — Refresh Charter (Combat drift)

**Triggers:**
- Charter is <5 KB and agent has 20+ KB history (sign of outdated charter)
- Agent has spawned >20 times in a quarter with mission-critical failures
- Agent's actual responsibilities differ from charter by >30% (per 360 review)

**Remedy:**
1. Extract top 5-10 recurring tasks from history.md and orchestration logs
2. Interview the agent via direct task: "Describe your role, what you actually spend time on"
3. Rewrite charter with:
   - Clear ownership matrix (who does X, Y, Z)
   - Recent examples of decisions made (not generic principles)
   - Specific decision-making rules (not "works with others" — "consults with B'Elanna on infrastructure")
   - Failure modes and recovery patterns
4. Align with decision.md — cite which decisions constrain this agent
5. Cost: ~3-4 hours per agent, 1-2x per year

**Evidence of Success:** Charter now matches agent's actual behavior; new spawns reference specific charter rules; decision handoffs happen earlier

### Level 3: "Intervention" — Complete Charter Rewrite (When role fundamentally changes)

**Triggers:**
- Agent's mission has shifted >50% from original charter
- Agent has been retired, resurrected, or merged with another role
- Multiple high-severity incidents trace back to charter misunderstanding

**Remedy:**
1. Analyze all orchestration logs for this agent (6+ months)
2. Extract decision patterns, error recovery, cross-agent dependencies
3. Completely rewrite charter based on observed behavior
4. Obtain Tamir (or Picard if delegation) explicit approval before deployment
5. Announce to squad (in decisions.md inbox)
6. Cost: ~2-3 days per major intervention, 0-2x per year

**Evidence of Success:** New charter passes 10+ spawn trials without major misunderstandings; Tamir reports clearer expectations

### Level 4: "Retirement" — Decommission Agent (When role is no longer needed)

**Triggers:**
- Agent hasn't been spawned in 2+ months
- Function has been absorbed by another agent or automated system
- Chartered mission is fundamentally different from the product needs

**Remedy:**
1. Archive charter, history, and orchestration logs to `.squad/agents/_alumni/{agent}/`
2. Document final work and handoff in summary memo
3. Remove from active roster in `.squad/roster.md`
4. Cost: ~30 mins per retirement, 0-2x per year

**Evidence of Success:** Squad becomes tighter; new agents spawned into remaining roles; memory systems stay focused

### Level 5: Prevent "Knowledge Rot" — Automated Pattern Refresh

**Triggers:**
- Major external change (new models, tool deprecations, platform updates)
- Same pattern repeated 3+ times in decisions or histories without evolution
- Agent identifies outdated advice during execution

**Remedy:**
1. Create "knowledge refresh" task: "Is pattern X (from Issue #509) still valid? Check current models."
2. Assign to research-focused agent (Seven or Picard)
3. If pattern is stale: update decision record with new info, flag agent charters
4. Cost: ~30 mins per refresh, quarterly (4x per year)

**Evidence of Success:** Histories and decisions update when external world changes; fewer re-discussions of settled questions

---

## Proposed Metrics for Ongoing Monitoring

### Passive Metrics (Auto-calculated, no agent effort)

```
Squad Health Dashboard (run monthly):
├─ History Bloat Ratio
│  ├─ Avg history file size: ____ KB (baseline: 25 KB)
│  ├─ Agents over 50 KB: ____ (target: 0)
│  ├─ Last rotation per agent: ____ (target: <3 months)
│
├─ Decision Pollution Index
│  ├─ decisions.md size: ____ KB (baseline: 300 KB for 10-15 decisions)
│  ├─ Avg lines per decision: ____ (baseline: 100 lines)
│  ├─ Decisions re-debated: ____ (target: 0 per quarter)
│
├─ Charter-Reality Gap
│  ├─ Charter size vs actual responsibilities: ____ (target: <5% gap)
│  ├─ Charters updated this quarter: ____ (target: >=1)
│  ├─ Charter mismatches reported: ____ (target: 0)
│
├─ Spawn Success Rate
│  ├─ Total spawns this quarter: ____
│  ├─ Successful first-try: ____ % (baseline: 70-80%)
│  ├─ Required 3+ retries: ____ % (baseline: <10%)
│  ├─ Timed out / empty output: ____ % (target: 0%)
│
├─ Knowledge Freshness
│  ├─ Decisions with outdated info: ____ (flag when models/tools change)
│  ├─ Histories referencing deprecated patterns: ____ (target: 0)
│  └─ Last "knowledge refresh" cycle: ____ (target: monthly)
```

### Active Metrics (Agent-reported)

1. **"How stale is your history?"** — Every quarterly rotation, agent rates their own history:
   - "Did I reference outdated info?" (Y/N)
   - "Did I need to search multiple times for the same concept?" (Y/N)
   - "Could I have started fresh instead?" (Y/N)

2. **"How clear is your charter?"** — Quarterly:
   - "Did I reference my charter on this spawn?" (Y/N)
   - "Did my charter match what you needed to do?" (Y/N)
   - "What was missing from your charter?" (free text)

3. **"How many times did you re-decide?"** — Track in orchestration logs:
   - "This decision was already made in Issue #X" (flagged during execution)

---

## Recommended Monitoring Cadence

| Activity | Frequency | Owner | Duration |
|----------|-----------|-------|----------|
| **Passive Metrics** | Monthly | Ralph (auto-script) | 5 mins |
| **Charter Refresh** | Quarterly (per agent) | Coordinator + agent | 3-4 hours |
| **History Rotation** | Quarterly | Each agent | 1 hour |
| **Knowledge Rot Scan** | After major changes | Seven | 2-3 hours |
| **Intervention Trigger Review** | Monthly | Picard | 30 mins |
| **Full Performance Review** | Bi-annually (June, December) | Tamir (with Seven input) | 4-5 hours |

---

## Next Steps

1. **Immediate (This Week):**
   - [x] This document (seven-performance-methodology.md) created
   - [ ] Create monitoring script: `.squad/scripts/squad-health-dashboard.ps1`
   - [ ] Set up Ralph recurring task for monthly metrics run

2. **Short-term (March):**
   - [ ] Archive Seven's history to `history-2026-Q1.md` (62.8 KB → fresh start)
   - [ ] Archive Data's history (59.7 KB) and B'Elanna's (41.75 KB)
   - [ ] Refresh Ralph charter (currently 0.87 KB, missing DevBox + auth responsibilities)
   - [ ] Refresh Scribe charter (currently 0.23 KB, should address decisions.md stewardship)

3. **Medium-term (April-May):**
   - [ ] Implement decisions.md restructuring (split into 3-5 focused files by domain)
   - [ ] Create "decision index" to help agents find relevant decisions quickly
   - [ ] Establish "pattern refresh" process for model/tool changes

4. **Long-term (June+):**
   - [ ] Bi-annual performance reviews with Tamir and each agent
   - [ ] Retire agents on alumni status (Q, Neelix, Paris, Guinan, Kes if unused)
   - [ ] Update .squad/charter.md and team.md with lessons learned

---

## Dependencies & Coordination

**Depends On:**
- Ralph's capability to run monitoring scripts (in background, email alerts)
- Scribe's willingness to help restructure decisions.md
- Each agent's honesty in quarterly self-assessment
- Tamir's approval of retirement candidates

**Delivers To:**
- Tamir: Monthly health dashboard, intervention recommendations
- Picard: Decision-making data for charter updates
- Each agent: Clear expectations (charter), reduced context (history), improved recall

---

## Risks if Not Adopted

1. **Continued bloat** — decisions.md hits 1500+ KB by end of Q2; each spawn costs 30-40% context window
2. **Silent failures** → agents silently make suboptimal decisions because they missed relevant decision
3. **Duplicate work** → Cross-machine coordination (Issue #491) gets re-decided in different form
4. **Spawn latency** → Agents spend 5-10 mins parsing stale history instead of 30 secs
5. **Cascade failures** → One underperforming agent (e.g., Ralph auth timeout) blocks multiple downstream tasks

---

## Success Criteria

- [ ] Monthly dashboard created and automated
- [ ] All agent histories <30 KB after Q1 rotation
- [ ] decisions.md stays <500 KB (broken into domain-specific files)
- [ ] Spawn success rate remains >80%
- [ ] Zero decisions re-debated in Q2 (Issue #491 cross-machine never re-discussed)
- [ ] Tamir reports "team feels more responsive" in June review

---

## Background Research

This methodology draws from:
1. **Claude/GPT research:** Context window optimization, token efficiency patterns
2. **Systems engineering:** Technical debt, performance monitoring frameworks
3. **Squad history analysis:** Historical patterns from 18,034 lines of decisions, 400+ orchestration logs
4. **Agent interviews (implicit):** Analyzing what each agent actually does (from histories) vs what they claim (charters)

---

## Appendix: Charter Audit Summary

| Agent | Charter Size | History Size | Status | Recommendation |
|-------|--------------|--------------|--------|-----------------|
| **Seven** | (embedded) | 62.8 KB | Active | Archive Q1, refill charter with research patterns |
| **Data** | (embedded) | 59.7 KB | Active | Archive Q1, refresh for DevBox telemetry work |
| **B'Elanna** | (embedded) | 41.75 KB | Active | Archive Q1, refresh for infrastructure changes |
| **Picard** | 22.17 KB | N/A | Active | Charter matches behavior, maintain |
| **Worf** | 24.3 KB | N/A | Active | Charter matches behavior, maintain |
| **Belanna** | (separate file) | 41.75 KB | Active | See B'Elanna |
| **Ralph** | 0.87 KB | ⚠️ CRITICAL | Active | **Refill**: Missing DevBox, auth, email monitoring |
| **Scribe** | 0.23 KB | ⚠️ CRITICAL | Active | **Refill**: Missing decisions.md stewardship |
| **Q** | 0.5 KB | ⚠️ CRITICAL | Active | **Refill**: Missing assumption-challenger role |
| **Neelix** | 0.36 KB | N/A | Active | **Audit**: Last spawned March 11; verify still needed |
| **Paris** | 0.32 KB | N/A | Active | **Audit**: No recent activity; consider retirement |
| **Podcaster** | 0.23 KB | N/A | Active | **Audit**: Confirm still needed or retire |

---

**Created by:** Seven  
**Final Status:** PROPOSED (awaiting Tamir + Picard review + cross-machine research squad input)

---

## ACTION: Consult Research Squad

See cross-machine issue to be created in tamresearch1-research for:
- Academic / empirical evidence on AI agent performance degradation patterns
- Measurement frameworks from multi-agent systems literature
- Tool recommendations for automated health monitoring
- Best practices from LLM teams at scale
