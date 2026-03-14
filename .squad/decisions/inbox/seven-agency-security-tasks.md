# Decision: Agency Security Squad Tasks — Multi-Agent Hardening Initiative

**Date:** 2026-03-14
**Author:** Seven (Research & Docs)
**Issue:** #486 (Agency Security Squad meeting analysis)
**Status:** 🟡 **Proposed** — Awaiting squad assignment and Tamir prioritization decision
**Requestor:** Tamir Dresher
**Scope:** Security Research + Strategic Communication

---

## Problem

Microsoft's Agency Security Squad met on 2026-03-12 to discuss implementing a "chief of staff" pattern — autonomous agents making routine decisions without human intervention. The meeting raised critical concerns:

1. **How do multi-agent systems stay secure?** (Prompt injection, credential exposure, lateral escalation)
2. **What's the research gap?** (No formal security architecture for agent frameworks)
3. **Can this approach scale to enterprise?** (Requires proven mitigations)

Our Squad has already built a working proof-of-concept (Tamir's blog: *How an AI Squad Changed My Productivity* — 48-hour case study with quantified results). Now we need to:
- **Communicate success** to Mitansh Shah (organizer) with concrete demo
- **Harden security** by researching + designing mitigations
- **Validate externally** with security researchers
- **Contribute to field** by publishing our findings

---

## Decision: Four Parallel Workstreams

### Workstream 1: Strategic Communication (Owner: Seven)

**Task:** Draft communication to Mitansh Shah (mitashah@microsoft.com)

**What to Include:**
- Tamir's blog as **concrete showcase** of chief-of-staff pattern working
- Squad Monitor demo (real-time agent activity dashboard)
- Reference to Brady's Squad + our Squad as **production implementations** of Agency principles
- Offer: Demo session + collaboration opportunity on security hardening

**Why:** Time-sensitive. Agency team may be planning Enterprise rollout. Positioning Tamir's Squad as reference implementation opens partnership opportunities.

**Acceptance Criteria:**
- ✅ Email drafted and approved by Tamir
- ✅ Demo link provided (Squad Monitor dashboard)
- ✅ Collaboration proposal included

**Timeline:** This week (2026-03-14 to 2026-03-20)

---

### Workstream 2: Prompt Injection Attack Surface (Owner: Worf with Data + Picard)

**Task:** Comprehensive attack surface analysis + mitigation design for prompt injection in agent frameworks

**What to Research:**
1. **Attack Vectors (5+ scenarios):**
   - Malicious GitHub issue comments → SQLi in query builders
   - Poisoned .squad/ config files → arbitrary decision override
   - Hostile PR descriptions → prompt manipulation of code review agents
   - Environment variable injection → credential exposure
   - Supply chain: malicious dependencies → injected instructions at runtime

2. **Why Agents Are Vulnerable (vs. Traditional Apps):**
   - Agents take external input and **make decisions on it** (not just render it)
   - Decisions cascade through system (one compromised agent → all downstream agents)
   - No traditional "output encoding" defense (agent is both executor and decision-maker)

3. **Mitigation Strategies:**
   - **Input Sanitization Layer**: All external inputs validated + sanitized before agent processing
   - **Isolation Capsule Pattern**: Each agent runs with minimal required permissions (least privilege)
   - **Decision Validation**: Decisions must pass consistency checks (signature verification, anomaly detection)
   - **Audit Trail**: Every decision + reasoning logged for post-incident analysis

4. **Proof-of-Concept:**
   - Inject adversarial prompts into test GitHub issues
   - Verify Ralph watch loop blocks them
   - Document successful blocks in test report

**Deliverable:** `.squad/research/prompt-injection-attack-surface.md`
- Problem statement
- 5+ documented attack vectors with examples
- 4 mitigation strategies with implementation guidance
- PoC test results
- Recommendations for Squad + Agency framework

**Timeline:** 2-3 weeks (2026-03-21 to 2026-04-04)

---

### Workstream 3: Multi-Agent Security Architecture (Owner: Worf with B'Elanna + Picard)

**Task:** Design comprehensive security architecture for multi-agent systems

**Threat Model (What We're Defending Against):**

1. **Lateral Escalation**: Agent A compromised → steal Agent B's credentials/scope
2. **Chain Reaction**: Malicious decision cascades through connected agents (one bad decision triggers cascade of dependent decisions)
3. **Resource Exhaustion**: Rogue agent spawns infinite task loops → DoS
4. **Data Poisoning**: Corrupt .squad/decisions.md → all future decisions based on false data
5. **Sandbox Escape**: Local vulnerabilities → arbitrary OS-level execution

**Defense Architecture (5 Layers):**

**Layer 1: Network Isolation**
- Agents communicate via authenticated channels (not shared memory/files)
- Each agent gets isolated namespace (scheduler-dependent: Kubernetes pods, Azure Container Instances, or local process groups)

**Layer 2: Ephemeral Credentials**
- Each agent gets scoped, time-limited tokens (15-min TTL)
- Tokens have explicit capability scopes (e.g., "read GitHub issues", "write decisions")
- No long-lived credentials stored locally

**Layer 3: Signature Verification**
- All decisions cryptographically signed by issuing agent
- No decision execution without valid signature
- Enables post-breach forensics ("Which agent made this decision?")

**Layer 4: Canary Deployment**
- New agents (or updated versions) start in **read-only mode** before full access
- Monitor behavior for 24-48 hours
- Automatic promotion to full access if no anomalies detected

**Layer 5: Circuit Breaker**
- Monitor each agent's decision rate, error rate, resource usage
- Automatic kill switch if agent exceeds anomaly thresholds
- Alert Scribe + Picard for immediate investigation

**Implementation Standards:**
- Design as `.squad/standards/agent-security-architecture.md`
- Reference existing: OpenAI evals, OWASP Agent Security guidelines
- Include deployment patterns (Kubernetes, local, Azure Container Apps)
- Roadmap for integration into Squad framework

**Deliverable:** `.squad/standards/agent-security-architecture.md`
- Threat model (documented)
- 5-layer defense architecture
- Implementation guide per deployment scenario
- Risk assessment (residual risks after mitigations)
- Integration roadmap

**Timeline:** 3-4 weeks (2026-03-21 to 2026-04-11)

---

### Workstream 4: Security Researcher Outreach (Owner: Seven with Worf)

**Task:** Establish collaboration with academic + industry security researchers

**Who to Contact:**
- **OWASP**: Agent Security working group (if exists, or propose creation)
- **Microsoft Research**: AI safety + agent security teams
- **Academia**: CMU, Stanford, MIT labs focusing on AI agent security
- **Industry**: OpenAI, Anthropic security researchers
- **Internal**: Microsoft Defender team (MDE.ServiceModernization — Copilot CLI assets repo)

**What to Propose:**
- Open collaboration on multi-agent security hardening
- Squad as **testbed** for agent security patterns
- Joint research: publish findings on prompt injection, lateral escalation defenses
- Validation: have external researchers audit our architecture

**Deliverables:**
- Collaboration proposal document (1-2 pages)
- Researcher contact list (20-30 key contacts)
- Meeting notes + feedback from initial outreach
- Joint research roadmap (if partners agree)

**Timeline:** 2-3 weeks (2026-03-21 to 2026-04-04)

---

## Consequences

✅ **If adopted:**
- Squad becomes **reference implementation** for Agency enterprise rollout
- Security research contributes to **field maturity** (entire industry benefits)
- Tamir + Brady positioned as **thought leaders** in agent security
- Partnership with Agency team → institutional credibility

⚠️ **If deferred:**
- Agency team proceeds without proven security patterns → potential enterprise risks
- Missed partnership opportunity with Microsoft internal adoption
- Security gaps remain in our own Squad implementation

---

## Dependencies

- **Workstream 1** (Communication) is time-sensitive — should start immediately
- Workstreams 2-4 can run in parallel after Tamir prioritizes
- Communication to Mitansh may inform priority/timeline (he may have Agency roadmap constraints)

---

## Status Tracking

| Workstream | Owner | Status | ETA |
|------------|-------|--------|-----|
| 1. Communication | Seven | 🟡 Proposed | 2026-03-20 |
| 2. Prompt Injection | Worf + Data | 🟡 Proposed | 2026-04-04 |
| 3. Arch Design | Worf + B'Elanna | 🟡 Proposed | 2026-04-11 |
| 4. Researcher Outreach | Seven + Worf | 🟡 Proposed | 2026-04-04 |

---

**Decision Status:** Proposed. Awaiting Tamir prioritization and squad assignment.
**Next Action:** Tamir to confirm: (1) Priority ranking, (2) Approval to contact Mitansh Shah, (3) Resource allocation.
