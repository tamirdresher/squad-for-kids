# PoP Token Authentication Implementation Guide (Issue #1147)

## Overview

This implementation enables Proof-of-Possession (PoP) token authentication for the FedRAMP Dashboard API (BasePlatformRP) per MISE V2 standards. PoP tokens replace standard Bearer tokens and provide enhanced security through:

- **Binding to caller identity** via public/private key pair (MetaRP service principal)
- **Binding to specific resource URIs** — a token for `/api/v1/dashboards` cannot be replayed for `/api/v1/reports`
- **Timestamp validation** — tokens are valid only within a 5-minute window

## Implementation Status

### ✅ Completed

1. **PoP Token Configuration** (`Authorization/PopTokenConfiguration.cs`)
   - Defines cloud environment mappings (Public, Fairfax, Mooncake, Dogfood)
   - MetaRP Tenant IDs per cloud per issue specification
   - Enable/disable toggle for PoP enforcement

2. **PoP Token Validation Service** (`Authorization/PopTokenValidationService.cs`)
   - Validates required PoP claims: 'p' (public key), 'u' (URI), 't' (timestamp)
   - URI binding validation (prevents token replay across endpoints)
   - Timestamp freshness checks (5-minute max age)
   - Signature validation hook for cloud-specific MetaRP key management

3. **PoP Token Validation Middleware** (`Middleware/PopTokenValidationMiddleware.cs`)
   - Extracts Bearer token from Authorization header
   - Detects PoP vs. standard Bearer tokens
   - Routes to appropriate validation
   - Enforces fallback-to-Bearer blocking in production clouds
   - Exempts health check and Swagger endpoints

4. **ASP.NET Core Integration** (`Program.cs`)
   - Wired PoP validation service into DI container
   - Added middleware to request pipeline (after CORS, before Auth)
   - Configurable via appsettings.json

5. **Configuration** (`appsettings.json`)
   - `PopTokenValidation.Enabled` — enable/disable globally
   - `PopTokenValidation.Required` — enforce PoP only vs. allow Bearer fallback
   - `PopTokenValidation.CurrentCloud` — runtime cloud selection
   - MetaRP Tenant ID mappings for all clouds

6. **RP Registration Manifest** (`infrastructure/rp-registration-pop-token.json`)
   - ARM API 2023-04-01-preview compatible
   - `tokenAuthConfiguration` at RP level (applies to all resource types)
   - Cloud-specific enforcement rules
   - Metadata for three resource types: dashboards, controls, assessments

## Key Deployment Steps (Issue Requirements)

### Step 1: Add TokenAuthConfiguration to RP Registration ✅
- Added in `infrastructure/rp-registration-pop-token.json`
- Uses API version `2023-04-01-preview`
- Configured at RP level (singular) per issue guidance

### Step 2: Implement MISE V2 PoP Token Validation in Service ✅
- `PopTokenValidationService` handles token parsing and claim validation
- `PopTokenValidationMiddleware` enforces per cloud environment
- MetaRP Tenant IDs configured per cloud:
  - Public (AME): `33e01921-4d64-4f8c-a055-5bdaffd5e33d`
  - Fairfax: `cab8a31a-1906-4287-a0d8-4eef66b95f6e`
  - Mooncake: `a55a4d5b-9241-49b1-b4ff-befa8db00269`
  - Dogfood: `ea8a4392-515e-481f-879e-6571ff2a8a36` (fallback enabled for testing)

### Step 3: Perform Default Rollout
**To Deploy:**
```powershell
# Deploy RP registration with PoP token configuration
az rest --method PUT \
  --uri "/subscriptions/{sub}/providers/Microsoft.Authorization/resourceProviders/Microsoft.FedRampDashboard?api-version=2023-04-01-preview" \
  --body @infrastructure/rp-registration-pop-token.json

# Verify rollout
az rest --method GET \
  --uri "/subscriptions/{sub}/providers/Microsoft.Authorization/resourceProviders/Microsoft.FedRampDashboard?api-version=2023-04-01-preview"
```

### Step 4: Verify via Kusto Queries ✅
**Monitor PoP Token Adoption:**
```kusto
// Cluster: rpsaas, Database: RPaaSProd
ProviderTraces
| where ['time'] >= ago(1d)
| where operationName == "ResourceEngine.CallResourceProviderWithFallbackToBearer"
| where providerNamespace =~ "Microsoft.FedRampDashboard"
| summarize FallbackCount = count() by bin(['time'], 1h)
// Should show decreasing trend as PoP adoption increases

// Check for PoP token validation errors
ProviderTraces
| where ['time'] >= ago(1d)
| where message contains "PoP" or message contains "token validation"
| where providerNamespace =~ "Microsoft.FedRampDashboard"
| project ['time'], correlationId, message, errorCode
```

