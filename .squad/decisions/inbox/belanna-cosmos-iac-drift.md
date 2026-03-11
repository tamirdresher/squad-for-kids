# Decision: Address Cosmos DB IaC Drift

**Author:** B'Elanna (Infrastructure)
**Date:** 2026-07-17
**Context:** Issue #337 — IcM Incident 759361753

## Problem

Live Azure state for multiple Cosmos DB accounts diverges from IaC definitions:
- Bicep template defines `publicNetworkAccess: 'Enabled'` and `networkAclBypass: 'AzureServices'`
- Several live accounts show `publicNetworkAccess: Disabled`, `networkAclBypass: None`
- NSP (Network Security Perimeter) policies (`NSP-CDB-v1-0-En-Deny`) are enforcing network restrictions in Deny mode

This drift means our IaC is no longer the source of truth for Cosmos DB network configuration.

## Recommendation

1. **Audit and reconcile** IaC templates with actual Azure state for all Cosmos DB accounts
2. **Import existing network rules** into Bicep/Terraform to prevent future drift
3. **Document which policies are managed centrally** (governance team) vs. team-managed
4. **Add drift detection** to CI/CD — `az deployment what-if` or similar to flag when live state diverges from IaC

## Impact

Without this, future incidents like IcM 759361753 will keep occurring — the team can't confidently answer "did we change anything?" when IaC doesn't reflect reality.
