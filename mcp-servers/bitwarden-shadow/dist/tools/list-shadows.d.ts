import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenShadowConfig } from "../types.js";
export interface ListShadowsArgs {
    collection?: string;
    include_available?: boolean;
}
export declare function listShadows(config: BitwardenShadowConfig, args: ListShadowsArgs): Promise<CallToolResult>;
//# sourceMappingURL=list-shadows.d.ts.map