# 🔴 SECURITY AUDIT: idk8s-infrastructure (Celestial Platform)
## Lieutenant Worf — Security & Cloud Analysis
### Stardate 2025.07 | Classification: TACTICAL SECURITY ASSESSMENT

---

> *"A warrior's duty is to find the weaknesses before the enemy does."*
> — Lt. Worf, USS Enterprise-D

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Security Architecture Overview](#2-security-architecture-overview)
3. [Authentication Flows](#3-authentication-flows)
4. [Authorization Model](#4-authorization-model)
5. [Secrets & Certificate Management](#5-secrets--certificate-management)
6. [Network Security](#6-network-security)
7. [Container Security Posture](#7-container-security-posture)
8. [EV2 Security Model](#8-ev2-security-model)
9. [Security Findings](#9-security-findings)
10. [Recommendations](#10-recommendations)

---

## 1. Executive Summary

The Celestial Platform (idk8s-infrastructure / IDK8S / Identity Kubernetes Platform v3) is Microsoft Entra's Kubernetes-based infrastructure for deploying identity workloads. This audit covers the **management plane (SU API)**, **secrets management pipeline (DSMS/dSTS/ACMS)**, **EV2 deployment security**, **container security**, and **network perimeter** based on code-level analysis of the repository.

### Key Metrics
| Area | Status |
|------|--------|
| Authentication (MISE + dSTS) | ✅ Strong — dual-path Entra/dSTS with MISE middleware |
| Authorization (Tenant + RBAC) | ⚠️ Moderate — OBO flow not yet implemented |
| Secrets Management (DSMS/ACMS) | ✅ Strong — hardware-backed KeyGuard validation |
| Network Security | ⚠️ Moderate — LB IP restriction but gaps in internal comms |
| Container Security | ✅ Strong — distroless images, non-root, seccomp |
| EV2 Integration | ✅ Strong — compound identity with cert exchange |

### Critical Findings Count
| Severity | Count |
|----------|-------|
| CRITICAL | 1 |
| HIGH | 4 |
| MEDIUM | 6 |
| LOW | 3 |

---

## 2. Security Architecture Overview

The Celestial platform uses a multi-layered security architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                         EV2 (Express V2)                        │
│  ┌──────────┐   AadApp Token    ┌──────────────────────┐       │
│  │ Approval │ ──────────────── │ MP Extension          │       │
│  │ Service  │                   │ (AadApplicationAuth)  │       │
│  └──────────┘                   └──────────┬───────────┘       │
└─────────────────────────────────────────────┼───────────────────┘
                                              │ Entra/dSTS Token
                                              ▼
┌─────────────────────── MANAGEMENT PLANE ────────────────────────┐
│  ┌────────┐     ┌──────────┐    ┌───────────────────────┐      │
│  │ MISE   │────▶│ Tenant   │───▶│ Scale Unit API        │      │
│  │ AuthN  │     │ AuthZ    │    │ (k8s API + ARM calls) │      │
│  └────────┘     └──────────┘    └───────────┬───────────┘      │
│                                              │                  │
│              MP SP (SN+I cert from AKV)      │                  │
│              via ClientCertificateCredential │                  │
└──────────────────────────────────────────────┼──────────────────┘
                                               │
┌─────────────────────── CLUSTER NODES ────────┼──────────────────┐
│                                              ▼                  │
│  ┌──────────────┐   ┌───────────┐   ┌──────────────────┐       │
│  │ DSMS Bootstrap│──▶│ ACMS      │──▶│ Workload Pods    │       │
│  │ Node Service  │   │ (OneCert) │   │ (Geneva certs)   │       │
│  └──────────────┘   └───────────┘   └──────────────────┘       │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────────────┐           │
│  │ WireServer Proxy  │   │ KeyGuard Validation Svc  │           │
│  │ (root, HTTP only) │   │ (cert integrity monitor)  │           │
│  └──────────────────┘   └──────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

### Key Source Files Analyzed

| Component | Path |
|-----------|------|
| MP Program.cs (auth setup) | `/src/csharp/fleet-manager/ManagementPlane/Program.cs` |
| Mock Auth Handler | `/src/csharp/fleet-manager/ManagementPlane/Auth/MockAuthenticationHandler.cs` |
| Entra Tenant Auth | `.../Apis/Ev2/Authorization/Handlers/EntraTenantAuthorizationHandler.cs` |
| dSTS Tenant Auth | `.../Apis/Ev2/Authorization/Handlers/DstsTenantAuthorizationHandler.cs` |
| DSMS Bootstrap Service | `/src/csharp/fleet-manager/DsmsBootstrapNodeService/DsmsBootstrapService.cs` |
| DSMS Client | `.../DsmsBootstrapNodeService/Services/DsmsClient.cs` |
| dSTS Information Provider | `.../DsmsBootstrapNodeService/Services/DstsInformationProvider.cs` |
| KeyGuard Validator | `.../DsmsBootstrapNodeService/Services/KeyGuardValidationService.cs` |
| ACMS Manager (Linux) | `/src/csharp/fleet-manager/DsmsNativeBootstrapper/AcmsManagerForLinux.cs` |
| Bootstrapper | `/src/csharp/fleet-manager/DsmsNativeBootstrapper/Bootstrapper.cs` |
| WireServer File Proxy | `/src/csharp/fleet-manager/WireServerFileProxy/` |
| AzureClient Provider | `.../ResourceProvider/AzureClient/AzureClientProvider.cs` |
| AKV Resource Provider | `.../ResourceProvider/AzureClient/AzureKeyVaultResourceProvider.cs` |
| Secrets Role Assignment | `.../ResourceProvider/AzureClient/AzureSecretsRoleAssignmentClient.cs` |
| Celestial Helm Chart | `/src/helm/charts/celestial/templates/deployment.yaml` |
| Security Context Helper | `/src/helm/charts/celestial/templates/_helpers.tpl` |
| KV Watcher | `/src/helm/charts/keyvaultwatcher/` |
| EV2 Extension Manifest | `/src/ev2/extensions/MPExtensionManifest-PROD.json` |
| EV2 Service Model | `/ev2/management-plane/ServiceGroupRoot/ServiceModel.json` |

---

## 3. Authentication Flows

### 3.1 MISE (Microsoft Identity Service Essentials) — Primary AuthN

**Source**: `ManagementPlane/Program.cs` lines in `AddAuthentication()` method

Production authentication uses MISE middleware with two modes:

```csharp
// Program.cs - AddAuthentication()
if (managementPlaneConfiguration.UseDsts)
{
    builder.Services
        .AddMiseWithDefaultAuthentication(builder.Configuration, authenticationSectionName: "dSTS")
        .EnableTokenAcquisitionToCallDownstreamApiAndDataProviderAuthentication(
            S2SAuthenticationDefaults.AuthenticationScheme);
}
else
{
    string sectionName = managementPlaneConfiguration.IsCliMode() ? "AzureAdCli" : "AzureAd";
    builder.Services
        .AddMiseWithDefaultModules(builder.Configuration, authenticationSectionName: sectionName);
}
```

**Assessment**: ✅ MISE correctly implements ASP.NET Core authentication with proper scheme registration. The dual-path (Entra + dSTS) provides flexibility across AME and CORP environments.

### 3.2 Mock Authentication Handler — Development Only

**Source**: `ManagementPlane/Auth/MockAuthenticationHandler.cs`

```csharp
protected override Task<AuthenticateResult> HandleAuthenticateAsync()
{
    var claims = new[]
    {
        new Claim(UniqueNameClaimName, $"{Environment.UserName}@microsoft.com"),
        new Claim(IdTypClaimName, AzpClaimValue),  // "app" — bypasses app token check
        new Claim(OidClaimName, Oid),  // Hardcoded OID: 99f45696-105c-49cd-88d5-feb4a4deeaf3
    };
    // ... creates mock ticket
}
```

**Assessment**: ⚠️ The mock handler is gated by `isDevelopment` check. However, the hardcoded OID `99f45696-105c-49cd-88d5-feb4a4deeaf3` is described as "The application ID which will allow access to LinuxApp and WinApp in CORP." This OID appears to be a real CORP app ID baked into source code. See **Finding WORF-HIGH-01**.

### 3.3 EV2 → Management Plane Authentication

**Source**: `MPExtensionManifest-PROD.json`, `MP-authn-authz.md`

```json
{
  "authentications": [
    {
      "type": "AadApplicationAuthentication",
      "properties": {
        "resourceUri": "https://idk8s-managementplane-prod"
      }
    }
  ]
}
```

EV2 authenticates by:
1. Downloading a certificate via compound identity (cert created during onboarding)
2. Exchanging the certificate for an Entra token against `https://idk8s-managementplane-prod` audience
3. SU API validates the token via MISE

**Assessment**: ✅ Standard EV2 AadApplicationAuthentication pattern. The resource URI is properly scoped per environment.

### 3.4 Management Plane → Downstream Services (SN+I Certificate)

**Source**: `Program.cs` — `AddAzureClientCertificate()` method, `AzureClientProvider.cs`

```csharp
async Task AddAzureClientCertificate()
{
    X509Certificate2 certificate = await CertificateLoader.LoadCertificate(
        isDevelopment, managementPlaneConfiguration, CancellationToken.None);
    builder.Services.Configure<AzureClientCertificateConfiguration>(options =>
    {
        options.Certificate = certificate;
    });
}
```

The MP uses a **OneCert SN+I certificate** stored in Azure Key Vault, accessed via **Node MSI**. The `AzureClientProvider` creates `ArmClient` instances using this `TokenCredential` (backed by `ClientCertificateCredential`).

**Assessment**: ⚠️ The docs state: *"MP uses the MP cluster node MSI to access the AKV with the MP identity certificate. The role assignment that gives NodeMSI access needs to be done manually when the cluster is created. This solution should be replaced with native dSMS support."* See **Finding WORF-MEDIUM-01**.

### 3.5 dSTS SCI Authentication (Node-Level)

**Source**: `DsmsClient.cs`, `DstsInformationProvider.cs`

The DSMS Bootstrap Node Service authenticates to dSMS using a dSTS Service Client Identity:

```csharp
// DsmsClient.cs - Lazy initialization
_dstsApp = new Lazy<IConfidentialClientApplication>(() =>
{
    return ConfidentialClientApplicationBuilder
        .Create(_dstsAppInfo.Value.PrincipalId)
        .WithAuthority(_dstsAppInfo.Value.DstsAuthorityUrl)
        .WithCertificate(_dstsAppInfo.Value.Certificate, sendX5C: true)
        .Build();
}, LazyThreadSafetyMode.ExecutionAndPublication);
```

The SCI info is resolved from either:
- `foundational_resources.json` (new path — written by node bootstrap)
- Legacy `dmsi.ini` + `SciData.json` mapping file

**Assessment**: ✅ Good use of MSAL with `sendX5C: true` for certificate chain validation. The SCI has a constant dSTS tenant ID: `7a433bfc-2514-4697-b467-e0933190487f`.

---

## 4. Authorization Model

### 4.1 Tenant Authorization — Entra Path

**Source**: `EntraTenantAuthorizationHandler.cs`

```csharp
// Validates that the token is an application token (not user/delegated)
if (!idType.Equals(IdType, StringComparison.OrdinalIgnoreCase))  // IdType = "app"
{
    context.Fail(...);
    return;
}

// Validates that the OID matches the expected deployment identity for the scale unit
ObjectId expectedOid = await _celestialServiceRegistry
    .GetScaleUnitAuthorizationOidAsync(scaleUnitName, CancellationToken.None);

if (expectedOid.Value != Guid.Parse(oid))
{
    context.Fail(...);
    return;
}
```

**Assessment**: ✅ Properly validates: (1) `idtyp=app` to ensure application-only tokens, (2) OID matches per-tenant ServiceProfile configuration. This prevents user tokens from being accepted.

### 4.2 Tenant Authorization — dSTS Path

**Source**: `DstsTenantAuthorizationHandler.cs`

```csharp
// Validates security group claim matches deployment security group
var deploymentSecurityGroup = scaleUnitMetadata.DeploymentSecurityObjectId;
var groupClaims = GetUserGroups(context);

if (!groupClaims.Any(c => c == deploymentSecurityGroup.Value))
{
    context.Fail(...);
}
```

**Assessment**: ✅ Group-based authorization for dSTS OBO tokens. Only `RolePrincipalType.Group` is supported, properly rejecting other principal types.

### 4.3 Kubernetes RBAC

**Source**: `MP-authn-authz.md`

Two cluster roles defined in `idk8s-infrastructure-enablement`:
- **`workload-provisioner`**: Bound to MP service principal
- **`workload-deployer`**: Currently also bound to MP SP, but intended for EV2 compound identity (OBO flow)

**Assessment**: ⚠️ Both roles are currently bound to the same MP SP. The intended separation (provisioner for MP, deployer for EV2 OBO identity) is **not yet implemented**. This means the MP SP has overly broad k8s permissions. See **Finding WORF-HIGH-02**.

### 4.4 Authorization Policies

**Source**: `AuthorizationPoliciesConstants.cs`

```csharp
internal static class AuthorizationPoliciesConstants
{
    public const string ScaleUnitAuthorizationPolicy = "ScaleUnitAuthorizationPolicy";
    public const string TenantAuthorizationPolicy = "TenantAuthorizationPolicy";
}
```

The `TenantAuthorizationPolicy` is applied via `Program.cs`:
```csharp
builder.Services
    .AddAuthorizationBuilder()
    .AddPolicy(AuthorizationPoliciesConstants.TenantAuthorizationPolicy,
        policy => policy.Requirements.Add(new TenantAuthorizationRequirement()));
```

And all controllers require authorization: `app.MapControllers().RequireAuthorization();`

**Assessment**: ✅ Good — all endpoints require authorization by default. Individual EV2 endpoints additionally apply the `TenantAuthorizationPolicy`.

---

## 5. Secrets & Certificate Management

### 5.1 Certificate Lifecycle Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CERTIFICATE LIFECYCLE                             │
│                                                                     │
│  OneCert (SN+I) ──▶ Azure Key Vault ──▶ Node MSI ──▶ MP Program   │
│                     (per-region)         (manual)     (startup)     │
│                                                                     │
│  dSMS Cert ──▶ VMSS ARM Template ──▶ KeyGuard ──▶ DsmsBootstrap   │
│  (per-VMSS)    (idk8sctl create)     (validated)   Node Service    │
│                                                                     │
│  ACMS Agent ──▶ DsmsNativeBootstrapper ──▶ OneCert Rotation        │
│  ID Cert        (init container)           (automated)             │
│                                                                     │
│  SSL Certs ──▶ AKV (platform-managed) ──▶ init-geneva-cert         │
│  Geneva Certs    OR dSMS (v3 clusters)    container (az CLI)       │
│                                                                     │
│  EV2 Cert ──▶ Compound Identity ──▶ Entra Token Exchange           │
│  (platform)   (deployment SG)       (AadApplicationAuth)           │
└─────────────────────────────────────────────────────────────────────┘
```

### 5.2 DSMS Bootstrap Node Service

**Source**: `DsmsBootstrapService.cs`, `DsmsClient.cs`, `LinuxCertificateInjector.cs`

This is a **DaemonSet-style service** running on each k8s worker node that:
1. Monitors containerd for new containers with `dsms/containers` annotations
2. Downloads certificates from dSMS using dSTS tokens
3. Injects certificates into containers via `/dev/shm/dsms/` (tmpfs memory-backed)

```csharp
// LinuxCertificateInjector.cs
public const string InjectionFolderPath = DevShmPath + "/dsms";  // /dev/shm/dsms
public const string InjectedCertificateFilePath = InjectionFolderPath + "/bootstrapcert.pfx";
public const string InjectedPasswordFilePath = InjectionFolderPath + "/bootstrapcert.pass";
```

**Assessment**: ✅ **Excellent** — Uses `/dev/shm` (tmpfs) so certificates never touch disk. Memory-backed volumes with explicit `sizeLimit`. However, see **Finding WORF-MEDIUM-02** regarding the certificate cache.

### 5.3 DsmsNativeBootstrapper (Init Container)

**Source**: `Bootstrapper.cs`, `AcmsManagerForLinux.cs`

The bootstrapper is an **init container** (with `restartPolicy: Always` for sidecar behavior) that:
1. Reads the bootstrap certificate injected by DsmsBootstrapNodeService from `/dev/shm/dsms/`
2. Installs ACMS (Azure Credentials Management Service) with the certificate thumbprint
3. ACMS then handles ongoing certificate rotation via OneCert

```csharp
// Bootstrapper.cs
public const string CertFolderPath = "/dev/shm/dsms";
public const string CertificateFilePath = CertFolderPath + "/bootstrapcert.pfx";
public const string PasswordFilePath = CertFolderPath + "/bootstrapcert.pass";
```

**Assessment**: ✅ Proper separation of concerns. The bootstrapper uses PersistKeySet for the X509 store:
```csharp
new X509Certificate2(certBytes, password,
    X509KeyStorageFlags.UserKeySet | X509KeyStorageFlags.PersistKeySet);
```

### 5.4 KeyGuard Validation Service

**Source**: `KeyGuardValidationService.cs`

This service validates that certificate private keys are stored in **KeyGuard** (hardware-backed VBS isolation):

```csharp
internal static bool IsPrivateKeyInKeyGuard(X509Certificate2 cert, out string? reason)
{
    // Checks RSACng key property "Virtual Iso"
    if (!rsaCng.Key.HasProperty(NCryptUseVirtualIsolationProperty, CngPropertyOptions.None))
    {
        reason = $"Property '{NCryptUseVirtualIsolationProperty}' not set";
        return false;
    }
    // ... validates keyGuardValue[0] != 0
}
```

Validates two certificate types:
- **AgentID**: Self-signed certificates with `CN=/certificates/selfsigned/agentidcert/` prefix
- **VmssID**: Certificates matching the cluster cert subject DN

**Assessment**: ✅ **Outstanding** — Proactive KeyGuard monitoring with metrics emission. This is a defense-in-depth control that detects if certificates are not properly protected by hardware isolation.

### 5.5 Platform-Managed Secrets (Legacy/v2 Path)

**Source**: `deployment.yaml` — `init-geneva-cert` container

For non-dSMS clusters, certificates are fetched from AKV using Azure CLI in an init container:

```yaml
command: ['bash', '-c',
  'az login --federated-token $(cat $AZURE_FEDERATED_TOKEN_FILE) ... &&
   az keyvault secret download --file /geneva/geneva_auth/genevacert.pfx ... &&
   openssl pkcs12 -in /geneva/geneva_auth/genevacert.pfx -out /geneva/geneva_auth/gcskey.pem -clcerts -nodes -passin pass:'
]
```

**Assessment**: ⚠️ Several concerns:
1. PFX is downloaded and converted to PEM with `-nodes` (no encryption on private key) — stored in emptyDir (Memory-backed at least)
2. Azure CLI runs with workload identity token — requires federated token file access
3. The `-passin pass:` indicates the PFX has an empty password

See **Finding WORF-MEDIUM-03**.

### 5.6 Key Vault Resource Provisioning

**Source**: `AzureKeyVaultResourceProvider.cs`

```csharp
var keyVaultContent = new KeyVaultCreateOrUpdateContent(
    new AzureLocation(region),
    new KeyVaultProperties(
        Guid.Parse(tenantId),
        new KeyVaultSku(KeyVaultSkuFamily.A, KeyVaultSkuName.Standard))
    {
        EnableRbacAuthorization = true  // ✅ RBAC, not access policies
    });
```

**Assessment**: ✅ Good — RBAC authorization is enabled (not legacy access policies). Secret-level role assignments are properly scoped via `AzureSecretsRoleAssignmentClient`.

---

## 6. Network Security

### 6.1 Load Balancer Source Restrictions

**Source**: `MP-authn-authz.md`, `service.yaml`

Per the docs: *"SU API endpoints in AME MP instances allow connections only from EV2 IPs as configured in the values.yaml files."*

The service template supports `loadBalancerSourceRanges` via values files and uses `azure-pip-ip-tags` for FirstPartyUsage tagging:

```yaml
annotations:
  service.beta.kubernetes.io/azure-pip-ip-tags: "FirstPartyUsage={{ .Values.deployment.loadBalancer.ingressServiceTag }}"
```

**Assessment**: ⚠️ The docs note: *"EV2 does not support a service tag, and the Azure Cloud plugin does not allow mixing service tags with individual IPs in `loadBalancerSourceRanges`, so with the current infrastructure, we can't add access from SAW."* This means:
- No SAW access for operational debugging
- LB source restrictions are IP-based only (no service tag support)

See **Finding WORF-MEDIUM-04**.

### 6.2 WireServer Access Restriction

**Source**: ADR 0011, `WireServerFileProxy/`

WireServer (169.254.169.1) is blocked at the network level. A dedicated proxy (`WireServerFileProxy`) runs as root to proxy only the service tags file:

```csharp
// WireServerFileProxy/Program.cs
app.MapGet("/serviceTags/{*route}", (string route, [FromServices] IFileProxyService service) =>
    service.GetServiceTagFileContentsAsync(route, CancellationToken.None));
```

**Assessment**: ⚠️ The proxy:
- Listens on HTTP (not HTTPS) — `http://*:{port}`
- Has no authentication middleware
- Runs as root (required for WireServer access)
- Only proxies service tags, which is properly scoped

See **Finding WORF-HIGH-03**.

### 6.3 IMDS Access

**Source**: ADR 0002

IMDS access is prohibited by default. An exception was filed specifically for the ScheduledEventsCollector (SEC) component. This is properly scoped.

**Assessment**: ✅ Good — Default-deny for IMDS with explicit exception only for scheduled events.

---

## 7. Container Security Posture

### 7.1 Security Context (All Celestial Containers)

**Source**: `_helpers.tpl`

```yaml
{{- define "celestial.containerSecurityContext" -}}
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - all
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  readOnlyRootFilesystem: true
  seccompProfile:
    type: RuntimeDefault
{{- end }}
```

**Assessment**: ✅ **Excellent** security context:
- ✅ `allowPrivilegeEscalation: false`
- ✅ All capabilities dropped
- ✅ Non-root (UID 1000)
- ✅ Read-only root filesystem
- ✅ Seccomp RuntimeDefault

This is applied to **all** containers in the celestial deployment template via `{{- include "celestial.containerSecurityContext" . | nindent 10 }}`.

### 7.2 Service Account Token

**Source**: `deployment.yaml`

```yaml
automountServiceAccountToken: false  # IMPORTANT: false for service deployment
```

For KV Watcher: `automountServiceAccountToken: true` (required for k8s API access).

**Assessment**: ✅ Good — SA token mounting disabled by default. Only enabled where explicitly needed.

### 7.3 Dockerfile Analysis

| Image | Base | Non-root | Assessment |
|-------|------|----------|------------|
| DsmsBootstrapNodeService | `mcr.microsoft.com/dotnet/aspnet:8.0-azurelinux3.0` | Via Helm (UID 1000) | ⚠️ No USER directive in Dockerfile |
| DsmsNativeBootstrapper | `mcr.microsoft.com/dotnet/runtime-deps:8.0-azurelinux3.0` | UID 1000 dirs created | ✅ Proper UID setup |
| WireServerFileProxy | `mcr.microsoft.com/dotnet/aspnet:8.0-azurelinux3.0-distroless` | Via Helm | ✅ Distroless final stage |
| node-problem-detector | `mcr.microsoft.com/azurelinux/base/core:3.0` | Not specified | ⚠️ No USER directive |
| skylarcagent (Windows) | `skylarcagentacr.azurecr.io/skylarc-agent:1.0.4` | N/A (Windows) | ⚠️ Windows container |

**DsmsBootstrapNodeService Dockerfile** downloads `crictl` from GitHub with proper SHA256 verification:
```dockerfile
RUN expected_sha256=$(cat crictl-$VERSION-linux-amd64.tar.gz.sha256 | awk '{print $1}') && \
    actual_sha256=$(sha256sum crictl-$VERSION-linux-amd64.tar.gz | awk '{print $1}') && \
    if [ "$expected_sha256" != "$actual_sha256" ]; then echo "SHA256 checksum mismatch!"; exit 1; fi
```

**Assessment**: ✅ Good supply chain verification for crictl binary. The `DsmsNativeBootstrapper` Dockerfile installs `acms-client` via `tdnf` and properly sets up UID 1000 directories.

### 7.4 Volume Security

**Source**: `deployment.yaml`

All sensitive volumes use memory-backed emptyDir with explicit size limits:

```yaml
- name: keyvault-auth-vol
  emptyDir:
    medium: "Memory"
    sizeLimit: 10Mi
- name: ssl-auth-vol
  emptyDir:
    medium: "Memory"
    sizeLimit: 10Mi
- name: dsms-secrets
  emptyDir:
    medium: Memory
    sizeLimit: 5Mi
```

**Assessment**: ✅ Excellent — Memory-backed volumes prevent secrets from being written to disk. Size limits prevent resource exhaustion.

---

## 8. EV2 Security Model

### 8.1 Extension Manifest

**Source**: `MPExtensionManifest-PROD.json`

```json
{
  "namespace": "Microsoft.Identity.Celestial",
  "serviceIdentifier": "5cee095b-4378-4308-b09d-06b70ae9ff8a",
  "endpoints": ["https://*.prod.celestial.trafficmanager.net/api/v1"],
  "authentications": [{
    "type": "AadApplicationAuthentication",
    "properties": {
      "resourceUri": "https://idk8s-managementplane-prod"
    }
  }]
}
```

**Assessment**: ✅ Properly configured:
- Wildcard endpoint scoped to `.prod.celestial.trafficmanager.net`
- AAD application authentication with proper resource URI
- Owner group and incident escalation configured

### 8.2 Compound Identity Flow

Per `MP-authn-authz.md`:
1. Platform generates EV2 certificate during onboarding
2. Deployment security group is granted access via EV2 compound identity
3. EV2 downloads the cert, exchanges it for an Entra token against the customer-owned SCI
4. SU API validates the token's OID matches the tenant's `ServiceProfile.json` configuration

### 8.3 Future: dSTS OBO Flow

**Source**: `MP-authn-authz.md`

The planned improvement is a **dSTS User OBO (On-Behalf-Of) flow** where:
- EV2 passes the approver's dSTS identity
- dSTS creates a delegated compound token
- The compound token would be scoped to specific k8s namespaces

**Assessment**: This is the ideal end state for tenant isolation. Currently not implemented. See **Finding WORF-HIGH-02**.

---

## 9. Security Findings

### WORF-CRITICAL-01: Certificate Password Stored Alongside Certificate in Memory Volume

**Severity**: CRITICAL
**Component**: `LinuxCertificateInjector.cs`, `Bootstrapper.cs`
**File**: `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/LinuxCertificateInjector.cs`

The bootstrap certificate PFX and its password are written as separate files in the **same directory** (`/dev/shm/dsms/`) and are accessible to any process in the container:

```csharp
_containerdClient.WriteFile(containerId, bootstrapCertBase64, InjectedCertificateFilePath);  // .pfx
_containerdClient.WriteFile(containerId, bootstrapCertPassword, InjectedPasswordFilePath);   // .pass
```

While `/dev/shm` is memory-backed (good), both the certificate and password are co-located. If a container process is compromised, the attacker gets both the cert and password. Additionally, the `_containerdClient.ExecListFiles` call before and after injection leaks file listing to logs.

**Recommendation**: Consider using a single PKCS#12 with hardware-bound protection rather than file-based password. At minimum, restrict file permissions on the injected files.

---

### WORF-HIGH-01: Hardcoded CORP Application ID in Mock Auth Handler

**Severity**: HIGH
**Component**: `MockAuthenticationHandler.cs`
**File**: `/src/csharp/fleet-manager/ManagementPlane/Auth/MockAuthenticationHandler.cs`

```csharp
private const string Oid = "99f45696-105c-49cd-88d5-feb4a4deeaf3";
```

This hardcoded OID is described as the app ID for LinuxApp/WinApp in CORP. While gated behind `isDevelopment`, this is a real application identity committed to source code. If the environment detection is misconfigured, this mock handler would accept any request with full permissions.

**Recommendation**: Remove the hardcoded CORP OID. Use a clearly synthetic/test-only value for development. Add explicit safeguards (e.g., fail if `ASPNETCORE_ENVIRONMENT` is not explicitly `Development`).

---

### WORF-HIGH-02: OBO Flow Not Implemented — MP SP Has Overly Broad K8s Permissions

**Severity**: HIGH
**Component**: Management Plane k8s RBAC
**Source**: `MP-authn-authz.md`

Both `workload-provisioner` and `workload-deployer` cluster roles are bound to the same MP service principal. The intended separation where `workload-deployer` would use a tenant-specific compound EV2 identity (OBO flow) has **not been implemented**.

This means:
- The MP SP can perform all k8s operations regardless of which tenant initiated the request
- No tenant isolation at the k8s API level
- A compromised EV2 cert for any tenant could trigger operations across all namespaces

The docs acknowledge this: *"To improve tenant isolation, the intention is to use the OBO flow..."*

**Recommendation**: Prioritize the dSTS OBO flow implementation. As an interim measure, implement k8s admission policies that validate the originating tenant against the target namespace.

---

### WORF-HIGH-03: WireServer File Proxy — Unauthenticated HTTP Service Running as Root

**Severity**: HIGH
**Component**: `WireServerFileProxy`
**Files**: `/src/csharp/fleet-manager/WireServerFileProxy/Program.cs`, ADR 0011

The WireServer File Proxy:
- Runs on **HTTP** (not HTTPS): `builder.WebHost.UseUrls($"http://*:{port}")`
- Has **no authentication** middleware
- Must run as **root** (required for WireServer network access)
- Is accessible to any pod that can reach its service endpoint

```csharp
app.MapGet("/serviceTags/{*route}", ...);  // No [Authorize] attribute
app.MapHealthChecks("/healthz");
```

While the proxy only serves the service tags file (which is low-sensitivity), the combination of root privileges and no authentication creates an attack surface. A path traversal or URL injection bug in the `route` parameter could be exploited.

**Recommendation**: Add network policies to restrict which pods can reach the proxy. Consider adding a simple shared-secret or mTLS for authentication. Audit the route parameter for injection attacks.

---

### WORF-HIGH-04: DSMS Certificate Cache Has No Eviction Policy

**Severity**: HIGH
**Component**: `DsmsClient.cs`
**File**: `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/DsmsClient.cs`

```csharp
private readonly ConcurrentDictionary<string, CertificateData> _certsCache;
// ...
// TODO: Add cache eviction based on cert expiration
if (_certsCache.TryGetValue(dsmsServiceObjectPath, out CertificateData? certData))
{
    return certData;  // Returns cached cert even if expired
}
```

The cache has a `TODO` comment for eviction but it's **not implemented**. Expired certificates will continue to be served from cache. This could lead to:
- Serving expired certificates to containers
- Memory growth over time as certificates accumulate
- Continued use of potentially compromised certificates after rotation

**Recommendation**: Implement cache eviction based on certificate `NotAfter` date. Set a maximum cache TTL aligned with the certificate rotation schedule.

---

### WORF-MEDIUM-01: Manual Node MSI Role Assignment for AKV Access

**Severity**: MEDIUM
**Component**: Management Plane identity setup
**Source**: `MP-authn-authz.md`

The MP docs state: *"MP uses the MP cluster node MSI to access the AKV with the MP identity certificate. The role assignment that gives NodeMSI access needs to be done manually when the cluster is created."*

Manual steps in security-critical paths create risk of misconfiguration, drift, and audit gaps.

**Recommendation**: Complete the migration to native dSMS support as noted in the docs. Automate the role assignment as part of the `idk8sctl create cluster` workflow.

---

### WORF-MEDIUM-02: Certificate Data Contains Password in PFX Format

**Severity**: MEDIUM
**Component**: `DsmsClient.cs`, `CertificateData` model
**File**: `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/DsmsClient.cs`

```csharp
certData = new CertificateData(dsmsCert.Body, dsmsCert.Password);
```

The `CertificateData` model carries both the PFX body and password. This data is stored in the `ConcurrentDictionary` cache (WORF-HIGH-04) in memory without any encryption or secure memory handling. While in-process memory is generally protected, a memory dump or crash dump would expose all cached certificates and their passwords.

**Recommendation**: Consider using `SecureString` or platform secure enclave for password storage. Ensure crash dumps are restricted and do not capture process memory.

---

### WORF-MEDIUM-03: Init Container Uses Azure CLI with Unencrypted PEM Output

**Severity**: MEDIUM
**Component**: `deployment.yaml` — `init-geneva-cert` container
**File**: `/src/helm/charts/celestial/templates/deployment.yaml`

The legacy (non-dSMS) path downloads certificates via `az keyvault secret download` and converts to PEM with no password:

```bash
openssl pkcs12 -in /geneva/geneva_auth/genevacert.pfx \
  -out /geneva/geneva_auth/gcskey.pem -clcerts -nodes -passin pass:
```

The `-nodes` flag means the private key is written unencrypted. While stored in a memory-backed emptyDir, the PEM file is readable by all containers sharing the volume.

**Recommendation**: Migrate all workloads to dSMS path (v3 clusters). For remaining v2 clusters, evaluate if Geneva agents support password-protected PEM files.

---

### WORF-MEDIUM-04: Load Balancer Cannot Mix Service Tags with IP-Based Source Restrictions

**Severity**: MEDIUM
**Component**: Service networking
**Source**: `MP-authn-authz.md`

*"EV2 does not support a service tag, and the Azure Cloud plugin does not allow mixing service tags with individual IPs in `loadBalancerSourceRanges`"*

This limitation means:
- No SAW access for operational debugging of production SU API
- No additional allowed service tags for monitoring/management

**Recommendation**: Investigate Azure Private Link as an alternative access path for SAW. Consider a separate internal service endpoint for debugging.

---

### WORF-MEDIUM-05: Self-Signed CAs in OSS Components Acknowledged but Unresolved

**Severity**: MEDIUM
**Component**: In-cluster TLS
**Source**: ADR 0007

The ADR acknowledges: *"OSS Components that come with built-in logic to generate a self-signed CA bundle... Gatekeeper, metrics-server, and KEDA fall into this category. Since these components have been running in the cluster for a while, we acknowledge this as a known gap."*

Self-signed CAs in production components present a risk of MITM within the cluster.

**Recommendation**: Follow up with the security team (as noted in the ADR) to determine if this pattern is acceptable. Evaluate cert-manager integration for OSS components.

---

### WORF-MEDIUM-06: V2 Clusters Lack MP Service Principal RBAC Bindings

**Severity**: MEDIUM
**Component**: k8s RBAC for v2 clusters
**Source**: `MP-authn-authz.md`

*"V2 clusters do not have roles and role bindings for the MP service principal created yet."*

V2 clusters are either using broader permissions or the MP cannot manage them through proper RBAC channels.

**Recommendation**: Create proper RBAC bindings for v2 clusters or ensure they are on a migration path to v3.

---

### WORF-LOW-01: GDN Security Suppressions File is Effectively Empty

**Severity**: LOW
**Component**: `.gdn/global.gdnsuppress`
**File**: `/.gdn/global.gdnsuppress`

The Guardian security suppressions file contains only 1 character (effectively empty). This is actually positive — it means no security findings are being suppressed.

**Assessment**: ✅ No suppressions — good security hygiene.

---

### WORF-LOW-02: KV Watcher ConfigMap Exposes Key Vault URL and Secret Names

**Severity**: LOW
**Component**: KeyVault Watcher
**File**: `/src/helm/charts/keyvaultwatcher/templates/kvw-configmap.yaml`

The ConfigMap contains KV URLs and secret names in plaintext. While ConfigMaps are not secrets, this information could help an attacker who has gained cluster access to identify high-value targets.

**Recommendation**: Ensure k8s RBAC restricts ConfigMap read access to the KV watcher service account only.

---

### WORF-LOW-03: Skylarcagent Windows Container Uses External ACR Image

**Severity**: LOW
**Component**: Skylarcagent Dockerfile
**File**: `/docker/skylarcagent/windows/Dockerfile`

```dockerfile
FROM skylarcagentacr.azurecr.io/skylarc-agent:1.0.4
```

The base image is pulled from `skylarcagentacr.azurecr.io`, a separate ACR. Ensure this ACR has proper vulnerability scanning and access controls.

**Recommendation**: Verify the Skylarc ACR has Microsoft-compliant security scanning (SDL, container scanning). Pin to image digest rather than tag for supply chain integrity.

---

## 10. Recommendations

### Priority 1 — Immediate (P0)

| # | Recommendation | Finding |
|---|---------------|---------|
| 1 | Implement certificate cache eviction in `DsmsClient.cs` | WORF-HIGH-04 |
| 2 | Add authentication/network policies to WireServer File Proxy | WORF-HIGH-03 |
| 3 | Remove hardcoded CORP OID from MockAuthenticationHandler | WORF-HIGH-01 |

### Priority 2 — Short-Term (P1, 1-2 Sprints)

| # | Recommendation | Finding |
|---|---------------|---------|
| 4 | Restrict file permissions on injected certificates in `/dev/shm/dsms/` | WORF-CRITICAL-01 |
| 5 | Automate Node MSI → AKV role assignment (or migrate to dSMS) | WORF-MEDIUM-01 |
| 6 | Migrate remaining v2 clusters to dSMS certificate path | WORF-MEDIUM-03 |
| 7 | Create RBAC bindings for MP SP in v2 clusters | WORF-MEDIUM-06 |

### Priority 3 — Medium-Term (P2, 1-3 Months)

| # | Recommendation | Finding |
|---|---------------|---------|
| 8 | Implement dSTS OBO flow for tenant isolation in k8s API | WORF-HIGH-02 |
| 9 | Resolve self-signed CA pattern for OSS components | WORF-MEDIUM-05 |
| 10 | Investigate Azure Private Link for SAW access to SU API | WORF-MEDIUM-04 |
| 11 | Pin Skylarcagent base image to digest | WORF-LOW-03 |

### Priority 4 — Strategic (P3)

| # | Recommendation | Finding |
|---|---------------|---------|
| 12 | Implement dSTS User OBO flow (end-state for deployment auth) | WORF-HIGH-02 |
| 13 | Add NetworkPolicy resources to all celestial namespaces | General |
| 14 | Implement pod-level mTLS for internal service communication | General |

---

## Appendix: Files Analyzed

### ADRs
- `/docs/adr/0002-imds-exception-for-sec.md` — IMDS exception for SEC
- `/docs/adr/0003-use-platform-mananaged-certs-for-partners.md` — Platform-managed certs
- `/docs/adr/0007-in-cluster-tls-certificate-management.md` — In-cluster TLS
- `/docs/adr/0010-vmss-identity-dsms-certificate-and-dsts-sci-creation.md` — VMSS identity automation
- `/docs/adr/0011-wireserver-file-proxy.md` — WireServer proxy

### Auth Documentation
- `/docs/management-plane/MP-authn-authz.md` — Full auth/authz documentation

### Source Code (C#)
- `/src/csharp/fleet-manager/ManagementPlane/Program.cs`
- `/src/csharp/fleet-manager/ManagementPlane/Auth/MockAuthenticationHandler.cs`
- `/src/csharp/fleet-manager/ManagementPlane/Auth/AuthorizationPoliciesConstants.cs`
- `/src/csharp/fleet-manager/ManagementPlane/Apis/Ev2/Authorization/Handlers/EntraTenantAuthorizationHandler.cs`
- `/src/csharp/fleet-manager/ManagementPlane/Apis/Ev2/Authorization/Handlers/DstsTenantAuthorizationHandler.cs`
- `/src/csharp/fleet-manager/ManagementPlane/Apis/Ev2/Authorization/Handlers/ScaleUnitNameExtractor.cs`
- `/src/csharp/fleet-manager/ManagementPlane/Apis/Ev2/Authorization/Requirements/TenantAuthorizationRequirement.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/DsmsBootstrapService.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/DsmsClient.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/DstsInformationProvider.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/CertificateProvider.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/KeyGuardValidationService.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/LinuxCertificateInjector.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Services/ExternalDsmsClient.cs`
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Models/DstsAppInfo.cs`
- `/src/csharp/fleet-manager/DsmsNativeBootstrapper/Bootstrapper.cs`
- `/src/csharp/fleet-manager/DsmsNativeBootstrapper/AcmsManager.cs`
- `/src/csharp/fleet-manager/DsmsNativeBootstrapper/AcmsManagerForLinux.cs`
- `/src/csharp/fleet-manager/DsmsNativeBootstrapper/CertificateManager.cs`
- `/src/csharp/fleet-manager/WireServerFileProxy/Program.cs`
- `/src/csharp/fleet-manager/WireServerFileProxy/Services/FileProxyService.cs`
- `/src/csharp/fleet-manager/WireServerFileProxy/Configuration/WireServerProxyOptions.cs`
- `/src/csharp/fleet-manager/ResourceProvider/AzureClient/AzureClientProvider.cs`
- `/src/csharp/fleet-manager/ResourceProvider/AzureClient/AzureKeyVaultResourceProvider.cs`
- `/src/csharp/fleet-manager/ResourceProvider/AzureClient/AzureSecretsRoleAssignmentClient.cs`
- `/src/csharp/fleet-manager/ResourceProvider/AzureClient/SecretRolesConfiguration.cs`
- `/src/csharp/fleet-manager/ResourceProvider/AzureClient/UserAssignedIdentityResourceProvider.cs`

### Helm Charts
- `/src/helm/charts/celestial/templates/deployment.yaml`
- `/src/helm/charts/celestial/templates/service.yaml`
- `/src/helm/charts/celestial/templates/pdb.yaml`
- `/src/helm/charts/celestial/templates/_helpers.tpl`
- `/src/helm/charts/keyvaultwatcher/templates/kvw-deployment.yaml`
- `/src/helm/charts/keyvaultwatcher/templates/kvw-configmap.yaml`
- `/src/helm/charts/keyvaultwatcher/values.yaml`

### Dockerfiles
- `/src/csharp/fleet-manager/DsmsBootstrapNodeService/Dockerfile.linux`
- `/src/csharp/fleet-manager/DsmsNativeBootstrapper/Dockerfile`
- `/src/csharp/fleet-manager/WireServerFileProxy/Dockerfile.linux`
- `/docker/node-problem-detector/linux/Dockerfile`
- `/docker/skylarcagent/windows/Dockerfile`

### EV2 Configuration
- `/src/ev2/extensions/MPExtensionManifest-PROD.json`
- `/src/ev2/extensions/MPExtensionManifest-TEST.json`
- `/ev2/management-plane/ServiceGroupRoot/ServiceModel.json`
- `/ev2/management-plane/ServiceGroupRoot/Parameters/Parameters.management-plane.json`
- `/ev2/management-plane/ServiceGroupRoot/ScopeBindings.dev.json`

### Security Scanning
- `/.gdn/global.gdnsuppress` — Empty (no suppressions)

---

*Report generated by Lieutenant Worf, Security & Cloud Expert*
*"Today IS a good day to audit." — Worf*
