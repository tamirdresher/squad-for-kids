# Cross-Repo Squad Communication: A2A/ACP Integration PRD

**Document Status:** Draft  
**Created:** 2026-03-08  
**Author:** Picard (Squad Lead)  
**Related Issue:** #296  
**Target Release:** Squad CLI v2.0

---

## Executive Summary

Squads are currently isolated within their repository boundaries, unable to coordinate, share context, or delegate work across repositories. This PRD proposes integrating the A2A (Agent-to-Agent) protocol into Squad CLI, transforming each squad instance into an addressable, discoverable agent that can communicate with squads in other repositories. This enables multi-repo coordination, cross-cutting concerns, and autonomous inter-squad collaboration.

**Core Vision:** Squad CLI becomes both a developer tool AND a network-aware A2A server, creating a mesh of cooperating squads across a developer's local workspace and (optionally) organizational network.

---

## Problem Statement

### Current State
- **Repository Silos:** Each squad operates independently within a single repository, unaware of related work in other repos.
- **Manual Coordination:** Developers must manually bridge context between repos (copy-paste decisions, duplicate documentation, synchronize breaking changes).
- **No Cross-Repo Intelligence:** A squad in `frontend-app` cannot ask the squad in `backend-api` about API contracts, status of breaking changes, or upcoming releases.
- **Fragmented Knowledge:** Architecture decisions, patterns, and lessons learned remain trapped in their origin repos.

### User Pain Points
1. **Microservice Hell:** Teams managing 5-10+ repos waste hours coordinating changes across boundaries.
2. **Breaking Changes:** Backend breaking changes aren't visible to frontend squads until integration breaks.
3. **Duplicate Effort:** Multiple squads researching the same technology, solving identical problems independently.
4. **Lost Context:** Developer switches repos, loses context of what the other squad is working on.
5. **Infrastructure Fragmentation:** DevOps changes (Kubernetes, CI/CD) need manual propagation across repos.

### Opportunity
Leverage the A2A protocol (now under Linux Foundation, backed by Google, AWS, Microsoft, 150+ orgs) to create an "internet of squads" where:
- Squads auto-discover each other locally and (optionally) on the network
- Squads exchange capabilities via Agent Cards
- Squads delegate tasks, query decisions, share research
- Zero manual configuration for local use case

---

## Proposed Solution

### High-Level Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│  Squad Instance A   │         │  Squad Instance B   │
│  (Repo: frontend)   │◄───────►│  (Repo: backend)    │
│                     │   A2A   │                     │
│  - Discovery Client │  Proto  │  - A2A Server       │
│  - A2A Client       │         │  - Agent Card       │
│  - Task Delegator   │         │  - Capability API   │
└─────────────────────┘         └─────────────────────┘
          │                              │
          │                              │
          └──────────┬───────────────────┘
                     │
              ┌──────▼───────┐
              │   Discovery  │
              │   Registry   │
              │  (Local/Net) │
              └──────────────┘
