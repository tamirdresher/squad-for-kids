import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenShadowConfig } from "../types.js";
import { BitwardenClient } from "../bitwarden-client.js";

export interface UnshadowItemArgs { item_id: string; target_collection?: string; }

export async function unshadowItem(config: BitwardenShadowConfig, args: UnshadowItemArgs): Promise<CallToolResult> {
  try {
    const { item_id, target_collection } = args;
    if (!item_id?.trim()) return err("item_id is required");
    const client = new BitwardenClient(config.session);
    const collection = await client.resolveCollection(target_collection ?? config.shadowCollectionId);
    let item;
    try { item = await client.getItem(item_id); }
    catch { return err(`Item "${item_id}" not found.`); }
    if (!item.collectionIds.includes(collection.id)) {
      return ok({ itemId: item.id, itemName: item.name, collectionId: collection.id, collectionName: collection.name, status: "not_shadowed", message: `"${item.name}" is not in "${collection.name}".` });
    }
    const remaining = item.collectionIds.filter((id) => id !== collection.id);
    if (remaining.length === 0) return err(`Refusing: removing "${collection.name}" would leave "${item.name}" with no collections.`);
    await client.updateItemCollections(item, remaining);
    console.error(`[unshadow_item] "${item.name}" removed from "${collection.name}"`);
    return ok({ itemId: item.id, itemName: item.name, collectionId: collection.id, collectionName: collection.name, status: "unshadowed", message: `"${item.name}" removed from "${collection.name}".`, remainingCollectionIds: remaining });
  } catch (error) { return err(`unshadow_item failed: ${error instanceof Error ? error.message : String(error)}`); }
}

function ok(data: Record<string, unknown>): CallToolResult { return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] }; }
function err(message: string): CallToolResult { return { content: [{ type: "text", text: message }], isError: true }; }
