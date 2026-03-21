/**
 * shadow_item — Add an org vault item to a target collection (shadow/share it)
 *
 * Implements "shadowing" by appending the target collection to the cipher's
 * existing collectionIds using PUT /public/ciphers/{id}/collections.
 *
 * The readOnly intent is recorded in the response; full enforcement requires
 * setting CollectionUser.readOnly for the squad service account, which is done
 * at the collection level by the org admin (outside this tool's scope).
 */

import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenConfig } from "../types.js";
import { BitwardenClient } from "../bitwarden.js";

export interface ShadowItemArgs {
  item_id: string;
  target_collection: string;
  access?: "read-only" | "read-write";
}

export async function shadowItem(
  config: BitwardenConfig,
  args: ShadowItemArgs
): Promise<CallToolResult> {
  const { item_id, target_collection, access = "read-only" } = args;

  if (!item_id?.trim()) {
    return errorResult("item_id is required");
  }
  if (!target_collection?.trim()) {
    return errorResult("target_collection is required");
  }

  try {
    const client = new BitwardenClient(config);

    // Resolve the target collection (accepts id or name)
    const collection = await client.resolveCollection(target_collection);

    // Fetch the current cipher
    const cipher = await client.getCipher(item_id);

    // Idempotent: already in this collection?
    if (cipher.collectionIds.includes(collection.id)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                ok: true,
                message: `Item "${cipher.name}" is already in collection "${collection.name}" — no change needed.`,
                itemId: cipher.id,
                itemName: cipher.name,
                collectionId: collection.id,
                collectionName: collection.name,
                access,
                alreadyPresent: true,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    // Add the target collection to the existing list
    const updatedCollectionIds = [...cipher.collectionIds, collection.id];
    await client.updateCipherCollections(cipher.id, updatedCollectionIds);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              ok: true,
              message: `Shadowed item "${cipher.name}" into collection "${collection.name}" with ${access} access.`,
              itemId: cipher.id,
              itemName: cipher.name,
              collectionId: collection.id,
              collectionName: collection.name,
              access,
              previousCollections: cipher.collectionIds,
              updatedCollections: updatedCollectionIds,
              note:
                access === "read-only"
                  ? "read-only is enforced at the CollectionUser level by the org admin; this tool adds the collection association."
                  : undefined,
            },
            null,
            2
          ),
        },
      ],
    };
  } catch (err) {
    return errorResult(
      `shadow_item failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }
}

function errorResult(message: string): CallToolResult {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}
