/**
 * Squad MCP Server — Get Squad Health Tool
 *
 * Returns comprehensive squad health metrics
 */

import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import type { SquadConfig } from "../types.js";
import { GitHubClient } from "../github.js";
import { SquadState } from "../squad-state.js";

export async function getSquadHealth(
  config: SquadConfig,
  args: { includeMetrics?: boolean }
): Promise<CallToolResult> {
  try {
    const includeMetrics = args.includeMetrics ?? true;

    const githubClient = new GitHubClient(config);
    const squadState = new SquadState(config);

    // Gather data
    const [
      teamMembers,
      openIssuesCount,
      openPRsCount,
      allIssues,
      untriagedIssues,
      copilotIssues,
      lastBoardUpdate,
    ] = await Promise.all([
      squadState.getTeamMembers(),
      githubClient.getOpenIssuesCount(),
      githubClient.getOpenPRsCount(),
      githubClient.getAllOpenIssues(),
      githubClient.getIssuesByLabel("squad"),
      githubClient.getIssuesByLabel("squad:copilot"),
      squadState.getLastBoardUpdate(),
    ]);

    // Calculate metrics
    const teamSize = teamMembers.filter(
      (m) => m.status.includes("✅") || m.status.includes("Active")
    ).length;
    const avgIssueAge = githubClient.calculateAverageIssueAge(allIssues);
    const issuesPerMember = teamSize > 0 ? openIssuesCount / teamSize : 0;

    // Calculate assigned issues per member
    const memberStats = await Promise.all(
      teamMembers.map(async (member) => {
        const memberName = member.name.toLowerCase();
        const assignedIssues = await githubClient.getMemberIssues(memberName);
        return {
          name: member.name,
          role: member.role,
          status: member.status,
          assignedIssues: assignedIssues.length,
        };
      })
    );

    // Determine health status
    let status: "healthy" | "warning" | "critical";
    if (openIssuesCount > 20 || openPRsCount > 10 || issuesPerMember > 4) {
      status = "critical";
    } else if (openIssuesCount > 10 || openPRsCount > 5 || issuesPerMember > 2) {
      status = "warning";
    } else {
      status = "healthy";
    }

    // Generate summary
    const statusEmoji = {
      healthy: "✅",
      warning: "⚠️",
      critical: "🔴",
    };

    const summary = `Squad health: ${statusEmoji[status]} ${status.toUpperCase()} — ${openIssuesCount} open issues, ${openPRsCount} open PRs, ${untriagedIssues.length} untriaged, ${copilotIssues.length} in @copilot queue. Average issue age: ${avgIssueAge} days.`;

    const result = {
      status,
      metrics: includeMetrics
        ? {
            teamSize,
            openIssues: openIssuesCount,
            openPRs: openPRsCount,
            issuesPerMember: Math.round(issuesPerMember * 10) / 10,
            avgIssueAge,
            untriagedCount: untriagedIssues.length,
            copilotQueueSize: copilotIssues.length,
          }
        : undefined,
      members: memberStats,
      lastBoardUpdate,
      summary,
    };

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error getting squad health: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    };
  }
}
