# Bitwarden Shadow Flow — Design Document

> **Issue:** [#1101](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1101) | **Implements:** [PR #1092](https://github.com/tamirdresher_microsoft/tamresearch1/pull/1092) (bitwarden-shadow MCP server)

## What Problem This Solves

You want an AI agent to use a credential — say, an API key or a deploy password — without you having to paste the secret into the chat. The AI needs *some* way to reference and retrieve the credential at runtime, but you never want the raw value to appear in a conversation, log, or LLM context.

The **shadow system** is the answer. Instead of giving the AI the secret, you give it a *handle* (a shadow reference). The secret itself never leaves the Bitwarden collection the AI is scoped to — and it only reaches the destination service at the moment it's actually needed.

---

## Core Concept: Shadow ≠ Secret

A **shadow** is Bitwarden's item ID plus collection membership. It is:

- ✅ A stable identifier the AI can pass around
- ✅ A name the AI can describe to the user ("I'll use the 'GitHub Actions Deploy Key' credential")
- ❌ The actual password, token, or key

The AI operates at the handle level. The secret is resolved only inside the trusted `bw` CLI process, on the user's local machine, at the moment of actual use.

---

## Architecture: The Three Zones

```
┌──────────────────────────────────────────────────────────────────────┐
│  ZONE 1 — User's local machine (trusted)                             │
│                                                                      │
│   ┌─────────────┐   BW_SESSION    ┌──────────────────────────────┐   │
│   │  bw CLI     │◄───────────────►│  bitwarden-shadow MCP server │   │
│   │ (Bitwarden) │                 │  (Node.js process)           │   │
│   └──────┬──────┘                 └──────────────────────────────┘   │
│          │                                  ▲  MCP protocol          │
│   Vault  │  (encrypted at rest)             │  (stdio/local)         │
│          ▼                                  ▼                        │
│   ┌──────────────────────────┐  ┌─────────────────────────────────┐  │
│   │  Org Collection: Admin   │  │  Org Collection: Squad Ops      │  │
│   │  (full CRUD)             │  │  (READ ONLY — Bitwarden-enforced)│  │
│   │  Item A ──────────────── │─►│  Item A 👁  (shadowed)          │  │
│   │  Item B                  │  │                                 │  │
│   │  Item C (not shadowed)   │  │                                 │  │
│   └──────────────────────────┘  └─────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
                                            │  names + IDs only
                                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  ZONE 2 — AI / LLM context (untrusted)                               │
│                                                                      │
│   AI Agent sees:  { itemId: "abc-123", itemName: "GitHub Token" }    │
│   AI Agent NEVER sees: passwords, tokens, TOTP seeds, field values  │
└──────────────────────────────────────────────────────────────────────┘
                                            │  item ID passed by AI
                                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  ZONE 3 — Destination service (e.g. a deploy script, GitHub CI)      │
│                                                                      │
│   The runner (not the AI) calls:  bw get item <id> --session $BW_SESSION │
│   and uses the resolved secret directly. The AI is not in this call. │
└──────────────────────────────────────────────────────────────────────┘
```

**Key insight:** The AI lives entirely in Zone 2. It can ask "is `abc-123` in the shadow collection?" and get "yes, that's the GitHub Token". It can *pass the ID* to Zone 3. It never crosses the boundary to see the raw secret.

---

## End-to-End Flow

### Step 1 — User unlocks Bitwarden locally

```powershell
.\setup-bitwarden.ps1
# Prompts for master password, sets BW_SESSION in environment
```

`BW_SESSION` is a short-lived session token scoped to your unlocked vault. It is set in the environment only — never written to disk (beyond the optional `~/.squad/bitwarden-session.json` config file, which is local-only).

### Step 2 — User identifies what to share

The user knows which Bitwarden item they want the AI to work with. They look up the item ID:

```powershell
bw list items --search "GitHub Actions Deploy Key" | ConvertFrom-Json | Select id, name
# → { id: "abc-123", name: "GitHub Actions Deploy Key" }
```

Or use the MCP tool with `include_available`:

```
list_shadows(include_available=true)
# Returns: availableToShadow: [{ itemId: "abc-123", itemName: "GitHub Actions Deploy Key" }]
```

### Step 3 — User shadows the item

The user (or a trusted setup agent running under user supervision) calls:

```
shadow_item(item_id="abc-123")
```

What happens under the hood:

1. The MCP server runs `bw get item abc-123 --session <token>`
2. It checks `item.organizationId` — rejects personal vault items (they can't join org collections)
3. It fetches the current `collectionIds` for the item (e.g., `["admin-collection-id"]`)
4. It appends the squad collection ID: `["admin-collection-id", "squad-ops-collection-id"]`
5. It calls `bw edit item abc-123 <base64-encoded-item> --session <token>`
6. Bitwarden updates the `CollectionCipher` junction — one cipher, two collections, no data duplication

**Return value to AI:**

```json
{
  "itemId": "abc-123",
  "itemName": "GitHub Actions Deploy Key",
  "collectionId": "squad-ops-collection-id",
  "collectionName": "Squad Ops",
  "status": "shadowed"
}
```

The AI sees the name and the shadow status. No passwords, no TOTP, no field values.

### Step 4 — AI works with the shadow

The AI can now:

- Call `list_shadows()` to see what's available — gets names and IDs, nothing more
- Pass the item ID to a script, CI job, or tool call that runs on the user's machine

Example — AI asks a shell tool to use the credential:

```powershell
# AI-generated command (runs locally, not inside the AI)
$secret = bw get item abc-123 --session $env:BW_SESSION | ConvertFrom-Json
$env:GITHUB_TOKEN = $secret.login.password
gh workflow run deploy.yml
```

At this point the AI passed the item ID (`abc-123`) but the actual password was fetched by the local `bw` process and stored in a local environment variable — never returned to the AI.

### Step 5 — User revokes the shadow

When the task is done, the user (or the AI on the user's request) calls:

```
unshadow_item(item_id="abc-123")
```

The MCP server:

1. Removes the squad collection ID from `collectionIds`
2. Guards against orphaning — refuses if the squad collection is the item's *only* collection (would make the item inaccessible)
3. Returns confirmation; the item is now only in the admin collection again

---

## What the AI CAN and CANNOT Do

| Capability | AI Can Do? | Notes |
|---|---|---|
| Know an item's **name** | ✅ | Returned by `list_shadows` and `shadow_item` |
| Know an item's **type** (login, note, card) | ✅ | Returned by `list_shadows` |
| Know an item's **ID** | ✅ | Required to reference it |
| Know which **collections** it belongs to | ✅ | Returned as collection IDs |
| See the **password** / token / secret value | ❌ | Never returned by any MCP tool |
| See **username** or **URL** fields | ❌ | Not exposed by the shadow tools |
| See **TOTP seeds** | ❌ | Never exposed |
| Access items **not in the shadow collection** | ❌ | Scoped by Bitwarden collection access |
| **Delete** items from the vault | ❌ | No delete tool exists; `unshadow` only removes collection membership |
| Access the **personal vault** (non-org items) | ❌ | `shadow_item` validates `organizationId != null` and rejects personal items |
| Enumerate all items in the vault | ❌ | `list_shadows` only lists items in the specific shadow collection |

---

## Trust Boundaries

### Boundary 1: MCP ↔ AI

The MCP protocol (stdio) is the outer wall. The MCP server is an explicit, registered tool the AI calls by name. The AI cannot reach past it to invoke `bw` directly or read environment variables.

### Boundary 2: Shadow collection ↔ Admin collection

Bitwarden itself enforces collection-level access. The `Squad Ops` collection is configured as **read-only** — meaning even if the MCP server tried to modify items through the `bw` CLI using the squad session, Bitwarden would reject it. The read-only flag is on the *collection membership*, not enforced by this code alone.

### Boundary 3: Session token scope

`BW_SESSION` is passed to the MCP server as an environment variable at startup. It is forwarded to `bw` as a `--session` flag (not via environment passthrough), and **never logged to stdout**. Logs go to stderr, and even then, the session token is omitted from log lines.

### Boundary 4: Personal vault exclusion

`shadow_item` validates that `item.organizationId != null`. A personal vault item can never be added to an org collection — Bitwarden's data model forbids it. The MCP server enforces this explicitly before even attempting the API call.

---

## Security Properties Summary

| Property | How it's enforced |
|---|---|
| AI never sees secret values | MCP tools return only `{ id, name, type }` |
| AI can't access unshadowed items | Bitwarden collection-level access (server-side) |
| AI can't access personal vault items | Validated in `shadow_item` before any API call |
| AI can't orphan a vault item | Orphan guard in `unshadow_item` |
| Session token not leaked to AI | Passed as `--session` flag, never in stdout |
| No vault data duplication | `CollectionCipher` junction — one cipher, N collections |
| Revocation is instant | `unshadow_item` removes collection membership immediately |

---

## Example Walkthrough: Giving the AI an API Key

**Scenario:** You want the AI to run a deployment script that needs your GitHub Personal Access Token.

**Your token is stored in Bitwarden as:** `GitHub PAT - Deployment` (item ID: `fa91b3e2-...`)

### 1. Unlock vault

```powershell
.\setup-bitwarden.ps1
# Enter master password → BW_SESSION set
```

### 2. Shadow the item

You tell the AI: *"Shadow my GitHub PAT for this session."*

AI calls: `shadow_item(item_id="fa91b3e2-...")`

AI response to you: *"Done — 'GitHub PAT - Deployment' is now available in the Squad Ops collection."*

### 3. AI uses the shadow

AI writes a PowerShell step for your pipeline:

```powershell
# Resolve secret locally — bw runs in your process, not in the AI
$token = (bw get item fa91b3e2-... --session $env:BW_SESSION | ConvertFrom-Json).login.password
gh workflow run deploy.yml --field token=$token
```

The AI knows the item ID. It does not know the token value. The token is fetched and used in your local shell — it never returns to the AI.

### 4. Revoke after use

```
unshadow_item(item_id="fa91b3e2-...")
```

The item is back to admin-only. The AI's handle `fa91b3e2-...` now returns "not in shadow collection" if it tries to use it.

---

## MCP Server Configuration

The server is registered in `.copilot/mcp-config.json`:

```json
"bitwarden-shadow": {
  "type": "local",
  "command": "node",
  "args": ["mcp-servers/bitwarden-shadow/dist/index.js"],
  "env": {
    "BW_SESSION": "${BW_SESSION}",
    "BW_SHADOW_COLLECTION_ID": "${BW_SHADOW_COLLECTION_ID}",
    "BW_ADMIN_COLLECTION_ID": "${BW_ADMIN_COLLECTION_ID}"
  }
}
```

- `BW_SESSION` — the unlocked vault session token (expires with the vault lock)
- `BW_SHADOW_COLLECTION_ID` — the collection the AI is scoped to (e.g., Squad Ops)
- `BW_ADMIN_COLLECTION_ID` — (optional) enables `list_shadows(include_available=true)` to show what can be shadowed

Config can also be stored in `~/.squad/bitwarden-session.json` for persistent local dev setups.

---

## Implementation Reference

| File | Purpose |
|---|---|
| `src/bitwarden-client.ts` | Thin wrapper around `bw` CLI — all vault operations go through here |
| `src/tools/shadow-item.ts` | Adds an item to the shadow collection; validates org ownership |
| `src/tools/unshadow-item.ts` | Removes an item from the shadow collection; orphan guard |
| `src/tools/list-shadows.ts` | Lists items in the shadow collection; names/IDs only |
| `src/config.ts` | Loads `BW_SESSION` and collection IDs from env or config file |
| `src/types.ts` | TypeScript types for vault items, collections, and shadow entries |

---

## Related Issues and PRs

- [#1057](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1057) — Design spec for cross-collection shadowing
- [#1058](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1058) — Implementation task for the MCP server
- [PR #1092](https://github.com/tamirdresher_microsoft/tamresearch1/pull/1092) — Implementation: `bitwarden-shadow` MCP server
- [#1101](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1101) — This design document
