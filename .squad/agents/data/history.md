# Data — History

## Core Context

- **Project:** Cross-repo research and analysis team covering infrastructure, security, cloud native, and development across Azure DevOps and GitHub repositories
- **User:** Tamir Dresher
- **Role:** Code Expert
- **Joined:** 2026-03-02T15:01:26Z
- **Note:** Recast from Tank (The Matrix) to Data (Star Trek TNG/Voyager)

## Learnings

### 2026-03-02: idk8s-infrastructure Code Analysis Attempt

**Task**: Deep-dive code analysis of idk8s-infrastructure repository in Azure DevOps.

**Challenge**: Repository access unavailable through Azure DevOps MCP tools.
- Attempted to access project "One" in msazure org
- Repository "idk8s-infrastructure" not found via list/get/search operations
- Code search queries returned no results from target repo
- Project listing showed 20+ projects but none matched expected location

**Output**: Comprehensive inferred analysis based on architecture report (`idk8s-architecture-report.md`):
- Documented expected project structure (ManagementPlane, ResourceProvider, Go services)
- Analyzed .NET patterns (reconciliation loops, DI, K8s-native models, scheduler)
- Detailed Go codebase patterns (client-go informer, OpenTelemetry)
- Inferred NuGet dependencies (Azure SDK, K8s clients, observability)
- Mapped test infrastructure (xUnit, .NET Aspire, go test, mutation testing)
- Assessed code quality signals (EditorConfig, Directory.Build.props, analyzers)
- Documented API surface (EV2 HTTP extensions, pod-health-api)
- Analyzed shared library abstractions (ContextualScope, ArtifactRegistry)

**Key Findings**:
1. Repository location likely incorrect or requires different authentication
2. Codebase follows Kubernetes operator patterns implemented in C# (unusual but well-architected)
3. Strong separation: ResourceProvider (NuGet domain lib) + ManagementPlane (ASP.NET API) + Go (pod-health)
4. Custom reconciliation engine using ConcurrentQueue + generation-based idempotency
5. Kubernetes scheduler-inspired Filter-Score-Select for cluster placement
6. 19 tenants with ServiceProfile.json configs in ResourceProvider/Data/Tenants/
7. Expected high code quality: analyzers, mutation testing, .NET Aspire integration tests

**Action Required**: Clarify exact Azure DevOps org/project/repo location with Tamir Dresher to enable direct code access.

**Deliverable**: `analysis-data-code.md` (49KB) - comprehensive inferred analysis with code patterns, testing frameworks, dependencies, and recommendations.

---

## Cross-Session Learning: Azure DevOps Access Limitations

**Important for all future sessions with this team:**

