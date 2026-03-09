# Squad Scheduler Implementation Roadmap

**Issue:** #199 — Generic, provider-agnostic scheduling system  
**Design:** See `squad-scheduler-design-v2.md` for full architecture  
**Owner:** B'Elanna (Infrastructure Expert)

---

## Quick Start: What Changes?

### Before (Current State)
```
ralph-watch.ps1 runs every 5 min
  ↓
Calls Invoke-SquadScheduler.ps1
  ↓
Reads schedule.json, evaluates cron/interval
  ↓
Executes tasks locally (PowerShell scripts, workflow dispatch)
  ↓
Writes state to schedule-state.json

PROBLEMS:
❌ If ralph-watch stops, tasks are missed forever
❌ GitHub Actions workflows have hardcoded cron schedules (not synced with schedule.json)
❌ No recovery from missed tasks
❌ No audit trail (can't query "why didn't X run?")
❌ Provider logic mixed with scheduler logic
```

### After (v2 Design)
```
ralph-watch.ps1 runs every 5 min
  ↓
Calls Invoke-SquadScheduler.ps1 -CatchUp
  ↓
Reads schedule.json + scheduler.db (SQLite)
  ↓
Detects missed tasks (e.g., machine was rebooted during 7 AM trigger)
  ↓
Executes missed tasks with catch-up flag
  ↓
Selects provider adapter (local-polling, github-actions, windows-scheduler)
  ↓
Executes tasks via provider, logs to scheduler.db

BENEFITS:
✅ Missed tasks are caught up on restart
✅ All schedules in schedule.json (no hardcoded cron in workflows)
✅ Queryable audit trail (SQL: "show all failed tasks")
✅ Provider abstraction (easy to add Azure DevOps, Kubernetes CronJobs)
✅ Persistent scheduling (Windows Scheduled Tasks survive reboots)
```

---

## MVP Deliverables (2 Weeks)

### Phase 1: Persistence Layer (Week 1)
**Files Changed:**
- [ ] `.squad/monitoring/scheduler.db` — NEW: SQLite database
- [ ] `.squad/scheduler/schema.sql` — NEW: Database schema
- [ ] `.squad/scripts/Invoke-SquadScheduler.ps1` — MODIFIED: Add database functions

**Functionality:**
- Replace `schedule-state.json` with SQLite database
- Tables: `schedules`, `executions`, `state`
- Query examples: "show failed tasks", "what's scheduled next", "why didn't X run"

**Testing:**
```powershell
# Initialize database
.squad/scripts/Invoke-SquadScheduler.ps1 -Initialize

# Run scheduler, verify logging
.squad/scripts/Invoke-SquadScheduler.ps1 -Provider local-polling

# Query execution history
sqlite3 .squad/monitoring/scheduler.db "SELECT * FROM executions WHERE status='failed';"
```

---

### Phase 2: Provider Abstraction (Week 2)
**Files Changed:**
- [ ] `.squad/scheduler/providers/ISchedulerProvider.ps1` — NEW: Base class
- [ ] `.squad/scheduler/providers/LocalPollingProvider.ps1` — NEW
- [ ] `.squad/scheduler/providers/GitHubActionsProvider.ps1` — NEW
- [ ] `.squad/scheduler/providers/CopilotAgentProvider.ps1` — NEW
- [ ] `.squad/scripts/Invoke-SquadScheduler.ps1` — MODIFIED: Use providers

**Functionality:**
- Extract provider logic into pluggable adapters
- Clean interface: `CanHandle()`, `Execute()`, `IsAvailable()`
- Provider priority: local-polling > github-actions > fallback

**Testing:**
```powershell
# Test local provider
.squad/scripts/Invoke-SquadScheduler.ps1 -Provider local-polling -TaskId daily-rp-briefing -DryRun

# Test GitHub Actions provider
.squad/scripts/Invoke-SquadScheduler.ps1 -Provider github-actions -TaskId daily-digest -DryRun

# Test auto-selection (picks best available provider)
.squad/scripts/Invoke-SquadScheduler.ps1 -Provider auto -TaskId ralph-heartbeat
```

---

### Phase 3: Catch-Up Logic (Week 2, Parallel with Phase 2)
**Files Changed:**
- [ ] `.squad/schedule.json` — MODIFIED: Add `trigger.catchUp`, `trigger.catchUpWindowMinutes`
- [ ] `.squad/scripts/Invoke-SquadScheduler.ps1` — MODIFIED: Add `Find-MissedExecutions`
- [ ] `ralph-watch.ps1` — MODIFIED: Call with `-CatchUp` flag

