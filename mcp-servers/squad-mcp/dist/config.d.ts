/**
 * Squad MCP Server — Configuration Loader
 *
 * Loads configuration from environment variables or config file
 */
import type { SquadConfig } from "./types.js";
/**
 * Load Squad MCP Server configuration
 *
 * Priority order:
 * 1. Environment variables (GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO, SQUAD_ROOT)
 * 2. Config file at ~/.config/squad-mcp/config.json
 * 3. Auto-detect SQUAD_ROOT from current directory (../.squad)
 */
export declare function loadConfig(): Promise<SquadConfig>;
//# sourceMappingURL=config.d.ts.map