# Decision: DevBox Provisioning Strategy

**Date:** 2026-03-08  
**Agent:** B'Elanna (Infrastructure Expert)  
**Issue:** #103 — Duplicate IDPDev DevBox  
**Status:** Executed

## Context

Tamir requested a duplicate of the IDPDev devbox (1SOC project) with identical specs.

## Decision

**Use Azure DevBox Portal UI for one-off DevBox provisioning, not CLI.**

## Rationale

1. **CLI Extension Unreliable:** `az devcenter` extension failed to install (`pip failed with status code 1`)
2. **Portal UI is Stable:** Web interface at https://devbox.microsoft.com is reliable and well-tested
3. **Playwright Automation:** Browser automation provides reproducible, auditable provisioning steps
4. **One-off Nature:** For single devbox creation, UI automation is faster than troubleshooting CLI issues

## Implementation

- **Tool:** Playwright via Edge browser (msedge) with persistent profile
- **Portal:** https://devbox.microsoft.com
- **Result:** IDPDev-2 created successfully in West Europe with matching specs

## Trade-offs

- **Pros:** Reliable, visual confirmation, no dependency on CLI extensions
- **Cons:** Not scriptable for bulk operations (but acceptable for one-off requests)

## Recommendation

For bulk or CI/CD DevBox provisioning, invest in fixing `az devcenter` CLI. For ad-hoc requests from team members, continue using Portal + Playwright automation.

---

**Related:** Issue #103, `.squad/agents/belanna/history.md`
