import { homedir } from "node:os";
import { join } from "node:path";
import { readFile } from "node:fs/promises";
export async function loadConfig() {
    const session = process.env.BW_SESSION;
    const shadowCollectionId = process.env.BW_SHADOW_COLLECTION_ID;
    const adminCollectionId = process.env.BW_ADMIN_COLLECTION_ID;
    if (session && shadowCollectionId) {
        return { session, shadowCollectionId, adminCollectionId };
    }
    try {
        const configPath = join(homedir(), ".squad", "bitwarden-session.json");
        const raw = await readFile(configPath, "utf-8");
        const parsed = JSON.parse(raw);
        const fileSession = session ?? parsed["session"];
        const fileCollectionId = shadowCollectionId ?? parsed["shadowCollectionId"] ?? parsed["folderId"];
        const fileAdminId = adminCollectionId ?? parsed["adminCollectionId"];
        if (!fileSession)
            throw new Error("BW_SESSION not set");
        if (!fileCollectionId)
            throw new Error("BW_SHADOW_COLLECTION_ID not set");
        return { session: fileSession, shadowCollectionId: fileCollectionId, adminCollectionId: fileAdminId };
    }
    catch (err) {
        if (err instanceof Error && (err.message.includes("BW_SESSION") || err.message.includes("BW_SHADOW")))
            throw err;
        console.error(`Config file issue: ${err instanceof Error ? err.message : String(err)}`);
    }
    const missing = [];
    if (!session)
        missing.push("BW_SESSION");
    if (!shadowCollectionId)
        missing.push("BW_SHADOW_COLLECTION_ID");
    throw new Error(`Missing: ${missing.join(", ")}. Run setup-bitwarden.ps1.`);
}
//# sourceMappingURL=config.js.map