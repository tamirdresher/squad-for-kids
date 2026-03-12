# What We Built — Custom Components in This Repo

**Prepared for:** Brady Gaster × Tamir Dresher sync (45 min)  
**Date:** July 2025  
**Scope:** Novel tooling only — assumes you already know how Squad works (routing, charters, decisions inbox, etc.)

---

## Table of Contents

1. [Ralph Watch Loop](#1-ralph-watch-loop)
2. [Squad Monitor Dashboard](#2-squad-monitor-dashboard)
3. [Outlook COM Automation](#3-outlook-com-automation)
4. [Teams Integration](#4-teams-integration)
5. [Podcaster](#5-podcaster)
6. [Neelix & Kes — Custom Squad Members](#6-neelix--kes--custom-squad-members)
7. [cli-tunnel](#7-cli-tunnel)
8. [Key Lessons Learned](#8-key-lessons-learned)

---

## 1. Ralph Watch Loop

**File:** `ralph-watch.ps1` (~570 lines)

An infinite-loop PowerShell script that invokes `agency copilot` every 5 minutes — the autonomous heartbeat that makes the squad self-running.

### 1.1 Round Lifecycle

```
┌──────────────────────────────────────────────┐
│              Ralph Round N                    │
├──────────────────────────────────────────────┤
│  1. Heartbeat → status: "running"             │
│  2. Run Squad Scheduler (cron + interval)     │
│  3. git fetch && git pull (stash if dirty)    │
│  4. agency copilot --yolo --autopilot         │
│     --agent squad -p $prompt                  │
│  5. Parse metrics from output (regex)         │
│  6. Heartbeat → status: "idle" / "error"      │
│  7. Structured log entry                      │
│  8. Rotate logs if > 500 entries / 1MB        │
│  9. Teams alert if ≥3 consecutive failures    │
│ 10. Sleep 5 minutes → repeat                  │
└──────────────────────────────────────────────┘
```

### 1.2 Single-Instance Mutex Guard

Running two Ralph instances = duplicate PRs, merge conflicts, double-triaging. Three layers prevent this:

```powershell
# Layer 1: System-wide named mutex
$mutexName = "Global\RalphWatch_tamresearch1"
$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$acquired = $false
try { $acquired = $mutex.WaitOne(0) }
catch [System.Threading.AbandonedMutexException] { $acquired = $true }  # crashed predecessor
if (-not $acquired) {
    Write-Host "ERROR: Another Ralph instance is already running" -ForegroundColor Red
    exit 1
}

# Layer 2: Kill stale processes (not us)
$staleRalphs = Get-CimInstance Win32_Process |
    Where-Object { $_.CommandLine -match 'ralph-watch' -and $_.ProcessId -ne $PID }
foreach ($stale in $staleRalphs) {
    Stop-Process -Id $stale.ProcessId -Force -ErrorAction SilentlyContinue
}

# Layer 3: Lockfile (Squad Monitor reads this to show Ralph's state)
$lockFile = Join-Path (Get-Location) ".ralph-watch.lock"
[ordered]@{
    pid = $PID
    started = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
    directory = (Get-Location).Path
} | ConvertTo-Json | Out-File $lockFile -Encoding utf8 -Force
```

The `AbandonedMutexException` catch is critical — if Ralph crashed without releasing the mutex, .NET throws this instead of returning `false`. Catching it = no deadlock after crashes.

Cleanup via `Register-EngineEvent PowerShell.Exiting` + `trap` covers graceful exit and Ctrl+C.

### 1.3 PS 5.1 Stderr Nightmare

Windows ships PS 5.1 which converts ANY native stderr to `NativeCommandError` exceptions. The `agency` CLI writes emoji banners to stderr. Ralph thought every round failed.

```powershell
# Fix UTF-8 rendering first
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Suppress stderr-to-error conversion, call agency WITHOUT pipes
$ErrorActionPreference_saved = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
agency copilot --yolo --autopilot --agent squad -p $prompt
$exitCode = $LASTEXITCODE
$ErrorActionPreference = $ErrorActionPreference_saved
```

**Cannot pipe** the agency command — no `| Tee-Object`, no `2>&1` — because piping in PS 5.1 breaks `$LASTEXITCODE`.

### 1.4 Heartbeat System

JSON status file updated before/after each round. A background runspace bumps `lastHeartbeat` every 30 seconds so Squad Monitor can distinguish "alive and working" from "stuck":

```powershell
function Update-Heartbeat {
    param([int]$Round, [string]$Status, [int]$ExitCode = 0,
          [double]$DurationSeconds = 0, [int]$ConsecutiveFailures = 0, [hashtable]$Metrics = @{})
    
    $heartbeat = [ordered]@{
        lastRun = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        lastHeartbeat = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        round = $Round; status = $Status; exitCode = $ExitCode
        durationSeconds = [math]::Round($DurationSeconds, 2)
        consecutiveFailures = $ConsecutiveFailures; pid = $PID
    }
    if ($Metrics.Count -gt 0) {
        $heartbeat["metrics"] = [ordered]@{
            issuesClosed = if ($Metrics.ContainsKey("issuesClosed")) { $Metrics.issuesClosed } else { 0 }
            prsMerged = if ($Metrics.ContainsKey("prsMerged")) { $Metrics.prsMerged } else { 0 }
            agentActions = if ($Metrics.ContainsKey("agentActions")) { $Metrics.agentActions } else { 0 }
        }
    }
    $heartbeat | ConvertTo-Json | Out-File -FilePath $heartbeatFile -Encoding utf8 -Force
}
```

### 1.5 Activity Monitor Runspace

Background runspace tails agency session logs every 30 seconds — without this, Ralph looks frozen during 10+ minute rounds:

```powershell
$activityRunspace = [PowerShell]::Create()
$activityRunspace.AddScript({
    param($RoundNum, $HeartbeatFile, $AgencyLogDir, $RoundStart)
    $seenLines = @{}
    while ($true) {
        Start-Sleep -Seconds 30
        $elapsed = (Get-Date) - $RoundStart
        $elapsedStr = "{0}m {1:00}s" -f [math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
        
        $latestSession = Get-ChildItem $AgencyLogDir -Directory -EA SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestSession) {
            $logFiles = Get-ChildItem $latestSession.FullName -Filter "*.log" -EA SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $newContent = Get-Content $logFiles.FullName -Tail 20 -EA SilentlyContinue
            foreach ($line in $newContent) {
                if (-not $seenLines.ContainsKey($line) -and
                    $line -match "(spawn|agent|merge|close|commit|push|label|issue|PR)") {
                    [Console]::WriteLine("  [$(Get-Date -f HH:mm:ss)] Round $RoundNum ($elapsedStr) | $($line.Trim().Substring(0,100))")
                    $seenLines[$line] = $true
                }
            }
        }
    }
}).AddArgument($round).AddArgument($heartbeatFile).AddArgument("$env:USERPROFILE\.agency\logs").AddArgument($roundStartTime)
$activityHandle = $activityRunspace.BeginInvoke()
```

Output looks like:
```
  [14:23:15] Round 42 (1m 15s) | spawn agent: Data fixing #169
  [14:23:45] Round 42 (1m 45s) | merged PR #167
  [14:24:15] Round 42 (2m 15s) | close issue #165
```

### 1.6 Window Title (OSC Escapes)

Three methods because different terminals respond to different APIs:

```powershell
$Host.UI.RawUI.WindowTitle = "Ralph Watch - Round $round"     # Classic PowerShell
[Console]::Title = "Ralph Watch - Round $round"                # .NET
Write-Host "`e]0;Ralph Watch - Round $round`a" -NoNewline     # OSC for Windows Terminal tabs
```

### 1.7 Scheduler Integration

Before each agency call, Ralph evaluates cron/interval tasks from `schedule.json`:

```powershell
$scheduleResult = & ".squad\scripts\Invoke-SquadScheduler.ps1" `
    -ScheduleFile ".\.squad\schedule.json" `
    -StateFile ".\.squad\monitoring\schedule-state.json" `
    -Provider "local-polling"
```

Schedule includes: daily digest (8 AM), daily RP briefing (7 AM Israel), ADR checks (weekdays), Teams message monitoring (every 20 min), tech news scan (daily).

### 1.8 WorkIQ Chaining in the Prompt

The ~80-line prompt Ralph sends to `agency copilot` chains Teams/email scanning:

```
TEAMS & EMAIL MONITORING (do this EVERY round):
1. Use workiq-ask_work_iq to check: "What Teams messages in the last
   30 minutes mention Tamir, squad, DK8S, reviews, action items?"
2. Use workiq-ask_work_iq to check: "Any emails sent to Tamir in the
   last hour that need a response or contain action items?"
3. For each actionable item: create a GitHub issue with label "teams-bridge"
   OR comment on an existing related issue. Do NOT create duplicates.
```

The prompt also chains **Neelix** (send styled Teams broadcasts for newsworthy events) and **Podcaster** (auto-generate audio for deliverables >500 words).

### 1.9 Teams Failure Alerts

After 3+ consecutive failures, fires a MessageCard to Teams:

```powershell
function Send-TeamsAlert {
    param([int]$Round, [int]$ConsecutiveFailures, [int]$ExitCode, [hashtable]$Metrics = @{})
    $webhookUrl = (Get-Content "$env:USERPROFILE\.squad\teams-webhook.url" -Raw).Trim()
    $message = @{
        "@type" = "MessageCard"; themeColor = "FF0000"; title = "⚠️ Ralph Watch Alert"
        sections = @(@{
            activityTitle = "Ralph watch has experienced $ConsecutiveFailures consecutive failures"
            facts = @(
                @{ name = "Round"; value = $Round },
                @{ name = "Consecutive Failures"; value = $ConsecutiveFailures },
                @{ name = "Last Exit Code"; value = $ExitCode }
            )
        })
    }
    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body ($message | ConvertTo-Json -Depth 10) -ContentType "application/json"
}
```

### 1.10 Log Rotation

288 rounds/day at 5-min intervals. Cap at 500 entries OR 1MB:

```powershell
function Invoke-LogRotation {
    $fileInfo = Get-Item $logFile
    if ($fileInfo.Length -gt $maxLogBytes -or
        (Get-Content $logFile | Measure-Object -Line).Lines -gt $maxLogEntries) {
        $kept = Get-Content $logFile | Select-Object -Last ($maxLogEntries - 1)
        @("# Ralph Watch Log - Rotated $(Get-Date) (kept last $($maxLogEntries - 1) entries)") + $kept |
            Out-File -FilePath $logFile -Encoding utf8 -Force
    }
}
```

---

## 2. Squad Monitor Dashboard

**Public repo:** [github.com/tamirdresher/squad-monitor](https://github.com/tamirdresher/squad-monitor)  
**Stack:** .NET 8 + Spectre.Console

### 2.1 What It Shows

7 panels in full dashboard mode (toggle orchestration-only view with `O` key):

| Panel | Source |
|-------|--------|
| Automation Watch Loop | Ralph's heartbeat JSON |
| Recent Rounds | Structured log parsing |
| GitHub Issues | `gh issue list --label squad` |
| Open PRs | `gh pr list` with review + CI status |
| Recently Merged PRs | `gh pr list --state merged` |
| **Live Agent Activity** | Tailing `~/.agency/logs/` in real time |
| Orchestration History | `.squad/orchestration-log/` files |

### 2.2 Live Agent Feed — AgentLogParser

The most novel component. Tails Copilot CLI's internal session logs (`~/.agency/logs/session_{id}/process-{pid}-{agent}.log`) to extract what agents are doing right now:

```csharp
public class AgentLogParser
{
    private readonly Dictionary<string, long> _filePositions = new();
    private readonly List<AgentLogEntry> _recentEntries = new();

    public void ParseLatestLogs()
    {
        // Top 3 most recent sessions, top 2 log files each
        var sessionDirs = Directory.GetDirectories(_logDirectory, "session_*")
            .OrderByDescending(Directory.GetLastWriteTime).Take(3);

        foreach (var sessionDir in sessionDirs)
        {
            var logFiles = Directory.GetFiles(sessionDir, "process-*.log")
                .OrderByDescending(File.GetLastWriteTime).Take(2);
            foreach (var logFile in logFiles)
                ParseLogFile(logFile);
        }
    }

    private void ParseLogFile(string filePath)
    {
        // Seek to last-known position (FileShare.ReadWrite for concurrent access)
        using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        fs.Seek(_filePositions.GetValueOrDefault(filePath, Math.Max(0, new FileInfo(filePath).Length - 50000)),
                SeekOrigin.Begin);
        using var reader = new StreamReader(fs);

        string? line;
        while ((line = reader.ReadLine()) != null)
            ParseLogLine(line, Path.GetFileName(filePath));

        _filePositions[filePath] = new FileInfo(filePath).Length;
    }
}
```

Four event types extracted:

```csharp
// Tool invocations
var toolMatch = Regex.Match(line, @"Tool invocation result:\s*([^\s]+)");

// Sub-agent spawns (explore, task, general-purpose)
if (line.Contains("\"agent_type\":"))  // → "Spawned explore agent: Find auth config"

// Background task launches
if (line.Contains("\"name\": \"task\""))  // → "Background task: Run tests"

// Completions
if (Regex.IsMatch(line, @"(agent|task)\s+(completed|finished|done)"))
```

Agent name extracted from filename pattern `process-{pid}-{agent}.log`.

### 2.3 Dynamic Terminal Height

Tables truncate to fit whatever terminal size you have:

```csharp
int termHeight = 50;
try { termHeight = Console.WindowHeight; } catch { }
int reservedLines = 38;
int maxIssueRows = Math.Max(3, (termHeight - reservedLines) / 3);
```

### 2.4 Spectre.Console Live Mode

Flicker-free auto-refresh with keyboard toggle:

```csharp
await AnsiConsole.Live(layout).AutoClear(false).StartAsync(async ctx =>
{
    do
    {
        if (Console.KeyAvailable)
        {
            var key = Console.ReadKey(intercept: true);
            if (key.Key == ConsoleKey.O)
                orchestrationOnlyMode = !orchestrationOnlyMode;
        }
        agentLogParser.ParseLatestLogs();
        var content = orchestrationOnlyMode
            ? BuildOrchestrationOnlyContent(...) : BuildDashboardContent(...);
        layout.Update(content);
        ctx.Refresh();
        await Task.Delay(interval * 1000);
    } while (true);
});
```

### 2.5 GitHub Integration

PR status uses review decision + CI rollup for colored indicators:

```csharp
var reviewStatus = reviewDecision switch
{
    "APPROVED" => "[green]✓[/]",
    "CHANGES_REQUESTED" => "[red]✗[/]",
    "REVIEW_REQUIRED" => "[yellow]?[/]",
    _ => "[dim]—[/]"
};

// CI: Check ALL runs — success only if every check passes
var allSuccess = statuses.All(s => /* CheckRun.conclusion == "SUCCESS" */);
var anyPending = statuses.Any(s => /* status == "IN_PROGRESS" || "QUEUED" */);
ciStatus = allSuccess ? "[green]✓[/]" : anyPending ? "[yellow]…[/]" : "[red]✗[/]";
```

---

## 3. Outlook COM Automation

**Skill file:** `.squad/skills/outlook-automation/SKILL.md` (~400 lines)

### 3.1 The Benchmark

| Operation | Playwright (Outlook Web) | COM |
|-----------|-------------------------|-----|
| Send email | ~25 min (SPFx, auth, DOM waits) | **2 sec** |
| Create meeting | ~20 min (calendar render) | **2 sec** |
| Search emails | ~10 min (pagination) | **1 sec** |
| Reliability | ~70% (selector drift, MFA) | **99%+** |

Playwright fights SPFx lazy loading, React hydration, auth redirects, and MFA popups. COM talks directly to the Outlook process — zero UI rendering, zero network roundtrips.

### 3.2 GAL Resolution — The Killer Feature

```powershell
$outlook = New-Object -ComObject Outlook.Application
$meeting = $outlook.CreateItem(1)  # AppointmentItem
$meeting.MeetingStatus = 1         # olMeeting
$meeting.Subject = "Team Sync"
$meeting.Start = [DateTime]"2026-03-15 14:00"
$meeting.Duration = 30

# Just pass a name — GAL resolves to the full email
$meeting.Recipients.Add("Brady Gaster")
$meeting.Recipients.ResolveAll()   # Searches Global Address List
$meeting.Send()
```

`ResolveAll()` is why COM wins: pass "Brady Gaster" and it resolves the full corporate email. With Playwright you'd type the name, wait for autocomplete dropdown, click the right suggestion — fragile and slow.

### 3.3 DASL Email Search

```powershell
$inbox = $namespace.GetDefaultFolder(6)  # olFolderInbox
$filter = "@SQL=""urn:schemas:httpmail:subject"" LIKE '%search term%'"
$results = $inbox.Items.Restrict($filter)
```

The skill file documents all `OlItemType` constants (0=Mail, 1=Appointment, 2=Contact, 3=Task), `OlDefaultFolders` (6=Inbox, 9=Calendar, 10=Contacts), and DASL query syntax.

---

## 4. Teams Integration

Three integration points, each solving a different problem:

### 4.1 Webhooks — Outbound Adaptive Cards

Simplest integration. One URL at `~/.squad/teams-webhook.url`, one `Invoke-RestMethod`:

```powershell
$webhookUrl = (Get-Content "$env:USERPROFILE\.squad\teams-webhook.url" -Raw).Trim()
$body = @{
    "@type" = "MessageCard"; themeColor = "00FF00"; title = "📰 Squad Update"
    sections = @(@{
        activityTitle = "3 PRs merged, 1 security finding"
        facts = @(
            @{ name = "Issues Closed"; value = "5" },
            @{ name = "Time"; value = (Get-Date -Format "HH:mm") }
        )
    })
} | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $body
```

Used by Ralph (failure alerts), Neelix (broadcasts), and the scheduler (task failure notifications).

### 4.2 Teams MCP Server — Bidirectional

`agency mcp teams` provides real MCP tools: read channel messages, post to channels, manage state. More powerful than webhooks but requires MCP server configured in the agency session.

### 4.3 WorkIQ — Calendar & Email Intelligence

Queries M365 Copilot for workplace data. **Session-only** — only works inside `agency copilot` sessions, not standalone scripts. This is why Teams monitoring runs inside Ralph's agency round.

```
Use workiq-ask_work_iq: "What Teams messages in the last 30 minutes
mention Tamir, squad, DK8S, reviews, action items?"
```

### 4.4 When to Use What

| | Webhook | Teams MCP | WorkIQ |
|---|---------|-----------|--------|
| Direction | Outbound only | Bidirectional | Read-only |
| Works from scripts | ✅ | ❌ (needs MCP) | ❌ (needs agency session) |
| Read messages | ❌ | ✅ | ✅ (M365 search) |
| Adaptive Cards | ✅ | ✅ | N/A |
| Auth | URL is auth | OAuth | Session token |

---

## 5. Podcaster

**Script:** `scripts/podcaster.ps1` (~170 lines)

Converts markdown → MP3 audio. Triggered automatically by Ralph when any agent produces a deliverable >500 words.

### 5.1 TTS Engine Selection

```
Input (.md) → Strip markdown → TTS engine → Output (.mp3/.wav)
                                ├── edge-tts (primary — neural quality)
                                └── System.Speech (fallback — robotic but offline)
```

**Primary — `edge-tts`** (Microsoft's neural TTS, voice `en-US-JennyNeural`):

```powershell
function Invoke-EdgeTTS {
    param([string]$Text, [string]$Output, [string]$Voice)
    $tempText = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempText, $Text, [System.Text.Encoding]::UTF8)
    try {
        $proc = Start-Process -FilePath "edge-tts" `
            -ArgumentList "--file `"$tempText`" --write-media `"$Output`" --voice $Voice" `
            -NoNewWindow -Wait -PassThru -ErrorAction Stop
        return ($proc.ExitCode -eq 0)
    } finally { Remove-Item $tempText -Force -EA SilentlyContinue }
}
```

**Fallback — `System.Speech`** (entirely local, no network):

```powershell
function Invoke-SystemSpeech {
    param([string]$Text, [string]$Output)
    Add-Type -AssemblyName System.Speech
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $voices = $synth.GetInstalledVoices() | Where-Object { $_.Enabled }
    $preferred = $voices | Where-Object { $_.VoiceInfo.Name -match "Zira|David|Jenny|Eva" } | Select-Object -First 1
    if ($preferred) { $synth.SelectVoice($preferred.VoiceInfo.Name) }
    $wavFile = [System.IO.Path]::ChangeExtension($Output, ".wav")
    $synth.SetOutputToWaveFile($wavFile)
    $synth.Speak($Text)
    $synth.Dispose()
    # Convert WAV → MP3 via ffmpeg if available
    $ffmpeg = Get-Command ffmpeg -EA SilentlyContinue
    if ($ffmpeg) { & ffmpeg -i $wavFile -codec:a libmp3lame -qscale:a 4 $Output -y -loglevel quiet }
}
```

### 5.2 Corporate Firewall Workaround

`edge-tts` calls Microsoft's TTS endpoints via HTTPS. Behind corporate firewalls: SSL inspection breaks certs, proxy auth isn't inherited, some networks block it entirely.

**Fix:** The `-ForceFallback` switch skips `edge-tts` entirely:

```powershell
param(
    [Parameter(Mandatory=$true)] [string]$InputFile,
    [string]$Voice = "en-US-JennyNeural",
    [switch]$ForceFallback
)
if (-not $ForceFallback) { $success = Invoke-EdgeTTS ... }
if (-not $success) { $OutputFile = Invoke-SystemSpeech ... }   # Always works locally
```

### 5.3 Auto-Trigger Pattern

Ralph's prompt chains podcaster after deliverables:
```
RESEARCH_REPORT.md       → RESEARCH_REPORT-audio.mp3
EXECUTIVE_SUMMARY.md     → EXECUTIVE_SUMMARY-audio.mp3
blog-draft-*.md          → blog-draft-*-audio.mp3
```

---

## 6. Neelix & Kes — Custom Squad Members

These two are custom agents that add capabilities beyond the standard squad roster.

### 6.1 Neelix — News Reporter

**What's novel:** Not a standard squad role. Neelix is a dedicated broadcast agent with a personality ("witty, engaging — makes dry updates feel like breaking news") that formats squad activity as styled Teams messages.

**Formats he produces:**

| Format | Content | Trigger |
|--------|---------|---------|
| 📰 Daily Briefing | Issues closed, PRs merged, decisions, blockers | Scheduled (8 AM) |
| ⚡ Breaking News | CI failures, blocking issues, important merges | Real-time events |
| 📊 Weekly Recap | Stats, highlights, top stories | End of week |
| 🎯 Status Flash | Board snapshot | On demand |

**Styling conventions:** emoji categories (🟢 Done, 🟡 In Progress, 🔴 Blocked), section dividers (`━━━`), pull quotes for decisions, reporter sign-off.

**Cost optimization:** Runs on `claude-haiku-4.5` — text formatting doesn't need Sonnet-level reasoning. 5-10x cheaper.

**Spam prevention:** Ralph's prompt says "only send when there is genuinely newsworthy activity — not every round." Routine board checks don't trigger Neelix.

### 6.2 Kes — Communications & Scheduling

**What's novel:** Personal assistant agent that owns all human communication — calendar, email, meetings, contact lookup. Bridges the gap between the autonomous squad and the human world.

**Capability stack:**

```
Kes Communication Stack:
├── Outlook COM (PRIMARY)      — 2-second email/meeting creation
├── Playwright + Outlook Web   — Fallback when COM unavailable  
├── Teams Webhook              — Teams message delivery
└── WorkIQ                     — People search, calendar queries
```

**Key charter rule:** "When Outlook is installed on Windows, use the outlook-automation skill instead of Playwright." This is the integration that turns a 25-minute Playwright workflow into a 2-second COM call.

**Also on Haiku** — composing emails and creating calendar invites doesn't need Sonnet.

---

## 7. cli-tunnel

**Public repo:** [github.com/tamirdresher/cli-tunnel](https://github.com/tamirdresher/cli-tunnel)

Exposes a local terminal (PTY) as a web interface via xterm.js. Enables remote access to Copilot CLI sessions.

### 7.1 Architecture

```
Local Machine                    Remote Browser
┌──────────┐    WebSocket    ┌──────────────────────┐
│ PTY      │◄──────────────►│ xterm.js terminal     │
│ (shell)  │                │ (full ANSI support)   │
└──────────┘                └──────────────────────┘
      │
      │ devtunnel (Azure Dev Tunnels)
      ▼
  Secure public URL with e2e encryption
```

### 7.2 Key Features

- **Real PTY** — not stdout/stderr streaming. Colors, cursor movement, interactive prompts all work.
- **devtunnel integration** — Azure Dev Tunnels for secure public URLs. QR code sharing for mobile access.
- **Local-only mode** — `cli-tunnel --local` skips devtunnel, runs at `localhost` only.
- **Hub mode** — `cli-tunnel` with no args = multi-session dashboard at `http://127.0.0.1:63726`.

### 7.3 Playwright Control Pattern

cli-tunnel's web UI can be automated by Playwright — enabling scripted terminal interactions:

```javascript
await page.goto('http://localhost:3000');
await page.locator('.xterm-helper-textarea').fill('agency copilot -p "check issues"');
await page.keyboard.press('Enter');
await page.waitForSelector('.xterm-rows', { hasText: 'issues found' });
```

Use cases: automated testing of Copilot CLI workflows, remote squad management from a DevBox, scripted demo recordings.

---

## 8. Key Lessons Learned

### PS 5.1 vs. pwsh — The Stderr Problem

Windows PowerShell 5.1 converts native command stderr to `NativeCommandError` exceptions. Agency writes emoji banners to stderr → Ralph reports 100% failure rate. PS 7 fixed this with `$PSNativeCommandUseErrorActionPreference` but stock Windows doesn't have PS 7.

**Fix:** `$ErrorActionPreference = "SilentlyContinue"` around the agency call + never pipe output (piping breaks `$LASTEXITCODE` in 5.1).

### WorkIQ is Session-Only

`workiq-ask_work_iq` queries M365 (emails, Teams, calendar) but only works inside `agency copilot` sessions — not standalone scripts. This forced the Teams/email monitor into Ralph's agency round rather than a separate scheduled task.

### Outlook COM >> Playwright

| | COM | Playwright |
|---|-----|-----------|
| Email send | 2 sec | 25 min |
| Meeting create | 2 sec | 20 min |
| Reliability | 99%+ | ~70% |
| GAL resolution | `ResolveAll()` — automatic | Type name → wait for dropdown → click |

Only downside: Windows-only. Squad runs on Windows, so irrelevant.

### EMU vs. Personal GitHub Account

EMU accounts (`_microsoft` suffix) can't push to personal repos. Personal accounts can't access enterprise repos. The public `squad-monitor` repo requires the personal account. Multi-repo watch needs auth switching via `gh auth status` / `gh auth switch`.

### edge-tts Firewall

Corporate SSL inspection breaks `edge-tts` certificate validation. `-ForceFallback` switch → `System.Speech` (robotic but 100% local, zero network).

### Mutex for Single-Instance

Three layers: named mutex (`Global\RalphWatch_*`), process scan + kill, lockfile. The `AbandonedMutexException` catch prevents deadlock after crashes — .NET throws this instead of returning `false` when a previous holder died without releasing.

### Parallel Work Pools > Serial Processing

Ralph originally processed work serially (untriaged → assigned → CI → ...). One 5-min task blocks everything. Solution: spawn ALL agents across ALL categories simultaneously via `mode: "background"` + `read_agent(wait: true)`. Throughput improvement: 9 min (serial) → 5 min (parallel).

---

*This document covers only what's custom-built in this repo. For how Squad itself works (routing, charters, casting, decisions inbox, orchestration logging), see the Squad framework docs.*

---

*Prepared by the AI Squad for the Brady × Tamir sync. Questions? Open a GitHub issue — an agent will triage it within 5 minutes.* 🖖
