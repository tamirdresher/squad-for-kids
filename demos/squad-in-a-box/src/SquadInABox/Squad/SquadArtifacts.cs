namespace SquadInABox.Squad;

/// <summary>Output from a single Squad agent run.</summary>
public sealed record AgentArtifact(
    string RoleName,
    string Emoji,
    string Output,
    TimeSpan Duration);

/// <summary>Collected output from a complete Squad session.</summary>
public sealed record SquadResult(
    string Task,
    IReadOnlyList<AgentArtifact> Artifacts,
    TimeSpan TotalDuration)
{
    public AgentArtifact? GetArtifact(string roleName) =>
        Artifacts.FirstOrDefault(a => a.RoleName == roleName);
}
