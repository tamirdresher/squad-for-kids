# Ralph Cluster Protocol — Implementation Specification

**Author:** Picard (Lead)  
**Date:** 2026-03-12  
**Status:** Ready for Implementation  
**Implements:** Issue #346 — Multi-Machine Ralph Coordination  
**Audience:** Data (implementer), Ralph (consumer)

---

## 1. Overview

This protocol enables N Ralph instances across different machines to share one issue board without duplicate work, using **GitHub as the sole coordination layer**. No Redis, no databases, no queues.

**Key design choices:**
- **Single heartbeat issue** per repo as the coordination hub (avoids commit/push merge conflicts)
- **Issue assignment** as the atomic claiming primitive (GitHub guarantees atomicity per HTTP request)
- **Comments** as append-only audit log (no merge conflicts, no race conditions on writes)
- **Labels** for observability only, never for correctness

---

## 2. Machine Identity

Each Ralph instance MUST have a unique, stable machine name.

**Resolution order (first match wins):**

```powershell
# Add to top of ralph-watch.ps1, after lockfile setup
function Get-RalphMachineId {
    # 1. Explicit file override
    $idFile = Join-Path (Get-Location) ".ralph-machine-id"
    if (Test-Path $idFile) {
        return (Get-Content $idFile -Raw -Encoding utf8).Trim()
    }
    # 2. Environment variable
    if ($env:RALPH_MACHINE_ID) {
        return $env:RALPH_MACHINE_ID.Trim()
    }
    # 3. Fallback: hostname (lowercased, sanitized)
    return ($env:COMPUTERNAME -replace '[^a-zA-Z0-9\-]', '').ToLower()
}

$machineId = Get-RalphMachineId
Write-Host "Ralph machine identity: $machineId" -ForegroundColor Cyan
```

**Convention:** Machine IDs should be short, lowercase, no spaces. Examples: `local`, `devbox`, `ci-runner-1`.

---

## 3. Heartbeat Mechanism

### 3.1 Heartbeat Issue

Each watched repo gets ONE pinned issue titled `Ralph Cluster Heartbeat`. Created once, never closed.

**Setup (one-time per repo):**

