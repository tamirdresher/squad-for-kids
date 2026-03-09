# Cross-Squad Orchestration Design

**Date:** 2026-03-09  
**Author:** Seven (Research & Docs)  
**Status:** Design Document for Issue #197  
**Audience:** Squad leadership, infrastructure team

---

## Executive Summary

Today, Squad operates as **independent instances** within their own repositories, with limited collaboration across squad boundaries. While `upstream` repos exist for organizational knowledge and `subsquad` patterns allow nested squads within the same instance, **inter-squad orchestration is not formalized**.

This document proposes a **cross-squad orchestration protocol** enabling squads to:
- Discover and connect to peer squads dynamically
- Delegate tasks across squad boundaries
- Share context, decisions, and personnel transparently
- Maintain audit trails and trust relationships

The goal: **One squad receives a task, but execution can flow across multiple squads, each leveraging their own expertise, decisions, and configuration.**

---

## Problem Statement

### Current Limitations

**Scenario:** A task arrives for Squad A that requires expertise from Squad B.

**Today:** 
- ❌ Squad A must manually extract Squad B's knowledge from `upstream` repos
- ❌ No formalized way to request Squad B's help
- ❌ No way to "run as Squad B" with Squad B's config, decisions, and personnel
- ❌ Squad A and Squad B cannot share task state or context
- ❌ No audit trail of cross-squad collaboration

### Why This Matters

1. **Organizational Scale:** As more squads come online (Platform Squad, Data Squad, DevEx Squad), tasks increasingly require **cross-functional expertise**.
2. **Efficiency:** Today, squads duplicate work. Cross-squad delegation would **reduce redundancy**.
3. **Consistency:** Decisions made in one squad should inform execution in others.
4. **Auditability:** Compliance and governance demand clear records of **who executed what and under which squad's authority**.

---

## Current Architecture

### Upstream Repos Pattern

```
.squad/upstream.json:
{
  "upstreams": [
    {
      "name": "dk8s-platform-squad",
      "type": "git",
      "source": "https://github.com/...",
      "ref": "main"
    }
  ]
}

.squad/_upstream_repos/
├── dk8s-platform-squad/
│   ├── .squad/
│   │   ├── team.md
│   │   ├── decisions.md
│   │   ├── charter.md
│   │   └── ...
```

**How it works:**
- Squad reads remote `.squad/` metadata to ingest decisions and team info
- **One-way dependency:** Current squad → Upstream squad(s)
- **No execution context:** Upstream is metadata only, not an execution target

### Subsquad Pattern

```
squad.config.ts:
{
  squadName: "Brady Squad",
  parentSquadId: "alice-squad"  // optional
}
```

**How it works:**
- Child squad inherits parent's decisions (in-repo hierarchy)
- **Still one instance:** Subsquad is part of the same repo, not a separate squad
- **No external delegation:** Cannot call out to peer squads

### Current Routing

From `.squad/routing.md`:
- Issues are assigned `squad:{member}` labels
- Members pick up work autonomously
- **No cross-squad work item flow**

---

## Proposed Architecture: Cross-Squad Orchestration

### 1. Squad Registry & Discovery

**Goal:** Squads need to find each other and establish trust.

```yaml
# .squad/registry.json (NEW)
{
  "squadId": "brady-squad",
  "squadName": "Brady Squad",
  "endpoint": "https://github.com/tamirdresher_microsoft/bradysquad/",
  "version": "1",
  "publicKey": "pk-brady-squad-...",  # for signing requests
  "discoverable": true,
  
  # Known peer squads
  "peers": [
    {
      "squadId": "platform-squad",
      "endpoint": "https://github.com/tamirdresher_microsoft/dk8s-platform-squad/",
      "trust": "verified",  # verified | unverified | untrusted
      "capabilities": ["kubernetes", "infrastructure", "helm"],
      "lastVerified": "2026-03-08T..."
    },
    {
      "squadId": "devex-squad",
      "endpoint": "https://github.com/tamirdresher_microsoft/devex-squad/",
      "trust": "unverified",
      "capabilities": ["tooling", "developer-experience"],
      "lastVerified": null
    }
  ]
}
```

**Discovery mechanism:**
- Manual: Each squad registers peers in `registry.json`
- Future: Central registry endpoint (e.g., `https://api.squad.ms/registry`)
- Verification: Squads sign registration requests to prove ownership

### 2. Cross-Squad Delegation Protocol

**Goal:** Task a peer squad without repo-switching or manual context passing.

#### 2.1 Delegation Request

