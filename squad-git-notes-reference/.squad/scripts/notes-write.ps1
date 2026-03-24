#!/usr/bin/env pwsh
# .squad/scripts/notes-write.ps1
# Write a squad note for a commit with schema validation.
# Called by agents after completing work on a commit.
#
# Usage:
#   .squad/scripts/notes-write.ps1 -Agent data -CommitSha <sha> -NoteContent @{...}
#
# Parameters:
#   -Agent          Agent role name (data|worf|belanna|picard|q|scribe|ralph)
#   -CommitSha      Full 40-char SHA of the commit to annotate
#   -NoteContent    Hashtable with the note content (will be merged with envelope fields)
#   -SessionId      (optional) Copilot CLI session ID; auto-detected if not provided
#   -MaxRetries     (optional) Max push retry attempts; default 5

param(
    [Parameter(Mandatory)][string]$Agent,
    [Parameter(Mandatory)][string]$CommitSha,
    [Parameter(Mandatory)][hashtable]$NoteContent,
    [string]$SessionId = "",
    [int]$MaxRetries = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Validate agent name
$validAgents = @('data','worf','belanna','picard','q','scribe','ralph')
if ($Agent -notin $validAgents) {
    Write-Error "Invalid agent name '$Agent'. Must be one of: $($validAgents -join ', ')"
    exit 1
}

# Validate commit SHA
if ($CommitSha -notmatch '^[0-9a-f]{40}$') {
    Write-Error "Invalid commit SHA '$CommitSha'. Must be a full 40-character hex SHA."
    exit 1
}

# Auto-detect instanceId from machine config
$squadConfig = Join-Path (git rev-parse --show-toplevel) ".squad/config.json"
$machineId = if (Test-Path $squadConfig) {
    (Get-Content $squadConfig | ConvertFrom-Json).machineId
} else {
    $env:COMPUTERNAME
}
$instanceId = "$Agent-$machineId"

# Build the note envelope
$noteEntry = @{
    v          = 1
    agent      = $Agent
    instanceId = $instanceId
    sessionId  = if ($SessionId) { $SessionId } else { [System.Guid]::NewGuid().ToString() }
    timestamp  = (Get-Date -Format 'o').Replace('+00:00', 'Z')
    commitSha  = $CommitSha
    type       = $NoteContent.type ?? "context"
    content    = @{
        summary    = $NoteContent.summary ?? "(no summary)"
        reasoning  = $NoteContent.reasoning ?? ""
        alternatives = $NoteContent.alternatives ?? @()
        confidence = $NoteContent.confidence ?? "medium"
        promotionCandidate = $NoteContent.promotionCandidate ?? $false
    }
    refs = @{
        prNumber       = $NoteContent.prNumber ?? $null
        workItemId     = $NoteContent.workItemId ?? $null
        relatedCommits = $NoteContent.relatedCommits ?? @()
        supersedes     = $NoteContent.supersedes ?? $null
    }
    tags = $NoteContent.tags ?? @()
}

# Add severity if type=finding
if ($noteEntry.type -eq 'finding') {
    $noteEntry.content.severity = $NoteContent.severity ?? "medium"
}

$noteJson = $noteEntry | ConvertTo-Json -Compress -Depth 10
$ref = "refs/notes/squad/$Agent"

Write-Verbose "[notes-write] Writing to $ref for commit $($CommitSha.Substring(0,8))"

# Retry loop: fetch → append → push
for ($attempt = 0; $attempt -lt $MaxRetries; $attempt++) {
    # Step 1: Fetch latest remote state for this namespace
    # Errors OK — namespace may not exist yet (first write)
    git fetch origin "${ref}:${ref}" 2>&1 | Out-Null

    # Step 2: Append on top of current (fetched) state
    $appendResult = git notes --ref=$ref append -m $noteJson $CommitSha 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "[notes-write] Append failed (attempt $($attempt+1)): $appendResult"
        continue
    }

    # Step 3: Push
    $pushResult = git push origin "${ref}:${ref}" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[notes-write] ✓ Note written to $ref for $($CommitSha.Substring(0,8))" -ForegroundColor Green
        exit 0
    }

    # Push rejected — backoff and retry
    Write-Warning "[notes-write] Push rejected (attempt $($attempt+1)/$MaxRetries) — $($pushResult | Select-Object -Last 1)"
    $backoff = [Math]::Pow(2, $attempt) + (Get-Random -Maximum 1000) / 1000.0
    Start-Sleep -Seconds $backoff
}

# All retries exhausted — write to failed queue
$failedQueuePath = Join-Path (git rev-parse --show-toplevel) ".squad/notes-failed-queue"
New-Item -ItemType Directory -Path $failedQueuePath -Force | Out-Null
$failedEntry = @{
    timestamp   = (Get-Date -Format 'o')
    namespace   = $Agent
    commitSha   = $CommitSha
    noteContent = $noteEntry
    reason      = "max_retries_exhausted"
} | ConvertTo-Json -Depth 10
$failedFile = Join-Path $failedQueuePath "$Agent-$(Get-Date -Format 'yyyyMMddHHmmss').json"
$failedEntry | Out-File $failedFile -Encoding utf8
Write-Warning "[notes-write] Failed after $MaxRetries attempts. Queued at $failedFile for Ralph to retry."
exit 1
