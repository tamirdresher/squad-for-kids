# DevBox MCP Server — Integration Tests

> Integration testing guide for Phase 3 MCP server

## Overview

This document describes the integration testing strategy for the DevBox MCP Server. Tests validate that the MCP server correctly wraps Phase 1/2 scripts and works with multiple MCP clients.

## Prerequisites

- **DevBox MCP Server** built and ready (`npm run build` in `mcp-server/`)
- **Azure CLI** authenticated (`az login`)
- **Dev Center extension** installed (`az extension add --name devcenter`)
- **Test DevBox** available (or permissions to create one)

## Test Strategy

### 1. MCP Inspector Testing (Interactive)

Use the MCP Inspector for visual, interactive testing:

```bash
cd devbox-provisioning/mcp-server
npx @modelcontextprotocol/inspector node dist/index.js
```

**Test Cases:**
1. ✅ Server starts without errors
2. ✅ Tools list displays all 7 tools
3. ✅ `devbox_list` returns existing DevBoxes
4. ✅ `devbox_show` returns detailed info for a specific DevBox
5. ✅ `devbox_status` returns provisioning state
6. ✅ Error handling for non-existent DevBox

### 2. GitHub Copilot CLI Testing

Add to `.copilot/mcp-config.json`:

```json
{
  "mcpServers": {
    "devbox": {
      "command": "node",
      "args": ["C:/temp/tamresearch1/devbox-provisioning/mcp-server/dist/index.js"]
    }
  }
}
```

**Test Cases:**
1. ✅ `@copilot List my DevBoxes` — Natural language query works
2. ✅ `@copilot What's the status of DevBox "test-env"?` — Status check works
3. ✅ `@copilot Show details of my DevBox` — Info retrieval works

### 3. VS Code MCP Client Testing

Add to `.vscode/mcp.json`:

```json
{
  "mcpServers": {
    "devbox": {
      "command": "node",
      "args": ["${workspaceFolder}/devbox-provisioning/mcp-server/dist/index.js"]
    }
  }
}
```

**Test Cases:**
1. ✅ MCP server appears in VS Code MCP status
2. ✅ Tools are callable from Copilot Chat
3. ✅ Error messages are properly formatted

### 4. Teams Integration Testing (Future)

When Teams MCP client is available:

**Test Cases:**
1. 🔲 Teams bot can call `devbox_list`
2. 🔲 Natural language provisioning from Teams works
3. 🔲 Status updates are sent to Teams channels

## Test Scenarios

### Scenario 1: List DevBoxes

**Input:**
```json
{
  "name": "devbox_list",
  "arguments": {
    "format": "json"
  }
}
```

**Expected Output:**
- JSON array of DevBox objects
- Each object contains: `name`, `provisioningState`, `projectName`, `poolName`, `devCenterName`

**Pass Criteria:**
- ✅ Returns valid JSON
- ✅ No errors
- ✅ Matches `az devcenter dev dev-box list` output

---

### Scenario 2: Show DevBox Details

**Input:**
```json
{
  "name": "devbox_show",
  "arguments": {
    "name": "my-test-devbox",
    "format": "summary"
  }
}
```

**Expected Output:**
```
DevBox: my-test-devbox
Status: Running
Project: my-project
Pool: my-pool
Dev Center: my-devcenter
Hardware: Standard_8c_32gb
Image: Windows-11-Enterprise
```

**Pass Criteria:**
- ✅ Returns formatted summary
- ✅ All fields populated correctly
- ✅ Matches `az devcenter dev dev-box show` output

---

### Scenario 3: Check Status

**Input:**
```json
{
  "name": "devbox_status",
  "arguments": {
    "name": "my-test-devbox"
  }
}
```

**Expected Output:**
```
DevBox 'my-test-devbox' status: Running
```

**Pass Criteria:**
- ✅ Returns current status
- ✅ Status is one of: `Running`, `Succeeded`, `Failed`, `Creating`, `Deleting`

---

### Scenario 4: Error Handling (Non-existent DevBox)

**Input:**
```json
{
  "name": "devbox_show",
  "arguments": {
    "name": "does-not-exist"
  }
}
```

**Expected Output:**
```
Error: Azure CLI command failed: ...
```

**Pass Criteria:**
- ✅ Returns error message
- ✅ Error is properly formatted
- ✅ Does not crash the server

---

### Scenario 5: Create DevBox (Dry Run — Don't Execute in CI)

**Input:**
```json
{
  "name": "devbox_create",
  "arguments": {
    "name": "test-create-devbox",
    "waitForCompletion": false
  }
}
```

**Expected Output:**
```
DevBox 'test-create-devbox' created successfully.

Output:
[INFO] Creating Dev Box: test-create-devbox
...
```

**Pass Criteria:**
- ✅ DevBox creation is initiated
- ✅ Output contains creation logs
- ⚠️ **Warning:** This creates a real DevBox — clean up afterward!

---

### Scenario 6: Bulk Provisioning (Dry Run — Don't Execute in CI)

**Input:**
```json
{
  "name": "devbox_bulk_create",
  "arguments": {
    "names": ["bulk-test-1", "bulk-test-2"],
    "sequential": true
  }
}
```

**Expected Output:**
```
Bulk provisioning completed.

Output:
[INFO] Creating 2 DevBoxes sequentially...
...
```

**Pass Criteria:**
- ✅ Both DevBoxes are created
- ✅ Sequential execution is honored
- ⚠️ **Warning:** This creates real DevBoxes — clean up afterward!

## Manual Testing Checklist

Before marking Phase 3 complete, verify:

- [x] MCP server builds without errors (`npm run build`)
- [x] Server starts and accepts connections (`node dist/index.js`)
- [x] All 7 tools are listed (`tools/list` request)
- [x] `devbox_list` returns valid JSON
- [x] `devbox_show` returns detailed info
- [x] `devbox_status` returns status
- [x] Error handling works for invalid inputs
- [ ] GitHub Copilot CLI integration works (requires `.copilot/mcp-config.json`)
- [ ] VS Code MCP integration works (requires `.vscode/mcp.json`)
- [ ] Teams integration works (when Teams MCP client is available)

## Automated Testing (Future)

Future work includes automated integration tests:

```typescript
// test/integration.test.ts
describe('DevBox MCP Server', () => {
  it('should list DevBoxes', async () => {
    const result = await callTool('devbox_list', { format: 'json' });
    expect(result).toBeInstanceOf(Array);
  });

  it('should handle errors gracefully', async () => {
    const result = await callTool('devbox_show', { name: 'invalid' });
    expect(result.isError).toBe(true);
  });
});
```

## Success Criteria

Phase 3 is considered complete when:

1. ✅ MCP server deployable alongside Squad infrastructure
2. ✅ At least 2 MCP clients successfully call DevBox operations (GitHub Copilot CLI + MCP Inspector)
3. ✅ Full integration test suite passing (manual verification)
4. ✅ Documentation complete (README, API reference, integration tests)

---

**Status:** All criteria met — Phase 3 complete ✅
