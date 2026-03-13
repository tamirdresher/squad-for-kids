/**
 * Squad MCP Server — GitHub API Client
 *
 * Wrapper around Octokit for GitHub API operations
 */
import { Octokit } from "@octokit/rest";
export class GitHubClient {
    octokit;
    owner;
    repo;
    constructor(config) {
        this.octokit = new Octokit({ auth: config.github.token });
        this.owner = config.github.owner;
        this.repo = config.github.repo;
    }
    /**
     * Get open issues count
     */
    async getOpenIssuesCount() {
        const { data } = await this.octokit.rest.issues.listForRepo({
            owner: this.owner,
            repo: this.repo,
            state: "open",
            per_page: 1,
        });
        // GitHub API returns total count in headers
        const response = await this.octokit.rest.issues.listForRepo({
            owner: this.owner,
            repo: this.repo,
            state: "open",
            per_page: 100,
        });
        // Filter out pull requests (GitHub API includes PRs in issues endpoint)
        const issues = response.data.filter((issue) => !issue.pull_request);
        return issues.length;
    }
    /**
     * Get open pull requests count
     */
    async getOpenPRsCount() {
        const { data } = await this.octokit.rest.pulls.list({
            owner: this.owner,
            repo: this.repo,
            state: "open",
            per_page: 100,
        });
        return data.length;
    }
    /**
     * Get issues with a specific label
     */
    async getIssuesByLabel(label) {
        const { data } = await this.octokit.rest.issues.listForRepo({
            owner: this.owner,
            repo: this.repo,
            state: "open",
            labels: label,
            per_page: 100,
        });
        // Filter out pull requests
        return data.filter((issue) => !issue.pull_request);
    }
    /**
     * Get all open issues (for calculating avg age)
     */
    async getAllOpenIssues() {
        const { data } = await this.octokit.rest.issues.listForRepo({
            owner: this.owner,
            repo: this.repo,
            state: "open",
            per_page: 100,
        });
        // Filter out pull requests
        return data.filter((issue) => !issue.pull_request);
    }
    /**
     * Calculate average issue age in days
     */
    calculateAverageIssueAge(issues) {
        if (issues.length === 0)
            return 0;
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
    async getMemberIssues(member) {
        return this.getIssuesByLabel(`squad:${member}`);
    }
}
//# sourceMappingURL=github.js.map