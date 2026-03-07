# Azure Resource Provider Registration Guide

> **Author:** Seven (Research & Docs) — DK8S Squad  
> **Date:** 2026-03-08  
> **Context:** DK8S is building a Resource Provider (BasePlatformRP) and needs to complete ARM registration  
> **Sources:** EngineeringHub (RPaaS docs, ARM onboarding, API review workflow), Azure SDK docs, ADR 202 analysis  
> **Related:** Issue #11 — RP Registration Requirements

---

## Table of Contents

1. [Overview: What Is RP Registration?](#1-overview-what-is-rp-registration)
2. [RPaaS vs Custom RP vs RP Lite — Tradeoffs](#2-rpaas-vs-custom-rp-vs-rp-lite--tradeoffs)
3. [Complete Registration Process (Step by Step)](#3-complete-registration-process-step-by-step)
4. [ARM Manifest Requirements](#4-arm-manifest-requirements)
5. [API Specification & TypeSpec Requirements](#5-api-specification--typespec-requirements)
6. [API Versioning Requirements](#6-api-versioning-requirements)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [SDK Generation Requirements](#8-sdk-generation-requirements)
9. [Compliance & Security Requirements](#9-compliance--security-requirements)
10. [Testing & Validation Requirements](#10-testing--validation-requirements)
11. [Regional Deployment Requirements](#11-regional-deployment-requirements)
12. [Timeline Estimates by Phase](#12-timeline-estimates-by-phase)
13. [Common Pitfalls & How to Avoid Them](#13-common-pitfalls--how-to-avoid-them)
14. [DK8S-Specific Recommendations](#14-dk8s-specific-recommendations)
15. [Key Links & Contacts](#15-key-links--contacts)

---

## 1. Overview: What Is RP Registration?

Resource Provider Registration is the process of onboarding a Resource Provider to Azure Resource Manager (ARM). ARM is Azure's unified control plane — all Azure services are accessed through it.

**What you get after registration:**
- Resources appear in Azure Portal
- Native `az` CLI and PowerShell commands
- Bicep/ARM template support (Infrastructure as Code)
- Azure RBAC integration (PIM, Conditional Access, audit logs)
- Azure Policy governance (naming, tagging, region restrictions)
- Azure Activity Log for all operations
- Azure Cost Management integration
- Auto-generated SDKs in 7+ languages
- Discoverability via Azure Resource Graph

**What registration requires:**
- An ARM manifest defining your resource types, endpoints, and API versions
- REST API specifications in TypeSpec (preferred) or OpenAPI/Swagger
- ARM API review and sign-off
- Authentication setup (First Party App, service roles, certificates)
- Compliance with ARM REST API Guidelines and Resource Provider Contract (RPC)
- Testing and validation (certification test suite)

**Key concept:** ARM acts as a gateway. Customer requests flow through `management.azure.com` → ARM → your RP endpoint. ARM handles routing, authentication, RBAC, policy, and auditing; your RP handles business logic.

---

## 2. RPaaS vs Custom RP vs RP Lite — Tradeoffs

There are three main approaches to building an ARM Resource Provider:

### RPaaS (Resource Provider as a Service) — Managed

RPaaS (also called "RP Platform" or "ProviderHub") is a managed platform where ARM hosts a "MetaRP" layer between ARM and your service (called "UserRP").

**How it works:**
- MetaRP sits between ARM and your UserRP, handling ARM requests
- ServiceRP manages ProviderHub resources (onboarding new resource types)
- RPaaS provides globally replicated storage for resource metadata
- Your UserRP handles custom business logic only

**Advantages:**
| Benefit | Impact |
|---------|--------|
| Reduced infrastructure burden — ARM hosts control plane | High |
| Faster certification — pre-certified for ARM compliance | High |
| All ARM benefits (Portal, CLI, Bicep, RBAC, Policy) out of the box | High |
| Built-in logging, metrics, throttling, API validation | Medium |
| Lower ongoing maintenance | Medium |

**Disadvantages:**
| Drawback | Impact |
|----------|--------|
| Constrained to RPaaS patterns (callback/webhook architecture) | High |
| Complex business logic is harder (config inheritance, custom workflows) | High |
| Data-plane operations still need separate hosting | High |
| Dependency on RPaaS team for feature requests and bug fixes | Medium |
| Migration from existing architecture can be complex | High |

**Best for:** New services with simple CRUD semantics, teams wanting ARM integration with minimal infrastructure overhead.

### Custom RP (Direct/Unmanaged) — Self-Hosted

You register your RP with ARM, pass certification, and ARM routes control-plane traffic to your self-hosted service.

**Advantages:**
| Benefit | Impact |
|---------|--------|
| Full control over API behavior and infrastructure | High |
| All ARM benefits (Portal, CLI, Bicep, RBAC, Policy) | High |
| No RPaaS dependency for business logic | Medium |
| Can handle complex domain-specific workflows | High |

**Disadvantages:**
| Drawback | Impact |
|----------|--------|
| 4–6 month onboarding timeline (review, certification, SDK generation) | High |
| Ongoing compliance burden (API reviews, Swagger, SDK regeneration) | High |
| Must implement full ARM contract (LRO, pagination, subscription lifecycle) | High |
| Must host and scale infrastructure yourself | Medium |
| Exception required for brand new unmanaged RPs (fill form at aka.ms/RPaaSException) | Medium |

**Best for:** Services with complex business logic, established infrastructure, large external customer base.

### RP Lite — Read-Only via Azure Resource Graph (ARG)

RP Lite allows resource types that only support GET/LIST operations through Azure Resource Graph without implementing full CRUD.

**Best for:** Exposing inventory or read-only data to ARM/Portal without full RP implementation.

**Note:** No exception process required for RP Lite onboarding.

### Hybrid RP

A Hybrid RP has some resource types managed by RPaaS and others managed directly. Uses `kind: "Hybrid"` in the registration.

**Best for:** Existing ARM RPs adding new managed resource types alongside existing direct types.

### Decision Framework for DK8S

Given DK8S's architecture (Kubernetes operators, Go-native, complex fleet management), the key question is whether BasePlatformRP's business logic fits RPaaS's callback model. Consider:

- If resource types have **simple CRUD** → RPaaS
- If resource types need **complex orchestration** (cluster provisioning, fleet scheduling) → Custom RP or Hybrid
- If you need **read-only exposure** of existing resources → RP Lite
- If you want to **start simple, expand later** → RPaaS for simple types + Hybrid for complex ones

---

## 3. Complete Registration Process (Step by Step)

### Phase 0: Prerequisites & Access (Week 1–2)

1. **Join GitHub organizations**
   - Join [Microsoft GitHub org](http://aka.ms/azuregithub)
   - Join [Azure GitHub org](http://aka.ms/azuregithub)
   - Join 'RP Platform Users' team for PR merge permissions

2. **Determine RP namespace**
   - Must follow `Microsoft.<ServiceName>` pattern
   - Get namespace approved early — changing it later is extremely painful

3. **Prepare ServiceTree metadata**
   - Service Tree ID for your service
   - PC Code (Profit Center Code)
   - Profit Center Program ID (numeric, e.g., "13082"; use "-1" if PC Code has no corresponding program)
   - IcM routing service and team names
   - Incident contact email

4. **Identify RP type** — Managed (RPaaS), Direct (Custom), Hybrid, or RP Lite

### Phase 1: API Design & Modeling (Week 2–4)

5. **Attend ARM API Modeling Office Hours** (required for new RPs)
   - Present your resource types, operations, and data model
   - Can use Word doc, PowerPoint, or TypeSpec/Swagger — spec is preferred but not required
   - Goal: Get guidance on correctly modeling your RP and resource types

6. **Define resource model in TypeSpec** (mandatory for new services since Jan 2024)
   ```typescript
   @armProviderNamespace
   @service({ title: "DK8S Platform" })
   namespace Microsoft.DK8S;
   ```
   - Define all resource types (tracked, proxy, extension)
   - Define all CRUD operations (GET, PUT, PATCH, DELETE, LIST)
   - All tracked resources **must** support tags update via PATCH
   - Implement both PUT and DELETE for all major resource types

7. **Determine resource type classifications**
   - **Tracked resources**: Have `location` and `tags` (e.g., clusters, fleets)
   - **Proxy resources**: No location, child of another resource (e.g., configurations)
   - **Extension resources**: Extend existing ARM resource types

### Phase 2: API Specification & Review (Week 4–8)

8. **Author TypeSpec/Swagger specification**
   - Create in `azure-rest-api-specs-pr` repo (private) for preview
   - The `readme.md` must contain `openapi-subtype: rpaas` tag
   - Place readme directly under the `resource-manager` folder

9. **Submit PR for API review**
   - First commit must be the base api-version (copy and paste as-is)
   - PR must contain API updates only — no refactors
   - Automation adds `WaitForARMFeedback` label
   - ARM reviewer reviews and comments

10. **Address feedback iteratively**
    - Use [ARM API Review Office Hours](https://aka.ms/armapireview) for discussions
    - Address all automated CI validations (Linter, Semantic, Breaking Change, Avocado)
    - Fix all RPC (Resource Provider Contract) errors

11. **Get ARM Sign-Off**
    - ARM reviewer adds `ARMSignedOff` label
    - TypeSpec PRs may qualify for automated sign-off (incremental changes, CI passes)

### Phase 3: RP Registration & Onboarding (Week 6–10)

12. **File RPaaS onboarding IcM** (for managed/hybrid RPs)
    - Provide: RP name, subscription ID, Swagger spec URL, environment, ServiceTree info
    - RPaaS DRI creates RP mapping via Geneva Action

13. **Register your RP** — Use API or Azure CLI:

    **For Managed RP:**
    ```bash
    az providerhub provider-registration create \
      --provider-namespace "Microsoft.DK8S" \
      --service-tree-infos service-id="{serviceId}" component-id="{componentId}" \
      --pc-code "{pcCode}" --pc-program-id "{profitCenterProgramId}"
    ```

    **For Direct RP:**
    ```bash
    az providerhub provider-registration create \
      --provider-namespace "Microsoft.DK8S" --kind "Direct" \
      --service-tree-infos service-id="{serviceId}" component-id="{componentId}"
    ```

    **For Hybrid RP:**
    ```bash
    az providerhub provider-registration create \
      --provider-namespace "Microsoft.DK8S" --kind "Hybrid" \
      --service-tree-infos service-id="{serviceId}" component-id="{componentId}" \
      --pc-code "{pcCode}" --pc-program-id "{profitCenterProgramId}"
    ```

14. **Deploy manifest to Dogfood first** (no DRI approval needed for Dogfood)
    - Use Geneva Actions for manifest deployment
    - First deployment requires RP API Review team approval

### Phase 4: Implementation & Certification (Week 8–16)

15. **Implement required ARM contracts:**
    - **Long-Running Operations (LRO)**: Azure-AsyncOperation polling pattern
    - **Pagination**: `nextLink`-based paged results for all LIST endpoints
    - **Subscription lifecycle callbacks**: Handle register/unregister and state changes
    - **Resource move support**: Cross-RG and cross-subscription (complex for hierarchical resources)
    - **Operations API**: List all available operations for your RP
    - **API version middleware**: Strict API versioning

16. **Implement authentication:**
    - Create First Party App registration
    - Configure service roles with minimum required permissions
    - Generate certificates (OneCert recommended)
    - Implement token validation for incoming requests

17. **Run ARM certification tests**
    - Pass the full certification test suite
    - Fix all errors or get suppressions approved

### Phase 5: Production Onboarding (Week 14–20)

18. **Deploy to production behind feature flag**
    - Can onboard to production before all errors are fixed
    - Feature flag must remain until all errors resolved

19. **Merge API spec to public repo**
    - Submit PR to `azure-rest-api-specs` (public, main branch)
    - Include link to signed-off private repo PR
    - Final merge is self-serve

20. **SDK generation and release**
    - SDKs auto-generated after public PR merge
    - Follow [Azure SDK Release Guidance](https://aka.ms/azsdk/release)

21. **Remove feature flag** — GA readiness
    - All RPC errors must be fixed
    - All SDK issues resolved
    - Full CRUD regression tests passing

---

## 4. ARM Manifest Requirements

The ARM manifest defines your RP's configuration in ARM. Key sections:

### Top-Level Properties

| Property | Description | Required |
|----------|-------------|----------|
| `namespace` | Your RP namespace (e.g., `Microsoft.DK8S`) | Yes |
| `providerAuthentication` | Allowed audiences for token validation | Yes |
| `providerAuthorizations` | App IDs, role definitions, extensions | Yes |
| `providerType` | `Internal`, `Hidden`, `Internal,Hidden`, etc. | Yes |
| `providerVersion` | Manifest version | Yes |
| `resourceTypes` | Array of resource type definitions | Yes |
| `globalNotificationEndpoints` | Endpoints for global notifications | Recommended |
| `RequestHeaderOptions` | Opt-in headers (signed tokens, group memberships) | Recommended |

### Resource Type Properties

Each resource type in `resourceTypes[]` requires:

| Property | Description |
|----------|-------------|
| `name` | Resource type name (e.g., `clusters`) |
| `endpoints` | Array of endpoint URIs with locations, API versions, timeouts |
| `apiVersions` / `commonApiVersions` | Supported API versions |
| `routingType` | How ARM routes requests (`Default`, `ProxyOnly`, `Extension`, etc.) |
| `serviceTreeInfos` | Service Tree ID and component ID for this resource type |
| `subscriptionStateRules` | Actions allowed in disabled/warned subscription states |
| `throttlingRules` | Rate limiting configuration |

### Endpoint Configuration

```json
{
  "endpointUri": "https://eastus.dk8s.azure.com/",
  "locations": ["East US", "East US 2"],
  "apiVersions": ["2025-01-01", "2025-01-01-preview"],
  "timeout": "PT20S",
  "endpointType": "Production",
  "requiredFeatures": ["Microsoft.Resources/EUAPParticipation"],
  "featuresRule": {
    "requiredFeaturesPolicy": "All"
  }
}
```

**Critical rules:**
- Canary regions MUST be hidden behind the `Microsoft.Resources/EUAPParticipation` AFEC flag
- Each endpoint must specify timeout (default PT20S)
- Separate endpoints for production vs. canary
- RPs must support the same API versions across their types

---

## 5. API Specification & TypeSpec Requirements

### TypeSpec is Mandatory for New Services (since January 2024)

TypeSpec (formerly CADL) is the required format for defining REST API specs. Benefits:
- Automated ARM sign-off for qualifying PRs
- Streamlined review process
- Design-first approach catches flaws early
- API validation enforcement during CRUD operations

### Required API Operations

All RPs must implement:

| Operation | HTTP Method | Description |
|-----------|-------------|-------------|
| Create/Update | PUT | Full resource creation/update |
| Read | GET | Single resource retrieval |
| Delete | DELETE | Resource deletion |
| List by RG | GET | List resources in a resource group |
| List by Subscription | GET | List resources in a subscription |
| Update Tags | PATCH | Update tags (required for tracked resources) |
| List Operations | GET | List all RP operations |

### Spec Repository Workflow

| Environment | Repo / Branch | Requirements |
|-------------|---------------|--------------|
| Dogfood | `RPSaaSDev` or `RPSaaSMaster` (private) | No version requirements |
| Canary (limited) | `RPSaaSMaster` (private) behind AFEC | GA and preview versions |
| Canary (all) | `Main` (public) | At least one endpoint not behind AFEC |
| Production (limited) | `RPSaaSMaster` (private) behind AFEC | GA and preview versions |
| Production (all) | `Main` (public) | At least one endpoint not behind AFEC |

### API Review Sign-Off

- **Automated sign-off** for TypeSpec PRs that are incremental, target qualified branches, pass CI, and have no unapproved suppressions
- **Manual review** for Swagger PRs, first-time PRs, TypeSpec conversion PRs
- ARM reviewer adds `ARMSignedOff` label when approved

---

## 6. API Versioning Requirements

### Versioning Rules

- Every API must specify a version in the format `YYYY-MM-DD` or `YYYY-MM-DD-preview`
- Preview versions: `2025-01-01-preview` — used during development/testing
- GA versions: `2025-01-01` — stable, long-term support
- Breaking changes require a new API version with deprecation notices
- Breaking changes MUST be avoided whenever possible

### API Deprecation Policy

- Minimum 12-month notification before removing a GA API version
- Preview APIs have shorter deprecation windows but still require notice
- Each version must have at least one publicly exposed endpoint not behind AFEC before it can be published to the public spec repo

### Best Practices

- Start with a `-preview` API version during development
- Use `commonApiVersions` at the resource type level for versions shared across all endpoints
- Maintain backwards compatibility — additive changes only within a version
- Follow the [Microsoft Azure REST API Guidelines](https://aka.ms/api-guidelines)
- Breaking changes require explicit [Breaking Changes Policy](https://aka.ms/breaking-changes) approval

---

## 7. Authentication & Authorization

### First Party App Registration

Your RP needs a First Party (1P) application registered in the Microsoft Services infrastructure tenant (`f8cdef31-a31e-4b4a-93e4-5f571e91255a`). This is the main identity of your RP.

**Recommended:** Configure the 1P app to support cred-free authentication using MSI Federated Identity Credentials (FIC).

**Legacy (not recommended):** Configure Subject Name and Issuer (SNI) authentication with certificates.

### Where the 1P App ID Goes

1. **`providerAuthentication.allowedAudiences`** — Requires MetaRP to attach a token validated by your 1P app on all requests (secures your API)
2. **`providerAuthorizations[].applicationId`** — Determines how your RP interacts with customer subscriptions

### Service Roles

A service role defines what your RP is allowed to do in customer subscriptions after they register your RP. Important rules:

- Add **minimum required permissions only** — service roles are powerful
- To add actions from other RPs (e.g., `Microsoft.Resources/deployments/read`), get permission from that service team
- Standard actions to include:
  ```json
  {
    "Actions": [
      "Microsoft.YourRP/Locations/OperationStatuses/read",
      "Microsoft.YourRP/Locations/OperationStatuses/write",
      "Microsoft.YourRP/your_resource/read",
      "Microsoft.YourRP/your_resource/delete",
      "Microsoft.YourRP/your_resource/write"
    ]
  }
  ```

### Authentication Flow

1. Customer registers your RP → service principal created in customer's tenant
2. Service principal granted permissions from your service role at subscription scope
3. At runtime: RP uses 1P app + cert/MSI to get token for customer subscription
4. Token requests should target **regional AAD endpoints** (e.g., `uksouth.login.microsoft.com`) to reduce latency

### Authentication Checklist

- [ ] Create security group for your team
- [ ] Create First Party app registration
- [ ] Configure 1P app for MSI FIC or SNI authentication
- [ ] Raise ICM to allowlist app ID with RP Platform (or use Authorized Applications API)
- [ ] Create service role with minimum permissions
- [ ] Add app registration and service role to RP registration
- [ ] Generate certificate in KeyVault (if not using MSI)
- [ ] Update code to validate bearer tokens on incoming requests
- [ ] Update code to use token for calling other APIs (ARM, MetaRP)

---

## 8. SDK Generation Requirements

### Automatic SDK Generation

Once your API spec is merged to the **public** `azure-rest-api-specs` repo:
- SDKs are auto-generated in 7+ languages: .NET, Python, Java, Go, JavaScript, Ruby, etc.
- Follow [Azure SDK Release Guidance](https://aka.ms/azsdk/release)

### Prerequisites for SDK Generation

1. **Public API spec** — Must be merged to `Main` branch of public spec repo
2. **ARM Sign-Off** — `ARMSignedOff` label on the PR
3. **SDK breaking change approval** — Required if SDK has breaking changes
4. **Onboard to Azure SDK team** — Register at the SDK onboarding portal

### SDK Quality Requirements

- All critical SDK issues must be fixed before feature flag removal
- Azure SDK breaking changes need approval from Azure SDK reviewers
- SDK regeneration is required whenever the API spec changes

---

## 9. Compliance & Security Requirements

### Mandatory Compliance

| Requirement | Description |
|-------------|-------------|
| **ARM RPC Compliance** | All APIs must comply with the [Resource Provider Contract](https://aka.ms/rpc) |
| **REST API Guidelines** | Follow [Microsoft Azure REST API Guidelines](https://aka.ms/api-guidelines) |
| **Safe Deployment Practices (SDP)** | All production deployments must follow SDP |
| **ServiceTree Registration** | Service must be registered in ServiceTree with valid PC Code |
| **IcM Integration** | Must have IcM routing configured for incident management |
| **Cross-Cloud Consistency** | If deploying to sovereign clouds, maintain consistent security baseline |

### Security Requirements

| Requirement | Description |
|-------------|-------------|
| **Token Validation** | All incoming API requests must have bearer-token validation |
| **Regional AAD Endpoints** | Use regional ESTS endpoints to reduce latency and decoupling |
| **Minimum Permissions** | Service roles must use minimum required permissions |
| **Certificate Rotation** | Implement automated certificate lifecycle management |
| **Network Security** | Default-deny network policies recommended |
| **Data Residency** | Respect regional data residency requirements for sovereign clouds |

### Sovereign Cloud Requirements

- **Mooncake (China)**: Follow the standard onboarding process (supported since May 2025)
- **Fairfax (US Gov)**: Follow the standard onboarding process (supported since May 2025)
- **Air-Gapped Clouds (USSec/USNat)**: File IcM to Resource Provider Service as a Service / RPaaS within those clouds. Contact AGC team: `tm-agc-rpaas@microsoft.com`
- **Bleu/Delos**: Follow specific cloud onboarding TSGs

---

## 10. Testing & Validation Requirements

### API Spec Validation (Pre-Merge)

Run locally before submitting PR:
1. **Linter Validation** — Style and convention checks
2. **Semantic Validation** — Structural correctness
3. **Breaking Change Validation** — Detect breaking changes vs. base version
4. **Model Validation** — Schema consistency
5. **Avocado** — Azure validation tool for OpenAPI
6. **Spell Check** — Documentation quality
7. **Prettier** — Formatting consistency

### ARM Certification Tests

- Must pass the full ARM certification test suite
- Test CRUD operations with API validation enabled
- RPaaS uses an API validation sidecar service in Kubernetes environments

### Deployment Validation

- **Dogfood first**: All changes must be validated in Dogfood before production
- **Canary deployment**: Test in canary regions before wide rollout
- **Spec changes are NOT covered by SDP**: They become globally available after refresh (~15 min Dogfood, ~30 min Production)
- **Regression tests**: Run full CRUD regression tests before merging spec changes
- **Rollback strategy**: Have a plan before merging specification changes

### Ongoing Testing

- Monitor API validation service for CRUD enforcement issues
- Validate Swagger/TypeSpec specs match actual implementation
- Test subscription lifecycle (register/unregister) flows
- Test feature flag gating works correctly

---

## 11. Regional Deployment Requirements

### Endpoint Configuration

- Define separate endpoints for each Azure region where your RP operates
- Each endpoint specifies: URI, locations, API versions, timeout, required features
- Canary regions (EUAP) **must** be behind `Microsoft.Resources/EUAPParticipation` AFEC flag

### Safe Deployment Practices (SDP)

ARM manifest deployment follows SDP for ring-based rollout:
1. **Dogfood** — Internal testing environment (self-serve, no approval needed)
2. **Canary** — Limited production subscriptions behind AFEC
3. **Production (limited)** — Behind feature flag
4. **Production (all)** — GA, feature flag removed

### Manifest Deployment

- First deployment to any ARM region requires RP API Review team approval
- Subsequent updates are self-service via Geneva Actions
- Separate manifests for each environment (Dogfood, Canary, Production)
- Manifest changes must be checked in and rolled out through the manifest repo

### Multi-Cloud Deployment

| Cloud | Process |
|-------|---------|
| Public (Prod) | Standard RPaaS onboarding |
| Mooncake (China) | Standard process (since May 2025) |
| Fairfax (US Gov) | Standard process (since May 2025) |
| USSec/USNat (AGC) | File IcM in those clouds; contact `tm-agc-rpaas@microsoft.com` |
| Bleu | Follow [Bleu onboarding TSG](https://eng.ms/docs/products/arm/rpaas/tsg/rpaas/partnericmtsgs/bleuonboardingtsg) |
| Delos | Follow [Delos onboarding TSG](https://eng.ms/docs/products/arm/rpaas/tsg/rpaas/partnericmtsgs/delosonboardingtsg) |

---

## 12. Timeline Estimates by Phase

### Optimistic Timeline (RPaaS, simple CRUD)

| Phase | Duration | Key Activities |
|-------|----------|----------------|
| **Phase 0: Prerequisites** | 1–2 weeks | GitHub access, ServiceTree setup, namespace selection |
| **Phase 1: API Design** | 2–3 weeks | ARM modeling office hours, TypeSpec authoring |
| **Phase 2: API Review** | 2–4 weeks | PR submission, CI validation, ARM reviewer feedback |
| **Phase 3: Registration** | 1–2 weeks | IcM filing, RP mapping, registration PUT |
| **Phase 4: Implementation** | 4–6 weeks | LRO, pagination, auth, subscription lifecycle |
| **Phase 5: Certification** | 2–4 weeks | ARM certification tests, error fixes |
| **Phase 6: Production** | 2–3 weeks | Feature flag deployment, SDK generation |
| **Total** | **~14–24 weeks** | |

### Realistic Timeline (Custom RP, complex domain)

| Phase | Duration | Key Activities |
|-------|----------|----------------|
| **Phase 0: Prerequisites** | 1–2 weeks | As above |
| **Phase 1: API Design** | 3–5 weeks | Complex resource modeling, multi-type hierarchy |
| **Phase 2: API Review** | 4–8 weeks | Multiple review iterations, breaking change discussions |
| **Phase 3: Registration** | 2–3 weeks | Exception process for direct RPs, mapping |
| **Phase 4: Implementation** | 8–12 weeks | Full ARM contract, auth, complex LRO |
| **Phase 5: Certification** | 4–6 weeks | Certification + error/suppression cycles |
| **Phase 6: Production** | 3–4 weeks | Staged rollout, SDK validation |
| **Total** | **~25–40 weeks (6–10 months)** | |

### Cloud Simulator ADR 202 Estimates (Reference Point)

The Cloud Simulator team documented these engineering estimates for full ARM RP onboarding:

| Work Item | Estimate |
|-----------|----------|
| Swagger/TypeSpec spec authoring | 2–4 weeks |
| LRO implementation | 2–3 weeks |
| Pagination (nextLink) | 1 week |
| Subscription lifecycle callbacks | 1 week |
| Resource move support | 2–3 weeks |
| ARM certification test fixes | 2–4 weeks |
| ARM team review cycles (external dependency) | 4–6 weeks |
| SDK validation and samples | 1–2 weeks |
| Portal blade (custom UX) | 4–8 weeks |
| **Total** | **4–6 months** |

---

## 13. Common Pitfalls & How to Avoid Them

### 1. Changing RP Namespace Late

**Problem:** Namespace changes after registration are extremely painful — all API specs, SDKs, ARM templates, and Portal references break.

**Mitigation:** Get namespace approved in Phase 0 during ARM modeling office hours. Consider future expansion.

### 2. API Spec PR Contains Non-API Changes

**Problem:** Including refactors, file reorganization, or non-API changes in the spec PR causes review delays because reviewers must review every file.

**Mitigation:** Submit API-only changes. Refactors go in separate PRs.

### 3. Missing Base Version First Commit

**Problem:** Not copying the base api-version as the first commit in the PR. Reviewers can't compare iterations.

**Mitigation:** Copy base api-version contents as-is as your very first commit. Create a draft PR at this point.

### 4. Enabling Gating Too Early

**Problem:** Feature flags or gating mechanisms enabled before thorough testing causes customer impact.

**Mitigation:** Use monitoring-only mode first. Graduate to gating only after 30+ days of zero false positives.

### 5. Not Using Regional AAD Endpoints

**Problem:** Using global AAD endpoints creates latency and cross-region failure coupling.

**Mitigation:** Direct token requests to regional ESTS endpoints (e.g., `uksouth.login.microsoft.com`).

### 6. Service Role Permission Creep

**Problem:** Adding too many permissions to the service role, which has access to customer subscriptions.

**Mitigation:** Follow principle of minimum permissions. Each cross-RP action requires that team's approval.

### 7. Swagger/TypeSpec Spec Drift

**Problem:** API spec drifts from actual implementation, causing API validation failures at runtime.

**Mitigation:** Spec changes become globally available after 15–30 minutes and are NOT covered by SDP. Run full CRUD regression tests before merging. Have a rollback strategy.

### 8. Breaking Changes Without Versioning

**Problem:** Making breaking changes within an existing API version.

**Mitigation:** Breaking changes MUST create a new API version. Follow the [Breaking Changes Policy](https://aka.ms/breaking-changes). Minimum 12-month deprecation notice for GA versions.

### 9. Sovereign Cloud Differences

**Problem:** Assuming public cloud onboarding process works for sovereign clouds.

**Mitigation:** Since May 2025, Mooncake and Fairfax follow the standard process. AGC clouds (USSec/USNat) require separate IcM filing. Bleu and Delos have dedicated TSGs.

### 10. Ignoring the OBO Subscription

**Problem:** On-behalf-of (OBO) subscription not provisioned correctly, blocking RP operations.

**Mitigation:** Since May 2024, OBO subscription is created automatically during RP registration when PC Code and Program ID are provided. Validate this happened.

---

## 14. DK8S-Specific Recommendations

Based on DK8S's architecture (Kubernetes operators, Go-native, fleet management, complex orchestration):

### Recommended Approach: Hybrid RP

1. **Start with RPaaS for simple resource types** — Resource types with straightforward CRUD (e.g., cluster definitions, configuration profiles)
2. **Use Direct RP for complex orchestration** — Resource types requiring complex workflows (fleet scheduling, scale unit management)
3. **RP Lite for inventory exposure** — Expose existing cluster inventory as read-only ARM resources

### Key Considerations

- **Go vs .NET tension**: RPaaS controller generation is .NET-based (`@azure-tools/typespec-providerhub-controller`). DK8S is Go-native. Consider:
  - Go SDK for ARM (`Azure/azure-sdk-for-go`) for direct RP implementation
  - .NET thin layer for RPaaS callbacks that delegates to Go services
  
- **Kubernetes integration**: ARM manages control-plane operations; Kubernetes operators handle data-plane. Clear separation is critical.

- **Multi-cloud**: DK8S operates across public + sovereign clouds. Plan sovereign cloud registration early (not as an afterthought).

- **ConfigGen alignment**: Ensure RP manifest API versions align with ConfigGen configuration templates.

### BasePlatformRP Gap Analysis

The existing dk8s-platform-knowledge.md identifies 22 gaps in BasePlatformRP. This registration guide provides the framework to close those gaps systematically.

---

## 15. Key Links & Contacts

### Documentation

| Resource | URL |
|----------|-----|
| RP Platform Overview | https://eng.ms/docs/products/arm/rpaas/overview |
| RP Registration (ARM) | https://eng.ms/docs/products/arm/rp_onboarding/resourceproviderregistration |
| API Review Workflow | https://eng.ms/docs/products/arm/rp_onboarding/process/api_review |
| REST API Specifications | https://eng.ms/docs/products/arm/rpaas/swaggeronboarding |
| How Auth Works | https://eng.ms/docs/products/arm/rpaas/development_guides/how_auth_works |
| RPaaS Dogfood Guide | https://eng.ms/docs/products/arm/rp_onboarding/rpaasmicrosoftdogfooduserguide |
| RP Onboarding Roadmap | [Start Here deck](https://eng.ms/docs/products/arm/rpaas/overview) |
| Onboarding New RP TSG | https://eng.ms/docs/products/arm/rpaas/tsg/rpaas/partnericmtsgs/onboardingrpnewtsg |
| ADR 202 (Pseudo vs Real RP) | https://eng.ms/docs/cloud-ai-platform/microsoft-specialized-clouds-msc/cai-silver/ssocto-silver/cloud-simulator/internal-docs/adr/resource-provider/202-pseudo-rp-vs-real-arm-rp |

### Specifications

| Resource | URL |
|----------|-----|
| TypeSpec Getting Started | https://azure.github.io/typespec-azure/docs/getstarted/azure-resource-manager/step01/ |
| ARM Resource Operations | https://azure.github.io/typespec-azure/docs/howtos/arm/resource-operations/ |
| Public Spec Repo | https://github.com/Azure/azure-rest-api-specs |
| Private Spec Repo | https://github.com/Azure/azure-rest-api-specs-pr |
| ProviderHub NuGet | https://www.nuget.org/packages/Azure.ResourceManager.ProviderHub/ |
| ProviderHub Controller (npm) | https://www.npmjs.com/package/@azure-tools/typespec-providerhub-controller |
| ARM Schema Repo | https://github.com/Azure/azure-resource-manager-schemas |

### Contacts

| Team | Contact |
|------|---------|
| ARM API Review | armapireview@microsoft.com |
| RPaaS DRI | File IcM to "Resource Provider Service as a Service / RPaaS" |
| ARM Release Manager | armreleaseoncall@microsoft.com |
| AGC RPaaS Team | tm-agc-rpaas@microsoft.com |
| RPaaS Exception | https://aka.ms/RPaaSException |
| ARM API Modeling Office Hours | Book at https://aka.ms/armapireview |

---

*This guide synthesizes information from ARM/RPaaS internal documentation (EngineeringHub), Azure SDK public docs, and the Cloud Simulator ADR 202 decision record. For the most current information, always check the linked EngineeringHub pages.*
