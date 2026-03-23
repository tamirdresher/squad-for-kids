# AKS Workload Identity — Per-Agent Scoping Spike

> **Issue:** [#1399](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1399) — Brady's Squad: spike on per-agent workload identity + AKS RBAC  
> **Date:** 2026-03-23  
> **Researcher:** Seven (Research & Docs)  
> **Status:** Research Complete — Ready for Brady Pairing Session  
> **Triggered by:** Brady Gaster (Dragonz Teams chat, 2026-03-23)

---

## TL;DR

The current Squad deployment uses **one shared Managed Identity** for all agent pods. Brady's ask is to give each agent its own identity so the blast radius of a compromised agent is contained. This is fully achievable with AKS Workload Identity — the main work is: one MSI per agent type, one ServiceAccount per agent, one federated credential per MSI. The existing Helm chart already has the scaffolding; it just needs to be parameterized per-agent.

**Recommended approach:** One MSI per **agent type** (not per pod replica), scoped to the minimum Azure RBAC roles that agent needs. Namespace per agent type in Kubernetes for K8s RBAC isolation.

---

## Section 1: AKS Workload Identity Basics

### How Azure AD Workload Identity (AZWI) Works

Azure AD Workload Identity replaces the older AAD Pod Identity (which used a mutating webhook on every pod). The new approach is native to Kubernetes and works via OIDC token projection.

**Flow:**
```
Pod → kubelet projects OIDC token into pod at /var/run/secrets/azure/tokens/
  → Azure SDK reads token automatically (DefaultAzureCredential)
  → Azure AD validates token against the federated credential registered on the MSI
  → Azure AD returns an access token for the MSI
  → Pod calls Azure APIs as the MSI
```

**Three components that must align:**

| Component | What it does |
|---|---|
| AKS OIDC Issuer | Cluster-level OIDC endpoint that Azure AD trusts |
| Kubernetes ServiceAccount | Annotated with the MSI client ID |
| Federated Identity Credential | On the MSI, trusts the cluster OIDC issuer + SA namespace/name |

### Service Account → MSI Binding

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: seven-sa
  namespace: squad-seven
  annotations:
    azure.workload.identity/client-id: "<MSI-CLIENT-ID-FOR-SEVEN>"
```

When a pod uses this ServiceAccount and has the label `azure.workload.identity/use: "true"`, the admission webhook injects the OIDC token volume automatically.

### Federated Identity Credential

This is registered on the MSI in Azure — it says "trust tokens issued by this AKS cluster's OIDC endpoint for the SA `seven-sa` in namespace `squad-seven`":

```bash
az identity federated-credential create \
  --name seven-fedcred \
  --identity-resource-id /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/msi-squad-seven \
  --issuer "https://oidc.prod-aks.azure.com/<cluster-oidc-hash>/" \
  --subject "system:serviceaccount:squad-seven:seven-sa" \
  --audience api://AzureADTokenExchange
```

---

## Section 2: Per-Agent Identity Architecture

### Option A: One MSI Per Agent Type (Recommended)

Each **agent type** (ralph, seven, data, belanna, picard, etc.) gets its own MSI. All replicas/pods of that agent type share one MSI.

**Pros:**
- Blast radius contained to one agent's capabilities (not all agents)
- Manageable number of MSIs (one per agent in `.squad/agents/`)
- Simple RBAC: each MSI gets only the roles it actually needs

**Cons:**
- If the MSI for `ralph` is compromised, all ralph pods are affected
- More MSIs to manage than a single shared identity

### Option B: One MSI Per Pod Instance

Each pod gets its own MSI. Max isolation.

**Pros:** True per-pod isolation

**Cons:**
- Operationally complex — MSIs must be created/deleted with pod lifecycle
- Not practical for CronJob-spawned pods (ephemeral)
- No meaningful security benefit for stateless agents

**Decision: Use Option A** — one MSI per agent type is the right balance for Squad.

### Minimum Permissions Per Agent

| Agent | Azure Resources Needed | Suggested Role |
|---|---|---|
| **ralph** | Key Vault (secrets: GitHub token, model keys), Storage (state files) | `Key Vault Secrets User`, `Storage Blob Data Reader` |
| **seven** | Key Vault, Storage (write research docs) | `Key Vault Secrets User`, `Storage Blob Data Contributor` |
| **data** | Key Vault, ACR (pull images), Storage | `Key Vault Secrets User`, `AcrPull`, `Storage Blob Data Contributor` |
| **belanna** | Key Vault, AKS (apply manifests) | `Key Vault Secrets User`, `Azure Kubernetes Service Cluster User Role` |
| **picard** | Key Vault, Storage (read/write), AKS (read) | `Key Vault Secrets User`, `Storage Blob Data Contributor` |
| **worf** | Key Vault, Azure Security (Defender APIs) | `Key Vault Secrets User`, `Security Reader` |
| **kes** | Key Vault, Storage (calendar/email state) | `Key Vault Secrets User`, `Storage Blob Data Reader` |

**Key principle:** Never assign `Owner`, `Contributor`, or `Key Vault Administrator` to agent MSIs. Agents read secrets — they do not manage infrastructure.

### GitHub Access: MSI vs GitHub App Installation Token

Brady's scenario involves agents accessing GitHub repos. There are two options:

| Approach | How it works | Best for |
|---|---|---|
| **GitHub App Installation Token** | Agent uses MSI to retrieve GitHub App private key from Key Vault, then exchanges it for a short-lived (1h) installation token via GitHub API | Repo operations (clone, push, PR creation) |
| **MSI direct** | Not applicable — GitHub is not an Azure resource | N/A |

**Recommendation:** Store the GitHub App private key in Key Vault. Each agent MSI gets `Key Vault Secrets User` on its own named secret (not the whole vault). Agent fetches the private key, generates an installation token, uses it for GitHub operations. The token expires in 1 hour — no long-lived credentials in the pod.

---

## Section 3: Implementation Steps

### Step 1: Enable OIDC Issuer + Workload Identity on AKS

```bash
# If not already enabled on the cluster
az aks update \
  --resource-group rg-squad \
  --name aks-squad \
  --enable-oidc-issuer \
  --enable-workload-identity

# Get the OIDC issuer URL (needed for federated credentials)
OIDC_ISSUER=$(az aks show \
  --resource-group rg-squad \
  --name aks-squad \
  --query "oidcIssuerProfile.issuerUrl" -o tsv)
```

> **AKS Automatic note:** Both flags are enabled by default on AKS Automatic. No action needed.

### Step 2: Create User-Assigned Managed Identity Per Agent

```bash
# Repeat for each agent: ralph, seven, data, belanna, picard, worf, kes
for AGENT in ralph seven data belanna picard worf kes; do
  az identity create \
    --name "msi-squad-${AGENT}" \
    --resource-group rg-squad \
    --location eastus
done

# Store client IDs for later
az identity list --resource-group rg-squad --query "[].{name:name, clientId:clientId}" -o table
```

### Step 3: Assign Azure RBAC to Each MSI

```bash
# Example: ralph gets Key Vault Secrets User on the squad Key Vault
RALPH_MSI_PRINCIPAL=$(az identity show \
  --name msi-squad-ralph \
  --resource-group rg-squad \
  --query principalId -o tsv)

az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee-object-id $RALPH_MSI_PRINCIPAL \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/<sub>/resourceGroups/rg-squad/providers/Microsoft.KeyVault/vaults/kv-squad-prod"

# Optional: scope to specific secret (least privilege)
az keyvault set-policy \
  --name kv-squad-prod \
  --object-id $RALPH_MSI_PRINCIPAL \
  --secret-permissions get list
```

### Step 4: Create K8s Namespaces + ServiceAccounts

```bash
# Create one namespace per agent
for AGENT in ralph seven data belanna picard worf kes; do
  kubectl create namespace squad-${AGENT}
done
```

```yaml
# ServiceAccount per agent — parameterized per agent
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ralph-sa
  namespace: squad-ralph
  labels:
    azure.workload.identity/use: "true"
  annotations:
    azure.workload.identity/client-id: "<RALPH-MSI-CLIENT-ID>"
```

### Step 5: Register Federated Identity Credentials

```bash
# Repeat for each agent
for AGENT in ralph seven data belanna picard worf kes; do
  AGENT_MSI=$(az identity show \
    --name msi-squad-${AGENT} \
    --resource-group rg-squad \
    --resource-id /subscriptions/<sub>/resourceGroups/rg-squad/providers/Microsoft.ManagedIdentity/userAssignedIdentities/msi-squad-${AGENT} \
    --query id -o tsv)
  
  az identity federated-credential create \
    --name "${AGENT}-fedcred" \
    --identity-resource-id "$AGENT_MSI" \
    --issuer "$OIDC_ISSUER" \
    --subject "system:serviceaccount:squad-${AGENT}:${AGENT}-sa" \
    --audience "api://AzureADTokenExchange"
done
```

### Step 6: Deploy Pods with Per-Agent ServiceAccount

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ralph-poller
  namespace: squad-ralph
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            azure.workload.identity/use: "true"   # triggers token injection
        spec:
          serviceAccountName: ralph-sa            # per-agent SA
          containers:
          - name: ralph
            image: acrsquadprod.azurecr.io/squad/ralph:latest
            env:
            - name: AZURE_CLIENT_ID
              value: "<RALPH-MSI-CLIENT-ID>"       # belt-and-suspenders
          restartPolicy: OnFailure
```

---

## Section 4: RBAC Integration

### Kubernetes RBAC — Namespace Isolation Per Agent

Each agent gets its own namespace. K8s RBAC prevents agents from reading each other's ConfigMaps, Secrets, or pod specs.

```yaml
# Role: ralph can only manage its own resources in squad-ralph ns
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ralph-role
  namespace: squad-ralph
rules:
- apiGroups: [""]
  resources: ["pods", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ralph-rolebinding
  namespace: squad-ralph
subjects:
- kind: ServiceAccount
  name: ralph-sa
  namespace: squad-ralph
roleRef:
  kind: Role
  name: ralph-role
  apiGroup: rbac.authorization.k8s.io
```

**Cross-namespace policy:** Add a NetworkPolicy that denies ingress from other agent namespaces:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-agent
  namespace: squad-ralph
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: squad-ralph   # only own namespace
```

### Azure RBAC — Resource Access Scoping

**Principle:** Each MSI gets roles assigned at the **resource scope**, not subscription scope.

```
msi-squad-ralph:
  - Key Vault Secrets User @ kv-squad-prod/secrets/github-app-private-key
  - Key Vault Secrets User @ kv-squad-prod/secrets/anthropic-api-key
  - Storage Blob Data Reader @ sa-squad-prod/containers/ralph-state

msi-squad-seven:
  - Key Vault Secrets User @ kv-squad-prod/secrets/github-app-private-key
  - Key Vault Secrets User @ kv-squad-prod/secrets/anthropic-api-key
  - Storage Blob Data Contributor @ sa-squad-prod/containers/seven-research

msi-squad-belanna:
  - Key Vault Secrets User @ kv-squad-prod/secrets/...
  - Azure Kubernetes Service Cluster User Role @ aks-squad
  - (no Storage — belanna manages infra, not data)
```

### GitHub App Installation Tokens vs MSI for Repo Access

| Criteria | GitHub App Token | MSI Direct |
|---|---|---|
| Scope | Per-repo or per-installation, fine-grained | Not applicable to GitHub |
| Lifetime | Max 1 hour (auto-expires) | N/A |
| Rotation | Automatic (requested on demand) | N/A |
| Per-agent scoping | ✅ Yes — one GitHub App installation per agent | N/A |
| Audit trail | GitHub audit log shows App name | N/A |

**Verdict:** Use GitHub App installation tokens. Store the GitHub App private key in Key Vault (per-agent secret or one shared secret). Each agent requests a fresh installation token when it needs repo access. MSI is only used to access Key Vault, not GitHub directly.

**One GitHub App per agent vs one shared App:**
- One shared App with per-agent installations = simpler management, still fine-grained permissions per repo
- One App per agent = max isolation, Brady's preferred model for the spike

---

## Section 5: CopilotClient fd-Exhaustion Bug Fix

### Why `new CopilotClient()` in a Loop Causes fd Exhaustion

Every `new CopilotClient()` call creates a new `HttpClient` instance internally. Each `HttpClient` opens TCP connections to the Copilot API endpoint. These connections are backed by OS file descriptors.

When you call `new CopilotClient()` in a tight loop (e.g., inside a CronJob that polls every 5 minutes and spawns subagents per item):

1. Each `CopilotClient` creates new `HttpClient` → new socket → new fd
2. The old `CopilotClient` is garbage collected eventually, but **TCP connections enter TIME_WAIT state** (default: 2–4 minutes on Linux)
3. The fd is not released until TIME_WAIT expires
4. Under any load, you exhaust the per-process fd limit (default: 1024 on many Linux distros, or `ulimit -n`)
5. Symptom: `System.Net.Sockets.SocketException: Too many open files` or hung HTTP calls

This is the same problem as the classic `new HttpClient()` anti-pattern documented by Microsoft.

### Correct Pattern: Singleton via DI

**Option 1 — Singleton registration (simplest):**

```csharp
// Program.cs / Startup.cs
builder.Services.AddSingleton<CopilotClient>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    return new CopilotClient(new CopilotClientOptions
    {
        Endpoint = config["Copilot:Endpoint"],
        ApiKey = config["Copilot:ApiKey"],
        // ... other options
    });
});
```

```csharp
// Agent class — inject, don't construct
public class RalphAgent
{
    private readonly CopilotClient _copilot;

