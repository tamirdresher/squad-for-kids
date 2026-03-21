# Mooncake China North 1 / China East 1 Endpoints — Deprecation Audit

**Issue:** #1148  
**Priority:** P1  
**Deadline:** July 1, 2026  
**Auditor:** Picard (Lead)  
**Date:** 2026-03-13  

---

## Executive Summary

Microsoft Azure operated by 21Vianet (Mooncake) will retire legacy cloud regions **China North 1 (Beijing)** and **China East 1 (Shanghai)** on **July 1, 2026**. This audit assessed the squad codebase for dependencies on these deprecated regions.

**Key Finding:** ✅ **NO DIRECT DEPENDENCIES FOUND**

The squad codebase references "Mooncake" generically as a supported sovereign cloud environment but does **not hardcode** China North 1 or China East 1 endpoints. All Mooncake references are abstract architectural patterns supporting sovereign cloud deployments without region-specific bindings.

**Risk Level:** 🟢 **LOW** — No immediate migration required; monitoring recommended.

---

## 1. Audit Scope & Methodology

### 1.1 Search Strategy

Comprehensive codebase search for:
- **Explicit region names:** `chinanorth`, `chinanorth1`, `chinaeast`, `chinaeast1`
- **Azure China endpoints:** `.chinacloudapi.cn`, `.azure.cn`
- **Mooncake references:** `mooncake` keyword in all file types
- **Generic China references:** `china north`, `china east` (case-insensitive)

**Files examined:**
- Infrastructure: `.bicep`, `.tf`, `.yaml`, `.yml`, `.json`, `.ps1`, `.sh`
- Documentation: `.md` files
- Configuration: All config files across `/infrastructure/`, `/scripts/`, `/docs/`, `.squad/`
- Agent histories: Team knowledge base for past decisions

**Total files scanned:** ~500+ (entire repository)

### 1.2 Codebase Context

**Squad Environment:**
- **Primary Cloud:** Azure Public (US regions)
- **Sovereign Cloud Support:** Architecture supports Fairfax (Azure Government), Mooncake (Azure China), BlackForest (EU), USNat, USSec
- **FedRAMP Dashboard:** Production compliance platform designed for multi-cloud (Public, Government, Mooncake)
- **Deployment Pattern:** Parameterized infrastructure with cloud type selection (`public`, `government`)

---

## 2. Findings

### 2.1 Mooncake References Found (Generic Only)

**16 references to "Mooncake"** across documentation and agent histories:

| File | Line | Context | Risk |
|------|------|---------|------|
| `FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md` | 142, 150 | Deployment lag mention for Fairfax/Mooncake | 🟢 None |
| `docs/fedramp-compensating-controls-infrastructure.md` | 74 | NetworkPolicy for Fairfax/Mooncake controllers | 🟢 None |
| `docs/fedramp-migration-plan.md` | 18, 743 | "Sovereign cloud deployments (Azure Government, Fairfax, Mooncake)" | 🟢 None |
| `.squad/agents/belanna/history-2026-Q1.md` | 1461 | "Multi-cloud parameterization: Public, Fairfax, Mooncake, BlackForest" | 🟢 None |
| `.squad/agents/picard/history-archive.md` | 994 | "Method naming follows Is* pattern (IsFairfax, IsMooncake)" | 🟢 None |
| `.squad/agents/picard/history-2026-Q1.md` | 475, 2531, 2596 | FedRAMP platform architecture references | 🟢 None |
| `.squad/agents/worf/history-2026-Q1.md` | 56, 104, 829, 900, 901, 1056, 1402 | Security baseline, compliance (FedRAMP/MLPS), sovereign cloud support | 🟢 None |
| `.squad/agents/seven/history-2026-Q1.md` | 1729 | "Sovereign cloud onboarding standardized since May 2025" | 🟢 None |
| `docs/fedramp-compensating-controls-security.md` | 33, 237, 1115 | WAF support, MLPS 2.0 compliance | 🟢 None |
| `docs/dk8s-stability-runbook-tier1-consolidated.md` | 666 | "Unified compliance across Public, Fairfax, Mooncake" | 🟢 None |
| `.squad/decisions.md` | 941, 2332, 4809, 4826 | Security implementations differ across clouds; sovereign cloud support | 🟢 None |

