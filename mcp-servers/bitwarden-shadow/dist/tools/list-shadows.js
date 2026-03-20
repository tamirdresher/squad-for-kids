import { BitwardenClient } from "../bitwarden-client.js";
export async function listShadows(config, args) {
    try {
        const { collection, include_available = false } = args;
        const client = new BitwardenClient(config.session);
        const shadowCollection = await client.resolveCollection(collection ?? config.shadowCollectionId);
        let shadowedItems = [];
        try {
            shadowedItems = await client.listItemsInCollection(shadowCollection.id);
        }
        catch { /* empty */ }
        const shadows = shadowedItems.map((item) => ({ itemId: item.id, itemName: item.name, itemType: BitwardenClient.itemTypeName(item.type), collectionIds: item.collectionIds }));
        const result = { collection: { id: shadowCollection.id, name: shadowCollection.name }, shadowedCount: shadows.length, shadowed: shadows };
        if (include_available && config.adminCollectionId) {
            const adminCollection = await client.resolveCollection(config.adminCollectionId);
            let adminItems = [];
            try {
                adminItems = await client.listItemsInCollection(adminCollection.id);
            }
            catch { /* empty */ }
            const shadowedIds = new Set(shadows.map((s) => s.itemId));
            const available = adminItems.filter((item) => !shadowedIds.has(item.id)).map((item) => ({ itemId: item.id, itemName: item.name, itemType: BitwardenClient.itemTypeName(item.type) }));
            result["adminCollection"] = { id: adminCollection.id, name: adminCollection.name };
            result["availableToShadow"] = available;
            result["availableCount"] = available.length;
        }
        return { content: [{ type: "text", text: JSON.stringify(result, null, 2) }] };
    }
    catch (error) {
        return { content: [{ type: "text", text: `list_shadows failed: ${error instanceof Error ? error.message : String(error)}` }], isError: true };
    }
}
//# sourceMappingURL=list-shadows.js.map