using Microsoft.Extensions.AI;
using System.Text;

namespace SquadInABox.Agents;

/// <summary>
/// A single AI agent in the Squad. Wraps an IChatClient with a role/personality
/// and maintains conversation history for follow-up exchanges.
/// </summary>
public sealed class SquadAgent
{
    private readonly IChatClient _client;
    private readonly List<ChatMessage> _history = new();

    public AgentRole Role { get; }
    public string LastResponse { get; private set; } = string.Empty;

    public SquadAgent(IChatClient client, AgentRole role)
    {
        _client = client;
        Role = role;
        // Inject personality via system message — this shapes ALL responses
        _history.Add(new ChatMessage(ChatRole.System, role.SystemPrompt));
    }

    /// <summary>
    /// Execute the agent's primary task. Streams each token via <paramref name="onToken"/>.
    /// <paramref name="priorContext"/> contains output from all previous agents.
    /// </summary>
    public async Task ExecuteAsync(
        string task,
        string? priorContext,
        Action<string> onToken,
        CancellationToken ct = default)
    {
        var prompt = BuildPrompt(task, priorContext);
        _history.Add(new ChatMessage(ChatRole.User, prompt));
        await StreamAndRecordAsync(onToken, ct);
    }

    // ── Prompt Construction ─────────────────────────────────────────────────

    private string BuildPrompt(string task, string? priorContext) =>
        Role.Name switch
        {
            "Architect" => $"""
                ## Your Mission
                Design the architecture for this system:

                **{task}**

                Follow your system instructions exactly.
                """,

            "Developer" => $"""
                ## Your Mission
                Implement this system in C#:

                **{task}**

                ## Architecture (from the Architect)
                {priorContext ?? "No architecture provided — use your best judgment."}

                Write the complete `Program.cs` implementation now.
                """,

            "Tester" => $"""
                ## Your Mission
                Write tests for this implementation:

                **{task}**

                ## Implementation (from the Developer)
                {priorContext ?? "No implementation provided."}

                Produce your test coverage plan and test code now.
                """,

            "Reviewer" => $"""
                ## Your Mission
                Review this complete Squad output end-to-end.

                **Original task: {task}**

                ## All Prior Agent Outputs
                {priorContext ?? "No prior output available."}

                Deliver your review now.
                """,

            _ => $"Execute your role for this task: {task}"
        };

    // ── Streaming ───────────────────────────────────────────────────────────

    private async Task StreamAndRecordAsync(Action<string> onToken, CancellationToken ct)
    {
        var sb = new StringBuilder();

        await foreach (var update in _client.GetStreamingResponseAsync(_history, cancellationToken: ct))
        {
            var text = update.Text;
            if (!string.IsNullOrEmpty(text))
            {
                sb.Append(text);
                onToken(text);
            }
        }

        LastResponse = sb.ToString();
        // Add response to history so follow-up prompts have full context
        _history.Add(new ChatMessage(ChatRole.Assistant, LastResponse));
    }
}
