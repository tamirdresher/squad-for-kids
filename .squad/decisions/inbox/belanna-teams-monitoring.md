# Teams Monitoring Architecture Decision

**Date:** 2026-03-16
**Author:** B'Elanna (Infrastructure Expert)
**Issue:** #215
**PR:** #216
**Status:** Implemented

## Context

The squad needs continuous monitoring of Teams channels to catch actionable messages directed at Tamir without manual checks. Roy's review request example showed the gap — the squad should silently review and only surface items requiring Tamir's attention.

## Decision

Implement scheduled Teams monitoring using:

1. **Squad Scheduler Integration**
   - New schedule entry: `teams-message-monitor`
   - Interval trigger: every 20 minutes (1200 seconds)
   - Provider: `local-polling` (Ralph's watch loop)
   - Task type: `copilot` (enables WorkIQ tool access)

2. **Smart Filtering Pipeline**
   ```
   WorkIQ Query → Message Extraction → Actionability Filter → Deduplication → GitHub Issue
   ```
   
3. **Actionability Criteria**
   - Direct mentions: "Tamir", "@tamir", "squad"
   - Action keywords: "can you", "please review", "need you to", "urgent"
   - Context: combined mention + action keyword
   - Ignore: automated notifications, already processed

4. **State Management**
   - Track processed messages (last 100)
   - Track created issues (last 50)
   - State file: `.squad/monitoring/teams-monitor-state.json`

5. **Output Channels**
   - **GitHub issues**: Actionable items with `teams-bridge` label
   - **Teams notifications**: Summary when items found
   - **Logs**: All activity to `.squad/monitoring/teams-monitor.log`

## Rationale

### Why 20-minute interval?
- Responsive enough (3 checks per hour)
- Respects WorkIQ indexing delay
- Avoids rate limiting
- Balances with Ralph's 5-minute loop

### Why Copilot task type?
- Enables WorkIQ tool (`workiq-ask_work_iq`) access
- Allows natural language queries
- Supports dynamic query adaptation
- Better than pure PowerShell + API calls

### Why state-based deduplication?
- Prevents duplicate issues for same message
- Memory of recent context (last 100 messages)
- Survives Ralph restarts
- Simple file-based persistence

### Why smart filtering vs. all messages?
- Reduces noise (no spam)
- Focuses on actionable content
- Learns from keywords and patterns
- Iterative improvement possible

## Alternatives Considered

1. **Real-time webhook**: Not available for Teams read access
2. **Manual queries**: Too slow, inconsistent
3. **GitHub Actions cron**: Requires separate workflow, less integrated
4. **Every Ralph cycle**: Too frequent, would spam WorkIQ
5. **Daily digest only**: Too slow for urgent items

## Implementation

**Files:**
- `.squad/schedule.json`: Schedule entry
- `.squad/scripts/teams-monitor-check.ps1`: Monitoring script
- `.squad/skills/teams-monitor/SKILL.md`: Documentation update

**Integration Points:**
- Ralph's watch loop (every 5 min) evaluates schedule
- Squad Scheduler fires task when interval elapsed
- Copilot CLI executes with WorkIQ access
- Script creates issues via `gh` CLI
- Teams webhook for notifications

## Success Metrics

1. **Coverage**: Catch 90%+ of actionable messages
2. **Precision**: <10% false positives (non-actionable as actionable)
3. **Latency**: Surface items within 30 minutes of posting
4. **Noise**: No duplicate issues, minimal notifications

## Evolution Path

1. **Phase 1 (Current)**: Basic keyword filtering
2. **Phase 2 (Week 2-3)**: Refine query patterns based on results
3. **Phase 3 (Month 2)**: Add sender/channel weighting
4. **Phase 4 (Month 3)**: ML-based urgency scoring

## Notes

- WorkIQ has indexing delay (typically minutes)
- First implementation — expect tuning needed
- Monitor false positive/negative rates
- Adjust interval if needed (15-30 min range)
- Can disable by setting `enabled: false` in schedule

## References

- Issue #215: Original request
- Issue #183: Teams outbound integration (separate)
- PR #216: Implementation
- `.squad/skills/teams-monitor/SKILL.md`: Workflow documentation
