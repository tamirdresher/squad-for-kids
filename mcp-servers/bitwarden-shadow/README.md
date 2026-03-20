# bitwarden-shadow-mcp

MCP server for **Bitwarden cross-collection shadowing**. Lets Tamir share personal org-vault items with the Squad collection as read-only, without duplicating data.

Implements [#1057](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1057) + [#1058](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1058).

## How It Works

Bitwarden's `CollectionCipher` junction table lets one cipher live in multiple collections. Shadow access = add the squad collection ID to an item's `collectionIds`. No data duplication.

```
Organization Vault
  Tamir Admin (CRUD)    Squad Ops (read-only)
     Item A  ──────────────→  Item A 👁
     Item B  ──────────────→  Item B 👁
     Item C  (not shadowed)
```

## Tools

| Tool | Args | Description |
|------|------|-------------|
| `shadow_item` | `item_id`, `target_collection?` | Add item to squad collection |
| `unshadow_item` | `item_id`, `target_collection?` | Remove item from squad collection |
| `list_shadows` | `collection?`, `include_available?` | List shadowed items (names/IDs only) |

## Setup

### Prerequisites
- Bitwarden CLI: `winget install Bitwarden.CLI`
- Vault unlocked via `setup-bitwarden.ps1`
- Know your collection IDs: `bw list collections`

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `BW_SESSION` | ✅ | Session token (`bw unlock --raw`) |
| `BW_SHADOW_COLLECTION_ID` | ✅ | Target squad collection ID |
| `BW_ADMIN_COLLECTION_ID` | ⬜ | Admin collection (enables `include_available`) |

### Build

```bash
cd mcp-servers/bitwarden-shadow
npm install
npm run build
```

### .copilot/mcp-config.json entry

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

## Security

- Read-only enforced at Bitwarden collection level (not this server)
- `list_shadows` returns names/IDs only — never passwords
- `unshadow_item` refuses to orphan an item (removes last collection guard)
- `BW_SESSION` passed as `--session` flag, never logged to stdout