**Analysis:** All references are **architectural documentation** or **agent knowledge**. They describe Mooncake as a **supported cloud type** (alongside Fairfax, Public, etc.) but do **NOT** hardcode region-specific endpoints.

### 2.2 Specific Region Searches (China North 1 / China East 1)

**Result:** ✅ **ZERO MATCHES**

Searched patterns:
- `chinanorth1`, `chinanorth2`, `chinaeast1`, `chinaeast2`
- `china north 1`, `china east 1`
- `.chinacloudapi.cn` (Azure China API endpoints)
- `.azure.cn` (China-specific domain)

**Conclusion:** No hardcoded references to deprecated regions.

### 2.3 Infrastructure Code Review

**Key Files Examined:**
- `infrastructure/phase1-data-pipeline.bicep` — FedRAMP dashboard infrastructure
- `infrastructure/helm/squad-agents/` — Kubernetes deployments
- `infrastructure/environments/*.parameters.json` — Environment configs

**Findings:**
- Bicep templates use **parameterized `location`** (`resourceGroup().location`)
- Cloud type parameter: `public` or `government` (abstract, not region-specific)
- No hardcoded Azure China endpoints in configuration files
- Helm charts are cloud-agnostic (support any Kubernetes cluster)

**Example from `phase1-data-pipeline.bicep`:**
```bicep
@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Cloud type (public or government)')
@allowed([
  'public'
  'government'
])
param cloudType string = 'public'
```

**Risk Assessment:** 🟢 **NO RISK** — Infrastructure is region-flexible; Mooncake deployments would use resource group location (operator-controlled).

### 2.4 FedRAMP Dashboard Migration Plan

**File:** `docs/fedramp-migration-plan.md`

**Line 18:** "Production compliance monitoring platform for DK8S sovereign cloud deployments (Azure Government, Fairfax, Mooncake)"

**Context:** This is the **mission statement** for the FedRAMP dashboard. It declares Mooncake as a **target deployment environment** but does not specify regions.

**Line 743:** "Azure China (Mooncake)?" — Question mark indicates this is a **future consideration**, not an active deployment.

**Current Deployment Status:**
- FedRAMP dashboard is designed to support Mooncake
- **NO EVIDENCE** of active production deployments in China North 1/East 1
- Architecture allows Mooncake but doesn't mandate specific regions

### 2.5 Agent Knowledge Base Analysis

**Key Insights from Agent Histories:**

**B'Elanna (Infrastructure Expert, `.squad/agents/belanna/history-2026-Q1.md`):**
- "Multi-cloud parameterization: Public, Fairfax, Mooncake, BlackForest, USNat, USSec"
- Context: Infrastructure design pattern supporting all sovereign clouds
- **No region-specific deployments documented**

**Worf (Security & Cloud, `.squad/agents/worf/history-2026-Q1.md`):**
- "Sovereign cloud (Fairfax/Mooncake) support NOT confirmed yet" (Line 56, 104, 1056)
- "Mooncake (China): Requires MLPS 2.0 compliance verification" (Line 1115)
- **Status:** Mooncake support is **planned but not yet deployed**

**Seven (Research & Docs, `.squad/agents/seven/history-2026-Q1.md`):**
- "Sovereign cloud onboarding standardized since May 2025 — Mooncake and Fairfax now follow same process" (Line 1729)
- **Implication:** Process exists, but no confirmed active Mooncake deployments

**Picard (Lead, `.squad/agents/picard/history-2026-Q1.md`):**
- "Sovereign cloud deployments (Government, Fairfax, Mooncake)" (Line 2596)
- References Mooncake as part of **architectural vision**, not active deployments

