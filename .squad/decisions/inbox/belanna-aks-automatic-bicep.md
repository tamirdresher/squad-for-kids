# Decision: AKS Automatic with Bicep for Squad Infrastructure

**Date:** 2026-07-16  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #1149  
**PR:** #1183  
**Status:** Proposed  

## Context

Squad AI system requires a Kubernetes cluster for production deployment with the following requirements:
- Event-driven autoscaling (KEDA) for Ralph instances based on queue depth
- Automatic node scaling based on workload
- Container registry integration for Squad images
- Security hardening (AAD RBAC, managed identities)
- Minimal operational overhead

## Decision

**Use AKS Automatic mode instead of standard AKS**, provisioned via **Bicep** (not Terraform).

## Rationale

### Why AKS Automatic over Standard AKS?

1. **Built-in KEDA**: KEDA is pre-installed and managed by the platform
   - No manual Helm chart installation
   - No version upgrade management
   - Guaranteed compatibility with AKS version

2. **Optimized Auto-scaling Defaults**:
   - Intelligent scale-down timing (10-minute delays)
   - Pre-configured thresholds tuned for real-world workloads
   - Reduced configuration surface area

3. **Security by Default**:
   - Azure RBAC enabled automatically
   - Local accounts disabled (AAD-only)
   - Network policy enforcement
   - Azure Policy integration

4. **Simplified Operations**:
   - Fewer configuration knobs to manage
   - Automatic system pool management
   - Platform-managed add-ons

### Why Bicep over Terraform?

1. **Repository Consistency**: 
   - Existing infrastructure uses Bicep (`phase1-data-pipeline.bicep`, `phase4-*.bicep`)
   - Team already familiar with Bicep syntax

2. **Azure-Native Tooling**:
   - First-class support for new Azure features (AKS Automatic launched recently)
   - Better Azure CLI integration
   - Simpler syntax for Azure-only deployments

3. **Type Safety**:
   - Strong typing with IntelliSense in VS Code
   - Parameter validation at compile time
   - Better error messages than ARM JSON

## Implementation Details

### Components Provisioned

- **AKS Cluster**: SKU `Automatic`, Tier `Standard`, Kubernetes 1.29
- **Node Pools**: 
  - System (2-5 nodes, Standard_D4s_v5) - system workloads
  - Workload (1-10 nodes, Standard_D4s_v5) - Squad services
- **Azure Container Registry**: Standard SKU with managed identity integration
- **Virtual Network**: 10.240.0.0/16 with dedicated AKS and ACR subnets
- **Log Analytics**: 30-day retention for container insights

### Deployment Automation

- Bash script (`deploy-aks-automatic.sh`) for Linux/macOS/WSL
- PowerShell script (`deploy-aks-automatic.ps1`) for Windows
- Both handle: resource group creation, deployment, credential fetching

### Cost Profile

**Dev Environment (default)**:
- Min nodes: 3 (2 system + 1 workload)
- Max nodes: 15 (5 system + 10 workload)
- Estimated cost: ~$350-$1200/month depending on scale

**Cost Optimization**:
- Use reserved instances for predictable base load
- Set aggressive scale-down thresholds in dev
- 30-day Log Analytics retention (adjustable)

## Alternatives Considered

1. **Standard AKS + Manual KEDA**:
   - ❌ More operational overhead (Helm upgrades, version compatibility)
   - ❌ Additional failure modes (KEDA pod crashes, Helm repo issues)
   - ✅ More configuration flexibility
   - **Decision**: Not worth the flexibility gain for Squad's use case

2. **Terraform**:
   - ✅ Cloud-agnostic (could move to GKE/EKS easier)
   - ❌ Repository already uses Bicep (mixing IaC tools adds complexity)
   - ❌ Terraform state management overhead
   - **Decision**: Bicep alignment with existing infrastructure outweighs portability

3. **Azure Container Apps**:
   - ✅ Simpler than Kubernetes (no kubectl, no Helm)
   - ❌ Less control over networking and node configuration
   - ❌ Squad already has K8s manifests (infrastructure/k8s/)
   - **Decision**: Squad needs Kubernetes-level control for custom deployments

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| AKS Automatic is newer than standard AKS | AKS Automatic is GA (General Availability), not preview |
| KEDA version locked to platform | Platform ensures compatibility; auto-upgrades with AKS |
| Higher cost than minimal AKS setup | Auto-scaling configured to scale down aggressively in dev |
| Team unfamiliarity with Bicep | Documentation provided; syntax simpler than ARM JSON |

## Verification Steps

1. Deploy to dev environment: `./deploy-aks-automatic.sh dev eastus`
2. Verify KEDA: `kubectl get pods -n kube-system | grep keda`
3. Deploy sample Squad workload
4. Trigger KEDA scale event (queue depth > 5)
5. Observe auto-scaling behavior

## References

- [AKS Automatic Documentation](https://learn.microsoft.com/en-us/azure/aks/intro-aks-automatic)
- [KEDA Documentation](https://keda.sh/)
- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- Repository: `infrastructure/README-AKS-AUTOMATIC.md`

## Impacts

- **Agents Affected**: All (Squad workloads will run on this cluster)
- **Infrastructure**: New Azure resource group (`squad-aks-dev-rg`)
- **CI/CD**: Future step — update deployment pipelines to target AKS
- **Cost**: New monthly Azure spend (see Cost Profile above)

## Follow-up Tasks

- [ ] Deploy to dev environment and verify
- [ ] Update CI/CD pipelines to build/push images to ACR
- [ ] Create Kubernetes manifests for Squad components (Ralph, Scribe, etc.)
- [ ] Set up KEDA ScaledObjects for Ralph queue-based autoscaling
- [ ] Configure Log Analytics alerts for cluster health
- [ ] Document kubectl access for squad members
