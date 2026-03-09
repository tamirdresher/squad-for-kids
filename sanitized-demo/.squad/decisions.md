# Squad Decisions

This file tracks team-wide decisions that all agents must follow. Each decision includes context, rationale, and impact.

## Decision Template

```markdown
## Decision N: {Title}
**Date:** YYYY-MM-DD
**Author:** {Agent}
**Status:** ✅ Adopted | 🔄 Proposed | ⚠️ Action Required | 💬 Needs Team Input
**Scope:** {Domain - e.g., Process, Infrastructure, Security, Code Review}

### Context
{Why is this decision needed?}

### Decision
{What did we decide?}

### Rationale
{Why did we choose this approach?}

### Impact
{How does this affect the team?}
- ✅ Benefit 1
- ✅ Benefit 2
- ⚠️ Consideration 1

### Related Issues
- #{IssueNumber}
```

---

## Decision 1: Gap Analysis When Access Blocked
**Date:** 2026-03-XX
**Author:** Picard
**Status:** ✅ Adopted
**Scope:** Process

### Context
Agents sometimes encounter projects or repositories where access is restricted or credentials are unavailable. Rather than blocking indefinitely, we need a productive approach.

### Decision
When direct access is blocked:
1. **Document what we know** - Gather context from public sources (docs, GitHub README, public issues)
2. **Gap analysis** - Identify specific information needed
3. **Recommend next steps** - Propose how to obtain access or work around limitations
4. **Escalate if needed** - Tag project owner for access requests

### Rationale
Partial progress is better than no progress. Documentation and gap analysis provide value even without full access.

### Impact
- ✅ Agents can make progress on blocked work
- ✅ Clear escalation path for access issues
- ✅ Documents what's needed for future work

---

## Decision 2: Explanatory Comments for pending-user Status
**Date:** 2026-03-XX
**Author:** Picard
**Status:** ✅ Adopted
**Scope:** Process

### Context
When agents move issues to "Pending User" status, the project owner needs clear context about what's being requested.

### Decision
When setting issue status to `pending-user`:
1. **Always add a comment** explaining what input is needed
2. **Be specific** - Don't just say "needs user input", explain exactly what question or decision is required
3. **Provide options** when possible - Give the user choices rather than open-ended questions
4. **Tag the user** with @mention so they're notified

### Rationale
Clear communication reduces round-trips and helps the project owner understand priority and urgency.

### Impact
- ✅ Faster response times from project owner
- ✅ Reduced ambiguity
- ✅ Better async collaboration

---

## Decision 3: Security Review Required for Auth Changes
**Date:** 2026-03-XX
**Author:** Worf
**Status:** ✅ Adopted
**Scope:** Security, Code Review

### Context
Authentication and authorization code is high-risk. Bugs in this area can lead to security vulnerabilities.

### Decision
All PRs that modify authentication, authorization, or session management code must:
1. **Be reviewed by @worf** before merging
2. **Include security test cases** demonstrating the change is safe
3. **Document any security assumptions** in PR description

### Rationale
Security vulnerabilities are expensive to fix post-deployment. Upfront review prevents issues.

### Impact
- ✅ Reduced security risk
- ✅ Consistent security patterns
- ⚠️ May slow down some PRs (acceptable trade-off)

---

## Decision 4: Infrastructure Changes Require Runbook
**Date:** 2026-03-XX
**Author:** B'Elanna
**Status:** ✅ Adopted
**Scope:** Infrastructure, Operations

### Context
Infrastructure changes (Kubernetes configs, CI/CD pipelines, cloud resources) can cause outages if not properly documented.

### Decision
All infrastructure changes must include:
1. **Deployment runbook** - Step-by-step deployment instructions
2. **Rollback procedure** - How to revert if something goes wrong
3. **Smoke tests** - How to verify deployment was successful
4. **Monitoring** - What metrics/logs to watch post-deployment

### Rationale
Runbooks enable safe deployments and quick recovery from issues.

### Impact
- ✅ Safer deployments
- ✅ Faster incident response
- ✅ Knowledge sharing across team
- ⚠️ Extra documentation work (worth it)

---

## Decision 5: Skills Are Documented After Second Use
**Date:** 2026-03-XX
**Author:** Seven
**Status:** ✅ Adopted
**Scope:** Knowledge Management

### Context
Agents discover patterns and procedures during work. We need a threshold for when to formalize these as Skills.

### Decision
Extract a pattern as a Skill after:
1. **Second successful use** - Pattern has been validated twice
2. **Distinct contexts** - Not just repeating the same task
3. **Reusable** - Likely to be useful again

Skill documentation includes:
- **Context:** When to use this skill
- **Procedure:** Step-by-step instructions
- **Examples:** Real usage from issues
- **Confidence:** High/Medium/Low based on validation

### Rationale
Balance between capturing knowledge and avoiding premature documentation of one-time patterns.

### Impact
- ✅ High-quality skills library
- ✅ Reduced documentation overhead
- ✅ Validated patterns only

---

## Decision 6: Project Board Status Must Stay Synchronized
**Date:** 2026-03-XX
**Author:** Ralph
**Status:** ✅ Adopted
**Scope:** Process, Automation

### Context
GitHub Project board is the source of truth for work status. Stale status causes confusion.

### Decision
Agents must update project board status when:
1. **Starting work** - Move to "In Progress"
2. **Completing work** - Move to "Done"
3. **Blocked** - Move to "Blocked" with comment explaining why
4. **Waiting for user** - Move to "Pending User" with explanatory comment

Use the `.squad/skills/github-project-board/SKILL.md` procedure.

### Rationale
Real-time visibility into what's being worked on. Prevents duplicate work and helps prioritization.

### Impact
- ✅ Always-current work status
- ✅ Better coordination
- ✅ Clear blockers
- ⚠️ Requires discipline from all agents

---

## Decision 7: Commits Must Reference Issue Numbers
**Date:** 2026-03-XX
**Author:** Data
**Status:** ✅ Adopted
**Scope:** Code, Process

### Context
Traceability between code changes and issues is essential for understanding context.

### Decision
All commit messages must:
1. **Include issue number** - Format: `feat: #42 Add user authentication`
2. **Follow conventional commits** - Type prefix (feat/fix/docs/chore)
3. **Be descriptive** - Explain what changed, not just that it changed

### Rationale
Links code changes to requirements and discussions. Makes git history searchable and meaningful.

### Impact
- ✅ Better git history
- ✅ Traceability
- ✅ Easier debugging

---

## Decision 8: Teams Notifications Only for Actionable Items
**Date:** 2026-03-XX
**Author:** Ralph
**Status:** ✅ Adopted
**Scope:** Process, Automation

### Context
Too many notifications cause alert fatigue. Teams messages should be high-signal.

### Decision
Send Teams notifications only for:
1. **PRs ready for review** - Human input needed
2. **PRs merged** - Significant progress milestone
3. **Critical failures** - CI/CD failures, security alerts
4. **Blocked work** - Human decision required
5. **Work completed** - User-facing features done

Do NOT send for:
- Routine status checks with no changes
- WIP updates
- Internal agent coordination

### Rationale
Respect attention. Only interrupt for things that matter.

### Impact
- ✅ High signal-to-noise ratio
- ✅ Alerts are taken seriously
- ✅ Reduced notification fatigue

---

## Adding New Decisions

To propose a new decision:
1. Create issue with `decision` label
2. Use the template above
3. Tag relevant agents for input
4. Move to "Adopted" status after consensus
5. Update this file via PR
