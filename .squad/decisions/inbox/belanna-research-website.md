# Decision: Research Website Auth & Deployment

**Date:** 2026-03-14
**Author:** B'Elanna (Infrastructure Expert)
**Issue:** #542

## Decision

Use Azure App Service built-in authentication (EasyAuth v2) with GitHub as the identity provider for the Starfleet Research Labs website. Deploy as a Node.js static server via zip deploy.

## Context

- The tam-research-website Azure Web App needed GitHub EMU authentication for internal-only access
- The `authV2` Azure CLI extension has install issues; REST API (`az rest`) is the reliable fallback
- GitHub OAuth Apps require manual browser creation — no API exists for this

## Approach

1. **Auth:** App Service EasyAuth v2 configured via REST API with GitHub provider, redirect on unauthenticated, token store enabled, scopes `read:user` + `read:org`
2. **Deployment:** Simple Node.js http server serving static HTML, deployed via `az webapp deploy --type zip`
3. **Branding:** LCARS/TNG aesthetic per SRL identity (deep space blue + amber)

## Key Details

- Resource group: `tamirdev`
- Runtime: Node.js 20 LTS on Linux
- Auth secret stored in app setting: `GITHUB_OAUTH_CLIENT_SECRET`
- Callback URL: `https://tam-research-website.azurewebsites.net/.auth/login/github/callback`
