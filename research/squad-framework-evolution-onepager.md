# Squad Framework Evolution — One-Pager

**Issue:** #419  
**Date:** 2026-07-23  
**Status:** Ready for executive review & podcast conversion

---

## Executive Summary

The Squad framework is a sophisticated, SDK-first multi-agent runtime for AI-powered team coordination. Our research reveals a mature foundation (bradygaster/squad v0.8.25) with **three major blind spots** where new GitHub Copilot platform capabilities can add transformative value:

1. **Cross-repository team coordination** — Real organizations split work across multiple repos (frontend/backend, research/production, libraries/consumers). Squad has no pattern for this.
2. **Research and non-code workflows** — Today's Squad ecosystem focuses purely on software development. We discovered a generalizable lifecycle pattern for research, evaluations, and exploration work.
3. **Bridging team memory to Copilot sessions** — Squad maintains sophisticated decision logs and agent history in markdown, but each new Copilot session starts without this context.

**Bottom line:** We have identified 10 high-impact, feasible contributions that will unlock Squad for a broader class of teams and make Copilot-powered agent coordination truly multi-dimensional. We recommend starting with 4 low-friction template PRs (Phase 1), then pursuing 3 SDK enhancements (Phase 2), with 3 longer-term platform integrations (Phase 3).

---

## Key Findings

### What Squad Does Well

- **Type-safe configuration** — The builder-pattern SDK (defineTeam, defineAgent, defineRouting, defineCasting) enforces correctness at compile time
- **21-agent runtime architecture** — Sophisticated division of labor: specialized agents for architecture, TypeScript, security, testing, CLI, docs, memory, DevRel, and release
- **Memory-first design** — A multi-tier system (decisions.md, agent history, session logs, decision inbox) that enables agents to learn and build institutional knowledge
- **Zero runtime dependencies** — Clean architecture; everything runs on Node.js built-ins
- **Governance through charters** — Each agent has a written charter defining identity, ownership, responsibilities, and boundaries

### Three Critical Gaps

| Gap | What's Missing | Impact | Feasibility |
|-----|-----------------|--------|-------------|
| **Cross-repo coordination** | No pattern for squads in different repositories to share work | Teams with frontend/backend or research/production splits can't use Squad | Medium — requires new builder function + label conventions |
| **Research/non-code workflows** | Only supports dev-team patterns; no lifecycle for exploration, evaluation, failed experiments | Research teams, DevRel, architecture review, vendor evaluation teams can't adopt Squad | High — template-based; our innovation is proven |
| **Copilot session context loss** | Decisions and history stored in markdown; every new Copilot session starts blank | Squads can't leverage accumulated knowledge across sessions | Medium — adapter to bridge store_memory / session store |

### Generalizable Innovations from Our Research Squad

- **Cross-repo communication protocol** — Our Ralph-R agent bridges tamresearch1 (production) and tamresearch1-research (research repo) via mirror issues and label-based routing
- **Research lifecycle** — Backlog → Active → {Completed | Failed} → Presentation → {Adopt | Archive}
- **Extended ceremonies** — Scheduled ceremonies (Symposium, Backlog Review) alongside reactive ones (Design Review, Retrospective)
- **Ralph-Watch observability** — Production-grade monitoring with structured logging, heartbeat files, single-instance guards, and alerting hooks
- **Human team member modeling** — Roster includes not just agents but humans with interaction preferences and escalation channels

---

## Gap Analysis Summary

Our detailed comparison revealed **8 major architectural areas** where research squad innovates beyond upstream:

1. **Team Definition** — We model human stakeholders; upstream does not
2. **Routing** — We support cross-repo patterns; upstream is code-module-centric
3. **Ceremonies** — We have scheduled ceremonies; upstream only failure-reactive ones
4. **Work Lifecycle** — We support research workflows; upstream has no abstraction
5. **Cross-Repo Communication** — We have a working protocol; upstream has no pattern
6. **Work Monitor (Ralph)** — We have observability; upstream has basic triage
7. **Decisions Framework** — Both mature, but we added async decision inbox pattern
8. **Skills System** — Upstream has 11 skills; ours is charter-based (smaller but sufficient for research)

**What's Not Generalizable:** DK8S-specific routing rules, Microsoft Teams integration, PowerShell-only monitoring, internal repo structure.

---

## Migration Path: Upgrading Your Squad

### For Existing squads Using `squad.config.ts`

