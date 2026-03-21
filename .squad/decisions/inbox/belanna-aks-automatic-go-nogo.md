# Decision: AKS Automatic — Go for Production, Standard Free for Dev/Test

**Date:** 2026-07-17
**Author:** B'Elanna (Infrastructure Expert)
**Issue:** #1136
**Status:** Recommended — Pending team adoption

## Decision

AKS Automatic is **GO for Squad production deployment**. AKS Standard Free tier is the right choice for initial dev/test to minimize cost.

## Rationale

All five research questions (issue #1136) returned green:
1. CronJob `concurrencyPolicy: Forbid` — fully supported
2. Workload Identity for Key Vault — built-in and simpler on Automatic
3. KEDA with Prometheus custom metrics — KEDA v2.10+ pre-installed, full scaler support
4. Cold-start from zero — 1–3 min typical, acceptable for async Squad agents
5. Pricing — ~$150–200/mo (Automatic) vs ~$55–80/mo (Standard Free)

The 9 manual setup steps eliminated (OIDC issuer, Workload Identity, CSI driver, KEDA addon, 2 node pools, autoscaler, node pool labels, Log Analytics wiring) represent ~50% ops reduction vs current squad-on-aks.md.

## Implications for Other Agents

- **Helm chart:** `values-aks-automatic.yaml` override file added to `infrastructure/helm/squad-agents/`. Use this for production deploys. Default `values.yaml` remains compatible with Standard.
- **KEDA:** `keda.enabled: true` in the AKS Automatic values override. The ScaledObject for Picard is live when this file is used.
- **Node selectors:** Custom `squad.github.com/pool` node selectors are cleared in the override. Don't add manual nodeSelector blocks for Automatic clusters.
- **squad-on-aks.md:** Needs an "AKS Automatic Fast Path" section annotating the 9 eliminated steps.
- **Phase 3 CRDs:** Not blocked. AKS Automatic supports custom CRDs identically.
- **GPU/KAITO (#997):** Clear path via Karpenter + KAITO on Automatic.

## Migration Path

Standard Free (dev/test) → Standard tier (if SLA needed mid-flight) → Automatic (production). Not a one-way door.