```json
{
  "requestId": "req-f47ac10b-58c2-4372-a567-0e02b2c3d479",
  "fromSquadId": "brady-squad",
  "toSquadId": "platform-squad",
  "timestamp": "2026-03-09T10:30:00Z",
  "signature": "sha256:...",  # signed by source squad
  
  "taskType": "implement",  # implement | analyze | review | test | design
  "context": {
    "issueUrl": "https://github.com/tamirdresher_microsoft/tamresearch1/issues/197",
    "title": "Cross-squad orchestration design",
    "description": "Write design doc for squad coordination",
    "acceptance": "Design doc covers architecture, protocols, phases"
  },
  
  "requirements": {
    "expertise": ["kubernetes", "distributed-systems"],
    "confidenceLevel": "high",  # how confident Brady Squad is this peer can handle it
    "timeframe": "72 hours"
  },
  
  # Context to pass to peer squad
  "executionContext": {
    "teamMetadata": {
      "teamUrl": "brady-squad/team.md",
      "decisionsUrl": "brady-squad/decisions.md"
    },
    "decisionsThatApply": [
      "Infrastructure Patterns for idk8s-infrastructure",
      "Security Findings"
    ]
  },
  
  "authorizedActions": [
    "read",  # peer can read source repo for context
    "comment",  # peer can comment on GitHub issue
    "create-draft-pr",  # peer can open draft PR (requires explicit approval)
    "write-to-sandbox"  # peer can write to a designated integration branch
  ]
}
```

#### 2.2 Delegation Response

```json
{
  "requestId": "req-f47ac10b-58c2-4372-a567-0e02b2c3d479",
  "fromSquadId": "platform-squad",
  "toSquadId": "brady-squad",
  "timestamp": "2026-03-09T11:00:00Z",
  "signature": "sha256:...",  # signed by responding squad
  
  "status": "accepted",  # accepted | declined | needs-clarification
  "declineReason": null,
  
  "handoffDetails": {
    "assignedTo": "B'Elanna",  # which team member will execute
    "executionStart": "2026-03-09T11:30:00Z",
    "estimatedCompletion": "2026-03-10T11:00:00Z",
    "integrationBranch": "https://github.com/tamirdresher_microsoft/dk8s-platform-squad/tree/squad-197-brady-integration"
  },
  
  "workMetadata": {
    "workItemId": "platform-squad-work-123",  # internal tracking
    "trackingUrl": "https://github.com/tamirdresher_microsoft/dk8s-platform-squad/issues/456"
  }
}
```

### 3. Execution Context Handoff

When Platform Squad executes work delegated by Brady Squad, they need:
- Brady Squad's **charter** and **decisions** context
- Brady Squad's **team roster** (who to ask questions)
- Clear **authorization boundaries** (what they can/cannot do)

#### 3.1 Context Injection

Platform Squad's agent loads Brady Squad context:

```typescript
// .squad/agents/belanna/context-loader.ts (PSEUDO)

async function loadDelegationContext(delegationRequest: DelegationRequest) {
  // 1. Fetch source squad's metadata
  const sourceSquadTeam = await fetch(
    `${delegationRequest.fromSquadId}/team.md`
  );
  const sourceSquadDecisions = await fetch(
    `${delegationRequest.fromSquadId}/decisions.md`
  );
  
  // 2. Verify signatures
  if (!verifySig(delegationRequest.signature, delegationRequest)) {
    throw new Error('Invalid delegation request signature');
  }
  
  // 3. Prepare context object
  return {
    sourceSquad: {
      id: delegationRequest.fromSquadId,
      team: sourceSquadTeam,
      decisions: sourceSquadDecisions,
      contactPerson: sourceSquadTeam.lead  // who to ask questions
    },
    task: delegationRequest.context,
    authorizations: delegationRequest.authorizedActions,
    originalRequest: delegationRequest
  };
}

// 3. In agent execution loop, make context available
async function executeTask(task: Task, delegationContext?: DelegationContext) {
  // If this is a delegated task, inject source squad's context
  if (delegationContext) {
    process.env.SOURCE_SQUAD_ID = delegationContext.sourceSquad.id;
    process.env.SOURCE_SQUAD_CONTACT = delegationContext.sourceSquad.contactPerson;
    // Load source squad decisions into local decision cache
    loadDecisions(delegationContext.sourceSquad.decisions);
  }
  
  // Execute task as normal, but respecting delegationContext.authorizations
  return await agent.execute(task);
}
```

#### 3.2 Authorization Boundary Enforcement

```typescript
// Example: Platform Squad agent respects Brady Squad's authorizations

if (delegationContext && delegationContext.authorizations) {
  if (!delegationContext.authorizations.includes('create-draft-pr')) {
    throw new Error(
      'Not authorized to create PR in source repo. ' +
      'Allowed actions: ' + delegationContext.authorizations.join(', ')
    );
  }
}
```