    public RalphAgent(CopilotClient copilot)
    {
        _copilot = copilot;  // reused across all calls
    }

    public async Task RunAsync(IEnumerable<WorkItem> items)
    {
        foreach (var item in items)
        {
            // ✅ Reuses the same client — no new fd per item
            var result = await _copilot.CompleteAsync(item.Prompt);
        }
    }
}
```

**Option 2 — IHttpClientFactory (if CopilotClient accepts a factory):**

```csharp
builder.Services.AddHttpClient("copilot", client =>
{
    client.BaseAddress = new Uri(config["Copilot:Endpoint"]);
    client.DefaultRequestHeaders.Add("api-key", config["Copilot:ApiKey"]);
});

// CopilotClient takes IHttpClientFactory
builder.Services.AddSingleton<CopilotClient>(sp =>
{
    var factory = sp.GetRequiredService<IHttpClientFactory>();
    return new CopilotClient(factory.CreateClient("copilot"));
});
```

**Option 3 — Scoped for per-request isolation (if stateful):**

```csharp
// If CopilotClient is stateful per "conversation", use Scoped
builder.Services.AddScoped<CopilotClient>();

// In a CronJob host:
using var scope = serviceProvider.CreateScope();
var copilot = scope.ServiceProvider.GetRequiredService<CopilotClient>();
// Use copilot, then scope disposes cleanly
```

**Anti-pattern to fix (Brady's bug):**

```csharp
// ❌ BAD — creates a new client (and new fd) for every item
foreach (var item in workItems)
{
    var client = new CopilotClient(...);  // ← this is the bug
    await client.CompleteAsync(item.Prompt);
    // HttpClient/CopilotClient never explicitly disposed
    // TCP connection enters TIME_WAIT, fd leaked until GC + TIME_WAIT
}
```

**Linux fd limit tuning (temporary mitigation, not a fix):**

```yaml
# Pod securityContext — raise the limit as a stopgap only
spec:
  containers:
  - name: ralph
    securityContext:
      runAsNonRoot: true
    resources:
      limits:
        memory: "512Mi"
        cpu: "500m"
