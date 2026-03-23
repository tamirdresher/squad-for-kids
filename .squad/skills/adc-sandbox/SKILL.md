# ADC Sandbox Management Skill

Manage Agent Dev Compute (ADC) sandboxes via the MCP API.

## Prerequisites
- API key stored in Windows Credential Manager as `ADC_API_KEY`
- Key name: `squad-tamresearch1` (expires 6/15/2026)

## MCP Endpoint
- **URL:** `https://management.agentdevcompute.io/mcp`
- **Protocol:** Streamable HTTP with SSE
- **Auth:** `x-api-key` header
- **Server:** adc-mcp-server v1.0.0

## Quick Start

```powershell
# Load API key
$key = "YOUR_API_KEY_HERE"  # Or retrieve from credential store

# MCP call helper
$h = @{ "x-api-key" = $key; "Content-Type" = "application/json"; "Accept" = "application/json, text/event-stream" }

function Invoke-AdcMcp($method, $params, $id=1) {
    $body = @{ jsonrpc = "2.0"; method = "tools/call"; id = $id
               params = @{ name = $method; arguments = $params }
    } | ConvertTo-Json -Depth 10
    $r = Invoke-WebRequest -Uri "https://management.agentdevcompute.io/mcp" -Headers $h -Method POST -Body $body
    $data = ($r.Content -split "`n" | Where-Object { $_ -match '^data: ' }) -replace '^data: ','' -join ''
    ($data | ConvertFrom-Json).result.content[0].text
}

# Initialize session first
$init = @{ jsonrpc="2.0"; method="initialize"; id=0; params=@{
    protocolVersion="2024-11-05"; capabilities=@{}
    clientInfo=@{ name="squad"; version="1.0" }
}} | ConvertTo-Json -Depth 4
Invoke-WebRequest -Uri "https://management.agentdevcompute.io/mcp" -Headers $h -Method POST -Body $init | Out-Null
```

## Available Tools (50+)

### Sandbox Lifecycle
| Tool | Params | Notes |
|------|--------|-------|
| `list_sandboxes` | `{}` | List all sandboxes |
| `get_sandbox` | `{sandboxId}` | Get sandbox details |
| `stop_sandbox` | `{sandboxId}` | Stop a running sandbox |
| `resume_sandbox` | `{sandboxId}` | Resume a stopped sandbox |
| `delete_sandbox` | `{sandboxId}` | Delete a sandbox |
| `create_sandbox` | `{diskImageId, cpuMillicores, memoryMB}` | ⚠️ Blocked: disk images not in MCP scope |

### Command Execution
| Tool | Params | Notes |
|------|--------|-------|
| `execute_command` | `{sandboxId, command}` | Run shell command, returns stdout/stderr/exitCode |

### File Operations
| Tool | Params | Notes |
|------|--------|-------|
| `sandbox_read_file` | `{sandboxId, path}` | Read file content |
| `sandbox_write_file` | `{sandboxId, path, content}` | Write file |
| `sandbox_list_dir` | `{sandboxId, path}` | List directory |
| `sandbox_mkdir` | `{sandboxId, path}` | Create directory |
| `sandbox_stat_file` | `{sandboxId, path}` | Get file metadata |
| `sandbox_delete_file` | `{sandboxId, path}` | Delete file |

### Secrets
| Tool | Params | Notes |
|------|--------|-------|
| `upsert_secret` | `{secretId, data}` | data must be JSON: `{"key":"value"}` |
| `list_secrets` | `{}` | List secret metadata |
| `peek_secret` | `{secretId}` | Retrieve secret values |
| `delete_secret` | `{secretId}` | Delete a secret |

### Lifecycle Policy
| Tool | Params | Notes |
|------|--------|-------|
| `set_lifecycle_policy` | `{sandboxId, autoSuspendEnabled, autoDeleteEnabled}` | Mutable after creation! |

### Connections
| Tool | Params | Notes |
|------|--------|-------|
| `list_connections` | `{}` | 7 connectors: GH Copilot, OneDrive, Teams, M365, O365, ADO, Kusto |

### App Deployment
| Tool | Params | Notes |
|------|--------|-------|
| `create_content_package` | Upload tar.gz first | Returns contentPackageId |
| `deploy_app` | `{contentPackageId, ...}` | Deploy app to sandbox |
| `create_static_site` | `{contentPackageId}` | Deploy static site |

## Workaround: Creating Sandboxes via deploy_app

`create_sandbox` is blocked (can't see public disk images), but `deploy_app` creates a **new sandbox** from a Dockerfile:

```powershell
# 1. Create app context tar.gz
tar -czvf context.tar.gz -C ./my-app .

# 2. Upload content package
$result = curl.exe -s -X POST "https://management.azuredevcompute.io/contentpackages/upload" `
    -H "Content-Type: application/gzip" `
    -H "x-ms-api-key: $key" `
    --data-binary "@context.tar.gz"
$pkgId = ($result | ConvertFrom-Json).id

# 3. Deploy (creates sandbox + builds image)
Invoke-AdcMcp "deploy_app" @{
    contentPackageId = $pkgId
    dockerfile = "FROM node:22-slim`nWORKDIR /app`nCOPY . .`nEXPOSE 3000`nCMD [`"node`",`"server.js`"]"
    exposedPort = 3000
    imageName = "my-agent"
}
# Returns: { sandboxId, diskImageId, appUrl }
```

## Known Limitations
1. **create_sandbox** — Use `deploy_app` workaround (see above)
2. **Agent identity** — `AgentBlueprint` not configured server-side. Need ADC team to enable.
3. **Volume file ops** — Volume must be mounted to a sandbox before file operations work.
4. **set_egress_policy** — Fails with generic error. Egress is readable but not settable via MCP.
5. **REST API** (`/disk-images`, `/connectors`) — 401 with API key, use MCP tools instead.

## Tested Tool Scorecard (25+ working / 50+ total)

### ✅ Working
list_sandboxes, get_sandbox, get_sandbox_debug, stop_sandbox, resume_sandbox, delete_sandbox,
execute_command, sandbox_read_file, sandbox_write_file, sandbox_list_dir, sandbox_mkdir, sandbox_stat_file,
upsert_secret, list_secrets, peek_secret, delete_secret, set_lifecycle_policy,
list_connections, list_ports, add_port, remove_port, create_volume, list_volumes,
get_egress_decisions, deploy_app, create_content_package, create_static_site (needs content pkg)

### ❌ Blocked
create_sandbox (disk image scope), create_agent_identity (AgentBlueprint), create_disk_image,
get_disk_image, set_egress_policy, volume file ops (unmounted)

## Existing Sandboxes
- `d342b3dc` — Running, bare image, 2000m/4Gi, westus2, auto-suspend disabled
- `b985c374` — Stopped, copilot image (gh/node/python), 1000m/2Gi

## GitHub Issues
- tamirdresher_microsoft/adc-research#1 — MCP test results (15 tools)
- tamirdresher_microsoft/adc-research#2 — Agent identity blocker
- tamirdresher_microsoft/adc-research#3 — Connectors inventory
- tamirdresher_microsoft/adc-research#4 — Squad-on-ADC architecture
- tamirdresher_microsoft/adc-research#5 — create_sandbox workaround (deploy_app e2e)
