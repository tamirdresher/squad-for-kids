# Bitwarden Shadow Access — Design & Implementation

**Issue:** [#1057](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1057)  
**Status:** In Design  
**Author:** Picard  
**Date:** 2026-03-20

---

## Problem

Squad agents (Picard, Data, B'Elanna, etc.) need read access to certain secrets that currently live in Tamir's **personal Bitwarden vault**:

- GitHub personal access tokens
- Webhook signing secrets
- Third-party API keys (Azure, OpenAI, cloud services)
- Service account credentials

The naive solutions are bad:

| Option | Why it fails |
|--------|-------------|
| Duplicate items | Two copies to keep in sync — manual toil, drift risk |
| Full vault access | Agents see financial data, personal passwords, everything |
| Hard-code in scripts | Exposed in repo, no rotation, no audit trail |

What we need is a **shadow system**: one copy of the secret, two views with different permission levels.

---

## Solution: Bitwarden Multi-Collection Architecture

Bitwarden supports exactly this via the **`CollectionCipher` junction table**: a single cipher can belong to multiple collections simultaneously. Each collection has independent access control — one collection can grant `ReadOnly=1` while another grants full CRUD.

### How it works

```
Cipher X  ─────────────────────────────────────────────────────────────
               ↓                                ↓
    Collection "Tamir Admin"         Collection "Squad Ops"
    ReadOnly = 0 (full CRUD)         ReadOnly = 1 (read-only)
    Tamir personal API key           Squad service account key
```

A single item — one source of truth — visible in two different access contexts with different permissions. When Tamir rotates a key, it is immediately reflected in both views.

---

## Architecture

### Organization Structure

```
Organization: "TAM Research"
│
├── Collection: "Tamir Admin"          ← Tamir has full CRUD
│   ├── [All items Tamir manages]
│   └── [Including items shadowed to squad]
│
├── Collection: "Squad Ops"            ← Squad read-only service account
│   ├── GitHub PAT (shadowed from Tamir Admin)
│   ├── Webhook secrets (shadowed)
│   ├── Azure service principal (shadowed)
│   └── OpenAI API key (shadowed)
│
└── Collection: "Squad Secrets"        ← Squad read/write service account
    ├── squad/bitwarden-mcp-session
    ├── squad/github-app-key
    └── [Items agents CREATE for themselves]
```

### Access Model

| Collection     | Tamir account | Squad Ops key | Squad Secrets key |
|----------------|:-------------:|:-------------:|:-----------------:|
| Tamir Admin    | Read/Write    | No access     | No access         |
| Squad Ops      | Read/Write    | Read-only ✅  | No access         |
| Squad Secrets  | Read/Write    | No access     | Read/Write ✅     |

### Shadow Item Flow

```
Tamir wants squad to read "GitHub PAT":

1. Item "GitHub PAT" exists in Collection "Tamir Admin"
2. Tamir (or shadow_item tool) calls:
       PUT /api/ciphers/{id}/collections
       body: { collectionIds: ["tamir-admin-id", "squad-ops-id"] }
3. Item now appears in Squad Ops collection (read-only)
4. Squad agent reads it via Bitwarden API using Squad Ops service account
5. Item is NOT duplicated — same cipher ID, two collection memberships

To "unshadow" (revoke squad access):
6. Tamir calls:
       PUT /api/ciphers/{id}/collections
       body: { collectionIds: ["tamir-admin-id"] }   // Squad Ops removed
7. Item immediately disappears from squad view
```

---

## Items to Include in Squad Ops Collection

### ✅ Include (operational secrets agents need)

| Item Pattern            | Type         | Why agents need it                       |
|-------------------------|--------------|------------------------------------------|
| GitHub PAT              | Login        | Create PRs, push commits, manage issues  |
| Webhook - GitHub        | Secure Note  | Validate inbound GitHub webhook payloads |
| Azure SP - TAM Research | Login        | Deploy to Azure, manage resources        |
| OpenAI API Key          | Secure Note  | AI content generation (podcasts, blogs)  |
| Teams Webhook URL       | Secure Note  | Post notifications to Teams channels     |
| Gumroad API Key         | Secure Note  | Revenue tracking, product management     |
| DevBox API Key          | Secure Note  | Provision and manage dev boxes           |
| YouTube API             | Secure Note  | Upload videos, manage channel            |

### ❌ Never Include (personal/financial)

| Category              | Examples                               |
|-----------------------|----------------------------------------|
| Banking/financial     | Bank logins, credit cards              |
| Personal email        | Gmail, Outlook personal                |
| Medical               | Health portals                         |
| Identity documents    | Government ID portals                  |
| Master keys           | Vault master password, recovery codes  |
| Personal accounts     | Netflix, social media, family accounts |

**Rule:** If it could embarrass Tamir or be used for fraud, it never goes near Squad Ops.

---

## MCP Tool Design: `shadow_item`

The `shadow_item` tool (issue #1058) automates the shadow/unshadow flow so Tamir never has to call Bitwarden APIs manually.

### Tool Specifications

```typescript
// shadow_item — Add a vault item to the squad read-only view
interface ShadowItemParams {
  item_id: string;              // Bitwarden cipher UUID
  target_collection?: string;   // Default: "Squad Ops"
  access?: "read-only" | "read-write";  // Default: "read-only"
}
interface ShadowItemResult {
  success: boolean;
  item_name: string;
  collection: string;
  collection_ids: string[];     // All collections item now belongs to
  message: string;
}

// unshadow_item — Remove an item from the squad view
interface UnshadowItemParams {
  item_id: string;
  target_collection?: string;   // Default: "Squad Ops"
}

// list_shadows — Audit what items are visible to squad
interface ListShadowsParams {
  collection?: string;          // Default: "Squad Ops"
}
interface ListShadowsResult {
  collection: string;
  items: Array<{
    id: string;
    name: string;
    type: "login" | "note" | "card" | "identity";
    also_in_collections: string[];
  }>;
}

// get_item — Read a secret (uses Squad Ops key — read-only)
interface GetItemParams {
  name: string;                 // Item name or ID
  field?: string;               // "password", "username", "notes", etc.
}
```

### API Flow

The tools use the **Bitwarden Public API** (not the CLI):

```
Auth: POST https://identity.bitwarden.com/connect/token
      grant_type=client_credentials
      → Bearer token

shadow_item:
  GET  https://api.bitwarden.com/ciphers/{id}
  PUT  https://api.bitwarden.com/ciphers/{id}/collections
    body: { collectionIds: [...existing, targetCollectionId] }

list_shadows:
  GET  https://api.bitwarden.com/ciphers
  filter: collectionIds contains squadOpsCollectionId

get_item (Squad Ops service account):
  GET  https://api.bitwarden.com/ciphers
  filter: name matches, collectionIds contains squadOpsCollectionId
```

### MCP Server Placement

The tools live in a **new `bitwarden-shadow` MCP server** separate from `squad-mcp`:

```
mcp-servers/
├── squad-mcp/            ← Squad health, triage, routing (GitHub-focused)
└── bitwarden-shadow/     ← Shadow access, secret management (Bitwarden-focused)
    ├── README.md
    ├── package.json
    ├── tsconfig.json
    └── src/
        ├── index.ts
        ├── config.ts
        ├── bitwarden-client.ts   ← API client (client_credentials OAuth)
        ├── types.ts
        └── tools/
            ├── shadow-item.ts
            ├── unshadow-item.ts
            ├── list-shadows.ts
            └── index.ts
```

**Why separate:** Different auth credentials, different concern area, different agents use it differently. Separation keeps `squad-mcp` focused on GitHub/squad operations.

---

## Security Model

### Authentication Tiers

```
Tier 1 — Tamir personal session (BW_SESSION)
  Full CRUD on all collections.
  Used by: Tamir only, in his terminal.
  Setup: bw login --apikey + bw unlock

Tier 2 — Organization Admin API Key (BW_ORG_CLIENT_ID + BW_ORG_CLIENT_SECRET)
  Required for shadow_item / unshadow_item operations.
  Can add/remove collection memberships via Public API.
  Never stored in repo — lives in Tamir Admin collection.
  Setup: vault.bitwarden.com → Organization → Settings → API Key

Tier 3 — Squad Ops Service Account  (BW_SQUAD_OPS_CLIENT_ID + SECRET)
  Read-only access to "Squad Ops" collection only.
  Cannot see Tamir Admin collection or Squad Secrets collection.
  Cannot modify or delete any items.
  Setup: vault.bitwarden.com → Organization → Service Accounts

Tier 4 — Squad Secrets Service Account  (BW_SQUAD_SECRETS_CLIENT_ID + SECRET)
  Read/write on "Squad Secrets" collection only.
  For agents creating/updating their own operational keys.
  Setup: vault.bitwarden.com → Organization → Service Accounts
```

### Agent Permissions Matrix

| Agent    | Squad Ops (read) | Squad Secrets (r/w) | Org Admin API |
|----------|:----------------:|:-------------------:|:-------------:|
| Picard   | ✅               | ✅                  | ❌            |
| Data     | ✅               | ✅                  | ❌            |
| B'Elanna | ✅               | ✅                  | ❌            |
| Ralph    | ✅               | ❌                  | ❌            |
| Tamir    | ✅               | ✅                  | ✅ (manual)   |

> Ralph is monitoring-only — reads webhook status from Squad Ops, no ability to create or modify secrets.

### Audit Trail

All reads and writes to org items are logged in Bitwarden event logs:
`vault.bitwarden.com → Organization → Reports → Event Logs`

Events logged: `item_accessed`, `item_updated`, `collection_updated`

---

## Implementation Steps for Bitwarden Admin

### Prerequisites

- Bitwarden CLI: `winget install Bitwarden.CLI`
- Bitwarden Organization ("TAM Research") created
- Organization admin access

### Step 1: Create Collections

At vault.bitwarden.com → Organization → Collections, create:
- `Tamir Admin` — your account: Can Manage
- `Squad Ops` — your account: Can Manage
- `Squad Secrets` — your account: Can Manage

Or run the guided setup script:
```powershell
.\scripts\setup-bitwarden-squad-collection.ps1
```

### Step 2: Move personal items to the Organization

Items must be **in the Organization** (not personal vault) to be in collections.

```bash
bw move <item_id> <org_id>
# Or: vault.bitwarden.com → item → Edit → Organization → Select org
```

### Step 3: Create Squad Ops Service Account

1. vault.bitwarden.com → Organization → Service Accounts
2. Create: `squad-ops-readonly`
3. Grant: Read access to Collection "Squad Ops"
4. Generate access token → save CLIENT_ID and CLIENT_SECRET
5. Set env vars: `BW_SQUAD_OPS_CLIENT_ID`, `BW_SQUAD_OPS_CLIENT_SECRET`

### Step 4: Create Squad Secrets Service Account

1. Create: `squad-secrets-readwrite`
2. Grant: Read/Write access to Collection "Squad Secrets"
3. Set env vars: `BW_SQUAD_SECRETS_CLIENT_ID`, `BW_SQUAD_SECRETS_CLIENT_SECRET`

> **Note:** Service Accounts require Bitwarden Secrets Manager (business plan).
> On free plans, use the Organization API key (broader access — for testing only).

### Step 5: Shadow Items

For each item agents need to read:

```bash
# Via shadow_item MCP tool (issue #1058):
shadow_item(item_id="<github-pat-cipher-id>", target_collection="Squad Ops")

# Manual alternative:
# vault.bitwarden.com → item → Edit → Collections → Add "Squad Ops"
```

### Step 6: Configure bitwarden-shadow MCP server

Add to `~/.copilot/mcp-config.json`:
```json
{
  "mcpServers": {
    "bitwarden": {
      "command": "node",
      "args": ["dist/index.js"],
      "cwd": "mcp-servers/bitwarden-shadow",
      "env": {
        "BW_ORG_CLIENT_ID":             "${BW_ORG_CLIENT_ID}",
        "BW_ORG_CLIENT_SECRET":         "${BW_ORG_CLIENT_SECRET}",
        "BW_SQUAD_OPS_CLIENT_ID":       "${BW_SQUAD_OPS_CLIENT_ID}",
        "BW_SQUAD_OPS_CLIENT_SECRET":   "${BW_SQUAD_OPS_CLIENT_SECRET}",
        "BW_SQUAD_SECRETS_CLIENT_ID":   "${BW_SQUAD_SECRETS_CLIENT_ID}",
        "BW_SQUAD_SECRETS_CLIENT_SECRET": "${BW_SQUAD_SECRETS_CLIENT_SECRET}",
        "BW_ORG_ID":                    "${BW_ORG_ID}",
        "BW_SQUAD_OPS_COLLECTION_ID":   "${BW_SQUAD_OPS_COLLECTION_ID}",
        "BW_SQUAD_SECRETS_COLLECTION_ID": "${BW_SQUAD_SECRETS_COLLECTION_ID}"
      }
    }
  }
}
```

---

## Comparison: Old Approach vs Shadow Access

| Concern             | Old (personal folder)  | New (shadow collections)    |
|---------------------|------------------------|-----------------------------|
| Access scope        | Entire personal vault  | Specific items only         |
| Duplication         | Items duplicated       | Single source of truth      |
| Revocation          | Delete copy manually   | Remove from collection      |
| Audit trail         | None (personal)        | Org event logs              |
| Rotation            | Update two copies      | Update once, auto-synced    |
| Service accounts    | Session key (Tamir's)  | Dedicated scoped account    |
| Financial data risk | Could leak             | Never accessible            |
| Cross-machine       | No (session-bound)     | Yes (API key-based)         |

---

## Connection to Issue #1058

```
Issue #1057 (this doc) = Architecture + Bitwarden admin config
Issue #1058            = MCP tool implementation (bitwarden-shadow server)

#1057 must be completed first — the collections must exist before
the MCP tool has anything to target.
```

The `bitwarden-shadow` MCP server (issue #1058) implements tools in this order:
1. `get_item` — agents read a secret (Squad Ops key, read-only)
2. `list_shadows` — audit what is visible (Squad Ops key)
3. `shadow_item` — Tamir adds an item to squad view (Org Admin key)
4. `unshadow_item` — Tamir removes an item from squad view (Org Admin key)
5. `set_item` — agents write squad-owned secrets (Squad Secrets key)

---

## References

- [Bitwarden Public API Reference](https://bitwarden.com/help/api/)
- [Bitwarden Service Accounts](https://bitwarden.com/help/service-accounts/)
- [Bitwarden Collections](https://bitwarden.com/help/collections/)
- [bitwarden/server source (open source)](https://github.com/bitwarden/server)
- Issue [#1036](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1036) — Collection-scoped API keys
- Issue [#1058](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1058) — shadow_item MCP tool
- `scripts/setup-bitwarden-squad-collection.ps1` — Guided setup script
- `mcp-servers/bitwarden-shadow/` — MCP server implementation
