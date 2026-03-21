# ADC Integration Strategy Decision

**Date:** 2026-03-20
**Author:** Picard (Lead)
**Issue:** #1064 — ADC integration for Squad
**Status:** PROPOSED — Awaiting Tamir's decision

## Decision

Recommend pursuing **ADC as primary Squad deployment target (Option C: ADC Primary + DevBox for
capability tasks)**, contingent on #752 POC validation.

## Rationale

ADC solves Squad's top two pain points simultaneously:
1. **Session persistence** — no idle-timeout, no keep-alive hacks needed
2. **Zero infrastructure management** — no K8s expertise required to run Squad

## Conditions (Must All Pass Before Committing to Option C)

- [ ] MCP servers work inside ADC sessions (or equivalent extension point exists)
- [ ] ADC sessions have no idle-timeout over 24h
- [ ] ADC cost is competitive with DevBox/AKS for Squad's bursty workload pattern

## If Conditions Fail

Fall back to **Option B: ADC as overflow/scale layer** alongside existing DevBox/K8s targets.

## Full Research

See `docs/adc-squad-integration-research.md` for complete analysis including architecture options,
key questions, implementation steps, and risk register.
