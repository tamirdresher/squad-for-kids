# Aurora E2E Validation Experiment: DK8S Cluster Provisioning

**Author:** B'Elanna Torres, Infrastructure Expert  
**Date:** 2026-03-07  
**Issue:** #4 — DK8S stability & config management improvements + Aurora research  
**Branch:** `squad/4-stability-aurora`  
**Status:** Proposed Experiment Design

---

## Executive Summary

This document designs a controlled experiment to evaluate Aurora as an E2E validation layer for DK8S cluster provisioning. The goal is to answer Tamir's question: **"Can we do an experiment on a DK8S component? How about cluster provisioning? Will this make component changes and rollout slower?"**

**Short answer:** No, it won't — if we start in monitoring-only mode. Aurora Bridge runs out-of-band from the provisioning pipeline, consuming results via metadata and manifests. Zero pipeline changes, zero added latency. We observe first, gate later.

---

## Part 1: Current Cluster Provisioning Pipeline

### 1.1 Step-by-Step Flow

DK8S cluster provisioning is a multi-stage orchestration, not a single "AKS create" call. The flow, confirmed via WorkIQ (DK8S Bot messages, support threads, Sev2 incidents):

```
┌─────────────────────────────────────────────────────────────────────┐
│  STAGE 1: Inventory & Config Generation                              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ PR to Infra.K8s.Clusters adds cluster to inventory          │    │
│  │ → ConfigGen expands: ClustersInventory.json + base values   │    │
│  │ → Produces: RolloutSpec.<ENV>.<REGION>.<CLUSTER>.json       │    │
│  │ → Per-cluster manifests: helm-prd-ame-eus2-1234-values.yaml │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                         [hours delay]                                 │
│                              ▼                                       │
│  STAGE 2: Pipeline Creation (Automated)                              │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Product Catalog API creates cluster-specific ADO pipeline   │    │
│  │ → Assigns permissions, ServiceTree metadata                 │    │
│  │ → DK8S Bot: "Cluster provisioning pipeline created!"        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                         [minutes]                                    │
│                              ▼                                       │
│  STAGE 3: Preflight Checks                                           │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Validate: parameters, subscription readiness                │    │
│  │ Check: RP registrations (Microsoft.Security, .Network)      │    │
│  │ Check: Feature flags (AllowServiceEndpointNetworkIdentifier)│    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  STAGE 4: EV2 Rollout — AKS + Azure Resources                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ EV2 drives ARM/AKS RP calls under managed identities       │    │
│  │ → Create AKS managed cluster                                │    │
│  │ → Create node pools (VMSS) — system + user pools            │    │
│  │ → Configure networking, identities, ACR access, RBAC        │    │
│  │ → Apply Azure policies, DDoS plans                          │    │
│  │ Template source: WDATP.Infra.System.Cluster/cg/GoTemplates │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                         [10-30 min]                                  │
│                              ▼                                       │
│  STAGE 5: Platform Bring-Up (Post-AKS)                               │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ ArgoCD bootstrap                                             │    │
│  │ Geneva Actions (monitoring/logging)                          │    │
│  │ cert-manager                                                 │    │
│  │ Prometheus / OpenTelemetry                                   │    │
│  │ Policy agents                                                │    │
│  │ DK8S platform components via app-of-apps                     │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                         [10-20 min]                                  │
│                              ▼                                       │
│  STAGE 6: Validation & Health Checks                                 │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ Register cluster in DK8S portals                             │    │
│  │ Enable health monitors                                       │    │
│  │ Validate workload deployability                              │    │
│  │ DK8S Cluster Health Validator runs                           │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Current Timing Baselines

| Phase | Estimated Duration | Source |
|-------|-------------------|--------|
| Inventory PR → ConfigGen expansion | Hours (async, depends on CI) | WorkIQ: support thread re: missing rollout specs |
| Pipeline creation + trigger | Minutes | WorkIQ: DK8S Bot timestamps |
| Preflight checks | Minutes | WorkIQ: pipeline failure timings |
| EV2 → AKS + resources | 10–30 minutes | Inferred from AKS RP create times + ARM deployments |
| Platform bring-up (ArgoCD + components) | 10–20 minutes | Inferred from component deployment stages |
| Validation + health checks | 5–10 minutes | DK8S Cluster Health Validator document |
| **Total end-to-end** | **~45–90 minutes** (excluding inventory delay) | Composite estimate |

**Note:** No formally published SLA exists for DK8S cluster provisioning (confirmed via WorkIQ). The automation itself is fast; most delays come from subscription readiness or post-provisioning failures.

### 1.3 Known Failure Modes

From the stability analysis (`dk8s-stability-analysis.md`) and WorkIQ research:

| # | Failure Mode | Phase | Frequency | Impact |
|---|-------------|-------|-----------|--------|
| 1 | Missing Azure RP registration (`Microsoft.Security`, `.Network`) | Preflight | Common on new subscriptions | Hard pipeline failure |
| 2 | Missing subscription feature flags (`AllowServiceEndpointNetworkIdentifier`) | Preflight | Occasional | Hard failure; manual `az feature register` required |
| 3 | VM allocation failures (`AllocationFailed`, `OverconstrainedZonalAllocationRequest`) | EV2/AKS | During capacity crunches | Cluster stuck in failed state |
| 4 | Quota exhaustion | EV2/AKS | During scale events | Stalled provisioning |
| 5 | ImagePullBackOff post-provisioning | Platform bring-up | Occasional | Cluster exists but pods can't pull images; ACR auth failure |
| 6 | KeyVault / SecretProviderClass misconfiguration | Platform bring-up | On new clusters | Pods stuck in ContainerCreating |
| 7 | "Provisioned but unhealthy" management clusters | Validation | Periodic | Infra components (Prometheus, Geneva) unhealthy despite cluster existing |
| 8 | NAT Gateway datapath degradation | Post-provisioning | ~Monthly | Image pull failures, probe failures, secret mount failures |
| 9 | DNS + Istio ztunnel cascading failure | Post-provisioning | Quarterly | Observability blackout during incidents |

### 1.4 Current Validation Gaps

What is **NOT tested today** during or after cluster provisioning:

| Gap | Description | Risk |
|-----|-------------|------|
| **No E2E provisioning validation** | No automated test runs a "provision → deploy workload → validate" cycle | Clusters pass pipeline checks but fail under real workloads |
| **No cross-stage correlation** | Each stage validates independently; no single view of "is this cluster actually healthy?" | "Provisioned but unhealthy" incidents go undetected |
| **No regression baseline** | No comparison between "last successful provision" and "this provision" | Slow drift in provisioning quality goes unnoticed |
| **No failure categorization** | Failures are manually triaged; no automated classification (infra vs. config vs. platform) | Same failure modes recur without systematic fix |
| **No sovereign cloud differentiation** | Same validation for all clouds despite different constraints | Sovereign-specific failures caught only in production |
| **Missing IDP feedback loop** | EV2 step failures don't report back to IDP/ConfigGen | Teams deploy with broken configs repeatedly |

---

## Part 2: Experiment Design

### 2.1 Objective

Validate whether Aurora can provide meaningful E2E validation of DK8S cluster provisioning by:
1. Observing the provisioning pipeline without impacting it (monitoring-only)
2. Capturing provisioning metrics that don't exist today
3. Building a regression baseline for provisioning quality
4. Evaluating Aurora's fitness as a gating mechanism for future use

### 2.2 Scope

| Dimension | Selection | Rationale |
|-----------|-----------|-----------|
| **Clusters** | 2–3 non-production clusters | Minimize blast radius; non-prod has regular provisioning activity |
| **Environments** | DEV + TEST (not PPE/PROD) | Start where failures are acceptable |
| **Regions** | East US 2 + Sweden Central | Two regions cover both Americas and EMEA; avoid sovereign clouds initially |
| **Tenant** | Single tenant (team's own) | Avoid cross-team coordination overhead |
| **Pipeline** | `WDATP.Infra.System.ClusterProvisioning` pipelines | This is the provisioning pipeline source |

**Candidate clusters for experiment:**

| Cluster | Env | Region | Why |
|---------|-----|--------|-----|
| `mps-dk8s-dev-eus2-*` | DEV | East US 2 | Frequent provisioning; team-owned |
| `mps-dk8s-tst-sec-*` | TEST | Sweden Central | EMEA coverage; test environment |
| `mps-dk8s-dev-sec-*` | DEV | Sweden Central | Secondary DEV; lower risk |

### 2.3 Aurora Integration Point

Aurora Bridge integrates **after the provisioning pipeline exists**, not inside it. The integration model:

```
┌──────────────────────────────────────────────────────────────────┐
│  EXISTING PIPELINE (unchanged)                                    │
│                                                                    │
│  Inventory → ConfigGen → Pipeline → EV2 → AKS → Components       │
│                                                                    │
│                    ┌──── Aurora Bridge ────┐                       │
│                    │  (observes pipeline)   │                      │
│                    │  via metadata/manifest │                      │
│                    └───────────────────────┘                       │
│                              │                                     │
│                              ▼                                     │
│                    ┌──── Aurora Platform ──┐                       │
│                    │  Telemetry & analysis  │                      │
│                    │  Regression detection  │                      │
│                    │  IcM (disabled phase 1)│                      │
│                    └───────────────────────┘                       │
└──────────────────────────────────────────────────────────────────┘
```

**How Aurora Bridge connects (documented in Aurora onboarding):**

1. **No pipeline YAML changes required** — Aurora consumes pipeline metadata externally
2. **Configuration is via Aurora Workload Manifest** (`ADO_Dev.json`) containing:
   - ADO organization and project
   - Pipeline definition ID
   - Branch reference
   - IcM creation flags (disabled for experiment)
3. **Aurora Workload App** (service principal) granted read access to the provisioning pipeline
4. **Results ingestion**: Aurora reads native ADO test results or structured `aurora-results.json`

### 2.4 Experiment Phases

#### Phase 1: Monitoring-Only (Weeks 1–4)

| Setting | Value |
|---------|-------|
| `WorkloadCreateIcM` | `false` |
| `ScenarioCreateIcM` | `false` |
| Mode | Observe only — no gating, no incidents |
| Duration | 2–4 weeks |

**What we measure:**
- Provisioning success/failure rate per cluster
- Time-to-provision (total and per-stage)
- Failure categorization (infra / config / platform / external)
- Regression detection (did provisioning get slower or more failure-prone?)

**Exit criteria to proceed to Phase 2:**
- Aurora successfully observes ≥10 provisioning runs
- Telemetry data is accurate and actionable
- No pipeline disruption observed
- Team reviews Aurora dashboard and confirms value

#### Phase 2: Enhanced Validation (Weeks 5–8)

Add structured result output from provisioning pipeline:
- Emit `aurora-results.json` with per-stage timings
- Add post-provisioning health check results to Aurora telemetry
- Compare provisioning quality across regions/environments

**Exit criteria to proceed to Phase 3:**
- Regression baseline established (≥20 provisioning runs)
- At least 1 failure correctly detected and categorized by Aurora
- Team confident in data quality

#### Phase 3: Gating Evaluation (Weeks 9–12)

| Setting | Value |
|---------|-------|
| `WorkloadCreateIcM` | `true` (DEV only) |
| `ScenarioCreateIcM` | `true` (DEV only) |
| Mode | Gate on DEV clusters; monitor on TEST |

**Decision point:** Based on Phase 2 data, decide whether to:
- Expand gating to TEST environment
- Add more clusters
- Extend to component deployment pipelines (beyond provisioning)
- Or abandon if value not demonstrated

### 2.5 Metrics to Capture

| Metric | How Captured | Baseline (Today) | Target |
|--------|-------------|-------------------|--------|
| Provisioning success rate | Aurora + pipeline results | Unknown (no tracking) | ≥95% for non-prod |
| Mean time to provision | Aurora stage telemetry | ~45–90 min (estimated) | Track P50/P95 |
| Failure categorization accuracy | Aurora vs. manual triage | Manual only | ≥80% auto-classified |
| Regression detection rate | Aurora baseline comparison | None | Detect within 1 run |
| Time to detect "unhealthy but provisioned" | Aurora health checks | Hours/days (manual) | <15 minutes |
| Aurora observation latency | Aurora telemetry timestamps | N/A | <5 min after pipeline completion |

### 2.6 Comparison: Before Aurora vs. With Aurora

| Aspect | Before Aurora | With Aurora (Monitoring) | With Aurora (Gating) |
|--------|-------------|-------------------------|---------------------|
| Provisioning visibility | Pipeline pass/fail only | Per-stage telemetry, trends, regressions | Same + enforcement |
| Failure triage | Manual, per-incident | Auto-categorized, historical | Same + IcM auto-creation |
| Regression detection | None | Baseline comparison per run | Same + blocking on regression |
| Time overhead | 0 | 0 (out-of-band) | +5–10 min (validation gate) |
| Pipeline changes | N/A | None (manifest-only) | Minimal (result emission) |

---

## Part 3: Rollout Impact Assessment

### 3.1 Will Aurora Add Latency to the Provisioning Pipeline?

**Phase 1 (Monitoring-only): ZERO impact.**

Aurora Bridge operates out-of-band:
- It does not inject steps into the pipeline
- It does not modify pipeline execution
- It consumes pipeline metadata and results after the fact
- No pipeline YAML changes required

This is explicitly documented in Aurora Bridge guides and confirmed by the Cloud Talks Aurora introduction: Aurora Bridge "meets you where you are" and connects to existing pipelines without requiring rewrites.

### 3.2 Phase 2 (Enhanced Validation): Minimal Impact

Adding `aurora-results.json` emission requires a small pipeline change:
- A post-provisioning step writes structured results
- Estimated addition: **<2 minutes** to pipeline execution
- This is a new step, not a modification of existing steps

### 3.3 Phase 3 (Gating): Controlled Impact

When Aurora is used as a gate:
- The pipeline waits for Aurora validation before proceeding
- Estimated additional time: **5–10 minutes** for validation checks
- This is comparable to existing health check duration (5–10 min)
- Impact on total provisioning time: ~10–15% increase (from ~60 min to ~65–70 min)

### 3.4 Strategies to Minimize Impact

| Strategy | Description | Impact Reduction |
|----------|-------------|-----------------|
| **Async validation** | Provisioning continues while Aurora validates in background; only blocks if Aurora detects a critical failure | Near-zero latency for passing runs |
| **Matrix subset execution** | Don't run full validation matrix for every cluster; validate critical paths only | 50–70% reduction in validation time |
| **Caching and baseline comparison** | Compare against last known-good provisioning; only deep-validate if delta detected | Skip validation entirely for identical configs |
| **Parallel health checks** | Run Aurora health checks concurrently with existing Stage 6 validation | Zero additional latency (overlapped) |
| **Fast-fail on known patterns** | Pre-classify failure signatures; skip full validation when failure pattern is recognized | Faster feedback on known-bad states |

### 3.5 Impact on Component Changes and Rollouts

**Will Aurora make component changes and rollout slower?**

| Scenario | Impact |
|----------|--------|
| **Component code changes** (no provisioning) | **Zero impact** — Aurora experiment is scoped to provisioning pipeline only |
| **Component Helm chart changes** | **Zero impact** — ArgoCD syncs are not in scope for this experiment |
| **New cluster provisioning** (Phase 1) | **Zero impact** — monitoring-only mode |
| **New cluster provisioning** (Phase 3, gating) | **+5–10 min** — validation gate before cluster handoff |
| **Cluster upgrades** | **Not in scope** — experiment covers new provisioning only |

### 3.6 Recommendation

**Start monitoring-only. Graduate to gating after baseline is established.**

1. **Weeks 1–4:** Monitoring-only (zero risk, zero latency)
2. **Weeks 5–8:** Enhanced telemetry (minimal change, <2 min addition)
3. **Weeks 9–12:** Gating on DEV only (5–10 min, DEV clusters only)
4. **Week 12+:** Decision point — expand, modify, or abandon

This phased approach means:
- No impact on production provisioning at any point
- No impact on component rollouts at any point
- Data-driven decision before any gating is enabled

---

## Part 4: Implementation Checklist

### Phase 0: Preparation (Week 0)

- [ ] **Identify Aurora team contact / office hours**
  - Aurora team under Cloud+AI Platform → Azure Core → One Fleet Platform
  - Cloud Talks Aurora sessions available as reference (Instance 1 & 2)
  - Estimated effort: 1 day
  
- [ ] **Select 2–3 non-prod clusters for experiment**
  - Review `ClustersInventory_DK8S.json` for DEV/TEST clusters in EUS2 + SEC
  - Confirm cluster provisioning frequency (need ≥2 provisions/month per cluster)
  - Estimated effort: 0.5 day

- [ ] **Get Aurora Workload App access**
  - Grant Aurora service principal read access to provisioning pipelines
  - Coordinate with pipeline owners (WDATP.Infra.System.ClusterProvisioning)
  - Estimated effort: 1–2 days (includes approval)

### Phase 1: Monitoring-Only (Weeks 1–4)

- [ ] **Author Aurora Workload Manifest (`ADO_Dev.json`)**
  - Define workload: DK8S Cluster Provisioning
  - Set ADO org, project, pipeline definition IDs
  - Set `WorkloadCreateIcM = false`, `ScenarioCreateIcM = false`
  - Estimated effort: 1 day

- [ ] **Submit manifest PR to Aurora**
  - Aurora onboarding is config-driven and code-reviewed
  - Follow Aurora Bridge onboarding guide
  - Estimated effort: 0.5 day + review cycle

- [ ] **Run monitoring-only for 2–4 weeks**
  - Verify Aurora receives pipeline telemetry
  - Check Aurora dashboard for provisioning data
  - Document any data quality issues
  - Estimated effort: 0.5 day/week for monitoring

- [ ] **Analyze Phase 1 results**
  - Are provisioning metrics accurate?
  - Does Aurora detect failures?
  - Is the data actionable?
  - Estimated effort: 1 day

### Phase 2: Enhanced Validation (Weeks 5–8)

- [ ] **Define provisioning scenario in Aurora format**
  - Map provisioning stages to Aurora scenarios
  - Define success/failure criteria per stage
  - Estimated effort: 2 days

- [ ] **Add structured result emission to pipeline**
  - Post-provisioning step writes `aurora-results.json`
  - Include per-stage timings, health check results
  - Estimated effort: 2–3 days (pipeline change + testing)

- [ ] **Establish regression baseline**
  - Minimum 20 provisioning runs with full telemetry
  - Document P50/P95 provisioning times per region
  - Estimated effort: 2–4 weeks (ongoing)

### Phase 3: Gating Evaluation (Weeks 9–12)

- [ ] **Enable IcM creation for DEV clusters**
  - Update manifest: `WorkloadCreateIcM = true` for DEV only
  - Monitor IcM quality and noise ratio
  - Estimated effort: 0.5 day

- [ ] **Evaluate gating value**
  - Would gating have caught any real failures?
  - What is the false positive rate?
  - Is the 5–10 min validation time acceptable?
  - Estimated effort: 1 day

- [ ] **Decision: expand, modify, or abandon**
  - Documented decision with data
  - If expanding: plan for TEST → PPE → PROD rollout
  - Estimated effort: 0.5 day

### Timeline Summary

| Week | Phase | Key Activities | Effort |
|------|-------|---------------|--------|
| 0 | Prep | Contacts, cluster selection, access | 3 days |
| 1–2 | Phase 1a | Manifest authoring, onboarding | 2 days |
| 3–4 | Phase 1b | Monitoring, data validation | 1 day/week |
| 5–6 | Phase 2a | Scenario definition, pipeline changes | 4 days |
| 7–8 | Phase 2b | Baseline collection, analysis | 1 day/week |
| 9–10 | Phase 3a | Gating enablement (DEV) | 1 day |
| 11–12 | Phase 3b | Evaluation, decision | 2 days |
| **Total** | | | **~15–20 person-days over 12 weeks** |

---

## Appendix A: Key Repositories

| Repository | Role in Experiment |
|-----------|-------------------|
| `Infra.K8s.Clusters` | Cluster inventory — identifies experiment targets |
| `WDATP.Infra.System.ClusterProvisioning` | Provisioning pipelines — Aurora Bridge target |
| `WDATP.Infra.System.Cluster` | EV2 templates — understand provisioning stages |
| `WDATP.Infra.System.PipelineTemplates` | Pipeline templates — shared build infrastructure |
| `Wcd.Infra.ConfigurationGeneration` | ConfigGen — generates per-cluster configs consumed by provisioning |

## Appendix B: Aurora Bridge Integration References

| Resource | URL / Location |
|----------|---------------|
| Aurora Bridge Onboarding Guide | eng.ms → Cloud+AI Platform → Azure Core → One Fleet → Aurora → Onboarding |
| Build Pipeline Workload | `31-authorbuildpipelineworkload` |
| Release Pipeline Workload | `32-authorreleasepipelineworkload` |
| Cloud Talks Aurora Introduction | Instance 1 & 2 recordings (March 2026) |
| Aurora Bridge Results Schema | `aurora-results.json` specification |

## Appendix C: Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Aurora team bandwidth for onboarding | Medium | Blocks experiment start | Early engagement; attend office hours |
| Insufficient provisioning events during experiment window | Medium | Inadequate baseline data | Extend Phase 1 if needed; trigger manual provisions |
| Aurora data quality issues | Low | Misleading metrics | Validate against known pipeline results in Phase 1 |
| Pipeline owner resistance to result emission changes (Phase 2) | Medium | Blocks enhanced validation | Keep Phase 1 change-free to demonstrate value first |
| Aurora platform outage during experiment | Low | Monitoring gap | Aurora is monitoring-only; pipeline unaffected |
| False positive gating blocks provisioning (Phase 3) | Medium | Delayed provisioning | Phase 3 is DEV-only; can disable gating instantly |

---

*This experiment is designed to answer a specific question with minimal risk: can Aurora provide value for cluster provisioning validation without slowing down the process? The phased approach ensures we learn before we commit.*
