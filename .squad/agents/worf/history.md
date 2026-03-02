# Worf — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Security & Cloud
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Morpheus (The Matrix) to Worf (Star Trek TNG/Voyager)

## Learnings

<!-- Append learnings below -->

### 2026-03-02: IDK8S Infrastructure Security Deep-Dive

**Context:** Conducted comprehensive security analysis of idk8s-infrastructure (Celestial Kubernetes Platform) for Identity/Entra division.

**Key Security Discoveries:**

1. **Authentication Architecture:**
   - Dual auth: Entra ID + dSTS for S2S (EV2 → Management Plane)
   - MISE middleware provides unified authentication abstraction
   - Certificate-based S2S auth with X.509 client certificates
   - Evolution from AAD Pod Identity → Workload Identity Federation

2. **Secrets Management:**
   - **dSMS (Distributed Secret Management Service)**: Automated certificate provisioning and rotation
   - **Azure KeyVault**: Application secrets, TLS certificates (manual rotation risk)
   - **DsmsBootstrapNodeService**: DaemonSet-based cert bootstrap on all nodes
   - **CSI Driver Pattern**: KeyVault secrets synced to pods as mounted volumes

3. **Authorization Model:**
   - **TenantAuthorizationPolicy**: Enforces deployment identity isolation (ObjectId validation)
   - **Per-tenant ServiceProfile.json**: DeploymentIdentities, DeploymentSecurityGroupId
   - **Multi-layer RBAC**: Management Plane + Kubernetes + Azure RBAC + OPA/Rego policies
   - **Namespace isolation**: Each scale unit = dedicated namespace with resource quotas

4. **Identity Management:**
   - **IdentityManager + IdentityGroupManager** components in ResourceProvider
   - **User-Assigned Managed Identity (UAMI)** per deployment unit
   - **Identity Groups** for aggregated RBAC assignments
   - **Azure RBAC scoping**: KeyVault Secrets User, Storage Blob Data Reader per UAMI

5. **Network Security:**
   - **Cluster type segregation**: generic, dpx, gateway, mp (Management Plane)
   - **WireServer File Proxy (ADR-0011)**: Mediated IMDS access for security
   - **Traffic Manager**: Public-facing global load balancer (requires WAF recommendation)
   - **Private Endpoints**: Expected for KeyVault, Storage, ACR (not confirmed in code search)

6. **Certificate Lifecycle:**
   - **dSMS**: Automated rotation for S2S auth certificates
   - **KeyVault TLS certs**: Manual rotation (compliance risk identified)
   - **Certificate monitoring**: Geneva/Azure Monitor for expiration tracking
   - **Recommendation**: Implement cert-manager for Kubernetes-native automation

7. **Multi-Cloud Security:**
   - **Public, Fairfax (Gov), Mooncake (China), BlackForest/BLEU (EU), USNat, USSec**
   - **Cloud-specific requirements**: FedRAMP High (Fairfax), MLPS (Mooncake), GDPR (EU)
   - **Security configuration differences**: Separate identity authorities, certificate CAs, network controls per cloud
   - **Compliance challenge**: No single security baseline across clouds

**Critical Findings:**

- **Dual auth complexity**: Entra ID + dSTS increases attack surface
- **Manual cert rotation**: KeyVault TLS certs risk service outages if expired
- **Traffic Manager exposure**: Public-facing requires robust app-layer auth + WAF
- **Cross-cloud drift**: Security implementations vary by cloud (compliance risk)

**Key Recommendations:**

1. **HIGH**: Accelerate migration to dSTS-only (deprecate Entra ID for S2S)
2. **HIGH**: Automate KeyVault certificate lifecycle (cert-manager, ACME integration)
3. **HIGH**: Mandate WAF for Traffic Manager endpoints
4. **HIGH**: Standardize cross-cloud security baseline with automated compliance validation
5. **MEDIUM**: Migrate to Workload Identity Federation (remove NMI DaemonSets)
6. **MEDIUM**: Implement default-deny Kubernetes Network Policies
7. **MEDIUM**: Enable Private Link for all Azure PaaS services

**Technical Insights:**

- **"Kubernetes for Kubernetes"**: System uses K8s-native patterns (reconciliation, desired-state) implemented in C# without requiring CRDs
- **NuGet integration boundary**: ResourceProvider SDK distributed as NuGet, consumed by Management Plane + CLI
- **Defense in depth**: Multiple isolation layers (namespace, identity, RBAC, network)
- **AOS health system**: Four interconnected services (NHA, NRS, RemediationController, PodHealthCheck) for node lifecycle

**Repository Access Challenge:**

- Could not directly browse idk8s-infrastructure repo via Azure DevOps tools (repo not found in "One" project)
- Azure DevOps code search returned results from other projects (WDATP, Universal Store, RDV, DefenderCommon)
- Analysis based primarily on existing architecture report (idk8s-architecture-report.md)
- Recommendation: Confirm exact Azure DevOps project/repo path for future code-level analysis

**Deliverable:** Comprehensive security deep-dive report (39KB) covering 7 security domains with architecture diagrams and 13 prioritized recommendations.

---

## Cross-Session Learning: Azure DevOps Access Limitations

**Important for all future sessions with this team:**

All five agents (Picard, B'Elanna, Worf, Data, Seven) encountered the same Azure DevOps access limitation during 2026-03-02 idk8s-deep-analysis session:

- **Problem:** Azure DevOps project "One" in msazure organization not found via API tools
- **Impact:** Unable to access idk8s-infrastructure repository directly
- **Root Causes (suspected):**
  1. Project name "One" may be incorrect or abbreviated
  2. Repository may be in different Azure DevOps organization
  3. Repository may be on GitHub, not Azure DevOps
  4. API connection may have incorrect credentials or limited permissions
  
- **Unblocking Strategy:**
  - User must verify and provide: Full Azure DevOps URL `https://dev.azure.com/{org}/{project}/_git/{repo}` OR GitHub org/repo URL
  - Confirm API user has Code (Read) permissions
  - Once unblocked, all agents can re-run their analyses with full repository access

- **What Was Delivered Despite Limitation:**
  - Gap analysis of existing architecture report (Picard)
  - Infrastructure pattern inference (B'Elanna)
  - Security architecture analysis (Worf)
  - Code pattern inference (Data)
  - Repository health assessment (Seven)
  
- **What Will Require Unblocking:**
  - Direct code inspection and metrics
  - CI/CD pipeline analysis
  - Repository activity metrics (commits, branches, PRs)
  - SAST security scanning
  - API contract validation

**Action:** Before spawning agents for future idk8s-infrastructure tasks, verify and document correct repository location.
