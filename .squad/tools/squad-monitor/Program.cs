using Spectre.Console;
using System.Diagnostics;
using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;

var interval = 5;
var runOnce = false;
var teamRoot = FindTeamRoot();
var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

for (int i = 0; i < args.Length; i++)
{
    if (args[i] == "--interval" && i + 1 < args.Length && int.TryParse(args[i + 1], out var n))
    {
        interval = n;
        i++;
    }
    else if (args[i] == "--once")
    {
        runOnce = true;
    }
}

if (teamRoot == null)
{
    AnsiConsole.MarkupLine("[red]Error: Could not find .squad directory. Run from team root.[/]");
    return 1;
}

AnsiConsole.MarkupLine($"[dim]Squad Monitor v2 - Refresh interval: {interval}s[/]");
AnsiConsole.MarkupLine($"[dim]Team root: {teamRoot}[/]");
AnsiConsole.WriteLine();

do
{
    if (!runOnce)
    {
        Console.Clear();
    }

    var now = DateTime.UtcNow;
    var header = new Rule($"[yellow bold]Squad Monitor v2[/] [dim]— {now:yyyy-MM-dd HH:mm:ss} UTC[/]")
    {
        Justification = Justify.Left
    };
    AnsiConsole.Write(header);
    AnsiConsole.WriteLine();

    // --- Ralph Watch Status ---
    DisplayRalphHeartbeat(userProfile);
    DisplayRalphLog(userProfile);

    // --- GitHub Issues ---
    DisplayGitHubIssues(teamRoot);

    // --- GitHub PRs ---
    DisplayGitHubPRs(teamRoot);

    // --- Orchestration Log (existing, now a section) ---
    var activities = LoadActivities(teamRoot);
    DisplayOrchestrationLog(activities);

    if (!runOnce)
    {
        AnsiConsole.MarkupLine($"\n[dim]Refreshing in {interval}s... (Ctrl+C to exit)[/]");
        await Task.Delay(TimeSpan.FromSeconds(interval));
    }

} while (!runOnce);

return 0;

// ─── Helpers ────────────────────────────────────────────────────────────────

static string? FindTeamRoot()
{
    var current = Directory.GetCurrentDirectory();
    while (current != null)
    {
        if (Directory.Exists(Path.Combine(current, ".squad")))
            return current;
        current = Directory.GetParent(current)?.FullName;
    }
    return null;
}

static string FormatAge(TimeSpan age)
{
    if (age.TotalMinutes < 1) return "just now";
    if (age.TotalMinutes < 60) return $"{(int)age.TotalMinutes}m ago";
    if (age.TotalHours < 24) return $"{(int)age.TotalHours}h ago";
    if (age.TotalDays < 7) return $"{(int)age.TotalDays}d ago";
    return $"{(int)(age.TotalDays / 7)}w ago";
}

static string CapitalizeAgent(string agent)
{
    if (string.IsNullOrEmpty(agent)) return agent;
    return char.ToUpper(agent[0]) + agent.Substring(1).ToLower();
}

static string? RunProcess(string fileName, string arguments, string? workingDirectory = null, int timeoutMs = 10_000)
{
    try
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        if (workingDirectory != null)
            psi.WorkingDirectory = workingDirectory;

        using var proc = Process.Start(psi);
        if (proc == null) return null;

        var output = proc.StandardOutput.ReadToEnd();
        proc.WaitForExit(timeoutMs);
        return proc.ExitCode == 0 ? output : null;
    }
    catch
    {
        return null;
    }
}

// ─── Ralph Heartbeat Panel ──────────────────────────────────────────────────

