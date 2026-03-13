# A2A Protocol: Latest Version Analysis

**Document Status:** Final  
**Created:** 2026-03-13  
**Author:** Seven (Research & Docs)  
**Requested by:** Tamir  
**Related:** Previous A2A PRD (`.squad/research/cross-repo-a2a-prd.md`, issue #296)  
**Research Date:** March 2026

---

## Executive Summary

Google's Agent-to-Agent (A2A) protocol has reached **v1.0** — a major milestone since our last research. The protocol has been **donated to the Linux Foundation** (June 2025), now has **150+ organizational backers** (including AWS, Microsoft, Cisco, Salesforce, SAP, ServiceNow), and has matured from an early-stage proposal into the de facto standard for cross-vendor AI agent communication.

This document covers what's new, what changed from the version we previously studied, and provides concrete recommendations for integrating A2A into Squad's multi-agent orchestration framework.

**Bottom line:** A2A v1.0 directly validates and enables our cross-repo Squad communication design. The protocol now provides exactly what we need: streaming, robust task management, standardized agent discovery, and production-grade security — all as open standards under vendor-neutral governance.

---

## 1. What's New in A2A v1.0

### 1.1 Protocol Maturity: v0.x → v1.0

The protocol has graduated from draft to a stable, versioned specification with:

- **Strict versioning:** Agent Cards now *require* an explicit protocol version field
- **Layered architecture:** Clean separation of data model (tasks, messages, artifacts) from protocol bindings (JSON-RPC, gRPC, HTTP/REST)
- **A2A Inspector:** New validation tooling for testing agent conformance
- **Technology Compatibility Kit (TCK):** Standardized test suite to certify A2A compliance

### 1.2 Streaming Support (New)

Full real-time streaming via multiple transports:

| Transport | Use Case |
|-----------|----------|
| **WebSocket** | Bidirectional real-time agent communication |
| **Server-Sent Events (SSE)** | One-way push updates, lightweight |
| **gRPC** | High-performance, cross-language streaming |

This is critical for Squad — agents can now receive live progress updates on delegated tasks rather than polling.

### 1.3 Enhanced Task State Management

- **State transition history:** Full audit trail of task state changes
- **Rollback & recovery:** Tasks can be rolled back to previous states
- **Multiple push notification configs per task:** More flexible subscription patterns
- **Async task lifecycle:** Start → update → stream → complete/cancel, all tracked

### 1.4 Security Overhaul

| Feature | Previous | v1.0 |
|---------|----------|------|
| Authentication | Basic auth, bearer tokens | **OAuth 2.0**, mTLS, signed Agent Cards |
| Authorization | None standardized | **RBAC/ABAC** built into spec |
| Audit | None | **Full audit logging** in protocol |
| Transport | HTTP recommended | **HTTPS required**, mTLS supported |
| Basic auth | Supported | **Removed** |

### 1.5 Multi-Language SDK Ecosystem

Official SDKs now available in:

- **Python** — AI/ML ecosystem, rapid prototyping
- **JavaScript/TypeScript** — Web-native agents, Node.js
- **C#/.NET** — Enterprise, Microsoft stack
- **Go** — Cloud-native, performant backends
- **Java** — Enterprise backend, Android

### 1.6 Linux Foundation Governance

- **Donated June 2025** by Google to Linux Foundation
- **Vendor-neutral governance** — no single company controls the standard
- **Open contribution model** via GitHub
- **150+ member organizations** actively participating

---

## 2. What Changed from Our Previous Research

Our prior work (`.squad/research/cross-repo-a2a-prd.md`, created 2026-03-08) was based on early A2A specs. Here's what's different:

### 2.1 Breaking Changes

| Area | Old Behavior | New (v1.0) |
|------|-------------|------------|
| **Agent Card URI** | `/.well-known/agent.json` | `/.well-known/agent-card.json` |
| **Version field** | Optional | **Required** in Agent Cards |
| **`message.type`** | Optional | **Mandatory** |
| **Security** | Basic auth supported | Basic auth **removed**; OAuth 2.0 required |
| **Bearer tokens** | Custom format | Standardized format |
| **API endpoints** | Flexible naming | Stricter naming conventions |
| **Message metadata** | Loosely structured | Revised structure for extensibility |

### 2.2 Impact on Our PRD Design

Our existing PRD needs these updates:

1. **Agent Card endpoint:** Change from `/a2a/card` to `/.well-known/agent-card.json` (aligns with IETF RFC 8615)
2. **Version negotiation:** Add protocol version to our Agent Card schema (support both v0.3 and v1.0 during transition)
3. **Streaming:** Our design assumed request-response only. Must add WebSocket/SSE support for real-time task updates
4. **Security model:** Our Phase 1 "local-trust" model remains valid, but Phase 2 should use OAuth 2.0 instead of shared secrets
5. **Task lifecycle:** Enhance our `TaskDelegation` interface to include state history and rollback

### 2.3 What We Got Right

Our PRD was well-aligned with where A2A ended up:

- ✅ JSON-RPC 2.0 over HTTP — now the mandated transport
- ✅ Agent Cards for capability advertising — now the official discovery mechanism
- ✅ Local file-based registry for Phase 1 — A2A supports this pattern
- ✅ Phased security (local → network → enterprise) — matches A2A's tiered approach
- ✅ Async task delegation — now first-class in the protocol

---

## 3. A2A Relevance to Squad

### 3.1 Cross-Squad Communication

**Direct applicability: HIGH**

A2A was designed exactly for our use case — multiple autonomous agent systems communicating across boundaries.

| Squad Need | A2A Solution |
|-----------|-------------|
| Multiple Squad instances talking | Each Squad = A2A server with Agent Card |
| Cross-repo coordination | JSON-RPC task delegation with streaming updates |
| Breaking change notifications | A2A broadcast with push notifications |
| Research sharing | `shareResearch` method via standardized protocol |
| Decision queries | Query/response with relevance scoring |

**Implementation approach:**
```
Squad Instance (frontend-repo)     Squad Instance (backend-repo)
       │                                    │
       │  ←── A2A Protocol (JSON-RPC) ──→  │
       │                                    │
       ├── Agent Card published at          ├── Agent Card published at
       │   /.well-known/agent-card.json     │   /.well-known/agent-card.json
       │                                    │
       ├── WebSocket for live updates       ├── WebSocket for live updates
       │                                    │
       └── OAuth 2.0 (network mode)        └── OAuth 2.0 (network mode)
```

### 3.2 Agent Discovery and Capability Advertising

**Direct applicability: HIGH**

A2A's discovery system maps perfectly to Squad's needs:

**Well-Known URI Pattern:**
- Each Squad instance publishes at `/.well-known/agent-card.json`
- Follows IETF RFC 8615 — industry standard, widely supported

**Curated Registries:**
- For enterprise deployments, a central registry catalogs all Squad instances
- Supports filtering by capability, team, technology stack
- Our file-based registry (`~/.squad/registry/active-squads.json`) is the Phase 1 equivalent

**DNS-Based Discovery (Emerging):**
- DNS TXT records (`_agent` records) for global federated discovery
- Aligns with our Phase 2 mDNS/Bonjour plans

**Updated Squad Agent Card (aligned with A2A v1.0):**
```json
{
  "name": "Backend API Squad",
  "description": "Squad managing the backend API repository",
  "url": "http://localhost:3001",
  "version": "1.0",
  "protocolVersion": "1.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "stateTransitionHistory": true
  },
  "skills": [
    {
      "id": "decision-query",
      "name": "Query Architecture Decisions",
      "description": "Search and return relevant architecture decisions"
    },
    {
      "id": "task-delegation",
      "name": "Accept Delegated Tasks",
      "description": "Accept and execute tasks from other squads"
    },
    {
      "id": "research-sharing",
      "name": "Share Research Findings",
      "description": "Return cached research on requested topics"
    }
  ],
  "authentication": {
    "schemes": ["local-trust", "oauth2"]
  },
  "provider": {
    "organization": "tamresearch1",
    "repository": "backend-api"
  }
}
```

### 3.3 Inter-Agent Task Delegation

**Direct applicability: HIGH**

A2A v1.0's task model is richer than what we designed:

| Feature | Our PRD Design | A2A v1.0 |
|---------|---------------|----------|
| Task states | 5 states | Full state machine with history |
| Updates | Polling | Streaming (WebSocket/SSE) + polling |
| Cancellation | Not specified | Built-in cancellation protocol |
| Chaining | Not specified | Follow-up task chaining supported |
| Multi-modal | Text only | Text, files, structured data, streams |

**Recommended update to our task flow:**
```
Delegating Squad                         Receiving Squad
      │                                        │
      ├── delegateTask (JSON-RPC) ───────────→ │
      │                                        ├── task.accepted
      │  ←── SSE: task.progress (streaming) ── │
      │  ←── SSE: task.progress ─────────────  │
      │  ←── SSE: task.completed ────────────  │
      │                                        │
      ├── getTaskHistory ────────────────────→ │
      │  ←── full state transition history ──  │
```

---

## 4. Protocol Landscape: A2A vs Competitors

### 4.1 A2A vs MCP (Model Context Protocol)

This is the most important distinction in the current ecosystem:

| Aspect | MCP (Anthropic) | A2A (Google/Linux Foundation) |
|--------|----------------|------------------------------|
| **Focus** | Agent ↔ Tool/Data integration | Agent ↔ Agent communication |
| **Metaphor** | "USB-C for AI" | "HTTP for AI Agents" |
| **Architecture** | Client-Server | Peer-to-Peer / Decentralized |
| **Primary use** | Give agents access to tools, APIs, databases | Agent discovery, delegation, collaboration |
| **Relationship** | Vertical integration | Horizontal integration |

**Key insight: They are complementary, not competitive.**

In Squad's architecture:
- **MCP** = how Squad agents access tools (Azure DevOps, GitHub, file system, etc.)
- **A2A** = how Squad instances talk to each other across repositories

```
┌─────────────────────────────────────────────┐
│              Squad Instance A                │
│                                              │
│  Agent (Seven) ──MCP──→ GitHub API           │
│  Agent (Worf)  ──MCP──→ Azure DevOps         │
│  Agent (Data)  ──MCP──→ Code Search          │
│                                              │
│  Squad A ═══A2A═══ Squad B (other repo)      │
│                                              │
└─────────────────────────────────────────────┘
```

**Recommendation:** Squad should implement BOTH protocols:
- Continue using MCP for tool integration (already in place)
- Add A2A for cross-squad communication (new capability)

### 4.2 Other Protocols

| Protocol | Focus | Status | Relevance to Squad |
|----------|-------|--------|-------------------|
| **ACP** (Agent Communication Protocol) | Message transport & discovery | Early stage | Watch — may complement A2A |
| **ANP** (Agent Network Protocol) | Decentralized agent networks | Emerging | Future interest for org-wide deployments |
| **OpenAI Swarm** | Lightweight multi-agent | Experimental | Not interoperable; prototyping only |
| **AutoGen** (Microsoft) | Conversation-based multi-agent | Production | No native A2A/MCP; .NET focused |
| **CrewAI** | Role-based agent teams | Growing | Adding A2A support |
| **LangGraph** | Graph-based orchestration | Mature | A2A via LangChain integration |
| **OpenAgents** | Interoperable agents | New | Native A2A + MCP support |

### 4.3 Framework Interoperability Matrix

| Framework | A2A Support | MCP Support | Squad Compatibility |
|-----------|-------------|-------------|-------------------|
| Squad (ours) | Planned (this PRD) | ✅ In use | — |
| CrewAI | Growing | Community plugins | Could talk to Squad via A2A |
| LangGraph | Via LangChain | Limited | Possible via A2A |
| AutoGen | No native | No native | Would need adapter |
| OpenAgents | ✅ Native | ✅ Native | High compatibility potential |

---

## 5. Recommendations

### 5.1 Immediate Actions

1. **Update the cross-repo A2A PRD** (`.squad/research/cross-repo-a2a-prd.md`) to reflect v1.0 breaking changes:
   - Agent Card URI: `/.well-known/agent-card.json`
   - Add mandatory `version` field
   - Require `message.type` in all messages
   - Remove basic auth from security roadmap

2. **Adopt the official TypeScript SDK** instead of building our own JSON-RPC layer:
   - `@a2a-protocol/sdk-js` — maintained by the A2A project
   - Saves ~2 weeks of implementation time
   - Gets streaming support (WebSocket/SSE) for free

3. **Add streaming to Phase 1 scope** — A2A v1.0 makes streaming a first-class feature, not an afterthought. Task delegation without streaming is now the exception, not the norm.

### 5.2 Architecture Updates

```
Previous Design:                    Updated Design:
───────────────                    ───────────────
HTTP REST + JSON-RPC      →       JSON-RPC 2.0 + WebSocket + SSE
Custom Agent Card          →       A2A v1.0 Agent Card standard
/a2a/card endpoint         →       /.well-known/agent-card.json
No auth (Phase 1)          →       No auth (Phase 1, local only)
Shared secret (Phase 2)    →       OAuth 2.0 (Phase 2, network)
Polling for task updates   →       SSE streaming (Phase 1)
```

### 5.3 Timeline Impact

| Phase | Previous Estimate | Updated Estimate | Change |
|-------|------------------|-----------------|--------|
| Phase 1 (Local) | 6 weeks | **5 weeks** | -1 week (SDK reuse) |
| Phase 2 (Network) | 4 weeks | **4 weeks** | No change |
| Phase 3 (Enterprise) | 4 weeks | **3 weeks** | -1 week (OAuth 2.0 built into SDK) |

Using the official SDK saves ~2 weeks total across phases.

### 5.4 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| A2A v1.0 spec changes again | Low | Medium | Pin to v1.0, support v0.3 fallback |
| SDK quality/maturity | Medium | Low | We can fork; official SDKs have 150+ org backing |
| Adoption stalls | Low | Medium | Linux Foundation governance reduces this risk |
| Security vulnerabilities in protocol | Low | High | mTLS + OAuth 2.0 + audit logging mitigate |

---

## 6. Sources

### Official Resources
- [A2A Protocol Official Site](https://a2a-protocol.org/latest/) — Specification, roadmap, SDK links
- [A2A GitHub Repository](https://github.com/a2aproject/A2A) — Source, releases, changelog
- [A2A Specification (GitHub)](https://github.com/a2aproject/A2A/blob/main/docs/specification.md) — Full technical spec
- [Agent Discovery Documentation](https://a2a-protocol.org/latest/topics/agent-discovery/) — Well-known URI, registries
- [A2A Protocol Roadmap](https://a2a-protocol.org/latest/roadmap/) — v1.0 and beyond

### Announcements & Analysis
- [Google Cloud: "A2A Protocol Getting an Upgrade"](https://cloud.google.com/blog/products/ai-machine-learning/agent2agent-protocol-is-getting-an-upgrade) — Official upgrade announcement
- [Google Developers: A2A Donated to Linux Foundation](https://developers.googleblog.com/en/google-cloud-donates-a2a-to-linux-foundation/) — Governance transition
- [Linux Foundation: A2A Project Launch](https://www.linuxfoundation.org/press/linux-foundation-launches-the-agent2agent-protocol-project-to-enable-secure-intelligent-communication-between-ai-agents) — Official LF announcement
- [A2A Protocol 2025.1 Release Notes](https://agent2agent.info/blog/a2a-protocol-2025-1-release/) — Detailed changelog

### Comparisons
- [DigitalOcean: A2A vs MCP](https://www.digitalocean.com/community/tutorials/a2a-vs-mcp-ai-agent-protocols) — Technical comparison
- [WorkOS: MCP vs A2A](https://workos.com/blog/mcp-vs-a2a) — Decision guide
- [Complete Protocol Guide: MCP vs A2A vs ACP vs ANP](http://jitendrazaa.com/blog/ai/mcp-vs-a2a-vs-acp-vs-anp-complete-ai-agent-protocol-guide/) — Full landscape

### Previous Squad Research
- `.squad/research/cross-repo-a2a-prd.md` — Our initial A2A integration PRD (2026-03-08)

---

*Research completed by Seven. The docs are the product.*
