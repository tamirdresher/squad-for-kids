# Workload Migration Deep-Dive: Celestial/idk8s Platform

**Requested by:** Tamir Dresher  
**Date:** July 2025  
**Source:** `idk8s-infrastructure` repo — comprehensive code analysis

---

## 1. Overview — What Is Workload Migration in This Context?

### Key Finding: No Dedicated Migration Subsystem Exists (Yet)

After exhaustive code search across the `idk8s-infrastructure` repository, **there is no standalone "Workload Migration Controller" implemented today**. The term "workload migration controller" appears exactly once in the codebase — in the Management Plane tech-debt and vision document (`/docs/management-plane/MP-tech-debt-and-vision.md`) — listed as a **future planned operator/resource provider**:

```
Adding more resource providers (RP)/operators, incl. environments and a coordinated 
release process for them. Examples:
  - Cluster RP - Provision (& delete?) clusters on demand
  - Workload migration controller          ← PLANNED, NOT IMPLEMENTED
  - N+1 controller for managing disruptive cluster upgrades
```

Searches for `WorkloadMigration`, `MigrationController`, `ScaleUnitMigration`, `MoveScaleUnit`, `RelocateScaleUnit`, `DrainScaleUnit`, `CordonCluster`, `Evacuate`, and `Failover` all returned **zero code results**.

### How Migration Works Today: Composition of Primitives

Migration is **not a single operation** but is achieved through the **composition of existing platform primitives**:

1. **Add** a new scale unit on the target cluster (via `ScaleUnitAddService`)
2. **Deploy** the workload release to the new scale unit (via `ScaleUnitDeployReleaseService`)
3. **Shift traffic** at the DNS/Traffic Manager level (manual or via external tooling)
4. **Delete** the old scale unit from the source cluster (via `ScaleUnitDeleteService`)

This is a manual, multi-step orchestration. The planned "Workload Migration Controller" would automate this sequence.

---

## 2. Architecture — How the Platform Is Designed

