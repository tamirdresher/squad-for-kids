/**
 * Squad MCP Server — Types
 *
 * Shared TypeScript types for the Squad MCP Server
 */
export interface SquadConfig {
    github: {
        token: string;
        owner: string;
        repo: string;
    };
    squadRoot: string;
}
export interface TeamMember {
    name: string;
    role: string;
    charter: string;
    status: string;
}
export interface SquadHealthMetrics {
    teamSize: number;
    openIssues: number;
    openPRs: number;
    issuesPerMember: number;
    avgIssueAge: number;
    untriagedCount: number;
    copilotQueueSize: number;
}
export interface SquadHealthResult {
    status: "healthy" | "warning" | "critical";
    metrics: SquadHealthMetrics;
    members: Array<{
        name: string;
        role: string;
        status: string;
        assignedIssues: number;
    }>;
    lastBoardUpdate: string;
    summary: string;
}
export interface GitHubIssue {
    number: number;
    title: string;
    body: string | null;
    state: "open" | "closed";
    labels: Array<{
        name: string;
    }>;
    assignee: {
        login: string;
    } | null;
    created_at: string;
    updated_at: string;
}
export interface GitHubPullRequest {
    number: number;
    title: string;
    state: "open" | "closed";
    created_at: string;
    updated_at: string;
}
export interface BoardSnapshot {
    timestamp: string;
    issueCount: number;
    issues: Array<{
        number: number;
        title: string;
        labels: string[];
        assignee?: string;
    }>;
}
//# sourceMappingURL=types.d.ts.map