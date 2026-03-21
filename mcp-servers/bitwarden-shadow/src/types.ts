/**
 * Bitwarden Shadow MCP Server — Types
 */

/** Bitwarden API configuration */
export interface BitwardenConfig {
  /** Bitwarden server URL (default: https://vault.bitwarden.com) */
  serverUrl: string;
  /** API client ID (from env BW_CLIENT_ID) */
  clientId: string;
  /** API client secret (from env BW_CLIENT_SECRET) */
  clientSecret: string;
  /** Organization ID the server operates on */
  organizationId: string;
}

/** Minimal representation of a Bitwarden collection */
export interface BwCollection {
  id: string;
  name: string;
  organizationId: string;
  externalId?: string;
}

/** Minimal representation of a Bitwarden cipher (vault item) */
export interface BwCipher {
  id: string;
  name: string;
  type: number; // 1=Login, 2=SecureNote, 3=Card, 4=Identity
  organizationId: string;
  collectionIds: string[];
  /** ReadOnly flag per collection — set on the CollectionCipher association */
  readOnly?: boolean;
}

/** A shadow association: item ↔ collection */
export interface ShadowEntry {
  itemId: string;
  itemName: string;
  collectionId: string;
  collectionName: string;
  readOnly: boolean;
}

/** Result returned by list_shadows */
export interface ListShadowsResult {
  collection: BwCollection;
  shadows: ShadowEntry[];
}
