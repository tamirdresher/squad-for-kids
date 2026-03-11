# Decision Proposal: Research Squad Architecture

**Date:** 2026-03-27  
**Author:** Picard (Lead)  
**Status:** 📥 Inbox — Awaiting User Approval  
**Issue:** #341  
**Scope:** Team Architecture, Cross-Squad Communication

---

## Summary

Create dedicated Research Squad in separate GitHub repository (`tamresearch1-research`) with cross-repo issue-based communication protocol. Research squad focuses exclusively on innovation, exploration, and continuous improvement, operating autonomously while feeding findings back to production squad.

---

## Decision

**RECOMMEND creating Research Squad with following architecture:**

### Structure
- **New Repository:** `tamresearch1-research` (private)
- **Squad Composition:** 6 agents (Guinan, Geordi, Troi, Brahms, Scribe-R, Ralph-R)
- **Communication Protocol:** Cross-repo GitHub issues with label-based routing
- **Symposium Cadence:** Monthly or quarterly batch findings delivery

### Communication Pattern
```
Production Squad (tamresearch1)
    ↓ [creates issue with label:research-request]
Research Squad (tamresearch1-research)
    ↓ [Ralph-R monitors, routes to researchers]
Research Squad (completes research)
    ↓ [creates issue in production repo with label:research-findings]
Production Squad (Ralph routes to Picard)
    ↓ [Picard decides: adopt, defer, reject]
```

### Key Architectural Choices

1. **Separate Repository** (not separate branch)
   - **Rationale:** Clean separation of concerns, independent issue boards, research workspace doesn't pollute production git history
   - **Consequence:** Requires cross-repo communication protocol (solved via GitHub issue references)

2. **Issue-Based Communication** (not real-time chat)
   - **Rationale:** Async, auditable, persistent, leverages existing GitHub primitives
   - **Consequence:** May introduce latency (mitigated by Ralph automation)

3. **Research Ralph** (dedicated monitor for research squad)
   - **Rationale:** Research squad needs autonomy; can't rely on production Ralph's routing
   - **Consequence:** Requires extending Ralph's capabilities to handle cross-repo monitoring

4. **Embrace Research Failure** (60-70% non-adoption is healthy)
   - **Rationale:** Research is exploratory; many experiments should fail
   - **Consequence:** Must document failed research in `research/failed/` with lessons learned

5. **Picard Has Veto Power** (production priorities trump research)
   - **Rationale:** Research should serve production needs, not become academic exercise
   - **Consequence:** Guinan (Research Lead) must coordinate with Picard on research agenda

---

## Rationale

### Problem Statement
Current squad handles both production work AND continuous improvement/innovation. This creates tension:
- Production urgency crowds out exploratory research
- Failed experiments feel like "wasted time" in production context
- No dedicated focus on scanning tech landscape, methodology improvements, architecture evolution

### Proposed Solution Benefits
- ✅ **Dedicated Research Capacity:** Research squad can explore freely without production pressure
- ✅ **Failure Is Expected:** Separate repo normalizes research failure as learning
- ✅ **Symposium Pattern:** Batch findings delivery prevents continuous interruption
- ✅ **Cross-Pollination:** Research squad learns from production work, production adopts research findings
- ✅ **Scalable:** Multiple research squads can exist (methodology squad, security research squad, etc.)

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Noise Overload** | High | Priority tiers (`priority:high`, `priority:explore`); production can defer low-priority research |
| **Coordination Overhead** | High | Async issue protocol; Ralph automates routing; no synchronous meetings required |
| **Context Loss** | Medium | Research issues must link to production context via cross-repo references |
| **Divergent Priorities** | High | Picard veto power on research agenda; quarterly alignment reviews |
| **Resource Waste** | Medium | Embrace 60-70% failure rate; document failures as learning |

---

## Implementation

### Prerequisites (User Action Required)
1. ✅ **User Approval:** Tamir confirms research scope, resource allocation
2. 🔧 **Repository Creation:** `gh repo create tamirdresher_microsoft/tamresearch1-research --private`
3. 🔧 **Ralph Enhancement:** Extend to monitor both repos (estimated: 2-4 hours config)

### Phase 1: Foundation (Week 1)
- Initialize `.squad/` structure in research repo
- Define research roster (Guinan, Geordi, Troi, Brahms, Scribe-R, Ralph-R)
- Create research-specific routing.md and charter files

### Phase 2: Communication Bridge (Week 2)
- Extend Ralph for cross-repo monitoring
- Test bidirectional issue flow
- Document label taxonomy and communication protocol

### Phase 3: Research Capacity (Week 3-4)
- Seed initial research backlog
- Run first symposium (3-5 research items)
- Deliver batch findings to production squad

### Phase 4: Continuous Operation
- Monitor research velocity and adoption rate
- Quarterly review of research squad effectiveness
- Iterate on communication protocol based on learnings

---

## Success Metrics

**Research Squad is successful if:**
1. **Research Velocity:** 5-10 research items completed per quarter
2. **Adoption Rate:** 30-40% of completed research adopted by production (60-70% failure is healthy)
3. **Innovation Index:** 1-2 novel techniques/tools adopted per quarter
4. **Symposium Cadence:** Held consistently (monthly or quarterly)
5. **Communication Latency:** <24hr median response time on cross-repo issues

**Failure Criteria (Sunset Research Squad If):**
- <20% adoption rate over 2 quarters (not delivering value)
- >3 days median communication latency (overhead too high)
- Research squad unable to complete 3 research items per quarter (capacity mismatch)

---

## Alternatives Considered

### Alternative 1: Research as Production Squad Capability
- **Pros:** No new infrastructure, single repo, unified team
- **Cons:** Production urgency crowds out research, failed experiments feel wasteful, no cultural space for exploration
- **Decision:** Rejected — research needs autonomy and failure tolerance

### Alternative 2: Research as Sub-Directory in Production Repo
- **Pros:** Single repo, easier cross-reference
- **Cons:** Git history pollution, research issues mixed with production issues, no clean separation
- **Decision:** Rejected — separate repo provides cleaner boundaries

### Alternative 3: Real-Time Chat Communication Between Squads
- **Pros:** Lower latency
- **Cons:** Not auditable, requires synchronous availability, ephemeral (no persistent record)
- **Decision:** Rejected — async issue-based protocol is more maintainable

---

## Related Decisions

- **Decision 1:** Gap Analysis When Blocked (established pattern of working with incomplete data)
- **Decision 2:** Infrastructure Patterns (research squad will research new patterns)
- **Decision 17:** Blog Anonymization (research findings must respect public content policy)

---

## Next Steps

**If Approved:**
1. Tamir creates `tamresearch1-research` repository
2. Picard initializes Squad structure in new repo
3. Guinan spawned for first time to establish research agenda
4. First test research request sent (e.g., "Evaluate GitHub Copilot Workspace for squad development")
5. After Q2 2026, review research squad effectiveness and decide: continue, pivot, or sunset

**If Rejected:**
- Document why (user directive to inbox)
- Consider alternative: dedicated "Research Thursday" for production squad to explore innovations

---

**Status:** 📥 Inbox — Awaiting User Approval  
**Issue:** #341 (labeled `status:pending-user`)  
**Recommendation:** ✅ APPROVE with 1-quarter pilot  
**Review Date:** End of Q2 2026
