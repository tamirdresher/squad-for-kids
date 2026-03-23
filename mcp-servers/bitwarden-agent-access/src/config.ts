/**
 * Configuration loader for bitwarden-agent-access MCP server.
 * Reads aac CLI path and optional proxy configuration from environment.
 */

export interface Config {
  /** Path to the aac CLI binary. Defaults to "aac" (assumes it's on PATH). */
  aacBin: string;

  /**
   * Optional WebSocket proxy URL override.
   * Defaults to aac's own default: wss://ap.lesspassword.dev
   */
  proxyUrl: string | null;

  /**
   * Session fingerprint/token for pre-paired sessions.
   * Can be set via AAC_SESSION env var.
   */
  sessionToken: string | null;

  /**
   * Default pairing token. If set, aac will use this to connect
   * without requiring user to provide a token each time.
   */
  defaultPairingToken: string | null;
}

export function loadConfig(): Config {
  return {
    aacBin: process.env.AAC_BIN ?? "aac",
    proxyUrl: process.env.AAC_PROXY_URL ?? null,
    sessionToken: process.env.AAC_SESSION ?? null,
    defaultPairingToken: process.env.AAC_PAIRING_TOKEN ?? null,
  };
}
