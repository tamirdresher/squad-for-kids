# Decision: Standalone Squad-Monitor Repository Structure

**Date:** 2025-01-08  
**Agent:** Data  
**Issue:** #229  
**Status:** Implemented  

## Context

Issue #229 requested creating a standalone repository structure for squad-monitor, making it shareable as an open-source observability tool for GitHub Copilot agent workflows. The existing squad-monitor was located at `.squad/tools/squad-monitor/` and contained Microsoft-specific references, Teams webhooks, and internal tooling patterns.

## Decision

Create a complete standalone repository at `squad-monitor-standalone/` with the following structure:

```
squad-monitor-standalone/
├── src/SquadMonitor/
│   ├── Program.cs           # Sanitized dashboard (1400+ lines)
│   ├── AgentLogParser.cs    # NEW: Live agent log parser
│   └── SquadMonitor.csproj  # .NET 8 project
├── automation-watch.ps1     # Sanitized automation loop
├── README.md                # Comprehensive documentation
├── QUICKSTART.md            # 5-minute setup guide
├── LICENSE                  # MIT License
└── .gitignore               # .NET-specific
```

### Key Architecture Decisions

#### 1. .NET 8 Target (Not .NET 10)

**Decision:** Target .NET 8 instead of .NET 10 (which the original used).

**Rationale:**
- Broader compatibility — .NET 8 is LTS, widely deployed
- .NET 10 is preview/bleeding-edge, may not be stable for external users
- Nothing in the codebase requires .NET 10 features

#### 2. AgentLogParser.cs — NEW Component

**Decision:** Create a new `AgentLogParser` class that tails GitHub Copilot CLI agent logs and parses structured events.

**Rationale:**
- Issue #229 explicitly requested live agent log parsing
- Provides real-time visibility into what Copilot agents are doing
- Complements existing orchestration log display
- Enables monitoring of tool calls, sub-agent spawns, task launches

**Implementation Pattern:**
- File tailing with `FileStream(FileMode.Open, FileAccess.Read, FileShare.ReadWrite)`
- Maintains file position dictionary to avoid re-parsing
- Rolling buffer (max 50 entries) to prevent unbounded memory growth
- Regex-based parsing for structured log patterns

**Parsed Events:**
1. Tool invocations: `Tool invocation result: {toolName}`
2. Sub-agent spawns: `"agent_type": "{type}"`
3. Task launches: `"name": "task"` with `"description"`
4. Agent completions: `(agent|task) (completed|finished|done)`

#### 3. Configurable Config Directory

**Decision:** Add `--config-dir` flag to override default `.squad/` and `~/.squad/` paths.

**Rationale:**
- Makes tool more flexible for different deployment scenarios
- Allows multiple isolated configurations on same machine
- Follows Unix/Linux tool conventions (e.g., `--config`, `--home`)

**Implementation:**
```csharp
var configDir = ".squad"; // default
if (args contains "--config-dir") {
    configDir = args[nextArg];
}
```

#### 4. Cross-Platform Path Handling

**Decision:** Use `Path.Combine()` throughout, no hardcoded path separators.

**Rationale:**
- Ensures tool works on Windows, macOS, Linux
- Avoids common portability bugs (e.g., `/` vs `\`)
- Standard .NET best practice

#### 5. Sanitization Strategy

**Decision:** Remove ALL Microsoft-specific content and sensitive data:
- Teams webhook URLs → `https://your-teams-webhook-url`
- Internal project names (DK8S) → `your-project`
- Personal names → generic examples
- Azure resource IDs → removed
- Internal team references → removed

**Rationale:**
- Required for open-source release
- Protects internal Microsoft information
- Makes tool usable for any team/organization

#### 6. Documentation Structure

**Decision:** Create two documentation files:
1. **README.md** — Comprehensive (11KB, covers architecture, features, usage, troubleshooting)
2. **QUICKSTART.md** — 5-minute setup guide (installation → running in 3 steps)

**Rationale:**
- README.md provides full context for maintainers and advanced users
- QUICKSTART.md reduces time-to-first-run for new users
- Follows open-source project conventions (e.g., React, Kubernetes)

## Alternatives Considered

### Alternative 1: Keep .NET 10 Target

**Rejected:** .NET 10 is not LTS, reduces audience, no benefits for this tool.

### Alternative 2: Embed Agent Log Parsing in Program.cs

**Rejected:** Separate class is cleaner, testable, reusable. `AgentLogParser` could be extracted to a library later.

### Alternative 3: Hard-code .squad Path

**Rejected:** `--config-dir` flag adds minimal complexity, significant flexibility.

### Alternative 4: Minimal Sanitization (Keep Some Internal Refs)

**Rejected:** For open-source release, MUST be fully sanitized. No exceptions.

## Implementation Details

### Build Configuration

```xml
<PropertyGroup>
  <TargetFramework>net8.0</TargetFramework>
  <PublishSingleFile>true</PublishSingleFile>
  <SelfContained>false</SelfContained>
</PropertyGroup>
```

- `SelfContained=false` → Smaller binary, requires .NET 8 runtime installed
- `PublishSingleFile=true` → Single executable (easier distribution)

### AgentLogParser Usage

```csharp
var parser = new AgentLogParser(); // Uses ~/.agency/logs by default
parser.ParseLatestLogs();          // Parses new log entries
var entries = parser.GetRecentEntries(); // Returns List<AgentLogEntry>
```

### automation-watch.ps1 Changes

- Renamed "Ralph" → "Automation" (generic)
- Removed Teams webhook URL (now reads from `~/.squad/webhook.url`)
- Removed Microsoft-specific prompt (replaced with generic example)
- Removed internal tooling references

## Consequences

### Positive

✅ Squad-monitor is now shareable as an open-source tool  
✅ Live agent log parsing provides real-time visibility  
✅ Cross-platform friendly (.NET 8, Path.Combine)  
✅ Configurable for different deployments (--config-dir)  
✅ Comprehensive documentation (README + QUICKSTART)  
✅ MIT license enables wide adoption  

### Negative

⚠️ .NET 8 requirement may limit some users (but .NET 8 is LTS)  
⚠️ Agent log parsing depends on undocumented log format (may break if Copilot CLI changes)  
⚠️ No automated tests (future work)  

### Neutral

ℹ️ Requires manual extraction to new GitHub repo (cannot be automated from here)  
ℹ️ NuGet package publishing is future work (after repo extraction)  

## Next Steps

1. **Merge PR #231** — Get standalone structure into main branch
2. **Extract to new repo** — Create `github.com/microsoft/squad-monitor` (or similar)
3. **CI/CD setup** — Add GitHub Actions for build/test/publish
4. **NuGet package** — Publish as `dotnet tool install -g squad-monitor`
5. **Community release** — Blog post, announcement, documentation site

## References

- Issue #229: https://github.com/tamirdresher_microsoft/tamresearch1/issues/229
- PR #231: https://github.com/tamirdresher_microsoft/tamresearch1/pull/231
- Original squad-monitor: `.squad/tools/squad-monitor/`
- Standalone location: `squad-monitor-standalone/`

## Team Consensus

**Data (implementer):** ✅ Implemented per issue requirements  
**Awaiting review from:** Tamir Dresher (project owner)  

---

**Decision Status:** ✅ IMPLEMENTED  
**Build Status:** ✅ VERIFIED (dotnet build succeeds, 1.2s)  
**PR Status:** 🔄 OPEN (#231)  
