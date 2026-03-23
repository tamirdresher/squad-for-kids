/**
 * Tool registry — exports all tool definitions and dispatch map
 */

export { GET_CREDENTIAL_INFO_TOOL } from "./get-credential-info.js";
export { RUN_WITH_CREDENTIAL_TOOL } from "./run-with-credential.js";
export {
  LIST_AAC_SESSIONS_TOOL,
  CLEAR_AAC_SESSIONS_TOOL,
  CHECK_AAC_AVAILABLE_TOOL,
} from "./sessions.js";

import {
  GET_CREDENTIAL_INFO_TOOL,
  getCredentialInfo,
} from "./get-credential-info.js";
import {
  RUN_WITH_CREDENTIAL_TOOL,
  runWithCredential,
} from "./run-with-credential.js";
import {
  LIST_AAC_SESSIONS_TOOL,
  listAacSessions,
  CLEAR_AAC_SESSIONS_TOOL,
  clearAacSessions,
  CHECK_AAC_AVAILABLE_TOOL,
  checkAacAvailable,
} from "./sessions.js";
import type { AacClient } from "../aac-client.js";

export const ALL_TOOLS = [
  GET_CREDENTIAL_INFO_TOOL,
  RUN_WITH_CREDENTIAL_TOOL,
  LIST_AAC_SESSIONS_TOOL,
  CLEAR_AAC_SESSIONS_TOOL,
  CHECK_AAC_AVAILABLE_TOOL,
];

export type ToolName =
  | "get_credential_info"
  | "run_with_credential"
  | "list_aac_sessions"
  | "clear_aac_sessions"
  | "check_aac_available";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function dispatchTool(client: AacClient, name: string, args: any) {
  switch (name as ToolName) {
    case "get_credential_info":
      return getCredentialInfo(client, args);
    case "run_with_credential":
      return runWithCredential(client, args);
    case "list_aac_sessions":
      return listAacSessions(client);
    case "clear_aac_sessions":
      return clearAacSessions(client, args);
    case "check_aac_available":
      return checkAacAvailable(client);
    default:
      return {
        content: [{ type: "text", text: `Unknown tool: ${name}` }],
        isError: true,
      };
  }
}
