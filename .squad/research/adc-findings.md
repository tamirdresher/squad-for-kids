## ADC (Agent Dev Compute) Research Findings

### What ADC Is

ADC is an **internal Microsoft platform for managing microVM sandboxes** — lightweight, hardware-isolated virtual machines for secure, ephemeral dev/agent compute.

- **Portal**: https://portal.agentdevcompute.io/ ("ADC Management Console")
- **Management API**: https://management.agentdevcompute.io/ (REST, `/health` returns "Healthy")
- **Test env**: `*.azuredevcompute-test.io`
- **Auth**: Microsoft Entra ID or GitHub OAuth (cookie-based sessions)

### Architecture & Concepts

| Concept | Description |
|---------|------------|
| **Sandboxes** | MicroVM instances — start/stop/resume, ports, egress rules |
| **Sandbox Groups** | Containers for organizing multiple sandboxes |
| **Disk Images** | Base OS images (public + private) |
| **Snapshots** | Point-in-time sandbox state captures |
| **Volumes** | Shared storage with file upload/download |
| **Connections** | External service connections (GitHub, Copilot) |
| **API Keys** | Programmatic access tokens |
| **Agent Identities** | Identity configs for agents in sandboxes |

### Entra ID App Registration

- **App ID**: `8bdf6603-4e80-4b34-856c-4ee02dfe8df3`
- **Tenant**: `72f988bf-86f1-41af-91ab-2d7cd011db47` (Microsoft corp)
- **Scope**: `AzureDevCompute.Portal.ReadWrite.All`
- **Token**: `az account get-access-token --resource "8bdf6603-4e80-4b34-856c-4ee02dfe8df3"` ✅ works

### Key API Endpoints (reverse-engineered from JS bundle)

**Sandbox ops:**
- `PUT /sandboxes?includeDebug=true` — Create sandbox
- `POST /sandboxes/{id}/executeShellCommand` — ⚡ Run commands in sandbox
- `POST /sandboxes/{id}/stop | /resume` — Lifecycle management
- `POST /sandboxes/{id}/ports/add | /remove` — Port management
- `POST /sandboxes/{id}/egresspolicy` — Network egress rules

**Storage:** `/volumes/{id}/files` (upload, download, mkdir, list)
**Auth:** `/auth/me`, `/auth/isAdmin`, `/apikeys` (CRUD)
**Images:** `/diskimages/{id}`, `/public/diskimages/{id}`
**Connections:** `/connections?includeSandboxIds=true`, `/connections/copilotStatus`

### Auth Status

| Method | Status |
|--------|--------|
| Entra token via az cli | ✅ Token with correct scope acquired |
| Bearer token to API | ❌ 401 — API uses cookie-based session auth |
| API Keys | 🔑 Available via portal — need browser login first |

**Key finding**: API uses OAuth redirect → cookie flow. Need to login via portal first, then generate API key for programmatic access.

### Ralph-Relevant Capabilities

- `POST /sandboxes/{id}/executeShellCommand` — run arbitrary shell commands
- Port exposure with Entra ID/GitHub auth + IP ACLs
- Configurable egress (allow `*.github.com`, etc.)
- File upload/download via volumes API
- GitHub + Copilot connections available
- MicroVMs designed for agent workloads — no idle timeout

### DTS (Developer Task Service)

Per Anirudh: "ADC is the raw sandboxed compute and DTS creates queues and spawns work on your behalf — orchestration layer." No public docs found for DTS API — need to reach out to Anirudh.

### Proposed Plan to Run Ralph on ADC

1. Log into portal → generate API key
2. List disk images → find one with PowerShell/Node.js
3. Create sandbox → configure egress for GitHub
4. Upload `ralph-watch.ps1` via volumes
5. `POST /executeShellCommand` to start Ralph
6. (Optional) Expose health port for monitoring

### Next Steps

- [ ] Manual portal login — explore UI, generate API key
- [ ] Watch Anirudh's video for DTS walkthrough
- [ ] Test API key auth on all endpoints
- [ ] POC: create sandbox, clone repo, run script
- [ ] Compare cost/perf vs DevBox

### ADC vs DevBox

| Aspect | DevBox | ADC |
|--------|--------|-----|
| Idle timeout | ⚠️ Yes (#700) | ✅ No |
| Startup | ~minutes | ~seconds |
| Cost | ~$0.50-2/hr | Unknown |
| Scaling | 1 per box | N sandboxes |
| Shell | Full RDP | executeShellCommand API |
| Network | Full | Configurable egress |

