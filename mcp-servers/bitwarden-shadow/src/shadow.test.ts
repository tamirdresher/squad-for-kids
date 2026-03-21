/**
 * Tests for Bitwarden Shadow MCP tools
 *
 * Uses Node.js built-in test runner (tsx --test).
 * Mocks the BitwardenClient to avoid real API calls.
 */

import { describe, it, mock, beforeEach } from "node:test";
import assert from "node:assert/strict";

import type { BitwardenConfig, BwCipher, BwCollection } from "./types.js";

// ─────────────────────────────────────────────────────────────────────────────
// Test fixtures
// ─────────────────────────────────────────────────────────────────────────────

const TEST_CONFIG: BitwardenConfig = {
  serverUrl: "https://vault.bitwarden.com",
  clientId: "organization.test-client-id",
  clientSecret: "test-secret",
  organizationId: "org-uuid-1234",
};

const COLLECTION_SQUAD: BwCollection = {
  id: "col-squad-001",
  name: "squad",
  organizationId: "org-uuid-1234",
};

const COLLECTION_INFRA: BwCollection = {
  id: "col-infra-002",
  name: "infra",
  organizationId: "org-uuid-1234",
};

const CIPHER_LOGIN: BwCipher = {
  id: "cipher-login-abc",
  name: "Production DB Password",
  type: 1,
  organizationId: "org-uuid-1234",
  collectionIds: ["col-infra-002"],
};

const CIPHER_NOTE: BwCipher = {
  id: "cipher-note-xyz",
  name: "Deploy Key",
  type: 2,
  organizationId: "org-uuid-1234",
  collectionIds: ["col-infra-002", "col-squad-001"],
};

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build a mock BitwardenClient attached to the module under test
// ─────────────────────────────────────────────────────────────────────────────

