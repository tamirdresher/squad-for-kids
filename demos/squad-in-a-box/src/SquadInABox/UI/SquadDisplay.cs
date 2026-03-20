using Spectre.Console;
using Spectre.Console.Rendering;
using SquadInABox.Agents;
using SquadInABox.Squad;

namespace SquadInABox.UI;

/// <summary>
/// All Spectre.Console rendering for the Squad demo.
/// Uses AnsiConsole.Live to stream AI tokens into panels in real-time.
/// </summary>
public sealed class SquadDisplay
{
    private readonly bool _isInteractive;

    public SquadDisplay()
    {
        _isInteractive = AnsiConsole.Profile.Capabilities.Interactive;
    }

    // ── Banner ───────────────────────────────────────────────────────────────

    public void RenderBanner(string task, AgentRole[] roles)
    {
        AnsiConsole.Clear();

        // Figlet title
        AnsiConsole.Write(
            new FigletText("SQUAD")
                .LeftJustified()
                .Color(Color.Cyan1));

        AnsiConsole.Write(
            new Rule("[bold cyan1]in a Box  ·  Multi-Agent AI Collaboration  ·  Powered by GitHub Copilot SDK[/]")
                .RuleStyle("cyan1 dim"));

        AnsiConsole.WriteLine();

        // Task display
        var taskPanel = new Panel(
            new Markup($"[bold white]{Markup.Escape(task)}[/]"))
        {
            Header = new PanelHeader("[bold yellow]🎯  Mission Briefing[/]"),
            Border = BoxBorder.Rounded,
            BorderStyle = new Style(Color.Yellow),
            Padding = new Padding(1, 0)
        };
        AnsiConsole.Write(taskPanel);
        AnsiConsole.WriteLine();

        // Agent roster table
        var table = new Table()
            .Border(TableBorder.Rounded)
            .BorderColor(Color.Grey)
            .AddColumn(new TableColumn("[bold]#[/]").Centered().Width(3))
            .AddColumn(new TableColumn("[bold]Agent[/]").Width(18))
            .AddColumn(new TableColumn("[bold]Role[/]").Width(22))
            .AddColumn(new TableColumn("[bold]Responsibility[/]"));

        string[] responsibilities =
        [
            "Define architecture, data model, and API surface",
            "Implement working C# code from the design",
            "Write tests covering happy path, edge cases, and errors",
            "Score the output and produce a final quality verdict"
        ];

        for (int i = 0; i < roles.Length; i++)
        {
            var r = roles[i];
            var color = GetColorName(r.PanelColor);
            table.AddRow(
                $"[dim]{i + 1}[/]",
                $"[bold {color}]{r.Emoji} {r.Name}[/]",
                $"[{color}]{r.Title}[/]",
                $"[dim]{responsibilities[i]}[/]"
            );
        }

        AnsiConsole.Write(table);
        AnsiConsole.WriteLine();
        AnsiConsole.MarkupLine("[dim]Starting Squad session… watch the agents collaborate in real-time.[/]");
        AnsiConsole.WriteLine();
    }

    // ── Agent Handoffs ───────────────────────────────────────────────────────

    public void AnnounceAgent(AgentRole role, int step, int total)
    {
        var color = GetColorName(role.PanelColor);
        AnsiConsole.WriteLine();
        AnsiConsole.Write(
            new Rule($"[bold {color}] STEP {step}/{total}  ·  {role.Emoji} {role.Name.ToUpper()}  ·  {role.Title} [/]")
                .RuleStyle($"{color} dim"));
        AnsiConsole.WriteLine();
    }

    public void RenderHandoff(AgentRole from, AgentRole to)
    {
        var fromColor = GetColorName(from.PanelColor);
        var toColor = GetColorName(to.PanelColor);

        AnsiConsole.WriteLine();
        AnsiConsole.MarkupLine(
            $"  [{fromColor}]{from.Emoji} {from.Name}[/] [dim]→ handing artifacts to[/] [{toColor}]{to.Emoji} {to.Name}[/] [dim]…[/]");
        AnsiConsole.WriteLine();
    }

    // ── Live Streaming Panel ─────────────────────────────────────────────────

