/**
 * Bitwarden Shadow MCP Server — Tool Registry
 */

import type { Tool } from "@modelcontextprotocol/sdk/types.js";

export const TOOLS: Tool[] = [
  {
    name: "shadow_item",
    description:
      "Shadow (share) an org vault item into a target Bitwarden collection. " +
      "Adds the CollectionCipher association so members of the target collection " +
      "can see the item. Defaults to read-only access intent. Idempotent — safe to call if already shadowed.",
    inputSchema: {
      type: "object",
      required: ["item_id", "target_collection"],
      properties: {
        item_id: {
          type: "string",
          description: "UUID of the Bitwarden cipher (vault item) to shadow.",
        },
        target_collection: {
          type: "string",
          description:
            "ID or name of the Bitwarden collection to shadow the item into.",
        },
        access: {
          type: "string",
          enum: ["read-only", "read-write"],
          default: "read-only",
          description:
            "Access level for collection members. 'read-only' (default) is the recommended setting for cross-collection sharing. " +
            "Note: full enforcement of read-only requires the org admin to set CollectionUser.readOnly for the target collection members.",
        },
      },
    },
  },
  {
    name: "unshadow_item",
    description:
      "Remove a shadow: unlinks an org vault item from a target Bitwarden collection. " +
      "Removes the CollectionCipher association. Idempotent — safe to call if the shadow doesn't exist.",
    inputSchema: {
      type: "object",
      required: ["item_id", "target_collection"],
      properties: {
        item_id: {
          type: "string",
          description: "UUID of the Bitwarden cipher (vault item) to unshadow.",
        },
        target_collection: {
          type: "string",
          description:
            "ID or name of the Bitwarden collection to remove the item from.",
        },
      },
    },
  },
  {
    name: "list_shadows",
    description:
      "List all vault items that are shadowed into a given Bitwarden collection. " +
      "Returns item IDs, names, types, and how many collections each item belongs to.",
    inputSchema: {
      type: "object",
      required: ["collection"],
      properties: {
        collection: {
          type: "string",
          description:
            "ID or name of the Bitwarden collection to inspect.",
        },
      },
    },
  },
];