### Component Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                    API Layer                             │
│  ┌──────────────┐  ┌────────────────────────────────┐   │
│  │ CelestialApi │  │ Ev2DeployScaleUnitController   │   │
│  │  (CLI mode)  │  │     (Generic/EV2 mode)         │   │
│  └──────┬───────┘  └──────────────┬─────────────────┘   │
│         │                         │                      │
│  ┌──────▼─────────────────────────▼─────────────────┐   │
│  │            ResourceProvider (Façade)              │   │
│  │  AddScaleUnit / DeployRelease / GetStatus / Del   │   │
│  └──────┬────────────────────────────────────────────┘   │
│         │                                                │
│  ┌──────▼────────────────────────────────────────────┐   │
│  │      Reconciliation Loop (Spec/Status/Gen)        │   │
│  │  ┌─────────────────┐  ┌────────────────────────┐ │   │
│  │  │ScaleUnitRecon-   │  │DeploymentUnitRecon-    │ │   │
│  │  │ciler             │  │ciler                   │ │   │
│  │  │                  │  │                        │ │   │
│  │  │ • AddScaleUnit   │  │ • CreateDU resources   │ │   │
│  │  │ • DeployRelease  │  │ • UpdateInfra          │ │   │
│  │  │ • ObservedGen++  │  │ • DeployRelease        │ │   │
│  │  └──────┬───────────┘  │ • ObservedGen++        │ │   │
│  │         │              └────────┬───────────────┘ │   │
│  └─────────┼───────────────────────┼─────────────────┘   │
│            │                       │                      │
│  ┌─────────▼───────────────────────▼─────────────────┐   │
│  │            Domain Services                         │   │
│  │  ScaleUnitAddService → ScaleUnitScheduler          │   │
│  │  ScaleUnitDeleteService → ScaleUnitRemovalService  │   │
│  │  ScaleUnitDeployReleaseService                     │   │
│  │  ScaleUnitOnboardService                           │   │
│  └────────────┬──────────────────────────────────────┘   │
│               │                                          │
│  ┌────────────▼──────────────────────────────────────┐   │
│  │    ScaleUnitScheduler (Placement Engine)           │   │
│  │    Filter → Score → Select                         │   │
│  │    ┌─────────────────┐  ┌───────────────────┐     │   │
│  │    │TopologyCluster  │  │MappingBasedFilter │     │   │
│  │    │Filter           │  │(explicit pinning) │     │   │
│  │    └─────────────────┘  └───────────────────┘     │   │
│  │    ┌─────────────────┐                             │   │
│  │    │SpreadScaleUnits │                             │   │
│  │    │Scorer           │                             │   │
│  │    └─────────────────┘                             │   │
│  └────────────────────────────────────────────────────┘   │
│                                                           │
│  ┌────────────────────────────────────────────────────┐   │
│  │    Inventory (Azure Table Storage / ConfigMap)      │   │
│  │    ScaleUnit ↔ DeploymentUnit state persistence     │   │
│  └────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────┘
```

### Two-Level Resource Model

The platform uses a **two-level resource hierarchy** inspired by Kubernetes:

| Level | Resource | Purpose |
|-------|----------|---------|
| **Logical** | `ScaleUnit` | The tenant-facing workload identity (name, region, cloud, env, quotas) |
| **Physical** | `DeploymentUnit` | The concrete instantiation on a specific cluster (cluster binding, namespace, MSI, release) |

A `ScaleUnit` is created by the tenant. The scheduler then produces a `DeploymentUnit` that binds it to a specific cluster. Both follow the **Spec/Status/Generation** reconciliation pattern.

---

## 3. Controller Implementation — Exact Code Paths

### 3.1 The Reconciliation Pattern (Kubernetes-Inspired)

**File:** `/src/csharp/fleet-manager/Inventory/Reconciliation/IReconciler.cs`

```csharp
public interface IReconciler<T> : IReconciler where T : class, IHasMetadata
{
    ValueTask ReconcileAsync(InventoryNamespace ns, InventoryObjectName name, CancellationToken ct);
}
```

**File:** `/src/csharp/fleet-manager/Inventory/Metadata.cs`

```csharp
public sealed record Metadata
{
    public required InventoryNamespace Namespace { get; init; }
    public required InventoryObjectName Name { get; init; }
    public string ResourceVersion { get; init; } = "undefined";  // optimistic concurrency
    public string Generation { get; init; } = "undefined";       // spec change counter
}
```

The `IReconciliationRunner` drives periodic reconciliation rounds, invoking reconcilers for any entity where `Generation != ObservedGeneration`.

### 3.2 ScaleUnitReconciler

**File:** `/src/csharp/fleet-manager/ResourceProvider/Reconciler/ScaleUnitReconciler.cs`

```csharp
internal sealed class ScaleUnitReconciler : IReconciler<ScaleUnit>
{
    public async ValueTask ReconcileAsync(...)
    {
        var scaleUnit = await _inventory.GetAsync(ns, name, ct);
        
        // IDEMPOTENT CHECK: skip if already reconciled
        if (scaleUnit.Metadata.Generation == scaleUnit.Status.ObservedGeneration)
            return;

        // Step 1: Ensure DeploymentUnit exists (calls scheduler if needed)
        await _scaleUnitAddService.AddScaleUnitAsync(scaleUnit.Spec, ct);

        // Step 2: Deploy release if specified
        if (scaleUnit.Spec.ReleaseId is not null && scaleUnit.Spec.HelmReleaseArtifact is not null)
            await _scaleUnitDeployReleaseService.DeployReleaseAsync(scaleUnit.Spec, ct);

        // Step 3: Mark as reconciled
        scaleUnit.Status.ObservedGeneration = scaleUnit.Metadata.Generation;
        await _inventory.UpdateStatusAsync(scaleUnit, ct);
    }
}
```

### 3.3 DeploymentUnitReconciler

**File:** `/src/csharp/fleet-manager/ResourceProvider/Reconciler/DeploymentUnitReconciler.cs`

```csharp
internal sealed class DeploymentUnitReconciler : IReconciler<DeploymentUnit>
{
    public async ValueTask ReconcileAsync(...)
    {
        // Skip if already reconciled
        if (du.Metadata.Generation == du.Status.ObservedGeneration) return;

        // Step 1: Create MSI/namespace resources if not yet assigned
        if (du.Status.AssignedIdentity is null)
        {
            var result = await deploymentUnitCreationService.CreateAsync(du, ct);
            du.Status.AssignedIdentity = result.AssignedIdentity;
        }

        // Step 2: Update infrastructure if spec changed
        string specHash = DeploymentUnitSpecHashUtility.Compute(du.Spec);
        if (du.Status.AppliedSpecHash != specHash)
        {
            await deploymentUnitUpdateService.UpdateInfrastructureResourcesAsync(du, ct);
            du.Status.AppliedSpecHash = specHash;
        }

        // Step 3: Deploy release if target differs from current
        if (du.Spec.ReleaseId is { } targetReleaseId
            && du.Spec.HelmReleaseArtifact is not null
            && targetReleaseId != du.Status.DeployedReleaseId)
        {
            await deploymentUnitUpdateService.UpdateReleaseResourcesAsync(du, ct);
            du.Status.DeployedReleaseId = targetReleaseId;
        }

        // Step 4: Mark as reconciled
        du.Status.ObservedGeneration = du.Metadata.Generation;
        await _inventory.UpdateStatusAsync(du, ct);
    }
}
```

### 3.4 IResourceProvider (Legacy Façade — Marked Obsolete)

**File:** `/src/csharp/fleet-manager/ResourceProvider/ResourceProvider/IResourceProvider.cs`

```csharp
public interface IResourceProvider
{
    [Obsolete("Use IReconciler<ScaleUnit>")]
    ValueTask<AddScaleUnitResult> AddScaleUnitAsync(ScaleUnitSpec spec, CancellationToken ct);

