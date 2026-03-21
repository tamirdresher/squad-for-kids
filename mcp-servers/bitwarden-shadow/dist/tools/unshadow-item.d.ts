import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenShadowConfig } from "../types.js";
export interface UnshadowItemArgs {
    item_id: string;
    target_collection?: string;
}
export declare function unshadowItem(config: BitwardenShadowConfig, args: UnshadowItemArgs): Promise<CallToolResult>;
//# sourceMappingURL=unshadow-item.d.ts.map