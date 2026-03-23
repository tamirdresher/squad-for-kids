# GitHub Copilot Authentication for K8s Pods

**Issue:** [#998](https://github.com/tamirdresher_microsoft/tamresearch1/issues/998)  
**Status:** Design  
**Authors:** Picard (architecture), B'Elanna (infrastructure), Worf (security)  
**Related:**
- [#999](https://github.com/tamirdresher_microsoft/tamresearch1/issues/999) / [PR #1240](https://github.com/tamirdresher_microsoft/tamresearch1/pull/1240) — K8s capability routing
- [#1000](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1000) / [PR #1239](https://github.com/tamirdresher_microsoft/tamresearch1/pull/1239) — Squad Helm chart
- [#995](https://github.com/tamirdresher_microsoft/tamresearch1/issues/995) — Test Squad-on-K8s with non-human user
- [#979](https://github.com/tamirdresher_microsoft/tamresearch1/issues/979) — Rate limit research

---

## 1. Problem Statement

Squad agents today run on DevBoxes where a developer has executed `gh auth login`. The Copilot CLI and the `gh` tool use
the resulting OAuth token stored in `~/.config/gh/hosts.yml`.

When agents move to K8s pods this model breaks:

| Today (DevBox) | Target (K8s Pod) |
|---|---|
| Interactive `gh auth login` per machine | No human present at pod startup |
| Token in user's home directory | No writable home directory needed |
| Single agent per DevBox | N pods × M agent types potentially running |
| Token lifetime tied to dev's session | Pods start/stop/restart automatically |
| Rate-limit coordination via local file | No shared filesystem across pods |

The solution must satisfy these requirements:

- **R1 Non-interactive** — No human clicks or browser redirects at pod start.
- **R2 Automatic rotation** — Tokens must refresh without human action.
- **R3 Least privilege** — The credential must only grant what the agent needs.
- **R4 Audit trail** — Actions must be traceable back to the specific agent identity.
- **R5 Compatible with Copilot quota** — A shared Copilot Business/Enterprise seat must be usable by N pods without
  each pod consuming a separate seat.
- **R6 Compatible with existing rate-pool** — Auth must expose the headers (#979) the rate-pool coordinator needs.

---

## 2. GitHub Copilot API Authentication Background

GitHub Copilot exposes two distinct API surfaces that require different auth:

### 2.1 Copilot Completions API (`api.githubcopilot.com`)

The completions endpoint requires a **Copilot API token**, not a raw GitHub OAuth token. The flow is:

```
GitHub OAuth/App token
    → GET https://api.github.com/copilot_internal/v2/token
    → Short-lived Copilot token (TTL ~30 min, `expires_at` in response)
    → Authorization: Bearer <copilot_token>
    → POST https://api.githubcopilot.com/chat/completions
```

The Copilot token exchange is rate-limited and the token contains the quota headers our rate-pool (#979) monitors:
- `x-ratelimit-limit`
- `x-ratelimit-remaining`
- `x-ratelimit-reset`

### 2.2 GitHub REST/GraphQL APIs (`api.github.com`)

Standard GitHub token — used for issue reads, PR creation, etc. Works directly with OAuth tokens, PATs, or GitHub App
installation tokens.

### 2.3 Non-Human User Options

| Credential type | Copilot access | Token TTL | Auto-rotate | K8s-friendly |
|---|---|---|---|---|
| Personal Access Token (PAT) | ✅ via owner's seat | Never (classic) / configurable (fine-grained) | ❌ Manual | ⚠️ Static secret |
| OAuth token | ✅ via user's seat | Until revoked | ❌ | ❌ Interactive |
| GitHub App installation token | ✅ via org Copilot Business | 1 hour | ✅ | ✅ |
| Workload Identity (OIDC) | ❌ direct | — | ✅ | ✅ |
| GitHub Actions OIDC | ✅ ephemeral | 1 hour | ✅ | ⚠️ CI only |

> **Key finding:** GitHub Apps with Copilot Business are the correct non-human path. An organization on Copilot Business
> can enable an App to access the completions API without consuming a per-seat license for each pod.

---

## 3. Authentication Options

### Option A — Static PAT via K8s Secret

A classic PAT (or fine-grained PAT) stored in a K8s Secret, mounted as an environment variable.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: squad-github-pat
  namespace: squad
type: Opaque
stringData:
  GITHUB_TOKEN: "ghp_xxxxxxxxxxxxxxxxxxxxx"
```

```yaml
# In pod spec
env:
  - name: GITHUB_TOKEN
    valueFrom:
      secretKeyRef:
        name: squad-github-pat
        key: GITHUB_TOKEN
```

**Pros:**
- Immediate, zero infrastructure dependencies.
- Works with any GitHub tier.

**Cons:**
- ❌ Token never auto-rotates; rotation requires human action + pod restart.
- ❌ PAT is scoped to a human user account — consuming that user's Copilot seat.
- ❌ No per-pod audit trail (all pods look identical in GitHub audit log).
- ❌ Classic PATs have broad permissions; fine-grained PATs can't be used for Copilot in all org configurations.

**Verdict:** Acceptable for development/testing. Not suitable for production.

---

### Option B — GitHub App Installation Token

Create a GitHub App installed on the organization. Each pod (or a token-vending sidecar) exchanges the App's private key
for a short-lived installation token.

```
GitHub App (org-installed)
├── private key → stored in Azure Key Vault
│                 synced to K8s Secret via External Secrets Operator
└── App ID → ConfigMap

Pod startup:
  JWT(App ID + private key, exp=10min)
      → POST /app/installations/{id}/access_tokens
      → installation_token (1h TTL)
      → GET /copilot_internal/v2/token
      → copilot_token (~30min TTL)
```

**GitHub App permissions needed:**

| Permission | Level | Reason |
|---|---|---|
| `Copilot` | Read | Token exchange for completions |
| `Contents` | Read | Repo access for context |
| `Issues` | Read/Write | Issue management |
| `Pull requests` | Read/Write | PR creation |
| `Members` | Read | Team lookups |

**Pros:**
- ✅ Installation tokens auto-expire (1h); private key never leaves Key Vault after bootstrap.
- ✅ Organization-level Copilot Business seat applies to the App — no per-pod seat.
- ✅ GitHub audit log shows App name + installation ID, not a generic user.
- ✅ Blast radius limited to App's permissions; App can be suspended instantly.

**Cons:**
- One App private key is still a secret that must be protected.
- Initial App creation and installation is a manual step.
- Requires Copilot Business or Enterprise at the org level.

**Verdict:** ✅ Recommended primary mechanism.

---

### Option C — Azure Workload Identity → GitHub App

Extends Option B: the GitHub App private key is stored in Azure Key Vault, never in the cluster. The pod uses AKS
Workload Identity (OIDC federation) to authenticate to Azure AD and fetch the key at runtime.

```
K8s ServiceAccount (annotated with Managed Identity client ID)
    → OIDC token (via kubelet projected volume)
    → Azure AD token exchange (Workload Identity webhook)
    → Azure Key Vault GetSecret → GitHub App private key
    → GitHub installation token (1h)
    → Copilot token (~30min)
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: squad-agent
  namespace: squad
  annotations:
    azure.workload.identity/client-id: "<managed-identity-client-id>"
```

**Pros:**
- ✅ Zero static secrets in the cluster (no Secret containing private key).
- ✅ Azure AD audit log + Key Vault access log for every token fetch.
- ✅ Rotate GitHub App key in Key Vault; pods pick it up on next token refresh without redeploy.

**Cons:**
- AKS Workload Identity must be enabled on the cluster (`oidcIssuerProfile.enabled: true`).
- Azure AD Federated Identity Credential must be configured (one-time setup per ServiceAccount).
- Adds Azure dependency to what is otherwise a GitHub-only auth chain.

**Verdict:** ✅ Recommended for production AKS deployments.

---

### Option D — Auth-Proxy Sidecar

A lightweight sidecar container in each agent pod handles all token lifecycle management. The agent container calls a
local HTTP endpoint instead of GitHub directly.

```
┌─────────────────────────────────────┐
│  Pod                                │
│  ┌─────────────┐  ┌──────────────┐  │
│  │ squad-agent  │  │ auth-proxy   │  │
│  │             │──▶│ :8081        │  │
│  │ COPILOT_URL=│  │              │  │
│  │ localhost:  │  │ - token mgmt │  │
│  │ 8081        │  │ - auto-renew │  │
│  └─────────────┘  │ - rate hdrs  │  │
│                   └──────┬───────┘  │
└──────────────────────────┼──────────┘
                           │ GitHub App token (Option B/C)
                           ▼
                  api.githubcopilot.com
```

The sidecar:
1. Fetches the GitHub App private key (via Workload Identity or mounted Secret).
2. Exchanges for installation token and Copilot token.
3. Refreshes tokens before expiry (5 min before `expires_at`).
4. Proxies Copilot completions requests, injecting the current token.
5. Forwards rate-limit response headers to the rate-pool Redis for coordination (#979).

**Pros:**
- Agent code has zero auth logic — all it needs is `COPILOT_URL=http://localhost:8081`.
- Single proxy binary works for all agent types (Ralph, Data, Picard, etc.).
- Proxy can implement circuit-breaker and retry-with-backoff transparently.
- Rate-pool headers (#979) are extracted at the proxy level consistently.

**Cons:**
- Extra container per pod (small: ~20MB Go binary).
- Additional image to build and maintain.
- Localhost network hop (negligible latency, <1ms).

**Verdict:** ✅ Strongly recommended as the agent-facing layer, layered on top of Option B or C.

---

## 4. Recommended Architecture

### 4.1 Overview

**Use Option C (Workload Identity) for credential sourcing + Option D (auth-proxy sidecar) for token management.**

For clusters without AKS Workload Identity, fall back to Option B (GitHub App key in K8s Secret synced from Key Vault
via External Secrets Operator).

```
┌─────────────────────────────────────────────────────────────┐
│ AKS Cluster (squad namespace)                               │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Pod: squad-agent (Job or Deployment)                  │  │
│  │  ┌──────────────┐     ┌──────────────────────────┐   │  │
│  │  │ agent        │────▶│ auth-proxy sidecar        │   │  │
│  │  │ container    │     │ localhost:8081             │   │  │
│  │  └──────────────┘     │ - GitHub App JWT signing  │   │  │
│  │                       │ - Installation token mgmt │   │  │
│  │                       │ - Copilot token mgmt      │   │  │
│  │                       │ - Rate-pool Redis publish │   │  │
│  │                       └──────────┬───────────────┘   │  │
│  └──────────────────────────────────┼───────────────────┘  │
│                                     │                       │
│  ServiceAccount: squad-agent        │ Workload Identity     │
│  (Managed Identity annotation)      │ OIDC token            │
│                                     ▼                       │
│  ┌──────────────────┐   ┌─────────────────────────────┐   │
│  │ Redis (rate-pool)│   │ Azure Key Vault              │   │
│  │ squad-rate-pool  │   │ squad-github-app-private-key │   │
│  └──────────────────┘   └──────────────┬────────────┘   │
└───────────────────────────────────────┼──────────────────┘
                                         │ Azure AD OIDC exchange
                                         ▼
                              GitHub App private key
                                         │
                                         ▼
                              POST /app/installations/{id}/access_tokens
                                         │
                                         ▼
                              GET /copilot_internal/v2/token
                                         │
                                         ▼
                              POST https://api.githubcopilot.com/chat/completions
```

### 4.2 Token Lifecycle

```
T+0:00   Pod starts, auth-proxy initializes
T+0:01   Proxy fetches GitHub App key from Key Vault (via Workload Identity)
T+0:02   Proxy creates signed JWT (10 min expiry) for App auth
T+0:03   Exchange JWT → installation token (1h TTL)
T+0:04   Exchange installation token → Copilot token (~30min TTL)
T+0:05   Proxy is ready; agent container starts receiving requests

T+0:25   Proxy renews Copilot token (5 min before expiry)
T+0:55   Proxy renews installation token (5 min before expiry)

T+1:00+  Repeat. No human involvement required.
```

---

## 5. Implementation Steps

### 5.1 GitHub App Setup (one-time, per organization)

```bash
# 1. Create App at: https://github.com/organizations/<org>/settings/apps/new
#    - Name: squad-k8s-agent
#    - Homepage: https://github.com/<org>/tamresearch1
#    - Permissions (see table in Section 3, Option B)
#    - Installation: Organization (not per-repo)

# 2. Generate and download private key (.pem file)
# 3. Note the App ID (numeric)
# 4. Install App on the organization
# 5. Note the Installation ID (from /app/installations API)
```

```bash
# Upload private key to Azure Key Vault
az keyvault secret set \
  --vault-name squad-keyvault \
  --name squad-github-app-private-key \
  --file ./squad-k8s-agent.private-key.pem

# Store App ID and Installation ID as secrets too
az keyvault secret set --vault-name squad-keyvault \
  --name squad-github-app-id --value "<APP_ID>"
az keyvault secret set --vault-name squad-keyvault \
  --name squad-github-app-installation-id --value "<INSTALL_ID>"
```

### 5.2 AKS Workload Identity Setup

```bash
# Enable OIDC issuer on AKS cluster (if not already enabled)
az aks update -g <rg> -n <cluster> \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get OIDC issuer URL
OIDC_ISSUER=$(az aks show -g <rg> -n <cluster> \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)

# Create Managed Identity
az identity create -g <rg> -n squad-agent-identity

CLIENT_ID=$(az identity show -g <rg> -n squad-agent-identity \
  --query clientId -o tsv)

# Grant Key Vault access
az keyvault set-policy --name squad-keyvault \
  --object-id $(az identity show -g <rg> -n squad-agent-identity \
    --query principalId -o tsv) \
  --secret-permissions get

# Create federated credential
az identity federated-credential create \
  --identity-name squad-agent-identity \
  --resource-group <rg> \
  --name squad-agent-k8s \
  --issuer "$OIDC_ISSUER" \
  --subject "system:serviceaccount:squad:squad-agent" \
  --audience "api://AzureADTokenExchange"
```

### 5.3 Helm Chart Values

Add to the existing Squad Helm chart (PR #1239):

```yaml
# values.yaml additions
authProxy:
  enabled: true
  image: ghcr.io/<org>/squad-auth-proxy:latest
  port: 8081
  keyVault:
    name: squad-keyvault
    appIdSecretName: squad-github-app-id
    installationIdSecretName: squad-github-app-installation-id
    privateKeySecretName: squad-github-app-private-key

workloadIdentity:
  enabled: true
  managedIdentityClientId: ""  # Set per-cluster

serviceAccount:
  create: true
  name: squad-agent
  annotations: {}  # Populated by workloadIdentity.managedIdentityClientId
```

```yaml
# templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.serviceAccount.name }}
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "squad.labels" . | nindent 4 }}
  annotations:
    {{- if .Values.workloadIdentity.enabled }}
    azure.workload.identity/client-id: {{ .Values.workloadIdentity.managedIdentityClientId | quote }}
    {{- end }}
    {{- with .Values.serviceAccount.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
```

```yaml
# templates/agent-job.yaml — sidecar injection
{{- if .Values.authProxy.enabled }}
- name: auth-proxy
  image: {{ .Values.authProxy.image }}
  ports:
    - containerPort: {{ .Values.authProxy.port }}
  env:
    - name: KEYVAULT_NAME
      value: {{ .Values.authProxy.keyVault.name | quote }}
    - name: APP_ID_SECRET
      value: {{ .Values.authProxy.keyVault.appIdSecretName | quote }}
    - name: INSTALLATION_ID_SECRET
      value: {{ .Values.authProxy.keyVault.installationIdSecretName | quote }}
    - name: PRIVATE_KEY_SECRET
      value: {{ .Values.authProxy.keyVault.privateKeySecretName | quote }}
    - name: RATE_POOL_REDIS_ADDR
      value: {{ include "squad.redisAddr" . }}
    - name: PROXY_PORT
      value: {{ .Values.authProxy.port | quote }}
  resources:
    requests:
      cpu: 50m
      memory: 32Mi
    limits:
      cpu: 200m
      memory: 64Mi
  readinessProbe:
    httpGet:
      path: /healthz
      port: {{ .Values.authProxy.port }}
    initialDelaySeconds: 3
    periodSeconds: 5
{{- end }}
```

### 5.4 Auth-Proxy Implementation (Go)

The auth-proxy is a small Go binary (lives in `squad-on-aks/cmd/auth-proxy/`):

```go
// Key responsibilities:
// 1. On start: fetch App credentials from Key Vault via Workload Identity
// 2. Mint GitHub App JWT, exchange for installation token
// 3. Exchange installation token for Copilot token
// 4. Serve HTTP proxy on :8081 (forward to api.githubcopilot.com with auth header)
// 5. Background goroutine: renew tokens 5 min before expiry
// 6. After each proxied response: publish rate-limit headers to Redis

package main

import (
    "context"
    "net/http"
    "net/http/httputil"
    "net/url"
    "time"
    
    "github.com/Azure/azure-sdk-for-go/sdk/azidentity"
    "github.com/Azure/azure-sdk-for-go/sdk/security/keyvault/azsecrets"
)

type TokenManager struct {
    appID          string
    installationID string
    privateKey     []byte
    
    installToken   string
    installExpiry  time.Time
    copilotToken   string
    copilotExpiry  time.Time
    
    mu sync.RWMutex
}

func (tm *TokenManager) GetCopilotToken(ctx context.Context) (string, error) {
    tm.mu.RLock()
    if time.Until(tm.copilotExpiry) > 5*time.Minute {
        token := tm.copilotToken
        tm.mu.RUnlock()
        return token, nil
    }
    tm.mu.RUnlock()
    return tm.refresh(ctx)
}

// ReverseProxy forwards to api.githubcopilot.com, injecting the current token
func newProxy(tm *TokenManager) *httputil.ReverseProxy {
    target, _ := url.Parse("https://api.githubcopilot.com")
    proxy := httputil.NewSingleHostReverseProxy(target)
    proxy.ModifyRequest = func(req *http.Request) error {
        token, err := tm.GetCopilotToken(req.Context())
        if err != nil {
            return err
        }
        req.Header.Set("Authorization", "Bearer "+token)
        req.Host = target.Host
        return nil
    }
    return proxy
}
```

### 5.5 RBAC

```yaml
# templates/rbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: squad-agent
  namespace: squad
rules:
  # Read own pod spec (for capability self-discovery, #999)
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  # Read ConfigMaps (rate-pool config)
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: squad-agent
  namespace: squad
subjects:
  - kind: ServiceAccount
    name: squad-agent
    namespace: squad
roleRef:
  kind: Role
  name: squad-agent
  apiGroup: rbac.authorization.k8s.io
```

### 5.6 Network Policy

```yaml
# templates/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: squad-agent-egress
  namespace: squad
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: squad-agent
  policyTypes: ["Egress"]
  egress:
    # GitHub API
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
      ports:
        - protocol: TCP
          port: 443
    # Rate-pool Redis (in-cluster)
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: squad-redis
      ports:
        - protocol: TCP
          port: 6379
    # Azure Key Vault (HTTPS, covered by 0.0.0.0/0 above)
```

---

## 6. Fallback: PAT via External Secrets Operator

For environments where Workload Identity is unavailable (dev clusters, local kind), the auth-proxy can fall back to a
PAT stored in Azure Key Vault and synced to a K8s Secret by External Secrets Operator:

```yaml
# templates/externalsecret.yaml (optional, dev-only)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: squad-github-pat
  namespace: squad
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault-store
    kind: SecretStore
  target:
    name: squad-github-pat
    creationPolicy: Owner
  data:
    - secretKey: GITHUB_TOKEN
      remoteRef:
        key: squad-github-pat-token
```

```yaml
# Auth proxy env var (PAT fallback mode)
env:
  - name: AUTH_MODE
    value: "pat"
  - name: GITHUB_TOKEN
    valueFrom:
      secretKeyRef:
        name: squad-github-pat
        key: GITHUB_TOKEN
```

Auth-proxy checks `AUTH_MODE` at startup; if `github_app` (default), uses Workload Identity + Key Vault; if `pat`, uses
the mounted secret directly.

---

## 7. Rate Limit Coordination

The auth-proxy sidecar integrates with the priority-aware rate-pool from #979:

```
After each Copilot API response:
  proxy reads headers:
    x-ratelimit-limit:     <total quota>
    x-ratelimit-remaining: <remaining>
    x-ratelimit-reset:     <unix timestamp>
    retry-after:           <seconds, if 429>

  proxy publishes to Redis:
    HSET squad:rate-pool <pod-name> remaining <value>
    HSET squad:rate-pool <pod-name> reset      <timestamp>
    HSET squad:rate-pool <pod-name> updated_at <now>

Ralph (rate-pool coordinator) reads Redis, computes priority schedule per #979:
    P0: Picard, Worf     (architectural, security — never blocked)
    P1: Data, Seven      (core delivery — blocked only at <5% remaining)
    P2: Ralph, Scribe    (monitoring, logging — blocked at <20% remaining)
```

---

## 8. Security Considerations

| Risk | Mitigation |
|---|---|
| Private key exfiltration | Key never leaves Key Vault; pods receive only short-lived installation tokens |
| Token leakage in logs | Auth-proxy strips `Authorization` headers before logging; agent container never sees raw token |
| Pod escape → cluster token theft | Workload Identity tokens are projected volumes, not env vars; scoped to pod's ServiceAccount |
| GitHub App over-privilege | App permissions are minimal (Section 3, Option B table); can be reviewed in GitHub org settings |
| Rate-pool Redis poisoning | Redis accessible only from squad namespace pods (NetworkPolicy); no auth needed within namespace |
| Copilot token lifetime | ~30 min TTL limits window after a token is captured; proxy renews before expiry |
| Installation ID leakage | Installation ID is not secret (visible in GitHub UI); only the private key is sensitive |
| Audit trail | GitHub audit log records every API call by App name + installation; Azure KV log records every key fetch |

### 8.1 Secret Rotation Procedure

1. Generate new GitHub App private key in GitHub UI (old key remains valid during rotation window).
2. Upload new key to Azure Key Vault: `az keyvault secret set ...`
3. Pods pick up new key on next installation token renewal (within 55 minutes).
4. Delete old private key from GitHub App settings.
5. No pod restarts required.

---

## 9. Open Questions

| # | Question | Owner | Target |
|---|---|---|---|
| OQ-1 | Does our GitHub org have Copilot Business/Enterprise? GitHub Apps need org-level Copilot to access completions API. | Picard | Before implementation |
| OQ-2 | Should auth-proxy be a separate image or embedded in each agent image? Separate is cleaner for maintenance. | B'Elanna | Design review |
| OQ-3 | Rate-pool Redis: use the same Redis instance from PR #1239, or a dedicated instance? | B'Elanna | Helm chart update |
| OQ-4 | Should #995 (non-human user test) use a PAT first, then graduate to GitHub App, or start directly with GitHub App? | Picard | Sprint planning |
| OQ-5 | Key Vault policy: should each agent type (Ralph, Data, etc.) have separate Managed Identities, or share one? More identities = better blast-radius isolation. | Worf | Security review |

---

## 10. Summary Recommendation

| Phase | Action | Complexity | Risk |
|---|---|---|---|
| **Phase 1 (dev/test)** | PAT in K8s Secret (from Key Vault via ESO). Unblocks #995. | Low | Medium (static token) |
| **Phase 2 (staging)** | GitHub App + installation tokens. Sidecar proxy. No Workload Identity yet. | Medium | Low |
| **Phase 3 (production)** | GitHub App + Workload Identity + sidecar proxy. No static secrets in cluster. | High | Very Low |

Start Phase 1 to unblock #995. Begin Phase 2 in parallel — it's the target state for Squad-on-K8s launch.

---

*Design document for [#1248](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1248) (docs sub-task of [#998](https://github.com/tamirdresher_microsoft/tamresearch1/issues/998)). Feedback welcome on the design.*
