import type { BitwardenCollection, BitwardenItem } from "./types.js";
export declare class BitwardenClient {
    private readonly session;
    constructor(session: string);
    private run;
    listCollections(): Promise<BitwardenCollection[]>;
    resolveCollection(idOrName: string): Promise<BitwardenCollection>;
    getItem(itemId: string): Promise<BitwardenItem>;
    listItemsInCollection(collectionId: string): Promise<BitwardenItem[]>;
    updateItemCollections(item: BitwardenItem, newCollectionIds: string[]): Promise<BitwardenItem>;
    static itemTypeName(type: number): string;
}
//# sourceMappingURL=bitwarden-client.d.ts.map