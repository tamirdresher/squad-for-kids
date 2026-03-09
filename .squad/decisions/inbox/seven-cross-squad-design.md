# Cross-Squad Orchestration Design — Seven's Recommendations

**Date:** 2026-03-09  
**Author:** Seven (Research & Docs)  
**Status:** Ready for Team Review  
**Related:** Issue #197, PR #223

---

## Recommendation Summary

The design document proposes a **delegation protocol** enabling squads to discover, request help from, and collaborate with peer squads across repository boundaries. Key features:

- **Squad Registry** (`.squad/registry.json`): Manual peer discovery with capability tags and trust levels
- **Delegation Protocol**: Signed request/response for task handoff across squads
- **Context Injection**: Executing squad loads source squad's decisions and team context
- **Authorization Boundaries**: Four-level permission model (`read`, `comment`, `create-draft-pr`, `write-to-sandbox`)
- **Async Job Tracking**: Progress polling and integration branch management

---

## Key Decisions Proposed

### 1. Backward Compatibility (CRITICAL)

**Decision:** New cross-squad patterns must not break existing `upstream.json`, `subsquad`, or routing mechanisms.

**Rationale:**
- Squad has invested heavily in these patterns
- Existing work depends on them
- Introducing breaking changes risks disrupting ongoing projects

**Implications:**
- Cross-squad orchestration layers on top as `.squad/registry.json`
- No changes to existing squad.config.ts, routing.md, or upstream patterns
- Safe to implement incrementally; existing code unaffected

**Status:** ✅ Adopted in design document

---

### 2. Trust via Signatures (HMAC-SHA256)

**Decision:** Cross-squad requests and responses are authenticated using HMAC-SHA256 signatures with squad-specific keys.

**Rationale:**
- Simple to implement and verify
- Proven industry pattern (JWT, API signing)
- Does not require infrastructure dependencies (no mTLS cert management, no central PKI)
- Public keys stored in registry for verification

**Alternatives Considered:**
- ❌ mTLS: Overkill for squad-to-squad communication; requires cert infrastructure
- ❌ OAuth 2.0: Too heavy for internal tool; squad service principals already have shared keys
- ✅ HMAC-SHA256: Right complexity/security tradeoff

**Implications:**
- Each squad generates a public/private key pair during setup
- Private key stored securely (env var or .squad/secrets/)
- Public key stored in registry (safe to distribute)
- Signature verification happens before processing request

**Status:** ✅ Adopted in design document

---

### 3. Authority Chaining — NOT Enabled in Phase 1

**Decision:** Do NOT allow Squad A to delegate to Squad B, who then delegates to Squad C (authority chaining).

**Rationale:**
- Increases audit complexity (chain of custody becomes unclear)
- Risk of authority escape (Squad B could redelegate with broader permissions than it was given)
- Simpler to enforce two-level model: source squad → executing squad
- Can be added in future if needed

**Implications:**
- Delegation protocol includes flag: `allowRedelegation: false` (default, enforced)
- If Squad B receives delegated task from Squad A and needs Squad C's help, Squad B must negotiate directly with Squad C
- Audit trail is always two-level

**Status:** ✅ Adopted in design document

---

### 4. Phase 1 Focus: Manual Registry + CLI Delegation

**Decision:** Implement Phase 1 (discovery + delegation protocol) immediately. Defer Phase 5 (central registry) to future.

**Rationale:**
- Manual registry (`.squad/registry.json` per squad) is low-friction, no infrastructure
- Enables team to validate delegation protocol design with real use cases
- Central registry is infrastructure work; can wait until Phase 1 proves value
- Risk of over-engineering: Build centralized system before validating simpler pattern

**Implications:**
- Each squad maintains its own `registry.json`
- Squad discovery is manual (Tamir adds peer URLs to registry)
- CLI command: `squad delegate --to platform-squad --issue 197`
- Phase 5 can add central registry later without changing Phase 1 implementation

**Status:** ✅ Adopted in design document, recommended for Picard approval

---

### 5. Execution Context Injection via Environment

**Decision:** Executing squad agent loads source squad's context (decisions, team) via environment variables and local decision cache.

**Rationale:**
- Simpler than modifying agent code per delegation
- Follows squad's existing pattern: agents read environment to understand context
- Non-intrusive: Agents execute unchanged; context is injected externally
- Audit trail captures which context was loaded

**Implications:**
- Context loader runs before agent execution (Phase 2)
- New environment variables: `SOURCE_SQUAD_ID`, `SOURCE_SQUAD_CONTACT`, `DELEGATION_REQUEST_ID`
- Decisions merged into `.squad/cache/merged-decisions.md` at execution time
- Audit log shows which decisions were loaded for each execution

**Status:** ✅ Adopted in design document

---

### 6. Authorization Enforcement via Middleware

**Decision:** Authorization boundaries are enforced by middleware that checks actions before execution.

**Rationale:**
- Prevents accidental violations (e.g., agent creates PR when not authorized)
- Centralized enforcement (one place to audit, one place to update policy)
- Clear audit trail (each action decision logged)
- Agents don't need to know about authorization; framework handles it

**Implications:**
- New module: `.squad/agents/_lib/authorization.ts`
- On every action (PR creation, comment, commit), check authorization
- Deny if not authorized, log with reason and delegation request ID
- Alerts to source squad if unauthorized action detected

**Status:** ✅ Adopted in design document

---

## Team Decisions Needed

The following questions require team (Picard, B'Elanna, Worf, Data) discussion before Phase 1 implementation:

1. **Manual vs. Central Registry** — Is `.squad/registry.json` sufficient for MVP, or should we plan central registry now?
2. **Trust Verification** — How do we verify a squad's public key when first adding to registry? (e.g., GitHub verification)
3. **Capacity Signals** — Should delegating squad check executing squad's capacity before requesting? (Can wait for Phase 4)
4. **Escalation Path** — If executing squad declines due to complexity/capacity, what happens? (E.g., can we route to 3rd squad?)

---

## Artifacts

- **Design Document:** `docs/cross-squad-orchestration-design.md`
- **Branch:** `squad/197-cross-squad-orchestration`
- **PR:** #223 (ready for team review)

---

## Next Steps

1. ✅ **Team review:** Present to Picard, B'Elanna, Worf, Data on next ceremony
2. ⏳ **Feedback incorporation:** Adjust design based on team decisions
3. ⏳ **Phase 1 kickoff:** Create CLI `squad delegate` command
4. ⏳ **Integration testing:** Brady Squad → Platform Squad pilot
5. ⏳ **Operational guide:** Write runbook for cross-squad delegation

---

**Prepared by:** Seven (Research & Docs)  
**Date:** 2026-03-09  
**Status:** Awaiting team review
