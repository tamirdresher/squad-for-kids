#!/usr/bin/env node

/**
 * Bitwarden Shadow MCP Server — Main Entry Point
 *
 * Exposes three MCP tools for cross-collection Bitwarden item sharing:
 *   - shadow_item      : add a vault item to a target collection
 *   - unshadow_item    : remove a vault item from a target collection
 *   - list_shadows     : list items shadowed into a given collection
 *
 * Authentication uses the Bitwarden Organization API Key via the
 * client_credentials OAuth2 flow (env vars: BW_CLIENT_ID, BW_CLIENT_SECRET,
 * BW_ORGANIZATION_ID, BW_SERVER_URL).
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { loadConfig } from "./config.js";
import { TOOLS } from "./tools/index.js";
import { shadowItem } from "./tools/shadow-item.js";
import { unshadowItem } from "./tools/unshadow-item.js";
import { listShadows } from "./tools/list-shadows.js";

async function main() {
  const config = await loadConfig();

  const server = new Server(
    {
      name: "bitwarden-shadow-mcp",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    switch (name) {
      case "shadow_item":
        return await shadowItem(config, args as unknown as Parameters<typeof shadowItem>[1]);

      case "unshadow_item":
        return await unshadowItem(config, args as unknown as Parameters<typeof unshadowItem>[1]);

      case "list_shadows":
        return await listShadows(config, args as unknown as Parameters<typeof listShadows>[1]);

      default:
        return {
          content: [
            {
              type: "text",
              text: `Unknown tool: ${name}`,
            },
          ],
          isError: true,
        };
    }
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("Bitwarden Shadow MCP Server running on stdio");
  console.error(`Server: ${config.serverUrl}`);
  console.error(`Org:    ${config.organizationId}`);
}

main().catch((error) => {
  console.error("Fatal error:", error.message);
  process.exit(1);
});
