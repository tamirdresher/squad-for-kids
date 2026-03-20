import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type { BitwardenCollection, BitwardenItem } from "./types.js";

const execFileAsync = promisify(execFile);

export class BitwardenClient {
  constructor(private readonly session: string) {}

  private async run(args: string[]): Promise<string> {
    const argsWithSession = [...args, "--session", this.session];
    console.error(`[bw] ${args.slice(0, 3).join(" ")} ...`);
    try {
      const { stdout } = await execFileAsync("bw", argsWithSession, {
        maxBuffer: 10 * 1024 * 1024,
        timeout: 30_000,
        env: { ...process.env, BW_SESSION: this.session },
      });
      return stdout.trim();
    } catch (err: unknown) {
      const stderr = typeof err === "object" && err !== null && "stderr" in err
        ? String((err as { stderr: unknown }).stderr) : "";
      const code = typeof err === "object" && err !== null && "code" in err
        ? (err as { code: unknown }).code : "unknown";
      if (stderr.includes("Vault is locked")) {
        throw new Error("Bitwarden vault is locked. Run setup-bitwarden.ps1.");
      }
      throw new Error(`bw failed (exit ${code}): ${stderr || (err instanceof Error ? err.message : String(err))}`);
    }
  }

  async listCollections(): Promise<BitwardenCollection[]> {
    const raw = await this.run(["list", "collections"]);
    return JSON.parse(raw) as BitwardenCollection[];
  }

  async resolveCollection(idOrName: string): Promise<BitwardenCollection> {
    const collections = await this.listCollections();
    let match = collections.find((c) => c.id === idOrName);
    if (match) return match;
    const lower = idOrName.toLowerCase();
    match = collections.find((c) => c.name.toLowerCase() === lower);
    if (match) return match;
    const partials = collections.filter((c) => c.name.toLowerCase().includes(lower));
    if (partials.length === 1) return partials[0]!;
    if (partials.length > 1) {
      throw new Error(`Ambiguous collection "${idOrName}": ${partials.map((c) => `"${c.name}" (${c.id})`).join(", ")}`);
    }
    throw new Error(`Collection "${idOrName}" not found. Available: ${collections.map((c) => `"${c.name}" (${c.id})`).join(", ")}`);
  }

  async getItem(itemId: string): Promise<BitwardenItem> {
    const raw = await this.run(["get", "item", itemId]);
    return JSON.parse(raw) as BitwardenItem;
  }

  async listItemsInCollection(collectionId: string): Promise<BitwardenItem[]> {
    const raw = await this.run(["list", "items", "--collectionid", collectionId]);
    return JSON.parse(raw) as BitwardenItem[];
  }

  async updateItemCollections(item: BitwardenItem, newCollectionIds: string[]): Promise<BitwardenItem> {
    const updated: BitwardenItem = { ...item, collectionIds: newCollectionIds };
    const encoded = Buffer.from(JSON.stringify(updated)).toString("base64");
    const raw = await this.run(["edit", "item", item.id, encoded]);
    return JSON.parse(raw) as BitwardenItem;
  }

  static itemTypeName(type: number): string {
    switch (type) {
      case 1: return "login";
      case 2: return "note";
      case 3: return "card";
      case 4: return "identity";
      default: return `type-${type}`;
    }
  }
}