```

### Core Components

#### 1. **A2A Server Mode** (New)
When `squad` CLI runs, it:
- Starts an embedded HTTP/JSON-RPC server (configurable port, default: auto-assign)
- Publishes an Agent Card describing the squad's capabilities
- Registers with local discovery registry (file-based or mDNS)
- Handles incoming A2A requests (query decisions, delegate task, share research)

#### 2. **Discovery Mechanism**
**Phase 1 - Local Discovery:**
- File-based registry: `~/.squad/registry/active-squads.json`
- Each squad instance writes: `{ "repoPath": "/path/to/repo", "port": 3001, "agentCard": {...}, "pid": 12345 }`
- Squads scan registry to find siblings
- Auto-cleanup stale entries (process dead, repo removed)

**Phase 2 - Network Discovery (Optional):**
- mDNS/Bonjour for LAN discovery
- Organizational registry server (opt-in)
- DNS-SD for enterprise deployments

#### 3. **Agent Card Specification**
Each squad publishes capabilities:
```json
{
  "id": "squad://github.com/org/repo",
  "name": "Backend API Squad",
  "repository": "org/backend-api",
  "capabilities": [
    "decision-query",
    "task-delegation",
    "research-sharing",
    "api-contract-query",
    "breaking-change-notification"
  ],
  "endpoints": {
    "base": "http://localhost:3001",
    "decisions": "/a2a/decisions",
    "tasks": "/a2a/tasks",
    "research": "/a2a/research"
  },
  "authentication": {
    "required": false,
    "methods": ["local-trust"]
  },
  "metadata": {
    "techStack": ["TypeScript", "Node.js", "PostgreSQL"],
    "domain": "backend-services",
    "team": ["picard", "data", "belanna"]
  }
}
```

#### 4. **Communication Protocol**
Based on A2A spec (JSON-RPC 2.0 over HTTP):

**Query Decisions:**
```json
{
  "jsonrpc": "2.0",
  "method": "squad.queryDecisions",
  "params": {
    "query": "API authentication strategy",
    "scope": ["architecture", "security"]
  },
  "id": "req-001"
}
```

**Delegate Task:**
```json
{
  "jsonrpc": "2.0",
  "method": "squad.delegateTask",
  "params": {
    "title": "Update API client for v2 endpoints",
    "description": "Backend deployed v2, need frontend updates",
    "priority": "high",
    "context": {
      "breakingChanges": ["auth-flow", "pagination"],
      "migrationGuide": "https://link-to-doc"
    }
  },
  "id": "req-002"
}
```

**Share Research:**
```json
{
  "jsonrpc": "2.0",
  "method": "squad.shareResearch",
  "params": {
    "topic": "Kubernetes Ingress Controllers",
    "findings": "...",
    "recommendations": ["nginx-ingress", "traefik"],
    "source": "squad://github.com/org/infrastructure"
  },
  "id": "req-003"
}
```

#### 5. **CLI Commands** (New)

```bash
# Start squad with A2A server
squad serve --port 3001 --registry local

# Discover other squads
squad discover
# Output:
# Found 3 squads:
# - frontend-app (http://localhost:3002)
# - backend-api (http://localhost:3001)
# - infrastructure (http://localhost:3003)

# Connect to a specific squad
squad connect backend-api

# Query decisions from another squad
squad ask backend-api "What's the API versioning strategy?"

# Delegate a task
squad delegate infrastructure "Update nginx config for new TLS requirements"

# Broadcast to all squads
squad broadcast "Breaking change in auth library - upgrade to v3.0 required"

