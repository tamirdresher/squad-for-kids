/**
 * Types for bitwarden/agent-access (aac) CLI integration
 */

/** Output from `aac connect --output json` */
export interface AacCredentialOutput {
  success: true;
  domain: string;
  credential: {
    username: string | null;
    password: string | null;
    totp: string | null;
    uri: string | null;
    notes: string | null;
  };
}

export interface AacErrorOutput {
  success: false;
  error: {
    message: string;
    code: AacErrorCode;
  };
}

export type AacOutput = AacCredentialOutput | AacErrorOutput;

/** Exit codes from the aac CLI */
export type AacErrorCode =
  | "connection_failed"
  | "auth_failed"
  | "credential_not_found"
  | "fingerprint_mismatch"
  | "unknown";

/** Output from `aac connections list` */
export interface AacSession {
  fingerprint: string;
  provider: string;
  created_at?: string;
  last_used?: string;
}

/** Safe credential info exposed to the AI — never includes the raw password */
export interface SafeCredentialInfo {
  domain: string;
  username: string | null;
  hasPassword: boolean;
  hasTotp: boolean;
  uri: string | null;
  notes: string | null;
}

/** Result of run_with_credential */
export interface RunResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  credential_injected_for: string;
}
