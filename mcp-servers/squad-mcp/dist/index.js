#!/usr/bin/env node
/**
 * Squad MCP Server — Main Entry Point
 *
 * Exposes squad operations (triage, routing, status, board) as MCP tools
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { loadConfig } from "./config.js";
import { TOOLS } from "./tools/index.js";
import { getSquadHealth } from "./tools/get-squad-health.js";
/**
 * Main server entry point
 */
async function main() {
    // Load configuration
    const config = await loadConfig();
    // Create MCP server
    const server = new Server({
        name: "squad-mcp",
        version: "0.1.0",
    }, {
        capabilities: {
            tools: {},
        },
    });
    // Register tool list handler
    server.setRequestHandler(ListToolsRequestSchema, async () => {
        return { tools: TOOLS };
    });
    // Register tool call handler
    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;
        switch (name) {
            case "get_squad_health":
                return await getSquadHealth(config, args ?? {});
            // Future tools will be added here:
            // case "triage_issue":
            //   return await triageIssue(config, args);
            // case "check_board_status":
            //   return await checkBoardStatus(config, args);
            // case "get_member_capacity":
            //   return await getMemberCapacity(config, args);
            // case "evaluate_routing":
            //   return await evaluateRouting(config, args);
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
    // Connect via stdio transport
    const transport = new StdioServerTransport();
    await server.connect(transport);
    // Log startup (to stderr to avoid interfering with stdio protocol)
    console.error("Squad MCP Server running on stdio");
    console.error(`Configuration: ${config.github.owner}/${config.github.repo}`);
    console.error(`Squad root: ${config.squadRoot}`);
}
// Start the server
main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
//# sourceMappingURL=index.js.map