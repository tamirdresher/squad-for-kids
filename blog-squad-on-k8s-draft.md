---
layout: post
title: "The Right Machine for the Right Agent — Squad, AKS, and KAITO"
date: 2026-04-02
tags: [ai-agents, squad, kubernetes, aks, kaito, gpu, helm, machine-capabilities, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: 6
---

> *"Perfection is not a destination. It is a continuous journey."*
> — Seven of Nine, Star Trek: Voyager

In [Part 5](/blog/2026/03/25/scaling-ai-part5-kubernetes), I showed you how we moved the Squad off a laptop and onto Kubernetes. Ralph's CronJob fires every five minutes. No more mouse-wiggling script. No more lock files lying about who's running. The Borg Collective finally has a home that doesn't go to sleep.

But a funny thing happened after that migration: *we started treating every agent the same.*

Ralph running on the same node as Data. Picard scheduled next to a lightweight metrics scraper. Seven analyzing research documents on the same 2-CPU burstable node as a GPU-hungry model inference job. K8s was running everything — it just wasn't running it *smart*.

This post is about fixing that.

---

## The Problem No One Talks About

When you containerize an AI team, you hit a scheduling problem that the Kubernetes docs don't cover in the getting-started guide: **not all agents are equal, and not all nodes are equal.**

Consider our crew:

- **Ralph** — watches GitHub every five minutes, calls the Copilot CLI, creates issues and PRs. CPU: light. Memory: modest. Network: GitHub API calls. No GPU needed.
- **Data** — writes code, runs tests, diffs PRs. CPU: can spike on large codebases. Memory: scales with repo size. Sometimes benefits from SSD-backed scratch space.
- **Seven** — research and documentation. Reads PDFs, synthesizes documents, generates long-form text. Memory-hungry on large document sets. If we're running a local model for summarization — GPU useful.
- **B'Elanna** — infrastructure operations. Runs Terraform, calls Azure APIs, applies Helm charts. Network-heavy. Needs specific cloud credentials. No GPU.
- **KAITO inference endpoint** — serving a fine-tuned model for squad-internal queries. Needs a GPU node. Full stop.

Running all of these on the same node type is like assigning your entire crew to the same duty station regardless of rank or specialty. Worf does not run ops. Data does not do security sweeps. And a 90B parameter model does not run on a 2-CPU burstable instance.

The solution is machine capabilities — declaring what each node *can* do, and what each agent *needs*.

---

## Machine Capabilities: Teaching Ralph What Each Node Knows

The core idea: every node in the cluster advertises its capabilities. Every agent deployment declares what it requires. The scheduler matches them.

In Kubernetes, this is node labels + pod nodeSelectors and resource requests. But the Squad layer adds semantic meaning on top.

Here's what a machine capability profile looks like in `.squad/machines.yaml`:

```yaml
# .squad/machines.yaml — Machine capability declarations
# Ralph reads this to understand what each node class can do
# This feeds directly into squad routing decisions

machines:
  - profile: lightweight
    nodeSelector:
      squad/node-class: lightweight
    capabilities:
      gpu: false
      memory: "4Gi"
      cpu: 2
      ssd: false
      network: standard
    suitable-for:
      - ralph          # Queue watching, GitHub API
      - picard         # Orchestration, routing decisions
      - worf           # Security scans (CPU-bound, not GPU)
      - belanna        # Infrastructure ops, Azure CLI

  - profile: compute
    nodeSelector:
      squad/node-class: compute
    capabilities:
      gpu: false
      memory: "16Gi"
      cpu: 8
      ssd: true
      network: high-throughput
    suitable-for:
      - data           # Code analysis, test runs, large diffs
      - seven          # Document processing, large context windows

  - profile: gpu
    nodeSelector:
      squad/node-class: gpu
      accelerator: nvidia-a100
    capabilities:
      gpu: true
      gpu-memory: "40Gi"
      memory: "64Gi"
      cpu: 16
      ssd: true
      network: high-throughput
    suitable-for:
      - kaito-inference    # Local model serving
      - seven-extended     # Seven + local model for deep research
```

Ralph reads this file on startup and uses it when routing tasks. The routing logic isn't complicated: if a task is labeled `requires: gpu` in the issue tracker, Ralph knows to hand it to an agent scheduled on a GPU node. If a task is pure documentation work, it goes to Seven on a compute node. Lightweight queue management stays on burstable.

This is machine profiles as squad routing tables. The infrastructure knowledge lives in `.squad/` alongside your decisions and team config — one place, one format, readable by humans and agents alike.

---

## Pod Design: The Squad Member as Container

Let me show you what a Squad agent pod actually looks like at the spec level. We'll use Seven as the example since she's the most interesting: she needs document access (shared volume), the ability to call external APIs (network), and potentially a local model for deep research (GPU node in the `gpu` profile).

```yaml
# templates/seven-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: squad-seven
  namespace: squad-agents
spec:
  replicas: 1
  selector:
    matchLabels:
      squad/member: seven
  template:
    metadata:
      labels:
        squad/member: seven
        squad/role: research-docs
    spec:
      # Schedule Seven on compute nodes — she needs memory and SSD
      nodeSelector:
        squad/node-class: compute

      # Co-locate Seven with Data (same zone, different nodes is fine)
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 50
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  squad/member: data
              topologyKey: topology.kubernetes.io/zone

      # Never co-locate two Sevens (no duplicate agents)
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              squad/member: seven
          topologyKey: kubernetes.io/hostname

      containers:
      # Main agent container
      - name: seven
        image: your-registry.azurecr.io/squad-seven:latest
        command: ["pwsh", "-NoProfile", "-File", "/squad/agent-watch.ps1"]
        env:
        - name: SQUAD_MEMBER
          value: "seven"
        - name: SQUAD_ROLE
          value: "research-docs"
        - name: GH_TOKEN
          valueFrom:
            secretKeyRef:
              name: squad-github-token
              key: token
        - name: KAITO_ENDPOINT
          value: "http://kaito-inference-svc.squad-ai:8080"
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
        volumeMounts:
        - name: squad-state
          mountPath: /squad/state
        - name: squad-config
          mountPath: /squad/config
          readOnly: true

      # Sidecar: MCP server for document operations
      # Seven can call this over localhost instead of spawning a subprocess
      - name: mcp-docs
        image: your-registry.azurecr.io/mcp-server-docs:latest
        ports:
        - containerPort: 9090
          name: mcp
        env:
        - name: MCP_TRANSPORT
          value: "http"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"

      volumes:
      - name: squad-state
        persistentVolumeClaim:
          claimName: squad-shared-state   # Shared across ALL squad members
      - name: squad-config
        configMap:
          name: squad-config
```

Three things worth calling out:

**The shared volume.** `squad-shared-state` is a `ReadWriteMany` PVC (backed by Azure Files in our AKS setup). Every squad member mounts it. When Seven writes to `/squad/state/decisions.md`, Data reads it in the next iteration. This is the `.squad/` directory living in the cloud. It's the team's shared brain — now durable, distributed, and not dependent on any single machine being awake.

**The MCP sidecar.** Every squad member pod runs one or more MCP server sidecars. These are the tool servers that give agents their capabilities: file operations, GitHub calls, Azure management. Running them as sidecars instead of spawning subprocesses means they're lifecycle-managed by K8s, they restart independently if they crash, and they don't compete for the agent container's resource limits. Seven calls `http://localhost:9090` for document operations. Picard calls `http://localhost:9091` for orchestration tools. Clean separation.

**Affinity and anti-affinity.** Seven *prefers* to be in the same availability zone as Data (they often collaborate, and cross-zone latency on a shared PVC adds up). But Seven *must not* run on the same node as another Seven instance. One research agent per node. These rules encode team structure into the scheduler.

---

## AKS Integration: Node Pools as Squad Tiers

On Azure Kubernetes Service, we translate machine capability profiles directly into node pools. One node pool per capability class:

```bash
# Lightweight pool — Ralph, Picard, Worf, B'Elanna
az aks nodepool add \
  --resource-group squad-rg \
  --cluster-name squad-aks \
  --name lightweight \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --labels squad/node-class=lightweight \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5

# Compute pool — Data, Seven
az aks nodepool add \
  --resource-group squad-rg \
  --cluster-name squad-aks \
  --name compute \
  --node-count 2 \
  --node-vm-size Standard_D8s_v5 \
  --labels squad/node-class=compute \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 8

# GPU pool — KAITO inference, extended Seven
az aks nodepool add \
  --resource-group squad-rg \
  --cluster-name squad-aks \
  --name gpu \
  --node-count 1 \
  --node-vm-size Standard_NC24ads_A100_v4 \
  --labels squad/node-class=gpu \
  --node-taints sku=gpu:NoSchedule \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 2
```

The GPU pool starts at zero nodes and scales up when KAITO inference is active. When no models are being served, AKS scales the pool back to zero. That's the cost control lever — GPU nodes are expensive, and you pay by the hour. An idle squad doesn't need an idle A100.

### Workload Identity: Authentication That Doesn't Hurt

The previous multi-machine setup had a recurring headache: every new machine needed GitHub credentials configured manually. Tokens expired. Configuration drifted. Agents on different machines were authenticating differently depending on what was cached.

AKS Workload Identity replaces all of that. Each squad member pod gets an Azure AD identity. That identity has fine-grained permissions. No tokens to rotate, no secrets to distribute, no credential drift.

Setup is a one-time operation:

```bash
# Create a managed identity for the squad
az identity create \
  --name squad-agent-identity \
  --resource-group squad-rg

# Federate with the AKS OIDC issuer
az identity federated-credential create \
  --name squad-aks-federated \
  --identity-name squad-agent-identity \
  --resource-group squad-rg \
  --issuer $(az aks show --resource-group squad-rg --name squad-aks --query oidcIssuerProfile.issuerUrl -o tsv) \
  --subject system:serviceaccount:squad-agents:squad-sa \
  --audience api://AzureADTokenExchange

# Grant ACR pull permission (so pods can pull their own images)
az role assignment create \
  --assignee $(az identity show --name squad-agent-identity --resource-group squad-rg --query clientId -o tsv) \
  --role AcrPull \
  --scope $(az acr show --name squadregistry --query id -o tsv)
```

Each pod's service account (`squad-sa`) gets the managed identity annotation, and Kubernetes injects a short-lived token that Azure AD accepts. The `GH_TOKEN` secret still handles GitHub auth (GitHub doesn't support OIDC federation for personal repos yet), but every Azure resource — ACR, Key Vault, Storage — now uses the managed identity. No secrets file. No rotation anxiety.