static void DisplayRalphHeartbeat(string userProfile)
{
    var section = new Rule("[cyan]Ralph Watch Loop[/]") { Justification = Justify.Left };
    AnsiConsole.Write(section);

    var heartbeatPath = Path.Combine(userProfile, ".squad", "ralph-heartbeat.json");
    if (!File.Exists(heartbeatPath))
    {
        AnsiConsole.MarkupLine("[dim]  No heartbeat file found — ralph-watch may not be running[/]");
        AnsiConsole.WriteLine();
        return;
    }

    try
    {
        var json = File.ReadAllText(heartbeatPath);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var lastRun = root.TryGetProperty("lastRun", out var lr) ? lr.GetString() : null;
        var round = root.TryGetProperty("round", out var rn) ? rn.ToString() : "?";
        var status = root.TryGetProperty("status", out var st) ? st.GetString() : "unknown";
        var consecutiveFailures = root.TryGetProperty("consecutiveFailures", out var cf) ? cf.GetInt32() : 0;
        var pid = root.TryGetProperty("pid", out var p) ? p.ToString() : "?";

        var staleness = "unknown";
        var stalenessColor = "dim";
        if (lastRun != null && DateTime.TryParse(lastRun, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out var lastRunDt))
        {
            var age = DateTime.UtcNow - lastRunDt;
            staleness = FormatAge(age);
            stalenessColor = age.TotalMinutes < 10 ? "green" : age.TotalMinutes < 30 ? "yellow" : "red";
        }

        var statusColor = status == "running" ? "green" : status == "idle" ? "yellow" : "red";
        var failColor = consecutiveFailures == 0 ? "green" : consecutiveFailures < 3 ? "yellow" : "red";

        AnsiConsole.MarkupLine($"  Status: [{statusColor}]{Markup.Escape(status ?? "unknown")}[/]  |  " +
                               $"Round: [white]{Markup.Escape(round)}[/]  |  " +
                               $"Last run: [{stalenessColor}]{Markup.Escape(staleness)}[/]  |  " +
                               $"Failures: [{failColor}]{consecutiveFailures}[/]  |  " +
                               $"PID: [dim]{Markup.Escape(pid)}[/]");
    }
    catch
    {
        AnsiConsole.MarkupLine("[red]  Error reading heartbeat file[/]");
    }

    AnsiConsole.WriteLine();
}

// ─── Ralph Watch Log Panel ──────────────────────────────────────────────────

static void DisplayRalphLog(string userProfile)
{
    var logPath = Path.Combine(userProfile, ".squad", "ralph-watch.log");
    if (!File.Exists(logPath))
    {
        return; // No log file — skip silently
    }

    var section = new Rule("[cyan]Ralph Recent Rounds[/]") { Justification = Justify.Left };
    AnsiConsole.Write(section);

    try
    {
        // Read last 500 chars to get recent entries
        using var fs = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        var tailSize = Math.Min(2000, fs.Length);
        fs.Seek(-tailSize, SeekOrigin.End);
        using var reader = new StreamReader(fs);
        var tail = reader.ReadToEnd();

        var lines = tail.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        // Show last 5 meaningful lines
        var recentLines = lines
            .Where(l => !string.IsNullOrWhiteSpace(l))
            .TakeLast(5)
            .ToList();

        if (recentLines.Count == 0)
        {
            AnsiConsole.MarkupLine("[dim]  Log file exists but is empty[/]");
        }
        else
        {
            foreach (var line in recentLines)
            {
                var trimmed = line.Trim();
                if (trimmed.Length > 120)
                    trimmed = trimmed[..120] + "…";
                // Color errors/warnings
                var color = trimmed.Contains("ERROR", StringComparison.OrdinalIgnoreCase) ? "red" :
                           trimmed.Contains("WARN", StringComparison.OrdinalIgnoreCase) ? "yellow" :
                           trimmed.Contains("SUCCESS", StringComparison.OrdinalIgnoreCase) ? "green" :
                           "dim";
                AnsiConsole.MarkupLine($"  [{color}]{Markup.Escape(trimmed)}[/]");
            }
        }
    }
    catch
    {
        AnsiConsole.MarkupLine("[red]  Error reading ralph-watch.log[/]");
    }

    AnsiConsole.WriteLine();
}

// ─── GitHub Issues Panel ────────────────────────────────────────────────────