    [Obsolete("Use IReconciler<ScaleUnit>")]
    ValueTask DeployReleaseAsync(ScaleUnitSpec spec, ReleaseId releaseId, 
        HelmReleaseArtifact release, CancellationToken ct);

    ValueTask<ScaleUnitStatusResult> GetScaleUnitStatusAsync(...);
    ValueTask<ScaleUnitDebugInfo> GetScaleUnitDebugInfoAsync(...);
}
```

Note: The `AddScaleUnitAsync` and `DeployReleaseAsync` methods are marked `[Obsolete]` in favor of the reconciler-based approach. The legacy `ResourceProvider` implementation still creates a `ScaleUnit` in inventory and then uses `_reconciliationRunner.WaitForAsync(...)` to block until the reconciliation loop processes it — a synchronous-over-async bridge.

---

## 4. Migration Flow — What Would Happen When a Workload Migrates

Since no automated migration controller exists, here is how migration would be accomplished today using existing primitives, and how the planned controller would likely work:

### 4.1 Manual Migration (Current State)

```
Step 1: ADD new scale unit on target cluster
  ├─ POST /scaleunit (CLI API) or PUT (EV2 API)
  ├─ ScaleUnitAddService.AddScaleUnitAsync()
  │   ├─ ScaleUnitScheduler.ScheduleAsync()
  │   │   ├─ TopologyClusterFilter: region/cloud/env/type match
  │   │   ├─ MappingBasedFilter: explicit cluster pin (if configured)
  │   │   └─ ScoringClusterSelector: SpreadScaleUnitsScorer (fewest DUs wins)
  │   └─ Creates DeploymentUnit in inventory → triggers DU reconciler
  │       ├─ DeploymentUnitCreationService.CreateAsync() → MSI, namespace
  │       └─ DeploymentUnitUpdateService.UpdateInfrastructureResourcesAsync()
  └─ Returns MSI bindings to caller