---

## KAITO: A Model Serving Layer Built for Kubernetes

Here's the piece that changes the cost and privacy equation for AI squads running heavy inference workloads.

By default, every Squad agent call goes to an external API — OpenAI, Anthropic, GitHub Copilot's backend. That works. It's fast, it's reliable, and for most tasks it's the right call. But there are scenarios where you want a model running *in your cluster*:

- **Data sovereignty** — customer data, proprietary code, or regulated content that can't leave your network boundary.
- **Cost control** — high-volume internal tasks (code summarization, doc generation) are expensive at per-token API pricing. A fine-tuned local model serving thousands of requests per day at fixed GPU cost often wins on unit economics.
- **Custom models** — a squad fine-tuned on your codebase, your conventions, your architecture patterns. No external model knows your code as well as a model trained on it.
- **Latency** — for synchronous agent-to-agent calls inside the cluster, a local inference endpoint is orders of magnitude faster than an external API call with network roundtrip.

KAITO (Kubernetes AI Toolchain Operator) is a Kubernetes operator that manages model inference as first-class cluster resources. Instead of writing deployment YAMLs for TensorRT configurations or figuring out GPU memory allocation, you declare a `Workspace` resource and KAITO handles the rest.

### Deploying a Squad Model with KAITO

Here's a KAITO Workspace that deploys Phi-3 Mini as an inference endpoint for the squad:

```yaml
# kaito-squad-model.yaml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: squad-phi3-inference
  namespace: squad-ai
spec:
  resource:
    instanceType: Standard_NC24ads_A100_v4
    labelSelector:
      matchLabels:
        squad/node-class: gpu
    count: 1

  inference:
    preset:
      name: phi-3-mini-128k-instruct
    # KAITO handles:
    # - Model download and caching
    # - GPU memory allocation
    # - Inference server startup (vLLM under the hood)
    # - Service endpoint creation
    # - Health checks and restarts
```

After `kubectl apply`, KAITO:

1. Provisions a GPU node from the AKS autoscaler (if none available)
2. Downloads the model weights from Hugging Face (and caches them on the PV)
3. Starts a vLLM inference server with the right quantization settings
4. Creates a Kubernetes Service (`squad-phi3-inference` in the `squad-ai` namespace)
5. Exposes an OpenAI-compatible API at `http://squad-phi3-inference.squad-ai:8080/v1`

That last point is important. The KAITO-served endpoint is **OpenAI-compatible**. Your squad agents don't need code changes — they point their `OPENAI_BASE_URL` env var at the KAITO service instead of `api.openai.com`, and the same API calls work. Seven summarizing a 200-page research document? She calls the KAITO endpoint. Data asking for code suggestions on a proprietary codebase? Same endpoint, same API contract, zero data leaving your cluster.