static void DisplayGitHubIssues(string teamRoot)
{
    var section = new Rule("[cyan]GitHub Issues (Open)[/]") { Justification = Justify.Left };
    AnsiConsole.Write(section);

    var json = RunProcess("gh", "issue list --state open --label squad --limit 15 --json number,title,labels,assignees,updatedAt", teamRoot);
    if (json == null)
    {
        AnsiConsole.MarkupLine("[dim]  Could not fetch issues (gh CLI unavailable or not authenticated)[/]");
        AnsiConsole.WriteLine();
        return;
    }

    try
    {
        using var doc = JsonDocument.Parse(json);
        var issues = doc.RootElement;

        if (issues.GetArrayLength() == 0)
        {
            AnsiConsole.MarkupLine("[dim]  No open issues with 'squad' label[/]");
            AnsiConsole.WriteLine();
            return;
        }

        var table = new Table();
        table.Border(TableBorder.Simple);
        table.AddColumn(new TableColumn("[bold]#[/]").RightAligned());
        table.AddColumn(new TableColumn("[bold]Title[/]").LeftAligned());
        table.AddColumn(new TableColumn("[bold]Labels[/]").LeftAligned());
        table.AddColumn(new TableColumn("[bold]Assignee[/]").LeftAligned());
        table.AddColumn(new TableColumn("[bold]Updated[/]").RightAligned());

        foreach (var issue in issues.EnumerateArray())
        {
            var number = issue.GetProperty("number").GetInt32();
            var title = issue.GetProperty("title").GetString() ?? "";
            if (title.Length > 60) title = title[..60] + "…";

            var labels = string.Join(", ", issue.GetProperty("labels").EnumerateArray()
                .Select(l => l.GetProperty("name").GetString() ?? "")
                .Where(l => l != "squad")); // Don't repeat the filter label

            var assignees = string.Join(", ", issue.GetProperty("assignees").EnumerateArray()
                .Select(a => a.GetProperty("login").GetString() ?? ""));
            if (string.IsNullOrEmpty(assignees)) assignees = "unassigned";

            var updatedStr = "";
            if (issue.TryGetProperty("updatedAt", out var updatedAt) &&
                DateTime.TryParse(updatedAt.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out var updatedDt))
            {
                updatedStr = FormatAge(DateTime.UtcNow - updatedDt);
            }

            // Status heuristic from labels
            var statusColor = labels.Contains("in-progress") ? "yellow" :
                             labels.Contains("assigned") || !string.IsNullOrEmpty(assignees) && assignees != "unassigned" ? "blue" :
                             "dim";

            table.AddRow(
                $"[white]#{number}[/]",
                $"[{statusColor}]{Markup.Escape(title)}[/]",
                $"[dim]{Markup.Escape(labels)}[/]",
                $"[cyan]{Markup.Escape(assignees)}[/]",
                $"[dim]{Markup.Escape(updatedStr)}[/]"
            );
        }

        AnsiConsole.Write(table);
    }
    catch
    {
        AnsiConsole.MarkupLine("[red]  Error parsing issue data[/]");
    }

    AnsiConsole.WriteLine();
}

// ─── GitHub PRs Panel ───────────────────────────────────────────────────────

