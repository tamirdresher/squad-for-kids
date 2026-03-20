# Decision: Bitwarden Shadow Access Architecture

**Date:** 2026-03-20
**Author:** Picard
**Status:** ADOPTED
**Issue:** #1057

## Decision

Use Bitwarden's native **multi-collection** support as the shadow access mechanism
for sharing personal vault items with squad agents.

A single cipher belongs to multiple collections simultaneously:
- `Tamir Admin` — full CRUD (Tamir's account)
- `Squad Ops` — read-only (squad service account)

No data duplication. Single source of truth. Server-enforced `ReadOnly` flag
prevents agents from ever modifying or deleting Tamir's items.

## Architecture

```
Organization "TAM Research"
├── Collection "Tamir Admin"    → Tamir full CRUD
├── Collection "Squad Ops"      → Squad service account READ-ONLY
└── Collection "Squad Secrets"  → Squad service account READ/WRITE
```

## Key Choices

1. **Multi-collection, not duplication.** One cipher, two views. Rotation syncs immediately.

2. **Separate service accounts per tier.** `squad-ops-readonly` for Squad Ops,
   `squad-secrets-readwrite` for Squad Secrets. Ralph gets only Squad Ops.

3. **Org Admin API key for `shadow_item` tool.** The MCP tool (issue #1058) needs
   org-level credentials to modify collection memberships. Stored in Tamir Admin
   collection, never in the repo.

4. **Personal vault items must move to org first.** `bw move <id> <orgId>` required
   before an item can be added to a collection.

5. **`bitwarden-shadow` is a separate MCP server.** Different auth, different concern.
   Not part of `squad-mcp`. Lives at `mcp-servers/bitwarden-shadow/`.

6. **Ralph reads but never writes.** Ralph gets Squad Ops (read) only.
   No Squad Secrets access.

## Items Never Shadowed

Financial, medical, personal identity, and master key items never go in Squad Ops.
Full list in `docs/bitwarden-shadow-access.md`.

## References

- Design doc: `docs/bitwarden-shadow-access.md`
- Setup script: `scripts/setup-bitwarden-squad-collection.ps1`
- MCP server: `mcp-servers/bitwarden-shadow/`
- Issue #1057, #1058
