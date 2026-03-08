# Decision: Cache Review Automation via Ralph-Watch

**Date:** 2026-03-08  
**Decision Maker:** B'Elanna (Infrastructure Expert)  
**Context:** Issue #116 — Monthly cache reviews need automation  
**Status:** Implemented

---

## Problem

Tamir requested automation for the monthly FedRAMP cache review (scheduled April 1, 2026) because he won't remember to trigger it manually. The issue would otherwise sit idle until someone notices.

---

## Constraints

1. **GitHub Actions unavailable** — EMU restrictions prevent GitHub-hosted runners from provisioning (Issue #110)
2. **Must run automatically** — No manual intervention on the 1st of each month
3. **Must integrate with existing tooling** — gh CLI, project boards, labels
4. **Must be testable** — Ability to verify before going live

---

## Decision

**Integrate scheduled automation into ralph-watch.ps1:**

1. **Created:** `scripts/scheduled-cache-review.ps1`
   - Checks if today is the 1st of the month
   - Auto-creates issue with full cache review checklist
   - Adds to project board as "Todo"
   - Labels appropriately for squad triage

2. **Modified:** `ralph-watch.ps1`
   - Added "Step 0: Run scheduled tasks" before agency copilot invocation
   - Calls scheduled-cache-review.ps1 every round
   - Script self-checks date and exits quickly if not due

3. **Testing:** Added `-Force` flag to allow manual testing anytime

---

## Alternatives Considered

### ❌ GitHub Actions (rejected)
- **Why not:** EMU restrictions prevent runner provisioning
- **Evidence:** Issue #110 shows 0-step executions on all workflows

### ❌ Windows Task Scheduler (rejected)
- **Why not:** Requires manual setup on each machine running ralph-watch
- **Problem:** Not portable, not versioned in git, fragile across environments

### ❌ Azure DevOps Pipelines (rejected)
- **Why not:** Adds external dependency, requires separate config
- **Problem:** Not integrated with existing ralph-watch flow

### ✅ Ralph-Watch Integration (selected)
- **Why yes:** Already running continuously, has all permissions, uses gh CLI
- **Benefits:** Portable, versioned, testable, zero external dependencies

---

## Implementation Details

**Script Location:** `scripts/scheduled-cache-review.ps1`  
**Integration Point:** `ralph-watch.ps1` line ~302 (before git pull)  
**Frequency:** Every ralph-watch round (5 minutes), script self-gates to 1st of month  
**Exit Behavior:** Exits quickly if not due, doesn't block main flow

**Issue Template:** Full cache review checklist with:
- Meeting agenda and attendees
- Kusto queries for Application Insights
- Deliverables checklist
- Reference documentation links

---

## Impact

**Positive:**
- ✅ Zero manual intervention needed
- ✅ Consistent format every month
- ✅ Integrated with project board
- ✅ Easy to test and modify
- ✅ Versioned in git

**Risks:**
- ⚠️ If ralph-watch isn't running on April 1, review won't auto-create (acceptable — ralph-watch is expected to run continuously)
- ⚠️ Script runs every round (5 min intervals), but self-checks date and exits quickly

**Mitigations:**
- Ralph-watch has heartbeat monitoring and Teams alerts
- Script is idempotent — can be run multiple times safely
- `-Force` flag allows manual triggering if needed

---

## Pattern for Future Use

This establishes a pattern for any **scheduled automation** in the repo:

1. Create standalone PowerShell script in `scripts/` directory
2. Script should self-check conditions (date, state, etc.) and exit quickly if not due
3. Integrate into ralph-watch.ps1 "scheduled tasks" section
4. Use gh CLI for GitHub operations (portable, versioned)
5. Include `-Force` flag for testing
6. Document in `.squad/agents/belanna/history.md`

**Examples for future:**
- Weekly dependency updates
- Monthly security scans
- Quarterly documentation reviews
- Periodic cleanup tasks

---

## Validation

**Testing:**
- ✅ Dry run: `.\scripts\scheduled-cache-review.ps1` (exits on non-1st day)
- ✅ Integration: Modified ralph-watch.ps1 calls script before agency
- ✅ Issue closed: #116 moved to Done column
- ✅ Comment posted: Explained solution to Tamir

**Next Milestone:** April 1, 2026 — verify automatic issue creation

---

## References

- **Issue #116:** Cache Review: April 2026 (CLOSED)
- **Issue #110:** GitHub Actions EMU restrictions
- **Script:** `scripts/scheduled-cache-review.ps1`
- **Integration:** `ralph-watch.ps1` line ~302
- **Skill:** `.squad/skills/github-project-board/SKILL.md`
