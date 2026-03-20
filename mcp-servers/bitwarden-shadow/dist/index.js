#!/usr/bin/env node
/**
 * Bitwarden Shadow MCP Server
 * Tools: shadow_item, unshadow_item, list_shadows
 */
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { loadConfig } from "./config.js";
import { TOOLS } from "./tools/index.js";
import { shadowItem } from "./tools/shadow-item.js";
import { unshadowItem } from "./tools/unshadow-item.js";
import { listShadows } from "./tools/list-shadows.js";
async function main() {
    const config = await loadConfig();
    const server = new Server({ name: "bitwarden-shadow-mcp", version: "0.1.0" }, { capabilities: { tools: {} } });
    server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));
    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;
        switch (name) {
            case "shadow_item": return await shadowItem(config, (args ?? {}));
            case "unshadow_item": return await unshadowItem(config, (args ?? {}));
            case "list_shadows": return await listShadows(config, (args ?? {}));
            default: return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
        }
    });
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("Bitwarden Shadow MCP Server running on stdio");
    console.error(`Shadow collection: ${config.shadowCollectionId}`);
    if (config.adminCollectionId)
        console.error(`Admin collection:  ${config.adminCollectionId}`);
}
main().catch((error) => { console.error("Fatal:", error.message); process.exit(1); });
//# sourceMappingURL=index.js.map