/**
 * MCP tool: list_aac_sessions
 * Lists active/cached aac sessions (no secrets exposed).
 */

import type { AacClient } from "../aac-client.js";

export const LIST_AAC_SESSIONS_TOOL = {
  name: "list_aac_sessions",
  description:
    "List active cached aac (bitwarden/agent-access) sessions. " +
    "Returns fingerprints and metadata only — no secrets. " +
    "Use this to check if a pairing session exists before requesting credentials.",
  inputSchema: {
    type: "object",
    properties: {},
  },
} as const;

export async function listAacSessions(client: AacClient) {
  const sessions = await client.listSessions();

  if (sessions.length === 0) {
    return {
      content: [
        {
          type: "text",
          text: "No active aac sessions.\n\nTo pair with your Bitwarden vault:\n1. Run `aac listen` on your trusted device\n2. Give the pairing token to the AI\n3. Call get_credential_info with the pairing_token parameter",
        },
      ],
    };
  }

  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(sessions, null, 2),
      },
    ],
  };
}

/**
 * MCP tool: clear_aac_sessions
 */
export const CLEAR_AAC_SESSIONS_TOOL = {
  name: "clear_aac_sessions",
  description:
    "Clear cached aac sessions. Use 'sessions_only' to preserve identity key (recommended). " +
    "After clearing, the user must re-pair with `aac listen` to use credentials again.",
  inputSchema: {
    type: "object",
    properties: {
      sessions_only: {
        type: "boolean",
        description: "If true (default), only clear sessions — keep identity key. If false, clear everything.",
        default: true,
      },
    },
  },
} as const;

export async function clearAacSessions(
  client: AacClient,
  args: { sessions_only?: boolean }
) {
  const sessionsOnly = args.sessions_only !== false;
  const result = await client.clearSessions(!sessionsOnly);

  return {
    content: [{ type: "text", text: result.message }],
    isError: !result.cleared,
  };
}

/**
 * MCP tool: check_aac_available
 */
export const CHECK_AAC_AVAILABLE_TOOL = {
  name: "check_aac_available",
  description:
    "Check if the aac CLI (bitwarden/agent-access) is installed and available. " +
    "Run this first to verify setup before requesting credentials.",
  inputSchema: {
    type: "object",
    properties: {},
  },
} as const;

export async function checkAacAvailable(client: AacClient) {
  const result = await client.isAvailable();

  if (!result.available) {
    return {
      content: [
        {
          type: "text",
          text:
            `aac CLI not available: ${result.error}\n\n` +
            `Install instructions:\n` +
            `  Windows: Download aac-windows-x86_64.zip from https://github.com/bitwarden/agent-access/releases/latest\n` +
            `  macOS (Apple Silicon): curl -L https://github.com/bitwarden/agent-access/releases/latest/download/aac-macos-aarch64.tar.gz | tar xz && sudo mv aac /usr/local/bin/\n` +
            `  Linux: curl -L https://github.com/bitwarden/agent-access/releases/latest/download/aac-linux-x86_64.tar.gz | tar xz && sudo mv aac /usr/local/bin/`,
        },
      ],
      isError: true,
    };
  }

  return {
    content: [
      {
        type: "text",
        text: `aac CLI is available. Version: ${result.version ?? "unknown"}`,
      },
    ],
  };
}
