## Decision Proposal: RP Registration Approach for DK8S

**Date:** 2026-03-08  
**Author:** Seven (Research & Docs)  
**Status:** Proposed  
**Scope:** RP Registration Strategy  
**Related:** Issue #11, rp-registration-guide.md

### Proposal

Adopt a Hybrid RP approach for DK8S's BasePlatformRP registration: RPaaS for simple CRUD resource types, Direct RP for complex orchestration types, and RP Lite for read-only inventory exposure.

### Key Findings

1. **RPaaS is the recommended path for new services** — but DK8S's complex orchestration logic (fleet scheduling, scale unit management, Kubernetes operator patterns) doesn't fit RPaaS's callback model cleanly
2. **Custom (Direct) RP requires an exception** — new unmanaged RPs need approval via aka.ms/RPaaSException
3. **Hybrid RP is the best of both worlds** — managed types for simple CRUD + direct types for complex workflows
4. **Timeline: 4–10 months** depending on complexity and review cycles
5. **TypeSpec is mandatory** for all new services since January 2024
6. **OBO subscriptions are now auto-provisioned** (since May 2024) when PC Code and Program ID are provided

### Recommended Next Steps

1. **Attend ARM API Modeling Office Hours** with resource type proposal
2. **Determine RP type** (Managed, Direct, or Hybrid) based on complexity assessment
3. **Begin TypeSpec authoring** for resource types
4. **File RPaaS onboarding IcM** with ServiceTree metadata
5. **Review IcM 757549503 response** to incorporate any guidance from RPaaS team

### Consequences

- ✅ Structured registration path aligned with ARM standards
- ✅ Auto-generated SDKs, Portal, CLI, Bicep support
- ✅ Sovereign cloud support (Mooncake, Fairfax since May 2025)
- ⚠️ 4–10 month timeline depending on approach
- ⚠️ Go vs .NET tension (RPaaS tooling is .NET-based, DK8S is Go-native)
- ⚠️ Ongoing compliance burden (API reviews, SDK regen, certification)