Step 2: DEPLOY release to new scale unit
  ├─ Updates ScaleUnit.Spec with ReleaseId + HelmReleaseArtifact
  ├─ ScaleUnitReconciler detects Generation change
  │   └─ DeployReleaseService → updates DU.Spec.ReleaseId
  │       └─ DU Reconciler: UpdateReleaseResourcesAsync() → Helm chart deployed
  └─ Workload running on target cluster

Step 3: SHIFT TRAFFIC (external)
  ├─ Azure Traffic Manager / DNS change
  └─ Old scale unit stops receiving traffic

Step 4: DELETE old scale unit
  ├─ DELETE /scaleunit/{name} (CLI API)
  ├─ ScaleUnitDeleteService.DeleteAsync()
  │   ├─ DeploymentUnitRemovalService.RemoveAsync() → cleans k8s resources
  │   └─ ScaleUnitRemovalService.RemoveAsync() → deletes Traffic Manager profiles
  └─ Old deployment cleaned up
```

### 4.2 Planned Automated Migration Controller (Future)

Based on the vision document and the existing architecture patterns, the planned controller would likely:

1. **Accept a migration CRD/spec** — source scale unit, target cluster/region
2. **Create a new DeploymentUnit** on the target cluster with same spec
3. **Wait for reconciliation** — DU fully provisioned (MSI, namespace, infrastructure)
4. **Deploy the same release** — copy ReleaseId + HelmReleaseArtifact
5. **Health check** — verify new deployment is healthy
6. **Traffic switchover** — update Traffic Manager endpoints atomically
7. **Drain old deployment** — wait for in-flight requests to complete
8. **Delete old DeploymentUnit** — clean up source cluster resources
9. **Update ScaleUnit spec** — point to new cluster binding

---

## 5. Placement Logic — How the Scheduler Decides Where to Place Workloads

### 5.1 Architecture: Filter → Score → Select

**File:** `/src/csharp/fleet-manager/ResourceProvider/ScaleUnitScheduler/`

```
IScaleUnitScheduler.ScheduleAsync(ScaleUnitSpec)
    │
    ▼
IClusterSelector.SelectClusterAsync(ScaleUnitSpec)
    │
    ├── IClusterFilter[] (eliminates infeasible clusters)
    │   ├── TopologyClusterFilter   → region, cloud, environment, cluster type
    │   └── MappingBasedFilter      → explicit scale-unit-to-cluster pinning
    │
    ├── IClusterScorer[] (ranks remaining candidates)
    │   └── SpreadScaleUnitsScorer  → fewer DUs on cluster = higher score
    │
    └── ScoringClusterSelector      → normalized scores × weights → best cluster
```

### 5.2 Filters

**TopologyClusterFilter** (`Filters/TopologyClusterFilter.cs`):
```csharp
clusters.RemoveAll(c => c.Region != scaleUnit.Region
                     || c.Cloud != scaleUnit.Cloud
                     || c.Environment != scaleUnit.Environment
                     || c.ClusterType != clusterType);
```

**MappingBasedFilter** (`Filters/MappingBasedFilter.cs`):
- Looks up explicit scale-unit-to-cluster mapping in `ScaleUnitClusterMappingsConfiguration.json`
- Supports exact match and **wildcard patterns** (e.g., `ENTRAGWDP-PUB-CUS-*`)
- **First-match semantics** — specific patterns MUST appear before wildcards
- If a mapping exists, the filter reduces the candidate list to exactly that one cluster

### 5.3 Scorers

**SpreadScaleUnitsScorer** (`Scorers/SpreadScaleUnitsScorer.cs`):
```csharp
// Score = 10000 - (number of DUs on cluster)
// Clusters with fewer deployment units get higher scores
var deploymentUnits = await _deploymentUnitInventory.QueryAsync(
    du => du.Spec.ClusterName == cluster.Name, ct);
