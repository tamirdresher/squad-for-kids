/**
 * Squad MCP Server — Get Squad Health Tool
 *
 * Returns comprehensive squad health metrics
 */
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { SquadConfig } from "../types.js";
export declare function getSquadHealth(config: SquadConfig, args: {
    includeMetrics?: boolean;
}): Promise<CallToolResult>;
//# sourceMappingURL=get-squad-health.d.ts.map