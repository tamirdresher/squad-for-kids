/**
 * Squad MCP Server — Squad State Readers
 *
 * Reads squad state from .squad/ files
 */
import { readFile } from "node:fs/promises";
import { join } from "node:path";
export class SquadState {
    squadRoot;
    constructor(config) {
        this.squadRoot = config.squadRoot;
    }
    /**
     * Parse team.md to extract team members
     */
    async getTeamMembers() {
        const teamMdPath = join(this.squadRoot, "team.md");
        const content = await readFile(teamMdPath, "utf-8");
        const members = [];
        const lines = content.split("\n");
        let inMembersTable = false;
        for (const line of lines) {
            if (line.startsWith("## Members")) {
                inMembersTable = true;
                continue;
            }
            if (inMembersTable && line.startsWith("##")) {
                // End of members section
                break;
            }
            if (inMembersTable && line.startsWith("|") && !line.includes("---")) {
                const cols = line.split("|").map((col) => col.trim()).filter(Boolean);
                // Skip header row
                if (cols[0] === "Name" || cols.length < 4)
                    continue;
                // Extract member data
                const [name, role, charter, status] = cols;
                // Skip human members and non-agents
                if (name.includes("👤") || name === "@copilot")
                    continue;
                members.push({ name, role, charter, status });
            }
        }
        return members;
    }
    /**
     * Read board_snapshot.json
     */
    async getBoardSnapshot() {
        try {
            const snapshotPath = join(this.squadRoot, "board_snapshot.json");
            const content = await readFile(snapshotPath, "utf-8");
            return JSON.parse(content);
        }
        catch (err) {
            // File doesn't exist or is invalid
            return null;
        }
    }
    /**
     * Get last board update timestamp
     */
    async getLastBoardUpdate() {
        const snapshot = await this.getBoardSnapshot();
        return snapshot?.timestamp ?? new Date().toISOString();
    }
}
//# sourceMappingURL=squad-state.js.map