**Step 1: Read the Release Notes**
```bash
# Check current version
npm list @bradygaster/squad-sdk

# Read what changed in the new version
squad changelog --version <target-version>
```

**Step 2: Review Breaking Changes**
New versions may change the builder API. Breaking changes will be documented in `docs/breaking-changes/`.

Common breaking changes (from v0.8.24 → v0.8.25):
- Constructor parameter renames (if any)
- Removed or renamed `define*()` functions
- CLI command changes

**Step 3: Run Migration Check**
```bash
npm run squad:check
# or via CLI
squad migrate --dry-run
```

This validates your `squad.config.ts` against the target SDK version and reports incompatibilities.

**Step 4: Update squad.config.ts**

If you're adopting new Phase 1 features (templates), the impact is minimal:

```typescript
// BEFORE: No research workflow support
export default defineSquad({
  team: defineTeam({ /* dev team */ }),
  routing: defineRouting([ /* code routing */ ]),
});

// AFTER: With research templates
import { defineLifecycle } from '@bradygaster/squad-sdk';

export default defineSquad({
  team: defineTeam({ /* dev team + research members */ }),
  routing: defineRouting([ /* code routing + cross-repo */ ]),
  // NEW: If adopting research-squad template
  lifecycle: defineLifecycle({
    name: 'research',
    states: ['backlog', 'active', 'completed', 'failed', 'presented', 'adopted'],
    transitions: [ /* state machine */ ],
  }),
});
```

**Step 5: Update .squad/decisions.md (Optional)**

If adopting the async decision inbox pattern:

```markdown
# Decisions

## Foundational Directives
- [existing directives]

## Sprint Directives
- [existing directives]

## Decision Process
New decisions are submitted to `.squad/decisions/inbox/{agent-name}.md` and merged by Scribe.
```

**Step 6: Add or Update Agent Charters**

If adopting human team member support, update your roster:

```markdown
## Team

### Agents
| Agent | Role | Domain |
|-------|------|--------|
| flight | Lead | Architecture |

### Human Members
| Name | Role | Interaction Channel | Notes |
|------|------|---------------------|-------|
| Tamir | Product Owner | GitHub Issues, Teams | Final decisions on architecture |
| Sarah | Stakeholder | Weekly sync | Collects requirements |
```

**Step 7: Commit and Test**

```bash
git add squad.config.ts .squad/decisions.md .squad/team.md
git commit -m "chore: upgrade squad framework to v0.X.Y"
squad --version
```

### Phase 1 Features (Low Friction)

If you're adopting Phase 1 features (Templates, Documentation, Human Roster):
- ✅ No CLI changes
- ✅ No runtime dependency updates
- ✅ Backward compatible — existing squads work unchanged
- ⚠️ New agents/teams won't use new features unless explicitly added

### Phase 2 Features (Medium Friction)

If SDK builders are added (defineLifecycle, defineSquadLink, extended ceremonies):
- ⚠️ May require `npm update`
- ⚠️ May require new imports in squad.config.ts
- ⚠️ New routing/linking configuration needed if cross-repo
- ✅ Existing squads continue to work (new features are opt-in)

### Phase 3 Features (Higher Friction)

If Copilot Memory integration or MCP server is added:
- ⚠️ New optional packages: `@bradygaster/squad-memory` or `@bradygaster/squad-mcp`
- ⚠️ New environment variables for Copilot API integration
- ✅ No changes to squad.config.ts required unless you opt into memory features

### Breaking Changes to Watch

Based on Squad's versioning practice:

1. **Builder function renames** — If `defineRouting()` changes signature
2. **Agent charter template changes** — If new mandatory sections are added
3. **Decision merge strategy** — If the `merge=union` strategy is revised
4. **CLI command changes** — If `squad migrate`, `squad spaces`, etc. are removed or renamed

**How to stay safe:** Always read the changelog. Open an issue in the Squad repo before upgrading if you have heavily customized charters or routing.

---

## Contribution Roadmap: 10 PRs in 3 Phases

### Phase 1: Templates & Documentation (4 PRs — Low Risk)

**Timeline:** 1–2 weeks | **Effort:** 6 days | **Impact:** Unblock research, DevRel, architecture teams

| # | Title | Files | Status |
|----|-------|-------|--------|
| 1 | Research Squad Template | 5 new markdown files | Ready to propose |
| 2 | Extended Ceremony Templates | 3 new templates (Symposium, Backlog Review, Failure Analysis) | Ready to propose |
| 3 | Human Team Member Section | 1 update to roster.md template | Ready to propose |
| 4 | Research Lifecycle Documentation | 1 new docs/workflows/research-lifecycle.md | Ready to propose |

