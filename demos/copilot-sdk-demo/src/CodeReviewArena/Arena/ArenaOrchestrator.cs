using CodeReviewArena.Judges;
using CodeReviewArena.UI;

namespace CodeReviewArena.Arena;

/// <summary>
/// Runs the full AI Code Review Arena session:
///   Round 1 — Both judges independently review the code (parallel streaming)
///   Round 2 — Each judge responds to the other's findings (the debate)
///   Round 3 — Both judges provide top-3 consensus fixes
///   Final    — Score board, diff summary, and verdict banner
/// </summary>
public sealed class ArenaOrchestrator
{
    private readonly Judge[] _judges;
    private readonly ArenaDisplay _display;

    public ArenaOrchestrator(Judge[] judges, ArenaDisplay display)
    {
        _judges = judges;
        _display = display;
    }

    public async Task<ArenaResult> RunAsync(
        string codeSnippet,
        string context,
        CancellationToken ct = default)
    {
        var start = DateTime.UtcNow;

        // ── Round 1: Independent Reviews ──────────────────────────────────────
        _display.AnnounceRound(1, "⚔️  INDEPENDENT REVIEWS", "Both judges examine the code simultaneously");

        await _display.RunLiveDualPanelAsync(
            _judges[0].Personality, _judges[1].Personality,
            async (leftWriter, rightWriter) =>
            {
                // Run both judges in parallel — the visual split-screen effect
                var leftTask = _judges[0].ReviewAsync(codeSnippet, context, leftWriter, ct);
                var rightTask = _judges[1].ReviewAsync(codeSnippet, context, rightWriter, ct);
                await Task.WhenAll(leftTask, rightTask);
            });

        // Parse scores from responses
        var round1Results = _judges.Select(j => ParseScores(j.Personality.Name, j.LastResponse)).ToArray();

        // ── Round 2: The Debate ────────────────────────────────────────────────
        _display.AnnounceRound(2, "💬  THE DEBATE", "Each judge challenges the other's findings");

        await _display.RunLiveDualPanelAsync(
            _judges[0].Personality, _judges[1].Personality,
            async (leftWriter, rightWriter) =>
            {
                // Judges respond to each other
                var leftDebate = _judges[0].RespondToOpponentAsync(
                    _judges[1].Personality.Name, _judges[1].LastResponse, leftWriter, ct);
                var rightDebate = _judges[1].RespondToOpponentAsync(
                    _judges[0].Personality.Name, _judges[0].LastResponse, rightWriter, ct);
                await Task.WhenAll(leftDebate, rightDebate);
            });

        // ── Round 3: Consensus ─────────────────────────────────────────────────
        _display.AnnounceRound(3, "🤝  CONSENSUS FIXES", "What must the author do right now?");

        var consensusActions = new List<string>();

        await _display.RunLiveDualPanelAsync(
            _judges[0].Personality, _judges[1].Personality,
            async (leftWriter, rightWriter) =>
            {
                var leftConsensus = _judges[0].ProduceConsensusAsync(leftWriter, ct);
                var rightConsensus = _judges[1].ProduceConsensusAsync(rightWriter, ct);
                await Task.WhenAll(leftConsensus, rightConsensus);
            });

        // Merge consensus points from both judges
        foreach (var judge in _judges)
        {
            consensusActions.Add($"[{judge.Personality.Name}] {TrimToFirstAction(judge.LastResponse)}");
        }

        var duration = DateTime.UtcNow - start;
        var result = new ArenaResult(codeSnippet, context, round1Results, consensusActions.ToArray(), duration);

        // ── Final Scoreboard ───────────────────────────────────────────────────
        _display.RenderScoreboard(result);

        return result;
    }

    private static RoundResult ParseScores(string judgeName, string review)
    {
        // Extract 0-10 scores from markdown "## 📊 Scores" section using simple parsing
        int ExtractScore(string dimension)
        {
            var patterns = new[] { $"{dimension}:", $"**{dimension}**:", $"{dimension} " };
            foreach (var pattern in patterns)
            {
                var idx = review.IndexOf(pattern, StringComparison.OrdinalIgnoreCase);
                if (idx >= 0)
                {
                    var segment = review.Substring(idx, Math.Min(30, review.Length - idx));
                    foreach (var token in segment.Split(' ', '/', '|', '\n', '\r'))
                    {
                        if (int.TryParse(token.Trim('.', '*', '`', '(', ')'), out var score) && score is >= 0 and <= 10)
                            return score;
                    }
                }
            }
            // Fallback: infer from sentiment
            return review.Contains("critical", StringComparison.OrdinalIgnoreCase) ? 4 : 6;
        }

        return new RoundResult(
            JudgeName: judgeName,
            Review: review,
            CorrectnessScore: ExtractScore("Correctness"),
            SecurityScore: ExtractScore("Security"),
            PerformanceScore: ExtractScore("Performance"),
            MaintainabilityScore: ExtractScore("Maintainability"),
            DesignScore: ExtractScore("Design")
        );
    }

    private static string TrimToFirstAction(string response)
    {
        var lines = response.Split('\n');
        var actionLine = lines.FirstOrDefault(l =>
            l.TrimStart().StartsWith("1.") || l.TrimStart().StartsWith("1)"));
        return actionLine?.Trim() ?? response.Split('\n').FirstOrDefault(l => l.Length > 10)?.Trim() ?? response.Substring(0, Math.Min(120, response.Length));
    }
}
