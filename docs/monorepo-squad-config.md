# Monorepo Support — Per-Area Squad Configuration

> **Summary guide for monorepo users.** Start here to understand how Squad handles multiple
> teams in a single repository. For complete reference documentation, see
> [`.squad/docs/monorepo-support.md`](../.squad/docs/monorepo-support.md).
>
> Closes issue [#1012](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1012).

---

## The Problem

In a standard single-team repo, `.squad/` lives at the root and everything shares one routing
table, one roster, and one decisions log. That works fine for small teams.

In a **monorepo** — `src/platform/`, `src/api/`, `src/frontend/`, etc. — the root `.squad/`
becomes a bottleneck. Platform-team routing rules mix with API-team rules. One area's decisions
clutter another area's log. Agents spawned for a frontend task load irrelevant infrastructure
context every time.

Squad solves this with **per-area configuration**: each subdirectory that wants its own team
identity can carry its own Squad config, inheriting from (and overriding) the root.

---

## Solution Overview: Three Layers

| Layer | What you create | Effort | Best for |
|-------|----------------|--------|----------|
| **1** | `<area>/.squad-context.md` | One file, ~30 lines | Any subdirectory that needs context awareness |
| **2** | `<area>/.squads/` directory | 2–3 files | Team-owned area with its own roster + routing |
| **3** | Automatic dispatch | Zero — already active | Falls out of Layers 1 + 2 once set up |

Layers are **additive** — add Layer 1 today without committing to Layer 2. The root `.squad/`
is always "HQ" and is always loaded; area configs supplement it.

---

## Layer 1 — Lightweight Context File

Create a single `.squad-context.md` file at the root of the area:

```
src/platform/
  .squad-context.md   ← add this
  auth/
  infra/
```

When an agent works on any file under `src/platform/`, Squad walks up the directory tree and
loads the first `.squad-context.md` it finds. The agent receives the area context automatically —
no routing changes required.

**Minimal template:**

```markdown
# Area: Platform

**Owner:** B'Elanna
**Label:** `area:platform`
**Primary path:** `src/platform/`

## What This Area Does

Core infrastructure: cluster lifecycle, service mesh, provisioning.
Changes here affect all other areas — coordinate carefully.

## Routing Hints

- Security changes (`auth/`) → always involve Worf
- Cluster changes → B'Elanna primary, Picard for architecture
- Breaking changes → apply `area:platform:breaking`, require Picard sign-off
```

**Rules:**
- File must be named exactly `.squad-context.md`
- The `**Label:**` field must match a label registered in `.squad/routing.md`
- Keep it short — this is context, not a design doc

---

## Layer 2 — Full Per-Area Subsquad Config

For areas that need their own agent roster, routing rules, or decisions log:

```
src/platform/
  .squad-context.md         ← Layer 1 (still needed)
  .squads/
    team.md                 ← which agents are active here
    routing.md              ← area-specific routing rules (additive to root)
    decisions/              ← area-scoped decisions log
      inbox/
```

See the live example at [`examples/platform-area/.squads/config.json`](../examples/platform-area/.squads/config.json).

### `team.md` — Restrict auto-dispatch to relevant agents

```markdown
# Platform Team

| Name | Role | Active Here |
|------|------|-------------|
| B'Elanna | Infrastructure Lead | ✅ Primary |
| Worf | Security & Cloud | ✅ Security gate |
| Data | Code Expert | ✅ Go code reviews |
| Picard | Lead | ✅ Architecture decisions |
| Seven | Research & Docs | ✅ Platform docs |
```

Agents not listed here are still available on-demand but won't be auto-dispatched.
**HQ mandates cannot be removed:** Crusher (content safety) and the Worf security gate are
always active regardless of what any area `team.md` specifies.

### `routing.md` — Add area-specific rules

```markdown
# Platform Area Routing

> Additive overrides for src/platform/. Root rules still apply.

| Work Type | Primary | Secondary |
|-----------|---------|----------|
| Cluster lifecycle | B'Elanna | Picard (arch) |
| Auth middleware (`auth/`) | Worf | Data |
| Helm charts | B'Elanna | — |
```

Area routing rules **add to** root rules. They do not replace them. HQ rules always win on conflict.

---

## Config Discovery: `find-squad-config.ps1`

The script `scripts/find-squad-config.ps1` discovers which area config applies to any given
file path. It is used by agents, Ralph's issue picker, and CI tooling.

```powershell
# Dot-source the script
. .\scripts\find-squad-config.ps1

# Which area config applies to this file?
Find-SquadConfig -Path "src/platform/auth/handler.go"

# Returns:
# ConfigPath    : C:\...\src\platform\.squad
# ConfigRoot    : C:\...\src\platform
# IsAreaConfig  : True
# AreaName      : src/platform

# Read the .squad-context.md for a file
Get-SquadContext -Path "src/platform/auth/handler.go"
```

The script walks up the directory tree from the given path. At each level it looks for a
`.squad/` directory (full area config) or a `.squad-context.md` (lightweight). If nothing
is found between the file and the repo root, it falls back to the root `.squad/`.

---

## Inheritance Rules at a Glance

```
Root .squad/               ← Always loaded (HQ)
  ↓ inherits
Area .squads/              ← Loaded when task touches this area
  ↓ additive override
Effective config for task
```

| Config element | How it merges |
|----------------|--------------|
| `team.md` roster | Area list *restricts* auto-dispatch; root agents still on-demand |
| `routing.md` rules | Area rules *add to* root; HQ wins on conflict |
| `decisions/` | Area decisions stay in area; root decisions apply everywhere |
| HQ mandates | **Cannot be overridden** by any area config |

---

## Agent Identity (Issue #1012 Companion)

This section addresses the second question from the original issue.

**How agents authenticate today:** Agents inherit the invoking user's identity via Entra ID SSO
passthrough through Copilot CLI. There is no separate service principal per agent today.

**What this means practically:**
- Agent actions are auditable as the human user's actions
- MCP server connections use the same token scope as the user session
- Admins can audit agent activity through the same tooling as human activity

**MCP server manifest:** Each Squad repository documents its MCP servers in
`.squad/mcp-servers.md`. This lists which MCP servers are active, what scopes they require,
and which agents use them — giving admins a single place to review the agent's "blast radius."

**Roadmap:** A Squad service principal for automated/unattended runs is tracked separately.

---

## Quick Setup Checklist

- [ ] Create `<area>/.squad-context.md` for each named area (Layer 1)
- [ ] Register the `area:<name>` label in `.squad/routing.md`
- [ ] Create GitHub label `area:<name>` (see `.squad/scripts/setup-area-labels.ps1`)
- [ ] If the area needs its own roster: add `<area>/.squads/team.md`
- [ ] If the area needs routing overrides: add `<area>/.squads/routing.md`
- [ ] Test discovery: `. .\scripts\find-squad-config.ps1; Find-SquadConfig -Path "<area>/somefile"`

---

## See Also

- **Full reference:** [`.squad/docs/monorepo-support.md`](../.squad/docs/monorepo-support.md)
- **Root routing table:** [`.squad/routing.md`](../.squad/routing.md)
- **Config discovery script:** [`scripts/find-squad-config.ps1`](../scripts/find-squad-config.ps1)
- **Live example:** [`examples/platform-area/.squads/`](../examples/platform-area/.squads/)
- **Area label setup:** `.squad/scripts/setup-area-labels.ps1` (issue #1153)
- **Original issue:** [#1012](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1012)
