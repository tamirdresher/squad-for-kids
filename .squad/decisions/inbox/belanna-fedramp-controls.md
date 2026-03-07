# Decision: NetworkPolicy Architecture for Ingress Security

**Date:** 2026-03-12  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #54  
**Status:** Proposed  
**Impact:** High

## Decision

Deploy default-deny + explicit allow-list NetworkPolicies in the `ingress-nginx` namespace as FedRAMP compensating controls, with separate policies for public and sovereign clouds.

## Key Choices

1. **Default-deny first, allow-list second.** ArgoCD sync-wave -10 ensures zero-trust baseline before any ingress workload starts. This is non-negotiable for FedRAMP SC-7 compliance.

2. **Separate sovereign policy.** Gov clusters use restricted source CIDRs instead of `0.0.0.0/0`, block HTTP port 80 entirely, and include dSTS egress. This avoids complex conditional logic in a single policy.

3. **Helm-driven configuration.** `networkPolicy.enabled` and `networkPolicy.sovereign.enabled` toggles allow per-environment control via ArgoCD ApplicationSet valueFiles. No manual kubectl operations.

4. **CI/CD policy-as-code.** Conftest/OPA rules enforce that no NetworkPolicy in the ingress namespace allows unrestricted egress, and all policies carry FedRAMP control labels.

## Risks

- **False-positive blocks:** If node CIDRs change, healthcheck probes fail → ingress goes unhealthy. Mitigated by configurable `nodeCIDRs` in values.yaml.
- **CNI dependency:** NetworkPolicies require a CNI that enforces them (Calico, Cilium). If DK8S uses Azure CNI without network policy support, these are no-ops. Must verify CNI configuration.
- **Sync ordering:** If ArgoCD sync waves fail or are bypassed (manual sync), policies might not be in place before ingress. Mitigated by conftest CI/CD gate.

## Depends On

- Worf: WAF deployment (Front Door CIDRs needed for sovereign policy)
- Worf: OPA/Gatekeeper ConstraintTemplates (admission-time validation)
- Verification of DK8S CNI type and network policy enforcement capability
