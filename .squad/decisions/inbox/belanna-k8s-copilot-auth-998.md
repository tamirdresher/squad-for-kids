# Decision: K8s Copilot Auth — Phase 2 Implementation (#998)

**Date:** 2026-03-23  
**Author:** B'Elanna  
**Issue:** #998 — Design: GitHub Copilot Authentication for K8s Pods  
**Branch:** feat/k8s-copilot-auth-998-CPC-tamir-3H7BI  

## What was implemented

Added auth-proxy sidecar injection to the `squad-agents` Helm chart, implementing Phase 2
of the design (GitHub App + installation tokens). Key changes:

### New templates
- `templates/auth-proxy-configmap.yaml` — Non-secret config for the auth-proxy container:
  Key Vault secret names, auth mode, proxy port, Redis addr, token renewal buffers.
- `templates/networkpolicy.yaml` — Egress policy restricting pods to GitHub/Copilot API
  (TCP 443), in-cluster Redis (TCP 6379), and DNS (UDP/TCP 53). `networkPolicy.enabled=false`
  by default until CNI support is confirmed on the target cluster.

### Modified templates
- `templates/secret-provider-class.yaml` — Added conditional GitHub App credential sync
  from Key Vault when `authProxy.enabled=true`: app-id, installation-id, private-key.
- `templates/rbac.yaml` — Added `configmaps` get/list/watch to the agent-spawner Role
  (needed by auth-proxy for rate-pool config reads and capability discovery #999).
- `templates/picard-deployment.yaml` — Conditional auth-proxy sidecar container injection
  + `COPILOT_URL=http://localhost:8081` env var on the picard main container.
- `templates/ralph-cronjob.yaml` — Same sidecar injection pattern as Picard.

### values.yaml additions
- `authProxy.*` section — image, port, authMode, keyVault secret names, Redis addr,
  resources. **`authProxy.enabled=false` by default** — flip to `true` once GitHub App
  is created and credentials uploaded to Key Vault.
- `networkPolicy.*` section — CNI-gated network policy controls.

## Design choices

- **`authProxy.enabled=false` default**: Preserves current Phase 1 behavior (static
  `GH_TOKEN`/`COPILOT_API_KEY` from Key Vault). Teams opt in to Phase 2 explicitly.
- **Auth mode toggle** (`authProxy.authMode`): `github_app` (default) for Workload
  Identity path; `pat` for dev fallback. Allows gradual rollout.
- **Sidecar pattern** (Design §4): Agent containers have zero auth logic. They only need
  `COPILOT_URL=http://localhost:8081`. Proxy handles JWT signing, token exchange, renewal,
  and Redis publishing.
- **ReadonlyRootFilesystem on proxy**: The proxy binary writes nothing to disk — pure
  in-memory token management. Hardened by default.

## Open questions (from design §9) — blocking for activation

| OQ | Question | Status |
|----|----------|--------|
| OQ-1 | Does our GitHub org have Copilot Business/Enterprise? | 🔴 Needs Picard to confirm |
| OQ-2 | Auth-proxy: separate image vs embedded? | ✅ Decided: separate image (sidecar) |
| OQ-3 | Redis: shared or dedicated instance? | Deferred — `rateLimitRedisAddr: ""` for now |
| OQ-4 | #995 test order: PAT-first or GitHub App directly? | Deferred to sprint planning |
| OQ-5 | Separate Managed Identities per agent type? | 🔴 Needs Worf security review |

## What's NOT done yet (requires manual one-time setup)

1. GitHub App creation (`github.com/organizations/<org>/settings/apps/new`)
2. Upload App credentials to Key Vault:
   ```bash
   az keyvault secret set --vault-name squad-keyvault --name squad-github-app-id --value <ID>
   az keyvault secret set --vault-name squad-keyvault --name squad-github-app-installation-id --value <ID>
   az keyvault secret set --vault-name squad-keyvault --name squad-github-app-private-key --file ./key.pem
   ```
3. Build and push the `squad-auth-proxy` image to ACR (Go binary, design §5.4)
4. Set `authProxy.enabled=true` in values and redeploy