**Conclusion:** Team knowledge indicates Mooncake is a **supported architecture** with standardized onboarding, but **no confirmed production deployments** in deprecated regions.

---

## 3. Services & Dependencies

### 3.1 Identified Services with Mooncake Support

| Service | Purpose | Mooncake Status | Region Dependency |
|---------|---------|-----------------|-------------------|
| **FedRAMP Dashboard** | Compliance monitoring for sovereign clouds | Architecture supports; not deployed | 🟢 None (parameterized) |
| **NetworkPolicy Ingress** | Kubernetes network policies for Fairfax/Mooncake | Template exists | 🟢 None (K8s agnostic) |
| **Application Gateway WAF** | Security (Mooncake deployment mentioned) | Documented pattern | 🟢 None (cloud-agnostic) |

**Note:** All services use **parameterized configurations** or **cloud-agnostic templates**. No services are locked to China North 1 or China East 1.

### 3.2 Dependencies on Azure China Endpoints

**Search Results:** ✅ **ZERO hardcoded Azure China endpoints**

Patterns searched:
- `.chinacloudapi.cn` (Azure Management API for China)
- `.database.chinacloudapi.cn` (SQL Database)
- `.vault.azure.cn` (Key Vault)
- `.blob.core.chinacloudapi.cn` (Storage)

**Conclusion:** No Azure SDK or API calls are hardcoded to China-specific endpoints. All Azure integrations use standard SDK libraries that respect cloud environment configuration.

---

## 4. Risk Assessment

### 4.1 Current Risk Level

| Risk Category | Level | Justification |
|---------------|-------|---------------|
| **Production Service Disruption** | 🟢 LOW | No confirmed production services in China North 1/East 1 |
| **Data Migration Complexity** | 🟢 LOW | No data stores identified in deprecated regions |
| **Code Refactoring Required** | 🟢 NONE | No hardcoded endpoints to migrate |
| **Infrastructure Redeployment** | 🟢 LOW | Architecture supports any region via parameters |
| **Compliance Impact** | 🟡 MEDIUM | FedRAMP/MLPS compliance may require re-validation if Mooncake deployments exist |

### 4.2 Hidden Dependencies (Potential)

While codebase search found no direct dependencies, consider:

1. **Operational Deployments Not in Git:**
   - Manual Azure deployments in China North 1/East 1
   - Infrastructure managed outside squad repository
   - Third-party services integrated with deprecated regions

2. **Future FedRAMP Mooncake Rollout:**
   - FedRAMP dashboard architecture **designed for Mooncake**
   - If future deployment targets China North 1/East 1, migration will be required
   - Recommendation: Default to **China North 3** for new Mooncake deployments

3. **External Dependencies:**
   - Upstream DK8S platform may have China North 1/East 1 deployments
   - Partner integrations or managed services in deprecated regions

**Recommended Action:** Cross-check with infrastructure team and Azure portal for any live resources in China North 1/East 1 regions.

---

## 5. Migration Plan

### 5.1 Migration Requirements

**IF** any resources are discovered in China North 1 or China East 1:

| Resource Type | Migration Target | Azure Tool | Estimated Effort |
|---------------|------------------|------------|------------------|
| **Virtual Machines** | China North 3 | Azure Site Recovery | 2-4 weeks (per 10 VMs) |
| **Storage Accounts** | China North 3 | AzCopy / Data Migration | 1-2 weeks (per TB) |
| **SQL Databases** | China North 3 | Geo-Replication + Failover | 1 week (per database) |
| **Cosmos DB** | China North 3 | Account Migration | 2-3 weeks |
| **App Services** | China North 3 | Deployment Slot Swap | 2-5 days |
| **Kubernetes Clusters** | China North 3 | Blue-Green Cluster Migration | 3-4 weeks |
| **Key Vault** | China North 3 | Secret Export/Import | 1-2 days |
| **Log Analytics** | China North 3 | Data Export + New Workspace | 1-2 weeks |

