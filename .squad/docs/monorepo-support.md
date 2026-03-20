# Monorepo Support Guide

> **Full reference for per-area Squad configuration in large repositories.**
> If you are setting up Squad for the first time, start with [Quick Start](#quick-start).
> Cross-references: `scripts/find-squad-config.ps1` (issue #1146) · `.squad/mcp-servers.md`

---

## Quick Start

If your repo is a monorepo with multiple teams or product areas, Squad can be configured to respect area boundaries:

1. **Lightweight:** Drop a `.squad-context.md` file into any subdirectory to give Squad context about that area.
2. **Formal:** Create a `.squads/` directory beside your area code for a full subsquad config (roster, routing,
   decisions log).
3. **Automated:** Add `area:*` labels to issues and PRs so the routing engine dispatches to the right area agents.

You don't need all three layers. Start with Layer 1. Add layers as your team grows.

---

## The Three Layers

### Layer 1: `.squad-context.md` — Lightweight per-area context (start here)

A single Markdown file that tells agents *who owns this area*, *what it does*, and *how to route work here*.
It requires zero tooling and zero setup beyond creating the file.

**When to use Layer 1 only:**
- Your repo has 2–5 areas with low cross-area churn
- You want squad awareness without managing a subsquad roster
- You are piloting monorepo support before committing to a full setup

### Layer 2: Per-area `.squads/` directory — Full subsquad config

A directory placed alongside your area code containing a complete squad config scoped to that area.
Inherits all root `.squad/` rules; area files override on conflicts (except security gates — see
[Merge Rules](#inheritance--merge-rules)).

**When to use Layer 2:**
- Your area has its own dedicated roster of agents
- You need area-specific routing rules (e.g., all `area:api` PRs require a Data review)
- You maintain area-scoped decisions that should not pollute the root log

### Layer 3: Directory-aware dispatch — Labels and automation

GitHub `area:*` labels on issues and PRs, combined with the routing engine, ensure work reaches the right
area agents automatically without any human triage step.

**When to use Layer 3:**
- You have CI or event-driven workflows that auto-label PRs by changed paths
- You want to enforce area ownership (e.g., `area:platform:security` always involves Worf)
- Multiple teams contribute simultaneously and need independent queues

---

## Schema Reference

### `.squad-context.md` format

Place this file in any subdirectory. Agents walking the directory tree will find and respect it.

```markdown
# Squad Context — <Area Name>

## Owner
- **Primary agent:** <AgentName> (e.g., B'Elanna)
- **Backup agent:** <AgentName>
- **Human DRI:** <GitHub username or team>

## Purpose
One paragraph describing what this area does and why it exists.

## Key Files
- `<path>` — <what it does>
- `<path>` — <what it does>

## Routing Hints
- PRs touching `<pattern>` should involve <AgentName>
- Breaking changes require Picard review
- Security-sensitive paths: <list if any>

## Area Label
`area:<slug>` — used on issues and PRs to trigger area routing

## Notes
Any freeform context that doesn't fit above.
```

**Required fields:** `Owner.Primary agent`, `Purpose`, `Area Label`
**Optional fields:** Everything else

---

### Area `team.md` format

Placed at `<area>/.squads/team.md`. Declares which root agents are active in this area and whether any
area-specific agent overrides apply.

```markdown
# <Area Name> — Team

> Inherits all agents from root `.squad/agents/`. This file declares area-level overrides only.

## Active in This Area

| Agent | Role in Area | Override? |
|-------|-------------|-----------|
| Data | Primary code reviewer | No |
| B'Elanna | Infrastructure changes | No |
| Worf | Security gate (mandatory) | No |
| Seven | Area documentation | No |

## Area-Specific Overrides

<!-- Only needed if an agent behaves differently in this area. -->
<!-- Example: a specialized routing rule or a different primary agent. -->

## Agents NOT Active Here

| Agent | Reason |
|-------|--------|
| Podcaster | No audio content in this area |
| Troi | No blog content in this area |

## Notes
Any context about team structure, contacts, or on-call rotation for this area.
```

---

### Area `routing.md` format

Placed at `<area>/.squads/routing.md`. Defines routing rules that *add to* root routing (never replace).

```markdown
# <Area Name> — Routing

> These rules apply **in addition to** root `.squad/routing.md`.
> HQ security gates (Worf, Crusher) cannot be overridden here.

## Area Label

`area:<slug>`

## Routing Table

| Work Type | Route To | Notes |
|-----------|----------|-------|
| All code changes | Data | Primary reviewer |
| Infrastructure changes | B'Elanna | Required for k8s changes |
| Breaking API changes | Data + Picard | Both must sign off |
| Security changes | Worf | Mandatory, cannot be skipped |

## Auto-Label Rules

Paths that trigger this area label automatically:
- `src/<area>/**`
- `tests/<area>/**`
- `docs/<area>/**`

## Cross-Area Rules

When a PR touches this area AND another area:
1. Apply all routing rules for both areas (union)
2. Picard arbitrates if agent assignments conflict
3. Both area routing.md files are evaluated; neither takes priority
```

---

## Config Discovery Algorithm

When an agent is given a file path, issue, or PR, it discovers which area config applies using this algorithm:

```
function find-squad-config(target_path):
    dir = directory_of(target_path)
    while dir is not repo_root:
        if exists(dir + "/.squads/"):
            return load_squads_config(dir + "/.squads/")    # Layer 2
        if exists(dir + "/.squad-context.md"):
            return load_context(dir + "/.squad-context.md") # Layer 1
        dir = parent(dir)
    return load_root_config(repo_root + "/.squad/")         # Root (always present)
```

**Key properties:**
- **Nearest-wins:** The config closest to the changed file takes precedence on conflicts.
- **Always inherits root:** Area configs layer on top of root; they never replace it.
- **Full subtree coverage:** A config at `src/platform/` covers `src/platform/auth/` too, unless a more
  specific config exists at `src/platform/auth/`.
- **Multi-path PRs:** If a PR touches paths covered by two different area configs, both are applied (union).
  See [Cross-Area Work](#cross-area-work).

### Using `find-squad-config.ps1`

```powershell
# Which area owns this file?
.\scripts\find-squad-config.ps1 -Path "src/platform/auth/handler.go" -ShowArea

# List all registered area configs in the repo
.\scripts\find-squad-config.ps1 -All

# Validate all area configs against schema
.\scripts\find-squad-config.ps1 -ValidateAll
```

> Script tracked in issue #1146.

---

## Inheritance & Merge Rules

### What area configs can do

| Rule type | Area can add | Area can override | Area can remove |
|-----------|-------------|-------------------|-----------------|
| Routing assignments | ✅ | ✅ (non-security) | ❌ |
| Agent roster (active/inactive) | ✅ | ✅ | ❌ (cannot deactivate HQ gates) |
| Decisions log scope | ✅ | N/A | N/A |
| Area label definition | ✅ | ✅ | ❌ |
| HQ security gates (Worf, Crusher) | — | ❌ | ❌ |
| Root status label taxonomy | — | ❌ | ❌ |

### Security gate invariant

**Worf (security) and Crusher (content safety) cannot be bypassed by any area config.**

Even if an area `.squads/routing.md` does not mention Worf, any change tagged `area:*:security` or any
publishable content will still invoke the HQ security gate. This is enforced at the routing engine level,
not by convention.

### Field-level merge semantics

When a field exists in both root config and area config:

| Field | Merge strategy |
|-------|----------------|
| Routing table rows | Union (area rows added to root rows) |
| Agent active list | Union (area can add agents; cannot remove root-required ones) |
| Area label | Area definition wins |
| Model assignments | Area can override per-agent model for work in this area |
| Decisions log | Separate log; area decisions do not appear in root log |

### Conflict resolution order

```
1. Area config (nearest to changed file)
2. Parent area config (if nested areas exist)
3. Root .squad/ config
4. HQ invariants (security gates — always win, regardless of order)
```

---

## Cross-Area Work

When a single issue or PR spans multiple areas:

1. **Auto-detect:** The routing engine applies all `area:*` labels matching the touched paths.
2. **Union routing:** All routing requirements from all touched areas are applied. If area A requires Data
   and area B requires B'Elanna, both are dispatched.
3. **Conflict arbitration:** If area A and area B have conflicting routing rules for the same agent slot,
   **Picard** arbitrates. A comment is left on the issue explaining the conflict and resolution.
4. **Decisions scoping:** Decisions made during cross-area work are written to the *root* decisions log
   (not any area log), tagged with all relevant area labels.
5. **Security gates always fire:** Even if only one of the two areas is security-sensitive, the security
   gate fires for the entire PR.

---

## Examples: Real Repo Structures

### Example 1 — Flat Repo (Single Team, No Areas)

```
my-repo/
├── src/
├── tests/
├── .squad/          ← All squad config lives here (root only)
│   ├── agents/
│   ├── decisions.md
│   └── routing.md
└── README.md
```

**No area config needed.** All agents work from root config. This is the default.

---

### Example 2 — Frontend / Backend Split

Two teams share a monorepo. Each has a lightweight `.squad-context.md`.

```
my-repo/
├── frontend/
│   ├── src/
│   ├── .squad-context.md   ← Layer 1: identifies frontend area, routes UI PRs to Troi/Seven
│   └── tests/
├── backend/
│   ├── src/
│   ├── .squad-context.md   ← Layer 1: identifies backend area, routes API PRs to Data
│   └── tests/
├── .squad/                 ← Root config (inherited by both areas)
│   ├── agents/
│   ├── routing.md
│   └── decisions.md
└── README.md
```

**`frontend/.squad-context.md`:**
```markdown
# Squad Context — Frontend

## Owner
- **Primary agent:** Seven
- **Backup agent:** Troi
- **Human DRI:** @frontend-team

## Purpose
React SPA — user interface layer. Talks to backend via REST API.

## Key Files
- `frontend/src/components/` — Shared UI components
- `frontend/src/pages/` — Page-level components

## Routing Hints
- CSS/design changes can involve Troi for voice/style review
- Accessibility changes involve Crusher (content safety gate)

## Area Label
`area:frontend`
```

**`backend/.squad-context.md`:**
```markdown
# Squad Context — Backend

## Owner
- **Primary agent:** Data
- **Backup agent:** B'Elanna
- **Human DRI:** @backend-team

## Purpose
Go REST API serving the frontend. Postgres database. JWT auth.

## Key Files
- `backend/src/api/` — HTTP handlers
- `backend/src/db/` — Database layer

## Routing Hints
- Auth changes are security-sensitive — tag `area:backend:security`
- Database migrations require B'Elanna review

## Area Label
`area:backend`
```

---

### Example 3 — Microservices (Full Layer 2 Config per Service)

Large platform with multiple services, each with its own subsquad config.

```
platform/
├── services/
│   ├── auth-service/
│   │   ├── src/
│   │   ├── .squad-context.md      ← Layer 1: quick context
│   │   ├── .squads/               ← Layer 2: full subsquad config
│   │   │   ├── team.md            ← Agent roster for auth area
│   │   │   ├── routing.md         ← Auth-specific routing rules
│   │   │   └── decisions/         ← Auth-scoped decision log
│   │   └── tests/
│   ├── payments-service/
│   │   ├── src/
│   │   ├── .squad-context.md
│   │   ├── .squads/
│   │   │   ├── team.md
│   │   │   ├── routing.md         ← Payments: ALL changes require Worf sign-off
│   │   │   └── decisions/
│   │   └── tests/
│   └── notification-service/
│       ├── src/
│       ├── .squad-context.md      ← Layer 1 only (simpler service)
│       └── tests/
├── shared/
│   ├── .squad-context.md          ← Shared libraries context
│   └── src/
└── .squad/                        ← Root config
    ├── agents/
    ├── routing.md
    └── decisions.md
```

**`services/auth-service/.squads/routing.md`:**
```markdown
# Auth Service — Routing

> All root routing rules apply. These are additive.

## Area Label
`area:auth`

## Routing Table
| Work Type | Route To | Notes |
|-----------|----------|-------|
| All changes | Worf | Security review mandatory |
| Token/session logic | Worf + Data | Both must approve |
| Test changes only | Data | Worf not required for tests-only PRs |

## Auto-Label Rules
Paths triggering `area:auth`:
- `services/auth-service/**`
```

---

## FAQ

### "Where do I put context for my team's area?"

**Short answer:** Create `.squad-context.md` in your area's root directory.

**Long answer:** The file can live at any level of the directory tree. If your area is `src/platform/`, put
it at `src/platform/.squad-context.md`. If you have sub-areas, you can add more `.squad-context.md` files
deeper in the tree — the nearest one wins. See [Config Discovery Algorithm](#config-discovery-algorithm).

---

### "Can I restrict which agents work in my area?"

**Partially.** You can:
- ✅ Declare an agent as "not active" in your area's `team.md` (prevents them from being auto-dispatched)
- ✅ Override agent routing preferences for your area
- ❌ Remove HQ security gates (Worf, Crusher) — these are mandatory and cannot be overridden

If you want to *add* an agent to your area roster that isn't in the root config, that's also supported via
`team.md`. See [Area `team.md` format](#area-teammd-format).

---

### "What happens when a PR touches two areas?"

Both area configs are applied simultaneously (union semantics). All routing requirements from both areas
are combined. If there's a conflict, Picard arbitrates and comments on the PR with the resolution.

For decisions made during cross-area work, they go to the **root** decisions log (tagged with both area
labels), not to either area's scoped log.

See [Cross-Area Work](#cross-area-work) for the full rules.

---

### "How do decisions get scoped to an area?"

Area-scoped decisions live in `<area>/.squads/decisions/`. The format is identical to root decisions, but
they only appear in the area's decision log — not in the root `.squad/decisions.md`.

**When to use area decisions vs root decisions:**

| Use area decisions for... | Use root decisions for... |
|--------------------------|--------------------------|
| API contract choices for one service | Cross-cutting architecture decisions |
| Auth implementation choices | Changes to squad routing rules |
| Area-specific tooling | Security policies |
| Local performance trade-offs | Agent roster changes |

Agents automatically write to the correct log based on which area config is active when the decision
is made.

---

## Appendix: File Checklist

When setting up Squad for a new area, use this checklist:

### Layer 1 (Minimal Setup)
- [ ] `.squad-context.md` created in area root
- [ ] `Owner.Primary agent` field filled in
- [ ] `Area Label` field defined (e.g., `area:payments`)
- [ ] `area:*` label created in GitHub with a description

### Layer 2 (Full Subsquad)
- [ ] `.squads/` directory created
- [ ] `.squads/team.md` — agent roster defined
- [ ] `.squads/routing.md` — area routing rules defined
- [ ] `.squads/decisions/` directory created (can be empty)
- [ ] Root `.squad/routing.md` updated with area label in the Area Label Schema table
- [ ] CI/CD path-based label rule added (optional but recommended)

### Layer 3 (Automation)
- [ ] GitHub Actions workflow auto-labels PRs by path
- [ ] Routing engine configured to read `area:*` labels (done at root level, no per-area setup needed)
- [ ] `scripts/find-squad-config.ps1` tested against area paths

---

*Maintained by: Seven (Research & Docs)*
*Last updated: 2026-Q2*
*Related: `scripts/find-squad-config.ps1` (#1146) · `.squad/mcp-servers.md` (#1151) · Design: #1012*
