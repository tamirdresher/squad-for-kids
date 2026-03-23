/**
 * MCP tool: run_with_credential
 *
 * Fetches a credential from Bitwarden via aac and injects it as environment
 * variables into a child subprocess. Secrets NEVER appear in stdout or in
 * any value returned to the AI.
 *
 * This is the preferred way to use credentials in automation.
 * Example: run_with_credential(domain="github.com", command=["gh", "auth", "status"])
 * with env_mappings={"GITHUB_TOKEN": "password"}
 */

import type { AacClient } from "../aac-client.js";

export const RUN_WITH_CREDENTIAL_TOOL = {
  name: "run_with_credential",
  description:
    "Run a command with Bitwarden credentials injected as environment variables. " +
    "The credential is fetched via aac (bitwarden/agent-access) and injected directly " +
    "into the subprocess — secrets NEVER appear in stdout or in AI context. " +
    "Use env_mappings to map specific credential fields to env var names, " +
    "or omit to inject all fields with AAC_ prefix (AAC_USERNAME, AAC_PASSWORD, etc.). " +
    "Returns the command's stdout/stderr output (which should not contain secrets).",
  inputSchema: {
    type: "object",
    properties: {
      domain: {
        type: "string",
        description: "Domain to look up credentials for (e.g. 'github.com'). Mutually exclusive with item_id.",
      },
      item_id: {
        type: "string",
        description: "Bitwarden vault item ID (UUID). Mutually exclusive with domain.",
      },
      command: {
        type: "array",
        items: { type: "string" },
        description:
          "Command to run as an array of strings (e.g. ['gh', 'auth', 'status']). " +
          "The credential will be available in the command's environment.",
        minItems: 1,
      },
      env_mappings: {
        type: "object",
        additionalProperties: { type: "string" },
        description:
          "Optional mapping of environment variable names to credential fields. " +
          "Fields: username, password, totp, uri, notes, domain, credential_id. " +
          "Example: {\"GITHUB_TOKEN\": \"password\", \"GH_USER\": \"username\"}. " +
          "If omitted, all fields are injected with AAC_ prefix.",
      },
      pairing_token: {
        type: "string",
        description: "One-time pairing token from `aac listen`. Required if no cached session.",
      },
    },
    required: ["command"],
    oneOf: [{ required: ["domain"] }, { required: ["item_id"] }],
  },
} as const;

export async function runWithCredential(
  client: AacClient,
  args: {
    domain?: string;
    item_id?: string;
    command: string[];
    env_mappings?: Record<string, string>;
    pairing_token?: string;
  }
) {
  if (!args.command || args.command.length === 0) {
    return {
      content: [{ type: "text", text: "Error: command array must not be empty." }],
      isError: true,
    };
  }

  const result = await client.runWithCredential(
    args.domain ?? null,
    args.command,
    args.env_mappings,
    args.pairing_token,
    args.item_id
  );

  const summary =
    `Ran: ${args.command.join(" ")}\n` +
    `Credential injected for: ${result.credential_injected_for}\n` +
    `Exit code: ${result.exitCode}\n` +
    (result.stdout ? `\nSTDOUT:\n${result.stdout}` : "") +
    (result.stderr ? `\nSTDERR:\n${result.stderr}` : "");

  return {
    content: [{ type: "text", text: summary }],
    isError: result.exitCode !== 0,
  };
}