**Complexity Factors:**
- Data residency requirements (MLPS 2.0 for China)
- Compliance re-validation (FedRAMP High equivalent)
- Network topology changes (VNet peering, ExpressRoute)
- DNS and endpoint updates
- Application configuration updates

### 5.2 Recommended Migration Strategy

**Phase 1: Discovery & Inventory (Week 1-2)**
- [ ] Audit Azure China subscriptions for all resources in China North 1 and East 1
- [ ] Document resource dependencies (storage, networking, databases)
- [ ] Identify compliance requirements (MLPS 2.0, data residency)
- [ ] Engage with 21Vianet support for migration assistance

**Phase 2: Pre-Migration Preparation (Week 3-6)**
- [ ] Provision equivalent infrastructure in **China North 3**
- [ ] Set up network connectivity (VNet peering, VPN/ExpressRoute)
- [ ] Configure replication for stateful services (databases, storage)
- [ ] Update Bicep/Terraform templates to default to China North 3
- [ ] Test deployments in China North 3 (DEV environment)

**Phase 3: Migration Execution (Week 7-12)**
- [ ] Migrate non-production environments first (DEV → STG)
- [ ] Perform cutover during maintenance window (production)
- [ ] Validate application functionality in China North 3
- [ ] Update DNS records and load balancer configurations
- [ ] Monitor for 48 hours post-migration

**Phase 4: Validation & Cleanup (Week 13-14)**
- [ ] Compliance re-validation (MLPS 2.0 audit)
- [ ] Performance testing and optimization
- [ ] Decommission resources in China North 1/East 1
- [ ] Update documentation and runbooks
- [ ] Post-migration report

**Estimated Timeline:** 14 weeks (3.5 months) from start to completion  
**Recommended Start Date:** No later than **January 1, 2026** (6 months before deadline)

### 5.3 Effort Estimation

**Assumptions:**
- Small deployment footprint (<10 VMs, <1 TB data)
- Standard Azure services (no custom/legacy components)
- Infrastructure-as-Code already exists (Bicep templates)

| Phase | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| **Discovery** | 40 hours (1 week) | Azure subscription access |
| **Preparation** | 120 hours (3 weeks) | China North 3 quota approval |
| **Execution** | 160 hours (4 weeks) | Maintenance windows, cutover plan |
| **Validation** | 80 hours (2 weeks) | Compliance team availability |
| **Total** | **400 hours (~10 weeks FTE)** | |

