# Multi-Agent Conflict Protocol

## The Problem

`refs/notes/squad/data` is a single ref. It holds at most one JSONL blob per commit SHA. When two Data instances on different machines both finish annotating commit `abc1234` at the same time:

```
Time T+0: Data-m1 fetches refs/notes/squad/data — no note for abc1234
Time T+0: Data-m2 fetches refs/notes/squad/data — no note for abc1234
Time T+1: Data-m1 appends note, pushes → SUCCESS (first writer wins)
Time T+2: Data-m2 appends note, pushes → REJECTED (non-fast-forward)
```

Data-m2's push fails because the remote ref has moved forward (Data-m1 already pushed a note blob for this namespace). Data-m2 now has a conflict to resolve.

---

## Architecture Decision: Per-Role Namespaces

**Decision: use per-agent-ROLE namespaces, not per-agent-INSTANCE namespaces.**

The alternative — `refs/notes/squad/data-machine1`, `refs/notes/squad/data-machine2` — avoids the conflict entirely but creates a worse problem: consumers of the notes (Ralph, humans using `git notes show`) must enumerate all instance namespaces. Three machines running Data means three fetches, three reads, three merges in the consumer's code. When you add a fourth machine, all consumers need updating.

Per-role namespaces mean one namespace, all instances write there, all consumers read from one place. The `instanceId` field inside each JSONL entry provides deduplication and tracing. Conflicts are resolved at write time via the protocol below.

**This decision is non-negotiable for this reference implementation.** If you find yourself tempted to use per-instance namespaces, re-read Q's objection: the conflict is at write time, which is operationally containable. The per-instance explosion is a design debt that compounds.

---

## Note Format Requirement

All notes MUST be JSONL — one JSON object per line, no trailing comma, no wrapping array. This is what enables the `cat_sort_uniq` merge strategy and what `git notes append` produces.

```jsonl
{"v":1,"agent":"data","instanceId":"data-machine1","timestamp":"2026-03-25T02:14:00Z","commitSha":"abc1234...","type":"decision","content":{"summary":"Use JWT for auth middleware","reasoning":"Existing auth.go uses JWT on lines 47-89. Adding API key strategy requires refactoring auth interceptor.","confidence":"high","promotionCandidate":true},"refs":{"prNumber":57},"tags":["auth","jwt"]}
{"v":1,"agent":"data","instanceId":"data-machine2","timestamp":"2026-03-25T02:18:33Z","commitSha":"abc1234...","type":"context","content":{"summary":"JWT secret rotation handled by existing KeyVault integration","confidence":"medium","promotionCandidate":false},"refs":{"prNumber":57},"tags":["auth","keyvault"]}
```

Each line is a self-contained JSON record. No multi-line JSON. No pretty-printing. The timestamp+instanceId combination is the deduplication key.

---

## Retry Protocol (PowerShell Reference Implementation)

