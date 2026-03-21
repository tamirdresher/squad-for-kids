# Squad DK8S ConfigGen — `Squad.DK8SApp`

> **Issue #1038** — ConfigGen support for deploying Squad agents as DK8S applications.

## What this project does

This C# project uses the `ConfigurationGeneration.*` NuGet packages to generate
deployment manifests for Squad AI agents on DK8S clusters.

Running the executable produces:
- **EV2 deployment manifests** — for rolling out to DK8S environments via Ev2
- **Helm values files** — per-environment Helm configuration for each agent
- **Resource manifest** — typed JSON manifest consumed by the DK8S deployment pipeline

## Agents defined

| Agent    | K8S type   | Role                                        | Resources           |
|----------|------------|---------------------------------------------|---------------------|
| Picard   | Deployment | Lead — architecture, ADRs, coordination     | 500m–2 vCPU / 512–4 GiB |
| B'Elanna | Deployment | Infrastructure — K8s, Helm, ArgoCD          | 500m–2 vCPU / 512–2 GiB |
| Worf     | Deployment | Security — Azure RBAC, NSG, SFI compliance  | 500m–2 vCPU / 512–2 GiB |
| Ralph    | CronJob    | Work monitor — polls GH issues every 5 min  | 250m–1 vCPU / 128–512 MiB |

## Environments

| ConfigGen alias | Description        |
|-----------------|--------------------|
| `DEV`           | Integration / CI   |
| `STG`           | Pre-production     |
| `PRD`           | Production         |

## Project structure

```
Squad.DK8SApp/
├── Program.cs                        # Entry point — runs the ConfigGen host
├── Squad.DK8SApp.csproj              # Project file
├── generated/                        # ← output (git-ignored)
│   ├── ev2/                          # EV2 rollout spec + shell extensions
│   └── manifest/                     # Typed resource manifest JSON
└── src/
    ├── SquadTopology.cs              # Topology definition (environments + services)
    ├── Agents/
    │   ├── SquadAgentDefaults.cs     # Shared constants (image, env vars, secrets)
    │   ├── SquadAgentServiceBase.cs  # Abstract base for Deployment agents
    │   ├── PicardService.cs          # Picard K8SService (Deployment)
    │   ├── BelannaService.cs         # B'Elanna K8SService (Deployment)
    │   ├── WorfService.cs            # Worf K8SService (Deployment)
    │   └── RalphService.cs           # Ralph K8SCronJob (CronJob)
    └── Environments/
        ├── SquadIntEnvironment.cs    # DEV environment
        ├── SquadPpeEnvironment.cs    # STG environment
        └── SquadProdEnvironment.cs   # PRD environment
```

## How to run

```bash
# From the repository root:
dotnet run --project configgen/Squad.DK8SApp/Squad.DK8SApp.csproj
```

Generated files will appear under `configgen/Squad.DK8SApp/generated/`.

## How to extend

### Adding a new agent (e.g. Data, Seven)

1. Create a new file in `src/Agents/`, extending `SquadAgentServiceBase`:

```csharp
public class DataService : SquadAgentServiceBase
{
    public override string NameOverride => "data";

    // Override ComputeResourceSettings if the agent needs different sizing
}
```

2. Add the new agent as a property on `SquadTopology` and register it in `CreateDcSettings`.

### Customising per-environment settings

Override methods/properties in the relevant `Squad*Environment` class, or
add environment-conditional logic inside the service's `EnvironmentVariablesCreator`.

## Relationship to Helm chart

This ConfigGen project generates the **Helm values** that feed the
`infrastructure/helm/squad-agents` chart.  The chart already has templates for
`ralph-cronjob.yaml` and `picard-deployment.yaml`.  B'Elanna and Worf reuse the
same Deployment template pattern.

## Key design decisions

| Decision | Rationale |
|---|---|
| Ralph = CronJob | Mirrors `ralph-watch.ps1` scheduled-task; no idle-compute waste |
| Deployment agents = always-on | Low-latency response to GitHub events (no cold starts) |
| One K8S namespace "squad" | Simple RBAC; all agents share the same Workload Identity |
| CSI driver for secrets | Standard DK8S pattern; avoids secrets in environment variables |
| `ConcurrencyPolicy: Forbid` for Ralph | Prevents queue-pile-up (same as PS mutex) |