static void DisplayGitHubPRs(string teamRoot)
{
    var section = new Rule("[cyan]GitHub Pull Requests (Open)[/]") { Justification = Justify.Left };
    AnsiConsole.Write(section);

    var json = RunProcess("gh", "pr list --state open --limit 10 --json number,title,author,reviewDecision,statusCheckRollup,updatedAt,isDraft,headRefName", teamRoot);
    if (json == null)
    {
        AnsiConsole.MarkupLine("[dim]  Could not fetch PRs (gh CLI unavailable or not authenticated)[/]");
        AnsiConsole.WriteLine();
        return;
    }

    try
    {
        using var doc = JsonDocument.Parse(json);
        var prs = doc.RootElement;

        if (prs.GetArrayLength() == 0)
        {
            AnsiConsole.MarkupLine("[dim]  No open pull requests[/]");
            AnsiConsole.WriteLine();
            return;
        }

        var table = new Table();
        table.Border(TableBorder.Simple);
        table.AddColumn(new TableColumn("[bold]#[/]").RightAligned());
        table.AddColumn(new TableColumn("[bold]Title[/]").LeftAligned());
        table.AddColumn(new TableColumn("[bold]Author[/]").LeftAligned());
        table.AddColumn(new TableColumn("[bold]Review[/]").Centered());
        table.AddColumn(new TableColumn("[bold]CI[/]").Centered());
        table.AddColumn(new TableColumn("[bold]Updated[/]").RightAligned());

        foreach (var pr in prs.EnumerateArray())
        {
            var number = pr.GetProperty("number").GetInt32();
            var title = pr.GetProperty("title").GetString() ?? "";
            var isDraft = pr.TryGetProperty("isDraft", out var d) && d.GetBoolean();
            if (isDraft) title = "[draft] " + title;
            if (title.Length > 55) title = title[..55] + "…";

            var author = pr.TryGetProperty("author", out var auth) && auth.TryGetProperty("login", out var login)
                ? login.GetString() ?? "" : "";

            // Review decision
            var reviewDecision = pr.TryGetProperty("reviewDecision", out var rd) ? rd.GetString() ?? "" : "";
            var reviewDisplay = reviewDecision switch
            {
                "APPROVED" => "[green]✓ Approved[/]",
                "CHANGES_REQUESTED" => "[red]✗ Changes[/]",
                "REVIEW_REQUIRED" => "[yellow]⏳ Pending[/]",
                _ => "[dim]—[/]"
            };

            // CI status rollup
            var ciDisplay = "[dim]—[/]";
            if (pr.TryGetProperty("statusCheckRollup", out var checks) && checks.ValueKind == JsonValueKind.Array)
            {
                var total = checks.GetArrayLength();
                var success = 0;
                var fail = 0;
                var pending = 0;
                foreach (var check in checks.EnumerateArray())
                {
                    var conclusion = check.TryGetProperty("conclusion", out var c) ? c.GetString() ?? "" : "";
                    var checkStatus = check.TryGetProperty("status", out var s) ? s.GetString() ?? "" : "";
                    if (conclusion == "SUCCESS") success++;
                    else if (conclusion == "FAILURE" || conclusion == "ERROR") fail++;
                    else if (checkStatus == "IN_PROGRESS" || checkStatus == "QUEUED" || checkStatus == "PENDING") pending++;
                }

                if (fail > 0)
                    ciDisplay = $"[red]✗ {fail}/{total}[/]";
                else if (pending > 0)
                    ciDisplay = $"[yellow]⏳ {pending}/{total}[/]";
                else if (success == total && total > 0)
                    ciDisplay = $"[green]✓ {success}/{total}[/]";
            }

            var updatedStr = "";
            if (pr.TryGetProperty("updatedAt", out var updatedAt) &&
                DateTime.TryParse(updatedAt.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out var updatedDt))
            {
                updatedStr = FormatAge(DateTime.UtcNow - updatedDt);
            }

            table.AddRow(
                $"[white]#{number}[/]",
                $"[white]{Markup.Escape(title)}[/]",
                $"[cyan]{Markup.Escape(author)}[/]",
                reviewDisplay,
                ciDisplay,
                $"[dim]{Markup.Escape(updatedStr)}[/]"
            );
        }

        AnsiConsole.Write(table);
    }
    catch
    {
        AnsiConsole.MarkupLine("[red]  Error parsing PR data[/]");
    }

    AnsiConsole.WriteLine();
}

// ─── Orchestration Log Panel ────────────────────────────────────────────────

static List<AgentActivity> LoadActivities(string teamRoot)
{
    var activities = new List<AgentActivity>();
    var orchestrationLogPath = Path.Combine(teamRoot, ".squad", "orchestration-log");

    if (!Directory.Exists(orchestrationLogPath))
        return activities;

    var logFiles = Directory.GetFiles(orchestrationLogPath, "*.md")
        .OrderByDescending(f => File.GetLastWriteTime(f))
        .Take(20);

    foreach (var file in logFiles)
    {
        try
        {
            var activity = ParseOrchestrationLog(file);
            if (activity != null)
                activities.Add(activity);
        }
        catch
        {
            // Skip malformed files
        }
    }

    return activities.OrderByDescending(a => a.Timestamp).ToList();
}

