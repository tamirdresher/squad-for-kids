import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenShadowConfig, BitwardenItem, ShadowEntry } from "../types.js";
import { BitwardenClient } from "../bitwarden-client.js";

export interface ListShadowsArgs { collection?: string; include_available?: boolean; }

export async function listShadows(config: BitwardenShadowConfig, args: ListShadowsArgs): Promise<CallToolResult> {
  try {
    const { collection, include_available = false } = args;
    const client = new BitwardenClient(config.session);
    const shadowCollection = await client.resolveCollection(collection ?? config.shadowCollectionId);
    let shadowedItems: BitwardenItem[] = [];
    try { shadowedItems = await client.listItemsInCollection(shadowCollection.id); } catch { /* empty */ }
    const shadows: ShadowEntry[] = shadowedItems.map((item) => ({ itemId: item.id, itemName: item.name, itemType: BitwardenClient.itemTypeName(item.type), collectionIds: item.collectionIds }));
    const result: Record<string, unknown> = { collection: { id: shadowCollection.id, name: shadowCollection.name }, shadowedCount: shadows.length, shadowed: shadows };
    if (include_available && config.adminCollectionId) {
      const adminCollection = await client.resolveCollection(config.adminCollectionId);
      let adminItems: BitwardenItem[] = [];
      try { adminItems = await client.listItemsInCollection(adminCollection.id); } catch { /* empty */ }
      const shadowedIds = new Set(shadows.map((s) => s.itemId));
      const available = adminItems.filter((item) => !shadowedIds.has(item.id)).map((item) => ({ itemId: item.id, itemName: item.name, itemType: BitwardenClient.itemTypeName(item.type) }));
      result["adminCollection"] = { id: adminCollection.id, name: adminCollection.name };
      result["availableToShadow"] = available;
      result["availableCount"] = available.length;
    }
    return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
  } catch (error) { return { content: [{ type: "text", text: `list_shadows failed: ${error instanceof Error ? error.message : String(error)}` }], isError: true }; }
}
