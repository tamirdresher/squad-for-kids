using CodeReviewArena.UI;
using Microsoft.Extensions.AI;
using Spectre.Console;

namespace CodeReviewArena.Tools;

/// <summary>
/// Demonstrates Microsoft.Extensions.AI tool/function calling.
///
/// The AI is given the AnalyzeCode tool and asked to:
///   1. Call the tool to get objective code metrics
///   2. Interpret those metrics in its review
///
/// This renders as a clear before/after:
///   "Here is what the AI SEES (raw code)"
///   → tool call fires automatically →
///   "Here is what the AI KNOWS (enriched metrics)"
///   → AI writes analysis grounded in the data
/// </summary>
public sealed class ToolCallDemo
{
    private readonly IChatClient _client;

    public ToolCallDemo(IChatClient client)
    {
        _client = client;
    }

    public async Task<string> RunAsync(string codeSnippet, CancellationToken ct = default)
    {
        AnsiConsole.WriteLine();
        AnsiConsole.Write(new Rule("[bold magenta1]  🔧  TOOL CALLING DEMO  —  AI-Driven Static Analysis  [/]")
            .RuleStyle("magenta1"));
        AnsiConsole.MarkupLine("[dim]The AI calls analyze_code() autonomously, gets structured metrics, then writes a data-grounded review.[/]");
        AnsiConsole.WriteLine();

        // ── Register tool with IChatClient ─────────────────────────────────────
        // UseFunctionInvocation() middleware auto-executes tool calls returned by the model.
        // The IChatClient abstraction means ANY underlying model supports this identically.
        var toolChatClient = _client.AsBuilder()
            .UseFunctionInvocation()
            .Build();

        var analyzeCodeTool = AIFunctionFactory.Create(
            CodeMetricsTool.AnalyzeCode,
            name: "analyze_code",
            description: "Statically analyse a C# code snippet. Returns line count, cyclomatic complexity, " +
                         "code smells, and security hotspots. Call this BEFORE writing your review.");

        var options = new ChatOptions
        {
            Tools = [analyzeCodeTool],
            ToolMode = ChatToolMode.Auto,   // model decides when to call
        };

        var messages = new List<ChatMessage>
        {
            new(ChatRole.System, """
                You are an expert C# code analyser with access to the analyze_code tool.
                ALWAYS call analyze_code first — use the objective metrics to anchor your findings.
                After receiving the tool result, write a concise analysis that references the actual numbers.

                Format your response with:
                ## 📊 Metrics Summary  (repeat key numbers from the tool result)
                ## 🔍 What the Data Tells Us  (interpretation)
                ## 🎯 Top 3 Actions  (actionable fixes, numbered)
                """),
            new(ChatRole.User, $"""
                Analyse this C# code. Use analyze_code first, then explain what the metrics mean.

                ```csharp
                {codeSnippet}
                ```
                """)
        };

        // ── Track tool call lifecycle ─────────────────────────────────────────
        bool toolCallDetected = false;
        bool toolResultReceived = false;
        var responseBuffer = new System.Text.StringBuilder();
        string finalResponse;

        await AnsiConsole.Status()
            .Spinner(Spinner.Known.Dots2)
            .SpinnerStyle(Style.Parse("magenta1"))
            .StartAsync("[magenta1]AI is reasoning… watching for tool call…[/]", async ctx =>
            {
                await foreach (var update in toolChatClient.GetStreamingResponseAsync(messages, options, ct))
                {
                    if (!toolCallDetected && update.Contents.OfType<FunctionCallContent>().Any())
                    {
                        toolCallDetected = true;
                        ctx.Status("[bold magenta1]⚡ Tool call detected: analyze_code() invoked by AI![/]");
                    }

                    if (!toolResultReceived && update.Contents.OfType<FunctionResultContent>().Any())
                    {
                        toolResultReceived = true;
                        ctx.Status("[bold green]✅ Tool result received — AI composing data-grounded analysis…[/]");
                    }

                    var text = update.Text;
                    if (!string.IsNullOrEmpty(text))
                        responseBuffer.Append(text);
                }
            });

        finalResponse = responseBuffer.ToString();

        // ── Show the tool's return value (rendered nicely) ─────────────────────
        var metrics = CodeMetricsTool.AnalyzeCode(codeSnippet);
        RenderMetricsPanel(metrics);

        // ── Show AI's interpretation ───────────────────────────────────────────
        if (!string.IsNullOrWhiteSpace(finalResponse))
        {
            var aiPanel = new Panel(new Markup($"[white]{Markup.Escape(finalResponse)}[/]"))
            {
                Header = new PanelHeader("[bold magenta1]🤖  AI Interpretation (post tool-call)[/]"),
                Border = BoxBorder.Rounded,
                BorderStyle = new Style(Color.Magenta1),
                Padding = new Padding(1, 0, 1, 0),
                Expand = true
            };
            AnsiConsole.Write(aiPanel);
        }

        // ── Summary line ──────────────────────────────────────────────────────
        AnsiConsole.WriteLine();
        if (toolCallDetected)
            AnsiConsole.MarkupLine("[bold green]✅ Tool calling confirmed:[/] The AI invoked [bold]analyze_code()[/] autonomously and grounded its review in real metrics.");
        else
            AnsiConsole.MarkupLine("[dim yellow]ℹ️  The AI answered without a tool call (model may have enough context from the prompt).[/]");

        AnsiConsole.WriteLine();
        return finalResponse;
    }

