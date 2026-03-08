# Decision: Centralized Alert Helper Module for FedRAMP Alerting

**Date:** 2026-03-07  
**Author:** Worf (Security & Cloud)  
**Status:** Implemented  
**Scope:** Code Quality & Maintainability

## Context

During PR #97 review, identified code quality issues in the FedRAMP alerting pipeline:
- Dedup key generation logic duplicated 3 times (IsDuplicateAsync, IsSuppressedAsync, StoreAlertInCacheAsync)
- Severity mapping logic duplicated across PagerDutyClient.cs and TeamsClient.cs
- Each duplication increases bug surface area and maintenance burden

## Decision

Created `functions/AlertHelper.cs` shared module with centralized helper methods:

1. **Dedup Key Generation:**
   ```csharp
   public static string GenerateDedupKey(string alertType, string controlId, string environment)
   {
       return $"alert:dedup:{alertType}:{controlId ?? "global"}:{environment}";
   }
   ```

2. **Severity Mapping:**
   ```csharp
   public static class SeverityMapping
   {
       public static string ToPagerDuty(string severity);
       public static string ToTeamsWebhookKey(string severity);
       public static string ToTeamsCardStyle(string severity);
   }
   ```

## Rationale

- **Single Source of Truth:** Changes to key format or severity mapping only require one edit
- **Type Safety:** Static methods with clear signatures reduce runtime errors
- **Testability:** Centralized logic easier to unit test in isolation
- **Security:** Consistent key generation reduces cache collision vulnerabilities
- **Maintainability:** New severity levels or platforms only require updating helper module

## Alternatives Considered

1. **Base Class with Inheritance:**
   - Rejected: AlertProcessor is static function, inheritance adds complexity
   - Static helper methods more appropriate for stateless utility functions

2. **Constants File:**
   - Rejected: Key generation has logic (null coalescing, string interpolation)
   - Methods provide better encapsulation than string templates

3. **Extension Methods:**
   - Rejected: Severity mapping not intrinsic to string type
   - Static class methods more discoverable and explicit

## Impact

- **Code Reduction:** ~40 lines of duplicate code eliminated
- **Bug Surface Area:** 3 dedup key locations → 1 (67% reduction in error prone code)
- **Severity Mapping:** 3 switch expressions → 1 class (easier to add new platforms)
- **Performance:** No impact (static methods, no allocations)

## Team Standards

Going forward, all shared alert processing logic should be added to `AlertHelper.cs`:
- Key generation methods (dedup, acknowledgment, rate limiting, etc.)
- Severity mapping for new integrations (email, Slack, ServiceNow)
- Alert metadata enrichment helpers
- Common validation functions

Do NOT duplicate key generation or mapping logic in individual handlers.

## Related

- Issue #99: FedRAMP Dashboard: Alerting Code Quality & Load Testing
- PR #101: https://github.com/tamirdresher_microsoft/tamresearch1/pull/101
- File: `functions/AlertHelper.cs`

## Testing

- Load test validates dedup key consistency across 100+ payload variations
- Unit tests should be added for AlertHelper methods (future work)
- Integration test validates Redis cache behavior with helper-generated keys