### The Squad Routing Update

With KAITO running, `.squad/machines.yaml` gains a new entry and the routing logic gets one more decision branch:

```yaml
# Updated routing rules in .squad/routing.md

## Model Routing

### External tasks (low-sensitivity, general knowledge)
- Use: GitHub Copilot API / Anthropic
- Examples: public repo work, open source analysis, general documentation

### Internal tasks (sensitive code, proprietary content)
- Use: KAITO endpoint (http://kaito-inference-svc.squad-ai:8080)
- Examples: internal API designs, customer data processing, compliance docs

### Fine-tuned tasks (codebase-specific)  
- Use: KAITO endpoint with squad-finetuned model
- Examples: code review using project conventions, architecture validation
```

Ralph routes based on issue labels. Issues tagged `internal` or `sensitive` go to agents configured with the KAITO endpoint. Everything else goes to the external API. One label in GitHub. Zero agent code changes.

---

## The Scheduling Problem, Solved

Let me tie the machine capabilities, pod design, and node pools together with the full scheduling picture.

The goal: when Ralph picks up a task and decides which agent to dispatch, the right agent runs on hardware that matches the task, co-located with its collaborators, and isolated from interference.

Here's the complete affinity map for a full squad deployment:

```yaml
# Squad-wide scheduling policy (embedded in squad-helm/values.yaml)

scheduling:
  # Ralph and Picard: lightweight, co-located for fast hand-off
  ralph:
    nodeClass: lightweight
    colocateWith: [picard]
  picard:
    nodeClass: lightweight
    colocateWith: [ralph]

  # Data and Seven: compute nodes, prefer same zone
  data:
    nodeClass: compute
    colocateWith: [seven]
  seven:
    nodeClass: compute
    colocateWith: [data]

  # Worf and B'Elanna: lightweight (security scans + Azure CLI don't need GPU)
  worf:
    nodeClass: lightweight
  belanna:
    nodeClass: lightweight

  # KAITO inference: GPU only, dedicated
  kaito-inference:
    nodeClass: gpu
    exclusive: true    # taint-tolerating pod, no other squad workloads on this node
```

