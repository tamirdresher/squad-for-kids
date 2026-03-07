# Decision: TAM Patent Strategy — Option A (Narrow Claims)

**Date:** March 11, 2026  
**Owner:** Tamir Dresher (decision maker), Seven (research lead)  
**Status:** Awaiting Tamir's confirmation on co-inventors + filing intent  
**Related Issues:** #42, #23 (OpenCLAW patterns — complementary to TAM)  

---

## The Decision

**Implement Option A: File narrow, TAM-focused patent claims** covering:
1. Ralph proactive monitoring with autonomous recovery
2. Universe-based casting with governance policies  
3. Git-native persistent state for coordination
4. Drop-box memory for asynchronous consensus
5. Integrated system combining all 4 (non-obvious combination)

**Why**: Broad multi-agent orchestration claims are heavily prior-art'd (CrewAI, MetaGPT, LangGraph, NEC patent WO2025099499A1). Narrow integration-focused claims have defensibility.

**Timeline**: 4-6 weeks to filing (via Microsoft Inventor Portal)

**Cost**: ~$500 filing fee (provisional); Microsoft covers everything

**Upside**: Defensive IP (prevent copying), Microsoft rewards ($500-2,000 filing bonus), locks in priority date

**Downside**: Risk on git-native state claims (gitclaw prior art timing unknown), requires inventor confirmation

---

## Context: Why TAM Is Patentable

### What Makes TAM Novel

| Element | Existing Solution | TAM Difference |
|---------|---|---|
| **Proactive Monitoring** | Kubernetes (infrastructure) | Application-level agents, **autonomous recovery** (not just alerting) |
| **Task Assignment** | Load balancing (CrewAI, LangGraph) | **Declarative governance policies** (role, seniority, org rules) |
| **Persistent State** | Database or API state | **Git as backbone** (version-controlled, auditable, distributed) |
| **Consensus** | Real-time (Raft, Paxos) | **Asynchronous with rationale** (decisions preserve reasoning) |
| **Integration** | Individual components | **Unified system** addressing knowledge work gaps |

### What Competitors Are Missing

- **CrewAI**: Has routing + roles, but no proactive monitoring, no governance policies, no git state
- **MetaGPT**: Has SOP encoding + collaborative workflows, but no autonomous recovery, no governance, no asynchronous consensus
- **LangGraph**: Has graph orchestration, but no proactive monitoring, no governance, no git state
- **Kubernetes**: Has monitoring + recovery, but for infrastructure not agents, no governance policies for workload assignment
- **Microsoft Agent Framework**: Has durable state + orchestration, but no proactive monitoring, no governance policies

### Why Integration Matters

Individual components are table-stakes. The **combination** is what's defensible:
- Ralph detects failure → signals casting algorithm
- Casting reassigns work respecting governance → updates Git state atomically  
- Drop-box memory enables team consensus on recovery strategy → feeds back to policies
- Git state serves as backbone for all → full audit trail

This feedback loop is not modeled anywhere else.

---

## Prior Art Assessment

### High Risk (Probably Prior-Art'd)
- ❌ General multi-agent task delegation (CrewAI, MetaGPT, NEC patent)
- ❌ Database/API state for workflows (well-established)
- ❌ Health monitoring and alerting (Kubernetes, Datadog, Prometheus)

### Medium Risk (Competitive Landscape, Case-by-Case)
- ⚠️ Git-native coordination (gitclaw project is active, timing unknown)
- ⚠️ Governance policies in task routing (emerging in enterprise orchestration, not standard)
- ⚠️ Asynchronous consensus with rationale preservation (GitHub RFC process exists, not formalized as reusable pattern)

### Low Risk (Genuinely Novel)
- ✅ **Autonomous recovery from multi-agent cascading failures** (Ralph pattern) — no equivalent in frameworks
- ✅ **Universe-based casting with declarative governance** — not in any orchestration framework
- ✅ **Integrated 4-part system** — combination is non-obvious

---

## Filing Strategy

### Provisional Patent (Recommended First Step)

**What**: 10-20 page document with claims, abstract, and description  
**Cost**: $500 filing fee  
**Timeline**: File now, submit to Microsoft portal week 4  
**Benefit**: Locks in priority date, buys 12 months to assess competitive landscape  

**Advantages over utility patent**:
- Lower risk (narrower claims OK in provisional)
- Lower cost ($500 vs. $2,000+ for utility)
- Decision flexibility: at month 10, can convert to utility or abandon based on competitive landscape
- Allows public disclosure after filing without losing patent rights (1-year grace period in US)

### Utility Patent Conversion (Month 10 Decision)

**What**: Full patent application (30-50 pages) with claims, detailed description, drawings, prosecution  
**Cost**: $8,000-15,000  
**Timeline**: Month 10-12 after provisional filing  
**Benefit**: Broader protection, longer patent term  

**Criteria to decide at month 10**:
- Has gitclaw (or similar) invalidated git-native claims? If yes: narrower utility patent
- Have competitors copied Squad? If yes: prioritize patenting
- Has Squad been publicly disclosed? If yes: 12-month US grace period timer started
- International expansion planned? If yes: consider PCT filing (enables multi-country coverage)

---

## Critical Items Requiring Tamir's Decision

### 1. Confirm Inventorship

Patent validity depends on correctly listing **all co-inventors**. Each co-inventor must consent to filing.

**Questions for Tamir:**
- Who conceived Ralph proactive monitoring pattern?
- Who conceived universe-based casting with governance?
- Who conceived Git-native state coordination?
- Who conceived drop-box memory pattern?

**Default assumption** (confirm or correct):
- Tamir: primary inventor (overall system architecture)
- [TBD]: co-inventor(s) for specific patterns

