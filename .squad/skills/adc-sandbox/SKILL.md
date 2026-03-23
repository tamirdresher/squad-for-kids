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

## Known Limitations
1. **create_sandbox blocked** — MCP API key can't see public disk images. Create sandboxes via portal UI first.
2. **Agent identity blocked** — AgentBlueprint not configured server-side.
3. **REST API endpoints** (`/disk-images`, `/connectors`) return 401 with API key — use MCP tools instead.

## Existing Sandboxes
- `d342b3dc` — Running, bare image, 2000m/4Gi, westus2, auto-suspend disabled
- `b985c374` — Stopped, copilot image, 1000m/2Gi, auto-suspend 300s

## GitHub Issues
- tamirdresher_microsoft/adc-research#1 — MCP test results
- tamirdresher_microsoft/adc-research#2 — Agent identity blocker
- tamirdresher_microsoft/adc-research#3 — Connectors inventory
