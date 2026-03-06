# Decision Proposal: DK8S Stability & Config Management Priorities

**Author:** B'Elanna Torres (Infrastructure Expert)  
**Date:** 2026-03-07  
**Status:** Proposed  
**Scope:** DK8S Platform Reliability  
**Related Issue:** #4

---

## Context

Comprehensive stability analysis of the DK8S platform based on IcM incidents, Teams conversations (BAND, DK8S Leads), meeting transcripts, and EngineeringHub docs. See `dk8s-stability-analysis.md` for full details.

## Key Findings

1. **Networking is the #1 outage driver** — NAT Gateway degradations, DNS resolution failures, and ingress issues caused most Sev2 incidents (Oct 2025 – Feb 2026)
2. **Istio integration is the highest-risk active change** — Jan 2026 Sev2 directly caused by ztunnel + DNS interaction when Geneva loggers were meshed
3. **ConfigGen breaking changes are an acknowledged leadership KPI problem** — Tracked as "decrease the # of breaking changes" at IDP level
4. **Weak deployment feedback loops** — IDP has no visibility into EV2 step failures or NuGet version adoption
5. **Argo Rollouts have shared-resource failure modes** — Leads actively debating whether to continue supporting them

## Proposed Decisions

### Decision A: Decouple infrastructure components from Istio mesh
- **Rationale:** Jan 2026 outage root cause was geneva-loggers in mesh creating cascading failure
- **Action:** Establish permanent exclusion list for Geneva, CoreDNS, kube-system components
- **Impact:** Prevents observability blackout during mesh failures

### Decision B: Enforce minimum ConfigGen NuGet version at CI
- **Rationale:** Breaking changes from MI/ACR transitions break deployments on old versions
- **Action:** CI gate that blocks builds using ConfigGen versions below minimum
- **Impact:** Eliminates known-broken deployment paths

### Decision C: Implement zone-aware NAT Gateway monitoring
- **Rationale:** Current alerting pages on single NAT Gateway drops without AZ discrimination
- **Action:** Zone-aware monitoring to reduce false Sev2 pages
- **Impact:** Better incident discrimination, fewer unnecessary escalations

### Decision D: Add deny assignments for manual resource deletions
- **Rationale:** Manual cluster/resource deletions cause alert storms and downstream failures
- **Action:** Deny assignments at management-group level with Geneva Actions approval flow
- **Impact:** Prevents accidental infrastructure destruction

## Team Input Needed

- Picard: Architectural alignment with RP-first direction
- Worf: Security implications of Istio exclusion list
- Data: ConfigGen CI enforcement implementation
- Seven: Documentation gaps in breaking change communication
