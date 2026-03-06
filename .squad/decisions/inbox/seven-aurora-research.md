# Decision Proposal: Aurora Adoption for DK8S

**Date:** 2026-03-06  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** Platform Validation & Quality  
**Related:** Issue #4

## Context

Aurora is Microsoft's E2E validation platform for Azure (owned by Azure Core / One Fleet Platform). Today's Cloud Talks session introduced Aurora's capabilities: customer workload validation, Deployment Integrated Validation (DIV), Aurora Bridge for existing pipelines, resiliency testing with Chaos Studio, and AI-assisted workload creation.

## Proposed Decision

**Adopt Aurora in phased approach for DK8S validation, starting with Aurora Bridge.**

### Rationale
1. DK8S has no structured E2E validation or resiliency testing today
2. Aurora Bridge connects to existing OneBranch pipelines with zero test rewriting
3. DIV is tracked as S360 KPI — early adoption avoids future compliance pressure
4. Aurora Resiliency fills a critical gap in DK8S's fault injection capabilities

### Important Caveats
- **Aurora does NOT address configuration management** — ConfigGen, ArgoCD, and GitOps workflows remain separate workstreams
- **Custom K8s workloads must be built** — Aurora has no existing Kubernetes operator validation scenarios
- **3-6 month lead time** before meaningful E2E validation is operational

### Recommended Phases
1. Month 1-2: Aurora Bridge for DK8S build pipelines
2. Month 3-5: Custom K8s validation workloads + DIV
3. Month 6-8: Resiliency platform onboarding
4. Month 9-12: Full integration with matrix execution and ICM

### Next Action
Attend Aurora office hours (Thursdays, 10:00 AM PST) and contact compute-aurora-pmdev@microsoft.com for DK8S-specific guidance.

## Team Input Needed
- B'Elanna: Which DK8S pipelines are best candidates for Aurora Bridge pilot?
- Worf: Resiliency testing priorities — which fault scenarios matter most for Defender infrastructure?
- Data: Feasibility of building .NET-based Aurora workloads for Go/Helm operator validation?