static AgentActivity? ParseOrchestrationLog(string filePath)
{
    var content = File.ReadAllText(filePath);
    var fileName = Path.GetFileNameWithoutExtension(filePath);

    var match = Regex.Match(fileName, @"^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})Z-(.+)$");
    if (!match.Success) return null;

    var timestamp = new DateTime(
        int.Parse(match.Groups[1].Value), int.Parse(match.Groups[2].Value), int.Parse(match.Groups[3].Value),
        int.Parse(match.Groups[4].Value), int.Parse(match.Groups[5].Value), int.Parse(match.Groups[6].Value),
        DateTimeKind.Utc);
    var agentName = match.Groups[7].Value;

    var status = "Unknown";
    var statusMatch = Regex.Match(content, @"\*\*Status:\*\*\s*(.+)");
    if (statusMatch.Success)
        status = statusMatch.Groups[1].Value.Trim();

    var task = "";
    var assignmentMatch = Regex.Match(content, @"## Assignment\s*(.+?)(?=##|$)", RegexOptions.Singleline);
    if (assignmentMatch.Success)
    {
        task = assignmentMatch.Groups[1].Value.Trim().Replace("\r", "").Replace("\n", " ");
        if (task.Length > 150) task = task[..150] + "...";
    }

    var outcome = "";
    var outcomeMatch = Regex.Match(content, @"\*\*Result:\*\*\s*(.+?)(?:\r?\n|$)");
    if (outcomeMatch.Success)
    {
        outcome = outcomeMatch.Groups[1].Value.Trim();
    }
    else
    {
        var outcomeSection = Regex.Match(content, @"## Outcome\s*(.+?)(?=##|$)", RegexOptions.Singleline);
        if (outcomeSection.Success)
        {
            var lines = outcomeSection.Groups[1].Value.Trim().Split('\n');
            outcome = lines.FirstOrDefault(l => !string.IsNullOrWhiteSpace(l))?.Trim() ?? "";
            if (outcome.Length > 100) outcome = outcome[..100] + "...";
        }
    }

    return new AgentActivity
    {
        Agent = CapitalizeAgent(agentName),
        Timestamp = timestamp,
        Status = status,
        Task = task,
        Outcome = outcome
    };
}

static void DisplayOrchestrationLog(List<AgentActivity> activities)
{
    var now = DateTime.UtcNow;

    var section = new Rule("[cyan]Orchestration Log (Recent)[/]") { Justification = Justify.Left };
    AnsiConsole.Write(section);

    if (activities.Count == 0)
    {
        AnsiConsole.MarkupLine("[dim]  No activities found in orchestration logs.[/]");
        AnsiConsole.WriteLine();
        return;
    }

    var table = new Table();
    table.Border(TableBorder.Simple);
    table.AddColumn(new TableColumn("[bold]Agent[/]").Centered());
    table.AddColumn(new TableColumn("[bold]Status[/]").Centered());
    table.AddColumn(new TableColumn("[bold]Age[/]").Centered());
    table.AddColumn(new TableColumn("[bold]Task[/]").LeftAligned());
    table.AddColumn(new TableColumn("[bold]Outcome[/]").LeftAligned());

    foreach (var activity in activities.Take(10))
    {
        var age = now - activity.Timestamp;
        var ageStr = FormatAge(age);

        var statusColor = activity.Status.Contains("✅") || activity.Status.Contains("Completed") ? "green" :
                         activity.Status.Contains("⏳") || activity.Status.Contains("Progress") ? "yellow" :
                         activity.Status.Contains("❌") || activity.Status.Contains("Failed") ? "red" :
                         "blue";

        table.AddRow(
            $"[cyan]{Markup.Escape(activity.Agent)}[/]",
            $"[{statusColor}]{Markup.Escape(activity.Status)}[/]",
            age.TotalHours < 1 ? $"[green]{Markup.Escape(ageStr)}[/]" :
                age.TotalDays < 1 ? $"[yellow]{Markup.Escape(ageStr)}[/]" :
                $"[dim]{Markup.Escape(ageStr)}[/]",
            $"[white]{Markup.Escape(activity.Task)}[/]",
            !string.IsNullOrEmpty(activity.Outcome)
                ? $"[dim]{Markup.Escape(activity.Outcome)}[/]"
                : "[dim]-[/]"
        );
    }

    AnsiConsole.Write(table);

    var totalAgents = activities.Select(a => a.Agent).Distinct().Count();
    var recentActivities = activities.Count(a => (now - a.Timestamp).TotalHours < 24);
    AnsiConsole.MarkupLine($"[dim]  Agents: {totalAgents} | Activities (24h): {recentActivities} | Showing top 10 of {activities.Count}[/]");
    AnsiConsole.WriteLine();
}

record AgentActivity
{
    public required string Agent { get; init; }
    public required DateTime Timestamp { get; init; }
    public required string Status { get; init; }
    public required string Task { get; init; }
    public required string Outcome { get; init; }
}
