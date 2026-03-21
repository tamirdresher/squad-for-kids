# Squad + .NET Aspire Integration Research

**Issue:** [#1037 Squad-on-K8s: Aspire integration sub-track](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1037)  
**Related:** [#1046 Durable Task Scheduler + Aspire sample](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1046) | [#1059 K8s architecture](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1059)  
**Status:** Research  
**Owner:** Picard (Lead) + Belanna (Infrastructure)

---

## Executive Summary

.NET Aspire is a strong fit for Squad's local development orchestration story. It solves the hardest parts of running a multi-agent team locally: port management, service discovery, structured logging, and a built-in dashboard. For production (K8s/DK8S), Aspire serves as the manifest generator — producing the Kubernetes YAML that Helm or ArgoCD then deploys.

**Bottom line:** Use Aspire for `F5` local dev; use Helm + ArgoCD for production. The two are complementary, not competing.

---

## 1. What Aspire Brings to Squad

### 1.1 Local Orchestration
Squad agents today are PowerShell processes, Node.js MCP servers, and shell scripts — manually started in separate terminals. Aspire replaces that chaos with a single `dotnet run` in `SquadAppHost`:

- All agents start in dependency order
- Ports auto-allocated and conflict-free
- Environment variables injected into every resource
- One `Ctrl+C` shuts the entire team down cleanly

### 1.2 Service Discovery
Aspire injects `{ResourceName}_URLS` environment variables so agents find each other without hard-coded ports. Ralph doesn't need to know Picard's port — Aspire provides `PICARD_URLS=http://localhost:7234` at startup.

For Squad, this maps to:
- MCP server endpoints (Ralph → Picard's MCP server)
- Agent health endpoints
- Squad monitor API

### 1.3 Built-in Dashboard
Aspire's developer dashboard (http://localhost:15888 by default) provides:
- **Resources view** — all agents with status (Running / Stopped / Error)
- **Console logs** — per-agent stdout/stderr, searchable
- **Structured logs** — OpenTelemetry-formatted entries
- **Distributed traces** — cross-agent request flows
- **Metrics** — CPU, memory, custom metrics

For Squad: Ralph heartbeats, agent task completions, and decision inbox writes all become observable events in the dashboard without any extra instrumentation code.

### 1.4 Multi-Language Support (Aspire 9+)
Squad agents are polyglot — PowerShell, Node.js, Python, .NET. Aspire 9+ supports:
- `.NET` services (APIs, workers)
- `Node.js` apps via `AddNpmApp()`
- `Python` apps via `AddPythonApp()`
- `Executable` / process launch for PowerShell scripts

This means Ralph (PowerShell), Seven (Node.js MCP server), and SquadMonitor (.NET API) can all live as first-class Aspire resources in the same AppHost.

### 1.5 MCP Server Integration
The Aspire MCP server (already in Squad's mcp-config.json) allows AI agents to query Aspire programmatically:
- List running resources
- Stream logs from a specific resource
- Check health status
- Trigger resource restarts

This creates a closed loop: Picard can ask the Aspire MCP "is Ralph healthy?" and get a real-time answer.

---

## 2. Integration Model: Squad Agents as Aspire Resources

### Resource Type Mapping

| Squad Component | Aspire Resource Type | Notes |
|---|---|---|
| Ralph (watcher loop) | `AddExecutable()` or `AddDockerfile()` | PowerShell process or containerized |
| Picard (Lead agent) | `AddDockerfile()` | Copilot CLI container |
| Seven (Research) | `AddNpmApp()` | Node.js MCP server |
| Belanna (Infrastructure) | `AddDockerfile()` | K8s/Helm specialist container |
| Squad Monitor | `AddProject<SquadMonitor>()` | .NET Blazor/API project |
| MCP Servers | `AddNpmApp()` or `AddExecutable()` | gh MCP, ADO MCP, etc. |
| Redis (work queue) | `AddRedis()` | Built-in Aspire hosting |
| PostgreSQL (state) | `AddPostgres()` | If SQLite-on-PV is insufficient |

### Containerization Decision
Two viable models:

**Model A — Process-native (recommended for dev)**
```
AppHost launches agents as local processes.
Ralph = PowerShell process, Seven = node process.
Fast startup, easy debugging, full file system access.
```

**Model B — Container-native (recommended for CI/production parity)**
```
AppHost uses AddDockerfile() for each agent.
Each agent has a Dockerfile with its dependencies.
Closer to K8s production reality but slower inner loop.
```

**Recommendation:** Start with Model A for day-to-day dev. Use Model B Dockerfiles for CI and K8s manifest generation.

---

## 3. AppHost Design for Squad

### Directory Structure
```
squad/
  SquadAppHost/
    Program.cs          ← orchestration entrypoint
    SquadAppHost.csproj
  SquadMonitor/         ← existing .NET project
  agents/
    ralph/
      Dockerfile
      ralph-watch.ps1
    seven/
      Dockerfile
      package.json
    picard/
      Dockerfile
```

### AppHost Program.cs (Prototype)
```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Infrastructure dependencies
var redis = builder.AddRedis("squad-redis")
    .WithDataVolume("squad-redis-data");

// Squad Monitor API (health endpoint for all agents)
var squadMonitor = builder.AddProject<Projects.SquadMonitor>("squad-monitor")
    .WithReference(redis)
    .WithHttpHealthCheck("/health");

// Ralph — the orchestrator heartbeat process
var ralph = builder.AddExecutable("ralph",
        "pwsh",
        workingDirectory: "../..",
        args: ["-File", "ralph-watch.ps1", "-DryRun"])
    .WithEnvironment("SQUAD_REDIS_URL", redis.GetEndpoint("tcp"))
    .WithEnvironment("SQUAD_MONITOR_URL", squadMonitor.GetEndpoint("http"));

// Seven — Research MCP server (Node.js)
var sevenMcp = builder.AddNpmApp("seven-mcp", "../agents/seven")
    .WithNpmPackageInstallation()
    .WithEnvironment("PORT", "0")  // Aspire assigns port
    .WithHttpEndpoint(name: "mcp");

// Picard — Lead agent (containerized for consistency)
var picard = builder.AddDockerfile("picard", "../agents/picard")
    .WithReference(sevenMcp)
    .WithReference(squadMonitor)
    .WithEnvironment("SEVEN_MCP_URL", sevenMcp.GetEndpoint("mcp"));

builder.Build().Run();
```

### Health Endpoint Pattern for Ralph
Ralph currently has no HTTP server. For Aspire health checking, add a minimal health endpoint:

```powershell
# ralph-watch.ps1 addition
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$env:RALPH_HEALTH_PORT/health/")
$listener.Start()

# Background thread responds to health checks
$healthJob = Start-Job {
    while ($true) {
        $context = $listener.GetContext()
        $response = $context.Response
        $response.StatusCode = 200
        $responseBody = '{"status":"Healthy","lastHeartbeat":"' + $script:lastHeartbeat + '"}'
        $buffer = [Text.Encoding]::UTF8.GetBytes($responseBody)
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()
    }
}
```

This satisfies issue #1037's acceptance criterion: _"Ralph exposes Aspire-compatible health endpoint"_.

---

## 4. Service Mesh: Agent Communication via Aspire

### Current State
Agents communicate through the file system (`.squad/inbox/`, `decisions/`, `heartbeats/`). This works locally but doesn't scale to K8s.

### Aspire Service Discovery Layer
Aspire injects named endpoints as environment variables:
```
RALPH_HTTP=http://localhost:5001
SEVEN_MCP_HTTP=http://localhost:5234
SQUAD_MONITOR_HTTP=http://localhost:7000
```

Agents that need to send tasks to each other can POST to these URLs instead of writing files. This is the bridge between the current file-based model and a proper K8s-ready service mesh.

### Migration Path
```
Phase 1 (now):     File system coordination (current model)
Phase 2 (Aspire):  File system + HTTP health/status endpoints
Phase 3 (K8s):     HTTP-native coordination with K8s Services
```

### Service Discovery in K8s
When Aspire generates K8s manifests (via `aspirate` or the built-in publisher), each `AddDockerfile()` resource becomes a `Deployment` + `Service`. The service names match the Aspire resource names, so `ralph` becomes `ralph.squad.svc.cluster.local`. No code changes needed between environments.

---

## 5. Aspire Dashboard for Squad Agent Health

### What Agents Should Emit

**Structured Logs** (OpenTelemetry-compatible):
```json
{
  "agent": "ralph",
  "event": "heartbeat",
  "timestamp": "2025-03-20T08:00:00Z",
  "state": "healthy",
  "active_tasks": 3,
  "last_commit": "abc1234"
}
```

**Metrics to expose:**
- `squad.ralph.tasks_processed` (counter)
- `squad.ralph.queue_depth` (gauge)
- `squad.agent.response_latency_ms` (histogram per agent)
- `squad.decisions.inbox_size` (gauge)

**Health Check Responses:**
```json
{
  "status": "Healthy",
  "checks": {
    "git_repo": "Healthy",
    "mcp_servers": "Healthy",
    "last_heartbeat_age_seconds": 45
  }
}
```

### Squad Monitor as Aspire Dashboard Extension
Issue #1037 asks for Squad Monitor to integrate with the Aspire dashboard. The path:

1. Squad Monitor exposes `/health` (already exists in `SquadMonitor.csproj`)
2. Each agent registers with Squad Monitor on startup
3. Squad Monitor aggregates and forwards metrics to OpenTelemetry Collector
4. Aspire Dashboard shows unified view of all agent health

---

## 6. Durable Task Scheduler Integration (Issue #1046)

### The Pattern
The Durable Task Scheduler (DTS) is a natural fit for long-running Squad workflows:

```
Ralph detects new issue → schedules DTS orchestration
  → DTS orchestration:
      1. Activity: Research (Seven)
      2. Activity: Architecture review (Picard)
      3. Activity: Write ADR (Scribe)
      4. Activity: Create PR (Worf)
      5. Activity: Post to Teams (Neelix)
```

### Aspire + DTS AppHost Addition
```csharp
// Add Durable Task Scheduler emulator for local dev
var dts = builder.AddDurableTaskScheduler("dts-emulator")
    .WithDataVolume("dts-data");

// Ralph becomes a DTS worker (not just a scheduler)
var ralph = builder.AddProject<Projects.Ralph>("ralph")
    .WithReference(dts)
    .WithReference(redis)
    .WithEnvironment("DTS_ENDPOINT", dts.GetEndpoint("grpc"));
```

### DK8S Provisioning Flow Example
Per issue #1046, a real-world DTS orchestration for DK8S:
```
NewClusterOrchestration:
  1. ValidateClusterConfig (Activity)
  2. RunTerraformPlan (Activity)  
  3. WaitForApproval (ExternalEvent — wait for human)
  4. ApplyTerraform (Activity)
  5. ConfigureArgoCD (Activity)
  6. RunSmokeTests (Activity)
  7. NotifyTeam (Activity)
```

This maps directly to how Belanna and Picard work today — the DTS makes it durable and restartable.

---

## 7. Development vs. Production

### Local Development (Aspire)
```
dotnet run --project SquadAppHost
→ Starts all agents locally
→ Dashboard at http://localhost:15888
→ Hot reload for .NET services
→ File-based git coordination (current model preserved)
```

### Production (K8s via Aspire manifest)
```
aspirate generate
→ Produces kubernetes/ YAML folder
→ Ralph → CronJob or Deployment
→ Agents → Deployments with health probes
→ MCP servers → Services
→ Helm chart wraps the YAML
→ ArgoCD deploys from git
```

### Environment Parity Matrix

| Capability | Local (Aspire) | CI | K8s (Helm) |
|---|---|---|---|
| Ralph heartbeat | Process | Container | CronJob/Deployment |
| Agent discovery | Aspire env vars | Aspire env vars | K8s Services |
| Health checks | HTTP `/health` | HTTP `/health` | livenessProbe |
| Dashboard | Aspire Dashboard | N/A | Squad Monitor |
| State | File system / git | File system / git | PV + git |
| Work queue | In-memory / Redis | Redis | Redis (AKS managed) |
| DTS | Local emulator | Local emulator | Azure DTS (managed) |

---

## 8. Prototype Plan: Minimal Aspire AppHost

### Sprint Goal
Get Ralph visible in the Aspire dashboard with a health check. Everything else is additive.

### Phase 1 — Ralph Health Endpoint (1 day)
- [ ] Add minimal HTTP health listener to `ralph-watch.ps1`
- [ ] Endpoint: `GET /health` → `{"status":"Healthy"}`
- [ ] Test with `Invoke-WebRequest`

### Phase 2 — AppHost Skeleton (1 day)
- [ ] Create `SquadAppHost/` project (`dotnet new aspire-apphost`)
- [ ] Add Ralph as `AddExecutable("ralph", "pwsh", ...)`
- [ ] Add Squad Monitor as `AddProject<SquadMonitor>()`
- [ ] Verify both appear in dashboard

### Phase 3 — Service Discovery Wiring (2 days)
- [ ] Inject `RALPH_URL` into Squad Monitor
- [ ] Squad Monitor polls Ralph `/health` and aggregates status
- [ ] Dashboard shows unified health panel

### Phase 4 — DTS Integration (3 days)
- [ ] Add DTS emulator to AppHost
- [ ] Prototype `NewIssueOrchestration` with 2 activities
- [ ] Test with a real issue from the board

### Phase 5 — K8s Manifest Generation (2 days)
- [ ] Run `aspirate generate` against AppHost
- [ ] Review produced manifests
- [ ] Wrap in Helm chart skeleton (relates to #1059)

---

## 9. Decisions

**Decision 1: Process-native first, container-native second**  
Use `AddExecutable()` for initial prototype. Dockerfile-based resources add friction during active development. Switch to containers when targeting K8s manifest generation.

**Decision 2: File-based coordination preserved in Aspire phase**  
Don't migrate from file-based `.squad/` coordination to HTTP in Phase 1-2. Let Aspire add observability without changing the core coordination model. HTTP-native coordination is a Phase 3 concern tied to K8s deployment.

**Decision 3: Aspirate for manifest generation**  
Use the [`aspirate`](https://github.com/prom3theu5/aspirational-manifests) tool (or Aspire's built-in publisher) to generate K8s manifests from the AppHost. This ensures dev/prod parity at the manifest level.

---

## 10. Open Questions

1. **Ralph container base image**: Windows (for PowerShell 7 + gh CLI) vs. Linux (mcr.microsoft.com/powershell). Linux is strongly preferred for K8s. Need to validate `ralph-watch.ps1` runs on Linux PowerShell.

2. **Copilot CLI in containers**: Does `gh copilot` work in a headless container with PAT auth? Need to test before committing to the container model for Picard/Seven.

3. **DTS managed vs. emulated**: For DK8S production use, does the team have access to the Azure Durable Task Scheduler managed service, or do we run the scheduler ourselves in K8s?

4. **Aspire version**: Squad currently uses Aspire MCP (9.x). The AppHost should target the same version for consistency.

---

## References

- `aspire-research-summary.txt` — Prior research on Aspire for 1P AKS
- `squad-monitor-standalone/` — Existing Squad Monitor .NET project
- `docs/adr/` — Architecture Decision Records folder
- [.NET Aspire docs](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [Aspirate tool](https://github.com/prom3theu5/aspirational-manifests) — K8s manifest generation
- [Azure Durable Task Scheduler](https://learn.microsoft.com/en-us/azure/azure-functions/durable/durable-functions-overview)
- Issue #1059 — K8s architecture (Helm chart structure, CronJob vs Deployment decision)
