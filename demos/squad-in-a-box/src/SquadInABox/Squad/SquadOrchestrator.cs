using SquadInABox.Agents;
using SquadInABox.UI;

namespace SquadInABox.Squad;

/// <summary>
/// Runs the full Squad pipeline: Architect → Developer → Tester → Reviewer.
/// Each agent receives the accumulated output of all prior agents as context.
/// </summary>
public sealed class SquadOrchestrator
{
    private readonly SquadAgent[] _agents;
    private readonly SquadDisplay _display;

    public SquadOrchestrator(SquadAgent[] agents, SquadDisplay display)
    {
        _agents = agents;
        _display = display;
    }

    public async Task<SquadResult> RunAsync(string task, CancellationToken ct = default)
    {
        var sessionStart = DateTime.UtcNow;
        var artifacts = new List<AgentArtifact>();

        for (int i = 0; i < _agents.Length; i++)
        {
            var agent = _agents[i];
            ct.ThrowIfCancellationRequested();

            // Build accumulated context from ALL prior agents
            string? context = artifacts.Count > 0
                ? BuildContext(artifacts)
                : null;

            // Announce this agent is starting
            _display.AnnounceAgent(agent.Role, i + 1, _agents.Length);

            // Stream the agent's response into a live panel
            var agentStart = DateTime.UtcNow;

            await _display.RunLiveAgentPanelAsync(
                agent.Role,
                async onToken =>
                {
                    await agent.ExecuteAsync(task, context, onToken, ct);
                });

            var agentDuration = DateTime.UtcNow - agentStart;
            artifacts.Add(new AgentArtifact(
                agent.Role.Name,
                agent.Role.Emoji,
                agent.LastResponse,
                agentDuration));

            // Show completion marker between agents
            if (i < _agents.Length - 1)
            {
                _display.RenderHandoff(agent.Role, _agents[i + 1].Role);
            }
        }

        var totalDuration = DateTime.UtcNow - sessionStart;
        var result = new SquadResult(task, artifacts, totalDuration);

        // Final summary panel — the big wow moment
        _display.RenderFinalSummary(result);

        return result;
    }

    /// <summary>
    /// Builds context string passed to each successive agent.
    /// Formats all prior outputs as labelled sections.
    /// </summary>
    private static string BuildContext(IEnumerable<AgentArtifact> artifacts) =>
        string.Join("\n\n---\n\n",
            artifacts.Select(a => $"## {a.Emoji} {a.RoleName}\n\n{a.Output}"));
}