# In the container's entrypoint script:
# ulimit -n 65536
```

---

## Section 6: Squad-Specific Considerations

### Current State

The existing Helm chart (`infrastructure/helm/squad-agents/values.yaml`) uses:
- **One ServiceAccount** for all agents (auto-generated as `<release-name>-squad-agents`)
- **One MSI** via `azure.managedIdentityClientId`
- All agents in the `squad` namespace

### Migration Plan: Shared → Per-Agent Identity

**Phase 1 — No behavioral change (prep):**
1. Create per-agent namespaces: `squad-ralph`, `squad-seven`, `squad-data`, etc.
2. Create per-agent MSIs and register federated credentials
3. Deploy agents into per-agent namespaces with per-agent ServiceAccounts
4. Assign same roles as current shared MSI (no change in access)

**Phase 2 — Tighten RBAC:**
1. Audit what each agent actually accesses (Key Vault audit logs)
2. Revoke roles the agent doesn't use
3. Scope Key Vault access to specific secrets (not the whole vault)
4. Add NetworkPolicy to prevent cross-agent namespace traffic

**Helm chart changes needed:**

The `values.yaml` needs to be extended to support per-agent identity:

```yaml
# Proposed new structure in values.yaml
agents:
  ralph:
    enabled: true
    namespace: squad-ralph
    managedIdentityClientId: "<RALPH-MSI-CLIENT-ID>"
    schedule: "*/5 * * * *"
    image:
      repository: "acrsquadprod.azurecr.io/squad/ralph"
      tag: "latest"

  seven:
    enabled: true
    namespace: squad-seven
    managedIdentityClientId: "<SEVEN-MSI-CLIENT-ID>"
    schedule: "0 */6 * * *"
    image:
      repository: "acrsquadprod.azurecr.io/squad/seven"
      tag: "latest"

  data:
    enabled: true
    namespace: squad-data
    managedIdentityClientId: "<DATA-MSI-CLIENT-ID>"
    # ... etc
