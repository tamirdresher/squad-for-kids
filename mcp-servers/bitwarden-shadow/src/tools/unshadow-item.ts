/**
 * unshadow_item — Remove an org vault item from a target collection
 *
 * Reverses shadow_item by removing the target collection from the cipher's
 * collectionIds using PUT /public/ciphers/{id}/collections.
 */

import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenConfig } from "../types.js";
import { BitwardenClient } from "../bitwarden.js";

export interface UnshadowItemArgs {
  item_id: string;
  target_collection: string;
}

export async function unshadowItem(
  config: BitwardenConfig,
  args: UnshadowItemArgs
): Promise<CallToolResult> {
  const { item_id, target_collection } = args;

  if (!item_id?.trim()) {
    return errorResult("item_id is required");
  }
  if (!target_collection?.trim()) {
    return errorResult("target_collection is required");
  }

  try {
    const client = new BitwardenClient(config);

    // Resolve the target collection
    const collection = await client.resolveCollection(target_collection);

    // Fetch the current cipher
    const cipher = await client.getCipher(item_id);

    // Idempotent: not in this collection?
    if (!cipher.collectionIds.includes(collection.id)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                ok: true,
                message: `Item "${cipher.name}" is not in collection "${collection.name}" — no change needed.`,
                itemId: cipher.id,
                itemName: cipher.name,
                collectionId: collection.id,
                collectionName: collection.name,
                alreadyAbsent: true,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    // Remove the target collection from the list
    const updatedCollectionIds = cipher.collectionIds.filter(
      (id) => id !== collection.id
    );
    await client.updateCipherCollections(cipher.id, updatedCollectionIds);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              ok: true,
              message: `Removed shadow of item "${cipher.name}" from collection "${collection.name}".`,
              itemId: cipher.id,
              itemName: cipher.name,
              collectionId: collection.id,
              collectionName: collection.name,
              previousCollections: cipher.collectionIds,
              updatedCollections: updatedCollectionIds,
            },
            null,
            2
          ),
        },
      ],
    };
  } catch (err) {
    return errorResult(
      `unshadow_item failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }
}

function errorResult(message: string): CallToolResult {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}