The `exclusive: true` flag on KAITO is important. GPU nodes are expensive and the model server uses most of the available GPU memory. We taint the GPU nodes with `sku=gpu:NoSchedule` (see the node pool setup above) and only pods that explicitly tolerate this taint get scheduled there. No accidental lightweight workloads landing on an A100.

The result: Ralph and Picard spin up fast on burstable nodes. Data and Seven get real CPU and SSD for code and document work. KAITO gets a clean GPU node, scales to zero when idle, scales back up within a couple of minutes when a GPU task arrives.

---

## What It Costs (And What It Saves)

Running the squad on AKS with this setup breaks down roughly as:

| Node Pool | VM Size | On-demand/hr | Notes |
|---|---|---|---|
| lightweight (2 nodes) | Standard_B2s | ~$0.04/hr | Always on, minimal cost |
| compute (2 nodes) | Standard_D8s_v5 | ~$0.38/hr | Always on for code/docs work |
| gpu (0–1 nodes) | NC24ads_A100_v4 | ~$3.67/hr | Scale-to-zero when idle |

At 8 hours of GPU usage per day (KAITO serving inference requests during active hours, idle overnight), the GPU cost is roughly **$29/day**. Compare that to equivalent OpenAI API usage for the same volume — a squad running heavy internal inference at scale tips the math toward local models faster than most teams expect.

The lightweight and compute pools run continuously and cost about **$22/day** combined. Total squad infrastructure: under $50/day for a fully operational, always-on AI engineering team running on production-grade hardware.

---

## Honest Reflection

Three things I didn't anticipate:

**KAITO model downloads are slow.** The first time you apply a Workspace for a 7B parameter model, plan for 20–40 minutes of download time. KAITO caches the weights on a PersistentVolume, so subsequent pod restarts are fast — but the first deployment will feel like it's hanging. It isn't. It's just a 14GB file on a storage endpoint.

**The shared PVC is the new single point of failure.** We traded the "laptop goes to sleep" problem for the "Azure Files mount latency spikes during storage maintenance" problem. It's a better problem, but it's still a problem. We added retry logic in every agent's file write operations and moved decision-critical state to a PostgreSQL sidecar for writes that can't tolerate flaky mounts.

**GPU node scale-up takes 3–5 minutes.** AKS needs to provision and bootstrap the node, pull the KAITO image, and start the inference server. For synchronous tasks that need a local model, this cold-start latency is noticeable. We solved this by keeping KAITO running during business hours (a simple CronJob that pings the endpoint every 30 minutes to prevent scale-down) and letting it go to zero overnight.

None of these are dealbreakers. They're just the next layer of the distributed systems onion. You peel one, another appears. The trick is that each new layer is better-understood than the last.

---

## Where This Goes Next

Machine capabilities, AKS node pools, KAITO inference — these are the pieces that turn a K8s-based squad from "convenient process manager" into "actual production AI platform."

The next question on my mind: **federation**. Multiple squads, multiple clusters, cross-cluster MCP calls. Your Picard asking my Worf for a security review. A shared KAITO inference endpoint serving model requests from five different squad deployments. The Borg Collective at scale.

That's the post after this one.

For now: the squad is on the cloud, it knows which hardware it needs, it has a model serving layer that doesn't leak your data, and it costs less than a mid-tier SaaS license per day.

The Borg don't just assimilate. They *optimize*.

---

> 📚 **Series: Scaling Your AI Development Team**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [From Personal Repo to Work Team — Scaling Squad to Production](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)
> - **Part 4**: [When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-distributed-failures)
> - **Part 5**: [Assimilating the Cloud — Running Your AI Squad on Kubernetes](/blog/2026/03/25/scaling-ai-part5-kubernetes)
> - **Part 6**: The Right Machine for the Right Agent — Squad, AKS, and KAITO ← You are here
