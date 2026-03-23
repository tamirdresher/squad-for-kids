# Squad — Azure AI Foundry Phase 1

Cloud-resident Squad agents via `azd ai agent invoke`.  
Tracks **issue #986**: [Thats cool, can we build a feature for our squad around this?](https://github.com/tamirdresher_microsoft/tamresearch1/issues/986)

---

## What This Does

Deploys an **Azure AI Foundry Hub + Project** and registers **Seven** (Research & Docs) as the first cloud-resident Squad agent. Once deployed, any trigger — GitHub Actions, Teams bot, cron job — can invoke Seven without needing a local machine.

```
azd ai agent invoke "Summarize issue #986 and write a research report" --agent seven
```

---

## Architecture

```
Azure Resource Group: squad-rg-<env>
├── Azure AI Foundry Hub        (squad-ai-hub-<env>)
│   └── AI Foundry Project      (squad-ai-project-<env>)
│       └── Agent: seven        (system prompt = Seven's charter)
├── Storage Account             (squadstorage<env>)   ← required by Hub
├── Key Vault                   (squad-kv-<env>)      ← required by Hub
└── Log Analytics Workspace     (squad-logs-<env>)    ← observability
```

**Cost profile:** Uses the **consumption / serverless** tier where available. Foundry agents are billed per token, not per hour. Estimated Phase 1 cost: ~$0–$5/month for light usage.

---

## Prerequisites

1. **Azure CLI** — `az version` should show ≥ 2.55
2. **Azure Developer CLI (azd)** — `azd version` should show ≥ 1.9
3. **azd ai.agents extension** — installed in setup step below
4. **Azure subscription** with Contributor access on the target resource group
5. **Azure AI Foundry availability** — check your region supports it (eastus2 recommended)

---

## Setup

### 1. Install the `azure.ai.agents` extension

```bash
azd extension add azure.ai.agents
azd extension list   # confirm azure.ai.agents appears
```

### 2. Authenticate

```bash
az login
azd auth login
```

### 3. Set environment

```bash
cd infrastructure/azd-ai-agent
azd env new squad-dev          # creates .azure/squad-dev/
azd env set AZURE_LOCATION eastus2
azd env set AZURE_RESOURCE_GROUP squad-ai-rg   # or existing RG
```

### 4. Deploy infrastructure

```bash
azd provision          # deploys Bicep: Hub, Project, Storage, KV, Log Analytics
```

### 5. Deploy Seven agent

```bash
azd deploy seven       # uploads Seven's system prompt and tool config to Foundry
```

### 6. Smoke test

```bash
azd ai agent invoke "Hello — summarize what Squad is in one paragraph" --agent seven
```

---

## Agent: Seven

Seven is the **Research & Docs** agent. She's the pilot for cloud deployment because she has no filesystem dependencies — her work is purely API-based (GitHub reads, web research, document writing).

**System prompt:** `.squad/agents/seven/charter.md`  
**Tools enabled in Foundry:**
- GitHub read (issues, PRs, code search) via MCP
- Web search (Bing)

**What she can be invoked for:**
- Research analysis on issues
- Writing documentation, summaries, blog drafts
- Answering questions about the repo

---

## Phase Roadmap

| Phase | Owner | Status | Description |
|-------|-------|--------|-------------|
| **Phase 1** | B'Elanna | 🚧 In Progress | Azure AI Foundry infra + Seven deployed |
| **Phase 2** | Data | ⏳ Planned | GitHub Actions bridge — `go:seven` label triggers cloud invoke |
| **Phase 3** | B'Elanna + Data | ⏳ Planned | Expand to Worf, Picard; `azd up` deploys full squad |

---

## Windows Compatibility Note

> ⚠️ Seven's Action note from issue #986: The `azd ai agent run` blog examples show Linux/macOS. Squad's DevBox runs Windows.

The GitHub Actions workflow (Phase 2) runs on `ubuntu-latest` — that path is safe.  
For local Windows usage, `azd ai agent invoke` (without `run`) should work via `azd.exe`. Verify with:

```powershell
azd version
azd extension list
azd ai agent invoke "test" --agent seven
```

If the extension fails on Windows, Phase 2 Actions workflow is the unblocked path.

---

## Files

```
infrastructure/azd-ai-agent/
├── README.md                   ← this file
├── azure.yaml                  ← azd project config (agents declared here)
├── infra/
│   └── main.bicep              ← Azure AI Foundry Hub, Project, dependencies
└── agents/
    └── seven/
        ├── agent.yaml          ← Seven's agent manifest (tools, model config)
        └── system-prompt.md    ← Seven's system prompt (sourced from charter)
```