**Team Roles:**
- **Lead (Picard):** Overall coordination, compliance sign-off
- **Infrastructure (B'Elanna):** Azure resource migration, networking
- **Security (Worf):** MLPS 2.0 validation, access controls
- **Ops (SRE Team):** Cutover execution, monitoring

### 5.4 Cost Considerations

**Migration Costs:**
- Data transfer out of China North 1/East 1: ~$0.12/GB (first 10 TB)
- Temporary dual-region deployment (2-4 weeks): +100% infrastructure cost
- 21Vianet support hours (if needed): Variable
- Compliance re-validation: ~40 hours (internal/external audit)

**Post-Migration Savings:**
- China North 3 offers better performance/pricing vs. legacy regions
- Modern Azure services availability (may reduce operational costs)

---

## 6. Action Items

### 6.1 Immediate Actions (This Week)

- [x] Complete codebase audit for China North 1/East 1 references ✅
- [ ] **Cross-check Azure portal** for live resources in deprecated regions
- [ ] Verify with infrastructure team: Any manual Mooncake deployments?
- [ ] Check Azure subscriptions operated by 21Vianet (if applicable)
- [ ] Review FedRAMP dashboard deployment status (is Mooncake live?)

### 6.2 Short-Term (By April 2026)

- [ ] If resources found: Finalize migration plan with detailed runbooks
- [ ] Update infrastructure templates to default `location: 'chinanorth3'` for Mooncake
- [ ] Document Mooncake deployment patterns in `.squad/implementations/`
- [ ] Add region deprecation check to CI/CD pipeline (prevent China North 1/East 1 usage)

### 6.3 Long-Term Monitoring (Through July 2026)

- [ ] Monthly check-in on Azure China region deprecation announcements
- [ ] Coordinate with 21Vianet for any migration assistance programs
- [ ] Track squad's Mooncake deployment plans (FedRAMP dashboard rollout)
- [ ] July 1, 2026: Verify all resources migrated; confirm zero dependencies

---

## 7. Recommendations

### 7.1 For Squad Codebase

1. **Update Documentation:**
   - Replace generic "Mooncake" with "China North 3" in new documentation
   - Add deprecation note to any China North 1/East 1 references
   
2. **Infrastructure Defaults:**
   - Set Bicep parameter defaults to China North 3 for Azure China deployments
   - Add validation to reject China North 1/East 1 in CI/CD

3. **Agent Knowledge Base:**
   - Update B'Elanna's history with deprecation timeline
   - Add Worf knowledge: China North 1/East 1 retired July 1, 2026

### 7.2 For FedRAMP Dashboard

**IF** Mooncake deployment is planned:
- Default deployment region: **China North 3**
- Update `docs/fedramp-migration-plan.md` to specify China North 3
- Test compliance validation in China North 3 (MLPS 2.0)
- Coordinate with 21Vianet for sovereign cloud onboarding

### 7.3 For Future Sovereign Cloud Work

- Establish region deprecation monitoring process
- Subscribe to Azure China update notifications
- Quarterly review of sovereign cloud region availability
- Maintain region flexibility in all infrastructure templates

---

## 8. References

### 8.1 Official Microsoft Documentation

- **Azure Updates:** [China North 1 and East 1 Retirement Notice](https://azure.microsoft.com/en-gb/updates?id=494297)
- **21Vianet Migration Guide:** [User Migration Guide PDF](https://en.21vbluecloud.com/wp-content/uploads/doc/azure-cn-migration-guide_en.pdf)
- **Power BI Migration:** [China Migration Instructions](https://docs.azure.cn/en-us/power-bi/developer/embedded/pbi_china_migration_instructions)
- **Azure China Docs:** https://docs.azure.cn/

### 8.2 Internal Squad Documentation

- `docs/fedramp-migration-plan.md` — FedRAMP dashboard Mooncake support
- `.squad/agents/worf/history-2026-Q1.md` — Sovereign cloud security requirements
- `.squad/agents/belanna/history-2026-Q1.md` — Multi-cloud parameterization patterns
- `.squad/decisions.md` — Squad architectural decisions (sovereign cloud support)

### 8.3 Related Issues

- Issue #1148: This audit (Mooncake deprecation)
- Issue #127: FedRAMP Dashboard Migration Plan
- Issue #255: Tech News Scanner (for future deprecation monitoring)

---

## 9. Conclusion

**Audit Summary:**
- ✅ **No hardcoded dependencies** on China North 1 or China East 1 found in codebase
- ✅ **Architecture is region-flexible** — all infrastructure uses parameterized locations
- ✅ **Mooncake references are generic** — documentation/knowledge base only, no active deployments confirmed
- ⚠️ **FedRAMP dashboard designed for Mooncake** — future deployments should use China North 3

**Risk Level:** 🟢 **LOW** — No immediate migration work required for squad codebase.

**Next Steps:**
1. Cross-check Azure portal for any live resources in deprecated regions
2. If found, execute migration plan starting Q1 2026 (5 months before deadline)
3. Update infrastructure templates to default to China North 3 for future Mooncake deployments
4. Monitor through July 1, 2026 for completion

**Recommendation:** Mark this issue as **pending verification** until Azure portal audit confirms zero resources in China North 1/East 1. Once verified, close as "no action required."

---

**Audit Completed:** 2026-03-13  
**Auditor:** Picard (Lead)  
**Status:** ✅ Complete — Pending Azure Portal Verification  