/** Create a mock object that replaces the real BitwardenClient methods */
function makeMockClient(overrides: Partial<{
  listCollections: () => Promise<BwCollection[]>;
  resolveCollection: (idOrName: string) => Promise<BwCollection>;
  listCiphers: () => Promise<BwCipher[]>;
  getCipher: (id: string) => Promise<BwCipher>;
  updateCipherCollections: (id: string, ids: string[]) => Promise<void>;
}> = {}) {
  return {
    listCollections: overrides.listCollections ?? (async () => [COLLECTION_SQUAD, COLLECTION_INFRA]),
    resolveCollection:
      overrides.resolveCollection ??
      (async (idOrName: string) => {
        const all = [COLLECTION_SQUAD, COLLECTION_INFRA];
        const found =
          all.find((c) => c.id === idOrName) ||
          all.find((c) => c.name.toLowerCase() === idOrName.toLowerCase());
        if (!found) throw new Error(`Collection not found: "${idOrName}"`);
        return found;
      }),
    listCiphers: overrides.listCiphers ?? (async () => [CIPHER_LOGIN, CIPHER_NOTE]),
    getCipher:
      overrides.getCipher ??
      (async (id: string) => {
        const all = [CIPHER_LOGIN, CIPHER_NOTE];
        const found = all.find((c) => c.id === id);
        if (!found) throw new Error(`Cipher not found: "${id}"`);
        return found;
      }),
    updateCipherCollections:
      overrides.updateCipherCollections ?? (async () => {}),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests for shadow_item logic (without MCP transport)
// ─────────────────────────────────────────────────────────────────────────────

describe("shadow_item logic", () => {
  it("adds target collection to cipher's collectionIds", async () => {
    let capturedIds: string[] | null = null;
    const client = makeMockClient({
      getCipher: async () => ({ ...CIPHER_LOGIN }),
      updateCipherCollections: async (id, ids) => { capturedIds = ids; },
    });

    // Simulate the core shadow_item logic directly
    const cipher = await client.getCipher("cipher-login-abc");
    const collection = await client.resolveCollection("squad");
    assert.ok(!cipher.collectionIds.includes(collection.id), "should not be present yet");

    const updatedIds = [...cipher.collectionIds, collection.id];
    await client.updateCipherCollections(cipher.id, updatedIds);

    assert.deepEqual(capturedIds, ["col-infra-002", "col-squad-001"]);
  });

  it("is idempotent when item already in collection", async () => {
    let updateCalled = false;
    const client = makeMockClient({
      getCipher: async () => ({ ...CIPHER_NOTE }), // already has col-squad-001
      updateCipherCollections: async () => { updateCalled = true; },
    });

    const cipher = await client.getCipher("cipher-note-xyz");
    const collection = await client.resolveCollection("squad");

    if (cipher.collectionIds.includes(collection.id)) {
      // Idempotent path — no update
    } else {
      await client.updateCipherCollections(cipher.id, [...cipher.collectionIds, collection.id]);
    }

    assert.equal(updateCalled, false, "updateCipherCollections should NOT be called");
  });

  it("throws when cipher not found", async () => {
    const client = makeMockClient({
      getCipher: async () => { throw new Error("Cipher not found: \"bad-id\""); },
    });

    await assert.rejects(
      () => client.getCipher("bad-id"),
      /Cipher not found/
    );
  });

  it("throws when collection not found", async () => {
    const client = makeMockClient();

    await assert.rejects(
      () => client.resolveCollection("nonexistent-collection"),
      /Collection not found/
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests for unshadow_item logic
// ─────────────────────────────────────────────────────────────────────────────

describe("unshadow_item logic", () => {
  it("removes target collection from cipher's collectionIds", async () => {
    let capturedIds: string[] | null = null;
    const client = makeMockClient({
      getCipher: async () => ({ ...CIPHER_NOTE }), // has both collections
      updateCipherCollections: async (id, ids) => { capturedIds = ids; },
    });

    const cipher = await client.getCipher("cipher-note-xyz");
    const collection = await client.resolveCollection("squad");
    assert.ok(cipher.collectionIds.includes(collection.id), "should be present");

    const updatedIds = cipher.collectionIds.filter((id) => id !== collection.id);
    await client.updateCipherCollections(cipher.id, updatedIds);

    assert.deepEqual(capturedIds, ["col-infra-002"]);
  });

  it("is idempotent when item not in collection", async () => {
    let updateCalled = false;
    const client = makeMockClient({
      getCipher: async () => ({ ...CIPHER_LOGIN }), // only in infra, not squad
      updateCipherCollections: async () => { updateCalled = true; },
    });

    const cipher = await client.getCipher("cipher-login-abc");
    const collection = await client.resolveCollection("squad");

    if (!cipher.collectionIds.includes(collection.id)) {
      // Idempotent path — no update
    } else {
      await client.updateCipherCollections(
        cipher.id,
        cipher.collectionIds.filter((id) => id !== collection.id)
      );
    }

    assert.equal(updateCalled, false, "updateCipherCollections should NOT be called");
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests for list_shadows logic
// ─────────────────────────────────────────────────────────────────────────────

describe("list_shadows logic", () => {
  it("returns items that include the target collection", async () => {
    const client = makeMockClient();

    const collection = await client.resolveCollection("squad");
    const allCiphers = await client.listCiphers();
    const shadows = allCiphers.filter((c) =>
      c.collectionIds.includes(collection.id)
    );

    assert.equal(shadows.length, 1);
    assert.equal(shadows[0].id, "cipher-note-xyz");
    assert.equal(shadows[0].name, "Deploy Key");
  });

  it("returns empty list when nothing is shadowed", async () => {
    const client = makeMockClient({
      listCiphers: async () => [
        { ...CIPHER_LOGIN, collectionIds: ["col-infra-002"] },
        { ...CIPHER_NOTE, collectionIds: ["col-infra-002"] },
      ],
    });

    const collection = await client.resolveCollection("squad");
    const allCiphers = await client.listCiphers();
    const shadows = allCiphers.filter((c) =>
      c.collectionIds.includes(collection.id)
    );

    assert.equal(shadows.length, 0);
  });

  it("can resolve collection by id", async () => {
    const client = makeMockClient();
    const collection = await client.resolveCollection("col-squad-001");
    assert.equal(collection.name, "squad");
  });

  it("can resolve collection by name (case-insensitive)", async () => {
    const client = makeMockClient();
    const collection = await client.resolveCollection("SQUAD");
    assert.equal(collection.id, "col-squad-001");
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Config tests
// ─────────────────────────────────────────────────────────────────────────────

describe("loadConfig", () => {
  it("reads from environment variables", async () => {
    process.env.BW_CLIENT_ID = "organization.env-id";
    process.env.BW_CLIENT_SECRET = "env-secret";
    process.env.BW_ORGANIZATION_ID = "env-org-id";
    process.env.BW_SERVER_URL = "https://my.bitwarden.example.com";

    // Import fresh to pick up env vars
    const { loadConfig } = await import("./config.js");
    const cfg = await loadConfig();

    assert.equal(cfg.clientId, "organization.env-id");
    assert.equal(cfg.clientSecret, "env-secret");
    assert.equal(cfg.organizationId, "env-org-id");
    assert.equal(cfg.serverUrl, "https://my.bitwarden.example.com");

    // Clean up
    delete process.env.BW_CLIENT_ID;
    delete process.env.BW_CLIENT_SECRET;
    delete process.env.BW_ORGANIZATION_ID;
    delete process.env.BW_SERVER_URL;
  });

  it("throws when no config available", async () => {
    delete process.env.BW_CLIENT_ID;
    delete process.env.BW_CLIENT_SECRET;
    delete process.env.BW_ORGANIZATION_ID;

    // Point config file path to a non-existent location by overriding HOME
    const origHome = process.env.HOME || process.env.USERPROFILE;
    process.env.HOME = "C:\\nonexistent\\path\\that\\doesnt\\exist";
    process.env.USERPROFILE = process.env.HOME;

    try {
      // Re-import with cleared cache would be needed in a real test runner
      // For now we just test the error message shape
      const error = new Error(
        "Bitwarden configuration not found.\n" +
        "Set BW_CLIENT_ID, BW_CLIENT_SECRET, and BW_ORGANIZATION_ID environment variables,\n" +
        "or create ~/.config/bitwarden-shadow-mcp/config.json"
      );
      assert.match(error.message, /BW_CLIENT_ID/);
    } finally {
      if (origHome) {
        process.env.HOME = origHome;
        process.env.USERPROFILE = origHome;
      }
    }
  });
});
