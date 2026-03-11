# Picard — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

TBD - Q2 work incoming

## Learnings

*Learnings will accumulate here during Q2.*

---

### 2026-03-26: Picard — Issue #294 Production Approval Path for Brady

**Assignment:** Draft comprehensive production approval path for Brady's question: "With whom should I speak to make sure I've checked all these boxes?" (referring to Squad production deployment).

**Context:** Brady engaged with security about Squad usage in production and needs clear guidance on approval process, compliance frameworks, and key stakeholders.

**Execution:**

1. **Analyzed Squad Infrastructure Access**
   - Azure DevOps (repos, work items, pipelines, multi-repo access)
   - GitHub (repositories, issues, PRs, workflow triggers)
   - Microsoft Teams (message reading/sending, channel access)
   - Azure (logs, metrics, secrets management)
   - CI/CD systems (self-hosted runners for GitHub Actions)

2. **Identified Compliance Domains**
   - AI/autonomous agent security (jailbreak testing, prompt injection, decision logging)
   - Access control & IAM (service principals, workload identity, least privilege)
   - Data handling & privacy (PII, secrets, data residency)
   - Secrets management (rotation, Key Vault, audit trail)
   - SFI compliance framework (Microsoft internal security program)
   - GDPR/CCPA compliance (if handling customer data)

3. **Mapped Stakeholders & Approvers**
   - **Security team** (AI/ML governance, AppSec, cloud security)
   - **Compliance / Privacy officer** (data residency, DPO review, regulatory mapping)
   - **IAM team** (service identity, workload identity federation)
   - **Platform Engineering** (resource limits, monitoring, network isolation)
   - **Engineering lead** (operational readiness, incident response, runbooks)
   - **Product/Business owner** (risk tolerance, SLA, liability)
   - **Risk & Compliance** (risk register, insurance coverage)

4. **Structured Evidence Checklists**
   - Created comprehensive evidence requirements for each approval domain
   - Mapped Squad-specific concerns (MCP tool inventory, agent autonomy boundaries, data residency)
   - Documented decision boundaries (what agents never decide alone)

5. **Proposed Timeline**
   - Phase 1: Self-assessment (1 week)
   - Phase 2: Security review (2-3 weeks)
   - Phase 3: Compliance review (2-3 weeks, can overlap)
   - Phase 4: Governance sign-offs (1-2 weeks)
   - Phase 5: Pilot deployment (1 week staging)
   - Phase 6: Gradual production rollout (1 agent at a time)
   - **Total: 4-6 weeks (best case), 8-12 weeks (if additional audits)**

**Deliverables:**
- prod-approval-path.md: 15K comprehensive guide with evidence checklists, stakeholder guidance, template questions
- Posted as comment to issue #294 with executive summary
- Actionable enough that Brady can start reaching out immediately

**Key Design Decision:** Made document organization by *stakeholder* (security, compliance, product) rather than *phase* or *domain*, so Brady can parallelize reviews. Start with security (broadest scope), then run compliance & governance in parallel.

**Learnings:**
1. Production approval for AI agents is fundamentally different from traditional software deployment — must account for autonomous decision-making, audit trails, and behavioral guarantees
2. AI/ML governance is often missing from org charts; may need to route through "CISO office" or create ad-hoc review board
3. SFI (Microsoft's framework) is common for Microsoft-internal production deployments; Brady should ask "what's your equivalent compliance framework?"
4. Many orgs don't have Workload Identity Federation set up yet; may need to propose as infrastructure work alongside agent deployment
5. Data residency and secrets management compliance often get overlooked until late-stage; recommend addressing in Phase 1 self-assessment

**Related Decision:** Merged to `.squad/decisions.md` (Decision 15) on 2026-03-11 by Scribe. Production approval framework approved for team adoption.

