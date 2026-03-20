import type { Tool } from "@modelcontextprotocol/sdk/types.js";

export const TOOLS: Tool[] = [
  {
    name: "shadow_item",
    description: "Add an existing org vault item to the squad collection for read-only shadow access. The item stays in its original collection — this creates a cross-collection link so squad members can read it. Requires item_id (Bitwarden UUID).",
    inputSchema: {
      type: "object",
      properties: {
        item_id: { type: "string", description: "Bitwarden item UUID" },
        target_collection: { type: "string", description: "Collection ID or name. Defaults to BW_SHADOW_COLLECTION_ID." }
      },
      required: ["item_id"]
    }
  },
  {
    name: "unshadow_item",
    description: "Remove an item from the squad collection (revoke squad read access). The item itself is NOT deleted. Refuses to remove the last remaining collection to prevent orphaning.",
    inputSchema: {
      type: "object",
      properties: {
        item_id: { type: "string", description: "Bitwarden item UUID to unshadow" },
        target_collection: { type: "string", description: "Collection ID or name. Defaults to BW_SHADOW_COLLECTION_ID." }
      },
      required: ["item_id"]
    }
  },
  {
    name: "list_shadows",
    description: "List items currently shadowed into the squad collection. Returns names and IDs only — never passwords. Set include_available=true to also see unshadowed items from the admin collection.",
    inputSchema: {
      type: "object",
      properties: {
        collection: { type: "string", description: "Collection ID or name. Defaults to BW_SHADOW_COLLECTION_ID." },
        include_available: { type: "boolean", description: "Also list admin-collection items not yet shadowed (requires BW_ADMIN_COLLECTION_ID).", default: false }
      }
    }
  }
];
