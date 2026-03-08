using Spectre.Console;
using Spectre.Console.Rendering;
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

if (runOnce)
{
    // Run once mode: render directly without Live display
    var now = DateTime.UtcNow;
    var header = new Rule($"[yellow bold]Squad Monitor v2[/] [dim]— {now:yyyy-MM-dd HH:mm:ss} UTC[/]")
    {
        Justification = Justify.Left
    };
    AnsiConsole.Write(header);
    AnsiConsole.WriteLine();

    DisplayRalphHeartbeat(userProfile);
    DisplayRalphLog(userProfile);
    DisplayGitHubIssues(teamRoot);
    DisplayGitHubPRs(teamRoot);
    var activities = LoadActivities(teamRoot);
    DisplayOrchestrationLog(activities);
}
else
{
    // Live mode: use AnsiConsole.Live() for flicker-free updates
    var layout = new Layout("Root");
    
    await AnsiConsole.Live(layout)
        .AutoClear(false)
        .StartAsync(async ctx =>
        {
            do
            {
                var now = DateTime.UtcNow;
                var content = BuildDashboardContent(now, userProfile, teamRoot);
                layout.Update(content);
                ctx.Refresh();

                AnsiConsole.MarkupLine($"\n[dim]Refreshing in {interval}s... (Ctrl+C to exit)[/]");
                await Task.Delay(TimeSpan.FromSeconds(interval));

            } while (true);
        });
}

return 0;

// ─── Dashboard Content Builder ─────────────────────────────────────────────

static IRenderable BuildDashboardContent(DateTime now, string userProfile, string teamRoot)
{
    var sections = new List<IRenderable>();

    // Header
    var header = new Rule($"[yellow bold]Squad Monitor v2[/] [dim]— {now:yyyy-MM-dd HH:mm:ss} UTC[/]")
    {
        Justification = Justify.Left
    };
    sections.Add(header);
    sections.Add(Text.Empty);

    // Ralph Watch Heartbeat
    sections.Add(BuildRalphHeartbeatSection(userProfile));
    
    // Ralph Watch Log
    sections.Add(BuildRalphLogSection(userProfile));
    
    // GitHub Issues
    sections.Add(BuildGitHubIssuesSection(teamRoot));
    
    // GitHub PRs
    sections.Add(BuildGitHubPRsSection(teamRoot));
    
    // Orchestration Log
    var activities = LoadActivities(teamRoot);
    sections.Add(BuildOrchestrationLogSection(activities));

    // Combine all sections into a group
    var rows = new Rows(sections);
    return rows;
}

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

// ─── Section Builders (return IRenderable) ──────────────────────────────────

static IRenderable BuildRalphHeartbeatSection(string userProfile)
{
    var items = new List<IRenderable>();
    
    var section = new Rule("[cyan]Ralph Watch Loop[/]") { Justification = Justify.Left };
    items.Add(section);

    var heartbeatPath = Path.Combine(userProfile, ".squad", "ralph-heartbeat.json");
    if (!File.Exists(heartbeatPath))
    {
        items.Add(new Markup("[dim]  No heartbeat file found — ralph-watch may not be running[/]"));
        items.Add(Text.Empty);
        return new Rows(items);
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

        items.Add(new Markup($"  Status: [{statusColor}]{Markup.Escape(status ?? "unknown")}[/]  |  " +
                            $"Round: [white]{Markup.Escape(round)}[/]  |  " +
                            $"Last run: [{stalenessColor}]{Markup.Escape(staleness)}[/]  |  " +
                            $"Failures: [{failColor}]{consecutiveFailures}[/]  |  " +
                            $"PID: [dim]{Markup.Escape(pid)}[/]"));
    }
    catch
    {
        items.Add(new Markup("[red]  Error reading heartbeat file[/]"));
    }

    items.Add(Text.Empty);
    return new Rows(items);
}

