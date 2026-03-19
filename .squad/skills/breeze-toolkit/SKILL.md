# s360-breeze-toolkit

> **Source:** `agency-microsoft/playground` → `plugins/s360-breeze-toolkit`  
> **Category:** Security  
> **Status:** Preview — under active development  
> **Built by:** 1ES AI Native Engineering Team (Microsoft)

## What It Is

An AI-powered agent plugin for the **Agency / GitHub Copilot** platform that automates SFI (Secure Future Initiative) compliance violation remediation. Give it a KPI ID and a repo, and it resolves the issue or walks you through it.

> ⚠️ This plugin is **Microsoft-internal**. Access requires SSO via Microsoft EMU. It is hosted in `agency-microsoft/playground` (private org).

---

## What It Does

- Accepts an SFI/QEI KPI ID (e.g., `ID 4.2.1`, `NS 2.2.1`, `ES 5.4.1`)
- Calls the S360 API to fetch KPI metadata and remediation guidance
- Routes to the correct skill for that KPI
- Applies code/config fixes in your repo
- Reports what was changed

### KPI Coverage (v0.3)

| Pillar | Coverage |
|--------|----------|
| ES (Engineering Systems) | 1/24 |
| ID (Identity) | 10/38 |
| NS (Network Security) | 3/16 |
| PS (Protect Software) | 0/14 |
| TI (Threat Intelligence) | 3/47 |
| AR / SM / Other | 4/12 |
| QE (Quality & Efficiency) | 1/33 |
| **Total** | **22 of 164+ KPIs** with dedicated skills |

All 164+ KPIs have intelligent TSG-guided fallback coverage.

---

## Agents Included

| Agent | Purpose |
|-------|---------|
| `s360-breeze-orchestrator` | Main orchestrator — routes KPI violations to correct skill |
| `mise-v2-migration-orchestrator` | MISE v2 identity middleware migrations |
| `msaljs-migration` | MSAL.js version upgrade migrations |
| `otel-audit-orchestrator` | OpenTelemetry instrumentation audits |
| `plugin-static-analyzer` | Static analysis of plugins for SFI patterns |
| `generic-pr-quality-evaluator` | PR quality checks (ADO + GitHub variants) |
| `sfi-skill-tester` | Tests SFI remediation skills |

## Skills Included (Notable)

- `sfi-id421/422/423/427/431/432/433` — Entra ID auth migrations (Storage, SQL, CosmosDB, Redis, Cognitive, EventHub, ServiceBus)
- `sfi-ns221-*` — Network Security Perimeter (NSP) logging and creation
- `sfi-ns252-avnm-*` — Azure Virtual Network Manager
- `sfi-ti433-multitenant-org-restriction` — Multi-tenant org restriction
- `sfi-es541-fcib-remediate` — Foreign Checked-In Binary remediation
- `mise-v1/v2-*` — MISE middleware migration (legacy → v2, OWIN, ASP.NET Core, container)
- `msaljs-*` — MSAL.js migrations (v2→v5 paths, Angular, React, browser, node)
- `qei-pr342-eliminate-high-blast-radius-msi` — QEI blast radius MSI cleanup

---

## Prerequisites

- **Azure CLI** — `az login` with corporate identity
- **GitHub Copilot CLI** — installed and authenticated
- **MCP Servers** — WorkIQ (for TSG lookups); Playwright (optional, for portal automation)
- **Access** — Microsoft EMU SSO required (internal only)

---

## How to Install

```bash
# Via Copilot CLI Agency plugin system
/plugin install s360-breeze-toolkit
```

The `mise-v2-migration` plugin dependency is installed automatically.

---

## How to Use

```
> I have an SFI violation for ID 4.2.1 in my repo
> Fix SFI ES 5.4.1 FCIB violation in tamresearch1
> Run MISE v2 migration for my service
```

The agent will:
1. Ask for consent to call S360 API
2. Fetch KPI metadata and remediation guidance
3. Route to the right skill
4. Fix code/config in your repo
5. Report what it changed

---

## Relevance to This Repo

This repo (`tamresearch1`) is a research/personal workspace and does **not** currently have SFI compliance requirements as a production service. However, the toolkit is useful to **understand, reference, and potentially contribute to** SFI remediation automation.

**Recommendation:** Install via `/plugin install s360-breeze-toolkit` when working on repos with active SFI KPI violations.

---

## References

- Plugin: `agency-microsoft/playground/plugins/s360-breeze-toolkit`
- Marketplace: [Agency Plugins Marketplace](https://github.com/agency-microsoft/.github-private)
- Docs: `plugins/s360-breeze-toolkit/ONBOARDING-GUIDE.md` (in playground repo)