    /// <summary>
    /// Shows a live-updating panel as the agent streams tokens.
    /// The producer receives an onToken callback and should stream into it.
    /// </summary>
    public async Task RunLiveAgentPanelAsync(
        AgentRole role,
        Func<Action<string>, Task> producer)
    {
        var buffer = new System.Text.StringBuilder();
        var done = false;
        var color = GetColorName(role.PanelColor);

        IRenderable BuildPanel()
        {
            var content = buffer.Length == 0
                ? new Markup("[dim italic]Thinking…[/]")
                : (IRenderable)new Markup(BuildMarkupSafe(buffer.ToString(), role.PanelColor));

            return new Panel(content)
            {
                Header = new PanelHeader(
                    $"[bold {color}]{role.Emoji}  {role.Name}  ·  {role.Title}[/]" +
                    (done ? $" [green]✓ Done[/]" : " [dim]⋯[/]")),
                Border = BoxBorder.Rounded,
                BorderStyle = new Style(role.PanelColor),
                Expand = true,
                Padding = new Padding(1, 0)
            };
        }

        if (_isInteractive)
        {
            await AnsiConsole.Live(BuildPanel())
                .AutoClear(false)
                .Overflow(VerticalOverflow.Ellipsis)
                .Cropping(VerticalOverflowCropping.Bottom)
                .StartAsync(async ctx =>
                {
                    void OnToken(string token)
                    {
                        buffer.Append(token);
                        ctx.UpdateTarget(BuildPanel());
                        ctx.Refresh();
                    }

                    await producer(OnToken);
                    done = true;
                    ctx.UpdateTarget(BuildPanel());
                    ctx.Refresh();
                });
        }
        else
        {
            // Non-interactive fallback (CI, pipe)
            await producer(token => buffer.Append(token));
            AnsiConsole.MarkupLine($"[bold {color}]{role.Emoji} {role.Name}:[/]");
            AnsiConsole.WriteLine(buffer.ToString());
        }
    }

    // ── Final Summary ────────────────────────────────────────────────────────

    public void RenderFinalSummary(SquadResult result)
    {
        AnsiConsole.WriteLine();
        AnsiConsole.Write(
            new Rule("[bold cyan1]  🏁  SQUAD SESSION COMPLETE  [/]")
                .RuleStyle("cyan1"));
        AnsiConsole.WriteLine();

        // Per-agent summary cards
        foreach (var artifact in result.Artifacts)
        {
            var role = GetRoleByName(artifact.RoleName);
            if (role is null) continue;

            var color = GetColorName(role.PanelColor);
            var preview = TruncateForSummary(artifact.Output, 300);

            var panel = new Panel(
                new Markup(BuildMarkupSafe(preview, role.PanelColor)))
            {
                Header = new PanelHeader(
                    $"[bold {color}]{artifact.Emoji} {artifact.RoleName}[/]" +
                    $" [dim]({artifact.Duration.TotalSeconds:F1}s)[/]"),
                Border = BoxBorder.Rounded,
                BorderStyle = new Style(role.PanelColor),
                Padding = new Padding(1, 0)
            };

            AnsiConsole.Write(panel);
            AnsiConsole.WriteLine();
        }

        // Session stats footer
        AnsiConsole.Write(
            new Rule(
                $"[dim]Session complete · {result.Artifacts.Count} agents · " +
                $"{result.TotalDuration.TotalSeconds:F1}s · Powered by GitHub Copilot SDK[/]")
                .RuleStyle("dim"));
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static string BuildMarkupSafe(string text, Color color)
    {
        if (string.IsNullOrEmpty(text))
            return "[dim italic]Thinking…[/]";

        // Escape Spectre.Console markup, then apply colour
        var escaped = Markup.Escape(text);
        return $"[{GetColorName(color)}]{escaped}[/]";
    }

    private static string GetColorName(Color color)
    {
        // Map common colours to their Spectre name
        if (color == Color.SteelBlue1) return "steelblue1";
        if (color == Color.Green3)     return "green3";
        if (color == Color.Gold1)      return "gold1";
        if (color == Color.OrangeRed1) return "orangered1";
        if (color == Color.Cyan1)      return "cyan1";
        if (color == Color.Yellow)     return "yellow";
        return color.ToString().ToLowerInvariant();
    }

    private static AgentRole? GetRoleByName(string name) =>
        name switch
        {
            "Architect" => AgentRole.Architect,
            "Developer" => AgentRole.Developer,
            "Tester"    => AgentRole.Tester,
            "Reviewer"  => AgentRole.Reviewer,
            _           => null
        };

    private static string TruncateForSummary(string text, int max)
    {
        text = text.Trim();
        return text.Length <= max
            ? text
            : text[..max] + "\n[dim]…[/] (use --save to view full output)";
    }
}
