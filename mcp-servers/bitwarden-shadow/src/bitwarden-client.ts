/**
 * Bitwarden CLI client wrapper
 * All vault operations go through this module
 */

import { exec } from "child_process";
import { promisify } from "util";
import type { BitwardenItem, BitwardenCollection } from "./types.js";

const execAsync = promisify(exec);

export class BitwardenClient {
  constructor(private readonly sessionToken: string) {}

  /**
   * Get a vault item by ID
   * Returns full item metadata but this client never exposes passwords/secrets to callers
   */
  async getItem(itemId: string): Promise<BitwardenItem> {
    const { stdout, stderr } = await execAsync(
      `bw get item ${itemId} --session ${this.sessionToken}`
    );

    if (stderr) {
      console.error(`[bw stderr] ${stderr}`);
    }

    return JSON.parse(stdout);
  }

  /**
   * List all items in a specific collection
   */
  async listItemsInCollection(collectionId: string): Promise<BitwardenItem[]> {
    const { stdout, stderr } = await execAsync(
      `bw list items --collectionid ${collectionId} --session ${this.sessionToken}`
    );

    if (stderr) {
      console.error(`[bw stderr] ${stderr}`);
    }

    return JSON.parse(stdout);
  }

  /**
   * Get collection details by ID
   */
  async getCollection(collectionId: string): Promise<BitwardenCollection> {
    const { stdout, stderr } = await execAsync(
      `bw get collection ${collectionId} --session ${this.sessionToken}`
    );

    if (stderr) {
      console.error(`[bw stderr] ${stderr}`);
    }

    return JSON.parse(stdout);
  }

  /**
   * Edit a vault item (used to update collectionIds for shadowing)
   */
  async editItem(itemId: string, item: BitwardenItem): Promise<BitwardenItem> {
    const itemJson = JSON.stringify(item);
    const base64Item = Buffer.from(itemJson).toString("base64");

    const { stdout, stderr } = await execAsync(
      `bw edit item ${itemId} ${base64Item} --session ${this.sessionToken}`
    );

    if (stderr) {
      console.error(`[bw stderr] ${stderr}`);
    }

    return JSON.parse(stdout);
  }

  /**
   * Sync vault with server (useful after remote changes)
   */
  async sync(): Promise<void> {
    const { stderr } = await execAsync(
      `bw sync --session ${this.sessionToken}`
    );

    if (stderr) {
      console.error(`[bw stderr] ${stderr}`);
    }
  }
}