return Math.Max(0, BaseScore - deploymentUnits.Count);
```

**ScoringClusterSelector** normalizes all scores to [0, 100] via min-max normalization, applies configurable weights, then picks the cluster with the highest total score.

### 5.4 Explicit Cluster Mappings (The Migration-Relevant Part)

**File:** `/src/csharp/fleet-manager/ResourceProvider/Data/Platform/ScaleUnitClusterMappingsConfiguration.json`

This JSON file contains ~38 explicit mappings like:
```json
{"clusterName": "idk8s-prod-centralus-003", "scaleUnitNamePattern": "ENTRAGWDP-PUB-CUS-PROD-G-101"}
{"clusterName": "idk8s-prod-centralus-002", "scaleUnitNamePattern": "ENTRAGWDP-PUB-CUS-*"}
```

**Migration implication:** To migrate a workload to a different cluster, you would:
1. Update the mapping in `ScaleUnitClusterMappingsConfiguration.json` to point to the new cluster
2. Delete the existing DeploymentUnit
3. Re-add the ScaleUnit → scheduler now assigns it to the new cluster per the updated mapping

---

## 6. State Management — Spec/Status/Generation Pattern

### The Three-Field Reconciliation Contract

Every entity in the inventory follows this pattern:

| Field | Location | Changes When |
|-------|----------|--------------|
| `Generation` | `Metadata.Generation` | Spec is updated (`UpdateAsync`) |
| `ObservedGeneration` | `Status.ObservedGeneration` | Reconciler completes successfully |
| `ResourceVersion` | `Metadata.ResourceVersion` | ANY write (optimistic concurrency) |

**Reconciliation trigger:** `Generation != ObservedGeneration`

### ScaleUnit State

```csharp
public record ScaleUnit : IHasMetadata
{
    public required Metadata Metadata { get; init; }        // Generation tracking
    public required ScaleUnitSpec Spec { get; init; }        // Desired state
    public ScaleUnitStatusInfo Status { get; init; } = new(); // ObservedGeneration only
}
```

### DeploymentUnit State (Richer)

```csharp
public record DeploymentUnit : IHasMetadata
{
    public required Metadata Metadata { get; init; }
    public required DeploymentUnitSpec Spec { get; init; }
    public DeploymentUnitStatus Status { get; init; } = new();
}

public class DeploymentUnitStatus
{
    public string ObservedGeneration { get; set; } = "unset";
    public PlatformAssignedIdentity? AssignedIdentity { get; set; }  // MSI info
    public PlatformAssignedIdentity? AddonsIdentity { get; set; }
    public ReleaseId? DeployedReleaseId { get; set; }                // Last deployed release
    public string? AppliedSpecHash { get; set; }                     // Infra spec hash
}
```

### ScaleUnit Status Enum

```csharp
public enum ScaleUnitStatus
{
    NonExistent,    // Namespace does not exist
    Provisioning,   // Namespace exists, creation in progress
    Provisioned,    // Creation done
    Transitioning,  // DU deployment in progress
    Ready,          // DU deployment succeeded
    Failed          // DU deployment failed
}
```

### Storage Backend

The inventory is backed by **Azure Table Storage** (or Kubernetes ConfigMaps for the SU API's local persistent store). The `IInventory<T>` interface abstracts:
- `CreateAsync` / `UpdateAsync` / `UpdateStatusAsync` / `GetAsync` / `QueryAsync`
- Optimistic concurrency via `ResourceVersion` (ETag)

---

## 7. Multi-Cloud Considerations

### Current Topology

The platform operates across **7 clouds** with 19 tenants. The `ScaleUnitSpec` carries:

```csharp
public required PlatformCloud Cloud { get; init; }          // Public, USGov, China, etc.
public required PlatformEnvironment Environment { get; init; } // Test, DogFood, Prod
public required AzureRegion Region { get; init; }           // centralus, eastus, etc.
```

### Cluster Selection Is Region+Cloud+Env Scoped

The `TopologyClusterFilter` ensures that a scale unit is **only placed on clusters matching its region, cloud, and environment**. This means:

- **Cross-region migration** within the same cloud: Possible by creating a new ScaleUnit with a different region in its spec
- **Cross-cloud migration**: Would require changing the cloud attribute — the scheduler would then only consider clusters in the target cloud
- **Same-region cluster migration**: Change the cluster mapping in `ScaleUnitClusterMappingsConfiguration.json`

### Cluster Orchestrator (ADR-0006)

The platform chose the **Cluster Orchestrator** model over the Region Orchestrator. Each cluster is a separate EV2 stamp. This means:
- EV2 handles rollout ordering across clusters
- Each cluster gets its own deployment step
- Migration between clusters = creating a new deployment step + removing the old one

---

## 8. API Surface — How to Interact with Scale Units

### CLI API (Celestial CLI Mode)

**File:** `/src/csharp/fleet-manager/ManagementPlane/Apis/CLI/CelestialApi.cs`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/scaleunit/{scaleUnitName}?release={id}` | Get status of a scale unit |
| POST | `/scaleunit` | Add a new scale unit (body: `ScaleUnitSpec`) |
| PUT | `/scaleunit/{scaleUnitName}` | Deploy a release (**currently throws `NotImplementedException`**) |
| DELETE | `/scaleunit/{scaleUnitName}` | Delete a scale unit |
| GET | `/scaleunit/{scaleUnitName}/debug` | Get debug info (pod logs) |

