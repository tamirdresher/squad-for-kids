/**
 * Bitwarden Shadow MCP Server — Configuration Loader
 *
 * Loads Bitwarden API credentials from environment variables or a config file.
 *
 * Environment variables (highest priority):
 *   BW_SERVER_URL      — Bitwarden server URL (default: https://vault.bitwarden.com)
 *   BW_CLIENT_ID       — API client_id  (format: organization.XXXXXX)
 *   BW_CLIENT_SECRET   — API client_secret
 *   BW_ORGANIZATION_ID — Organization GUID to operate on
 *
 * Config file (fallback): ~/.config/bitwarden-shadow-mcp/config.json
 *   { "serverUrl": "...", "clientId": "...", "clientSecret": "...", "organizationId": "..." }
 */

import { homedir } from "node:os";
import { join } from "node:path";
import { readFile } from "node:fs/promises";
import { z } from "zod";
import type { BitwardenConfig } from "./types.js";

const DEFAULT_SERVER_URL = "https://vault.bitwarden.com";

const ConfigFileSchema = z.object({
  serverUrl: z.string().url().optional(),
  clientId: z.string().min(1),
  clientSecret: z.string().min(1),
  organizationId: z.string().min(1),
});

/**
 * Load Bitwarden configuration.
 * Priority: env vars > config file > error
 */
export async function loadConfig(): Promise<BitwardenConfig> {
  const envClientId = process.env.BW_CLIENT_ID;
  const envClientSecret = process.env.BW_CLIENT_SECRET;
  const envOrgId = process.env.BW_ORGANIZATION_ID;

  if (envClientId && envClientSecret && envOrgId) {
    return {
      serverUrl: process.env.BW_SERVER_URL ?? DEFAULT_SERVER_URL,
      clientId: envClientId,
      clientSecret: envClientSecret,
      organizationId: envOrgId,
    };
  }

  // Try config file
  try {
    const configPath = join(
      homedir(),
      ".config",
      "bitwarden-shadow-mcp",
      "config.json"
    );
    const raw = await readFile(configPath, "utf-8");
    const parsed = ConfigFileSchema.parse(JSON.parse(raw));
    return {
      serverUrl: parsed.serverUrl ?? DEFAULT_SERVER_URL,
      clientId: parsed.clientId,
      clientSecret: parsed.clientSecret,
      organizationId: parsed.organizationId,
    };
  } catch (err) {
    console.error(
      `Failed to load config file: ${err instanceof Error ? err.message : String(err)}`
    );
  }

  throw new Error(
    "Bitwarden configuration not found.\n" +
      "Set BW_CLIENT_ID, BW_CLIENT_SECRET, and BW_ORGANIZATION_ID environment variables,\n" +
      "or create ~/.config/bitwarden-shadow-mcp/config.json"
  );
}
