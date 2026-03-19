---
name: bitwarden
description: Secure credential storage and retrieval for Squad agents via Bitwarden CLI. Agents can store and retrieve secrets but CANNOT delete them. All access is logged.
---

# Bitwarden — Squad Credential Management

Provides secure, audited credential management for AI squad agents. Built on Bitwarden CLI (`bw`).

## CRITICAL: Security Rules

1. **NO DELETE** — Agents may NEVER delete vault items. Only the vault owner (Tamir) can delete.
2. **NO EXPORT** — Never export the entire vault or dump all passwords.
3. **NO MASTER PASSWORD** — Never request, store, or log the master password.
4. **AUDIT ALL ACCESS** — Every credential access must be logged to `.squad/log/bitwarden-access.log`.
5. **LEAST PRIVILEGE** — Only retrieve the specific credential needed for the current task.
6. **NO PLAINTEXT LOGGING** — Never log actual password values. Log only item name/ID + action + timestamp.

## Prerequisites

- Bitwarden CLI installed: `npm install -g @bitwarden/cli`
- Vault must be unlocked (BW_SESSION env var set)
- CLI version 2026.2.0+

## Available Operations

### Store a Credential

Use the Bitwarden CLI to create a new login item:

```powershell
# Create a login item
$item = @{
  type = 1  # Login type
  name = "squad/service-name"
  notes = "Created by [agent-name] for [purpose]. Issue: #NNN"
  login = @{
    username = "the-username"
    password = "the-password"
    uris = @(@{ uri = "https://service-url.com" })
  }
} | ConvertTo-Json -Depth 5

# Encode and create
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($item))
bw create item $encoded --session $env:BW_SESSION
```

**Naming Convention:** Always prefix item names with `squad/` (e.g., `squad/github-api-key`, `squad/azure-storage-key`).

### Retrieve a Credential

```powershell
# Search by name
bw get item "squad/service-name" --session $env:BW_SESSION

# Get just the password
bw get password "squad/service-name" --session $env:BW_SESSION
```

### List Squad Credentials

```powershell
# List all squad-prefixed items
bw list items --search "squad/" --session $env:BW_SESSION
```

### Update a Credential

```powershell
# Get current item, modify, re-encode, update
$item = bw get item "squad/service-name" --session $env:BW_SESSION | ConvertFrom-Json
$item.login.password = "new-password"
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($item | ConvertTo-Json -Depth 5)))
bw edit item $item.id $encoded --session $env:BW_SESSION
```

## Audit Logging

Every access MUST be logged. Append to `.squad/log/bitwarden-access.log`:

```
[2026-03-18T19:30:00Z] STORE  | agent=Data | item=squad/azure-key | issue=#729
[2026-03-18T19:31:00Z] GET    | agent=Ralph | item=squad/github-token | issue=#750
[2026-03-18T19:32:00Z] LIST   | agent=Seven | search=squad/ | count=5
[2026-03-18T19:33:00Z] UPDATE | agent=Data | item=squad/azure-key | issue=#729
```

**Format:** `[ISO-timestamp] ACTION | agent=NAME | item=ITEM_NAME | issue=#NNN`

## Vault Unlock Flow

The vault must be unlocked before any operations. This requires human interaction (master password):

1. Human runs: `bw login` (first time) or `bw unlock`
2. Export session: `$env:BW_SESSION = bw unlock --raw`
3. Session persists for the terminal session
4. Agents use `--session $env:BW_SESSION` for all commands

**Important:** Agents cannot unlock the vault themselves. The session must be pre-established by the vault owner.

## Collection-Based Isolation (Organization Mode)

If using Bitwarden Organization:

```powershell
# Create item in specific collection
$item.collectionIds = @("squad-collection-id")
```

Collections provide:
- **Squad Collection** — agents can read/write
- **Admin Collection** — owner-only, sensitive secrets
- **Shared Collection** — cross-squad accessible

## Integration with Squad Framework

### Ralph Integration
Ralph can check credential health during morning patrol:
```powershell
# Check for expiring credentials (items with notes containing expiry dates)
bw list items --search "squad/" --session $env:BW_SESSION | ConvertFrom-Json | 
  Where-Object { $_.notes -match "expires:" }
```

### Cross-Squad Sharing
Use Bitwarden Organization collections to share credentials between squads:
- tamresearch1 squad → Squad Collection
- tamresearch1-research squad → Research Collection
- Shared items → Shared Collection

## Troubleshooting

| Error | Solution |
|-------|----------|
| `You are not logged in` | Run `bw login` |
| `Vault is locked` | Run `$env:BW_SESSION = bw unlock --raw` |
| `Item not found` | Check name prefix (`squad/`) and sync: `bw sync` |
| `Session expired` | Re-unlock: `$env:BW_SESSION = bw unlock --raw` |
