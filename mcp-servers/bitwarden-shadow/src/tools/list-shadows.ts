/**
 * list_shadows — Show which org vault items are shadowed into a given collection
 *
 * Fetches all ciphers visible to the org API key and returns those whose
 * collectionIds array contains the requested collection.
 */

import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { BitwardenConfig, ShadowEntry } from "../types.js";
import { BitwardenClient } from "../bitwarden.js";

export interface ListShadowsArgs {
  collection: string;
}

const CIPHER_TYPE_NAMES: Record<number, string> = {
  1: "Login",
  2: "SecureNote",
  3: "Card",
  4: "Identity",
};

export async function listShadows(
  config: BitwardenConfig,
  args: ListShadowsArgs
): Promise<CallToolResult> {
  const { collection } = args;

  if (!collection?.trim()) {
    return errorResult("collection is required");
  }

  try {
    const client = new BitwardenClient(config);

    // Resolve the collection
    const resolvedCollection = await client.resolveCollection(collection);

    // Fetch all ciphers
    const allCiphers = await client.listCiphers();

    // Filter those that are in this collection (excluding the collection itself as "home")
    const shadows: ShadowEntry[] = allCiphers
      .filter((c) => c.collectionIds.includes(resolvedCollection.id))
      .map((c) => ({
        itemId: c.id,
        itemName: c.name,
        itemType: CIPHER_TYPE_NAMES[c.type] ?? `Type${c.type}`,
        collectionId: resolvedCollection.id,
        collectionName: resolvedCollection.name,
        readOnly: c.readOnly ?? false,
        totalCollections: c.collectionIds.length,
      }));

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(
            {
              ok: true,
              collection: {
                id: resolvedCollection.id,
                name: resolvedCollection.name,
                organizationId: resolvedCollection.organizationId,
              },
              shadowCount: shadows.length,
              shadows,
              message:
                shadows.length === 0
                  ? `No items are shadowed into collection "${resolvedCollection.name}".`
                  : `${shadows.length} item(s) shadowed into collection "${resolvedCollection.name}".`,
            },
            null,
            2
          ),
        },
      ],
    };
  } catch (err) {
    return errorResult(
      `list_shadows failed: ${err instanceof Error ? err.message : String(err)}`
    );
  }
}

function errorResult(message: string): CallToolResult {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}