> **Note:** The CLI `DeployScaleUnitAsync` endpoint currently throws `NotImplementedException` — deployment via CLI is not yet wired up.

### EV2 API (Generic/Production Mode)

**File:** `/src/csharp/fleet-manager/ManagementPlane/Apis/Ev2/Controllers/Ev2DeployScaleUnitController.cs`

| Method | Endpoint | Description |
|--------|----------|-------------|
| PUT | `/api/v1/Rollout/{rolloutId}/Step/{stepName}/Extension/.../` | Create deployment (fire-and-forget, returns 202) |
| GET | Same path | Get deployment status |
| PUT | `.../validate` | Not supported (405) |
| POST | `.../cancel` | Not supported (405) |
| POST | `.../suspend` | Not supported (405) |
| PUT | `.../resume` | Not supported (405) |

The EV2 API accepts an `Ev2ExtensionPayload<Ev2DeployScaleUnitRequest>` with `ScaleUnitName` and `PathToBuildoutZip`.

### No Migration-Specific API

There is **no migration endpoint** today. No `POST /scaleunit/{name}/migrate`, no `PUT /scaleunit/{name}/move`, etc.

---

## 9. Related Components

### 9.1 ScaleUnitOnboardService

**File:** `/src/csharp/fleet-manager/ResourceProvider/ResourceProvider/ScaleUnitOnboardService.cs`

Before a scale unit can be deployed, it must be **onboarded**:
- Creates identity groups (security groups for MSI)
- Creates deployment certificates via OneCert on all feasible clusters
- These certificates are used by EV2/LSM for authenticated deployments

### 9.2 ScaleUnitDeleteService

**File:** `/src/csharp/fleet-manager/ResourceProvider/ResourceProvider/ScaleUnitDeleteService.cs`

Deletion flow:
1. Find the DeploymentUnit for this ScaleUnit
2. `DeploymentUnitRemovalService.RemoveAsync()` — cleans up Kubernetes resources
3. `ScaleUnitRemovalService.RemoveAsync()` — deletes Azure Traffic Manager profiles

### 9.3 ComponentDeployer

**File:** `/src/csharp/fleet-manager/ComponentDeployer/`

Handles cluster-level infrastructure deployment (not individual workload migration), but it's designed for **future migration to EV2 HTTP extension** (the CLI→HTTP split is already prepared).

### 9.4 ScaleUnitClusterMappingsConfiguration

**File:** `/src/csharp/fleet-manager/ResourceProvider/Data/Platform/ScaleUnitClusterMappingsConfiguration.json`

The critical **static configuration** that pins scale units to clusters. Contains 38 explicit mappings for production workloads. This is where you'd make changes to redirect a workload to a different cluster during migration.

### 9.5 ServiceProfile.json (Per-Tenant Configuration)