### 4. Communication Protocol

#### 4.1 Sync vs. Async Execution

- **Sync:** Brady Squad waits for Platform Squad response (blocking, <5 min timeout)
- **Async:** Brady Squad submits task and polls for status (non-blocking, hours/days)

Default: **Async** (delegation is inherently async)

#### 4.2 Status Tracking

Brady Squad can poll Platform Squad's integration branch or tracking URL for progress:

```json
GET /squad-status/{requestId}

Response:
{
  "requestId": "req-f47ac10b-...",
  "status": "in-progress",  # queued | in-progress | completed | failed
  "progress": {
    "percentComplete": 45,
    "currentStep": "Writing design document",
    "lastUpdate": "2026-03-09T12:00:00Z"
  },
  "outputBranch": "squad-197-brady-integration",
  "estimatedCompletionTime": "2026-03-10T11:00:00Z"
}
```

#### 4.3 Result Delivery

Once Platform Squad completes the task:

1. **Code/content:** Pushed to integration branch
2. **Metadata:** Updated work item/PR with status
3. **Notification:** Callback to Brady Squad's webhook or polling endpoint
4. **Handoff:** Brady Squad pulls changes, reviews, merges or provides feedback

---

## Implementation Plan

### Phase 1: Foundation (Weeks 1-2)

**Goal:** Enable discovery and basic delegation protocol

**Deliverables:**
- [ ] `squad/registry.json` schema and validation
- [ ] Delegation request/response JSON schemas
- [ ] Signature verification (HMAC-SHA256)
- [ ] Discovery mechanism (manual registry + GitHub metadata)
- [ ] CLI command: `squad delegate --to platform-squad --task "implement feature X"`

**Files:**
- `.squad/registry.json`
- `.squad/schemas/delegation-request.schema.json`
- `.squad/schemas/delegation-response.schema.json`
- `tools/squad-cli/commands/delegate.ts`

**Success criteria:**
- Brady Squad can send delegated task to Platform Squad
- Platform Squad can receive and acknowledge request
- Request signature is verified

---

### Phase 2: Context Injection (Weeks 3-4)

**Goal:** Allow executing squad to run under source squad's context

**Deliverables:**
- [ ] Context loader (fetch team, decisions, charter from source squad)
- [ ] Context cache (avoid repeated fetches)
- [ ] Decision merging logic (source squad decisions + executing squad decisions)
- [ ] Environment variable injection for agents
- [ ] Audit logging (who ran what under whose context)

**Files:**
- `.squad/agents/_lib/delegation-context.ts`
- `.squad/agents/_lib/context-loader.ts`
- `.squad/agents/_lib/decision-loader.ts`
- `.squad/log/cross-squad-delegations.md`

**Success criteria:**
- Platform Squad agent can access Brady Squad's decisions
- Agent respects Brady Squad's team structure when asking questions
- Audit log shows execution context

---

### Phase 3: Authorization Boundaries (Weeks 5-6)

**Goal:** Enforce action permissions across squad boundaries

**Deliverables:**
- [ ] Authorization middleware (check `authorizedActions` before each operation)
- [ ] Scope validator (can this squad member perform this action in source squad?)
- [ ] Audit trail per action (what was attempted, succeeded, or blocked)

**Files:**
- `.squad/agents/_lib/authorization.ts`
- `.squad/agents/_lib/audit.ts`

**Success criteria:**
- Platform Squad cannot comment on Brady Squad repo if not authorized
- All cross-squad actions are logged with authorization status
- Policy violations are caught and reported

---

### Phase 4: Async Job Tracking (Weeks 7-8)

**Goal:** Long-running delegation tasks with progress tracking

**Deliverables:**
- [ ] Work item creation in executing squad's repo
- [ ] Status polling endpoint (REST or GitHub API)
- [ ] Progress updates (estimated completion, current step)
- [ ] Integration branch management (auto-create, cleanup after completion)
- [ ] Webhook notifications (optional: notify source squad when done)

**Files:**
- `.squad/agents/_lib/job-tracker.ts`
- `tools/squad-api/routes/squad-status.ts`

**Success criteria:**
- Brady Squad can poll Platform Squad's work status
- Integration branch is auto-managed
- Status is updated every 30 min while in-progress

---

### Phase 5: Central Registry (Weeks 9-10) [FUTURE]

**Goal:** Move from manual registry to discoverable peer network

**Deliverables:**
- [ ] Central registry API (`https://api.squad.ms/registry`)
- [ ] Squad registration endpoint
- [ ] Peer discovery by capability (find all squads with "kubernetes" tag)
- [ ] Trust verification (TLS certificates for squad domains)

