# Decision: Fleet Manager Security — FIC and Identity Movement

**Date:** 2026-03-07  
**Author:** Worf (Security & Cloud)  
**Issue:** #3 — Azure Fleet Manager evaluation for DK8S RP  
**Status:** Proposed  
**Impact:** Critical

---

## Summary

Fleet Manager adoption for DK8S RP is a **CONDITIONAL NO-GO** from a security perspective. Four hard security gates must be satisfied before proceeding.

## Security Gates (All Must Pass)

| Gate | Condition | Current Status |
|------|-----------|----------------|
| **G1** | Workload Identity migration complete (retire AAD Pod Identity) | 🟡 In Progress |
| **G2** | Fleet Manager GA in US NAT, US SEC, Blue, Delos | 🔴 Not Met |
| **G3** | FIC scaling solution (Identity Bindings or equivalent) GA | 🔴 Preview Only |
| **G4** | Fleet Manager hub threat model documented | 🔴 Not Started |

## Critical Risks Identified

1. **FIC 20-per-UAMI ceiling** — DK8S scale (50+ clusters) exceeds per-identity FIC limit
2. **UAMI node exposure** — Shared fleet environments allow node-level identity access (Falcon team confirmed)
3. **Sovereign cloud gaps** — Features not available in all required clouds (hard constraint)
4. **Identity movement gaps** — No automated FIC lifecycle for cluster migration scenarios

## 17 Mitigations Proposed

See `fleet-manager-security-analysis.md` for full details:
- 4 pre-adoption requirements
- 5 architecture controls
- 4 operational controls
- 4 migration-specific controls

## Phased Adoption Path

- **Phase 0 (Q2 2026):** PoC in public cloud, non-production
- **Phase 1 (Q3 2026):** Limited production, public cloud only
- **Phase 2 (Q4 2026):** Multi-region public cloud
- **Phase 3 (2027+):** Sovereign clouds (dependent on AKS roadmap)

## Alignment

Aligns with Picard's architectural DEFER recommendation. Security gates are the primary blockers.

## Evidence Sources

- Feb 18, 2026 Defender/AKS meeting — identity blast radius, sovereign cloud constraints
- Partner FIC Document — UAMI exposure in shared fleets, zero-trust gaps
- EngineeringHub — FalconFleet FIC guide, Fleet Workload Identity Setup
- Public docs — Azure Fleet Manager MI, AKS Identity Bindings (preview)