**Why now:** These have zero SDK dependencies, zero breaking changes, and represent our core innovation. Immediate value for non-dev teams.

### Phase 2: SDK Enhancements (3 PRs — Medium Friction)

**Timeline:** 4–6 weeks | **Effort:** 10 days | **Impact:** Enable cross-repo work, custom workflows, extended ceremonies

| # | Title | Changes | Prerequisite |
|----|-------|---------|--------------|
| 5 | `defineLifecycle` Builder | New function in squad-sdk | Design proposal first (docs/proposals/) |
| 6 | Cross-Repo Squad Links | New function + routing extensions | Design proposal + Phase 1 acceptance |
| 7 | Extended Ceremony Schema | New ceremony builder or extended existing | Phase 1 ceremonies template |

**Why Phase 2:** Requires upstream maintainer alignment on API design. Propose Phase 1 first to build credibility and get feedback.

### Phase 3: Copilot Platform Integration (3 PRs — Higher Friction)

**Timeline:** 8–12 weeks | **Effort:** 12 days | **Impact:** Bridge team memory across sessions, expose squad state to other AI tools

| # | Title | Scope | Coordination |
|----|-------|-------|--------------|
| 8 | Ralph-Watch Observability | Node.js port of monitoring template | Cross-platform strategy alignment |
| 9 | Squad MCP Server | New `@bradygaster/squad-mcp` package | MCP spec alignment |
| 10 | Copilot Memory Integration Guide | Documentation + adapter patterns | Copilot API team review |

**Why Phase 3:** These are newer capabilities in the Copilot platform. Longer iteration cycle expected.

---

## Recommendations

### For Immediate Action (Next 2 Weeks)

1. **Propose Phase 1 PRs to bradygaster/squad**
   - Fork the repo, branch `research-squad-template`
   - Start with PR #1 (Research Squad Template) — it's the lowest risk and demonstrates our value
   - Use the PR description to reference this research

2. **Socialize the Gap Analysis**
   - Share the gap analysis findings with the upstream maintainer (Brady Gaster)
   - Gauge interest in cross-repo coordination and research workflows
   - Get alignment on API design before Phase 2 SDKwork

3. **Prepare Phase 2 Design Proposals**
   - Write `docs/proposals/lifecycle-builder.md` for upstream PR #5
   - Write `docs/proposals/cross-repo-squad-links.md` for upstream PR #6
   - Get feedback before implementation

### For Medium-Term (Next 6–8 Weeks)

4. **Ship Phase 1 + Phase 2 PRs**
   - Iterate on Phase 1 with upstream feedback
   - Submit Phase 2 PRs in order of priority (cross-repo, then lifecycle, then ceremonies)

5. **Evangelize to Broader Squad Community**
   - Publish a blog post: "Why Research Teams Need the Squad Framework"
   - Record a podcast from this one-pager
   - Show before/after examples of research squads

### For Long-Term (Months 3+)

6. **Pursue Phase 3 Integrations**
   - Start with MCP server (`squad-mcp`) — highest impact for cross-tool federation
   - Add Copilot Memory adapter once Phase 1 is merged (provides reference)

7. **Build Ecosystem**
   - Once cross-repo links ship, contribute a "squad federation" guide
   - Contribute research-specific skills: `research-methodology`, `cross-repo-triage`, `failed-experiment-documentation`

### Success Metrics

- ✅ Phase 1 PRs merged within 6 weeks
- ✅ At least 2 teams outside our organization adopt research-squad template
- ✅ Phase 2 PRs proposed within 12 weeks (may take longer to merge)
- ✅ MCP server (Phase 3 #9) begins development within 4 months

---

## Why This Matters

The Squad framework is poised to become the industry standard for AI-powered team coordination. By contributing these patterns — especially cross-repo coordination and research workflows — we shape the future of multi-agent systems in real organizations.

**Our research squad is not just a proof-of-concept.** It's a laboratory for generalizable patterns that benefit *all* squads. These 10 PRs represent that translation from innovation to ecosystem value.

---

## Questions?

- **Technical:** Review the full research report (`squad-framework-evolution-full.md`)
- **Gap analysis details:** See `squad-framework-gap-analysis.md`
- **PR details:** See `squad-framework-contribution-plan.md`
