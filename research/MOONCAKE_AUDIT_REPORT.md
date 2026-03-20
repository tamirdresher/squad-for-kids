# Mooncake Region Deprecation — Audit Report
## China North 1 / China East 1 Endpoint Inventory

**Issue:** #1148  
**Priority:** P1  
**Deadline:** July 1, 2026  
**Author:** Picard (Squad Lead)  
**Date:** 2026-03-21  
**Source:** RP Platform Newsletter — March 2026 ([Issue #1144](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1144))

---

## Executive Summary

Azure is decommissioning **China North 1** (`chinanorth`) and **China East 1** (`chinaeast`) on **July 1, 2026**. This audit documents the findings from searching all configuration files, infrastructure code, and documentation in this repository for any references to these deprecated regions.

**Key Finding:** No endpoint registrations for CN1/CE1 were found in this repository's infrastructure configs. However, BasePlatformRP's production RP/RT registration manifest is not stored here — **a manual audit of that manifest is required before this issue can be closed.**

---

## Repo Audit Findings

### Files Scanned
- `infrastructure/environments/*.parameters.json` — all environment configs
- `infrastructure/helm/**`, `infrastructure/k8s/**`, `infrastructure/docker/**`
- `docs/**` — all documentation
- `*.yaml`, `*.json`, `*.md` — all config and doc files in repo root

### Region References Found

| File | Reference | Type |
|------|-----------|------|
| `docs/fedramp/networkpolicy-ingress-sovereign.yaml` | "Stricter policy for Fairfax/Mooncake" | Comment — sovereign cloud policy header |
| `.squad/decisions.md` | Mooncake mentioned in cross-cloud security, sovereign cloud support | Architecture discussion only |
| `issue1144-full.txt` | Full analysis of Mooncake deprecation from newsletter | Research artifact |

### Region Configs — Infrastructure Environments

All `infrastructure/environments/*.parameters.json` files use **Public Cloud regions only**:

| Environment | Location | Failover |
|-------------|----------|---------|
| `dev` | `eastus2` | — |
| `stg` | `eastus2` | — |
| `ppe` | `eastus2` | — |
| `prod` | `eastus2` | `westus2` |
| `stg-gov` | (Fairfax-gov config) | — |

✅ **No `chinanorth`, `chinaeast`, `chinanorth2`, `chinaeast2` references found in any infrastructure files.**

### Mooncake Cloud Tenant Reference

From issue1144 analysis, Mooncake's MISE V2 AME tenant ID is:  
`a55a4d5b-9241-49b1-b4ff-befa8db00269`

This was documented in the MISE V2 auth context — no deployed resource using this tenant ID was found in any infrastructure config in this repo.

---

## What Needs Manual Verification

This repository does **not** contain BasePlatformRP's production RP/RT registration manifest. The following must be checked directly with the team.

### Checklist for Tamir / BasePlatformRP Team

#### 1. RP/RT Registration Manifest (`endpoints.locations`)

- [ ] Open BasePlatformRP's RP manifest (typically at `<repo>/src/Config/Prod/rp-registration.json` or similar)
- [ ] Search for `"chinanorth"` — must NOT appear unless it refers to `chinanorth2` or `chinanorth3`
- [ ] Search for `"chinaeast"` — must NOT appear unless it refers to `chinaeast2` or `chinaeast3`
- [ ] Search for `"China North"` (display name variant)
- [ ] Search for `"China East"` (display name variant)
- [ ] Confirm no `endpoints.locations` entry matches ARM region names: `chinanorth`, `chinaeast`

#### 2. Service Deployment Configs

- [ ] Check Ev2 rollout configs for any `chinanorth` or `chinaeast` deployment targets
- [ ] Check ServiceModel or subscription/region mappings for Mooncake CN1/CE1 entries
- [ ] Search ARM deployment templates for China region location parameters

#### 3. Swagger / OpenAPI Specs

- [ ] Check if any Swagger `x-ms-skip-url-encoding`, `x-ms-azure-resource`, or `x-ms-locations` enums list `chinanorth` or `chinaeast`
- [ ] If SDP for OpenAPI Specs is active (see item #3 in newsletter), ensure the swagger PR workflow is not accidentally propagating stale region lists

#### 4. Monitoring & Alerting

- [ ] Check Geneva monitoring configs for Mooncake China North 1 / China East 1 endpoints
- [ ] Check ICM on-call routing rules for CN1/CE1 cluster references
- [ ] Search Application Insights / Kusto workspaces for `chinanorth`/`chinaeast` queries

#### 5. Downstream Dependencies

- [ ] Does BasePlatformRP call any services that have CN1/CE1 endpoints? (Storage, CosmosDB, Service Bus, Key Vault)
- [ ] Check ARM allowlist or network ACLs for CN1/CE1 CIDR blocks

---

## ADO Context

Related ARM/RP Platform ADO work items (from newsletter):

| ADO ID | Title | Status |
|--------|-------|--------|
| 36955411 | [Mooncake] Migration tooling changes for China East 1/North 1 deprecation | New |
| 35009131 | [Region Buildout] ARM Mooncake Region Decommissioning | New |
| 35009124 | [Scale] ARM Mooncake Region Decommissioning | New |

These are ARM-side items. Tamir should check if BasePlatformRP has its own linked work items.

---

## Region Migration Reference

If CN1/CE1 endpoints **are found**, the migration path is:

| Deprecated Region | ARM Name | → Migrate To | ARM Name |
|---|---|---|---|
| China North 1 | `chinanorth` | China North 2 | `chinanorth2` |
| China North 1 | `chinanorth` | China North 3 | `chinanorth3` |
| China East 1 | `chinaeast` | China East 2 | `chinaeast2` |
| China East 1 | `chinaeast` | China East 3 | `chinaeast3` |

Migration steps (if endpoints found):
1. Provision BasePlatformRP service in CN2/CN3 or CE2/CE3
2. Add new endpoint entries in RP/RT registration manifest
3. Update rollout configs (Ev2) to include new regions
4. Verify swagger location enums are updated
5. Submit RP registration update PR and get ARM team approval
6. Monitor traffic cutover before July 1 deadline
7. Remove CN1/CE1 entries from manifest after confirmed migration

---

## Key Documentation

| Resource | URL |
|----------|-----|
| Azure China Datacenter Overview | https://learn.microsoft.com/azure/china/overview-datacenter |
| ARM Region Decommissioning (search on ARM Wiki) | https://eng.ms/docs/products/arm/ → "Region Decommissioning: Resource Provider Responsibilities" |
| RP Platform Newsletter March 2026 | Issue #1144 in this repo |
| Mooncake MISE V2 tenant ID | `a55a4d5b-9241-49b1-b4ff-befa8db00269` |

---

## Timeline

| Date | Milestone |
|------|-----------|
| Now | Audit RP/RT manifest — check for CN1/CE1 endpoints |
| +1 week | If found: begin CN2/CE2 provisioning |
| +3 weeks | Complete endpoint migration and RP manifest update |
| +4 weeks | Submit RP registration PR for ARM review |
| June 1, 2026 | All CN1/CE1 traffic must be migrated (1-month buffer) |
| **July 1, 2026** | **ARM decommissions CN1/CE1 — hard deadline** |

---

## Recommended Actions

1. **Immediately:** Search BasePlatformRP's production RP manifest for `chinanorth` and `chinaeast` entries (use the checklist above)
2. **If no endpoints found:** Document the finding, close this issue ✅
3. **If endpoints found:** Escalate to P0, follow migration steps above, target June 1 completion to have a 1-month buffer before the hard deadline

> **Note:** Even if BasePlatformRP has never deployed to Mooncake, the RP/RT registration manifest may still list these regions from an initial template or historical registration. Always verify the manifest directly.
