# Security Context MCP Server

An MCP (Model Context Protocol) server that aggregates security posture data from multiple Microsoft security services into a unified interface for AI assistants.

## Overview

This server exposes six tools that query security data from:

| Tool | Data Source | Description |
|------|-------------|-------------|
| `security_get_alerts` | Microsoft Graph Security API | Security alerts with severity/status filtering |
| `security_get_recommendations` | Azure Defender for Cloud | Actionable security recommendations |
| `security_get_score` | Microsoft Graph Security API | Tenant-wide Microsoft Secure Score |
| `security_get_vulnerabilities` | GitHub Advanced Security | Code scanning / vulnerability alerts |
| `security_search_threats` | Microsoft Graph Threat Intelligence | Threat intel articles by keyword/IoC |
| `security_get_compliance` | Azure Defender for Cloud | Regulatory compliance posture |

## Prerequisites

- **Node.js** ≥ 20
- **Azure identity** configured (e.g. `az login`, Managed Identity, or env vars)
- **GitHub token** with `security_events` scope (for vulnerability scanning)

## Required Permissions

### Microsoft Graph (Entra ID app or delegated)

| Permission | Type | Purpose |
|------------|------|---------|
| `SecurityEvents.Read.All` | Application | Read security alerts |
| `SecurityEvents.ReadWrite.All` | Application | Read secure scores |
| `ThreatIntelligence.Read.All` | Application | Search threat intelligence |

### Azure RBAC

| Role | Scope | Purpose |
|------|-------|---------|
| `Security Reader` | Subscription | Read recommendations & compliance |

### GitHub

| Scope | Purpose |
|-------|---------|
| `security_events` | Read code-scanning alerts |

## Setup

```bash
# Install dependencies
npm install

# Build
npm run build

# Run (production)
npm start

# Run (development with hot-reload)
npm run dev
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GITHUB_TOKEN` | For vulnerability tool | GitHub PAT with `security_events` scope |
| `AZURE_TENANT_ID` | Depends on auth method | Azure AD tenant ID |
| `AZURE_CLIENT_ID` | Depends on auth method | Service principal client ID |
| `AZURE_CLIENT_SECRET` | Depends on auth method | Service principal secret |

> **Note:** When running under Managed Identity (e.g. Azure VM, App Service), the `AZURE_*` variables are not required — `DefaultAzureCredential` picks up the identity automatically.

## MCP Client Configuration

Add to your MCP client config (e.g. `.copilot/mcp-config.json`):

```json
{
  "servers": {
    "security-context": {
      "type": "stdio",
      "command": "node",
      "args": ["mcp-servers/security-context/dist/index.js"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

## Security Considerations

This server handles **sensitive security data**. The following safeguards are built in:

1. **No credentials logged** — Tokens are never written to stdout/stderr or included in MCP responses.
2. **Response sanitization** — All API responses are recursively scanned; fields like `token`, `secret`, `password`, `credential`, `apiKey`, and `connectionString` are replaced with `[REDACTED]`.
3. **Rate limiting** — Each endpoint is limited to 30 requests per 60-second window to prevent API abuse.
4. **Minimal scopes** — Only read-only permissions are requested from each data source.
5. **Stderr-only logging** — stdout is reserved for MCP JSON-RPC; operational logs go to stderr.
6. **Error sanitization** — Caught exceptions are logged by message only; stack traces that may contain tokens are suppressed in output.

## Architecture

```
┌─────────────────────────────────────┐
│          MCP Client (AI)            │
└──────────────┬──────────────────────┘
               │ JSON-RPC (stdio)
┌──────────────▼──────────────────────┐
│     Security Context MCP Server     │
│                                     │
│  ┌───────────┐  ┌────────────────┐  │
│  │ Rate Limit│  │  Sanitizer     │  │
│  └─────┬─────┘  └───────┬────────┘  │
│        │                │           │
│  ┌─────▼────────────────▼────────┐  │
│  │       API Fetch Layer         │  │
│  │  (Graph / ARM / GitHub)       │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Development

```bash
# Type-check without emitting
npx tsc --noEmit

# Run in dev mode
npm run dev
```

## License

Internal — see repository root for license details.