static IRenderable BuildRalphLogSection(string userProfile)
{
    var items = new List<IRenderable>();
    
    var logPath = Path.Combine(userProfile, ".squad", "ralph-watch.log");
    if (!File.Exists(logPath))
    {
        return Text.Empty; // No log file — skip silently
    }

    var section = new Rule("[cyan]Ralph Recent Rounds[/]") { Justification = Justify.Left };
    items.Add(section);

    try
    {
        using var fs = new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        using var reader = new StreamReader(fs);
        
        var fileLength = fs.Length;
        if (fileLength == 0)
        {
            items.Add(new Markup("[dim]  Log file exists but is empty[/]"));
            items.Add(Text.Empty);
            return new Rows(items);
        }

        var startPos = Math.Max(0, fileLength - 500);
        fs.Seek(startPos, SeekOrigin.Begin);
        var tail = reader.ReadToEnd();

        var lines = tail.Split('\n', StringSplitOptions.RemoveEmptyEntries);
        var last5 = lines.TakeLast(5);

        foreach (var line in last5)
        {
            var trimmed = line.Trim();
            if (string.IsNullOrEmpty(trimmed)) continue;

            var color = trimmed.Contains("✓") ? "green" :
                       trimmed.Contains("→") ? "cyan" :
                       trimmed.Contains("⚠") || trimmed.Contains("WARN") ? "yellow" :
                       trimmed.Contains("✗") || trimmed.Contains("ERROR") ? "red" :
                       "dim";
            items.Add(new Markup($"  [{color}]{Markup.Escape(trimmed)}[/]"));
        }
    }
    catch
    {
        items.Add(new Markup("[red]  Error reading ralph-watch.log[/]"));
    }

    items.Add(Text.Empty);
    return new Rows(items);
}

static IRenderable BuildGitHubIssuesSection(string teamRoot)
{
    var items = new List<IRenderable>();
    
    var section = new Rule("[magenta]GitHub Issues (squad)[/]") { Justification = Justify.Left };
    items.Add(section);

    var output = RunProcess("gh", "issue list --label squad --json number,title,author,createdAt,labels,assignees --limit 20", teamRoot);
    if (output == null)
    {
        items.Add(new Markup("[dim]  Could not fetch issues (gh CLI unavailable or not authenticated)[/]"));
        items.Add(Text.Empty);
        return new Rows(items);
    }

    try
    {
        using var doc = JsonDocument.Parse(output);
        var issues = doc.RootElement;

        if (issues.GetArrayLength() == 0)
        {
            items.Add(new Markup("[dim]  No open issues with 'squad' label[/]"));
            items.Add(Text.Empty);
            return new Rows(items);
        }

        var table = new Table()
            .BorderColor(Color.Grey)
            .Border(TableBorder.Rounded)
            .AddColumn(new TableColumn("#").Width(6))
            .AddColumn(new TableColumn("Title").Width(40))
            .AddColumn(new TableColumn("Author").Width(15))
            .AddColumn(new TableColumn("Labels").Width(20))
            .AddColumn(new TableColumn("Assignees").Width(15))
            .AddColumn(new TableColumn("Age").Width(8));

        foreach (var issue in issues.EnumerateArray())
        {
            var number = issue.TryGetProperty("number", out var n) ? n.GetInt32().ToString() : "?";
            var title = issue.TryGetProperty("title", out var t) ? t.GetString() ?? "" : "";
            var author = issue.TryGetProperty("author", out var a) && a.TryGetProperty("login", out var login) ? login.GetString() ?? "" : "";
            var createdAt = issue.TryGetProperty("createdAt", out var c) && DateTime.TryParse(c.GetString(), out var created) ? FormatAge(DateTime.UtcNow - created) : "?";

            var labelsList = new List<string>();
            if (issue.TryGetProperty("labels", out var labels))
            {
                foreach (var label in labels.EnumerateArray())
                {
                    if (label.TryGetProperty("name", out var name))
                    {
                        var labelName = name.GetString() ?? "";
                        if (!string.IsNullOrEmpty(labelName))
                            labelsList.Add(labelName);
                    }
                }
            }
            var labelsStr = string.Join(", ", labelsList);

            var assigneesList = new List<string>();
            if (issue.TryGetProperty("assignees", out var assignees))
            {
                foreach (var assignee in assignees.EnumerateArray())
                {
                    if (assignee.TryGetProperty("login", out var aLogin))
                    {
                        var assigneeName = aLogin.GetString() ?? "";
                        if (!string.IsNullOrEmpty(assigneeName))
                            assigneesList.Add(assigneeName);
                    }
                }
            }
            var assigneesStr = assigneesList.Count > 0 ? string.Join(", ", assigneesList) : "[dim]none[/]";

            if (title.Length > 40)
                title = title.Substring(0, 37) + "...";

            table.AddRow(
                $"[cyan]{Markup.Escape(number)}[/]",
                Markup.Escape(title),
                $"[yellow]{Markup.Escape(author)}[/]",
                $"[dim]{Markup.Escape(labelsStr)}[/]",
                assigneesStr,
                $"[dim]{Markup.Escape(createdAt)}[/]"
            );
        }

        items.Add(table);
    }
    catch
    {
        items.Add(new Markup("[red]  Error parsing issue data[/]"));
    }

    items.Add(Text.Empty);
    return new Rows(items);
}

