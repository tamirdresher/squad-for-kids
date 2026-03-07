# DevBox MCP Server

> **Phase 3: MCP Server Integration for DevBox Provisioning**  
> Issue #65 — MCP server interface for Microsoft DevBox operations

## Overview

The DevBox MCP Server provides a [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) interface for Microsoft DevBox provisioning operations. It wraps the Phase 1 templates and Phase 2 scripts with a standard MCP stdio transport, enabling any MCP client to provision and manage DevBox instances.

## Features

### Available Tools

1. **`devbox_list`** — List all DevBox instances
2. **`devbox_create`** — Create a new DevBox with specified configuration
3. **`devbox_clone`** — Clone an existing DevBox configuration
4. **`devbox_show`** — Get detailed information about a DevBox
5. **`devbox_status`** — Check provisioning status
6. **`devbox_delete`** — Delete a DevBox instance (teardown)
7. **`devbox_bulk_create`** — Create multiple DevBoxes in parallel

### Key Capabilities

- **Auto-detection:** Automatically discovers current DevBox configuration
- **Parallel provisioning:** Bulk create operations with configurable concurrency
- **Status monitoring:** Real-time provisioning status tracking
- **Flexible configuration:** Override defaults or use auto-detected values
- **Error handling:** Graceful error reporting with detailed messages

## Installation

### Prerequisites

- **Node.js** v18.0.0 or higher
- **Azure CLI** with `devcenter` extension
- **PowerShell** (pwsh) for script execution
- **Azure authentication** (`az login`)

### Install from npm (when published)

```bash
npm install -g @microsoft/devbox-mcp-server
```

### Build from source

```bash
cd devbox-provisioning/mcp-server
npm install
npm run build
```

## Usage

### Adding to MCP Configuration

Add to your MCP configuration file (`.copilot/mcp-config.json` or `.vscode/mcp.json`):

```json
{
  "mcpServers": {
    "devbox": {
      "command": "npx",
      "args": ["-y", "@microsoft/devbox-mcp-server"],
      "env": {}
    }
  }
}
```

Or for local development:

```json
{
  "mcpServers": {
    "devbox": {
      "command": "node",
      "args": ["C:/path/to/devbox-provisioning/mcp-server/dist/index.js"],
      "env": {}
    }
  }
}
```

### Using with GitHub Copilot CLI

Once configured, the tools are available to GitHub Copilot:

```bash
# List DevBoxes
@copilot List my DevBoxes

# Create a new DevBox
@copilot Create a DevBox named "feature-branch-env"

# Clone existing DevBox
@copilot Clone my DevBox as "hotfix-env"

# Check status
@copilot What's the status of DevBox "my-devbox"?

# Bulk provisioning
@copilot Create 3 DevBoxes for the team
```

### Using with MCP Clients

Any MCP client (VS Code, Teams, GitHub, etc.) can call the tools:

**Example: List DevBoxes**
```json
{
  "method": "tools/call",
  "params": {
    "name": "devbox_list",
    "arguments": {
      "format": "json"
    }
  }
}
```

**Example: Create DevBox**
```json
{
  "method": "tools/call",
  "params": {
    "name": "devbox_create",
    "arguments": {
      "name": "my-new-devbox",
      "waitForCompletion": true,
      "timeoutMinutes": 30
    }
  }
}
```

**Example: Clone DevBox**
```json
{
  "method": "tools/call",
  "params": {
    "name": "devbox_clone",
    "arguments": {
      "newName": "cloned-devbox",
      "sourceName": "original-devbox"
    }
  }
}
```

## API Reference

### devbox_list

List all DevBox instances for the authenticated user.

**Parameters:**
- `format` (optional): Output format (`json` or `table`, default: `json`)

**Returns:** JSON array of DevBox instances or table-formatted output.

---

### devbox_create

Create a new DevBox instance with specified configuration.

**Parameters:**
- `name` (required): Name for the new DevBox (3-63 chars, alphanumeric and hyphens)
- `devCenterName` (optional): Dev Center name (auto-detected if omitted)
- `projectName` (optional): Project name (auto-detected if omitted)
- `poolName` (optional): Pool name (auto-detected if omitted)
- `waitForCompletion` (optional): Wait for provisioning to complete (default: `true`)
- `timeoutMinutes` (optional): Timeout in minutes (default: `30`)

**Returns:** Success message with provisioning details.

---

### devbox_clone

Clone an existing DevBox configuration to create a new instance.

**Parameters:**
- `newName` (required): Name for the cloned DevBox
- `sourceName` (optional): Source DevBox to clone (auto-detected if omitted)
- `waitForCompletion` (optional): Wait for provisioning to complete (default: `true`)
- `timeoutMinutes` (optional): Timeout in minutes (default: `30`)

**Returns:** Success message with cloning details.

---

### devbox_show

Get detailed information about a specific DevBox instance.

**Parameters:**
- `name` (required): Name of the DevBox to query
- `format` (optional): Output format (`json` or `summary`, default: `json`)

**Returns:** Detailed DevBox information in JSON or summary format.

---

### devbox_status

Check the provisioning status of a DevBox.