**Path pattern:** `/src/csharp/fleet-manager/ResourceProvider/Data/Tenants/<tenant>/<service>/ServiceProfile.json`

Defines the complete set of scale units for each tenant-service, including:
- Scale unit names
- Regions
- Resource quotas (CPU, Memory)
- DSMS service object paths

### 9.6 Reconciliation Runner

**File:** `/src/csharp/fleet-manager/Inventory/Reconciliation/ReconciliationRunner.cs`

The engine that drives all reconciliation. It:
1. Scans for entities with `Generation != ObservedGeneration`
2. Invokes the appropriate `IReconciler<T>` for each modified entity
3. Supports cascading — changes during reconciliation are picked up in subsequent rounds

---

## 10. Code References — File Paths and Key Types

### Core Domain Model

| File | Type | Purpose |
|------|------|---------|
| `ResourceProvider/Abstractions/ScaleUnit.cs` | `record ScaleUnit : IHasMetadata` | Logical workload identity |
| `ResourceProvider/Abstractions/ScaleUnitSpec.cs` | `record ScaleUnitSpec` | Desired state (tenant, service, region, cloud, env, addons, release) |
| `ResourceProvider/Abstractions/ScaleUnitStatus.cs` | `enum ScaleUnitStatus` | NonExistent → Provisioning → Provisioned → Transitioning → Ready / Failed |
| `ResourceProvider/Abstractions/ScaleUnitStatusInfo.cs` | `record ScaleUnitStatusInfo` | ObservedGeneration tracking |
| `ResourceProvider/Abstractions/DeploymentUnit.cs` | `record DeploymentUnit : IHasMetadata` | Physical cluster binding |
| `ResourceProvider/Abstractions/DeploymentUnitSpec.cs` | `record DeploymentUnitSpec` | Cluster name, namespace, MSI, quotas, release |
| `ResourceProvider/Abstractions/DeploymentUnitStatus.cs` | `class DeploymentUnitStatus` | AssignedIdentity, AppliedSpecHash, DeployedReleaseId |

### Reconciler Layer

| File | Type | Purpose |
|------|------|---------|
| `Inventory/Reconciliation/IReconciler.cs` | `interface IReconciler<T>` | Generic reconciliation contract |
| `Inventory/Reconciliation/IReconciliationRunner.cs` | `interface IReconciliationRunner` | Runs reconciliation rounds |
| `ResourceProvider/Reconciler/ScaleUnitReconciler.cs` | `class ScaleUnitReconciler` | Reconciles ScaleUnit → Add + Deploy |
| `ResourceProvider/Reconciler/DeploymentUnitReconciler.cs` | `class DeploymentUnitReconciler` | Reconciles DU → Create + Update + Deploy |
| `ResourceProvider/Reconciler/ReconcilerExtensions.cs` | DI registration | Wires up both reconcilers |

### Scheduler (Placement Engine)

| File | Type | Purpose |
|------|------|---------|
| `ResourceProvider/ScaleUnitScheduler/IScaleUnitScheduler.cs` | `interface IScaleUnitScheduler` | `ScheduleAsync(ScaleUnitSpec) → DeploymentUnit` |
| `ResourceProvider/ScaleUnitScheduler/ScaleUnitScheduler.cs` | `class ScaleUnitScheduler` | Orchestrates filter→score→select + identity validation |
| `ResourceProvider/ScaleUnitScheduler/IClusterFilter.cs` | `interface IClusterFilter` | In-place cluster list filtering |
| `ResourceProvider/ScaleUnitScheduler/IClusterScorer.cs` | `interface IClusterScorer` | Per-cluster scoring |
| `ResourceProvider/ScaleUnitScheduler/IClusterSelector.cs` | `interface IClusterSelector` | End-to-end cluster selection |
| `ResourceProvider/ScaleUnitScheduler/ScoringClusterSelector.cs` | `class ScoringClusterSelector` | Weighted multi-scorer with min-max normalization |
| `ResourceProvider/ScaleUnitScheduler/Filters/TopologyClusterFilter.cs` | `class TopologyClusterFilter` | Region/cloud/env/type matching |
| `ResourceProvider/ScaleUnitScheduler/Filters/MappingBasedFilter.cs` | `class MappingBasedFilter` | Explicit SU-to-cluster pinning |
| `ResourceProvider/ScaleUnitScheduler/Scorers/SpreadScaleUnitsScorer.cs` | `class SpreadScaleUnitsScorer` | Prefer clusters with fewer DUs |
| `ResourceProvider/ScaleUnitScheduler/ScaleUnitClusterMapping.cs` | `record ScaleUnitClusterMapping` | Pattern + ClusterName mapping model |
| `ResourceProvider/ScaleUnitScheduler/ScaleUnitClusterMappingResolver.cs` | `class ScaleUnitClusterMappingResolver` | Regex/exact matching resolver |

