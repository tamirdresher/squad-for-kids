# bitwarden-shadow-mcp

MCP server implementing cross-collection Bitwarden item sharing ("shadowing").

Closes [#1058](../../issues/1058).

## What is shadowing?

Bitwarden supports a many-to-many relationship between vault items (ciphers) and
collections via the `CollectionCipher` junction table. A "shadow" is when an
item that *lives* in one collection (e.g. `infra`) is **also added** to a second
collection (e.g. `squad`), giving squad members visibility of the item without
moving or duplicating it.

```
infra collection ─────┐
                       ├─ "Production DB Password" (cipher)
squad collection ──────┘  (CollectionCipher row for each)
```

## Tools

### `shadow_item`

Add an org vault item to a target collection.

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `item_id` | string | ✅ | — | Bitwarden cipher UUID |
| `target_collection` | string | ✅ | — | Collection ID or name |
| `access` | `"read-only"` \| `"read-write"` | ❌ | `"read-only"` | Access intent |

> **Note on read-only:** The Public API manages `CollectionCipher` associations.
> The `readOnly` flag lives on `CollectionUser` and must be set by an org admin
> at the collection level. This tool records the intent and documents it.

### `unshadow_item`

Remove a shadow — unlinks an item from a target collection.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `item_id` | string | ✅ | Bitwarden cipher UUID |
| `target_collection` | string | ✅ | Collection ID or name |

### `list_shadows`

List all vault items shadowed into a given collection.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `collection` | string | ✅ | Collection ID or name |

Returns: item ID, name, type, and total collection count per item.

## Configuration

Set environment variables (highest priority) or create a config file.

### Environment variables

```sh
BW_SERVER_URL=https://vault.bitwarden.com  # optional, this is the default
BW_CLIENT_ID=organization.XXXXXXXXXXXXXXXX
BW_CLIENT_SECRET=XXXXXXXXXXXXXXXXXXXXXXXX
BW_ORGANIZATION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

Obtain `BW_CLIENT_ID` and `BW_CLIENT_SECRET` from your Bitwarden organization:
**Org Settings → API Key → View API Key**.

### Config file

`~/.config/bitwarden-shadow-mcp/config.json`

```json
{
  "serverUrl": "https://vault.bitwarden.com",
  "clientId": "organization.XXXXXXXXXXXXXXXX",
  "clientSecret": "XXXXXXXXXXXXXXXXXXXXXXXX",
  "organizationId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

## Build & run

```sh
cd mcp-servers/bitwarden-shadow
npm install
npm run build
npm start
```

### Development mode (no build step)

```sh
npm run dev
```

### Tests

```sh
npm test
```

## MCP config example

Add to `~/.config/mcp/config.json` (or your Copilot CLI config):

```json
{
  "mcpServers": {
    "bitwarden-shadow": {
      "command": "node",
      "args": ["path/to/mcp-servers/bitwarden-shadow/dist/index.js"],
      "env": {
        "BW_CLIENT_ID": "organization.XXXXXXXX",
        "BW_CLIENT_SECRET": "YOUR_SECRET",
        "BW_ORGANIZATION_ID": "YOUR_ORG_UUID"
      }
    }
  }
}
```

## Architecture notes

- Uses the [Bitwarden Public API](https://bitwarden.com/help/public-api/) (`/api/public/*`)
- Auth: `client_credentials` OAuth2 flow against `/identity/connect/token`
- Token is cached in-process and refreshed 60 s before expiry
- All three tools are **idempotent** (safe to call multiple times)
- Collection resolution accepts both UUID and display name (case-insensitive)

## Relation to #1036

Issue #1036 (collection-scoped API keys) is not yet complete. This server is
designed to work with the existing **Organization API Key** in the interim.
When #1036 lands, only the `BW_CLIENT_ID` / `BW_CLIENT_SECRET` values need to
change — the tool interface stays the same.
