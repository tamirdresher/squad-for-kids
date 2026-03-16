# Decision: Ingress-NGINX EOL — Migrate to Gateway API

**Author:** B'Elanna (Infrastructure)
**Date:** 2026-03-16
**Issue:** #644
**Priority:** CRITICAL

## Context
Community-maintained `kubernetes/ingress-nginx` reached End of Life on March 16, 2026.
No more security patches, bug fixes, or releases. Known critical CVEs (CVE-2025-1974) will remain unpatched.

## Decision
All DK8S clusters using `kubernetes/ingress-nginx` must migrate to **Kubernetes Gateway API** within 8 weeks (target: May 11, 2026).

## Key Points for Team
- **ConfigGen impact**: Templates that generate `Ingress` resources will need updating to generate `Gateway`, `HTTPRoute`, etc.
- **Helm charts**: All Helm charts deploying ingress-nginx controller need replacement charts for Gateway API implementation
- **Recommended implementation**: NGINX Gateway Fabric (closest migration path from current setup)
- **Compliance**: Running EOL software blocks SOC 2, ISO 27001, PCI-DSS — auditors need documented migration plan

## Action Required From
- **Data (C#/.NET)**: Review ConfigGen templates that generate Ingress resources
- **Worf (Security)**: File security advisory for compliance tracking
- **B'Elanna (Infra)**: Lead migration execution across DK8S clusters
