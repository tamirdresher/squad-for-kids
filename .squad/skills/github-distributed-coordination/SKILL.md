# Skill: GitHub-Native Distributed Coordination

**Confidence:** high  
**Domain:** distributed-systems, coordination, multi-machine  
**Last validated:** 2026-03-12

## Context

When multiple autonomous agents or processes need to coordinate work without duplicate effort, **GitHub can serve as the coordination backend** using native features (comments, labels, timestamps) instead of external infrastructure (Redis, databases, message queues).

This pattern enables distributed work claiming with automatic recovery, zero new infrastructure, and complete transparency.

## Use Cases

✅ **Good fit for:**
- Multi-machine agents working same issue board (e.g., Ralph on multiple machines)
- Distributed job processors claiming tasks from GitHub issues
- Automated workflows with failover (machine crashes, network loss)
- Scenarios requiring audit trail of who-did-what-when

❌ **Not suitable for:**
- High-frequency coordination (>100 ops/min) — GitHub API rate limits
- Real-time locking (<1s latency) — GitHub API has ~1-3s roundtrip
- Large-scale coordination (>1000 concurrent workers) — API limits
- Critical safety systems requiring guaranteed consistency

## Architecture Pattern

### 1. Machine Identity

Each process identifies itself with a stable, unique machine ID:

```powershell
$machineId = if ($env:MACHINE_ID) { 
    $env:MACHINE_ID 
} else { 
    # Fallback: sanitized hostname
    [System.Net.Dns]::GetHostName() -replace '[^a-zA-Z0-9-]', '-'
}
```

### 2. Work Claiming Protocol

**Claim via atomic GitHub comment:**

```powershell
function Claim-Work {
    param([int]$IssueNumber, [string]$MachineId, [int]$LeaseMinutes = 15)
    
    # 1. Check existing claims
    $existingClaim = gh issue view $IssueNumber --json comments --jq \
        ".comments[] | select(.body | contains('🔄 Claimed by')) | .body" | 
        Select-Object -Last 1
    
    if ($existingClaim -and $existingClaim -notmatch "Claimed by $MachineId") {
        # Extract timestamp and check if lease expired
        if ($existingClaim -match "at (\S+)") {
            $claimedAt = [DateTime]::Parse($Matches[1])
            $age = (Get-Date) - $claimedAt
            if ($age.TotalMinutes -lt $LeaseMinutes) {
                return $false  # Still claimed by another machine
            }
        }
    }
    
    # 2. Post claim comment (atomic operation)
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    gh issue comment $IssueNumber --body "🔄 Claimed by $MachineId at $timestamp (lease: ${LeaseMinutes}m)"
    
    # 3. Add machine label for visibility
    gh issue edit $IssueNumber --add-label "machine:$MachineId:active"
    
    return $true
}
```

**Release claim on completion:**

```powershell
function Release-Claim {
    param([int]$IssueNumber, [string]$MachineId, [string]$Reason = "completed")
    
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    gh issue comment $IssueNumber --body "✅ Released by $MachineId at $timestamp — $Reason"
    gh issue edit $IssueNumber --remove-label "machine:$MachineId:active"
}
```

### 3. Stale Work Recovery

**Automatic reclaim of orphaned work:**

```powershell
function Recover-StaleWork {
    param([string]$MachineId, [int]$StaleThresholdMinutes = 15)
    
    # Find all issues with active machine labels
    $staleIssues = gh issue list --json number,labels,comments --label "machine:*:active" --state open | 
        ConvertFrom-Json | Where-Object {
            $issue = $_
            $claimComment = $issue.comments | Where-Object { $_.body -match "🔄 Claimed by" } | Select-Object -Last 1
            
            if ($claimComment -and $claimComment.body -match "at (\S+)") {
                $claimedAt = [DateTime]::Parse($Matches[1])
                $age = (Get-Date) - $claimedAt
                # Stale if older than threshold and not our claim
                return ($age.TotalMinutes -gt $StaleThresholdMinutes -and 
                        $claimComment.body -notmatch "Claimed by $MachineId")
            }
            return $false
        }
    
    foreach ($issue in $staleIssues) {
        # Remove stale label
        $staleLabel = $issue.labels | Where-Object { $_.name -match "machine:.*:active" }
        if ($staleLabel) {
            gh issue edit $issue.number --remove-label $staleLabel.name
        }
        
        # Mark as available for reclaim
        gh issue comment $issue.number --body "⚠️ Lease expired, available for reclaim"
    }
}
```

