/**
 * Squad MCP Server — Configuration Loader
 *
 * Loads configuration from environment variables or config file
 */

import { homedir } from "node:os";
import { join } from "node:path";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import type { SquadConfig } from "./types.js";

// Zod schema for validating config
const SquadConfigSchema = z.object({
  github: z.object({
    token: z.string().min(1),
    owner: z.string().min(1),
    repo: z.string().min(1),
  }),
  squadRoot: z.string().optional(),
});

/**
 * Load Squad MCP Server configuration
 *
 * Priority order:
 * 1. Environment variables (GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO, SQUAD_ROOT)
 * 2. Config file at ~/.config/squad-mcp/config.json
 * 3. Auto-detect SQUAD_ROOT from current directory (../.squad)
 */
export async function loadConfig(): Promise<SquadConfig> {
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
    const parsedConfig = JSON.parse(configContent);
    
    // Validate with Zod schema
    const config = SquadConfigSchema.parse(parsedConfig) as SquadConfig;

    // Auto-detect squadRoot if not provided
    if (!config.squadRoot) {
      config.squadRoot = join(process.cwd(), ".squad");
    }

    return config;
  } catch (err) {
    // Log config errors to stderr to help users debug
    console.error(`Failed to load config file: ${err instanceof Error ? err.message : 'Unknown error'}`);
  }

  // Fallback: try to construct config with minimal info
  if (!squadRoot) {
    squadRoot = join(process.cwd(), ".squad");
  }

  throw new Error(
    "Configuration not found. Set GITHUB_TOKEN, GITHUB_OWNER, GITHUB_REPO environment variables, " +
    "or create ~/.config/squad-mcp/config.json"
  );
}
