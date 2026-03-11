# Decision: Squad Production Approval Framework

**Date:** 2026-03-26  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** Team / External Guidance  
**Issue:** #294 — Production approval path for Brady

---

## Decision

Establish a comprehensive **production approval framework for Squad** that:

1. **Maps all compliance domains** required for AI agent deployment in production
2. **Identifies stakeholders** (security, compliance, IAM, platform, product)
3. **Provides actionable evidence checklists** for each stakeholder
4. **Recommends realistic timeline** (4-12 weeks depending on org maturity)
5. **Clarifies Squad-specific concerns** (MCP tool access, agent autonomy, data residency)

This framework is documented in `prod-approval-path.md` and posted to issue #294 for Brady's immediate use.

---

## Rationale

**Why now:**
- Brady is actively seeking production approval guidance
- Squad team needs clarity on what approvals are required vs. optional
- Future operators (not just Brady) will benefit from a documented path

**Why this approach:**
- **Organization by stakeholder** (not phase) allows Brady to parallelize reviews
- **Evidence checklists** make it specific and non-negotiable (reduces ambiguity)
- **Squad-specific section** addresses AI agent risks head-on (not generic)
- **Timeline expectations** (4-12 weeks) prevent unrealistic "next week" promises

**Why important:**
- AI agents accessing production infrastructure require security + compliance alignment
- Different orgs have different compliance frameworks (SFI, GDPR, FedRAMP, etc.)
- Without clear guidance, Brady would spend weeks asking ad-hoc questions
- Document serves as reference for future Squad deployments

---

## Key Findings & Implications

### For Squad Team:

1. **Security clearance is not binary**
   - Multiple approval layers: AI security, access control, data handling, secrets
   - Compliance review typically waits for security clearance (can overlap)
   - Governance (platform, product) is usually last step

2. **MCP tool inventory is critical**
   - Brady must document what each agent can do with each tool
   - Least privilege principle applies: each agent gets minimum necessary permissions
   - Approvers will ask "why does agent X need repo *write* access?"

3. **Agent autonomy boundaries must be explicit**
   - Define what agents never decide alone (e.g., "merge to main")
   - Define what agents can do safely (e.g., "create draft PRs")
   - Missing boundaries = security review blocker

4. **Data residency is often overlooked**
   - Existing `.squad/decisions.md` and agent history are committed to repo
   - If they contain sensitive data → compliance issue
   - Phase 1 self-assessment should audit these files

### For External Stakeholders (Brady):

1. **Start with security, not compliance**
   - Security review gates everything else
   - Compliance review often waits for "security approved" status
   - Platform & product reviews are faster (usually 1-2 weeks)

2. **Timeline is realistic: 4-12 weeks**
   - Best case (cooperating org, no additional audits): 4-6 weeks
   - Typical (bureaucratic process, multiple review rounds): 8-10 weeks
   - Worst case (regulatory audit, EU AI Act review): 12+ weeks

3. **Workload Identity Federation is likely required**
   - Most orgs don't have it set up yet
   - Propose it as infrastructure work *before* agent deployment
   - Reduces approval time (cleaner IAM posture)

---

## Consequences

✅ **Benefits:**
- Brady (and future operators) have clear, structured guidance
- Squad team has framework for future deployments
- Reduces back-and-forth with approvers ("here's what we need to address")
- Document can be tailored per organization (copy-and-customize approach)

⚠️ **Risks:**
- Document is generic; Brady's org may have different frameworks (SFI, HIPAA, etc.)
- Some approvers may not follow the outlined timeline
- Document assumes standard org structure (may not apply to startups or heavily regulated industries)

**Mitigation:**
- Document explicitly says "Tailor to your organization"
- Provides template questions Brady can ask any approver
- Framework is flexible enough to accommodate variations

---

## Implementation

1. **Completed:** `prod-approval-path.md` created (15K comprehensive guide)
2. **Completed:** Posted to issue #294 with executive summary
3. **Recommended:** Brady uses this as starting point for conversations with approvers
4. **Recommended:** Squad team reviews and updates based on Brady's feedback

---

## Related Decisions

- Decision 1: Gap Analysis When Repository Access Blocked (applies to future Squadron research)
- Decision 1.1: Explanatory Comments for pending-user (process discipline — apply same rigor to approvals)

---

## Questions for Brady

If you're reading this:

1. **Does your organization have an AI/ML governance process?** If so, start there (not with general security).
2. **What compliance frameworks apply?** (SFI, GDPR, FedRAMP, HIPAA, SOC 2, etc.)
3. **Do you have Workload Identity Federation set up?** If not, factor it into Phase 1 planning.
4. **Who is your DPO or data protection officer?** You'll need them for compliance review.
5. **Do you have a self-hosted runner program?** GitHub Actions on self-hosted runners requires platform engineering buy-in.

---

**Next Steps for Scribe:** Merge this decision to `.squad/decisions.md` under a new section "AI Agent Production Deployment" or "Squad Production Governance."
