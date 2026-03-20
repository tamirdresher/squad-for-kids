# Picard Decision: Squad × DK8S Integration Roadmap — Design References Locked

**Date:** 2026-03-20
**Author:** Picard (Lead)
**Issue:** #1039 — Squad as DK8S first-class citizen
**Status:** Decided

## Decision

The `docs/squad-dk8s-integration-roadmap.md` has been updated to explicitly incorporate and cross-reference the full set of Squad-on-Kubernetes design work:

- **#994** (Squad-on-K8s architecture) → pod-per-agent model confirmed as the implementation approach
- **#998** (Copilot Auth for K8s pods) → Workload Identity + sidecar auth proxy is the recommended auth pattern; Redis for rate pool coordination
- **#999** (K8s-Native Capability Routing) → Capability Discovery DaemonSet replaces `discover-machine-capabilities.ps1`; node labels map 1:1 from `needs:*` issue labels
- **#1000** (Squad Helm Chart prototype) → Full chart structure documented in roadmap; values.yaml schema aligned with DK8S conventions
- **#1059** (Squad on K8s architecture design) → CronJob vs. Deployment choice (both acceptable; Deployment preferred for Phase 2)

## What This Means for Other Agents

- **Belanna:** ConfigGen integration (#1038) is the critical Phase 2 gate. No manual `values.yaml` editing — ConfigGen generates it.
- **Worf:** Auth design is locked: Workload Identity + auth-proxy sidecar. Review #998 for security posture details.
- **Data:** Helm chart prototype (#1000) is the coding target for Phase 2. Chart structure is in the roadmap.
- **All agents:** The three-phase roadmap (Issue Management → Running on DK8S → Platform Capability) is the canonical sequence. Do not skip Phase 1 completion before starting Phase 2.