**Parameters:**
- `name` (required): Name of the DevBox to check

**Returns:** Current provisioning status (e.g., `Succeeded`, `Running`, `Failed`).

---

### devbox_delete

Delete a DevBox instance (teardown).

**Parameters:**
- `name` (required): Name of the DevBox to delete
- `force` (optional): Force deletion without confirmation (default: `false`)

**Returns:** Success message with deletion confirmation.

---

### devbox_bulk_create

Create multiple DevBox instances in parallel.

**Parameters:**
- `count` (optional): Number of DevBoxes to create (1-20)
- `namePrefix` (optional): Prefix for auto-generated names (default: `devbox`)
- `names` (optional): Explicit array of names (overrides `count` and `namePrefix`)
- `sequential` (optional): Create sequentially instead of in parallel (default: `false`)
- `maxConcurrent` (optional): Max concurrent operations in parallel mode (default: `5`)

**Returns:** Success message with bulk provisioning summary.

## Architecture

```
┌─────────────────────┐
│   MCP Client        │  (GitHub Copilot, VS Code, Teams, etc.)
│   (stdio)           │
└──────────┬──────────┘
           │ MCP Protocol (stdio)
┌──────────▼──────────┐
│  DevBox MCP Server  │
│  (TypeScript/Node)  │
└──────────┬──────────┘
           │
     ┌─────┴──────┐
     │            │
┌────▼────┐  ┌───▼──────┐
│ Azure   │  │ Phase 1  │
│ CLI     │  │ & Phase 2│
│ Commands│  │ Scripts  │
└─────────┘  └──────────┘
```

The MCP server acts as a bridge:
1. **Receives** tool calls via MCP stdio transport
2. **Validates** parameters and maps to operations
3. **Executes** Azure CLI commands or PowerShell scripts
4. **Returns** formatted results to the MCP client

## Integration Testing

### Testing with MCP Inspector

Use the [MCP Inspector](https://github.com/modelcontextprotocol/inspector) to test the server:

```bash
npx @modelcontextprotocol/inspector node dist/index.js
```

This opens a web UI for interactive testing of all tools.

### Manual Testing

Run the server directly and send JSON-RPC requests:

```bash
node dist/index.js
```

Then send test requests via stdin:

```json
{"jsonrpc":"2.0","id":1,"method":"tools/list"}
```

## Troubleshooting

### Server Won't Start

**Error:** `Cannot find module '@modelcontextprotocol/sdk'`

**Solution:** Run `npm install` in the `mcp-server` directory.

---

**Error:** `pwsh: command not found`

**Solution:** Install PowerShell 7+ from [https://aka.ms/powershell](https://aka.ms/powershell).

---

### Tool Execution Fails

**Error:** `Azure CLI command failed`

**Solution:** Verify Azure CLI authentication:
```bash
az login
az account show
```

---

**Error:** `Script execution failed`

**Solution:** Ensure Phase 1/2 scripts exist at `../scripts/`:
```bash
ls devbox-provisioning/scripts/
# Should show: provision.ps1, clone-devbox.ps1, bulk-provision.ps1
```

---

### DevBox Creation Fails

**Error:** `Resource not found` or `Access denied`

**Solution:** Check permissions and configuration:
```bash
# Verify Dev Center access
az devcenter dev dev-box list

# List available projects and pools
az devcenter dev project list
az devcenter dev pool list --project-name "YOUR_PROJECT"
```

## Development

### Project Structure

```
mcp-server/
├── src/
│   └── index.ts          # Main MCP server implementation
├── dist/                 # Compiled JavaScript output
├── package.json          # Node.js project configuration
├── tsconfig.json         # TypeScript configuration
├── .gitignore
└── README.md             # This file
```

### Building

```bash
npm run build       # Compile TypeScript
npm run dev         # Watch mode for development
```

### Adding New Tools

1. Add tool definition to `TOOLS` array in `src/index.ts`
2. Implement handler in `handleToolCall` function
3. Update API documentation in this README
4. Rebuild: `npm run build`

## Contributing

To add features or fix issues:
1. Create a feature branch
2. Make changes to `src/index.ts`
3. Test with MCP Inspector
4. Update documentation
5. Submit a pull request

## References

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [MCP SDK Documentation](https://github.com/modelcontextprotocol/sdk)
- [Microsoft Dev Box Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Azure CLI Dev Center Extension](https://learn.microsoft.com/cli/azure/devcenter)

## Roadmap

### Current (Phase 3) ✅
- ✅ MCP server interface with 7 core tools
- ✅ stdio transport for universal MCP client support
- ✅ Auto-detection and configuration flexibility
- ✅ Bulk provisioning with parallel execution

### Future Enhancements
- 🔲 Resource monitoring and cost tracking tools
- 🔲 Custom image and network configuration tools
- 🔲 Scheduled hibernation and auto-start tools
- 🔲 Integration with CI/CD for ephemeral DevBoxes
- 🔲 Team management and access control tools

---

**Maintained by:** B'Elanna (Infrastructure Expert)  
**Issue:** #65 (Phase 3)  
**Status:** Complete — Ready for deployment
