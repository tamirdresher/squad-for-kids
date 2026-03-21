# azd ai-agent run/invoke — Squad Framework Integration Design

**Date:** 2026-03-21  
**Author:** Seven  
**Issue:** [#986](https://github.com/tamirdresher_microsoft/tamresearch1/issues/986)  
**Source:** https://devblogs.microsoft.com/azure-sdk/azd-ai-agent-run-invoke/

---

## What `azd ai-agent run` and `azd ai-agent invoke` Do

The `azure.ai.agents` extension for Azure Developer CLI adds two terminal commands that bring the inner development loop for AI agents entirely into the CLI — no browser, no portal required.

| Command | What it does |
|---------|--------------|
| `azd ai agent run` | Starts an AI agent process locally. Auto-detects project type (Python, Node.js, etc.), installs dependencies, launches the agent. Optionally targets a named agent in multi-agent projects. |
| `azd ai agent invoke` | Sends a message to a running agent. Defaults to the remote Azure AI Foundry endpoint; add `--local` to target a locally running agent. Session/conversation IDs persist across calls — supports multi-turn conversations. |

```bash
azd ai agent run                          # Start default agent locally
azd ai agent run my-agent                 # Start a named agent
azd ai agent invoke "Summarize this doc"  # Send to remote Foundry endpoint
azd ai agent invoke "Hello" --local       # Send to local agent
```

**Key insight:** This is a CLI-first way to start *any* AI agent, trigger it with a message, and get a streamed response — making agent invocation scriptable from anywhere that can run a shell command. Session continuity (multi-turn) is built-in.

---

## Proposed Squad Feature: `azd ai-agent` as a Squad Execution Backend

### The Problem Today

Each squad agent runs as a GitHub Copilot CLI process (`gh copilot`) invoked by Ralph on the local machine. This ties execution tightly to:
- A specific machine where Ralph is running
- The `gh copilot` CLI's model/tool configuration
- Local environment setup done manually per machine

There's no standard way to invoke a squad agent as an Azure-hosted service, or to have one squad agent call another agent over a defined API interface.

### The Opportunity

`azd ai agent invoke` makes it possible to treat any Azure AI Foundry-deployed agent as a **callable service endpoint** — invokable from a shell script with a single command. Combined with the squad's existing label-based routing, this unlocks two valuable patterns:

#### Pattern 1 — Remote Agent Execution (AKS → Foundry)

Deploy squad agents (or specialized sub-agents) to Azure AI Foundry. Ralph, running on AKS, uses `azd ai agent invoke` to delegate work to the deployed agent instead of spawning a local Copilot CLI process. This decouples agent execution from Ralph's host machine.

```
GitHub Issue (squad:seven label)
  → Ralph picks up on AKS pod
  → azd ai agent invoke "Research #986" --agent seven
  → Foundry-hosted Seven agent processes, returns streamed result
  → Ralph posts result back to the issue
```

#### Pattern 2 — Agent-to-Agent Orchestration (Picard Delegates)

Picard (Lead) can invoke specialist agents as sub-tasks without spawning them as separate Copilot CLI processes. This enables **sequential multi-agent pipelines** from a single orchestrating agent:

```
Picard: "Design feature for issue #986"
  → azd ai agent invoke "Research blog post X" --agent seven
  → await result
  → azd ai agent invoke "Sketch architecture for: {seven's result}" --agent picard-arch
  → await result
  → post combined output to issue
```

#### Pattern 3 — Local Development Loop for Squad Agent Authors

When Tamir or team members want to test a new squad agent behavior locally before deploying, they can use `azd ai agent run` to spin up the agent, then `azd ai agent invoke` to send test prompts — all without touching the production squad loop.

```bash
azd ai agent run seven                               # Start Seven locally
azd ai agent invoke "Write a research doc for X" --local  # Test prompt
```

---

## Concrete Use Cases for Tamir's Team

### 1. Reliable Cross-Machine Agent Execution
**Problem:** Today, if Ralph's machine goes offline, all squad work stops. Agents can't be called from a different machine.  
**Solution:** Deploy critical agents (Seven, Data, Picard) to Azure AI Foundry. Ralph invokes them via `azd ai agent invoke` — the execution happens in the cloud regardless of which Ralph instance is running.

### 2. Faster Agent Authoring Iteration
**Problem:** Testing a new agent behavior requires pushing to GitHub, waiting for Ralph to pick it up, and observing results in issues.  
**Solution:** `azd ai agent run` + `azd ai agent invoke` creates a tight local feedback loop. Author → test → refine entirely in terminal.

### 3. Scripted Agent Tasks from GitHub Actions
**Problem:** Some one-off tasks (generate report, triage batch of issues) could be triggered from CI, not just from Ralph's loop.  
**Solution:** A GitHub Actions workflow can call `azd ai agent invoke "Triage open issues" --agent picard` as a step, using an Azure service principal for auth. No need for a running Ralph instance.

### 4. Cost and Model Isolation
**Problem:** All squad agents currently share the same GitHub Copilot model tier.  
**Solution:** High-cost tasks (deep research, architecture docs) can be routed to a Foundry-hosted agent with a specific model (GPT-4o, o3), while routine tasks stay on the local Copilot CLI. Billing is per-task via Foundry.

---

## Implementation Sketch

### What needs to change in the squad framework

#### 1. Agent Deployment Manifests (`.squad/agents/{name}/foundry.yaml`)
Each agent that can be deployed to Foundry gets a manifest declaring its deployment config:
```yaml
name: seven
description: Research & Docs specialist
runtime: python  # or node
entry: .squad/agents/seven/runner.py
model: gpt-4o
tools:
  - github
  - web_search
  - file_system
```

#### 2. Ralph: Invoke Mode Selection
Ralph's pick-up loop gains a `--execution-mode` flag or environment config:
```
SQUAD_EXECUTION_MODE=foundry   # Use azd ai agent invoke for all agents
SQUAD_EXECUTION_MODE=local     # Use gh copilot (current default)
SQUAD_EXECUTION_MODE=hybrid    # Local for routine, Foundry for labeled agents
```

For `foundry` mode, Ralph replaces:
```powershell
gh copilot suggest --agent seven "Work on issue #986"
```
with:
```powershell
azd ai agent invoke "Work on issue #986" --agent seven
```

#### 3. Squad Charter Extension: `execution` Block
Agent charters get an optional `execution` section:
```markdown
## Execution
- **Mode:** foundry
- **Foundry agent name:** seven-prod
- **Fallback:** local (gh copilot)
```

#### 4. Helm Chart Update (AKS Squad Deployment)
The `infrastructure/helm/squad-agents/` chart gets:
- New values: `foundryEndpoint`, `azdExtensionVersion`
- Init container that installs `azd` + `azure.ai.agents` extension
- Secret mount for Azure AI Foundry credentials

#### 5. `azd` Environment Setup
```bash
# One-time setup per environment
azd extension add azure.ai.agents
azd auth login  # service principal in AKS scenario
azd env set AZURE_AI_PROJECT_NAME squad-agents-prod
```

### Minimal viable path (Phase 1)

Don't deploy agents to Foundry yet. Just use `azd ai agent invoke` with `--local` as an **alternative runner** for squad agents, replacing `gh copilot` in local dev scenarios. This validates the integration with minimal infrastructure change.

**Effort:** ~1–2 days  
**Risk:** Low (additive change, existing flow unchanged)

---

## Priority Recommendation

**Verdict: Later — but design now, implement in Q2 2026.**

### Why not now
- The `azure.ai.agents` extension is at `v0.1.14-preview` — pre-1.0, API stability not guaranteed
- Deploying agents to Azure AI Foundry adds operational surface (cost, monitoring, scaling)
- The current local Ralph + `gh copilot` approach works well for the current squad size

### Why design now
- The squad is actively running on AKS (`infrastructure/helm/squad-agents/`) — Foundry integration is a natural evolution
- Cross-machine reliability (Pattern 1) solves a real pain point: squad goes dark when Ralph's machine is offline
- The CLI-native approach (`azd ai agent invoke`) fits perfectly with the squad's "everything in terminal" philosophy
- Designing the agent manifest format now prevents divergence between local and cloud agent definitions

### Recommended next steps

1. **Picard:** Review this design for architectural alignment — especially the hybrid execution mode and charter extension proposal
2. **B'Elanna:** Spike the Helm chart changes to add `azd` tooling to the AKS pod
3. **Data:** Prototype a minimal `azd ai agent invoke` wrapper that Ralph can call as an alternative to `gh copilot`
4. **Track in:** Create `squad:picard` + `status:needs-decision` label on issue #986 after this review

---

*Seven — Research & Docs*  
*Turns complexity into clarity. If the docs are wrong, the product is wrong.*
