/**
 * MCP tool: get_credential_info
 *
 * Returns safe metadata about a credential (username, hasPassword, hasTotp).
 * The raw password is NEVER returned — use run_with_credential to inject
 * secrets directly into a subprocess.
 */

import type { AacClient } from "../aac-client.js";

export const GET_CREDENTIAL_INFO_TOOL = {
  name: "get_credential_info",
  description:
    "Look up credential metadata from Bitwarden via aac (bitwarden/agent-access). " +
    "Returns username, hasPassword, hasTotp, and uri — but NEVER the raw password or TOTP seed. " +
    "Use run_with_credential if you need to inject the credential into a subprocess. " +
    "Requires aac CLI to be installed and a paired device session or pairing token.",
  inputSchema: {
    type: "object",
    properties: {
      domain: {
        type: "string",
        description:
          "The domain to look up (e.g. 'github.com', 'api.openai.com'). " +
          "Use the bare domain, not the full URL. Mutually exclusive with item_id.",
      },
      item_id: {
        type: "string",
        description:
          "Bitwarden vault item ID (UUID). Use instead of domain when you know the exact item. " +
          "Mutually exclusive with domain.",
      },
      pairing_token: {
        type: "string",
        description:
          "One-time pairing token from `aac listen` on the user's trusted device. " +
          "Required if no cached session exists. Ask the user to run `aac listen` to get one.",
      },
    },
    oneOf: [{ required: ["domain"] }, { required: ["item_id"] }],
  },
} as const;

export async function getCredentialInfo(
  client: AacClient,
  args: { domain?: string; item_id?: string; pairing_token?: string }
) {
  const result = await client.getCredentialInfo(
    args.domain ?? null,
    args.pairing_token,
    args.item_id
  );

  if (!result.success) {
    let hint = "";
    switch (result.code) {
      case "connection_failed":
        hint = " The user's device may not be running `aac listen`. Ask them to start it.";
        break;
      case "auth_failed":
        hint = " The pairing token may be stale. Ask the user to run `aac connections clear sessions` and get a new token from `aac listen`.";
        break;
      case "credential_not_found":
        hint = " No matching credential found for that domain. Confirm the domain with the user — they may store it under a different name.";
        break;
      case "fingerprint_mismatch":
        hint = " ⚠️ Security warning: fingerprint mismatch. Do not proceed. Alert the user immediately.";
        break;
    }

    return {
      content: [
        {
          type: "text",
          text: `Failed to get credential: ${result.error}${hint}`,
        },
      ],
      isError: true,
    };
  }

  return {
    content: [
      {
        type: "text",
        text: JSON.stringify(result.info, null, 2),
      },
    ],
  };
}
