// ═══════════════════════════════════════════════════════════════════════════
//  Squad in a Box  ·  Program.cs
//  Spawns four AI agents (Architect, Developer, Tester, Reviewer),
//  gives them a coding task, and shows them collaborating in real-time
//  in a beautiful Spectre.Console TUI.
//
//  Quick start:
//    $env:GITHUB_TOKEN = "github_pat_..."
//    dotnet run
//
//  Custom task:
//    dotnet run -- "Build a rate limiter middleware in C#"
// ═══════════════════════════════════════════════════════════════════════════

using Azure;
using Azure.AI.Inference;
using Microsoft.Extensions.AI;
using Spectre.Console;
using SquadInABox.Agents;
using SquadInABox.Squad;
using SquadInABox.UI;

// ── Configuration ──────────────────────────────────────────────────────────
var githubToken = Environment.GetEnvironmentVariable("GITHUB_TOKEN")
    ?? throw new InvalidOperationException(
        """
        GITHUB_TOKEN environment variable not set.

        Get a free GitHub PAT (no scopes required) at:
          https://github.com/settings/tokens

        Then set it:
          Windows : $env:GITHUB_TOKEN = "github_pat_..."
          macOS   : export GITHUB_TOKEN="github_pat_..."
        """);

var model = Environment.GetEnvironmentVariable("SQUAD_MODEL") ?? "gpt-4o-mini";
var endpoint = new Uri("https://models.inference.ai.azure.com");

// ── Parse task from CLI args ───────────────────────────────────────────────
var task = args.Length > 0
    ? string.Join(" ", args)
    : "Build a minimal TODO REST API in C# .NET with full CRUD operations and in-memory storage";

// ── Build IChatClient factory (GitHub Models via Azure.AI.Inference) ───────
//
//  The IChatClient abstraction (Microsoft.Extensions.AI) means we could swap
//  this to Azure OpenAI, Ollama, or any other backend — zero other code changes.
//
IChatClient CreateChatClient() =>
    new ChatCompletionsClient(
        endpoint,
        new AzureKeyCredential(githubToken))
        .AsChatClient(model);

// ── Create the four Squad agents ───────────────────────────────────────────
var roles = new[]
{
    AgentRole.Architect,
    AgentRole.Developer,
    AgentRole.Tester,
    AgentRole.Reviewer,
};

// Each agent gets its own IChatClient instance (separate conversation history)
var agents = roles
    .Select(role => new SquadAgent(CreateChatClient(), role))
    .ToArray();

// ── Run the demo ───────────────────────────────────────────────────────────
var display = new SquadDisplay();
display.RenderBanner(task, roles);

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;   // Don't kill the process — let us clean up
    cts.Cancel();
};

try
{
    var orchestrator = new SquadOrchestrator(agents, display);
    var result = await orchestrator.RunAsync(task, cts.Token);
    return 0;
}
catch (OperationCanceledException)
{
    AnsiConsole.MarkupLine("\n[yellow]⚡ Squad session cancelled.[/]");
    return 1;
}
catch (Exception ex)
{
    AnsiConsole.MarkupLine("\n[red]Squad session failed:[/]");
    AnsiConsole.WriteException(ex, ExceptionFormats.ShortenEverything);
    return 2;
}
