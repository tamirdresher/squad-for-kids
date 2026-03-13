/**
 * Squad MCP Server — Squad State Readers
 *
 * Reads squad state from .squad/ files
 */
import type { SquadConfig, TeamMember, BoardSnapshot } from "./types.js";
export declare class SquadState {
    private squadRoot;
    constructor(config: SquadConfig);
    /**
     * Parse team.md to extract team members
     */
    getTeamMembers(): Promise<TeamMember[]>;
    /**
     * Read board_snapshot.json
     */
    getBoardSnapshot(): Promise<BoardSnapshot | null>;
    /**
     * Get last board update timestamp
     */
    getLastBoardUpdate(): Promise<string>;
}
//# sourceMappingURL=squad-state.d.ts.map