using Microsoft.Extensions.AI;

namespace CodeReviewArena.Judges;

/// <summary>
/// A single AI judge in the arena. Wraps an IChatClient with a personality.
/// Supports streaming responses directly into a Spectre.Console renderable.
/// </summary>
public sealed class Judge
{
    private readonly IChatClient _client;
    private readonly List<ChatMessage> _history = new();

    public JudgePersonality Personality { get; }
    public string LastResponse { get; private set; } = string.Empty;

    public Judge(IChatClient client, JudgePersonality personality)
    {
        _client = client;
        Personality = personality;

        // Inject personality via system message
        _history.Add(new ChatMessage(ChatRole.System, personality.SystemPrompt));
    }

    /// <summary>
    /// Submit code for initial review. Streams each token via the <paramref name="onToken"/> callback.
    /// </summary>
    public async Task ReviewAsync(
        string codeSnippet,
        string context,
        Action<string> onToken,
        CancellationToken ct = default)
    {
        var prompt = $"""
            ## Code Under Review

            Context: {context}

            ```csharp
            {codeSnippet}
            ```

            Provide your review now.
            """;

        _history.Add(new ChatMessage(ChatRole.User, prompt));
        await StreamAndRecordAsync(onToken, ct);
    }

    /// <summary>
    /// Respond to the other judge's findings (the debate round).
    /// </summary>
    public async Task RespondToOpponentAsync(
        string opponentName,
        string opponentReview,
        Action<string> onToken,
        CancellationToken ct = default)
    {
        var prompt = $"""
            {opponentName} just submitted this review of the same code:

            ---
            {opponentReview}
            ---

            Do you agree or disagree? Where are the key points of contention?
            Specifically address their most controversial claim.
            Keep your rebuttal to 3-4 sharp paragraphs.
            """;

        _history.Add(new ChatMessage(ChatRole.User, prompt));
        await StreamAndRecordAsync(onToken, ct);
    }

    /// <summary>
    /// Produce the final consensus contribution.
    /// </summary>
    public async Task ProduceConsensusAsync(
        Action<string> onToken,
        CancellationToken ct = default)
    {
        const string prompt = """
            Based on the entire debate so far, what are the TOP 3 actionable fixes 
            the author should make right now? Be concrete — give the actual code change, 
            not vague advice. Format as a numbered list.
            """;

        _history.Add(new ChatMessage(ChatRole.User, prompt));
        await StreamAndRecordAsync(onToken, ct);
    }

    private async Task StreamAndRecordAsync(Action<string> onToken, CancellationToken ct)
    {
        var sb = new System.Text.StringBuilder();

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
        _history.Add(new ChatMessage(ChatRole.Assistant, LastResponse));
    }
}