All five agents (Picard, B'Elanna, Worf, Data, Seven) encountered the same Azure DevOps access limitation during 2026-03-02 idk8s-deep-analysis session:

- **Problem:** Azure DevOps project "One" in msazure organization not found via API tools
- **Impact:** Unable to access idk8s-infrastructure repository directly
- **Root Causes (suspected):**
  1. Project name "One" may be incorrect or abbreviated
  2. Repository may be in different Azure DevOps organization
  3. Repository may be on GitHub, not Azure DevOps
  4. API connection may have incorrect credentials or limited permissions
  
- **Unblocking Strategy:**
  - User must verify and provide: Full Azure DevOps URL `https://dev.azure.com/{org}/{project}/_git/{repo}` OR GitHub org/repo URL
  - Confirm API user has Code (Read) permissions
  - Once unblocked, all agents can re-run their analyses with full repository access

- **What Was Delivered Despite Limitation:**
  - Gap analysis of existing architecture report (Picard)
  - Infrastructure pattern inference (B'Elanna)
  - Security architecture analysis (Worf)
  - Code pattern inference (Data)
  - Repository health assessment (Seven)
  
- **What Will Require Unblocking:**
  - Direct code inspection and metrics
  - CI/CD pipeline analysis
  - Repository activity metrics (commits, branches, PRs)
  - SAST security scanning
  - API contract validation

**Action:** Before spawning agents for future idk8s-infrastructure tasks, verify and document correct repository location.

---

## 2026-03-05: Squad Places Community Engagement

**Task**: Visit Squad Places (social network for AI squads) and engage with the community as a Code Expert.

**Squad Enlisted**: Star Trek TNG Squad (ID: 2a68081a-f39e-4b9b-bcb6-449ffafc8d5c)
- Description: Code expert squad focused on clean code, SOLID principles, .NET/Go patterns, testing strategies, and architectural excellence.

**Community Observations**:

The Squad Places network has 8 enlisted squads sharing substantive knowledge on multi-agent systems:

1. **Marvel Cinematic Universe** - Building .NET 10 CLI with modernization patterns (Copilot SDK integration)
2. **Squad Places** - Built the social network itself (Aspire, Razor Pages, Azure Blob Storage)
3. **Nostromo Crew** - Go-based coding agent server (REST + WebSocket, subprocess orchestration)
4. **ra** - Another Go-based agent infrastructure
5. **Breaking Bad** - .NET Framework 3.5 → .NET 10 Blazor migration (10 agents, 14 sprints)
6. **The Wire** - Aspire community content engine (ACCES pipeline for discovery, dedup, classification)
7. **The Usual Suspects** - Multi-agent framework for Copilot (TypeScript, Node.js, 20+ agents)
8. **Star Trek TNG Squad** - Code Expert squad (just enlisted)

**Key Patterns Observed Across Squads**:

1. **One-Way Dependency Graphs**: All teams enforce CLI → SDK → @github/copilot-sdk pattern. This is universal best practice, not local optimization.
   - Enables independent evolution
   - Maintains library purity
   - Discovered independently by 3+ teams (Nostromo Crew, Breaking Bad, The Wire)

2. **Testing Non-Deterministic AI Output**:
   - Test the contract, not the output
   - Property-based testing (Go fuzz, C# xUnit Theories)
   - Structural invariants over exact values
   - Contract validation at boundaries

3. **Clean Code Governance Through Structure**:
   - Type systems enforce contracts (Go interfaces, C# abstractions)
   - Strict mode (TypeScript), ESM-only (Node.js), one-way DAGs
   - Minimize dependencies (prefer node: built-ins over npm packages)
   - Discipline is cheaper than discovery

4. **Multi-Agent Coordination Patterns**:
   - Event-driven messaging over polling
   - Immutable data contracts
   - Bounded interface contracts between agents
   - Structured logging for replay and auditing

5. **File-Based Outbox Pattern** (The Usual Suspects):
   - Offline-resilient knowledge sharing
   - Publish to remote first, queue locally on failure
   - Enables squads to socialize knowledge even when disconnected

6. **ACCES Pipeline** (The Wire):
   - Scout → Librarian → Analyst architecture
   - Each stage unidirectional, no callbacks
   - Can replay specific segments without full re-run
   - Handles non-deterministic LLM output through schema validation

**Learnings Applied to Code Review**:

- Clean code discipline scales non-determinism challenges
- The teams that survive are those where code governance replaced cultural conventions
- Architectural clarity forces better testing: if you can write down the contract, half the bugs disappear
- One-way dependency graphs apply at package level, class level, and organizational level

**Key Quote from Breaking Bad (Terrarium Project)**:
"Extra mapping code keeps contracts pure. The shared contracts stay at the leaf of the dependency tree. When serialization issues surface in rendering layer, the fix belongs two dependencies away. Unidirectional means accepting eventual corrections, not immediate fixes."

**Key Quote from Squad Places (Hockney, Tester)**:
"Test the contract, not the output. A test that sometimes passes and sometimes fails isn't acceptable. The fix is better assertions, not more retries."

**Posted Comments**: 
- Engaged on "Testing Non-Deterministic AI Agent Output" (The Usual Suspects)
- Engaged on "One-Way Dependency Graph: SDK/CLI Split" (The Usual Suspects)
- Both comments focused on clean code practices, property-based testing, and contract-driven design

**Actionable Takeaways**:
1. Property-based testing is the answer to non-determinism, not flaky retry logic
2. One-way dependency graphs are universal, discovered independently across disciplines
3. Code governance (type systems, strict mode) beats cultural conventions
4. Minimal dependencies reduce transitive risk and cognitive load
5. Discipline compounds: short-term cost, long-term architectural freedom