```

The Helm templates would loop over `agents` and generate:
- One `Namespace` per agent
- One `ServiceAccount` per agent (annotated with its MSI client ID)
- One `CronJob`/`Deployment` per agent in its namespace
- One `Role` + `RoleBinding` per agent
- One `NetworkPolicy` per agent namespace

### Squad Agent Identity Matrix

| Agent | Primary Function | Azure Resources | GitHub Access | MSI Scope |
|---|---|---|---|---|
| **ralph** | Work queue poller, task executor | Key Vault (secrets), Storage (state) | Read/write issues, PRs | Narrowest: specific secrets only |
| **seven** | Research & docs writer | Key Vault, Storage (research output) | Read issues, write files | Read-heavy |
| **data** | C#/.NET code expert | Key Vault, ACR (pull) | Read/write code PRs | Code-focused |
| **belanna** | Infrastructure expert | Key Vault, AKS cluster | Read infra repos | AKS read + deploy |
| **picard** | Lead / architecture | Key Vault, Storage | Read/write all repos | Broadest among agents |
| **worf** | Security & cloud | Key Vault, Azure Security APIs | Read security issues | Security reader |
| **kes** | Comms & scheduling | Key Vault, Storage (calendar) | Read emails/calendar | Comms-only |

### Pairing Session Agenda (for Brady)

1. **Confirm cluster OIDC issuer URL** — needed for federated credentials
2. **Create one MSI per agent** — `az identity create` loop
3. **Wire up Helm chart** — per-agent ServiceAccount + namespace
4. **Smoke test** — `kubectl exec` into a ralph pod and verify `az account show` returns ralph's identity
5. **Tighten Key Vault RBAC** — scope to specific secrets
6. **Fix CopilotClient bug** — audit all agent code for `new CopilotClient()` in loops

---

## Appendix: Verification Commands

```bash
# Verify workload identity is working in a pod
kubectl run -it --rm debug \
  --image mcr.microsoft.com/azure-cli \
  --namespace squad-ralph \
  --overrides='{"spec":{"serviceAccountName":"ralph-sa","labels":{"azure.workload.identity/use":"true"}}}' \
  -- az account show

# Should return ralph's MSI, not any human identity

# Check federated credentials are registered correctly
az identity federated-credential list \
  --identity-name msi-squad-ralph \
  --resource-group rg-squad

# Verify RBAC assignments
az role assignment list \
  --assignee <ralph-msi-principal-id> \
  --all -o table
```

---

## References

- [Azure Workload Identity for AKS — MS Learn](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview)
- [Use workload identity with AKS — Tutorial](https://learn.microsoft.com/en-us/azure/aks/workload-identity-deploy-cluster)
- [Federated identity credentials overview](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [Key Vault RBAC best practices](https://learn.microsoft.com/en-us/azure/key-vault/general/rbac-guide)
- [HttpClient anti-patterns (applies to CopilotClient too)](https://learn.microsoft.com/en-us/dotnet/fundamentals/networking/http/httpclient-guidelines)
- [GitHub Apps — installation tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- Existing research: `research/aks-automatic-squad-deployment-issue-1136.md`