static IRenderable BuildGitHubPRsSection(string teamRoot)
{
    var items = new List<IRenderable>();
    
    var section = new Rule("[magenta]GitHub Pull Requests[/]") { Justification = Justify.Left };
    items.Add(section);

    var output = RunProcess("gh", "pr list --json number,title,author,createdAt,headRefName,reviewDecision,statusCheckRollup,isDraft --limit 20", teamRoot);
    if (output == null)
    {
        items.Add(new Markup("[dim]  Could not fetch PRs (gh CLI unavailable or not authenticated)[/]"));
        items.Add(Text.Empty);
        return new Rows(items);
    }

    try
    {
        using var doc = JsonDocument.Parse(output);
        var prs = doc.RootElement;

        if (prs.GetArrayLength() == 0)
        {
            items.Add(new Markup("[dim]  No open pull requests[/]"));
            items.Add(Text.Empty);
            return new Rows(items);
        }

        var table = new Table()
            .BorderColor(Color.Grey)
            .Border(TableBorder.Rounded)
            .AddColumn(new TableColumn("#").Width(6))
            .AddColumn(new TableColumn("Title").Width(35))
            .AddColumn(new TableColumn("Author").Width(12))
            .AddColumn(new TableColumn("Branch").Width(20))
            .AddColumn(new TableColumn("Review").Width(10))
            .AddColumn(new TableColumn("CI").Width(8))
            .AddColumn(new TableColumn("Age").Width(8));

        foreach (var pr in prs.EnumerateArray())
        {
            var number = pr.TryGetProperty("number", out var n) ? n.GetInt32().ToString() : "?";
            var title = pr.TryGetProperty("title", out var t) ? t.GetString() ?? "" : "";
            var author = pr.TryGetProperty("author", out var a) && a.TryGetProperty("login", out var login) ? login.GetString() ?? "" : "";
            var branch = pr.TryGetProperty("headRefName", out var b) ? b.GetString() ?? "" : "";
            var createdAt = pr.TryGetProperty("createdAt", out var c) && DateTime.TryParse(c.GetString(), out var created) ? FormatAge(DateTime.UtcNow - created) : "?";
            var isDraft = pr.TryGetProperty("isDraft", out var d) && d.GetBoolean();

            var reviewDecision = pr.TryGetProperty("reviewDecision", out var rd) ? rd.GetString() ?? "" : "";
            var reviewStatus = reviewDecision switch
            {
                "APPROVED" => "[green]✓[/]",
                "CHANGES_REQUESTED" => "[red]✗[/]",
                "REVIEW_REQUIRED" => "[yellow]?[/]",
                _ => "[dim]—[/]"
            };

            var ciStatus = "[dim]—[/]";
            if (pr.TryGetProperty("statusCheckRollup", out var rollup) && rollup.ValueKind == JsonValueKind.Array)
            {
                var statuses = rollup.EnumerateArray().ToList();
                if (statuses.Count > 0)
                {
                    var allSuccess = statuses.All(s =>
                    {
                        if (s.TryGetProperty("__typename", out var tn))
                        {
                            var typename = tn.GetString();
                            if (typename == "CheckRun" && s.TryGetProperty("conclusion", out var conclusion))
                                return conclusion.GetString() == "SUCCESS";
                            if (typename == "StatusContext" && s.TryGetProperty("state", out var state))
                                return state.GetString() == "SUCCESS";
                        }
                        return false;
                    });

                    var anyPending = statuses.Any(s =>
                    {
                        if (s.TryGetProperty("__typename", out var tn))
                        {
                            var typename = tn.GetString();
                            if (typename == "CheckRun" && s.TryGetProperty("status", out var status))
                                return status.GetString() == "IN_PROGRESS" || status.GetString() == "QUEUED";
                            if (typename == "StatusContext" && s.TryGetProperty("state", out var state))
                                return state.GetString() == "PENDING";
                        }
                        return false;
                    });

                    ciStatus = allSuccess ? "[green]✓[/]" : anyPending ? "[yellow]…[/]" : "[red]✗[/]";
                }
            }

            if (title.Length > 35)
                title = title.Substring(0, 32) + "...";
            if (branch.Length > 20)
                branch = branch.Substring(0, 17) + "...";

            var titleMarkup = isDraft ? $"[dim]{Markup.Escape(title)} (draft)[/]" : Markup.Escape(title);

            table.AddRow(
                $"[cyan]{Markup.Escape(number)}[/]",
                titleMarkup,
                $"[yellow]{Markup.Escape(author)}[/]",
                $"[dim]{Markup.Escape(branch)}[/]",
                reviewStatus,
                ciStatus,
                $"[dim]{Markup.Escape(createdAt)}[/]"
            );
        }

        items.Add(table);
    }
    catch
    {
        items.Add(new Markup("[red]  Error parsing PR data[/]"));
    }

    items.Add(Text.Empty);
    return new Rows(items);
}