**Functionality:**
- On startup, detect tasks that missed their trigger window
- Execute missed tasks with `context.catchUp = true`
- Only catch up if within catchUpWindowMinutes (default: 120 minutes)

**Testing Scenario:**
```powershell
# 1. Schedule task for 7 AM
# 2. Stop ralph-watch at 6:50 AM
# 3. Wait until 8:30 AM
# 4. Start ralph-watch with -CatchUp
# 5. Verify: 7 AM task runs immediately with catch-up flag
# 6. Check database: execution.context = '{"catchUp":true}'
```

---

## Full Roadmap (6 Weeks)

| Phase | Week | Goal | Deliverables |
|-------|------|------|--------------|
| **Phase 1** | 1 | Persistence Layer | SQLite database, migrate from JSON |
| **Phase 2** | 2 | Provider Abstraction | Pluggable provider adapters |
| **Phase 3** | 2 | Catch-Up Logic | Detect & execute missed tasks |
| **Phase 4** | 3-4 | Windows Scheduler | Persistent scheduling across reboots |
| **Phase 5** | 5 | GitHub Actions Sync | Unify workflow cron with schedule.json |
| **Phase 6** | 6 | Observability Dashboard | Web UI for schedules & execution history |

---

## Decision Points (Need User Input)

### 1. Primary Provider Strategy
**Question:** Should Squad rely on local polling (ralph-watch) or persistent scheduling (Windows Task Scheduler)?

**Options:**
- **A. Local Polling Primary** — ralph-watch runs 24/7, Windows Scheduler as backup
- **B. Persistent Primary** — Windows Scheduled Tasks run everything, ralph-watch optional
- **C. Hybrid (Recommended)** — Critical tasks use Windows Scheduler, dynamic tasks use ralph-watch

**My Recommendation:** **Option C (Hybrid)**
- Daily briefings, ADR checks → Windows Scheduler (persistent)
- Ralph heartbeat, dynamic triage → ralph-watch (flexible)
- Best of both: reliability + flexibility

---

### 2. GitHub Actions Integration
**Question:** How to sync GitHub Actions workflows with schedule.json?

**Options:**
- **A. Generate Workflows** — Script reads schedule.json, writes workflow YAML files
- **B. Single Dispatcher (Recommended)** — One workflow calls Invoke-SquadScheduler every 5 min
- **C. Keep Separate** — Workflows remain independent (status quo)

**My Recommendation:** **Option B (Single Dispatcher)**
- Simpler, less brittle
- One workflow to maintain, not N workflows
- Schedules stay in schedule.json (single source of truth)

---

### 3. Rollout Strategy
**Question:** Phased migration or big bang?

**Options:**
- **A. Phased (Recommended)** — Deploy Phase 1-3 in Week 1-2, Phase 4-6 over 4 weeks
- **B. Big Bang** — Deploy all 6 phases at once (2-3 weeks, higher risk)
- **C. Hybrid** — Deploy persistence layer immediately, add providers incrementally

**My Recommendation:** **Option A (Phased)**
- Less risk, iterative feedback
- Can test each phase independently
- Delivers value quickly (catch-up logic in Week 2)

---

## Quick Reference: Key Files

### New Files (To Be Created)
```
.squad/
├── monitoring/
│   └── scheduler.db                         # SQLite database (NEW)
├── scheduler/
│   ├── schema.sql                           # Database schema (NEW)
│   └── providers/
│       ├── ISchedulerProvider.ps1          # Base class (NEW)
│       ├── LocalPollingProvider.ps1        # Local execution (NEW)
│       ├── GitHubActionsProvider.ps1       # Workflow dispatch (NEW)
│       ├── CopilotAgentProvider.ps1        # Agency sessions (NEW)
│       └── WindowsTaskSchedulerProvider.ps1 # Persistent tasks (NEW, Phase 4)
└── implementations/
    ├── squad-scheduler-design-v2.md         # Full architecture (THIS FILE)
    └── squad-scheduler-roadmap.md           # Implementation plan (YOU ARE HERE)
```

### Modified Files
```
.squad/
├── schedule.json                            # Add catchUp fields
└── scripts/
    └── Invoke-SquadScheduler.ps1           # Add database, providers, catch-up
ralph-watch.ps1                              # Add -CatchUp flag, -EnableWindowsScheduler
```

