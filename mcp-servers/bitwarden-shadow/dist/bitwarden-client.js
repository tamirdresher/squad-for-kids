import { execFile } from "node:child_process";
import { promisify } from "node:util";
const execFileAsync = promisify(execFile);
export class BitwardenClient {
    session;
    constructor(session) {
        this.session = session;
    }
    async run(args) {
        const argsWithSession = [...args, "--session", this.session];
        console.error(`[bw] ${args.slice(0, 3).join(" ")} ...`);
        try {
            const { stdout } = await execFileAsync("bw", argsWithSession, {
                maxBuffer: 10 * 1024 * 1024,
                timeout: 30_000,
                env: { ...process.env, BW_SESSION: this.session },
            });
            return stdout.trim();
        }
        catch (err) {
            const stderr = typeof err === "object" && err !== null && "stderr" in err
                ? String(err.stderr) : "";
            const code = typeof err === "object" && err !== null && "code" in err
                ? err.code : "unknown";
            if (stderr.includes("Vault is locked")) {
                throw new Error("Bitwarden vault is locked. Run setup-bitwarden.ps1.");
            }
            throw new Error(`bw failed (exit ${code}): ${stderr || (err instanceof Error ? err.message : String(err))}`);
        }
    }
    async listCollections() {
        const raw = await this.run(["list", "collections"]);
        return JSON.parse(raw);
    }
    async resolveCollection(idOrName) {
        const collections = await this.listCollections();
        let match = collections.find((c) => c.id === idOrName);
        if (match)
            return match;
        const lower = idOrName.toLowerCase();
        match = collections.find((c) => c.name.toLowerCase() === lower);
        if (match)
            return match;
        const partials = collections.filter((c) => c.name.toLowerCase().includes(lower));
        if (partials.length === 1)
            return partials[0];
        if (partials.length > 1) {
            throw new Error(`Ambiguous collection "${idOrName}": ${partials.map((c) => `"${c.name}" (${c.id})`).join(", ")}`);
        }
        throw new Error(`Collection "${idOrName}" not found. Available: ${collections.map((c) => `"${c.name}" (${c.id})`).join(", ")}`);
    }
    async getItem(itemId) {
        const raw = await this.run(["get", "item", itemId]);
        return JSON.parse(raw);
    }
    async listItemsInCollection(collectionId) {
        const raw = await this.run(["list", "items", "--collectionid", collectionId]);
        return JSON.parse(raw);
    }
    async updateItemCollections(item, newCollectionIds) {
        const updated = { ...item, collectionIds: newCollectionIds };
        const encoded = Buffer.from(JSON.stringify(updated)).toString("base64");
        const raw = await this.run(["edit", "item", item.id, encoded]);
        return JSON.parse(raw);
    }
    static itemTypeName(type) {
        switch (type) {
            case 1: return "login";
            case 2: return "note";
            case 3: return "card";
            case 4: return "identity";
            default: return `type-${type}`;
        }
    }
}
//# sourceMappingURL=bitwarden-client.js.map