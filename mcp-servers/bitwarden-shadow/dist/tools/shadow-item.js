import { BitwardenClient } from "../bitwarden-client.js";
export async function shadowItem(config, args) {
    try {
        const { item_id, target_collection } = args;
        if (!item_id?.trim())
            return err("item_id is required");
        const client = new BitwardenClient(config.session);
        const collection = await client.resolveCollection(target_collection ?? config.shadowCollectionId);
        let item;
        try {
            item = await client.getItem(item_id);
        }
        catch {
            return err(`Item "${item_id}" not found.`);
        }
        if (!item.organizationId)
            return err(`"${item.name}" is a personal vault item. Move it to the org vault first.`);
        if (item.collectionIds.includes(collection.id)) {
            return ok({ itemId: item.id, itemName: item.name, collectionId: collection.id, collectionName: collection.name, status: "already_shadowed", message: `"${item.name}" already in "${collection.name}".` });
        }
        const newIds = [...item.collectionIds, collection.id];
        await client.updateItemCollections(item, newIds);
        console.error(`[shadow_item] "${item.name}" added to "${collection.name}"`);
        return ok({ itemId: item.id, itemName: item.name, collectionId: collection.id, collectionName: collection.name, status: "shadowed", message: `"${item.name}" is now shadowed to "${collection.name}".`, collectionIds: newIds });
    }
    catch (error) {
        return err(`shadow_item failed: ${error instanceof Error ? error.message : String(error)}`);
    }
}
function ok(data) { return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] }; }
function err(message) { return { content: [{ type: "text", text: message }], isError: true }; }
//# sourceMappingURL=shadow-item.js.map