---

## Success Metrics

### Phase 1-3 (MVP, Week 2)
- [ ] Scheduler uses SQLite database (no more schedule-state.json)
- [ ] Can query: `sqlite3 scheduler.db "SELECT * FROM executions WHERE status='failed';"`
- [ ] Missed tasks detected and executed on restart
- [ ] Provider abstraction in place (3 providers: local, github, copilot)

### Phase 4-6 (Full Release, Week 6)
- [ ] Windows Scheduled Tasks registered (survive reboots)
- [ ] GitHub Actions workflows unified with schedule.json
- [ ] Dashboard shows all schedules + execution history
- [ ] Zero hardcoded cron schedules in `.github/workflows/`

---

## Getting Started (Developer Guide)

### Step 1: Review Design
```powershell
# Read full architecture document
cat .squad/implementations/squad-scheduler-design-v2.md | less
```

### Step 2: Implement Phase 1 (Persistence)
```powershell
# Create database schema
mkdir -p .squad/scheduler
cat > .squad/scheduler/schema.sql <<'EOF'
-- schedules table
CREATE TABLE schedules (
    id TEXT PRIMARY KEY,
    config TEXT NOT NULL,
    enabled INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- executions table
CREATE TABLE executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    schedule_id TEXT NOT NULL,
    trigger_time TIMESTAMP NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    status TEXT NOT NULL,
    exit_code INTEGER,
    output TEXT,
    provider TEXT,
    duration_seconds REAL,
    context TEXT,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

-- state table
CREATE TABLE state (
    schedule_id TEXT PRIMARY KEY,
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    consecutive_failures INTEGER DEFAULT 0,
    FOREIGN KEY (schedule_id) REFERENCES schedules(id)
);

-- Indexes
CREATE INDEX idx_executions_schedule_id ON executions(schedule_id);
CREATE INDEX idx_executions_status ON executions(status);
EOF

# Initialize database
mkdir -p .squad/monitoring
sqlite3 .squad/monitoring/scheduler.db < .squad/scheduler/schema.sql
```

### Step 3: Test Database
```powershell
# Insert test schedule
sqlite3 .squad/monitoring/scheduler.db <<'EOF'
INSERT INTO schedules (id, config, enabled)
VALUES ('test-task', '{"name":"Test Task"}', 1);
EOF

# Query schedules
sqlite3 .squad/monitoring/scheduler.db "SELECT * FROM schedules;"
```

### Step 4: Update Invoke-SquadScheduler.ps1
```powershell
# Add database functions (see design doc for full implementation)
# Key functions to add:
# - Initialize-SchedulerDatabase
# - Get-LastRun
# - Add-ExecutionRecord
# - Update-ScheduleState
```

---

## FAQ

### Q: Will this break existing workflows?
**A:** No. Phases 1-3 are additive (new features), existing workflows unchanged. Phase 5 migrates workflows, but with backward compatibility.

### Q: What if I don't want Windows Scheduled Tasks?
**A:** Skip Phase 4. Use only local-polling + github-actions providers. Design is modular.

### Q: Can I use this on Linux/Mac?
**A:** Yes. Windows Task Scheduler provider is optional. Use local-polling + github-actions on Linux/Mac. Cron integration coming in future (similar to Windows Scheduler).

### Q: What about Azure DevOps Pipelines?
**A:** Add `AzureDevOpsProvider.ps1` in Phase 2 (similar to GitHubActionsProvider). Design supports any provider.

### Q: How do I migrate existing schedules?
**A:** Run `Invoke-SquadScheduler.ps1 -Initialize` — reads schedule.json, populates database. Existing schedule.json unchanged.

---

## Related Issues & PRs

- **Issue #199:** Can Squad have its own schedule? (THIS ISSUE)
- **Issue #198:** Daily ADR channel monitoring (uses scheduler)
- Related design docs:
  - `squad-scheduler-design.md` (v1, superseded by v2)
  - `squad-scheduler-design-v2.md` (this design)

---

## Contact

**Questions?** Tag @belanna (B'Elanna — Infrastructure Expert) in issue comments.

**Ready to implement?** Create PR for Phase 1, reference this roadmap.

---

*Last Updated: 2025-01-21*  
*Status: Design Complete, Awaiting User Decisions + Phase 1 Implementation*
