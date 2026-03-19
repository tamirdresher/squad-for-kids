# Decision: Squad-on-Kubernetes — Cloud-Native Agent Orchestration

**Date:** 2026-06-25
**Author:** Picard
**Status:** Proposed
**Issues:** #994, #997, #998, #999, #1000

## Context

Squad currently runs as PowerShell scripts on DevBoxes. Ralph watches issues via `ralph-watch.ps1`, discovers machine capabilities via `discover-machine-capabilities.ps1`, and coordinates rate limiting through a shared `rate-pool.json` file. This works for 1-3 machines but doesn't scale.

## Decision

Move Squad agent orchestration to Kubernetes, with AKS as the primary platform.

### Core Architecture Choices

1. **Pod-per-Agent model** — Each agent (Ralph, Picard, Seven, etc.) runs as its own pod. StatefulSet for Ralph (stable identity for machine-id claim protocol), Jobs for on-demand agents. This preserves the isolation we have today where each agent is an independent process.

2. **Custom Resources for team definitions** — `SquadTeam`, `SquadAgent`, `SquadRound` CRDs replace the filesystem-based `.squad/` state. A Squad operator/controller reconciles these resources.

3. **Node labels replace machine capabilities** — The `needs:*` label system on GitHub issues (#987) maps directly to K8s node selectors. `needs:gpu` → `nvidia.com/gpu` node selector. A capability-discovery DaemonSet replaces `discover-machine-capabilities.ps1`.

4. **Redis replaces rate-pool.json** — The shared file approach doesn't work without a shared filesystem. Redis provides the rate-pool service, maintaining the three-tier priority system from #979 (P0: Picard/Worf, P1: Data/Seven, P2: Ralph/Scribe).

5. **Workload Identity + Auth Proxy sidecar for Copilot auth** — No static PATs in production. Azure Workload Identity provides credential sourcing. A sidecar auth-proxy handles token refresh, rate limit headers, and circuit breaking.

6. **KAITO as degraded-mode fallback** — When Copilot is rate-limited, lower-priority agents (Ralph, Scribe) can fall back to KAITO-hosted local models (phi-3, mistral). Not a replacement for Copilot — a safety net.

7. **Copilot-first model chain** — GitHub Copilot is the primary AI backend. The fallback chain: `copilot-sonnet → copilot-gpt → kaito-local`. Claude/OpenAI are not in the default chain.

8. **Cloud-agnostic core, AKS-first** — Core CRDs and Helm chart work on any K8s. AKS-specific features (KAITO, Workload Identity, Azure Monitor, Node Autoprovision) are optional values in the chart.

## Consequences

- **Migration path:** Existing DevBox-based Squad continues running. K8s deployment is parallel, not a replacement, until proven.
- **New skills needed:** B'Elanna leads Helm chart and AKS setup. Worf owns auth/security design.
- **Cost:** AKS cluster + GPU nodes (for KAITO) adds infrastructure cost. Offset by reducing DevBox count over time.
- **Complexity:** CRDs and operators are more complex than PowerShell scripts. Worth it for scalability, self-healing, and observability.

## Alternatives Considered

- **Docker Compose on VMs** — Simpler but no scheduling, no auto-scaling, no capability routing.
- **Azure Container Apps** — Serverless, but no node-level control for GPU/capability affinity.
- **Keep DevBoxes** — Works today, doesn't scale past 5 machines without significant operational burden.

## Next Steps

1. Seven + B'Elanna: Research KAITO integration (#997)
2. Worf + B'Elanna: Design Copilot auth for pods (#998)
3. B'Elanna: Design capability routing (#999)
4. B'Elanna + Data: Build prototype Helm chart (#1000)
5. Picard: Review all designs, approve architecture (#994)