    // ── Render helpers ────────────────────────────────────────────────────────

    private static void RenderMetricsPanel(CodeMetrics m)
    {
        var grid = new Grid()
            .AddColumn(new GridColumn().NoWrap())
            .AddColumn(new GridColumn());

        grid.AddRow("[dim]Total / non-blank lines[/]", $"[white]{m.TotalLines}[/] / [white]{m.NonBlankLines}[/]");
        grid.AddRow("[dim]Method count[/]", $"[white]{m.MethodCount}[/]");
        grid.AddRow("[dim]Cyclomatic complexity (est.)[/]", ComplexityBadge(m.EstimatedCyclomaticComplexity));
        grid.AddRow("[dim]Max nesting depth[/]", DepthBadge(m.MaxNestingDepth));

        if (m.CodeSmells.Length > 0)
        {
            grid.AddRow("", "");
            grid.AddRow($"[yellow]▸ Code smells ({m.CodeSmells.Length})[/]", "");
            foreach (var s in m.CodeSmells)
                grid.AddRow("  [yellow]•[/]", $"[yellow]{Markup.Escape(s)}[/]");
        }

        if (m.SecurityHotspots.Length > 0)
        {
            grid.AddRow("", "");
            grid.AddRow($"[red]▸ Security hotspots ({m.SecurityHotspots.Length})[/]", "");
            foreach (var h in m.SecurityHotspots)
                grid.AddRow("  [red]•[/]", $"[red]{Markup.Escape(h)}[/]");
        }

        var panel = new Panel(grid)
        {
            Header = new PanelHeader("[bold cyan1]📦  analyze_code() → Return Value  (what the AI received)[/]"),
            Border = BoxBorder.Rounded,
            BorderStyle = new Style(Color.Cyan1),
            Padding = new Padding(1, 0, 1, 0),
            Expand = true
        };

        AnsiConsole.Write(panel);
        AnsiConsole.WriteLine();
    }

    private static string ComplexityBadge(int cc) => cc switch
    {
        <= 5 => $"[green]{cc} (simple)[/]",
        <= 10 => $"[yellow]{cc} (moderate)[/]",
        <= 20 => $"[orange1]{cc} (complex)[/]",
        _ => $"[red]{cc} (very complex — refactor)[/]"
    };

    private static string DepthBadge(int d) =>
        d <= 3 ? $"[green]{d}[/]" : d <= 5 ? $"[yellow]{d}[/]" : $"[red]{d} (deeply nested)[/]";
}
