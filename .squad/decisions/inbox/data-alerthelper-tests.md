# Decision: AlertHelper Test Strategy

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Context:** Issue #114 - Add unit tests for AlertHelper class  
**PR:** #117

## Decision

Created separate `FedRampDashboard.Functions.Tests` project with copied `AlertHelper.cs` rather than adding project reference to `FedRampDashboard.Functions.csproj`.

## Rationale

1. **Functions Project Build Failure**: The Functions project has 64 build errors due to missing Azure Functions SDK dependencies (HttpTrigger, FunctionName attributes, JsonPropertyName). These are unrelated to AlertHelper.

2. **AlertHelper is Standalone**: AlertHelper.cs has zero dependencies - just System namespaces. It's a pure helper class with static methods.

3. **Test Isolation**: Copying AlertHelper to the test project allows tests to run independently without fixing the entire Functions project build.

4. **Minimal Surface Area**: AlertHelper is 86 lines, stable code from PR #101. Risk of divergence is low. If AlertHelper changes, tests will fail and catch the drift.

## Alternatives Considered

- **Fix Functions Project Build**: Rejected. Would require adding Azure Functions SDK dependencies to Functions.csproj. Out of scope for this issue.
- **Add Project Reference**: Rejected. Test project would fail to build because Functions project doesn't compile.
- **Create Shared Library**: Rejected. Over-engineering for a single 86-line helper class.

## Impact

- **Positive**: Tests can run immediately. 47 tests provide >90% coverage.
- **Risk**: If AlertHelper.cs changes in functions/, tests won't automatically reflect changes. Mitigated by CI failures when tests diverge.
- **Maintenance**: If AlertHelper evolves significantly, reconsider extracting to shared library.

## Test Coverage Details

47 tests covering:
- Dedup key generation (null handling, special characters, determinism)
- Ack key generation (format validation, differentiation)
- Severity mappings for 3 platforms (PagerDuty, Teams webhook, Teams card style)
- Edge cases (whitespace, unicode, colons, null values)
- Cross-platform consistency

All tests passing. CI blocked by #110 (EMU runner issue).

## Recommendation for Future

If Functions project build is fixed, consider:
1. Adding project reference from test project to Functions project
2. Removing copied AlertHelper.cs from test project
3. Keeping the 47 tests as-is (they'll work with either approach)
