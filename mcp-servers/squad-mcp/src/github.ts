/**
 * Squad MCP Server — GitHub API Client
 *
 * Wrapper around Octokit for GitHub API operations
 */

import { Octokit } from "@octokit/rest";
import type { SquadConfig, GitHubIssue, GitHubPullRequest } from "./types.js";

export class GitHubClient {
  private octokit: Octokit;
  private owner: string;
  private repo: string;

  constructor(config: SquadConfig) {
    this.octokit = new Octokit({ auth: config.github.token });
    this.owner = config.github.owner;
    this.repo = config.github.repo;
  }

  /**
   * Get open issues count
   */
  async getOpenIssuesCount(): Promise<number> {
    // Use search API for accurate count beyond 100
    const { data } = await this.octokit.rest.search.issuesAndPullRequests({
      q: `repo:${this.owner}/${this.repo} is:issue is:open`,
    });
    return data.total_count;
  }

  /**
   * Get open pull requests count
   */
  async getOpenPRsCount(): Promise<number> {
    // Use search API for accurate count beyond 100
    const { data } = await this.octokit.rest.search.issuesAndPullRequests({
      q: `repo:${this.owner}/${this.repo} is:pr is:open`,
    });
    return data.total_count;
  }

  /**
   * Get issues with a specific label
   */
  async getIssuesByLabel(label: string): Promise<GitHubIssue[]> {
    // Use paginate to get all issues across all pages
    const allIssues = await this.octokit.paginate(
      this.octokit.rest.issues.listForRepo,
      {
        owner: this.owner,
        repo: this.repo,
        state: "open",
        labels: label,
        per_page: 100,
      }
    );

    // Filter out pull requests
    return allIssues.filter((issue) => !issue.pull_request) as GitHubIssue[];
  }

  /**
   * Get all open issues (for calculating avg age)
   */
  async getAllOpenIssues(): Promise<GitHubIssue[]> {
    // Use paginate to get all issues across all pages
    const allIssues = await this.octokit.paginate(
      this.octokit.rest.issues.listForRepo,
      {
        owner: this.owner,
        repo: this.repo,
        state: "open",
        per_page: 100,
      }
    );

    // Filter out pull requests
    return allIssues.filter((issue) => !issue.pull_request) as GitHubIssue[];
  }

  /**
   * Calculate average issue age in days
   */
  calculateAverageIssueAge(issues: GitHubIssue[]): number {
    if (issues.length === 0) return 0;

    const now = Date.now();
    const totalAge = issues.reduce((sum, issue) => {
      const createdAt = new Date(issue.created_at).getTime();
      const ageInDays = (now - createdAt) / (1000 * 60 * 60 * 24);
      return sum + ageInDays;
    }, 0);

    return Math.round(totalAge / issues.length);
  }

  /**
   * Get issues assigned to a specific member (by label)
   */
  async getMemberIssues(member: string): Promise<GitHubIssue[]> {
    return this.getIssuesByLabel(`squad:${member}`);
  }
}