# Health check
squad health --all
```

---

## Use Cases

### Use Case 1: Breaking Change Coordination
**Scenario:** Backend squad makes a breaking API change.

1. Backend squad commits breaking change to `.squad/decisions/api-v2-migration.md`
2. Backend squad runs: `squad broadcast "API v2 released - migration required"`
3. Frontend squad receives notification via A2A
4. Frontend squad's Kes agent creates issue: "Migrate to backend API v2"
5. Frontend squad queries backend: `squad ask backend "API v2 migration steps?"`
6. Backend squad returns decision document with migration guide

**Value:** Zero-latency notification, automatic issue creation, instant access to migration docs.

### Use Case 2: Shared Research
**Scenario:** Multiple squads evaluating the same technology.

1. Infrastructure squad researches Kubernetes ingress controllers
2. Infrastructure squad writes research report: `.squad/research/ingress-comparison.md`
3. Platform squad needs same info, runs: `squad ask infrastructure "ingress controller recommendation"`
4. Infrastructure squad returns cached research via A2A
5. Platform squad saves 4 hours of duplicate research

**Value:** Knowledge reuse, consistent decisions, time savings.

### Use Case 3: Cross-Repo Dependency Tracking
**Scenario:** Frontend depends on backend library version.

1. Frontend squad queries: `squad ask backend "What's the stable version of api-client?"`
2. Backend squad responds: `v2.3.1 (stable), v2.4.0-beta (latest)`
3. Frontend squad auto-updates dependency in package.json
4. Frontend squad creates PR with reference to backend decision

**Value:** Always-current dependencies, automated sync, audit trail.

### Use Case 4: Multi-Repo Initiatives
**Scenario:** Security audit spans 5 repos.

1. Security squad creates task: "Audit all repos for hardcoded secrets"
2. Security squad delegates to all discovered squads
3. Each squad runs local audit, reports findings
4. Security squad aggregates results, creates consolidated report

**Value:** Parallel execution, consistent methodology, centralized results.

### Use Case 5: Onboarding New Developers
**Scenario:** New developer needs to understand multi-repo architecture.

1. Developer asks: "How do these repos interact?"
2. Squad CLI queries all local squads for architecture decisions
3. Aggregates responses into coherent architecture map
4. Generates visual diagram + decision references

**Value:** Instant architecture overview, discoverable knowledge, no stale docs.

---

## Technical Design

### Discovery Registry (Phase 1: Local)

**Location:** `~/.squad/registry/active-squads.json`

**Schema:**
```json
{
  "version": "1.0",
  "lastUpdated": "2026-03-08T10:30:00Z",
  "squads": [
    {
      "id": "squad-12345",
      "repoPath": "/Users/dev/frontend-app",
      "repoUrl": "github.com/org/frontend-app",
      "port": 3001,
      "pid": 45678,
      "agentCard": { /* full agent card */ },
      "startedAt": "2026-03-08T09:00:00Z",
      "lastSeen": "2026-03-08T10:29:55Z"
    }
  ]
}
```

**Operations:**
- **Register:** On `squad serve`, write entry (upsert by repoPath)
- **Heartbeat:** Every 30s, update `lastSeen`
- **Cleanup:** On graceful shutdown, remove entry
- **Stale Detection:** Remove entries with `lastSeen > 2 minutes ago` OR `pid` not running

### A2A Server Implementation

**Stack:** Node.js + Express + JSON-RPC middleware

**Endpoints:**
```
POST /a2a/rpc          # Main JSON-RPC endpoint
GET  /a2a/card         # Agent Card (for discovery)
GET  /a2a/health       # Health check
POST /a2a/decisions    # Query decisions (RESTful alternative)
POST /a2a/tasks        # Delegate tasks
POST /a2a/research     # Share research
```

**Security (Phase 1):**
- Local-only binding (127.0.0.1)
- Process-level trust (same user)
- No authentication required

**Security (Phase 2):**
- TLS for network communication
- Mutual TLS with cert-based auth
- OAuth2/OIDC for organizational deployments
- Request signing (HMAC)

### Message Routing

**Synchronous (Request/Response):**
```javascript
const client = new A2AClient('http://localhost:3002');
const response = await client.call('squad.queryDecisions', { query: 'auth' });
```

**Asynchronous (Task Delegation):**
```javascript
const taskId = await client.call('squad.delegateTask', { title: '...' });
// Returns immediately with taskId
// Receiving squad processes async, sends updates via callback/webhook
```

**Broadcast:**
```javascript
const registry = await loadRegistry();
const results = await Promise.allSettled(
  registry.squads.map(squad => 
    fetch(`${squad.port}/a2a/rpc`, { method: 'POST', body: message })
  )
);
```

### Data Model

**Decision Query Response:**
```typescript
interface DecisionQueryResponse {
  decisions: Array<{
    id: string;
    title: string;
    summary: string;
    path: string; // Relative path in repo
    createdAt: string;
    author: string;
    tags: string[];
    relevanceScore: number; // 0-1, based on query match
  }>;
  totalCount: number;
  source: {
    squad: string;
    repo: string;
  };
}
```

**Task Delegation:**
```typescript
interface TaskDelegation {
  id: string;
  fromSquad: string;
  toSquad: string;
  title: string;
  description: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  context: Record<string, any>;
  status: 'pending' | 'accepted' | 'rejected' | 'in_progress' | 'completed';
  createdAt: string;
  dueDate?: string;
}
```

---

## Phased Rollout

### Phase 1: Local Discovery (MVP) — 6 weeks
**Scope:**
- Embedded A2A server in Squad CLI
- File-based local discovery registry
- Basic JSON-RPC implementation
- CLI commands: `serve`, `discover`, `connect`, `ask`
- Three core capabilities: decision-query, task-delegation, research-sharing
- Local-only security (same machine, same user)

**Deliverables:**
- A2A server module
- Discovery registry manager
- CLI command extensions
- Agent Card generator
- Integration tests (2 squads on localhost)
- Documentation: User guide, API reference

**Success Metrics:**
- 2+ squads can discover each other locally
- Query decisions from another squad < 200ms
- Zero-config setup for local use case

### Phase 2: Network Discovery (Optional) — 4 weeks
**Scope:**
- mDNS/Bonjour support for LAN discovery
- TLS for encrypted communication
- Basic authentication (shared secret or mutual TLS)
- Organizational registry server (optional backend)
- `squad serve --network` flag (opt-in)

**Deliverables:**
- Network discovery module (mDNS)
- TLS certificate generation/management
- Authentication middleware
- Registry server (Go or Node.js)
- Network security documentation

**Success Metrics:**
- Squads on same LAN discover each other < 5 seconds
- Secure communication (TLS + auth) working
- Registry server handles 100+ squads

### Phase 3: Advanced Features — 8 weeks
**Scope:**
- Persistent connections (WebSocket for real-time updates)
- Subscription model (watch for changes)
- Federation (cross-org communication with consent)
- Advanced routing (load balancing, failover)
- UI dashboard (visualize squad mesh)
- Analytics (inter-squad communication patterns)

**Deliverables:**
- WebSocket transport layer
- Subscription API
- Federation protocol
- Dashboard web app (React)
- Analytics backend
- Advanced security (RBAC, audit logs)

**Success Metrics:**
- Real-time notifications < 1 second latency
- Dashboard visualizes 50+ squad mesh
- Federation working across 2+ organizations

---

## Risks and Mitigations

### Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Port conflicts** | High | Medium | Auto-assign ports, fallback range (3000-3100) |
| **Stale registry entries** | Medium | High | Heartbeat + PID check, auto-cleanup |
| **Network security** | High | Low (Phase 1) | Local-only Phase 1, TLS Phase 2, auth mandatory for network |
| **Performance (100+ squads)** | Medium | Low | Lazy discovery, cache agent cards, rate limiting |
| **Protocol versioning** | Medium | Medium | Semantic versioning, backward compatibility guarantees |
| **Firewall issues** | Low | Medium | Document port requirements, provide local-only fallback |

### Adoption Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Developers ignore feature** | High | Medium | Make discovery automatic, zero-config for value |
| **Too complex** | High | Low | Hide complexity, intuitive CLI, great docs |
| **Single-repo teams don't care** | Low | High | Fine — optional feature, no penalty for not using |
| **Security concerns** | High | Low | Local-only default, explicit opt-in for network |

### Privacy Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **Leaking sensitive data** | Critical | Low | Agent Cards expose only metadata (no code, decisions opt-in), allow `.squadignore` patterns |
| **Unauthorized access** | High | Medium | Local-only Phase 1, strong auth Phase 2, audit logs |
| **Cross-org data leak** | Critical | Low | Federation requires explicit mutual consent |

---

## Dependencies

### External
- **A2A Protocol Libraries:** Official Python/JS SDK from a2aproject (Linux Foundation)
- **mDNS Library:** `bonjour-service` (Node.js) or `avahi` (Linux) for network discovery
- **TLS Certificates:** Let's Encrypt or self-signed for dev

### Internal
- **Squad CLI Core:** Refactor to support long-running server mode
- **Agent System:** Extend agents to handle A2A requests
- **Decision System:** API to query `.squad/decisions/` programmatically
- **Task System:** Integration with GitHub Issues API

---

## Success Metrics

### Phase 1 (MVP)
- **Adoption:** 30% of multi-repo teams enable A2A within 3 months
- **Usage:** Average 10 cross-repo queries per day per team
- **Performance:** P95 query latency < 500ms
- **Reliability:** 99% uptime for A2A server (local)
- **Feedback:** NPS > 40 from pilot users

### Phase 2 (Network)
- **Network Adoption:** 10% of teams enable network mode
- **Security:** Zero security incidents in 6 months
- **Scale:** Support 100+ squads per organization
- **Discovery Time:** <5 seconds to discover all LAN squads

### Phase 3 (Advanced)
- **Real-Time:** 80% of notifications delivered <1 second
- **Federation:** 5+ organizations actively using cross-org federation
- **Ecosystem:** 3rd-party integrations (IDEs, dashboards, monitoring)
- **Platform:** A2A becomes industry standard for agent tooling

---

## Open Questions

1. **Naming:** Should we call it A2A, ACP, or invent our own term (e.g., "Squad Link")?
   - **Recommendation:** Use "A2A" for protocol, "Squad Connect" for feature branding.

2. **Offline Squads:** How to handle squads that are temporarily offline?
   - **Proposal:** Cache last-known agent card, retry with exponential backoff, mark as "unavailable."

3. **Multi-Tenant:** How to handle multiple users on same machine with different repos?
   - **Proposal:** Registry per user (`~/.squad/registry/`), isolation via file permissions.

4. **Language Support:** Should we build SDKs for other languages (Python, Go, C#)?
   - **Proposal:** Phase 3 — start with JS/TS (CLI is Node), expand based on demand.

5. **Cloud Deployment:** Should squads run in CI/CD as A2A servers?
   - **Proposal:** Future consideration — "GitHub Actions Squad" could answer queries during builds.

6. **UI Dashboard:** Web-based or CLI TUI?
   - **Proposal:** Both — TUI for quick status, web for deep visualization.

---

## Alternatives Considered

### Alternative 1: Shared Database
**Approach:** All squads write to shared SQLite/Postgres database.
**Pros:** Simple, centralized, transactional.
**Cons:** Requires setup, single point of failure, coupling, not aligned with A2A standards.
**Verdict:** Rejected — doesn't scale to network, misses industry protocol opportunity.

### Alternative 2: Git-Based Sync
**Approach:** Squads commit decisions/research to shared Git repo, others pull.
**Pros:** Version controlled, no network needed, Git-native.
**Cons:** Polling required, high latency, merge conflicts, not real-time.
**Verdict:** Rejected — too slow, not suitable for task delegation.

### Alternative 3: Message Queue (RabbitMQ, Kafka)
**Approach:** Squads publish/subscribe via message broker.
**Pros:** Decoupled, scalable, proven technology.
**Cons:** Heavy infrastructure, overkill for local use case, setup complexity.
**Verdict:** Rejected for MVP — consider for Phase 3 enterprise deployments.

### Alternative 4: gRPC
**Approach:** Use gRPC instead of JSON-RPC.
**Pros:** Performance, streaming, type safety.
**Cons:** More complex, less debuggable, not aligned with A2A (which uses JSON-RPC + HTTP).
**Verdict:** Rejected for MVP — A2A spec uses JSON-RPC, we align with standard.

---

## Alignment with A2A Protocol

This design fully aligns with the A2A v0.3.0 specification:
- **Agent Cards:** JSON-based capability advertisement
- **JSON-RPC 2.0:** Primary communication protocol
- **Discovery:** Registry-based (file) + optional mDNS (network)
- **Security:** Local trust Phase 1, TLS + auth Phase 2
- **Interoperability:** Squads can interact with non-Squad A2A agents (e.g., Google ADK agents)
- **Modality Agnostic:** Support for text, files, structured data

**Strategic Value:** By adopting A2A, Squad becomes part of the broader agent ecosystem, enabling:
- Integration with Google Cloud Agent Development Kit (ADK)
- Compatibility with AWS, Azure, Salesforce AI agents
- Future-proofing as A2A becomes industry standard

---

## Timeline

| Phase | Duration | Start | End |
|-------|----------|-------|-----|
| **Phase 1: MVP** | 6 weeks | Week 1 | Week 6 |
| **Phase 2: Network** | 4 weeks | Week 7 | Week 10 |
| **Phase 3: Advanced** | 8 weeks | Week 11 | Week 18 |
| **Total** | 18 weeks | — | ~4.5 months |

---

## Conclusion

Cross-repo squad communication via A2A protocol transforms Squad from a single-repo tool into a distributed intelligence platform. By aligning with industry standards (A2A under Linux Foundation), we ensure interoperability, future-proofing, and ecosystem participation. The phased rollout minimizes risk while delivering immediate value to multi-repo teams.

**Next Steps:**
1. Review and approve PRD
2. Create implementation issues (see: GitHub issues created for this PRD)
3. Assign Phase 1 workstreams to squad members
4. Begin technical spike for A2A SDK integration
5. Prototype local discovery mechanism

---

**Appendix A: References**
- [A2A Protocol Specification](https://a2a-protocol.org/latest/)
- [A2A GitHub Repository](https://github.com/a2aproject/A2A)
- [Google Cloud Agent Development Kit](https://cloud.google.com/agent-development-kit)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)

**Appendix B: Glossary**
- **A2A:** Agent-to-Agent protocol for AI agent interoperability
- **Agent Card:** Machine-readable JSON document describing agent capabilities
- **Squad:** Local AI team managing a repository
- **Discovery Registry:** Database of active squads (local file or network service)
- **JSON-RPC:** Remote procedure call protocol using JSON
- **mDNS:** Multicast DNS for zero-config network discovery

---

*This PRD is a living document. Feedback welcome.*