### 4. Heartbeat Protocol

**Keep lease active for long-running work:**

```powershell
function Update-Heartbeat {
    param([int]$IssueNumber, [string]$MachineId)
    
    # Update timestamp in existing claim comment
    $commentId = gh api "repos/{owner}/{repo}/issues/$IssueNumber/comments" --jq \
        ".[] | select(.body | contains('Claimed by $MachineId')) | .id" | 
        Select-Object -Last 1
    
    if ($commentId) {
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        gh api "repos/{owner}/{repo}/issues/$IssueNumber/comments/$commentId" \
            -X PATCH -f body="🔄 Claimed by $MachineId (heartbeat: $timestamp)"
    }
}
```

## Integration Pattern

**In a polling loop (e.g., Ralph watch script):**

```powershell
while ($true) {
    # 1. Recover stale work at round start
    Recover-StaleWork -MachineId $machineId
    
    # 2. Find actionable issues
    $actionableIssues = gh issue list --label "status:ready" --state open --json number | ConvertFrom-Json
    
    # 3. Claim and process
    foreach ($issue in $actionableIssues) {
        if (Claim-Work -IssueNumber $issue.number -MachineId $machineId) {
            # Work on issue
            Process-Issue -IssueNumber $issue.number -MachineId $machineId
            
            # Release claim
            Release-Claim -IssueNumber $issue.number -MachineId $machineId -Reason "completed"
        } else {
            # Already claimed by another machine, skip
            Write-Host "Issue #$($issue.number) claimed by another machine, skipping"
        }
    }
    
    Start-Sleep -Seconds 300  # 5 min interval
}
```

## Key Design Principles

1. **Comments as immutable logs** — GitHub preserves creation timestamps, providing natural ordering
2. **Labels for visibility** — Human operators can see machine activity at a glance
3. **Lease-based claiming** — Prevents indefinite starvation if a machine fails
4. **UTC timestamps** — Avoids clock skew issues across machines
5. **Idempotent operations** — Re-claiming own work is safe
6. **Graceful degradation** — API failures don't break the system, just delay coordination

## Limitations & Tradeoffs

### Rate Limits
- GitHub API: 5,000 requests/hour for authenticated users
- Comment edits: No documented limit but subject to abuse detection
- **Mitigation:** Cache claim state locally, only sync on round boundaries

### Latency
- GitHub API roundtrip: 1-3 seconds typical
- Comment propagation: Eventually consistent (usually <5s)
- **Mitigation:** Use appropriate lease duration (>5 min recommended)

### Race Conditions
- Two machines claiming simultaneously → both may succeed briefly
- GitHub comment ordering resolves this (later claim is visible to both)
- **Mitigation:** Post-claim verification — read back claim comment, verify yours is latest

### Clock Skew
- Machines with different system times may miscalculate lease expiration
- **Mitigation:** Use UTC timestamps, add ±2 min tolerance window

## Observability

**What to track:**
- Claims per machine per hour (detect imbalance)
- Stale work recoveries (detect failing machines)
- Claim conflicts (race condition frequency)
- API rate limit consumption

**Where to log:**
- Machine-local heartbeat file: `~/.coordination/heartbeat.json`
- GitHub labels: `machine:{id}:active` visible in UI
- Issue comments: Complete audit trail

## Related Patterns

- **Leader election:** Use this pattern with "claim issue #0" convention
- **Job queue:** Issues as jobs, labels as queue metadata
- **Failover coordination:** Primary/secondary machine coordination

## Example: Multi-Machine Ralph (Issue #346)

See `.squad/decisions/inbox/picard-ralph-coordination-design.md` for full implementation of this pattern in the Ralph watch script.

**Key adaptation:**
- Machine ID: hostname or `RALPH_MACHINE_ID` env var
- Work items: GitHub issues with `squad:*` labels
- Lease duration: 15 minutes
- Branch namespacing: `squad/{issue}-{slug}-{machineId}` prevents push conflicts

---

## References

- **Issue #346:** Multi-machine Ralph coordination design
- **GitHub API:** [Issues](https://docs.github.com/en/rest/issues), [Comments](https://docs.github.com/en/rest/issues/comments)
- **Distributed locks:** [Martin Kleppmann — How to do distributed locking](https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html)

**Pattern origin:** Picard (Lead), 2026-03-12, tamresearch1 repository
