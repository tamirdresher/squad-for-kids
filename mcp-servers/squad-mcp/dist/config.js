/**
 * Squad MCP Server — Configuration Loader
 *
 * Loads configuration from environment variables or config file
 */
import { homedir } from "node:os";
import { join } from "node:path";
import { readFile } from "node:fs/promises";
/**
 * Load Squad MCP Server configuration
 *
 * Priority order:
 * 1. Environment variables (GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO, SQUAD_ROOT)
 * 2. Config file at ~/.config/squad-mcp/config.json
 * 3. Auto-detect SQUAD_ROOT from current directory (../.squad)
 */
export async function loadConfig() {
    // Try environment variables first
    const token = process.env.GITHUB_TOKEN;
    const owner = process.env.GITHUB_OWNER;
    const repo = process.env.GITHUB_REPO;
    let squadRoot = process.env.SQUAD_ROOT;
    if (token && owner && repo) {
        // Auto-detect squadRoot if not provided
        if (!squadRoot) {
            squadRoot = join(process.cwd(), ".squad");
        }
        return {
            github: { token, owner, repo },
            squadRoot,
        };
    }
    // Try config file
    try {
        const configPath = join(homedir(), ".config", "squad-mcp", "config.json");
        const configContent = await readFile(configPath, "utf-8");
        const config = JSON.parse(configContent);
        // Validate config
        if (!config.github?.token || !config.github?.owner || !config.github?.repo) {
            throw new Error("Invalid config file: missing required fields");
        }
        // Auto-detect squadRoot if not provided
        if (!config.squadRoot) {
            config.squadRoot = join(process.cwd(), ".squad");
        }
        return config;
    }
    catch (err) {
        // Config file not found or invalid
    }
    // Fallback: try to construct config with minimal info
    if (!squadRoot) {
        squadRoot = join(process.cwd(), ".squad");
    }
    throw new Error("Configuration not found. Set GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO environment variables, " +
        "or create ~/.config/squad-mcp/config.json");
}
//# sourceMappingURL=config.js.map