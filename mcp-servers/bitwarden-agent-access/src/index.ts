#!/usr/bin/env node

/**
 * bitwarden-agent-access MCP Server
 *
 * Wraps the bitwarden/agent-access `aac` CLI as an MCP server.
 * Provides secure credential access for AI agents via an end-to-end
 * encrypted tunnel — no vault session tokens, no collection scoping,
 * no Bitwarden organization required.
 *
 * Tools:
 *   - check_aac_available    : verify aac CLI is installed
 *   - list_aac_sessions      : list cached pairing sessions (no secrets)
 *   - clear_aac_sessions     : clear stale sessions
 *   - get_credential_info    : get username/metadata for a domain (no raw password)
 *   - run_with_credential    : run a command with credentials injected as env vars
 *
 * Security contract:
 *   - Raw passwords and TOTP seeds NEVER appear in tool output returned to the AI
 *   - Secrets are injected into child process environments only (via aac run)
 *   - The AI sees: username, hasPassword, hasTotp, uri, notes
 *
 * Setup:
 *   1. Install aac: https://github.com/bitwarden/agent-access/releases/latest
 *   2. On your trusted device: run `aac listen`
 *   3. Give the pairing token to the AI
 *   4. The AI calls get_credential_info with pairing_token
 *
 * Environment variables:
 *   AAC_BIN           - path to aac binary (default: "aac")
 *   AAC_PROXY_URL     - override relay proxy URL
 *   AAC_SESSION       - pre-cached session fingerprint
 *   AAC_PAIRING_TOKEN - default pairing token (for headless/CI use)
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { loadConfig } from "./config.js";
import { AacClient } from "./aac-client.js";
import { ALL_TOOLS, dispatchTool } from "./tools/index.js";

async function main() {
  const config = loadConfig();
  const client = new AacClient(config);

  const server = new Server(
    {
      name: "bitwarden-agent-access-mcp",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: ALL_TOOLS };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    return dispatchTool(client, name, args ?? {});
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("bitwarden-agent-access MCP server running on stdio");
  console.error(`aac binary: ${config.aacBin}`);
  if (config.proxyUrl) console.error(`Proxy: ${config.proxyUrl}`);
}

main().catch((error) => {
  console.error("Fatal error:", error instanceof Error ? error.message : String(error));
  process.exit(1);
});