```powershell
# Create heartbeat issue if it doesn't exist
$heartbeatIssue = gh issue list -R "$owner/$repo" --search "Ralph Cluster Heartbeat in:title" --state open --json number --jq '.[0].number' 2>$null
if (-not $heartbeatIssue) {
    $heartbeatIssue = gh issue create -R "$owner/$repo" `
        --title "Ralph Cluster Heartbeat" `
        --body "This issue is used for multi-machine Ralph coordination. Each active Ralph instance posts periodic heartbeat comments here. **Do not close this issue.**" `
        --label "squad,ralph:cluster"
    # Pin it (via API — gh CLI doesn't support pinning)
    # Optional: can be done manually
}
```

**Issue number** is cached locally in `.squad/ralph-cluster-config.json` to avoid repeated lookups:

```json
{
    "machineId": "local",
    "heartbeatIssues": {
        "tamirdresher/tamresearch1": 999,
        "tamirdresher/squad-monitor": 10
    },
    "heartbeatIntervalMinutes": 5,
    "staleThresholdMinutes": 15,
    "staleCheckEveryNRounds": 2,
    "raceBackoffMinSec": 5,
    "raceBackoffMaxSec": 15
}
```

### 3.2 Heartbeat Post (every round)

At the START of each round, Ralph posts a single comment to the heartbeat issue:

```powershell
function Send-ClusterHeartbeat {
    param(
        [string]$Repo,
        [int]$HeartbeatIssueNumber,
        [string]$MachineId,
        [int]$Round,
        [string[]]$WorkingOn  # issue numbers currently claimed
    )

    $workingStr = if ($WorkingOn.Count -gt 0) { ($WorkingOn | ForEach-Object { "#$_" }) -join ", " } else { "idle" }
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'

    $body = @"
**⏱️ Heartbeat** | ``$MachineId`` | Round $Round | $ts
Working on: $workingStr
PID: $PID | Status: running
"@

    gh issue comment $HeartbeatIssueNumber -R $Repo --body $body 2>$null
}
```

**API cost:** 1 comment per repo per round = ~12 comments/hour/machine/repo.

### 3.3 Heartbeat Read (peer discovery)

Any Ralph instance can discover peers by reading the heartbeat issue:

```powershell
function Get-ClusterPeers {
    param(
        [string]$Repo,
        [int]$HeartbeatIssueNumber,
        [string]$MyMachineId
    )

    # Get last 50 comments (covers ~4 hours of heartbeats for 2 machines)
    $comments = gh issue view $HeartbeatIssueNumber -R $Repo --json comments --jq '.comments[-50:]' | ConvertFrom-Json

    $peers = @{}
    foreach ($comment in $comments) {
        if ($comment.body -match '\*\*⏱️ Heartbeat\*\* \| ``([^`]+)``') {
            $peerId = $Matches[1]
            $commentTime = [DateTime]::Parse($comment.createdAt)
            $age = (Get-Date).ToUniversalTime() - $commentTime

            if (-not $peers.ContainsKey($peerId) -or $commentTime -gt $peers[$peerId].lastSeen) {
                $peers[$peerId] = @{
                    machineId     = $peerId
                    lastSeen      = $commentTime
                    ageMinutes    = [math]::Round($age.TotalMinutes, 1)
                    isAlive       = $age.TotalMinutes -lt 15
                    isSelf        = ($peerId -eq $MyMachineId)
                }
            }
        }
    }

    return $peers
}
```

**API cost:** 1 GET per repo per round.

---

## 4. Work Claiming Protocol

### 4.1 Claim Flow (step-by-step)

This replaces the current "just spawn agents" logic in the Ralph coordinator prompt.

```
CLAIM PROTOCOL (executed by Ralph's coordinator prompt, not ralph-watch.ps1):

1. DISCOVER: List open issues with label squad:copilot
   → gh issue list --label "squad:copilot" --state open --json number,title,assignees

2. FILTER: For each issue, skip if:
   a. issue.assignees is non-empty (already claimed by someone)
   b. issue has label "ralph:hold" (explicitly paused)

3. CLAIM (for each unclaimed issue you intend to work):
   a. POST assignment:
      → gh issue edit {number} --add-assignee @me
   b. POST claim comment:
      → gh issue comment {number} --body "🔄 Claimed by {machineId} at {ISO timestamp}"
   c. VERIFY (race check):
      → gh issue view {number} --json assignees
      → If assignees.length > 1:
           - Read claim comments, find earliest "🔄 Claimed by" timestamp
           - If MY comment is NOT the earliest → BACK OFF:
             → gh issue edit {number} --remove-assignee @me
             → Skip this issue
           - If MY comment IS earliest → other machine should back off
             → Continue working

4. WORK: Spawn agent for claimed issue
   - Branch name: squad/{number}-{slug}-{machineId}
   - Agent works as normal

5. COMPLETE: When agent finishes (PR merged or issue resolved):
   → gh issue edit {number} --remove-assignee @me
   → gh issue comment {number} --body "✅ Completed by {machineId} — PR #{pr} merged"
```

### 4.2 Race Condition Handling

**Scenario:** Two Ralphs claim same issue within the same ~5-second window.

```
Timeline:
  T+0.0s  Ralph-A: gh issue edit 42 --add-assignee @me       → 200 OK
  T+0.1s  Ralph-B: gh issue edit 42 --add-assignee @me       → 200 OK (GitHub allows it)
  T+0.5s  Ralph-A: gh issue comment 42 "🔄 Claimed by local"  → created_at: T+0.5s
  T+0.8s  Ralph-B: gh issue comment 42 "🔄 Claimed by devbox" → created_at: T+0.8s
  T+1.0s  Ralph-A: gh issue view 42 → assignees: 2            → Race detected!
  T+1.0s  Ralph-B: gh issue view 42 → assignees: 2            → Race detected!
  T+1.5s  Both check claim comments:
          - Ralph-A's comment: T+0.5s (earlier)
          - Ralph-B's comment: T+0.8s (later)
  T+2.0s  Ralph-B: I'm later → gh issue edit 42 --remove-assignee @me → backs off
  T+2.0s  Ralph-A: I'm earlier → I win → continue working
```

**Tiebreaker rule:** The machine whose `🔄 Claimed by` comment has the earliest `createdAt` wins. Loser removes their assignment and moves on.

**Implementation:**

```powershell
function Test-ClaimWon {
    param(
        [string]$Repo,
        [int]$IssueNumber,
        [string]$MachineId
    )

    Start-Sleep -Seconds 3  # Grace window for competing claims to land

    $issue = gh issue view $IssueNumber -R $Repo --json assignees,comments | ConvertFrom-Json

    # No race if sole assignee
    if ($issue.assignees.Count -le 1) { return $true }

    # Race detected — find all claim comments
    $claims = $issue.comments | Where-Object { $_.body -match '🔄 Claimed by' }
    $myClaim = $claims | Where-Object { $_.body -match $MachineId } | Select-Object -First 1

    if (-not $myClaim) {
        # Our claim comment hasn't landed yet? Back off to be safe
        return $false
    }

    # Find any earlier claim
    $earlierClaims = $claims | Where-Object {
        $_.body -notmatch $MachineId -and
        [DateTime]::Parse($_.createdAt) -lt [DateTime]::Parse($myClaim.createdAt)
    }

    if ($earlierClaims.Count -gt 0) {
        # We lost — back off
        gh issue edit $IssueNumber -R $Repo --remove-assignee "@me" 2>$null
        gh issue comment $IssueNumber -R $Repo --body "⚠️ $MachineId backing off — race lost to earlier claim" 2>$null
        return $false
    }

    return $true
}
```

**API cost:** 1 GET per claimed issue (only on race detection). Race is rare (<1%).

### 4.3 What Changes in the Coordinator Prompt

Add this block to the Ralph prompt in `ralph-watch.ps1` (the `$prompt` variable):

```
MULTI-MACHINE COORDINATION:
You are running as machine "{machineId}". Other Ralph instances may be running on other machines.

BEFORE claiming any issue:
1. Check if the issue has ANY assignees. If yes, SKIP it — another machine owns it.
2. To claim: first run `gh issue edit {N} --add-assignee @me`, then immediately comment `🔄 Claimed by {machineId} at {timestamp}`.
3. After claiming, run `gh issue view {N} --json assignees` — if more than 1 assignee, check claim comment timestamps. Back off if your claim is later.
4. Use branch name `squad/{N}-{slug}-{machineId}` to avoid push conflicts.

HEARTBEAT: At the start of each round, post a heartbeat comment to issue #{heartbeatIssueNumber}:
`⏱️ Heartbeat | {machineId} | Round {N} | {timestamp} | Working on: #X, #Y`

STALE RECOVERY: Check assigned issues. If any have a last heartbeat comment older than 15 minutes from a DIFFERENT machine, reclaim them:
1. Remove current assignee: `gh issue edit {N} --remove-assignee @me`
2. Re-assign: `gh issue edit {N} --add-assignee @me`
3. Comment: `♻️ Reclaimed by {machineId} — original machine offline`
```

---

## 5. Stale Recovery

### 5.1 Detection Logic

Run every 2nd round (~10 minutes). Checks ALL assigned issues.

```powershell
function Find-AndReclaimStaleIssues {
    param(
        [string]$Repo,
        [int]$HeartbeatIssueNumber,
        [string]$MachineId,
        [int]$StaleThresholdMinutes = 15
    )

    # Get peer status from heartbeat issue
    $peers = Get-ClusterPeers -Repo $Repo -HeartbeatIssueNumber $HeartbeatIssueNumber -MyMachineId $MachineId

    # Get all currently assigned issues
    $assigned = gh issue list -R $Repo --assignee "@me" --state open --json number,comments | ConvertFrom-Json

    foreach ($issue in $assigned) {
        # Find the latest claim/heartbeat comment
        $claimComments = $issue.comments | Where-Object {
            $_.body -match '🔄 Claimed by|⏱️.*heartbeat|♻️ Reclaimed by'
        }
        $lastActivity = $claimComments | Sort-Object createdAt | Select-Object -Last 1

        if (-not $lastActivity) { continue }

        # Extract machine name from comment
        $claimMachine = ""
        if ($lastActivity.body -match 'Claimed by (\S+)' -or $lastActivity.body -match 'Reclaimed by (\S+)') {
            $claimMachine = $Matches[1]
        }

        # If claimed by US, skip (we're alive, obviously)
        if ($claimMachine -eq $MachineId) { continue }

        # If claimed by ANOTHER machine, check staleness
        $activityAge = (Get-Date).ToUniversalTime() - [DateTime]::Parse($lastActivity.createdAt)

        if ($activityAge.TotalMinutes -gt $StaleThresholdMinutes) {
            # Also verify peer is dead via heartbeat issue
            $peer = $peers[$claimMachine]
            if ($peer -and $peer.isAlive) {
                # Peer is alive on heartbeat board but silent on this issue — don't reclaim yet
                # It might be in the middle of a long agent run
                continue
            }

            # Peer is dead — reclaim
            Write-Host "STALE: Issue #$($issue.number) claimed by $claimMachine, last seen $([int]$activityAge.TotalMinutes) min ago — reclaiming"

            gh issue edit $issue.number -R $Repo --remove-assignee "@me" 2>$null
            Start-Sleep -Seconds 1
            gh issue edit $issue.number -R $Repo --add-assignee "@me" 2>$null
            gh issue comment $issue.number -R $Repo --body "♻️ Reclaimed by $MachineId — $claimMachine offline (last seen $([int]$activityAge.TotalMinutes) min ago)"
        }
    }
}
```

### 5.2 Safety: Double-Check via Heartbeat Board

Before reclaiming, we cross-reference the heartbeat issue. If the owning machine's GLOBAL heartbeat is recent (even though the per-issue heartbeat is stale), we do NOT reclaim — the machine is alive but its agent is just running long.

This prevents false positives from agents that take >15 minutes on a single round.

### 5.3 Reclaim Sequence

```
1. Verify stale (per-issue activity > 15 min old)
2. Cross-check heartbeat issue (peer's global heartbeat also stale?)
3. If both stale → reclaim:
   a. Remove current assignment
   b. Wait 1 second (avoid rapid-fire API calls)
   c. Re-assign to self
   d. Post reclaim comment with reason
   e. Clean up stale branch if exists:
      → git push origin --delete squad/{N}-{slug}-{deadMachine} 2>$null
4. If only per-issue stale but peer globally alive → skip (long-running agent)
```

---

## 6. Work Splitting Strategy

### 6.1 Strategy: "First to Claim Wins" with Natural Round-Robin

No explicit work splitting algorithm. Instead:

1. Both machines discover unclaimed issues at round start
2. Each machine iterates the list and claims the FIRST unclaimed issue it finds
3. After claiming, move to next unclaimed issue
4. Natural jitter (5-min intervals don't align) means machines rarely collide

**Why this works:**
- With 5-minute intervals and random start times, machines are offset by 0-5 minutes
- Issue lists are ordered (by creation date), so machines tend to grab different issues
- Race handling (Section 4.2) covers the rare collision

### 6.2 Optional: Priority-Based Routing (Phase 2)

If specific machines should handle specific work types:

```json
// .squad/ralph-cluster-config.json
{
    "routing": {
        "local":  { "prefer": ["squad:picard", "squad:data"], "maxConcurrent": 3 },
        "devbox": { "prefer": ["squad:seven", "squad:worf"], "maxConcurrent": 5 }
    }
}
```

Machines check `prefer` labels first, then fall through to general pool. **Not required for Phase 1.**

---

## 7. Cross-Repo Support

The protocol works identically for every repo the squad watches (tamresearch1, squad-monitor, etc.).

**Per-repo setup:**
1. Create a heartbeat issue in that repo
2. Add the repo + heartbeat issue number to `.squad/ralph-cluster-config.json`
3. All claiming/heartbeat/stale logic passes `-R $repo` to `gh` commands

**No protocol changes needed.** The `gh` CLI's `-R owner/repo` flag handles everything.

```powershell
# Example: Multi-repo heartbeat loop
$repos = @(
    @{ repo = "tamirdresher/tamresearch1"; heartbeatIssue = 999 },
    @{ repo = "tamirdresher/squad-monitor"; heartbeatIssue = 10 }
)

foreach ($r in $repos) {
    Send-ClusterHeartbeat -Repo $r.repo -HeartbeatIssueNumber $r.heartbeatIssue -MachineId $machineId -Round $round -WorkingOn $currentWork[$r.repo]
}
```

---

## 8. Changes to ralph-watch.ps1

### 8.1 Summary of Modifications

| Section | Change | Lines (est.) |
|---------|--------|-------------|
| **Top of file** | Add `Get-RalphMachineId` function, load config | +20 |
| **Before main loop** | Create/find heartbeat issue, cache config | +15 |
| **Inside main loop (top)** | Post heartbeat to heartbeat issue | +10 |
| **Inside main loop (before agency)** | Inject machineId + claiming instructions into `$prompt` | +15 |
| **Inside main loop (after agency)** | Stale detection scan (every 2nd round) | +25 |
| **New functions** | `Send-ClusterHeartbeat`, `Get-ClusterPeers`, `Find-AndReclaimStaleIssues`, `Test-ClaimWon` | +80 |
| **Total** | | **~165 lines added** |

### 8.2 Concrete Diff Sketch

```powershell
# === ADD after line 51 (after lockfile setup) ===

# Multi-machine coordination
function Get-RalphMachineId {
    $idFile = Join-Path (Get-Location) ".ralph-machine-id"
    if (Test-Path $idFile) { return (Get-Content $idFile -Raw -Encoding utf8).Trim() }
    if ($env:RALPH_MACHINE_ID) { return $env:RALPH_MACHINE_ID.Trim() }
    return ($env:COMPUTERNAME -replace '[^a-zA-Z0-9\-]', '').ToLower()
}

$machineId = Get-RalphMachineId

# Load cluster config
$clusterConfigPath = Join-Path (Get-Location) ".squad\ralph-cluster-config.json"
$clusterConfig = if (Test-Path $clusterConfigPath) {
    Get-Content $clusterConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
} else {
    [PSCustomObject]@{
        heartbeatIssues = @{}
        heartbeatIntervalMinutes = 5
        staleThresholdMinutes = 15
        staleCheckEveryNRounds = 2
    }
}

Write-Host "Ralph cluster mode: machine=$machineId" -ForegroundColor Cyan
```

```powershell
# === ADD inside main loop, after "Write-Host Round N started" ===

# Post cluster heartbeat
foreach ($repoEntry in $clusterConfig.heartbeatIssues.PSObject.Properties) {
    $hbRepo = $repoEntry.Name
    $hbIssue = $repoEntry.Value
    Send-ClusterHeartbeat -Repo $hbRepo -HeartbeatIssueNumber $hbIssue -MachineId $machineId -Round $round -WorkingOn @()
}
```

```powershell
# === MODIFY the $prompt variable to inject machine identity ===

$prompt = @"
$($existingPrompt)

MULTI-MACHINE COORDINATION:
You are machine "$machineId". Other Ralphs may be running on other machines.
BEFORE claiming any issue: check assignees. If assigned, SKIP. To claim: assign @me + comment "🔄 Claimed by $machineId at {timestamp}". Then verify assignees.count == 1. If >1, check comment timestamps — earliest wins.
Branch names: squad/{N}-{slug}-$machineId
HEARTBEAT: Post to issue #$($clusterConfig.heartbeatIssues.'tamirdresher/tamresearch1') each round.
STALE: If a claimed issue's last heartbeat is >15 min old AND the owning machine's global heartbeat is stale, reclaim it.
"@
```

```powershell
# === ADD inside main loop, after agency completes ===

# Stale detection (every Nth round)
if ($round % $clusterConfig.staleCheckEveryNRounds -eq 0) {
    foreach ($repoEntry in $clusterConfig.heartbeatIssues.PSObject.Properties) {
        Find-AndReclaimStaleIssues `
            -Repo $repoEntry.Name `
            -HeartbeatIssueNumber $repoEntry.Value `
            -MachineId $machineId `
            -StaleThresholdMinutes $clusterConfig.staleThresholdMinutes
    }
}
```

---

## 9. Rate Limit Budget

| Operation | Frequency | Calls/hour (2 machines, 2 repos) |
|-----------|-----------|----------------------------------|
| Heartbeat post | 1/round/repo | 48 |
| Heartbeat read (peer discovery) | 1/round/repo | 48 |
| Issue list (work discovery) | 1/round/repo | 48 |
| Claim attempt | ~2/round (avg) | 48 |
| Claim verify | ~2/round (on race only) | ~10 |
| Stale detection | 1/2 rounds/repo | 24 |
| **Coordination subtotal** | | **~226** |
| Baseline agent work | ~100/round/machine | 2400 |
| **Grand total** | | **~2626** |

**Headroom:** 5000 - 2626 = **2374 calls/hour remaining**. Safe for up to 5 machines.

---

## 10. Failure Modes & Mitigations

| Failure | Impact | Mitigation |
|---------|--------|------------|
| GitHub API down | No coordination | Fall back to single-machine mode; skip heartbeat/claim, work normally |
| Network partition | Machine appears dead | 15-min grace period; cross-check heartbeat board before reclaim |
| Long agent run (>15 min) | Looks stale per-issue | Cross-check GLOBAL heartbeat; if machine alive, don't reclaim |
| Two machines reclaim same stale issue | Duplicate work | Same race detection as initial claim (Section 4.2) |
| Heartbeat issue deleted | No peer discovery | Auto-recreate on next round; log warning |
| Machine ID collision | Confusing heartbeats | Startup validation: check heartbeat board for active peer with same ID, refuse to start |

---

## 11. Observability

### 11.1 What's Visible in GitHub UI

- **Heartbeat issue:** Full timeline of which machines are alive, what they're working on
- **Issue comments:** Claim/reclaim/completion audit trail
- **Issue assignees:** Current owner at a glance
- **Branch names:** Which machine created each branch

### 11.2 Local Monitoring (squad-monitor integration)

The existing `ralph-heartbeat.json` (written to `$env:USERPROFILE\.squad\`) gains a `cluster` section:

```json
{
    "lastRun": "2026-03-12T14:30:00",
    "round": 42,
    "status": "idle",
    "cluster": {
        "machineId": "local",
        "peers": {
            "devbox": { "lastSeen": "2026-03-12T14:28:00", "alive": true },
            "ci-runner": { "lastSeen": "2026-03-12T13:45:00", "alive": false }
        },
        "claimedIssues": [42, 43],
        "reclaimedThisRound": []
    }
}
```

---

## 12. Implementation Order (for Data)

### Step 1: Machine Identity + Config (30 min)
- Add `Get-RalphMachineId` to `ralph-watch.ps1`
- Create `.squad/ralph-cluster-config.json` schema
- Load config at startup

### Step 2: Heartbeat Issue Setup (30 min)
- Create heartbeat issue in tamresearch1 (manual or scripted)
- Add `Send-ClusterHeartbeat` function
- Wire into main loop

### Step 3: Coordinator Prompt Update (1 hour)
- Inject machineId + claiming instructions into `$prompt`
- Add branch namespacing instruction
- Test with single machine (should be backward compatible)

### Step 4: Stale Detection (1 hour)
- Add `Get-ClusterPeers` and `Find-AndReclaimStaleIssues`
- Wire stale check into main loop (every 2nd round)
- Add cross-check logic (global heartbeat vs per-issue)

### Step 5: Race Handling (30 min)
- Add `Test-ClaimWon` function
- Document in coordinator prompt
- Race handling is mostly in the prompt (Ralph's LLM decides)

### Step 6: Testing (2 hours)
- Test 1: Single machine — verify no behavior change
- Test 2: Two machines — verify no duplicate claims
- Test 3: Kill one machine — verify reclaim after 15 min
- Test 4: Simulate race — verify tiebreaker works
- Test 5: Long agent run — verify NOT reclaimed while machine alive

### Step 7: squad-monitor Integration (1 hour)
- Repeat Steps 1-2 for squad-monitor repo
- Add repo to config JSON
- Test cross-repo heartbeat

**Total estimated effort: 7-8 hours (1 day)**

---

## 13. What This Protocol Does NOT Do

- **Load balancing**: No active balancing. "First to claim wins" is sufficient for 2-5 machines.
- **Agent-level coordination**: This protocol coordinates issue-level work. Two agents on the same machine don't need this.
- **Conflict resolution on code**: If two machines somehow produce competing PRs, humans resolve. The protocol prevents this from happening in the first place.
- **Persistence**: No database. All state is in GitHub (comments, assignments) and local config files. A machine can crash and restart cleanly by reading GitHub state.

---

## Appendix A: Configuration File Reference

**`.squad/ralph-cluster-config.json`**

```json
{
    "machineId": "local",
    "heartbeatIssues": {
        "tamirdresher/tamresearch1": 999,
        "tamirdresher/squad-monitor": 10
    },
    "heartbeatIntervalMinutes": 5,
    "staleThresholdMinutes": 15,
    "staleCheckEveryNRounds": 2,
    "raceBackoffMinSec": 5,
    "raceBackoffMaxSec": 15,
    "enabled": true
}
```

**`.ralph-machine-id`** (repo root, gitignored)

```
local
```

## Appendix B: gh CLI Commands Quick Reference

| Action | Command |
|--------|---------|
| List unclaimed issues | `gh issue list -R {repo} --label squad:copilot --state open --json number,assignees --jq '.[] \| select(.assignees \| length == 0)'` |
| Claim issue | `gh issue edit {N} -R {repo} --add-assignee @me` |
| Post claim comment | `gh issue comment {N} -R {repo} --body "🔄 Claimed by {id} at {ts}"` |
| Verify claim | `gh issue view {N} -R {repo} --json assignees` |
| Release claim | `gh issue edit {N} -R {repo} --remove-assignee @me` |
| Post heartbeat | `gh issue comment {N} -R {repo} --body "⏱️ Heartbeat \| {id} \| Round {R} \| {ts}"` |
| Read heartbeats | `gh issue view {N} -R {repo} --json comments --jq '.comments[-50:]'` |
| Reclaim stale | Remove assignee → re-assign → comment with ♻️ |
