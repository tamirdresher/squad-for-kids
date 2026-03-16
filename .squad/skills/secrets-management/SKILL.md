---
name: secrets-management
description: Centralized secrets management pattern for the squad. Secrets never in git, always accessible at runtime.
triggers: ["secret", "credential", "api key", "token", "password", "env var", ".env", "credential manager"]
confidence: high
---

# Secrets Management

> **Rule Zero:** No secret value is ever committed to git. Period.

## Where Secrets Live (Priority Order)

| Priority | Source | Example | Notes |
|----------|--------|---------|-------|
| 1 | **Windows Credential Manager** | `squad-email-outlook` | Most secure. Survives reboots. |
| 2 | **Machine-local file** | `$env:USERPROFILE\.squad\teams-webhook.url` | For values that are file-based by convention. |
| 3 | **Machine-local .env** | `$env:USERPROFILE\.squad\.env` | Fallback for machines without Credential Manager. |
| 4 | **Environment variable** | `$env:GOOGLE_API_KEY` | Already set in session (e.g., by CI). |

The script `scripts/setup-secrets.ps1` checks all sources in priority order and sets environment variables for the current session.

## Known Secrets

| Secret | Env Var | Credential Manager Key | Required |
|--------|---------|----------------------|----------|
| Google Gemini API Key | `GOOGLE_API_KEY` | `google-gemini-api-key` | ✅ |
| Teams Webhook URL | `TEAMS_WEBHOOK_URL` | (file-based) | ✅ |
| Telegram Bot Token | `TELEGRAM_BOT_TOKEN` | `telegram-bot-token` | ❌ |
| Squad Email Password | `SQUAD_EMAIL_PASSWORD` | `squad-email-outlook` | ❌ |
| GitHub PAT | `GITHUB_TOKEN` | Managed by `gh auth` | ❌ |

## How to Add a New Secret

1. **Add to `.env.example`** — document the variable name, description, and where to get it. No values.
2. **Add to `scripts/setup-secrets.ps1`** — add an entry to the `$SecretDefs` array with:
   - `EnvVar`: environment variable name
   - `CredTarget`: Windows Credential Manager key (or `$null`)
   - `Description`: human-readable name
   - `Required`: `$true` or `$false`
3. **Store the value** in Credential Manager on each machine:
   ```powershell
   # Using cmdkey
   cmdkey /add:my-new-secret /user:my-new-secret /pass:"actual-value"
   
   # Using CredentialManager module (preferred)
   New-StoredCredential -Target 'my-new-secret' -UserName 'my-new-secret' -Password 'actual-value' -Persist LocalMachine
   ```
4. **Update this document** — add the secret to the Known Secrets table above.

## Cross-Machine Sync

**Secrets do NOT sync between machines.** Each Dev Box or workstation must set up its own secrets independently.

Setup steps for a new machine:
1. Clone the repo
2. Run `scripts/devbox-startup.ps1` (which calls `setup-secrets.ps1`)
3. For each MISSING secret reported, add it to Credential Manager or `$env:USERPROFILE\.squad\.env`

## .env.example Pattern

The file `.env.example` in the repo root lists all required environment variables with descriptions but **no values**. It serves as documentation and a template.

To use as a fallback:
```powershell
Copy-Item .env.example "$env:USERPROFILE\.squad\.env"
# Edit the file and fill in actual values
notepad "$env:USERPROFILE\.squad\.env"
```

## .gitignore Protection

The `.gitignore` includes patterns to prevent accidental secret commits:
- `*.env`, `.env.*` — environment files
- `*secret*`, `*credential*` — anything named with sensitive terms
- `*-config.json` — config files that may contain tokens
- `*.key`, `*.pem` — cryptographic material
- `!.env.example` — the template is explicitly allowed

## Rotation Procedures

When a secret is compromised or needs rotation:
1. Generate new value from the provider
2. Update Credential Manager on all machines
3. Revoke the old value at the provider
4. Document in `.squad/decisions/inbox/` that rotation occurred
5. If the secret was ever in git history, consider it permanently compromised — always rotate

## Security Checklist

- [ ] No secret values in any committed file
- [ ] `.env.example` has descriptions only, no values
- [ ] `.gitignore` blocks `*.env`, `*secret*`, `*credential*`, `*.key`, `*.pem`
- [ ] `setup-secrets.ps1` validates all required secrets on startup
- [ ] Screenshots with visible secrets are removed from repo
