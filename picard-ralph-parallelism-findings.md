## Research Findings: Ralph Parallelism Architecture

I analyzed four approaches to solve the work starvation problem where heavy tasks (5+ min) block fast operations (board updates, labels, comments).

### Current Architecture Context

Ralph operates in two modes:
1. **ralph-watch.ps1** — Detached PowerShell process that spawns Squad coordinator via `agency copilot` every 5 minutes
2. **In-session Ralph** — User-activated loop ("Ralph, go") that continuously processes work until board is clear

The bottleneck: Both modes use the **Squad coordinator** which spawns agents **serially per work category** (untriaged → assigned → CI failures → review feedback → approved PRs). If one category has a heavy task, everything else waits.

---

### Approach 1: Priority Queues

**Concept:** Categorize work as `fast` (board ops, labels, comments, triage) vs `slow` (code changes, research, blog writing). Fast items always preempt slow work.

**Implementation:**
- Modify Squad coordinator's Step 2 (Categorize findings) to add priority tier
- Split Step 3 into two passes: process all `fast` items first, then `slow`
- Fast agents spawn with `mode: "background"`, slow agents spawn after fast batch completes

**Mapping to existing architecture:**
- **Squad.agent.md lines 996-1006:** Add `priority` field to category table
- **Ralph.charter.md:** No changes needed — priority logic lives in coordinator
- Changes are **centralized** in Squad coordinator's work-check cycle

**Complexity:** ⭐⭐ (Low-Medium)
- One-time change to categorization logic
- Existing background mode handles the execution model
- No new infrastructure, no process management

**User Experience:**
- ✅ Fast items (triage, board moves, label changes) complete in <30s
- ✅ Transparent — user sees fast work finish before slow work starts
- ⚠️ Slow work still blocks other slow work (blog rewrite blocks research report)

**Tradeoffs:**
- ✅ Minimal code change, no new failure modes
- ✅ Preserves existing serial model within priority tiers
- ❌ Doesn't solve slow-vs-slow contention
- ❌ Coarse-grained (only 2 tiers: fast/slow)

---

### Approach 2: Parallel Work Pools

**Concept:** Use `mode: "background"` more aggressively. Spawn ALL agents across ALL categories simultaneously in one tool-calling turn, then collect results. Heavy tasks run in parallel, not serially.

**Implementation:**
- Modify Squad coordinator Step 3: instead of "process one category at a time," spawn agents for ALL work items in a **single** `task` tool call batch
- Squad.agent.md already supports this: "Multiple `task` calls in one response enables true parallelism" (line 526)
- Use `read_agent` with `wait: true, timeout: 300` to collect all results after spawn

**Mapping to existing architecture:**
- **Squad.agent.md lines 520-540:** Already documents parallel fan-out pattern — this extends it to Ralph's work-check cycle
- **No changes to Ralph.charter.md** — Ralph just triggers the cycle, coordinator handles execution
- Changes are **minimal** — reorder existing spawn calls into one batch

**Complexity:** ⭐ (Low)
- Leverage existing `mode: "background"` + `read_agent` infrastructure
- No new code paths, no new failure modes
- Already proven in multi-agent spawn scenarios (lines 536-543)

**User Experience:**
- ✅ All work starts simultaneously — no category waits for another
- ✅ Fast work finishes fast (30s), heavy work finishes in 5+ min, but runs concurrently
- ✅ User sees progress on multiple fronts: "🔧 Data fixing #169, 🏗️ B'Elanna on #167, 📋 Scribe triaging #42"
- ⚠️ Higher cognitive load — multiple agents working at once

**Tradeoffs:**
- ✅ True parallelism — solves slow-vs-slow and slow-vs-fast
- ✅ Minimal implementation risk (reuses proven patterns)
- ✅ Scales with work volume (10 issues = 10 parallel agents)
- ❌ Higher resource usage (multiple LLM calls in flight)
- ❌ Harder to debug failures (which agent failed? need better observability)

---

### Approach 3: Time-Boxing

**Concept:** Set max execution time per task category. If exceeded, agent checkpoints state and continues in next round. Prevents one heavy task from monopolizing the round.

**Implementation:**
- Add `timeout` parameter to `task` tool calls (e.g., 60s for fast, 300s for slow)
- If timeout triggers, agent writes checkpoint to `.squad/agents/{name}/checkpoint.md`
- Next round, agent resumes from checkpoint

**Mapping to existing architecture:**
- **task tool:** Already supports `timeout` on `read_agent` but NOT on spawn
- Would need NEW checkpointing protocol — agents don't currently support suspend/resume
- **Major change** to agent spawn flow + Scribe logging

**Complexity:** ⭐⭐⭐⭐ (High)
- New checkpoint protocol across all agents
- Risk: agent leaves work half-done, inconsistent state
- Requires changes to: Squad.agent.md, all agent charters, Scribe log format

**User Experience:**
- ✅ Guarantees fast work completes within timeout window
- ❌ Heavy work gets interrupted repeatedly — frustrating UX
- ❌ "Chunky" progress — blog rewrite takes 5 rounds instead of 1
- ❌ Hard to explain to user: "Data was interrupted after 5 minutes, resuming next round"