**Action**: Reply with names + roles; I'll update patent application before submission

### 2. Confirm Filing Intent

Is Squad being filed for:
- Defensive protection (prevent copying)?
- Offensive strategy (licensing revenue)?
- Company IP program participation (Microsoft rewards)?
- Combination of above?

**Recommendation**: All three (defensive + participation in rewards program is smart play)

### 3. Timing: Public Disclosure Imminent?

Patent rights are lost in most jurisdictions if public disclosure occurs **before filing**.

**Has Squad been publicly disclosed?**
- ❌ Confidential (keep confidential until filing — we're on timeline)
- ✅ Yes, blog posts published (we're in grace period — must file soon to lock in rights)
- ✅ Yes, GitHub public repo (we're in grace period — must file soon)
- ✅ Yes, conference talks (we're in grace period — must file soon)

**US Grace Period**: 1 year from first public disclosure to file and retain rights  
**Other countries**: NO grace period (filing before disclosure mandatory)

**Action**: Confirm current status; if disclosed, we must file within 1 year to preserve US rights

### 4. gitclaw Timeline Investigation

**Critical for git-native state claims**:

If `gitclaw` (github.com/open-gitagent/gitclaw) was conceived/published **before Squad**, then git-native coordination claims may be invalid.

**Action items**:
- When did Squad git-native state conception start? (Approximate date)
- When did gitclaw development start? (Check GitHub history)
- If gitclaw predates Squad: remove git-native from independent claims, keep as conditional dependent claim

**Status**: Research report flagged this; waiting for your timeline info to confirm

### 5. International Filing Scope

**Options for utility patent conversion (month 10)**:

| Option | Scope | Cost | Timeline |
|--------|-------|------|----------|
| **US Only** | United States | ~$8K | 6-12 months to grant |
| **US + Canada/UK** | North America + Europe | ~$12-15K | 12-18 months |
| **PCT Filing** | 150+ countries under single app | ~$5K filing + per-country costs | 18-36 months decision |

**Recommendation**: File US provisional now; reassess at month 10 based on:
- Competitive threat level (did others copy?)
- International Squad expansion plans
- Microsoft's strategic intent

---

## Success Criteria

Patent filing is successful when:

- [ ] Co-inventors confirmed and consented
- [ ] Tamir reviews claims and confirms accuracy
- [ ] gitclaw timeline investigated (confirm git-state claims viability)
- [ ] Patent application submitted via Microsoft Inventor Portal
- [ ] Provisional patent issued (~4 weeks after submission)
- [ ] Priority date locked in (prevents future prior art)

**Stretch goal**: Utility patent granted within 2 years (standard USPTO timeline)

---

## Related Decisions

### Decision 15: OpenCLAW Pattern Adoption (Complementary)

OpenCLAW patterns (QMD framework, Issue-Triager, Dream Routine) extract institutional knowledge from channels into Skills. This complements patent strategy:

- Patent claims the **system architecture** (Ralph, casting, state, consensus)
- OpenCLAW patterns **populate the knowledge** that system operates on
- Together: defensible IP (system) + defensible moat (proprietary knowledge)

**Synergy**: Filing patent on core architecture + documenting proprietary extraction patterns = defensible competitive advantage

---

## Timeline

| Week | Milestone | Owner |
|------|-----------|-------|
| **1** | ✅ Patent claims draft complete | Seven (DONE) |
| **2** | ⏳ Tamir confirms inventors, files decision | Tamir |
| **3** | ⏳ Tamir internal review of claims accuracy | Tamir |
| **3** | ⏳ Patent attorney prepares diagrams | Microsoft (auto) |
| **4** | ⏳ Submit via Microsoft portal | Tamir (with Seven support) |
| **4-8** | ⏳ USPTO provisional review | Microsoft attorney (auto) |
| **~8** | ✅ Provisional patent issued | USPTO |

**Critical path**: Tamir's inventor confirmation + decision + review is the blocker. Patent attorney work (diagrams, refinement) is fast-track once inventors confirmed.

---

## Appendix: Comparison to Competing Patents

### WO2025099499A1 (NEC Labs — "Multi Agent Task Planning")

**What it claims:**
- Meta-agent orchestrating sub-agent task decomposition
- Task scheduling and collaborative workflows
- Generic multi-agent coordination

**Why TAM is different:**
- NEC patent doesn't cover proactive monitoring
- NEC patent doesn't cover governance policies
- NEC patent doesn't cover git-native state or auditability
- TAM's integration + autonomous recovery + governance is novel

**Filing strategy**: Reference NEC patent in patent application as "related prior art"; distinguish TAM by focusing on autonomous recovery + governance (which NEC lacks)

### CrewAI (Open Source — 13k+ GitHub stars)

**What it has:**
- Task routing to agent roles
- Memory/state management
- Workflow orchestration

**Why TAM is different:**
- CrewAI has no proactive monitoring (no Ralph equivalent)
- CrewAI has no autonomous recovery (only basic error handling)
- CrewAI has no governance policies (just role-based routing, not org-level policies)
- CrewAI has no git-native state (uses database/API)

**Filing impact**: CrewAI establishes prior art for general orchestration; TAM's claims must be narrow enough to not overlap. Our narrow focus (autonomous recovery + governance) is outside CrewAI's scope.

---

## Decision Outcome

**Approved**: Proceed with Option A (narrow TAM-focused claims)  
**Next Action**: Await Tamir's inventor confirmation and filing decision  
**Document**: PATENT_CLAIMS_DRAFT.md (639 lines, ready for review)  
**Tracking**: Issue #42, PR #60  

---

**Prepared by**: Seven (Research & Docs)  
**Approved by**: [Awaiting Tamir]  
**Date**: March 11, 2026
