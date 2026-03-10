# Decision: @copilot Integration into Squad

**Date:** 2026-03-10  
**Decider:** B'Elanna (Infrastructure Expert)  
**Context:** Issue #269  
**Status:** ✅ Implemented (PR #270)

## Decision

Integrated @copilot as a Coding Agent member of the Squad with:
1. Capability-based routing (🟢/🟡/🔴 rating system)
2. Auto-assignment for `squad:copilot` labeled issues
3. Scheduled PR health monitoring every 15 minutes
4. Guidance documentation for @copilot operations

## Rationale

**Why now:**
- Squad has well-defined tasks suitable for autonomous agent work (bug fixes, tests, small features)
- PR review overhead can be reduced with automated monitoring and reviews
- @copilot routing infrastructure already exists in `.squad/routing.md`

**Why this approach:**
- **Capability profile** allows Lead to triage appropriately (🟢 = good fit, 🟡 = needs review, 🔴 = not suitable)
- **Auto-assign flag** enables autonomous pickup without manual assignment
- **Schedule.json entry** ensures PR health is monitored consistently
- **Copilot-instructions.md** provides clear boundaries and escalation paths

## Implementation Details

### 1. Team Roster Changes (`.squad/team.md`)
```markdown
| @copilot | Coding Agent | — | 🤖 Active |

<!-- copilot-auto-assign: true -->

## @copilot Capability Profile
| Category | Rating | Notes |
|----------|--------|-------|
| Bug fixes, test additions | 🟢 Good fit | Well-defined, bounded scope |
| Small features with specs | 🟡 Needs review | PR review required |
| Architecture, security | 🔴 Not suitable | Keep with squad members |
```

### 2. Scheduled Monitoring (`schedule.json`)
```json
{
  "name": "pr-health-check",
  "interval": "15m",
  "description": "Check open PRs for review feedback, CI failures, stale PRs, auto-merge approved"
}
```

### 3. Guidance Documentation (`.github/copilot-instructions.md`)
- Context reading (team.md, routing.md, decisions.md)
- Project conventions (branch naming: `squad/{issue}-{description}`)
- Capability boundaries (when to escalate to squad members)
- PR guidelines (review behavior, testing requirements)
- Escalation procedures (tag @picard for unclear requirements, @worf for security, @belanna for infrastructure)

## Routing Workflow

1. **Issue gets `squad` label** → Lead (Picard) triages
2. **Lead evaluates @copilot capability fit:**
   - 🟢 Good fit → Apply `squad:copilot` label
   - 🟡 Needs review → Apply `squad:copilot` + note "PR review required"
   - 🔴 Not suitable → Route to appropriate squad member
3. **`squad:copilot` label applied + auto-assign enabled** → @copilot is assigned automatically
4. **@copilot works on issue** → Creates PR with `Closes #<issue-number>`
5. **PR health check (every 15 min)** → Monitors reviews, CI, staleness, auto-merge approved PRs

## Constraints & Boundaries

**@copilot should handle:**
- Bug fixes with clear reproduction steps
- Test additions for existing features
- Dependency updates
- Documentation updates (non-architectural)
- Small features with complete specifications

**@copilot should NOT handle:**
- Architecture decisions or design changes
- Security-sensitive code (auth, encryption, access control)
- API design or breaking changes
- Complex refactoring without tests
- Work requiring domain expertise or judgment calls

**Escalation triggers:**
- Unclear or incomplete requirements
- Security concerns discovered during work
- Architecture questions
- Infrastructure/deployment issues

## Branch Protection (Deferred)

Requiring reviews before merge requires GitHub repo admin access. Configuration steps:
1. Settings → Branches → Branch protection rules
2. Add rule for `main` branch
3. Require pull request reviews before merging (1 approver minimum)
4. Require status checks to pass before merging

**Decision:** Defer to Tamir (repo admin) or configure after PR #270 merges.

## Success Metrics

- **Issue throughput:** Number of `squad:copilot` issues completed per week
- **PR quality:** Review approval rate, CI pass rate
- **Escalation rate:** % of issues @copilot escalates to squad members
- **Lead triage time:** Time spent evaluating capability fit per issue
- **PR staleness:** % of PRs that become stale (no activity for 7+ days)

## Alternatives Considered

1. **Manual @copilot assignment (no auto-assign)**
   - Rejected: Adds friction; Lead would need to manually assign every time
   
2. **No capability profile (route everything)**
   - Rejected: @copilot would receive inappropriate tasks (security, architecture)
   
3. **No scheduled PR monitoring**
   - Rejected: PRs could go stale; CI failures unnoticed
   
4. **External PR monitoring tool**
   - Rejected: Squad already has schedule.json + Ralph infrastructure

## Rollback Plan

If @copilot integration causes issues:
1. Remove `squad:copilot` routing from `.squad/routing.md`
2. Set auto-assign flag to `false` in `team.md`
3. Remove `pr-health-check` from `schedule.json`
4. Re-route open `squad:copilot` issues to squad members

## Future Enhancements

- **PR auto-merge:** If CI passes + approved → auto-merge (requires branch protection + repo settings)
- **Review comment resolution:** @copilot responds to review feedback autonomously
- **Capability learning:** Track which issue types succeed/fail → refine capability profile
- **Multi-agent coordination:** @copilot + squad member pair programming for 🟡 complexity work

## References

- Issue: #269
- PR: #270
- Related routing: `.squad/routing.md` (lines 16, 25)
- Team charter: `.squad/team.md`
- Schedule manifest: `schedule.json` (repo root)