```powershell
function Write-SquadNote {
    param(
        [string]$Namespace,      # e.g. "data"
        [string]$CommitSha,      # full 40-char SHA
        [hashtable]$NoteContent, # will be serialized to JSONL line
        [int]$MaxRetries = 5
    )

    $ref = "refs/notes/squad/$Namespace"
    $noteJson = $NoteContent | ConvertTo-Json -Compress -Depth 10

    for ($attempt = 0; $attempt -lt $MaxRetries; $attempt++) {
        # Step 1: Fetch latest remote state for this namespace
        # This overwrites local ref with remote. Do it FIRST, before appending.
        git fetch origin "${ref}:${ref}" 2>&1 | Out-Null
        # Ignore fetch errors — remote namespace may not exist yet (first write)

        # Step 2: Append OUR content on top of the now-current remote state
        git notes --ref=$ref append -m $noteJson $CommitSha
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[notes] Append failed on attempt $attempt — retrying"
            continue
        }

        # Step 3: Push
        $pushOutput = git push origin "${ref}:${ref}" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Verbose "[notes] Wrote note to $ref for $($CommitSha.Substring(0,8))"
            return $true
        }

        # Step 4: Push rejected — another writer won the race
        # Log it, then loop back to Step 1 (fetch + re-append + retry)
        Write-Warning "[notes] Push rejected (attempt $($attempt+1)/$MaxRetries) — conflict on $ref"

        # Exponential backoff with jitter: 2^n seconds + up to 1s jitter
        $backoffSecs = [Math]::Pow(2, $attempt) + (Get-Random -Maximum 1000) / 1000.0
        Start-Sleep -Seconds $backoffSecs
    }

    # All retries exhausted — write to failed queue for Ralph to process
    $failedQueuePath = ".squad/notes-failed-queue"
    New-Item -ItemType Directory -Path $failedQueuePath -Force | Out-Null
    $failedEntry = @{
        timestamp   = (Get-Date -Format 'o')
        namespace   = $Namespace
        commitSha   = $CommitSha
        noteContent = $NoteContent
        reason      = "max_retries_exhausted"
    }
    $failedEntry | ConvertTo-Json | Out-File "$failedQueuePath/$Namespace-$(Get-Date -Format 'yyyyMMddHHmmss').json"
    Write-Error "[notes] Failed to write note after $MaxRetries attempts — queued for Ralph"
    return $false
}
```

### Why This Works

The key insight: **fetch-then-append-then-push** rather than **append-then-fetch-then-merge-then-push**.

The naive approach (append first, then handle rejection) requires you to merge your local blob with the remote blob after the fact. This is error-prone because after a failed push and a fetch, git has overwritten your local ref with the remote state. Your appended content still exists in the NOTES_EDITMSG or similar — but recovering it cleanly requires knowing git internals.

The correct approach: fetch first (get latest), append on top of latest (now you have a fast-forward), push. If someone else pushes between your fetch and your push (a true race), retry from the top. The window is milliseconds. In practice, retries beyond attempt 1 are rare.

---

## Blob-Level Conflict: `cat_sort_uniq` Merge Strategy

In the extreme case where the retry protocol still results in a conflict (both agents wrote at byte-for-byte the same nanosecond and both fetched the same empty state), git notes merge resolves it:

```bash
# If git notes push still fails after retries, use merge as last resort
git fetch origin "refs/notes/squad/data:refs/notes/remotes/origin/squad/data"
git notes merge -s cat_sort_uniq refs/notes/remotes/origin/squad/data
git push origin "refs/notes/squad/data"
```

`cat_sort_uniq` concatenates the two blobs, sorts all lines, and deduplicates identical lines. Since each JSONL entry is a unique JSON object (unique timestamp + instanceId), no valid entry is ever dropped. Sorting may reorder entries (oldest-first alphabetically by timestamp field — ISO-8601 sorts correctly), which is fine.

**Never use `git notes merge -s ours` or `-s theirs`** — these discard one side's content entirely.

---

## Failed Queue Processing

Ralph checks `.squad/notes-failed-queue/` every round. For each queued file:

1. Parse the failed note
2. Run `Write-SquadNote` with the original content
3. If successful, delete the queued file
4. If still failing after another 5 attempts: escalate via Teams notification

The failed queue is a `.gitignore`d local directory — it is NOT committed to the repo. It's machine-local state. If a machine crashes without processing its queue, those notes are lost. This is an acceptable tradeoff: git notes are commit-scoped context, not the primary state store. The important decisions will be re-generated if the context is reconstructed.

---

## Decision Summary

| Question | Answer |
|----------|--------|
| Per-role or per-instance namespaces? | **Per-role.** One namespace per agent role. |
| What if two instances write same commit? | Fetch → append → push retry loop with exponential backoff |
| Max retries | 5, then fail to local queue |
| Blob merge strategy (last resort) | `cat_sort_uniq` — never drops content |
| Note format requirement | **JSONL only** — one JSON object per line, no wrapping |
| Can notes be edited after the fact? | Never. Append only. Add a new entry with `supersedes` field instead. |