**Out of scope for this design:** This is infrastructure work for a future phase.

---

## Trust & Security Model

### 1. Signature Verification (Request Origin)

Every delegation request and response is signed with the **squad's private key**.

```
Signature = HMAC-SHA256(
  privateKey=squad_key,
  message=JSON.stringify(requestBody)
)
```

Receiving squad verifies the signature using the **source squad's public key** (from registry).

### 2. Authorization Boundaries

Each delegation specifies what the executing squad can do:
- `read` — read-only access to source squad's repo
- `comment` — post comments to issue/PR
- `create-draft-pr` — open PRs (typically marked as draft)
- `write-to-sandbox` — write to integration branch only

Violation = action blocked + audit log + notification to source squad.

### 3. Audit Trail

Every cross-squad action is logged:

```yaml
Timestamp: 2026-03-09T12:30:45Z
SourceSquad: brady-squad
ExecutingSquad: platform-squad
Executor: B'Elanna
Action: create-draft-pr
Repository: tamirdresher_microsoft/tamresearch1
URL: https://github.com/tamirdresher_microsoft/tamresearch1/pull/201
Status: authorized | denied
Reason: "Created draft PR per delegation request req-f47ac10..."
```

### 4. Trust Levels

Peers in registry can have trust status:
- **verified** — signatures checked, past successful delegations, approved manually by lead
- **unverified** — signatures checked, but new peer or no approval yet
- **untrusted** — explicitly marked as untrusted (no delegation allowed)

Only **verified** peers can receive sensitive `authorizedActions` like `create-draft-pr`.

---

## Integration with Current Squad System

### Backward Compatibility

- Existing `upstream.json` pattern continues to work unchanged
- Subsquad pattern unchanged
- Routing.md assignment unchanged

### New Additions

- New `.squad/registry.json` alongside existing config
- New CLI command: `squad delegate`
- New environment variable: `SOURCE_SQUAD_ID` (available during delegated execution)
- New audit log: `.squad/log/cross-squad-delegations.md`

---

## Example: End-to-End Delegation Flow

### Scenario: Brady Squad Requests Infrastructure Help

```
1. Brady Squad (Issue #197):
   - "We need help designing cross-squad orchestration"
   - Expertise needed: Kubernetes, distributed systems
   
2. Brady Squad lead routes to Platform Squad:
   $ squad delegate --to platform-squad \
     --issue 197 \
     --title "Cross-squad orchestration design" \
     --expertise kubernetes,distributed-systems \
     --allow read,comment,create-draft-pr
   
   → Creates delegation request, signs it, sends to Platform Squad
   
3. Platform Squad receives request:
   - Verifies Brady Squad's signature ✓
   - Checks if B'Elanna has bandwidth
   - Accepts and responds with tracking URL
   
4. B'Elanna starts execution:
   - Context loader fetches Brady Squad's team.md and decisions.md
   - B'Elanna loads Brady Squad decisions into local context
   - B'Elanna writes design doc in Platform Squad's repo
   - B'Elanna creates draft PR against Brady Squad's issue
   
5. Status tracking:
   - Brady Squad polls: /squad-status/req-f47ac10b-...
   - Response: "In progress (60%), writing implementation plan section"
   
6. Completion:
   - B'Elanna finishes, merges draft PR
   - Delegation response sent: "Completed"
   - Brady Squad reviews, merges, closes issue
```

---

## Open Questions for Team Discussion

1. **Central Registry:** Should we implement now, or keep manual `.squad/registry.json` for Phase 1?
2. **Trust Model:** Is HMAC-SHA256 signing sufficient, or do we need mTLS?
3. **Authority Chaining:** Can Squad A delegate to Squad B, who then delegates to Squad C? (Recommend: No, for now)
4. **Capacity Management:** Should delegating squad check executing squad's capacity before requesting?
5. **Escalation:** What happens if executing squad declines due to capacity or complexity?

---

## Related Work & References

- **Issue #197** (this work)
- **Current upstream.json pattern** (`.squad/upstream.json`)
- **Subsquad pattern** (squad.config.ts)
- **Routing guidance** (`.squad/routing.md`)
- **Team decisions** (`.squad/decisions.md`)

---

## Next Steps

1. **Team review:** Present this design to squad leads (Picard, B'Elanna, Worf, Data)
2. **Feedback incorporation:** Address trust model and registry questions
3. **Phase 1 implementation kickoff:** Create CLI `squad delegate` command
4. **Integration testing:** Run Brady Squad → Platform Squad delegation pilot
5. **Documentation:** Write operational guide for cross-squad delegation

---

**Design Author:** Seven (Research & Docs)  
**Date:** 2026-03-09  
**Status:** Ready for team review and feedback
