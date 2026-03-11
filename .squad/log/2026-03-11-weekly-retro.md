# Weekly Retrospective — 2026-03-11

**Facilitator:** Picard (Lead)  
**Period:** 2026-03-05 → 2026-03-11  
**Type:** First weekly retro (test run)

---

## What Went Well

### 1. CI Restoration Sprint (March 8) — Outstanding Execution
The squad self-organized to fix GitHub Actions CI. B'Elanna deployed a self-hosted runner, Data migrated 16 workflows from ubuntu-latest to self-hosted and converted 9 bash scripts to PowerShell, Ralph fixed YAML parsing issues with here-strings. This was a **real engineering sprint** — coordinated across 3 agents, completed in one session, properly documented with decisions merged into the permanent record.

### 2. Ralph is Running Consistently
113 Ralph activations this week across monitoring, board scans, and task orchestration. Ralph is the backbone of autonomous operations — scanning boards, triaging issues, spawning agents, delivering briefings. The ralph-watch loop is proving its value.

### 3. Productive Research Output
- Cross-repo A2A PRD delivered (Issue #296 → PR #303, merged)
- dotnet/skills assessment completed (Issue #252)
- SharpConsoleUI beta branch created for squad-monitor (Issue #311)
- AI marketplace scanner built and deployed (Issue #283)
- Tech news digest system operational (Issues #309, #312)
- Neelix humor guidelines added (Issue #298 → PR #301, merged)

### 4. Meeting Intelligence Working
Issue #297 (Agency C2 kickoff) — Squad successfully analyzed the meeting via WorkIQ, extracted key decisions, and created 3 derived issues (#306, #307, #308). This is exactly the kind of autonomous value creation Tamir wants.

### 5. PRs Getting Merged Cleanly
19 PRs merged, 0 open. Merge rate is excellent. PRs are being created and completed, not stalling.

---

## What Didn't Go Well

### 1. Too Many Issues Stuck in `pending-user` — 18 Open
This is the biggest problem. We have **18 open issues labeled pending-user**, some dating back weeks (#25, #26, #29, #42). The label has become a parking lot, not a communication tool. Many of these are action items bridged from Teams that Tamir hasn't had time to address, and we're not proactively following up or self-resolving where possible.

**Root cause:** Agents default to "ask Tamir" instead of making decisions autonomously. This was explicitly called out in Tamir's directive today.

### 2. Tamir Had to Correct Board Hygiene (Issue #302)
Tamir asked "Why do we have issues in in-progress that are stuck there?" — Ralph initially reported the board was clean (it wasn't). Tamir had to point out issue #247 was stuck. This is exactly the kind of issue the squad should catch before Tamir does.

**Root cause:** Board scanning is shallow — checks labels but doesn't audit staleness or age of in-progress items.

### 3. Issue #305 — Tamir Had to Ask Twice
"Didn't I ask you to look in the Teams chat of the Copilot Windows app?" — The first search attempt returned poor results. Tamir had to repeat the request. Squad should have been more thorough on the first pass and escalated clearly when results were insufficient.

### 4. Roster File is Still a Template
The `.squad/roster.md` has placeholder `{Name}`, `{Role}`, `{user name}`, `{languages}` fields. After 9 days of active operation with 7+ agents, the roster should be populated. This is basic team management that was overlooked.

### 5. PR Creation Failures on External Repos
The SharpConsoleUI beta work (Issue #311) couldn't create a PR due to EMU policy restrictions on personal repos. This was handled gracefully (workaround documented) but indicates a **recurring gap** — agents try to create PRs on repos where policies prevent it, and we rediscover this limitation each time.

### 6. Duplicate Issues Created
Issues #309 and #312 are both "Tech News Digest: 2026-03-11" — duplicate issue creation suggests Ralph's board scanning doesn't deduplicate effectively before creating new work items.

---

## Action Items

| # | Action | Owner | Priority | Status |
|---|--------|-------|----------|--------|
| 1 | **Audit and close stale pending-user issues** — Review all 18, close what we can resolve autonomously, add clear explanations to the rest | Picard | HIGH | Pending |
| 2 | **Add staleness detection to Ralph board scans** — Flag any issue in-progress for >3 days without activity | B'Elanna | HIGH | Pending |
| 3 | **Populate roster.md** with actual team members and project context | Scribe | MEDIUM | Pending |
| 4 | **Add deduplication check before creating issues** — Ralph should search existing issues by title/keywords before filing new ones | Data | MEDIUM | Pending |
| 5 | **Document EMU PR restrictions** — Add to decisions.md so agents don't retry failed PR creation patterns | Picard | LOW | Pending |
| 6 | **Implement directive: "Decide and act, don't ask"** — Reduce pending-user defaults, make autonomous decisions where possible | ALL | HIGH | Directive filed |
| 7 | **Add follow-up mechanism for pending-user issues** — After 3 days, re-ping or attempt self-resolution | Ralph | MEDIUM | Pending |

---

## Directives Added/Updated

### New Directive: Autonomy Over Dependency (from Tamir, 2026-03-11)
> "Squad must be more autonomous and less dependent on Tamir. Don't ask — decide and act."

Filed to `.squad/decisions/inbox/copilot-directive-autonomy.md`

### New Directive: Weekly Retrospective (from Tamir, 2026-03-11)
> Every Friday: review all work, issue comments, what Tamir liked/disliked, improve rules/directives/tooling proactively.

### Reinforced: Explanatory Comments for pending-user (Decision 1.1)
> Always add a comment explaining WHY when setting pending-user. Never change the label without explanation.

Still being violated occasionally — agents sometimes set the label without enough context for Tamir to act on.

---

## Squad Behavior Assessment

### Autonomy: C+ (Needs Improvement)
Agents are productive when given tasks but too often default to `pending-user` instead of making judgment calls. Tamir's directive today was explicit: "I manage decisions, not tasks." We need to internalize this. If an issue has enough context to make a reasonable decision, make it. Only block on Tamir for truly ambiguous strategic choices.

### Self-Diagnosis: C (Poor)
Issue #302 (stuck items) was caught by Tamir, not by us. Ralph's board scans check for open items but don't analyze velocity or staleness. We should be surfacing "hey, #247 has been in-progress for 5 days with no activity" proactively.

### Branch/Worktree Policies: B+
SharpConsoleUI work correctly created a named branch (`squad/311-sharpconsole-ui-beta`). PRs are being created with proper naming. The EMU limitation on external repos is understood and documented.

### Ralph Effectiveness: B+
113 activations/week is strong. Ralph successfully triages, spawns agents, delivers briefings, and manages the board. Weaknesses: duplicate issue creation, shallow board audits, and not catching staleness.

### Decision Capture: B
Decisions are being written to inbox and merged to decisions.md. The CI restoration sprint was exemplary — 2 decisions captured, merged, inbox cleaned. But some informal decisions (e.g., EMU PR limitations) aren't being captured.

---

## Metrics

| Metric | Value |
|--------|-------|
| **Issues created this week** | ~30 |
| **Issues closed this week** | ~36 (from top 50) |
| **PRs merged** | 19 |
| **PRs open** | 0 |
| **Open pending-user issues** | 18 |
| **Agent spawns (orchestration log)** | 241 entries |
| **Agent breakdown** | Data: 48, B'Elanna: 45, Ralph: 42, Seven: 40, Picard: 40, Worf: 13, Scribe: 6 |
| **Ralph activations** | 113 |
| **Git commits this week** | ~30 |
| **Orchestration log entries** | 241 |
| **Session log entries** | 121 |
| **Failures documented** | CI restoration (fixed), PR creation on EMU repos (workaround), duplicate issue creation |

---

## Key Signals from Tamir

1. **"Don't ask — decide and act"** — The #1 message. Stop defaulting to pending-user.
2. **"Why do we have issues stuck?"** (#302) — Board hygiene matters. Catch it before he does.
3. **"Didn't I ask you to look?"** (#305) — First attempts need to be thorough. Don't make him repeat himself.
4. **"Do it"** (#283) — When he gives a directive, execute immediately. Don't just plan.
5. **"Tell my news reporter to be more funny"** (#298) — He cares about personality and quality, not just task completion.
6. **"From now on..."** pattern — Multiple directive issues (#278, #279, #299, #300). He's establishing standing orders. These MUST be captured as decisions and enforced permanently.

---

## Process Changes for Next Week

1. **Retro cadence:** Every Friday, automated. Picard runs it.
2. **Staleness alerts:** Ralph flags in-progress items >3 days old.
3. **Autonomy default:** When in doubt, act. Document the decision. Tamir can override later.
4. **Dedup check:** Before creating issues, search for existing similar titles.
5. **Pending-user audit:** Every retro reviews the pending-user backlog and prunes it.

---

**Filed by:** Picard (Lead)  
**Date:** 2026-03-11  
**Next retro:** 2026-03-14 (Friday)