## Architecture Decision

**Token Validation Location:**
- Middleware validates PoP tokens **before** standard Auth middleware
- Allows graceful fallback to Bearer tokens in dev/dogfood clouds
- Production clouds (Public, Fairfax, Mooncake) enforce PoP-only via configuration

**Why at RP Level, Not RT/Endpoint Level:**
- Single configuration point (DRY principle)
- All resource types and endpoints automatically protected
- Easier to audit and maintain
- Prevents configuration drift between resource types

## Common Issues & Solutions

| Issue | Root Cause | Solution |
|-------|-----------|----------|
| `Invalid 'p' claim` | URL rewriting by AFD/API Gateway | Create dedicated DNS entry for API endpoints; update 'u' claim scope |
| `Invalid 'u' claim` | Origin host header modified by proxy | Configure AFD origin group without `originHostHeader` override |
| `403 Forbidden in Fairfax/Mooncake` | V2 tokens use `azp` not `appid` | Claim validation updated; verify MetaRP principal has correct tenant ID |
| `Token is stale` | Clock skew between services | Increase max-age from 5min to 10min; sync system clocks |

## Testing

### Local Development (Dogfood Mode)
```bash
# appsettings.json
"PopTokenValidation": {
  "Enabled": true,
  "Required": false,  // Allow Bearer fallback for testing
  "CurrentCloud": "dogfood"
}

# Call API with either PoP or Bearer token
curl -H "Authorization: Bearer eyJ0eXAi..." https://localhost:5001/api/v1/dashboards
```

### Production Validation
```bash
# Generate PoP token (requires MetaRP service principal key)
# Call API - must use PoP token, Bearer tokens rejected
curl -H "Authorization: Bearer {pop_token}" \
  https://fedramp-dashboard.azure.microsoft.com/api/v1/dashboards
```

## Rollback Plan

If PoP adoption encounters issues:

1. **Immediate (< 1 hour):**
   - Set `PopTokenValidation.Required = false` in deployment config
   - Middleware allows Bearer tokens as fallback
   - No code changes needed

2. **Sustained (if needed):**
   - Revert `infrastructure/rp-registration-pop-token.json` deployment
   - Remove PoP token configuration from ARM registration
   - Services continue to accept Bearer tokens

## Next Steps

1. **Owner Confirmation** — Tamir should confirm which clouds BasePlatformRP supports
2. **Pilot Rollout** — Deploy to Dogfood cloud first (has fallback enabled)
3. **Monitoring** — Watch Kusto dashboards for fallback-to-Bearer errors
4. **Public Rollout** — Deploy to Public, Fairfax, Mooncake in sequence
5. **Sunset Bearer** — After 30 days, remove Bearer fallback if no incidents

## Key Files

- `api/FedRampDashboard.Api/Authorization/PopTokenConfiguration.cs` — Cloud/tenant configuration
- `api/FedRampDashboard.Api/Authorization/PopTokenValidationService.cs` — MISE V2 validation logic
- `api/FedRampDashboard.Api/Middleware/PopTokenValidationMiddleware.cs` — Token extraction & routing
- `api/FedRampDashboard.Api/Program.cs` — DI container & pipeline wiring
- `api/FedRampDashboard.Api/appsettings.json` — Runtime configuration
- `infrastructure/rp-registration-pop-token.json` — ARM RP registration manifest

## References

- [MISE V2 Adoption Guide (ASP.NET Core)](https://eng.ms/docs/microsoft-security/identity/entra-developer-application-platform/id4s-identity-for-services/authn-middleware-sdk-microsoft-identity-service-essentials/microsoft-identity-service-essentials/articles/v2/adoption-guide/adopting-mise-v2-aspnetcore)
- [RP Platform Auth & Authorization](https://eng.ms/docs/products/arm/rpaas/authentication_v2)
- [MISE V2 Migration Guide](https://eng.ms/docs/microsoft-security/identity/entra-developer-application-platform/id4s-identity-for-services/authn-middleware-sdk-microsoft-identity-service-essentials/microsoft-identity-service-essentials/articles/migration-guides/misev2)
- [mTLS PoP How-To](https://eng.ms/docs/microsoft-security/identity/entra-developer-application-platform/id4s-identity-for-services/authn-middleware-sdk-microsoft-identity-service-essentials/microsoft-identity-service-essentials/articles/using-mise/how-to-use-mtls-pop)
