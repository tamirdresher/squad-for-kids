# Monorepo Support — Per-Area Squad Config Guide

> **Full reference for per-area Squad configuration in large repositories.**
> If you are setting up Squad for the first time, start with [Quick Start](#quick-start).
> Cross-references: `scripts/find-squad-config.ps1` (issue #1146) · `.squad/mcp-servers.md` · `area:*` labels setup: `.squad/scripts/setup-area-labels.ps1` (issue #1153)

---

## Why This Matters

In a standard single-team repo, everything lives at `.squad/` and all agents share one routing
table, one roster, and one decisions log. That works well up to ~10 engineers on a single product.

In a **monorepo** — `src/platform/`, `src/api/`, `src/frontend/`, etc. — the root `.squad/` becomes
a bottleneck:
- Routing rules mix platform-team concerns with API-team concerns
- Decisions from one area clutter another area's log
- Agents working in `src/api/` load irrelevant platform context on every spawn

Squad solves this with **three layers of per-area config**, each with different weight and scope:

| Layer | File | Effort | When to use |
|-------|------|--------|-------------|
| 1 | `<area>/.squad-context.md` | Minimal | Any subdirectory that wants context awareness |
| 2 | `<area>/.squads/` | Medium | Team-owned area needing its own roster + routing |
| 3 | Directory-aware dispatch | Framework | Automatic once Layers 1-2 are in place |

Layers are **additive** — you can adopt Layer 1 today without committing to Layer 2. The root
`.squad/` is always "HQ" and all area configs inherit from it.

---

## Layer 1: `.squad-context.md` — Lightweight Area Context

### What It Is

A single Markdown file placed inside a subdirectory that tells agents:

> **Reference implementation:** [`.squad/.squad-context.md`](./.squad-context.md) — the Squad framework
> area itself uses this pattern. Use it as a canonical example when creating `.squad-context.md` files for
> your own areas.

**When to use Layer 1 only:**
- Your repo has 2–5 areas with low cross-area churn
- You want squad awareness without managing a subsquad roster
- You are piloting monorepo support before committing to a full setup

It does **not** change the agent roster or routing rules — it only adds context that agents load
when working in this directory tree.

### Convention

Place a `.squad-context.md` at the **root of the area** you want to describe:

```
src/
  platform/
    .squad-context.md   ← describes platform area
    auth/
    infra/
  api/
    .squad-context.md   ← describes api area
    handlers/
    middleware/
```

When an agent is spawned for a task touching `src/platform/auth/handler.go`, Squad walks up the
directory tree from `src/platform/auth/` and loads the nearest `.squad-context.md` it finds —
which is `src/platform/.squad-context.md`.

### Format

```markdown
# Area: Platform

**Owner:** B'Elanna  
**Label:** `area:platform`  
**Primary path:** `src/platform/`

## What This Area Does

The platform layer handles infrastructure provisioning, cluster lifecycle, and the internal
service mesh. Changes here affect ALL other areas — treat with care.

## Key Files

| File | Purpose |
|------|---------|
| `src/platform/cluster/manager.go` | Core cluster lifecycle |
| `src/platform/infra/provisioner.go` | Resource provisioning entry point |
| `src/platform/auth/middleware.go` | Auth middleware shared by all services |

## Routing Hints

- **Security changes** (anything under `auth/`) → always involve Worf
- **Cluster changes** → B'Elanna is primary, Picard for architecture decisions
- **Breaking changes** → apply `area:platform:breaking` label and require Picard sign-off

## Constraints

- Never merge platform changes during peak hours (09:00-17:00 UTC on weekdays) without explicit approval
- All changes to `infra/` require a linked ADO work item
- Helm chart changes trigger the `helm-validate` skill automatically

## Related Decisions

See `.squad/decisions/` for platform-specific decisions tagged `area:platform`.
```

### Rules

1. File must be named exactly `.squad-context.md` (dot-prefixed, no variations)
2. The `**Label:**` field must match a label in `.squad/routing.md`'s area label schema
3. Keep it short — this is a **context file**, not a design doc
4. Do not duplicate root `.squad/routing.md` content; only add area-specific overrides

---

## Layer 2: Per-Area `.squads/` — Full Subsquad Config

### What It Is

A `.squads/` directory placed inside an area that provides a **full squad configuration** scoped
to that area. It can contain its own team roster, routing overrides, and decisions log — all
inheriting from (and overriding) the root `.squad/`.

### Structure

```
src/platform/
  .squads/
    team.md          ← area agent roster (references root agents by name)
    routing.md       ← area routing overrides
    decisions/       ← area-scoped decisions log
      inbox/         ← incoming decisions (merged by Scribe)
```

You only need to create the files that differ from the root config. The root `.squad/` remains
the source of truth for anything not explicitly overridden.

### `team.md` — Area Roster

The area roster lists which root agents are **active in this area** and may add area-specific
notes. It does **not** introduce new agents — all agents are defined in the root `.squad/agents/`.

```markdown
# Platform Team

> Subset of root squad focused on `src/platform/`.

| Name | Role | Active Here |
|------|------|-------------|
| B'Elanna | Infrastructure Expert | ✅ Primary |
| Worf | Security & Cloud | ✅ Security gate |
| Data | Code Expert | ✅ Go code reviews |
| Picard | Lead | ✅ Architecture only |
| Seven | Research & Docs | ✅ Platform docs |
| Crusher | Content Safety | ✅ HQ mandate — cannot be removed |

<!-- agents not listed here are not dispatched for platform-area tasks -->
```

**Inheritance rule:** Agents in the root `.squad/team.md` that are **not listed** in an area
`team.md` are still available but will not be auto-dispatched. They can always be invoked
explicitly.

**HQ mandates (cannot be overridden):**
- Crusher (content safety) is always active regardless of area roster
- Worf is always active for security-tagged issues regardless of area roster

### `routing.md` — Area Routing Overrides

Follows the same format as root `.squad/routing.md`. Area rules are applied **on top of** root
rules — they do not replace them.

```markdown
# Platform Area Routing

> Overrides for `src/platform/`. All root routing rules still apply.

## Work Type → Agent (Platform Overrides)

| Work Type | Primary | Secondary |
|-----------|---------|----------|
| Cluster lifecycle changes | B'Elanna | Picard (arch) |
| Auth middleware (`auth/`) | Worf | Data |
| Helm chart changes | B'Elanna | — |
| Platform docs | Seven | B'Elanna |

## Area Label Rules

When an issue or PR carries `area:platform`:
- Auto-assign B'Elanna as primary reviewer
- Require Worf sign-off if the diff touches `auth/`
- Ping Picard if the PR description contains "architecture" or "breaking"

## Override Semantics

These rules ADD TO root routing. They do not replace it. If a rule here conflicts
with a root HQ rule (e.g., Crusher gate), the HQ rule wins.
```

### `decisions/` — Area-Scoped Decisions Log

Same structure as root `.squad/decisions/`:

```
src/platform/.squads/decisions/
  inbox/
    belanna-cluster-timeout.md   ← new decision submitted by B'Elanna
  0001-cluster-node-pools.md     ← merged decision
  0002-helm-version-pin.md
```

Area decisions are **not merged** into the root log. They live permanently at
`src/<area>/.squads/decisions/`. Cross-area decisions (affecting multiple areas) go into the
root `.squad/decisions/`.

### Inheritance and Override Semantics Summary

```
Root .squad/          ← Always loaded (HQ)
  ↓  inherits
Area .squads/         ← Loaded when task touches this area
  ↓  overrides (additive)
Effective config for this task
```

| Config element | Merge behaviour |
|----------------|----------------|
| `team.md` roster | Area list **restricts** auto-dispatch; root agents still available on-demand |
| `routing.md` rules | Area rules **add to** root rules; conflicts resolved in favour of HQ |
| `decisions/` | Area decisions stay in area; root decisions apply everywhere |
| HQ mandates (Crusher, Worf security gate) | **Cannot be overridden** by any area config |

---

## Layer 3: Directory-Aware Agent Dispatch

### How It Works

When Squad receives a task (issue, PR, or explicit agent invocation), the dispatch logic:

1. Identifies the **area** from the task's `area:*` label, or infers it from changed file paths
2. Walks up the directory tree from the first changed file to find the nearest `.squads/` directory
3. Loads that area's config **on top of** the root config
4. Spawns agents according to the effective (merged) config

This is transparent to agents — they receive a fully merged config and don't need to know whether
they're working in a root-only or area-overridden context.

### Area Detection Order

1. **Explicit `area:*` label** on the issue/PR → use the label's registered path from routing.md
2. **Changed files** (PR diff or issue body) → find common prefix, walk up for `.squads/`
3. **Fallback** → use root `.squad/` only

### Area Label Schema

Defined in `.squad/routing.md`. Labels must be registered there before area dispatch will work.

| Label | Area path | Primary agent |
|-------|-----------|---------------|
| `area:platform` | `src/platform/` | B'Elanna |
| `area:platform:infra` | `src/platform/infra/` | B'Elanna |
| `area:platform:security` | Auth + secrets in platform | Worf |
| `area:api` | `src/api/` | Data |
| `area:api:breaking` | Breaking API changes | Data + Picard |
| `area:api:security` | Auth middleware | Worf |

To register a new area, add a row to the routing.md table and create the corresponding
`.squad-context.md` (at minimum).

### Multi-Area Tasks

When a PR or issue spans multiple areas:

```
PR touches: src/platform/auth/ AND src/api/middleware/
→ Load: platform area config + api area config
→ Union the routing requirements
→ Dispatch: B'Elanna (platform primary) + Data (api primary) + Worf (both security gates)
```

The union is additive — if both areas require Worf, Worf is dispatched once, not twice.

---

## `find-squad-config.ps1` — Config Discovery Script

### Overview

`scripts/find-squad-config.ps1` is the canonical way to discover which area config applies to
a given file path. It is used by Ralph, agents, and CI tooling to avoid hardcoding paths.

> **Note:** This script is being created in issue #1146. The interface below is the spec.

### Usage

```powershell
# Which area config applies to this file?
.\scripts\find-squad-config.ps1 -Path "src/platform/auth/handler.go"

# Output:
# Area    : platform
# Label   : area:platform
# Config  : src/platform/.squads/
# Context : src/platform/.squad-context.md
# Agents  : B'Elanna (primary), Worf (security gate)

# Show just the area label (useful in scripts)
.\scripts\find-squad-config.ps1 -Path "src/api/handlers/users.go" -ShowArea
# area:api

# List all registered areas
.\scripts\find-squad-config.ps1 -All

# Output:
# Label               Path                  Config              Context
# ----                ----                  ------              -------
# area:platform       src/platform/         src/platform/.squads/  src/platform/.squad-context.md
# area:api            src/api/              src/api/.squads/        src/api/.squad-context.md
```

### How It Works

1. Starting from the given `-Path`, walk up the directory tree
2. At each level, check for `.squads/` (full area config) or `.squad-context.md` (lightweight)
3. Return the first match with full metadata
4. If no area config is found, return root `.squad/` as the effective config

### Integration Points

| Where | How it's used |
|-------|--------------|
| Ralph's issue picker | `find-squad-config.ps1 -Path <changed-file> -ShowArea` to apply area label automatically |
| PR auto-labeller | Runs on every PR to apply `area:*` labels from changed file paths |
| Agent spawn prompt | Included in spawned agent context so the agent knows its area config |
| CI workflow | Validates that changed files have a registered area (warns if not) |

---

## Worked Examples

### Example 1: Adding Layer 1 Context to a New Area

**Scenario:** The frontend team wants agents working in `src/frontend/` to know who owns it and
what the key files are.

**Step 1:** Create `src/frontend/.squad-context.md`:

```markdown
# Area: Frontend

**Owner:** Troi (content), Data (code)  
**Label:** `area:frontend`  
**Primary path:** `src/frontend/`

## What This Area Does

React/TypeScript web application. Handles all user-facing UI.

## Key Files

| File | Purpose |
|------|---------|
| `src/frontend/app/layout.tsx` | Root layout |
| `src/frontend/components/` | Shared component library |
| `src/frontend/api/client.ts` | API client (generated — do not hand-edit) |

## Routing Hints

- CSS/component changes → Data (code) + Troi (UX review)
- API client regeneration → Data only
- Copy/content changes → Troi primary

## Constraints

- Do not modify `api/client.ts` directly — regenerate from OpenAPI spec
- All component changes need a Storybook story update
```

**Step 2:** Register the area label in `.squad/routing.md`:

```markdown
| `area:frontend` | `src/frontend/` | Data (code), Troi (UX) |
```

That's it for Layer 1. Agents working in `src/frontend/` now auto-load this context.

---

### Example 2: Adding Layer 2 Full Subsquad Config

**Scenario:** The API team is large enough to have its own routing rules and decisions log.

**Directory structure to create:**

```
src/api/
  .squad-context.md          ← already exists from Layer 1
  .squads/
    team.md
    routing.md
    decisions/
      inbox/
```

**`src/api/.squads/team.md`:**

```markdown
# API Team

| Name | Role | Active Here |
|------|------|-------------|
| Data | Code Expert | ✅ Primary |
| Picard | Lead | ✅ Breaking-change decisions |
| Worf | Security & Cloud | ✅ Auth middleware |
| Seven | Research & Docs | ✅ API docs |
| Crusher | Content Safety | ✅ HQ mandate |
```

**`src/api/.squads/routing.md`:**

```markdown
# API Area Routing

## Work Type → Agent

| Work Type | Primary | Secondary |
|-----------|---------|----------|
| Endpoint changes | Data | — |
| Breaking API changes | Data | Picard (required sign-off) |
| Auth middleware | Worf | Data |
| OpenAPI spec updates | Data | Seven (docs) |

## Label Rules

- `area:api:breaking` → always require Picard comment before merge
- Changes to `middleware/auth*` → auto-add `area:api:security` label
```

**Result:** Issues and PRs labelled `area:api` now use this config. Root HQ rules still apply —
Crusher and Worf security gates cannot be bypassed.

---

### Example 3: Multi-Area PR Dispatch

**Scenario:** A PR adds JWT refresh token support, touching both `src/platform/auth/` and
`src/api/middleware/auth.go`.

**What happens:**

1. PR is opened → CI runs `find-squad-config.ps1` on each changed file
2. Script detects: `area:platform:security` (platform auth) and `area:api:security` (API auth)
3. Both labels are applied to the PR automatically
4. Dispatch unions the configs:
   - B'Elanna (platform primary)
   - Data (api primary)
   - Worf (both security gates → dispatched once)
   - Picard (api:security cross-cutting concern)
5. All four agents review; Worf's security sign-off is required before merge

---

## Quick Reference

### "Do I need per-area config?"

```
Is this a single-team repo or small monorepo (<5 areas)?
  → No. Root .squad/ is sufficient.

Does a subdirectory have its own team, routing needs, or decisions?
  → Yes. Start with Layer 1 (.squad-context.md).

Does the area need its own agent roster or decisions log?
  → Yes. Add Layer 2 (.squads/).
```

### File Checklist per Area

| File | Layer | Required? |
|------|-------|-----------|
| `<area>/.squad-context.md` | 1 | Recommended for any named area |
| `<area>/.squads/team.md` | 2 | Only if roster differs from root |
| `<area>/.squads/routing.md` | 2 | Only if routing rules differ |
| `<area>/.squads/decisions/` | 2 | Only if area has its own decision log |

### Override Cheatsheet

| You want to… | How |
|-------------|-----|
| Add context without changing routing | Layer 1 only |
| Restrict which agents auto-dispatch | Area `team.md` (list only relevant agents) |
| Add routing rules for this area | Area `routing.md` (additive) |
| Prevent root routing rules from applying | ❌ Not supported — area rules are additive |
| Override a HQ security gate | ❌ Not supported — HQ mandates are absolute |
| Track decisions only for this area | Area `decisions/` directory |

---

## See Also

- `.squad/routing.md` — root routing rules and area label schema (quick reference)
- `.squad/team.md` — full agent roster
- `scripts/find-squad-config.ps1` — config discovery script (issue #1146)
- Issue [#1012](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1012) — original design proposal
