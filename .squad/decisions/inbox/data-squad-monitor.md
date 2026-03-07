# Decision: Squad Activity Monitor Tool Architecture

**Date:** 2026-03-07  
**Author:** Data (Code Expert)  
**Issue:** #40  
**Status:** ✅ Implemented

## Context

Tamir requested a local tool to monitor squad member activity in real-time. Initial proposal included both PowerShell script and web dashboard options. Tamir chose the local tool approach but requested C# instead of PowerShell, specifically mentioning .NET 10's single-file capabilities.

## Decision

Built Squad Activity Monitor as a C# 13 console application using .NET 10 with Spectre.Console for terminal UI.

## Technical Choices

### Platform: .NET 10 + C# 13
- **Rationale:** Latest available SDK, single-file publish capability, modern language features
- **Benefits:** Cross-platform, type-safe, performant, self-contained executable
- **Trade-offs:** Requires .NET SDK to run (or single-file publish for distribution)

### UI Framework: Spectre.Console
- **Rationale:** Best-in-class terminal UI library for .NET
- **Benefits:** Beautiful tables, color support, rich formatting, escape handling
- **Trade-offs:** External dependency (but stable, well-maintained)

### Architecture: Simple File Parser
- **Rationale:** Orchestration logs are markdown files with predictable structure
- **Benefits:** No database, no state, simple regex parsing, fast startup
- **Trade-offs:** Limited to what's in log files, no historical analysis

### Data Source: Orchestration Logs Only
- **Rationale:** Primary source of truth for squad activity
- **Benefits:** Direct access, no API needed, real-time updates
- **Trade-offs:** Doesn't capture session logs or detailed agent state (not needed for MVP)

## Implementation Patterns

1. **Top-level statements** - No unnecessary ceremony
2. **Records** - Clean data models (AgentActivity)
3. **Regex parsing** - Extract timestamp and agent name from filename
4. **Markdown parsing** - Simple regex for Status, Assignment, Outcome sections
5. **Smart formatting** - Age relative to UTC now, color coding by status

## User Preferences Captured

- **C# over PowerShell** - Better type safety, more portable
- **Local tool over web dashboard** - Faster to build, simpler to use
- **Auto-refresh default** - Monitor mode is primary use case
- **`--once` flag** - Quick status check without loop

## Future Enhancements (Deferred)

- Session log integration for detailed agent state
- Historical trend analysis (activity over time)
- Agent filtering (show only specific agents)
- Export to JSON/CSV for analysis
- Web dashboard (if team grows or remote monitoring needed)

## Outcome

✅ Tool implemented in ~270 lines of C#, tested successfully, PR #47 created.  
✅ Displays 20 recent activities with beautiful formatting.  
✅ Auto-refresh every 5s (configurable).  
✅ Color-coded status indicators work as expected.

## Lessons Learned

1. Timestamp parsing from filenames requires explicit regex grouping
2. Spectre.Console's Markup.Escape() is critical for user-generated content
3. .NET 10 single-file publish creates truly self-contained executables
4. Top-level statements + records = minimal ceremony for console apps