### Resource Provider Services

| File | Type | Purpose |
|------|------|---------|
| `ResourceProvider/ResourceProvider/ResourceProvider.cs` | `class ResourceProvider` | Legacy façade (uses reconciler internally) |
| `ResourceProvider/ResourceProvider/IResourceProvider.cs` | `interface IResourceProvider` | Public contract (methods marked Obsolete) |
| `ResourceProvider/ResourceProvider/ScaleUnitAddService.cs` | `class ScaleUnitAddService` | Add SU → schedule → create/update DU |
| `ResourceProvider/ResourceProvider/ScaleUnitDeleteService.cs` | `class ScaleUnitDeleteService` | Delete DU + cleanup traffic manager |
| `ResourceProvider/ResourceProvider/ScaleUnitDeployReleaseService.cs` | `class ScaleUnitDeployReleaseService` | Update DU spec with release info |
| `ResourceProvider/ResourceProvider/ScaleUnitOnboardService.cs` | `class ScaleUnitOnboardService` | Create identity groups + certificates |

### API Controllers

| File | Type | Purpose |
|------|------|---------|
| `ManagementPlane/Apis/CLI/CelestialApi.cs` | Minimal API | CLI endpoints (add/deploy/delete/status/debug) |
| `ManagementPlane/Apis/Ev2/Controllers/Ev2DeployScaleUnitController.cs` | MVC Controller | EV2 HTTP extension for scale unit deployment |

### Configuration Data

| File | Purpose |
|------|---------|
| `ResourceProvider/Data/Platform/ScaleUnitClusterMappingsConfiguration.json` | 38 explicit SU→cluster mappings |
| `ResourceProvider/Data/Tenants/<tenant>/<service>/ServiceProfile.json` | Per-tenant scale unit definitions |

### Documentation

| File | Content |
|------|---------|
| `docs/management-plane/MP-tech-debt-and-vision.md` | Mentions "workload migration controller" as planned |
| `docs/management-plane/MP-architecture-and-overview.md` | MP architecture overview |
| `docs/adr/0006-cluster-orchestrator.md` | Decision: Cluster Orchestrator over Region Orchestrator |
| `docs/adr/0009-sku-selection.md` | SKU migration strategy (Dds_v6 / Dads_v6) |
| `.github/skills/onboard-scale-units/SKILL.md` | Complete guide to onboarding new scale units |

---

## Summary

**The "Workload Migration Controller" is a planned-but-not-yet-implemented component** in the Celestial/idk8s platform. Today, workload migration is achieved through the manual composition of existing primitives:

1. The **ScaleUnitScheduler** handles placement (Filter → Score → Select)
2. The **ScaleUnitAddService** + **ScaleUnitReconciler** creates workloads on target clusters
3. The **ScaleUnitDeleteService** removes workloads from source clusters  
4. The **ScaleUnitClusterMappingsConfiguration.json** provides explicit cluster pinning
5. Traffic shifting is handled externally via Azure Traffic Manager

The platform's **Spec/Status/Generation reconciliation pattern** and **two-level resource model** (ScaleUnit → DeploymentUnit) provide excellent building blocks for a future migration controller that would automate the create-deploy-switch-drain-delete sequence atomically.
