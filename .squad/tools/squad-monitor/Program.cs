using Spectre.Console;
using System.Globalization;
using System.Text.RegularExpressions;

var interval = 5;
var runOnce = false;
var teamRoot = FindTeamRoot();

// Parse command-line arguments
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

AnsiConsole.MarkupLine($"[dim]Squad Monitor - Refresh interval: {interval}s[/]");
AnsiConsole.MarkupLine($"[dim]Team root: {teamRoot}[/]");
AnsiConsole.WriteLine();

do
{
    if (!runOnce)
    {
        Console.Clear();
    }

    var activities = LoadActivities(teamRoot);
    DisplayActivities(activities, teamRoot);

    if (!runOnce)
    {
        AnsiConsole.MarkupLine($"\n[dim]Refreshing in {interval}s... (Ctrl+C to exit)[/]");
        await Task.Delay(TimeSpan.FromSeconds(interval));
    }

} while (!runOnce);

return 0;

static string? FindTeamRoot()
{
    var current = Directory.GetCurrentDirectory();
    while (current != null)
    {
        if (Directory.Exists(Path.Combine(current, ".squad")))
        {
            return current;
        }
        var parent = Directory.GetParent(current);
        current = parent?.FullName;
    }
    return null;
}

static List<AgentActivity> LoadActivities(string teamRoot)
{
    var activities = new List<AgentActivity>();
    var orchestrationLogPath = Path.Combine(teamRoot, ".squad", "orchestration-log");

    if (!Directory.Exists(orchestrationLogPath))
    {
        return activities;
    }

    var logFiles = Directory.GetFiles(orchestrationLogPath, "*.md")
        .OrderByDescending(f => File.GetLastWriteTime(f))
        .Take(20);

    foreach (var file in logFiles)
    {
        try
        {
            var activity = ParseOrchestrationLog(file);
            if (activity != null)
            {
                activities.Add(activity);
            }
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

    // Extract timestamp and agent name from filename: 2026-03-02T15-05-00Z-agentname.md
    var match = Regex.Match(fileName, @"^(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})Z-(.+)$");
    if (!match.Success)
    {
        return null;
    }

    var year = int.Parse(match.Groups[1].Value);
    var month = int.Parse(match.Groups[2].Value);
    var day = int.Parse(match.Groups[3].Value);
    var hour = int.Parse(match.Groups[4].Value);
    var minute = int.Parse(match.Groups[5].Value);
    var second = int.Parse(match.Groups[6].Value);
    var agentName = match.Groups[7].Value;
    
    var timestamp = new DateTime(year, month, day, hour, minute, second, DateTimeKind.Utc);

    // Parse status
    var status = "Unknown";
    var statusMatch = Regex.Match(content, @"\*\*Status:\*\*\s*(.+)");
    if (statusMatch.Success)
    {
        status = statusMatch.Groups[1].Value.Trim();
    }

    // Parse assignment/task
    var task = "";
    var assignmentMatch = Regex.Match(content, @"## Assignment\s*(.+?)(?=##|$)", RegexOptions.Singleline);
    if (assignmentMatch.Success)
    {
        task = assignmentMatch.Groups[1].Value.Trim().Replace("\r", "").Replace("\n", " ");
        if (task.Length > 150)
        {
            task = task.Substring(0, 150) + "...";
        }
    }

    // Parse outcome/result
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
            if (outcome.Length > 100)
            {
                outcome = outcome.Substring(0, 100) + "...";
            }
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

static string CapitalizeAgent(string agent)
{
    if (string.IsNullOrEmpty(agent))
        return agent;

    return char.ToUpper(agent[0]) + agent.Substring(1).ToLower();
}

static void DisplayActivities(List<AgentActivity> activities, string teamRoot)
{
    var now = DateTime.UtcNow;
    
    var rule = new Rule("[yellow]Squad Activity Monitor[/]")
    {
        Justification = Justify.Left
    };
    AnsiConsole.Write(rule);
    AnsiConsole.WriteLine();

    if (activities.Count == 0)
    {
        AnsiConsole.MarkupLine("[dim]No activities found in orchestration logs.[/]");
        return;
    }

    var table = new Table();
    table.Border(TableBorder.Rounded);
    table.AddColumn(new TableColumn("[bold]Agent[/]").Centered());
    table.AddColumn(new TableColumn("[bold]Status[/]").Centered());
    table.AddColumn(new TableColumn("[bold]Age[/]").Centered());
    table.AddColumn(new TableColumn("[bold]Task[/]").LeftAligned());
    table.AddColumn(new TableColumn("[bold]Outcome[/]").LeftAligned());

    foreach (var activity in activities)
    {
        var age = now - activity.Timestamp;
        var ageStr = FormatAge(age);
        
        var statusColor = activity.Status.Contains("✅") || activity.Status.Contains("Completed") ? "green" :
                         activity.Status.Contains("⏳") || activity.Status.Contains("Progress") ? "yellow" :
                         activity.Status.Contains("❌") || activity.Status.Contains("Failed") ? "red" :
                         "blue";

        var agentMarkup = $"[cyan]{Markup.Escape(activity.Agent)}[/]";
        var statusMarkup = $"[{statusColor}]{Markup.Escape(activity.Status)}[/]";
        var ageMarkup = age.TotalHours < 1 ? $"[green]{Markup.Escape(ageStr)}[/]" :
                       age.TotalDays < 1 ? $"[yellow]{Markup.Escape(ageStr)}[/]" :
                       $"[dim]{Markup.Escape(ageStr)}[/]";
        var taskMarkup = $"[white]{Markup.Escape(activity.Task)}[/]";
        var outcomeMarkup = !string.IsNullOrEmpty(activity.Outcome) 
            ? $"[dim]{Markup.Escape(activity.Outcome)}[/]" 
            : "[dim]-[/]";

        table.AddRow(agentMarkup, statusMarkup, ageMarkup, taskMarkup, outcomeMarkup);
    }

    AnsiConsole.Write(table);

    // Summary stats
    var totalAgents = activities.Select(a => a.Agent).Distinct().Count();
    var recentActivities = activities.Count(a => (now - a.Timestamp).TotalHours < 24);
    
    AnsiConsole.WriteLine();
    AnsiConsole.MarkupLine($"[dim]Total agents: {totalAgents} | Activities (24h): {recentActivities} | Last updated: {now:yyyy-MM-dd HH:mm:ss} UTC[/]");
}

static string FormatAge(TimeSpan age)
{
    if (age.TotalMinutes < 1)
        return "just now";
    if (age.TotalMinutes < 60)
        return $"{(int)age.TotalMinutes}m ago";
    if (age.TotalHours < 24)
        return $"{(int)age.TotalHours}h ago";
    if (age.TotalDays < 7)
        return $"{(int)age.TotalDays}d ago";
    
    return $"{(int)(age.TotalDays / 7)}w ago";
}

record AgentActivity
{
    public required string Agent { get; init; }
    public required DateTime Timestamp { get; init; }
    public required string Status { get; init; }
    public required string Task { get; init; }
    public required string Outcome { get; init; }
}
