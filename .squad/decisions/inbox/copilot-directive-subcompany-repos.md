### 2026-03-18T07-41-28Z: User directive — Sub-company repo isolation (SUPERSEDES Decision 23)
**By:** Tamir Dresher (via Copilot)
**What:** Each sub-company/division in the enterprise MUST operate in its own dedicated GitHub repo with its own Squad. The main tamresearch1 repo is the headquarters/coordinator that delegates to sub-company repos.

Known sub-companies (Tamir confirmed):
1. **Research Institute** — tamresearch1-research repo ✅ (already exists, has its own squad)
2. **TechAI Content** (content/marketing company) — NEEDS its own repo
3. **JellyBolt Games** (gaming company) — NEEDS its own repo  
4. **Investment/Venture company** — NEEDS its own repo (Tamir mentioned this)
5. **Kids Squad** — deferred but will need its own repo when activated
6. **Future sub-companies** — MUST follow same pattern: own repo, own squad

Rules:
- Main squad (tamresearch1) coordinates across all sub-companies but does NOT do their domain work
- Sub-company squads are autonomous — they have their own team.md, routing, decisions, Ralph
- Cross-company work uses GitHub issues tagged for the target company
- Picard (main squad Lead) can triage and route to sub-company squads but doesn't execute their work
- Content/marketing members (Guinan, Paris, Geordi, Crusher) should migrate to TechAI repo
- Each sub-company repo should have its own ralph-watch.ps1 running

**Why:** Enterprise scale — single repo can't handle all domains. Each company needs autonomy, its own knowledge, and its own execution pipeline.