static IRenderable BuildOrchestrationLogSection(List<AgentActivity> activities)
{
    var items = new List<IRenderable>();
    
    var section = new Rule("[yellow]Orchestration Activity (24h)[/]") { Justification = Justify.Left };
    items.Add(section);

    if (activities.Count == 0)
    {
        items.Add(new Markup("[dim]  No activities found in orchestration logs.[/]"));
        items.Add(Text.Empty);
        return new Rows(items);
    }

    var now = DateTime.UtcNow;
    var recentActivities = activities.Count(a => (now - a.Timestamp).TotalHours <= 24);
    var uniqueAgents = activities.Select(a => a.Agent).Distinct().ToList();
    var totalAgents = uniqueAgents.Count;

    var top10 = activities.Take(10).ToList();

    var table = new Table()
        .BorderColor(Color.Grey)
        .Border(TableBorder.Rounded)
        .AddColumn(new TableColumn("Agent").Width(10))
        .AddColumn(new TableColumn("Activity").Width(50))
        .AddColumn(new TableColumn("Age").Width(10));

    foreach (var activity in top10)
    {
        var age = FormatAge(now - activity.Timestamp);
        var activityText = activity.Task;
        if (activityText.Length > 50)
            activityText = activityText.Substring(0, 47) + "...";

        var agentName = CapitalizeAgent(activity.Agent);

        table.AddRow(
            $"[cyan]{Markup.Escape(agentName)}[/]",
            $"[white]{Markup.Escape(activityText)}[/]",
            $"[dim]{Markup.Escape(age)}[/]"
        );
    }

    items.Add(table);
    items.Add(new Markup($"[dim]  Agents: {totalAgents} | Activities (24h): {recentActivities} | Showing top 10 of {activities.Count}[/]"));
    items.Add(Text.Empty);
    
    return new Rows(items);
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
