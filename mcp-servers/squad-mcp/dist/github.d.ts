/**
 * Squad MCP Server — GitHub API Client
 *
 * Wrapper around Octokit for GitHub API operations
 */
import type { SquadConfig, GitHubIssue } from "./types.js";
export declare class GitHubClient {
    private octokit;
    private owner;
    private repo;
    constructor(config: SquadConfig);
    /**
     * Get open issues count
     */
    getOpenIssuesCount(): Promise<number>;
    /**
     * Get open pull requests count
     */
    getOpenPRsCount(): Promise<number>;
    /**
     * Get issues with a specific label
     */
    getIssuesByLabel(label: string): Promise<GitHubIssue[]>;
    /**
     * Get all open issues (for calculating avg age)
     */
    getAllOpenIssues(): Promise<GitHubIssue[]>;
    /**
     * Calculate average issue age in days
     */
    calculateAverageIssueAge(issues: GitHubIssue[]): number;
    /**
     * Get issues assigned to a specific member (by label)
     */
    getMemberIssues(member: string): Promise<GitHubIssue[]>;
}
//# sourceMappingURL=github.d.ts.map