# Aurora Adoption Plan & Scenario Definition Framework for DK8S

**Author:** Picard (Lead) — Issue #4
**Date:** 2026-03-07
**Sources:** Seven's Aurora research, B'Elanna's stability analysis, WorkIQ intelligence (Cloud Talks, Runtime Platform reviews, cluster automation brainstorms), Aurora onboarding docs, DK8S platform knowledge base
**Requested by:** Tamir Dresher
**Classification:** Internal — not for external distribution

---

## Table of Contents

1. [Part 1: Scenario Definition Framework](#part-1-scenario-definition-framework)
2. [Part 2: Adoption Plan](#part-2-adoption-plan)
3. [Part 3: Cluster Provisioning Experiment](#part-3-cluster-provisioning-experiment)
4. [Part 4: Rollout Impact Analysis](#part-4-rollout-impact-analysis)

---

## Part 1: Scenario Definition Framework

### 1.1 What Is an Aurora Scenario?

An Aurora **scenario** is a discrete, repeatable validation unit that exercises a specific Azure service capability under production-representative conditions. Scenarios are grouped into **workloads**, which represent end-to-end customer experiences composed of multiple scenarios.

**Hierarchy:**
```
Workload (e.g., "DK8S Cluster Lifecycle")
  └── Scenario (e.g., "Cluster Provisioning — East US 2")
        └── Steps (e.g., Create cluster → Validate node pools → Deploy smoke test → Teardown)
              └── Assertions (e.g., provisioning < 25min, all nodes Ready, DNS resolves)
```

### 1.2 Scenario Structure

Every Aurora scenario requires these components:

| Component | Description | DK8S Example |
|-----------|-------------|--------------|
| **Scenario Name** | Unique identifier within the workload | `dk8s-cluster-provision-eus2` |
| **Workload Definition** | Parent workload grouping | `DK8S Cluster Lifecycle` |
| **Target Environment** | Region, subscription, tenant | East US 2, DK8S-Test subscription, AME tenant |
| **Execution Type** | Ad-hoc, scheduled, DIV-triggered, matrix | Scheduled (nightly) + DIV-triggered on EV2 rollout |
| **Setup Steps** | Pre-scenario infrastructure preparation | Ensure quota, validate prerequisites, snapshot baseline metrics |
| **Execution Steps** | The actual operations under test | Trigger cluster provisioning pipeline, wait for completion |
| **Validation Assertions** | Success/failure criteria with thresholds | Provisioning time < 25min, all node pools Ready, kube-system pods healthy |
| **Teardown Steps** | Cleanup to prevent resource leaks | Delete test cluster, release quota reservation |
| **Telemetry Configuration** | What metrics to emit to Kusto/Geneva | Duration, success/failure, error codes, regional latency |
| **ICM Configuration** | When to auto-create incidents | On failure: Sev3 to DK8S on-call; on regression: Sev2 |
| **Matrix Parameters** | Dimensions for cross-environment execution | Regions: [EUS2, WEU, SCUS], K8s versions: [1.29, 1.30], Node pools: [3, 5] |

### 1.3 Inputs Aurora Needs

**Workload Definition (onboarding manifest):**
- Service Tree ID (DK8S service registration)
- Workload owner contact (DK8S platform team DL)
- Repository location (external repo for workload code)
- Authentication: two service principals (Infra SP + Workload SP) via Key Vault certificates
- Subscription(s) for workload execution
- Fairbanks workload registration

**Success Criteria:**
- Quantitative thresholds (latency P50/P95/P99, availability %, error rate)
- Comparison baselines (historical performance, cross-region deltas)
- Regression detection sensitivity (% deviation from baseline to flag)

**Matrix Parameters:**
- Regional spread (which Azure regions to validate)
- SKU/configuration variants (node pool sizes, K8s versions, network policies)
- Timing (execution frequency, DIV trigger points)

### 1.4 Mapping DK8S Operations to Aurora Scenarios

#### Cluster Provisioning

| Scenario | What It Tests | Steps | Success Criteria |
|----------|--------------|-------|-----------------|
| `provision-new-cluster` | End-to-end cluster creation | Trigger EV2 → validate ARM deployment → check node readiness → verify kube-system | Completion < 25min, all nodes Ready |
| `provision-scale-nodepool` | Node pool scaling | Add node pool → validate VMSS scale-out → check scheduling | Scale-out < 10min, new nodes accept pods |
| `provision-k8s-upgrade` | Kubernetes version upgrade | Trigger AKS upgrade → validate node drain → check workload continuity | Upgrade < 45min, zero pod disruptions for PDBs |
| `provision-regional-variance` | Cross-region provisioning consistency | Matrix: same cluster spec across 5 regions | P95 variance < 20% across regions |

#### Component Deployment

| Scenario | What It Tests | Steps | Success Criteria |
|----------|--------------|-------|-----------------|
| `deploy-helm-rollout` | Helm chart deployment via ArgoCD | Push chart update → ArgoCD sync → validate pod health | Sync < 5min, all replicas Ready, no crash loops |
| `deploy-argocd-sync` | ArgoCD sync reliability | Trigger sync → validate resource creation → check rollback capability | Sync success, clean rollback on failure |
| `deploy-component-upgrade` | Component version upgrade | Push new image → validate rolling update → check service continuity | Zero-downtime upgrade, health checks pass |

#### ConfigGen Validation

| Scenario | What It Tests | Steps | Success Criteria |
|----------|--------------|-------|-----------------|
| `config-generation` | ConfigGen manifest generation | Run ConfigGen with test inputs → validate output against schema | Valid manifests, no schema violations |
| `config-nuget-upgrade` | NuGet package compatibility | Upgrade ConfigGen NuGet → rebuild → validate output unchanged | Build success, output diff within tolerance |
| `config-breaking-change` | Breaking change detection | Apply known breaking change → validate build failure is clear | Clear error message, documented migration path |

#### Networking

| Scenario | What It Tests | Steps | Success Criteria |
|----------|--------------|-------|-----------------|
| `net-nat-gateway-failover` | NAT Gateway zonal resilience | Simulate AZ failure → validate outbound connectivity via alternate NAT | Failover < 2min, no image pull failures |
| `net-dns-resolution` | DNS resolution under stress | Inject DNS latency → validate service discovery continues | Resolution < 500ms P99, no cascading failures |
| `net-ingress-health` | Ingress routing reliability | Deploy service → validate external DNS → check 200 responses | Zero 504s, DNS propagation < 3min |

#### Istio Mesh Operations

| Scenario | What It Tests | Steps | Success Criteria |
|----------|--------------|-------|-----------------|
| `istio-injection-rollout` | Sidecar/ztunnel injection | Enable mesh for namespace → validate mTLS → check pod communication | All pods enrolled, zero mTLS handshake failures |
| `istio-rollback` | Mesh rollback safety | Disable mesh for namespace → validate traffic continues | Zero dropped connections during rollback |
| `istio-infra-isolation` | Infrastructure component isolation | Verify Geneva, CoreDNS excluded from mesh → validate independence | Infra components unaffected by mesh failures |

### 1.5 DK8S Aurora Scenario Template

```yaml
# Template: DK8S Aurora Scenario Definition
# Copy and fill for each new scenario

scenario:
  name: "dk8s-<operation>-<variant>"
  workload: "DK8S <Workload Group>"
  owner: "dk8s-platform@microsoft.com"
  version: "1.0"

environment:
  regions: ["eastus2", "westeurope"]      # Matrix dimension
  subscriptions: ["dk8s-aurora-test"]
  k8s_versions: ["1.29", "1.30"]          # Matrix dimension
  auth:
    infra_sp: "kv://dk8s-aurora-kv/infra-cert"
    workload_sp: "kv://dk8s-aurora-kv/workload-cert"

execution:
  type: "scheduled"                        # scheduled | div-triggered | ad-hoc
  frequency: "daily"                       # For scheduled
  div_trigger: "post-canary"               # For DIV: post-canary | post-pilot
  timeout_minutes: 60
  retry_on_infra_failure: true
  max_retries: 2

setup:
  - name: "Validate prerequisites"
    action: "check-quota"
    params:
      min_cores: 48
      min_ips: 10
  - name: "Snapshot baseline"
    action: "capture-metrics"
    params:
      metrics: ["provision_duration_p50", "node_ready_time"]

steps:
  - name: "Execute operation"
    action: "<operation-specific>"
    params: {}
    timeout_minutes: 30
  - name: "Validate result"
    action: "assert-conditions"
    assertions:
      - metric: "duration_seconds"
        operator: "lt"
        threshold: 1500
      - metric: "success"
        operator: "eq"
        threshold: true

teardown:
  - name: "Cleanup resources"
    action: "delete-test-resources"
    params:
      force: true

telemetry:
  kusto_db: "AuroraDK8S"
  kusto_table: "ScenarioResults"
  geneva_account: "dk8saurora"
  emit_metrics:
    - "scenario.duration"
    - "scenario.success"
    - "scenario.error_code"

alerting:
  icm:
    enabled: true
    on_failure:
      severity: 3
      team: "DK8S Platform"
    on_regression:
      severity: 2
      team: "DK8S Platform"
      threshold_pct: 15  # Trigger if metric regresses >15% from baseline

comparison:
  baseline: "rolling_7day"
  regression_sensitivity: "medium"        # low | medium | high
  cross_region_variance_max_pct: 20
```

---

## Part 2: Adoption Plan

### Phase 0: Cluster Provisioning Experiment Design (Now — 2 weeks)

**Objective:** Design and scope a concrete experiment that validates cluster provisioning through Aurora without impacting current deployment velocity.

| Item | Detail |
|------|--------|
| **Scenarios** | `provision-new-cluster`, `provision-regional-variance` |
| **Owner** | DK8S Platform Team (Picard as experiment lead) |
| **Success Metric** | Experiment design approved, Aurora subscription provisioned, initial scenario code committed |
| **Rollout Impact** | None — design phase only |
| **Deliverables** | Experiment design doc, Aurora subscription request, service principal setup, repo scaffold |

**Actions:**
1. Attend Aurora office hours (Thursdays, 10:00 AM PST) with experiment proposal
2. Request Aurora subscription and service principals from compute-aurora-pmdev@microsoft.com
3. Create `dk8s-aurora-workloads` external repo for workload code
4. Define cluster provisioning scenario using template above
5. Identify 2-3 test regions (recommend: East US 2, West Europe, South Central US)

---

### Phase 1: Aurora Bridge Integration (Month 1-2)

**Objective:** Connect existing DK8S OneBranch pipelines to Aurora Bridge for monitoring and historical analysis without requiring test rewrites.

| Item | Detail |
|------|--------|
| **Scenarios** | Existing pipeline pass/fail as Aurora signals; `provision-new-cluster` running nightly |
| **Owner** | DK8S Platform Team + CI/CD leads |
| **Success Metric** | ≥3 DK8S pipelines reporting to Aurora; results visible in Fairbanks; first cluster provisioning scenario executing nightly in 1 region |
| **Rollout Impact** | **Zero** — monitoring-only mode. No deployment gates. Aurora observes; does not block. |
| **Deliverables** | Aurora Bridge configuration for OneBranch pipelines, Fairbanks dashboard, first nightly cluster provisioning run |

**Why Bridge first:**
- No test rewriting required — reuse existing ADO Build/Release pipelines
- Provides immediate value: structured monitoring, alerting, historical trending
- Low risk: Aurora Bridge is additive (observes pipeline results, doesn't modify them)
- Builds organizational familiarity before custom workloads

**Risks:**
- Bridge only captures pipeline-level pass/fail, not deep infrastructure validation
- Limited to what existing tests cover (which is a known gap per B'Elanna's analysis)

---

### Phase 2: Custom K8s Validation Workloads + DIV (Month 3-5)

**Objective:** Develop DK8S-specific Aurora workloads using the .NET SDK in an external repo. Begin deployment-integrated validation (DIV) in Canary.

| Item | Detail |
|------|--------|
| **Scenarios** | All cluster provisioning scenarios + `deploy-helm-rollout`, `deploy-argocd-sync`, `config-generation` |
| **Owner** | DK8S Platform Team (workload development), Aurora PM team (onboarding support) |
| **Success Metric** | ≥5 custom workloads executing; DIV validating Canary deployments; first regression caught pre-production |
| **Rollout Impact** | **Low** — DIV runs in parallel with existing Canary deployment. Initially monitoring-only; gating enabled only after 30-day burn-in with zero false positives. |
| **Deliverables** | External workload repo with CI/CD, DIV integration with EV2 Canary ring, Kusto dashboards for scenario metrics |

**Key decisions for this phase:**
- Workload SDK is .NET — DK8S team primarily uses Go. Need to decide: (a) .NET wrapper calling Go/kubectl, or (b) pure .NET scenarios using K8s client library
- DIV trigger point: post-Canary is recommended (validates after Canary deployment, before Pilot promotion)
- Recommendation: Start with (b) pure .NET scenarios — simpler, better Aurora SDK integration

---

### Phase 3: Resiliency Platform — Fault Injection & AZ-Down (Month 6-8)

**Objective:** Onboard DK8S to Aurora Resiliency Platform for structured fault injection and zone-down validation.

| Item | Detail |
|------|--------|
| **Scenarios** | `net-nat-gateway-failover`, `net-dns-resolution`, `istio-injection-rollout`, `istio-infra-isolation`, node failure, AZ-down drills |
| **Owner** | DK8S Platform Team + Azure Chaos Studio team |
| **Success Metric** | Completed first AZ-down drill; identified ≥2 previously unknown failure modes; NAT Gateway failover validated |
| **Rollout Impact** | **Moderate** — Resiliency drills run in dedicated test environments, not production. Production AZ-down participation is opt-in and scheduled. |
| **Deliverables** | Chaos Studio integration, fault injection scenarios, AZ-down drill participation, resiliency report |

**Why this matters for DK8S specifically:**
- NAT Gateway zonal failures are the #1 recurring stability issue (monthly, per B'Elanna's analysis)
- No current structured resiliency testing exists — all fault discovery is reactive (via IcM)
- Istio ztunnel interactions under failure conditions are poorly understood
- This phase directly addresses Tamir's concern about platform stability

---

### Phase 4: Full Matrix Execution + ICM Integration (Month 9-12)

**Objective:** Achieve full Aurora integration with matrix execution across all DK8S environments, automated ICM, and historical regression trending.

| Item | Detail |
|------|--------|
| **Scenarios** | Full scenario catalog (15-20 scenarios), matrix across all production regions, sovereign cloud variants |
| **Owner** | DK8S Platform Team (operational ownership transferred from experiment to BAU) |
| **Success Metric** | All DK8S deployments validated by Aurora; mean time to detect regressions reduced by 50%; ICM auto-creation for all scenario failures |
| **Rollout Impact** | **Managed** — gating mode enabled for critical scenarios (provisioning, networking). Non-critical scenarios remain monitoring-only. Parallel execution keeps latency impact < 15min per deployment. |
| **Deliverables** | Full Fairbanks dashboard, ICM integration, regression trending, S360 DIV compliance, operational runbook |

---

## Part 3: Cluster Provisioning Experiment

### 3.1 Why Cluster Provisioning Is the Right First Candidate

Tamir asked: *"How about cluster provisioning?"* — it's the right call. Here's why:

1. **High blast radius, low frequency** — Cluster provisioning failures are catastrophic but infrequent, making them ideal for validation (high value per test run, affordable test cost)

2. **Clear success criteria** — Provisioning either works or it doesn't. Metrics are unambiguous: duration, node count, pod health. No subjective "is the app working?" questions.

3. **Existing pain points** — WorkIQ surfaced discussions (Runtime Platform Weekly, cluster automation brainstorms) where provisioning failures, silent failures from invalid cluster names, and pipeline health gaps were explicitly called out. This experiment directly addresses those gaps.

4. **Regional variance is a known unknown** — DK8S operates across multiple Azure regions. We don't currently have systematic data on provisioning time variance by region. This is exactly what Aurora matrix execution is built for.

5. **Independent of application logic** — Cluster provisioning validation doesn't depend on any specific DK8S component team's code. The platform team can own the entire experiment end-to-end without cross-team coordination overhead.

6. **Aligns with S360 trajectory** — Aurora DIV is tracked as an S360 KPI. Starting with cluster provisioning positions DK8S for early compliance before it potentially becomes mandatory.

### 3.2 What the Experiment Would Test

**Primary metrics:**

| Metric | Measurement | Current Baseline | Target |
|--------|------------|-----------------|--------|
| Provisioning duration | Time from EV2 trigger to all nodes Ready | Unknown (no systematic data) | Establish baseline, then < 25min P95 |
| Provisioning success rate | % of provisioning attempts that succeed without retry | Estimated 90-95% (anecdotal) | Measure accurately; target > 98% |
| Regional variance | Std dev of provisioning time across regions | Unknown | < 20% coefficient of variation |
| Node readiness time | Time from VMSS provisioning to kubelet Ready | Unknown | Establish baseline |
| kube-system health | Time until all kube-system pods are Running | Unknown | < 5min post-node-ready |
| Post-provision DNS | DNS resolution working within cluster | Not tested | 100% resolution within 2min |

**Secondary metrics:**

| Metric | Purpose |
|--------|---------|
| Quota consumption | Detect regional quota constraints before they cause failures |
| ARM API latency | Identify slow ARM responses per region |
| AKS control plane responsiveness | API server latency post-provision |
| Certificate provisioning | Time for workload identity cert issuance |

### 3.3 Impact on Rollout Speed

**Tamir's question: "Will this make component changes and rollout slower?"**

**Short answer: No — if we structure it correctly.**

**Monitoring-only mode (Phase 0-1):**
- Aurora runs *alongside* the deployment, not *gating* it
- Zero impact on deployment speed
- Provisioning scenarios run on a nightly schedule against test clusters, not production deployments
- Bridge monitors existing pipeline results without adding steps

**Additive validation mode (Phase 2):**
- DIV validates *after* Canary deployment completes, *before* Pilot promotion decision
- Canary → [Aurora validates, ~15-20min] → Pilot
- This adds 15-20min between Canary and Pilot rings
- **But:** DK8S already has a mandatory bake time between rings. Aurora validation can run *during* the existing bake period, adding zero net latency
- Key insight: if bake time is currently 30min+, Aurora validation completes within it

**Gating mode (Phase 4):**
- Only for critical scenarios (provisioning, networking)
- Adds a hard gate: deployment cannot proceed past Canary if Aurora detects regression
- Estimated latency addition: 15-30min per deployment (depending on scenario count)
- **Mitigation:** parallel scenario execution across the matrix reduces wall-clock time
- **Override:** emergency deployments can bypass Aurora gates with approval (similar to existing EV2 overrides)

### 3.4 Experiment Structure: Additive vs. Gating

```
┌─────────────────────────────────────────────────────────────────┐
│ Phase 0-1: MONITORING ONLY (No rollout impact)                  │
│                                                                 │
│  Production Pipeline ──────────────────────────► Deploy          │
│       │                                                         │
│       └──── Aurora Bridge (observes) ──► Fairbanks Dashboard    │
│                                                                 │
│  Nightly: Aurora Scenario ──► Test Cluster ──► Metrics to Kusto │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Phase 2-3: PARALLEL VALIDATION (Minimal rollout impact)         │
│                                                                 │
│  EV2 Canary Deploy ──────┬──────────────► Bake Timer (30min)    │
│                          │                     │                │
│                          └── Aurora DIV ───────┘                │
│                              (runs in parallel)                 │
│                                    │                            │
│                              Results to Fairbanks               │
│                              (advisory, not blocking)           │
│                                    │                            │
│                          ──────────┴──────────► Pilot Deploy    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Phase 4: GATED VALIDATION (Controlled rollout impact)           │
│                                                                 │
│  EV2 Canary Deploy ──► Aurora DIV (parallel scenarios) ──┐      │
│                                                          │      │
│                        ┌─────── PASS ────────────────────┤      │
│                        │                                 │      │
│                        ▼                        FAIL ────┤      │
│                  Pilot Deploy                            │      │
│                                               Block + ICM       │
│                                               (Sev2 auto)       │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5 Risk Assessment and Rollback Plan

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Aurora subscription provisioning delayed | Medium | Delays Phase 0 by 1-2 weeks | Start request immediately; escalate via Aurora office hours |
| Custom workload development takes longer than expected | Medium | Delays Phase 2 | Start with simplest scenario (provision + check nodes); iterate |
| False positives in DIV block legitimate deployments | Low (in monitoring mode) | High (if gating enabled prematurely) | 30-day burn-in requirement before gating; tunable regression thresholds |
| Aurora platform outage blocks DK8S deployments | Low | High (if gating) | Automatic bypass: if Aurora is unreachable, deploy proceeds (fail-open) |
| Test cluster provisioning consumes quota | Medium | Could impact production if shared quota | Dedicated Aurora subscription with isolated quota |
| .NET SDK learning curve for Go-native team | Medium | Slower workload development | Pair with Aurora PM team; consider Copilot/Workload Foundry for scaffolding |

**Rollback plan:**
- Phase 0-1 (monitoring only): Disable Aurora Bridge integration in pipeline config. Zero production impact.
- Phase 2-3 (parallel validation): Remove DIV trigger from EV2 configuration. Aurora stops running, deployment continues as before.
- Phase 4 (gating): Switch gate from "blocking" to "advisory" via Fairbanks configuration. Deployment proceeds regardless of Aurora result.
- Full rollback: Decommission Aurora subscription, remove service principals, archive workload repo. Estimated effort: 1 day.

---

## Part 4: Rollout Impact Analysis

### 4.1 Will Aurora Make Changes Slower?

**Under monitoring-only mode:** No. Zero impact. Aurora observes and reports.

**Under parallel validation mode:** Negligible. Aurora validation runs during existing bake time between deployment rings. If bake time exceeds Aurora scenario duration (which it should, since DK8S bake periods are typically 30min+), there is no additional latency.

**Under gating mode:** Yes, but controllably. Expected additional latency:

| Scenario Count | Parallel Execution | Estimated Wall Clock |
|---------------|-------------------|---------------------|
| 1-3 scenarios | All parallel | 10-15 min |
| 5-8 scenarios | 3 parallel streams | 15-25 min |
| 10-15 scenarios | 5 parallel streams | 20-30 min |
| 15-20 scenarios | 5 parallel streams | 25-35 min |

**Key principle:** Only critical scenarios should gate deployments. Advisory scenarios run in parallel but don't block.

### 4.2 Monitoring-Only vs. Gating Mode

| Dimension | Monitoring-Only | Gating |
|-----------|----------------|--------|
| Deployment speed impact | None | +15-30min |
| Regression detection | Post-hoc (detected after deployment) | Pre-promotion (caught before broader rollout) |
| False positive risk | No impact (informational) | Can block legitimate deployments |
| Operational overhead | Low (review dashboards) | Medium (respond to gates, manage overrides) |
| Recommended for | All scenarios initially; non-critical scenarios permanently | Critical scenarios only, after 30-day burn-in |

### 4.3 Parallel Execution Strategies

1. **Scenario parallelism:** Run independent scenarios simultaneously (e.g., DNS validation + provisioning time check + kube-system health in parallel)
2. **Regional parallelism:** Execute the same scenario across multiple regions simultaneously via Aurora matrix execution
3. **Pipeline parallelism:** Aurora validation runs in a separate pipeline stage that overlaps with existing bake/soak steps
4. **Async result collection:** Fire-and-forget scenario execution with async result polling — don't block pipeline waiting for Aurora

### 4.4 How Other Teams Handled the Speed Tradeoff

**Azure Storage (multi-year Aurora adoption):**
- Started with monitoring-only for 6+ months
- Gradually enabled gating for mission-critical workloads
- Key learning: invest heavily in reducing scenario execution time before enabling gates
- Result: "Fewer customer-visible incidents" (from Cloud Talks presentation) — the speed tradeoff was worth it

**Azure Databricks (large-scale compute validation):**
- Uses Aurora for rollout regression detection at massive scale
- Adopted a "validate the platform, not every deployment" approach — run comprehensive scenarios nightly, run lightweight smoke tests per deployment
- Key learning: separate deep validation (nightly, 1-2 hours) from deployment validation (per-rollout, 10-15 minutes)
- Result: residency/recovery drills caught issues that production monitoring missed

**Recommended approach for DK8S:**
- Follow the Databricks model: **deep nightly validation + lightweight per-deployment checks**
- Nightly: full matrix execution (all regions, all scenarios, 1-2 hours)
- Per-deployment: 3-5 critical smoke scenarios (provisioning health, DNS, pod scheduling), 10-15 minutes, monitoring-only for first 30 days
- This minimizes per-deployment latency while maximizing regression detection coverage

---

## Summary Decision

**Recommendation: Proceed with the cluster provisioning experiment.**

Aurora addresses a real, documented gap in DK8S validation maturity. The experiment is structured to be **additive** — it will not slow down deployments in Phase 0-1, and the transition to gating mode in Phase 4 is controlled, reversible, and only for critical scenarios.

The cluster provisioning experiment directly answers Tamir's question and provides the data we need to make an informed decision about broader adoption.

**Immediate next steps:**
1. Request Aurora subscription and attend office hours
2. Scaffold `dk8s-aurora-workloads` repo
3. Implement `provision-new-cluster` scenario using the template in §1.5
4. Configure Aurora Bridge for one DK8S OneBranch pipeline
5. Run first nightly provisioning validation within 2 weeks

---

## Appendix: Key Contacts and Resources

| Resource | Link/Contact |
|----------|-------------|
| Aurora Onboarding | https://aka.ms/AuroraResiliency/Onboarding |
| Fairbanks Portal | https://aka.ms/fairbanks |
| Aurora Office Hours | Thursdays, 10:00 AM PST |
| Aurora PM Team | compute-aurora-pmdev@microsoft.com |
| Aurora API (Swagger) | https://auroraapiprod.azureaurora.net/api/swagger/ui |
| Cloud Talks Recordings | https://aka.ms/CloudTalks/Recordings |
| Aurora Users Support | Teams channel |
| Related DK8S Analysis | dk8s-stability-analysis.md (B'Elanna, this branch) |
| Prior Aurora Research | Seven's research (commit 54951ab) |
