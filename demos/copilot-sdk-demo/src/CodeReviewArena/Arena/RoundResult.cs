namespace CodeReviewArena.Arena;

public sealed record RoundResult(
    string JudgeName,
    string Review,
    int CorrectnessScore,
    int SecurityScore,
    int PerformanceScore,
    int MaintainabilityScore,
    int DesignScore
)
{
    public double AverageScore =>
        (CorrectnessScore + SecurityScore + PerformanceScore + MaintainabilityScore + DesignScore) / 5.0;

    public string Verdict =>
        AverageScore >= 8 ? "✅ APPROVE"
        : AverageScore >= 5 ? "⚠️  REQUEST CHANGES"
        : "❌ REJECT";
}

public sealed record ArenaResult(
    string CodeSnippet,
    string Context,
    RoundResult[] JudgeResults,
    string[] ConsensusActions,
    TimeSpan Duration
)
{
    public RoundResult? WinningJudge =>
        JudgeResults.Length == 0 ? null :
        JudgeResults.OrderBy(r => Math.Abs(r.AverageScore - JudgeResults.Average(j => j.AverageScore))).First();

    public double OverallScore => JudgeResults.Length == 0 ? 0 : JudgeResults.Average(r => r.AverageScore);
}
