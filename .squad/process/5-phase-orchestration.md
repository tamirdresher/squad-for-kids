# Squad 5-Phase Orchestration Pipeline

## Overview
Standard pipeline for all feature-level tasks. Ralph uses this to decompose any
issue labeled `go:yes` into structured agent handoffs.

## The 5 Phases

### Phase 1: RESEARCH (Agent: seven/explore)
**Input:** Issue body + acceptance criteria  
**Output:** `research/{issue}-{slug}.md`  
**Trigger:** Issue has label `go:needs-research`  
**Done when:** Research doc committed, PR open, issue comment posted  

### Phase 2: PLAN (Agent: picard)
**Input:** Research doc + issue body  
**Output:** `plan.md` in session state (or `docs/plans/{slug}.md` for major features)  
**Uses:** ECC structured planner format (see picard charter)  
**Done when:** Plan reviewed and approved (or auto-approved for issues labeled `go:yes`)  

### Phase 3: IMPLEMENT (Agent: data/belanna/worf by type)
**Input:** Plan doc + issue context  
**Output:** Code changes committed to feature branch  
**Agent routing:**
- Code changes → `data` agent  
- Infrastructure/K8s → `belanna` agent  
- Security → `worf` agent  
**Done when:** All acceptance criteria met, tests pass  

### Phase 4: REVIEW (Agent: code-review / worf for security)
**Input:** Feature branch diff  
**Output:** PR review comments using ECC review format  
**Done when:** No CRITICAL/HIGH issues, or all are addressed  

### Phase 5: DELIVER (Agent: Ralph/neelix)
**Input:** Approved PR  
**Output:** Merged PR, closed issue, board moved to Done, Teams notification  
**Done when:** PR merged, issue closed, board updated, Neelix notified  

## Phase Skipping Rules
- Skip Phase 1 if issue has `go:no-research` label or is a clear bug fix
- Skip Phase 2 if task is <2h estimated and requirements are fully specified in issue
- Skip Phase 4 for documentation-only changes
- Never skip Phase 5

## Iterative Retrieval (Phase 3 sub-rule)
During implementation, agents may call back to Phase 1 (research) at most 3 times.
Each call-back must specify WHY additional context is needed. After 3 cycles, implement with best available information.

## Ralph Scheduling
Ralph checks issue labels to determine entry phase:
- `go:needs-research` → Start at Phase 1
- `go:yes` (no research label) → Start at Phase 3
- `go:needs-decision` → Pause, escalate to Tamir
- `go:no` → Skip entirely
