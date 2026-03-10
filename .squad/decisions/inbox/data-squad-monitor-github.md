# Decision: squad-monitor GitHub Integration Should Be Optional

**Date:** 2026-03-10  
**Agent:** Data (Code Expert)  
**Context:** Issue #263  
**Status:** Implemented

## Decision
Make GitHub integration in squad-monitor optional with graceful degradation when gh CLI is unavailable.

## Rationale
- **Robustness:** squad-monitor should work in environments without gh CLI or GitHub access
- **User Experience:** Missing dependencies should hide features, not show error messages
- **Separation of Concerns:** GitHub features are just one component; Ralph Watch and Orchestration monitoring are core
- **Flexibility:** Users may want to disable GitHub even when available (auth issues, rate limits, preference)

## Implementation
1. **Auto-detection:** Check gh CLI availability at startup using `gh --version`
2. **Conditional rendering:** Skip GitHub sections (Issues/PRs/Merged PRs) when disabled
3. **User control:** Added `--no-github` flag for explicit opt-out
4. **Clear messaging:** Display "GitHub integration: disabled (gh CLI not available)" in startup messages
5. **Dual-mode support:** Works in both live dashboard and `--once` modes

## Benefits
- ✅ No more error messages when gh CLI unavailable
- ✅ Clean user experience regardless of environment
- ✅ Other panels (Ralph Watch, Orchestration) work normally
- ✅ Users can explicitly disable GitHub if needed
- ✅ Minimal code changes (added 64 lines, modified 13)

## Trade-offs
- Adds one more command-line flag (acceptable given the value)
- Startup adds ~3ms for gh CLI detection (negligible)

## Future Considerations
- Could extend this pattern to other optional integrations (ADO, Jira, etc.)
- Consider adding runtime detection/retry if gh CLI becomes available later
- May want config file to set default GitHub behavior

## References
- Issue: #263
- Commit: [52c9360](https://github.com/tamirdresher/squad-monitor/commit/52c9360)
- Repo: tamirdresher/squad-monitor
