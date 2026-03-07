# Decision: MCP Server as Thin Protocol Adapter Pattern

**Context:** Issue #65 — DevBox MCP Server Phase 3

## Decision

MCP servers should be implemented as **thin protocol adapters** that translate MCP tool schemas to existing automation (scripts, CLIs, SDKs), NOT as business logic containers.

## Rationale

### Pattern Applied in DevBox MCP Server

The DevBox MCP server (`devbox-provisioning/mcp-server/`) wraps Phase 1 PowerShell scripts and Azure CLI commands instead of reimplementing provisioning logic in TypeScript:

```typescript
// MCP handler wraps existing script
async function handleToolCall(name: string, args: any) {
  case 'devbox_create':
    const scriptArgs = [`-DevBoxName`, `"${args.name}"`];
    return await executePowerShellScript('provision.ps1', scriptArgs);
}
```

### Benefits of Thin Adapter Pattern

1. **Code Reuse:** Phase 2 Squad Skill and Phase 3 MCP server execute same Phase 1 scripts
2. **Single Source of Truth:** Provisioning logic maintained in one place (PowerShell scripts)
3. **Independent Testing:** Test scripts independently of MCP protocol
4. **Composability:** Same automation callable via CLI, natural language, or MCP
5. **Maintenance:** Update provisioning logic once, all interfaces (CLI/Skill/MCP) benefit

### Anti-Pattern to Avoid

**Don't:** Reimplement business logic in the MCP server

```typescript
// ❌ BAD: Duplicates logic from scripts
async function handleToolCall(name: string, args: any) {
  case 'devbox_create':
    // Inline Azure SDK calls, validation, polling, error handling...
    // Now you have TWO implementations to maintain!
}
```

**Do:** Wrap existing automation

```typescript
// ✅ GOOD: Delegates to existing script
async function handleToolCall(name: string, args: any) {
  case 'devbox_create':
    return await executePowerShellScript('provision.ps1', scriptArgs);
}
```

## Implications

### For Future MCP Servers

When implementing MCP servers in this project:

1. **Identify Existing Automation:** Scripts, CLI tools, SDKs already solving the problem
2. **MCP Layer = Translation:** Map MCP tool schemas → existing automation parameters
3. **Keep Logic Out:** Validation, retries, error handling belong in underlying automation
4. **Test Separately:** Test automation independently, then test MCP protocol adherence

### Example: Future Resource Monitoring MCP Server

If we build a resource monitoring MCP server:

- **Underlying automation:** PowerShell/Python scripts that query Azure metrics
- **MCP server role:** Translate `devbox_get_metrics` tool call → script invocation
- **NOT the MCP server's job:** Query Azure Monitor API, parse metrics, aggregate data

## Alternatives Considered

### Alternative 1: Fat MCP Server (Azure SDK in TypeScript)

**Approach:** Implement all provisioning logic directly in MCP server using Azure SDK for JavaScript

**Rejected because:**
- Creates second implementation of provisioning logic (scripts already exist)
- Harder to maintain (logic split across PowerShell + TypeScript)
- Harder to test (requires mocking Azure SDK instead of testing real scripts)
- Less composable (Squad Skill can't reuse TypeScript MCP code)

### Alternative 2: Hybrid (Some Logic in MCP, Some in Scripts)

**Approach:** Simple operations in MCP server, complex operations delegate to scripts

**Rejected because:**
- Unclear boundary between \"simple\" and \"complex\"
- Still requires maintaining logic in two places
- Adds cognitive load (\"where does this validation happen?\")

## Decision Record

**Status:** Accepted  
**Date:** 2026-03-08  
**Author:** B'Elanna (Infrastructure Expert)  
**Issue:** #65  
**PR:** #69

## Tags

`mcp`, `architecture`, `devbox`, `phase-3`, `pattern`
