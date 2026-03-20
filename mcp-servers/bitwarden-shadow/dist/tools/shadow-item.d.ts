import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenShadowConfig } from "../types.js";
export interface ShadowItemArgs {
    item_id: string;
    target_collection?: string;
}
export declare function shadowItem(config: BitwardenShadowConfig, args: ShadowItemArgs): Promise<CallToolResult>;
//# sourceMappingURL=shadow-item.d.ts.map