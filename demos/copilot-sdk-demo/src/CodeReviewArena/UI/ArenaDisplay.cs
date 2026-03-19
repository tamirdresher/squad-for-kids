using CodeReviewArena.Arena;
using CodeReviewArena.Judges;
using Spectre.Console;
using Spectre.Console.Rendering;
using System.Collections.Concurrent;

namespace CodeReviewArena.UI;

/// <summary>
/// All the Spectre.Console rendering for the Arena.
/// Uses AnsiConsole.Live to stream AI tokens into split panels in real-time.
/// </summary>
public sealed class ArenaDisplay
{
    private readonly bool _isInteractive;

    public ArenaDisplay()
    {
        _isInteractive = AnsiConsole.Profile.Capabilities.Interactive;
    }

    // ── Banner ──────────────────────────────────────────────────────────────

    public void RenderBanner()
    {
        AnsiConsole.Clear();
        AnsiConsole.Write(new FigletText("Code Review Arena")
            .LeftJustified()
            .Color(Color.Gold1));

        AnsiConsole.Write(new Rule("[bold gold1]AI vs AI  ·  Live Code Review Battle  ·  Powered by GitHub Copilot SDK[/]")
            .RuleStyle("gold1 dim"));
        AnsiConsole.WriteLine();
    }

    public void RenderCodePreview(string code, string context)
    {
        var panel = new Panel(
            new Markup($"[bold white]{Markup.Escape(context)}[/]\n\n[grey]{Markup.Escape(TruncateForDisplay(code, 800))}[/]"))
        {
            Header = new PanelHeader("[bold yellow]📄  Code Under Review[/]"),
            Border = BoxBorder.Rounded,
            BorderStyle = new Style(Color.Yellow),
            Padding = new Padding(1, 0, 1, 0)
        };

        AnsiConsole.Write(panel);
        AnsiConsole.WriteLine();
    }

    // ── Round Announcements ─────────────────────────────────────────────────

    public void AnnounceRound(int roundNumber, string title, string subtitle)
    {
        AnsiConsole.WriteLine();
        AnsiConsole.Write(new Rule($"[bold white]  ROUND {roundNumber}  ·  {title}  [/]")
            .RuleStyle("white dim"));
        AnsiConsole.MarkupLine($"[dim grey]{subtitle}[/]");
        AnsiConsole.WriteLine();
    }

    // ── Dual-Panel Live Streaming ────────────────────────────────────────────

    /// <summary>
    /// Renders two side-by-side panels that stream AI tokens in real-time.
    /// The <paramref name="producer"/> receives two callbacks — one per panel —
    /// and can write tokens concurrently from parallel async tasks.
    /// </summary>
    public async Task RunLiveDualPanelAsync(
        JudgePersonality left,
        JudgePersonality right,
        Func<Action<string>, Action<string>, Task> producer)
    {
        var leftBuffer = new System.Text.StringBuilder();
        var rightBuffer = new System.Text.StringBuilder();
        var leftDone = false;
        var rightDone = false;
        var renderLock = new object();

        IRenderable BuildLayout()
        {
            lock (renderLock)
            {
                var leftText = BuildMarkupSafe(leftBuffer.ToString(), left.PanelColor);
                var rightText = BuildMarkupSafe(rightBuffer.ToString(), right.PanelColor);

                var leftPanel = new Panel(leftText)
                {
                    Header = new PanelHeader($"[bold]{left.Emoji}  {left.Name}  ·  {left.Title}[/]{(leftDone ? " ✓" : " ⋯")}"),
                    Border = BoxBorder.Rounded,
                    BorderStyle = new Style(left.PanelColor),
                    Expand = true,
                    Padding = new Padding(1, 0, 1, 0)
                };

                var rightPanel = new Panel(rightText)
                {
                    Header = new PanelHeader($"[bold]{right.Emoji}  {right.Name}  ·  {right.Title}[/]{(rightDone ? " ✓" : " ⋯")}"),
                    Border = BoxBorder.Rounded,
                    BorderStyle = new Style(right.PanelColor),
                    Expand = true,
                    Padding = new Padding(1, 0, 1, 0)
                };

                return new Columns(leftPanel, rightPanel);
            }
        }

        if (_isInteractive)
        {
            await AnsiConsole.Live(BuildLayout())
                .AutoClear(false)
                .Overflow(VerticalOverflow.Ellipsis)
                .Cropping(VerticalOverflowCropping.Bottom)
                .StartAsync(async ctx =>
                {
                    void WriteLeft(string token)
                    {
                        lock (renderLock) leftBuffer.Append(token);
                        ctx.UpdateTarget(BuildLayout());
                        ctx.Refresh();
                    }

                    void WriteRight(string token)
                    {
                        lock (renderLock) rightBuffer.Append(token);
                        ctx.UpdateTarget(BuildLayout());
                        ctx.Refresh();
                    }

                    await producer(WriteLeft, WriteRight);
                    leftDone = true;
                    rightDone = true;
                    ctx.UpdateTarget(BuildLayout());
                    ctx.Refresh();
                });
        }
        else
        {
            // Non-interactive fallback (CI, pipe) — just collect then print
            void WriteLeft(string token) => leftBuffer.Append(token);
            void WriteRight(string token) => rightBuffer.Append(token);
            await producer(WriteLeft, WriteRight);

            AnsiConsole.MarkupLine($"\n[bold]{left.Emoji} {left.Name}:[/]");
            AnsiConsole.WriteLine(leftBuffer.ToString());
            AnsiConsole.MarkupLine($"\n[bold]{right.Emoji} {right.Name}:[/]");
            AnsiConsole.WriteLine(rightBuffer.ToString());
        }
    }

