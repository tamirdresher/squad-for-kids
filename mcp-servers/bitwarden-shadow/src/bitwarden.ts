/**
 * Bitwarden Shadow MCP Server — Bitwarden API Client
 *
 * Wraps the Bitwarden Public API and (for collection-cipher associations)
 * the internal organization endpoints.
 *
 * Bitwarden Public API docs: https://bitwarden.com/help/public-api/
 *
 * Key endpoints used:
 *   POST   /public/auth/token               — obtain Bearer token
 *   GET    /public/collections              — list org collections
 *   GET    /public/ciphers                  — list org ciphers (items)
 *   PUT    /public/ciphers/{id}/collections — update a cipher's collection list
 *   GET    /public/ciphers/{id}             — get single cipher
 */

import type { BitwardenConfig, BwCipher, BwCollection } from "./types.js";

interface TokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
}

interface BwApiCipher {
  id: string;
  name: string;
  type: number;
  organizationId: string;
  collectionIds: string[];
}

interface BwApiCollection {
  id: string;
  name: string;
  organizationId: string;
  externalId?: string;
}

/**
 * Thin wrapper around the Bitwarden Public API.
 *
 * Authentication: uses the Organization API Key (client_credentials OAuth2 flow).
 * The token is cached for the lifetime of the client instance.
 */
export class BitwardenClient {
  private config: BitwardenConfig;
  private _token: string | null = null;
  private _tokenExpiry: number = 0;

  constructor(config: BitwardenConfig) {
    this.config = config;
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /** Obtain (or return cached) Bearer token */
  private async getToken(): Promise<string> {
    const now = Date.now();
    if (this._token && now < this._tokenExpiry) {
      return this._token;
    }

    const url = `${this.config.serverUrl}/identity/connect/token`;
    const body = new URLSearchParams({
      grant_type: "client_credentials",
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      scope: "api.organization",
    });

    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: body.toString(),
    });

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(
        `Bitwarden auth failed (${resp.status}): ${text}`
      );
    }

    const data = (await resp.json()) as TokenResponse;
    this._token = data.access_token;
    // Expire 60 s before the real expiry to be safe
    this._tokenExpiry = now + (data.expires_in - 60) * 1000;
    return this._token;
  }

  /** Make an authenticated request to the Bitwarden Public API */
  private async request<T>(
    method: string,
    path: string,
    body?: unknown
  ): Promise<T> {
    const token = await this.getToken();
    const url = `${this.config.serverUrl}/api${path}`;

    const resp = await fetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });

    if (!resp.ok) {
      const text = await resp.text();
      throw new Error(
        `Bitwarden API error ${resp.status} ${method} ${path}: ${text}`
      );
    }

    // Some endpoints return 200 with empty body on success
    const text = await resp.text();
    if (!text) return undefined as T;
    return JSON.parse(text) as T;
  }

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  /** List all collections in the organization */
  async listCollections(): Promise<BwCollection[]> {
    const data = await this.request<{ data: BwApiCollection[] }>(
      "GET",
      "/public/collections"
    );
    return (data.data ?? []).map((c) => ({
      id: c.id,
      name: c.name,
      organizationId: c.organizationId,
      externalId: c.externalId,
    }));
  }

  /**
   * Resolve a collection by ID or name.
   * @throws if not found
   */
  async resolveCollection(idOrName: string): Promise<BwCollection> {
    const all = await this.listCollections();
    const found =
      all.find((c) => c.id === idOrName) ||
      all.find((c) => c.name.toLowerCase() === idOrName.toLowerCase());
    if (!found) {
      throw new Error(
        `Collection not found: "${idOrName}". ` +
          `Available: ${all.map((c) => `${c.name} (${c.id})`).join(", ")}`
      );
    }
    return found;
  }

  // ---------------------------------------------------------------------------
  // Ciphers (vault items)
  // ---------------------------------------------------------------------------

  /** List all ciphers (items) visible to the org API key */
  async listCiphers(): Promise<BwCipher[]> {
    const data = await this.request<{ data: BwApiCipher[] }>(
      "GET",
      "/public/ciphers"
    );
    return (data.data ?? []).map((c) => ({
      id: c.id,
      name: c.name,
      type: c.type,
      organizationId: c.organizationId,
      collectionIds: c.collectionIds ?? [],
    }));
  }

  /**
   * Get a single cipher by ID.
   * @throws if not found
   */
  async getCipher(itemId: string): Promise<BwCipher> {
    const data = await this.request<BwApiCipher>("GET", `/public/ciphers/${itemId}`);
    return {
      id: data.id,
      name: data.name,
      type: data.type,
      organizationId: data.organizationId,
      collectionIds: data.collectionIds ?? [],
    };
  }

  /**
   * Update the list of collections a cipher belongs to.
   *
   * Bitwarden uses PUT /public/ciphers/{id}/collections with the full
   * desired collection list (replaces existing associations).
   *
   * The readOnly flag is not exposed on the Public API for ciphers —
   * it is set per CollectionUser, not per CollectionCipher. We record
   * the intent in our shadow metadata but cannot enforce it via Public API alone.
   */
  async updateCipherCollections(
    itemId: string,
    collectionIds: string[]
  ): Promise<void> {
    await this.request<void>("PUT", `/public/ciphers/${itemId}/collections`, {
      collectionIds,
    });
  }
}
