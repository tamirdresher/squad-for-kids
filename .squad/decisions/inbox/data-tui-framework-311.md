# Decision: SharpConsoleUI Beta Branch Strategy — Issue #311

**Date:** 2026-03-11  
**Author:** Data (Code Expert)  
**Status:** 📋 Proposed (awaiting team review)  
**Scope:** squad-monitor TUI Framework Selection

## Context

Reddit post identified SharpConsoleUI as a new .NET Terminal UI framework with advanced features:
- Multi-window support with per-window async threads
- WPF-style retained-mode GUI architecture
- Full Spectre.Console integration
- 30+ controls including interactive DataGrid, TreeView, Canvas

squad-monitor is a .NET 10.0 global tool (~2,000 lines) using Spectre.Console Layouts for real-time dashboard monitoring.

## Decision

**Approve beta branch experimentation** with SharpConsoleUI, but maintain current Spectre.Console implementation as stable mainline.

## Rationale

**Why Experiment:**
1. **Unique Features:** Only TUI framework offering overlapping windows + per-window threads
2. **Ideal Use Case:** squad-monitor's real-time monitoring needs independent refresh rates
3. **Spectre Integration:** Can reuse existing rendering logic via `SpectreRenderableControl`
4. **Interactive Potential:** Drill-down views, sortable tables, button actions

**Why Beta-Only:**
1. **Early Stage:** Project < 1 month old (created 2025-02-11)
2. **Small Community:** 145 stars, 1 fork (vs. Terminal.Gui 9.6k, Spectre.Console 9.4k)
3. **Unknown Stability:** No known production deployments
4. **API Risk:** Possible breaking changes as library matures

## Alternatives Considered

1. **Terminal.Gui:**
   - ✅ Mature (9.6k stars, 5+ years)
   - ✅ Large control library (40+)
   - ❌ No per-window threads
   - ❌ Weaker Spectre.Console integration

2. **Continue Spectre.Console:**
   - ✅ Proven stability
   - ✅ Good enough for current needs
   - ❌ No multi-window support
   - ❌ No interactive controls (read-only)

3. **Wait for SharpConsoleUI to Mature:**
   - ✅ Lower risk
   - ❌ Miss opportunity to provide early feedback
   - ❌ Delayed UX improvements

## Implementation Plan

**Phase 1: Proof-of-Concept (1-2 hours)**
- Branch: `feature/sharpconsoleui-tui`
- Add `SharpConsoleUI` NuGet package
- Single window with Ralph heartbeat panel
- Version: `1.1.0-beta.1`

**Phase 2: Multi-Window (2-4 hours)**
- GitHub issues as separate window
- Test per-window thread refresh rates
- Window management (focus, cycling, close)

**Phase 3: Interactivity (4-6 hours)**
- Drill-down PR details window
- Interactive table sorting/filtering
- Button actions (refresh, open URL)

**Phase 4: Live Feed (2-3 hours)**
- Agent feed as independent window
- High-frequency updates (2s vs. 30s)
- Performance validation

**Success Criteria:**
- ✅ Framework stable enough for local development
- ✅ Multi-window UX is tangibly better than single Layout
- ✅ Migration effort < 2 days for full feature parity
- ✅ No significant performance regressions

**Go/No-Go Decision Points:**
- ✅ **GO:** PoC stable + clear UX benefits → continue to Phase 2
- ⏸️ **PAUSE:** Bugs/issues → report to upstream, wait for fixes
- ❌ **NO-GO:** Too unstable or complex → abandon beta branch

## Consequences

**If Adopted:**
- ✅ Better UX for squad-monitor (multi-window, interactivity)
- ✅ Early feedback to SharpConsoleUI maintainer
- ✅ Learning opportunity for emerging TUI patterns
- ⚠️ Maintenance of two codebases (stable + beta)
- ⚠️ Risk of upstream breaking changes
- ⚠️ Limited community support for troubleshooting

**If Rejected:**
- ✅ Lower maintenance burden
- ✅ Proven stability
- ❌ Miss opportunity for UX improvements
- ❌ squad-monitor remains read-only dashboard

## Migration Risk Mitigation

1. **Preserve Spectre.Console Mainline:**
   - Keep main branch on current implementation
   - Beta branch clearly marked as experimental

2. **Version Semantics:**
   - Beta: `1.x.0-beta.N`
   - Stable: `1.x.0`
   - NuGet description: "Beta: Testing SharpConsoleUI TUI framework"

3. **Incremental Validation:**
   - Each phase has go/no-go checkpoint
   - Can abandon at any point without sunk cost fallacy

4. **Upstream Engagement:**
   - Report bugs to https://github.com/nickprotop/ConsoleEx/issues
   - Contribute fixes if feasible
   - Monitor release notes for breaking changes

## Team Discussion Points

1. **Risk Tolerance:** Is < 1 month maturity acceptable for beta experimentation?
2. **Maintenance:** Who owns the beta branch if Data is unavailable?
3. **User Communication:** How to surface beta vs. stable to users?
4. **Timeline:** Should we wait 3-6 months for library to mature first?
5. **Upstream Commitment:** Should we contribute to SharpConsoleUI to accelerate maturity?

## References

- Reddit Post: https://www.reddit.com/r/dotnet/comments/1rmspk3/terminal_ui_framework_for_net_multiwindow/
- GitHub: https://github.com/nickprotop/ConsoleEx
- NuGet: https://www.nuget.org/packages/SharpConsoleUI/
- Issue #311: https://github.com/tamirdresher_microsoft/tamresearch1/issues/311
- Research Summary: Issue #311 comment (2026-03-11)

## Recommendation

**Proceed with Phase 1 proof-of-concept.** The per-window thread feature is compelling enough to justify 1-2 hours of experimentation. If PoC is successful, we can make an informed decision about continuing vs. waiting for library to mature.

**Timeframe:** If starting today (2026-03-11), PoC should complete by 2026-03-12. Decision on Phase 2+ by 2026-03-13.