    // ── Scoreboard ───────────────────────────────────────────────────────────

    public void RenderScoreboard(ArenaResult result)
    {
        AnsiConsole.WriteLine();
        AnsiConsole.Write(new Rule("[bold gold1]  🏆  FINAL SCOREBOARD  [/]").RuleStyle("gold1"));
        AnsiConsole.WriteLine();

        // Score table
        var table = new Table()
            .Border(TableBorder.Rounded)
            .BorderColor(Color.Gold1)
            .AddColumn(new TableColumn("[bold]Judge[/]").Centered())
            .AddColumn(new TableColumn("[bold]Correctness[/]").Centered())
            .AddColumn(new TableColumn("[bold]Security[/]").Centered())
            .AddColumn(new TableColumn("[bold]Performance[/]").Centered())
            .AddColumn(new TableColumn("[bold]Maintainability[/]").Centered())
            .AddColumn(new TableColumn("[bold]Design[/]").Centered())
            .AddColumn(new TableColumn("[bold]Average[/]").Centered())
            .AddColumn(new TableColumn("[bold]Verdict[/]").Centered());

        foreach (var r in result.JudgeResults)
        {
            var judge = r.JudgeName;
            table.AddRow(
                $"[bold]{judge}[/]",
                ScoreBar(r.CorrectnessScore),
                ScoreBar(r.SecurityScore),
                ScoreBar(r.PerformanceScore),
                ScoreBar(r.MaintainabilityScore),
                ScoreBar(r.DesignScore),
                $"[bold]{r.AverageScore:F1}[/]",
                r.Verdict
            );
        }

        // Consensus row
        table.AddRow(
            "[bold gold1]CONSENSUS[/]",
            "", "", "", "", "",
            $"[bold gold1]{result.OverallScore:F1}[/]",
            OverallVerdict(result.OverallScore)
        );

        AnsiConsole.Write(table);
        AnsiConsole.WriteLine();

        // Consensus actions
        AnsiConsole.Write(new Rule("[bold cyan1]  🎯  TOP ACTIONS FOR AUTHOR  [/]").RuleStyle("cyan1"));
        AnsiConsole.WriteLine();

        for (int i = 0; i < result.ConsensusActions.Length; i++)
        {
            AnsiConsole.MarkupLine($"  [bold cyan1]{i + 1}.[/] [white]{Markup.Escape(result.ConsensusActions[i])}[/]");
        }

        AnsiConsole.WriteLine();
        AnsiConsole.Write(new Rule($"[dim]Arena completed in {result.Duration.TotalSeconds:F1}s  ·  Powered by GitHub Copilot SDK[/]")
            .RuleStyle("dim"));
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static string ScoreBar(int score) =>
        score switch
        {
            >= 9 => $"[green]{score}/10 ████[/]",
            >= 7 => $"[yellow]{score}/10 ██░░[/]",
            >= 5 => $"[orange1]{score}/10 █░░░[/]",
            _ => $"[red]{score}/10 ░░░░[/]"
        };

    private static string OverallVerdict(double avg) =>
        avg >= 8 ? "[bold green]✅ APPROVE[/]"
        : avg >= 5 ? "[bold yellow]⚠️  REQUEST CHANGES[/]"
        : "[bold red]❌ REJECT[/]";

    private static string BuildMarkupSafe(string text, Color color)
    {
        if (string.IsNullOrEmpty(text))
            return "[dim grey]Thinking…[/]";

        // Escape markup characters, then re-apply colour
        var escaped = Markup.Escape(text);
        return $"[{color}]{escaped}[/]";
    }

    private static string TruncateForDisplay(string text, int max) =>
        text.Length <= max ? text : text.Substring(0, max) + "\n[…truncated for display]";
}
