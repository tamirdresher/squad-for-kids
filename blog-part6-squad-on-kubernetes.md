---
layout: post
title: "The Unicomplex — AI Squads as Cloud-Native Kubernetes Citizens"
date: 2026-03-25
tags: [ai-agents, squad, github-copilot, kubernetes, aks, kaito, keda, helm, scheduling, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 6
---

> *"The Unicomplex is the Borg's home — a structure of unsurpassed complexity, billions of drones coordinated by a single Collective. Every drone knows its function. Every cube knows its node. Every task finds the machine with the right capabilities."*
> — Reconstructed from Seven of Nine's cortical implant archives

In [Part 5](/blog/2026/03/25/scaling-ai-part5-vinculum), I mapped out the distributed systems patterns underlying Squad — CRDTs for decisions, token buckets for rate limiting, event sourcing for agent history. In [Assimilating the Cloud](/blog/2026/03/25/assimilating-the-cloud), I showed you the migration: a Dockerfile, a Helm chart, a `concurrencyPolicy: Forbid` line that replaced 300 lines of PowerShell mutex logic.

This post goes deeper.

It answers the question: *if you were designing Squad to run on Kubernetes from day one, what would it actually look like?* Not the migration story — the target architecture. Custom Resource Definitions that make squads first-class K8s objects. Node labels that encode machine capabilities the same way GitHub issue labels encode requirements. A Kubernetes Event-Driven Autoscaler that scales your agent pool based on the GitHub issue backlog. KAITO-managed model inference running in-cluster for data sovereignty. AKS Workload Identity replacing every `GH_TOKEN` secret rotation.

This is the Unicomplex. The Borg's actual home. Not a laptop running PowerShell.

---

## The Problem With What We Built

Before the design, let me be honest about the gap between where we are and where we're going.

Today, Squad on Kubernetes means: Ralph runs as a CronJob. The agent container has PowerShell 7, Node.js, `gh` CLI, and a GitHub PAT mounted as a Secret. When Ralph decides to spawn Seven or Belanna or Worf to work on an issue, it calls `agency copilot` in a subprocess, which runs inside the same CronJob pod and terminates when done.

That's not a multi-agent system. That's a single Ralph pod that sometimes spawns short-lived subprocesses. The K8s scheduler doesn't know about Seven. The K8s scheduler can't put Seven on a GPU node because Seven's issue requires `needs:gpu`. The K8s autoscaler can't spin up more Ralphs because the issue backlog just grew by thirty items. The K8s network policies can't isolate Belanna's infrastructure work from Worf's security work.

To get those things, you need K8s to understand Squad at a deeper level. That's what this post is about.

---

## Custom Resource Definitions: Making Squads First-Class K8s Objects

The foundation is a pair of Custom Resource Definitions (CRDs) that express Squad concepts in K8s-native terms. From the architecture research in [#994](https://github.com/tamirdresher_microsoft/tamresearch1/issues/994):

```yaml
# squad-team.yaml — a Squad instance scoped to a repository
apiVersion: squad.tamresearch.dev/v1alpha1
kind: SquadTeam
metadata:
  name: tamresearch1
  namespace: squad-system
spec:
  repository: tamirdresher_microsoft/tamresearch1
  configRef: tamresearch1-squad-config   # ConfigMap with squad.config.ts equivalent
  agents:
    - name: ralph
      role: monitor                      # Always-on watcher
      replicas: 1
      schedule: "*/5 * * * *"
      capabilities: []                   # No special hardware needed
    - name: picard
      role: coordinator
      replicas: 1
      capabilities: []
    - name: belanna
      role: specialist
      replicas: 0                        # Scaled to 0 when idle
      capabilities: [azure, helm, k8s]
    - name: worf
      role: specialist
      replicas: 0
      capabilities: [azure, network]
    - name: seven
      role: specialist
      replicas: 0
      capabilities: []
    - name: neelix
      role: specialist
      replicas: 0
      capabilities: [teams-mcp, onedrive]
```

```yaml
# squad-agent.yaml — an individual agent instance
apiVersion: squad.tamresearch.dev/v1alpha1
kind: SquadAgent
metadata:
  name: tamresearch1-ralph-0
  namespace: squad-system
spec:
  teamRef: tamresearch1
  agentName: ralph
  issueRef: ""                          # Empty when idle, set when working
  capabilities:
    required: []
    preferred: []
  status:
    phase: Idle                          # Idle | Running | Completed | Failed
    lastRound: "2026-03-25T14:00:00Z"
    consecutiveFailures: 0
```

A Squad operator watches these resources and manages the pod lifecycle. When a `SquadAgent` transitions to `Running`, the operator creates the actual pod. When it transitions to `Completed`, the operator records the result and tears down the pod. The CronJob concept is hidden inside the operator — users think in terms of `SquadTeam` and `SquadAgent`, not in terms of `CronJob` and `Job`.

---

## Machine Capabilities as Node Labels

This is the conceptual heart of the cloud-native migration, and it's worth spending time on.

### The Local Problem

On my laptop, when Ralph sees an issue labeled `needs:gpu`, it checks `~/.squad/machine-capabilities.json`:

```json
{
  "hostname": "TAMIRDRESHER",
  "capabilities": {
    "gpu": { "available": true, "model": "NVIDIA RTX 3080" },
    "browser": { "available": true, "type": "chromium" },
    "whatsapp": { "available": true, "session": "active" },
    "azure-speech": { "available": false },
    "personal-gh": { "available": true, "user": "tamirdresher" },
    "emu-gh": { "available": true, "user": "tamirdresher_microsoft" }
  }
}
```

If the machine doesn't have the capability, Ralph skips the issue. If it does, Ralph claims it. This works for one machine. It gets awkward across three machines (laptop, DevBox, Azure VM), where each has different capabilities and Ralph instances race to claim issues before checking compatibility.

### The K8s Solution: Node Labels

In Kubernetes, node capabilities are expressed as labels. The mapping is direct ([#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999)):

| Issue `needs:*` Label | K8s Node Label | Provisioned By |
|---|---|---|
| `needs:gpu` | `nvidia.com/gpu: "true"` | NVIDIA device plugin (automatic) |
| `needs:browser` | `squad.io/capability-browser: "true"` | Capability DaemonSet |
| `needs:whatsapp` | `squad.io/capability-whatsapp: "true"` | Capability DaemonSet |
| `needs:azure-speech` | `squad.io/capability-azure-speech: "true"` | Capability DaemonSet |
| `needs:teams-mcp` | `squad.io/capability-teams-mcp: "true"` | Capability DaemonSet |
| `needs:personal-gh` | `squad.io/capability-personal-gh: "true"` | Capability DaemonSet |
| `needs:emu-gh` | `squad.io/capability-emu-gh: "true"` | Capability DaemonSet |
| `needs:onedrive` | `squad.io/capability-onedrive: "true"` | Capability DaemonSet |

The **Capability DaemonSet** is a lightweight pod that runs on every node, probes local capabilities (is there a WhatsApp session? does this node have Azure Speech SDK installed? can it reach the Teams MCP server?), and writes the results as node labels via the Kubernetes API. It replaces `discover-machine-capabilities.ps1` with a cloud-native equivalent.

When the Squad operator creates an agent pod to handle an issue labeled `needs:gpu` + `needs:browser`, it injects scheduling constraints automatically:

```yaml
spec:
  nodeSelector:
    nvidia.com/gpu: "true"
    squad.io/capability-browser: "true"
  tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
  resources:
    limits:
      nvidia.com/gpu: 1
```

For **soft preferences** — capabilities the issue would benefit from but doesn't strictly require — the operator uses `preferredDuringSchedulingIgnoredDuringExecution`:

```yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
            - key: squad.io/capability-azure-speech
              operator: In
              values: ["true"]
```

The K8s scheduler now understands Squad's requirements at the infrastructure level. No manual capability checking in PowerShell. No race conditions between Ralphs on different machines. The scheduler finds the right node. The right node runs the right agent.

### Node Pool Strategy on AKS

On Azure Kubernetes Service, this maps cleanly to node pools ([#997](https://github.com/tamirdresher_microsoft/tamresearch1/issues/997)):

```
AKS Cluster: squad-cluster
├── system-pool (Standard_D2s_v3)       — K8s system components, Squad operator
├── standard-pool (Standard_D4s_v3)     — Ralph, Picard, Seven, Scribe, Troi, Kes
├── gpu-pool (Standard_NC6s_v3)         — Issues labeled needs:gpu (voice synthesis, image gen)
└── burstable-pool (Standard_B2s)       — Spot instances for low-priority background work
```

Each pool has labels applied at creation time. Agents without special requirements land on `standard-pool`. GPU issues (`voice synthesis for Neelix`, `image generation for the blog`) land on `gpu-pool`. Lightweight background monitoring (Neelix checking Tech News sources, Ralph scanning for stale issues) runs on spot-priced `burstable-pool` nodes.

---

## Auto-Scaling Based on Issue Backlog

The hardest part of multi-agent scheduling isn't placement — it's knowing *how many* agents to run. Run too few, and the issue queue backs up. Run too many, and you're paying for idle pods hitting API rate limits in parallel.

### KEDA: Kubernetes Event-Driven Autoscaler

[KEDA](https://keda.sh) scales workloads based on external event sources. GitHub issues are an external event source. The connection is direct.

When the `tamresearch1` repo has 0 actionable issues, Ralph should be the only thing running — one pod, polling every 5 minutes. When Neelix's tech news scan produces 15 new issues for Seven to document, the system should spin up Seven replicas to process them in parallel. When Picard decomposes a feature into 8 tasks, 8 agent pods should claim them concurrently.

Here's the KEDA `ScaledJob` configuration for Seven:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledJob
metadata:
  name: seven-docs-scaler
  namespace: squad-system
spec:
  jobTargetRef:
    template:
      spec:
        containers:
          - name: seven
            image: ghcr.io/tamirdresher_microsoft/squad-seven:latest
            env:
              - name: GH_TOKEN
                valueFrom:
                  secretKeyRef:
                    name: squad-github-token
                    key: token
  triggers:
    - type: github
      metadata:
        owner: tamirdresher_microsoft
        repo: tamresearch1
        # Scale based on open issues assigned to Seven
        filter: "is:open is:issue assignee:seven label:docs"
        personalAccessTokenFromEnv: GITHUB_TOKEN
  # Scale 0 to 5 Seven-pods, one per pending docs issue
  minReplicaCount: 0
  maxReplicaCount: 5
  # Don't spawn more than 2 Seven pods at once (rate limit protection)
  pollingInterval: 60
  cooldownPeriod: 300
```

The trigger checks the GitHub API every 60 seconds. If there are 3 open documentation issues assigned to Seven, KEDA starts 3 Seven pods. When they complete, it scales back to 0. No idle pods. No manual scaling decisions. The issue queue *is* the demand signal.

For Ralph, a different scaling strategy applies. Ralph is always-on but needs more replicas when the global issue count spikes:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: ralph-scaler
  namespace: squad-system
spec:
  scaleTargetRef:
    name: ralph-statefulset
  triggers:
    - type: github
      metadata:
        filter: "is:open is:issue label:ralph"
        targetAverageValue: "5"   # 1 Ralph per 5 pending issues
  minReplicaCount: 1             # Ralph is never fully scaled to 0
  maxReplicaCount: 8             # Max 8 Ralphs (same as our original multi-machine setup)
```

`targetAverageValue: "5"` means KEDA targets 1 Ralph replica per 5 pending issues. If there are 25 open Ralph-tagged issues, KEDA runs 5 Ralph pods. Each Ralph claims different issues through the existing git-based lock mechanism.

### The Cost-Aware Scaling Policy

Raw scale-up is dangerous. Eight Belanna pods all hitting the GitHub API simultaneously will burn through the rate limit within minutes (a lesson painfully learned and documented in [Part 4](/blog/2026/03/17/scaling-ai-part4-distributed-failures)). KEDA's `scaleUpRules` and `stabilizationWindowSeconds` enforce rate-aware scaling:

```yaml
behavior:
  scaleUp:
    stabilizationWindowSeconds: 120   # Wait 2 min before scaling up again
    policies:
      - type: Pods
        value: 2                      # Add at most 2 pods per scale event
        periodSeconds: 60
  scaleDown:
    stabilizationWindowSeconds: 300   # Wait 5 min before scaling down
    policies:
      - type: Percent
        value: 50                     # Remove at most 50% per scale event
        periodSeconds: 120
```

This gives the rate limiter time to breathe between scale events. It also prevents flapping — a burst of 10 new issues doesn't cause 10 pods to spawn simultaneously.

---

## Pod Affinity: Co-Locating Squad Members

Squads work better when their members are close to each other. Picard and Seven frequently communicate (Picard routes research tasks to Seven). Data and Belanna collaborate on code+infra changes. Worf and Picard work in tandem on security architecture decisions.

Pod affinity puts related agents on the same node, reducing MCP call latency (intra-node vs. inter-node network hops):

```yaml
# Picard and Seven on the same node
affinity:
  podAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              squad.io/role: coordinator     # Prefer to be near Picard
          topologyKey: kubernetes.io/hostname

# Different squads on different nodes (isolation)
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            squad.io/team: other-team        # Hard separation between teams
        topologyKey: kubernetes.io/hostname
```

The anti-affinity rule means Team A's agents and Team B's agents never share a node. When we scale Squad to multiple tenants (the Douglas Guncet 100-client scenario), each squad is literally isolated at the hardware level. No shared process space. No accidental log interleaving. No auth state contamination.

---

## KAITO: Model Inference as a K8s Native Service

Right now, every Squad agent calls Claude via the Copilot CLI. That works when you have one squad. It doesn't work when you have 100 squads all competing for the same Anthropic rate limit.

[KAITO (Kubernetes AI Toolchain Operator)](https://github.com/Azure/kaito) provides model inference as a K8s-native service. Instead of calling `claude-sonnet-4.5` through the Copilot CLI, agents can call a KAITO-managed model running in the same cluster.

The setup ([#997](https://github.com/tamirdresher_microsoft/tamresearch1/issues/997)):

```yaml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-fallback-llm
  namespace: squad-system
spec:
  resource:
    instanceType: Standard_NC6s_v3     # GPU node, auto-provisioned by KAITO
    labelSelector:
      matchLabels:
        apps: squad-inference
  inference:
    preset:
      name: phi-3-mini-128k-instruct   # Or mistral-7b, llama-3-8b, etc.
```

KAITO handles everything: GPU node provisioning via AKS Node Autoprovision, pulling the quantized model image, deploying the vLLM inference server, health monitoring. You get a ClusterIP service at `squad-fallback-llm.squad-system.svc.cluster.local:8080` that speaks OpenAI-compatible API.

### The Fallback Chain

The Squad model chain in `squad.config.ts` currently looks like:

```typescript
standard: [
  "claude-sonnet-4.5",
  "gpt-5.2-codex",
  "claude-sonnet-4",
  "gpt-5.2"
]
```

With KAITO in the cluster, you extend the chain:

```typescript
standard: [
  "claude-sonnet-4.5",        // Primary: Copilot-managed
  "gpt-5.2-codex",            // Secondary: Copilot-managed
  "kaito-local-phi3",         // Tertiary: KAITO in-cluster (rate-limit fallback)
  "kaito-local-mistral"       // Quaternary: KAITO in-cluster (last resort)
]
```

When the shared rate pool hits throttling for background agents (Ralph monitoring, Scribe logging, Neelix scanning), those agents fall back to the in-cluster model. They keep working. Picard and Data — the agents doing actual user-facing work — get the full Copilot model. No task abandonment due to rate limits.

### What KAITO Costs

Running `phi-3-mini-128k-instruct` on a `Standard_NC6s_v3` GPU node in East US 2 costs approximately $0.90/hour at pay-as-you-go pricing. For a busy day with 200 fallback requests, where each request averages 2 seconds of inference time, you're looking at 400 seconds = 6.7 GPU minutes = **~$0.10 for the entire fallback traffic**. This compares favorably to the cost of a Claude Sonnet call at $0.003/1K tokens when you consider the latency reduction and the fact that you own the compute.

For a 100-client deployment, a shared KAITO cluster serving all clients' fallback traffic amortizes the GPU cost to near zero per client.

---

## AKS Workload Identity: Goodbye, PAT Rotation

The current Squad deployment uses a GitHub Personal Access Token stored as a K8s Secret. This works but requires periodic rotation (GitHub PATs expire or get compromised), creates a single point of failure (one PAT for all agents), and doesn't support fine-grained permissions per agent.

AKS Workload Identity changes this. It federates a Kubernetes Service Account with an Azure Active Directory application, which in turn authenticates to GitHub via the GitHub App mechanism. The token is auto-rotated. There's no PAT. If the pod is killed mid-operation, the next pod gets fresh credentials automatically.

The setup:

```bash
# Create the AKS cluster with OIDC issuer enabled
az aks create \
  --name squad-cluster \
  --resource-group squad-rg \
  --enable-oidc-issuer \
  --enable-workload-identity

# Create managed identity for squad agents
az identity create \
  --name squad-agent-identity \
  --resource-group squad-rg

# Federate the K8s service account
az identity federated-credential create \
  --identity-name squad-agent-identity \
  --resource-group squad-rg \
  --name squad-k8s-federation \
  --issuer "${OIDC_ISSUER}" \
  --subject "system:serviceaccount:squad-system:squad-agent"
```

In the pod spec, you just annotate the Service Account:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: squad-agent
  namespace: squad-system
  annotations:
    azure.workload.identity/client-id: "${MANAGED_IDENTITY_CLIENT_ID}"
```

The pod gets a projected token automatically. The agent code exchanges it for GitHub credentials via the GitHub App's JWT flow. Zero PAT management. Zero rotation ceremonies. The infrastructure team sleeps better at night.

---

## The Squad Deployment, End to End

Putting it all together, here's what deploying Squad on AKS actually looks like today, based on the Helm chart from [#1000](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1000):

```bash
# Create the cluster (one-time)
az aks create \
  --name squad-cluster \
  --resource-group squad-rg \
  --node-count 2 \
  --node-vm-size Standard_D4s_v3 \
  --enable-oidc-issuer \
  --enable-workload-identity \
  --enable-addons monitoring

# Add GPU pool for needs:gpu issues
az aks nodepool add \
  --cluster-name squad-cluster \
  --resource-group squad-rg \
  --name gpupool \
  --node-count 0 \
  --min-count 0 \
  --max-count 3 \
  --enable-cluster-autoscaler \
  --node-vm-size Standard_NC6s_v3 \
  --node-taints nvidia.com/gpu=present:NoSchedule

# Deploy the Helm chart
helm upgrade --install tamresearch1-squad ./charts/squad \
  --namespace squad-system \
  --create-namespace \
  --set squad.repository=tamirdresher_microsoft/tamresearch1 \
  --set agents.ralph.enabled=true \
  --set agents.belanna.enabled=true \
  --set agents.seven.enabled=true \
  --set keda.enabled=true \
  --set kaito.enabled=true \
  --set kaito.model=phi-3-mini-128k-instruct
```

After deploy, the state looks like this:

```
Namespace: squad-system
───────────────────────────────────────────────────────
Pod                               Status    Node
───────────────────────────────────────────────────────
ralph-0                           Running   standard-pool-node-1
squad-operator-7d4f9b-xk2mn       Running   system-pool-node-1
capability-daemonset-<node1>      Running   standard-pool-node-1
capability-daemonset-<node2>      Running   standard-pool-node-2
kaito-workspace-phi3-<hash>       Pending   (waiting for GPU node)
───────────────────────────────────────────────────────

KEDA ScaledJobs (all at 0 replicas — no pending issues)
───────────────────────────────────────────────────────
seven-docs-scaler                 0/0
belanna-infra-scaler              0/0
worf-security-scaler              0/0
data-code-scaler                  0/0
```

Ralph runs continuously, monitoring the repo. All specialist agents are at zero replicas. When an issue comes in labeled `squad:seven`, KEDA detects it within 60 seconds and starts a Seven pod. Seven works. Seven completes. Seven pod terminates. The replica count returns to zero.

---

## The Real Examples

Let me be concrete about how this maps to the actual agents in `tamresearch1`.

**Ralph (Monitor):** StatefulSet with 1–3 replicas. Scales up based on total open issues labeled `ralph`. Uses `concurrencyPolicy: Forbid` to prevent two Ralph pods from working the same round. State persisted in a PVC so Ralph remembers its consecutive-failure count and circuit breaker state across pod restarts.

**Neelix (News Reporter):** CronJob, runs daily at 07:00. Needs `teams-mcp` capability to post to Teams channels. Scheduled on nodes where the Teams MCP sidecar is running. On K8s, Neelix's entire "environment" — the Teams MCP server, the OneDrive access, the calendar tools — are sidecars in the same pod. No setup. No teardown. Just `kubectl apply`.

**Belanna (Infrastructure Expert):** ScaledJob, 0 replicas when idle. Scales when `squad:belanna` issues appear. Needs Azure CLI, Helm, kubectl. These are baked into Belanna's container image. When Belanna is working on a K8s issue (like the ingress-nginx EOL migration we tackled in March), her pod is literally running inside the cluster she's modifying. The Kubernetes API is a ClusterIP service call. No external network hop.

**Worf (Security):** ScaledJob, 0 replicas when idle. Hardened pod spec: `securityContext.readOnlyRootFilesystem: true`, `securityContext.runAsNonRoot: true`, `capabilities.drop: [ALL]`. Worf's pod can't write to the filesystem (except approved volume mounts), can't escalate privileges, and runs with a stripped Linux capability set. If Worf's agent gets compromised, the blast radius is the pod. Not the node. Not the cluster.

**Seven (Docs):** ScaledJob, 0 replicas when idle. Scales based on open documentation issues. No special hardware requirements. Runs on standard-pool nodes. Creates PRs via the GitHub API (authenticated via Workload Identity). Writes blog posts. Does research. Exactly like right now, but without being tied to any specific machine.

---

## What This Changes

Here's the table that captures the delta:

| Concern | Local Squad | K8s Squad |
|---|---|---|
| Ralph uptime | "Is the laptop awake?" | CronJob, always scheduled |
| Capability routing | PowerShell function + JSON file | Node labels + pod scheduling |
| Multi-agent concurrency | Subprocesses in one pod | Independent pods, independent resources |
| Scaling to backlog | Manual ("run another Ralph") | KEDA ScaledJobs, automatic |
| Auth management | PAT in env var, manual rotation | AKS Workload Identity, zero rotation |
| Model fallback | HTTP retry to next provider | KAITO in-cluster fallback |
| Multi-tenant isolation | Git namespace conventions | K8s namespace hard isolation |
| Observability | Teams webhook notifications | Prometheus, Grafana, distributed tracing |
| Debugging | Terminal window output | `kubectl logs --previous`, structured JSON |
| Cost when idle | Always-on machine (electricity, compute) | Scale-to-zero: pay only when working |

The two rows that matter most to daily operations:

**"Scale-to-zero"** means a squad that does nothing costs nothing. Seven doesn't run when there are no documentation issues. Belanna doesn't run when there are no infrastructure issues. You pay for the one Ralph pod, the operator, and the monitoring sidecars. Everything else bills zero. At scale, this changes the economics of multi-agent teams from "expensive always-on fleet" to "serverless on a scheduler."

**"Capability routing"** means you can add a new machine with new capabilities (say, a GPU node with Azure Neural Voice SDK for Neelix's audio generation) by labeling the node and letting the scheduler figure out the rest. No PowerShell capability manifest. No JSON file to update. The label *is* the capability declaration.

---

## What's Still Hard

This architecture solves structural problems. It doesn't solve fundamental distributed systems problems.

**Rate limits.** KEDA can scale to 8 Belanna pods. Eight Belanna pods can collectively burn through the GitHub API rate limit faster than one Belanna pod. KEDA doesn't know about GitHub's rate limits. The rate governor (the Redis token bucket design from the rate-limiting research in [#979](https://github.com/tamirdresher_microsoft/tamresearch1/issues/979)) needs to be a shared K8s service that all agent pods consult before making API calls. That service doesn't exist yet.

**Prompt size.** The prompt-as-command-name bug from Part 4 — where a 7KB PowerShell prompt gets interpreted as an executable name — doesn't go away in K8s. Container entrypoints have argument size limits too. The fix (write to a temp file, pass the file path) still applies. We're carrying this as tech debt in the Dockerfile.

**Cross-squad coordination.** When Picard (in `tamresearch1`) wants to consult Belanna (in a different squad, working on a different repo), that call currently doesn't exist. MCP over the cluster network would enable it — your Picard pod calls `belanna.other-squad.svc.cluster.local:8080` with a tool request, gets back a response. But the Squad framework doesn't expose an MCP server today. That's a framework-level change, not a deployment change.

**The Copilot CLI is still a CLI.** The entire Squad architecture currently depends on running `agency copilot --yolo --prompt "..."` in a subprocess. That's not a gRPC service. It's not a K8s-native API. Every Ralph pod carries a full Node.js runtime, a PowerShell runtime, the `gh` CLI, and the Copilot CLI extension — 890 MB of container image — to run what is fundamentally a chat completion call with some MCP tool bindings. The K8s-native path is a proper Squad SDK that exposes an HTTP API, and that's a future we're moving toward.

---

## Where This Goes

The Unicomplex — the Borg's actual home infrastructure — is described as housing millions of drones operating as a unified collective, each with a designated function, each scheduled to the right cube, each contributing its specific capability to the whole.

We're not building the Borg. But the infrastructure pattern is identical: **a scheduler that knows what each unit can do, a demand signal that determines how many units to run, and an isolation boundary that prevents one unit's failure from cascading**.

Kubernetes is the most mature implementation of that pattern that exists. Squad agents are workloads. The issue backlog is the demand signal. Machine capabilities are node labels. The Squad operator is the control plane.

The squad doesn't sleep anymore. The squad doesn't die when the laptop lid closes. The squad scales up when there's work and scales down when there isn't.

And when you have one hundred squads running in one cluster, each isolated in its own namespace, each with its own KAITO fallback model, each with its own rate governor, each automatically scaling to its own backlog — that's not duct tape and PowerShell anymore.

That's production infrastructure.

The assimilation is complete. 🟩⬛

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)
> - **Part 4**: [When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-distributed-failures)
> - **Part 5**: [The Vinculum — Eight Distributed Systems Lessons](/blog/2026/03/25/scaling-ai-part5-vinculum)
> - **Part 5b**: [Assimilating the Cloud — Running Your AI Squad on Kubernetes](/blog/2026/03/25/assimilating-the-cloud)
> - **Part 6 (this post)**: The Unicomplex — AI Squads as Cloud-Native Kubernetes Citizens

*All issue numbers, architecture decisions, and agent names in this post are real. The research in #994, #997, #999, and #1000 drove this design. The Squad framework code is at [tamirdresher_microsoft/tamresearch1](https://github.com/tamirdresher_microsoft/tamresearch1). The `keep-devbox-alive.ps1` script still exists in the repo. I'm choosing to believe it's now a historical artifact rather than a dependency.*