**Tradeoffs:**
- ❌ High complexity, introduces new failure modes
- ❌ Agent suspend/resume is fragile (partial file edits, lost context)
- ❌ Poor UX for heavy tasks — feels like thrashing
- ✅ Guarantees no single task blocks indefinitely
- ⚠️ Not recommended — complexity outweighs benefits

---

### Approach 4: Dedicated Lanes

**Concept:** Split Ralph's work-check cycle into parallel lanes: "fast lane" (board/labels/triage) runs inline/sync, "deep lane" (code changes, research) spawns as background work that persists across rounds.

**Implementation:**
- Modify Ralph Step 3: 
  - **Fast lane:** Spawn agents with `mode: "sync"`, wait for completion before next scan
  - **Deep lane:** Spawn agents with `mode: "background"`, DON'T wait — let them run across rounds
- Track deep-lane agents in `.squad/ralph-deep-lane.json` (pid, issue, status)
- Each round: check deep-lane status, spawn new fast-lane work if available

**Mapping to existing architecture:**
- **Squad.agent.md lines 500-518:** Already documents sync vs background mode selection
- **New file:** `.squad/ralph-deep-lane.json` to track long-running agents
- **Ralph.charter.md:** Document the two-lane model

**Complexity:** ⭐⭐⭐ (Medium-High)
- New state tracking file (deep-lane.json)
- Risk: deep-lane agents complete between rounds, need status polling
- Need to handle deep-lane failures gracefully (agent crashes, user interrupts)

**User Experience:**
- ✅ Fast work ALWAYS responsive (sync mode guarantees <30s)
- ✅ Heavy work runs "in the background" without blocking
- ✅ Intuitive mental model: "fast lane for quick stuff, deep lane for heavy lifting"
- ⚠️ User needs to understand two-lane model ("Data is still working on #169 in the deep lane")

**Tradeoffs:**
- ✅ Clean separation of concerns
- ✅ Fast work never starves
- ✅ Scales with work mix (1 heavy + 10 fast = all 10 fast complete immediately)
- ❌ More complex state management (deep-lane tracking)
- ❌ Requires documentation updates (Ralph.charter.md, Squad.agent.md)
- ⚠️ Medium risk — introduces new state file and failure modes

---

### Recommendation

**Implement Approach 2 (Parallel Work Pools) first**, then consider Approach 1 as refinement if needed.

**Why Approach 2:**
1. **Lowest implementation cost** — leverages existing `mode: "background"` infrastructure (already proven in Squad.agent.md lines 520-540)
2. **Solves the root problem** — all work runs in parallel, no category blocks another
3. **No new failure modes** — reuses existing spawn + collect pattern
4. **Best UX** — user sees all work start immediately, progress updates on multiple fronts

**Migration path:**
- **Phase 1:** Modify Squad coordinator Step 3 to spawn all agents in one batch (1-day change)
- **Phase 2 (optional):** Add Approach 1 priority tiers if we need finer control (fast work prioritized within the parallel batch)

**Why NOT Approaches 3 or 4:**
- **Approach 3 (Time-boxing):** Too complex, fragile checkpoint protocol, poor UX for heavy tasks
- **Approach 4 (Dedicated lanes):** More state management, higher risk, harder to debug

**Implementation sketch (Approach 2):**

```typescript
// Current: Squad.agent.md Step 3 (lines 1008-1012)
// Process ONE category, spawn agents, collect, repeat

// Proposed: Spawn ALL categories in one batch
async function ralphWorkCheck() {
  const work = await scanAllCategories(); // Step 1
  
  // Group all work items across categories
  const allAgentSpawns = [
    ...work.untriaged.map(issue => spawnLeadTriage(issue)),
    ...work.assigned.map(issue => spawnMemberAgent(issue)),
    ...work.ciFailures.map(pr => spawnFixAgent(pr)),
    // ... all categories
  ];
  
  // Spawn ALL agents in one batch (mode: "background")
  const agentIds = await Promise.all(allAgentSpawns);
  
  // Collect all results (wait: true, timeout: 300)
  const results = await Promise.all(
    agentIds.map(id => readAgent(id, { wait: true, timeout: 300 }))
  );
  
  // Present compact results, spawn Scribe
  // ... existing post-work flow
}
```

**File changes:**
- `.github/agents/squad.agent.md` lines 1008-1012 (Step 3 logic)
- Test with 1 fast + 1 heavy task, verify parallel execution
- Document in `.squad/decisions/inbox/picard-ralph-parallelism.md`

**Risks:**
- Higher LLM resource usage (multiple parallel calls) — monitor token costs
- Need better observability to debug parallel failures — enhance Scribe logging

**Expected outcome:**
- Fast tasks (triage, labels, comments) complete in <1 minute
- Heavy tasks (code changes, research) run in parallel without blocking fast work
- Ralph rounds complete faster overall (10 items = 1 parallel batch vs 10 serial batches)
