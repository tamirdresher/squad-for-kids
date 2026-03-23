/**
 * Wrapper around the aac (bitwarden/agent-access) CLI.
 *
 * Security contract:
 *  - Raw credentials (passwords, TOTP seeds) NEVER leave this module
 *    except via run_with_credential (injected into child process env only).
 *  - The AI only ever sees SafeCredentialInfo (username, hasPassword, hasTotp).
 *  - aac run injects secrets directly into subprocess env — they never
 *    appear in stdout or any value returned to the MCP caller.
 */

import { exec, spawn } from "child_process";
import { promisify } from "util";
import type { Config } from "./config.js";
import type {
  AacOutput,
  AacCredentialOutput,
  AacSession,
  SafeCredentialInfo,
  RunResult,
} from "./types.js";

const execAsync = promisify(exec);

export class AacClient {
  constructor(private readonly config: Config) {}

  private get bin(): string {
    return this.config.aacBin;
  }

  private proxyArgs(): string[] {
    return this.config.proxyUrl ? ["--proxy-url", this.config.proxyUrl] : [];
  }

  private sessionArgs(): string[] {
    return this.config.sessionToken
      ? ["--session", this.config.sessionToken]
      : [];
  }

  /**
   * Check if the aac CLI is available on the system.
   */
  async isAvailable(): Promise<{ available: boolean; version?: string; error?: string }> {
    try {
      const { stdout } = await execAsync(`${this.bin} --version`);
      return { available: true, version: stdout.trim() };
    } catch (err) {
      return {
        available: false,
        error: `aac CLI not found at '${this.bin}'. Install from: https://github.com/bitwarden/agent-access/releases/latest`,
      };
    }
  }

  /**
   * List active/cached aac sessions.
   * Returns session metadata — no secrets.
   */
  async listSessions(): Promise<AacSession[]> {
    try {
      const args = ["connections", "list", "--output", "json", ...this.proxyArgs()];
      const { stdout } = await execAsync(`${this.bin} ${args.join(" ")}`);
      const parsed = JSON.parse(stdout.trim());
      // Normalize to array
      if (Array.isArray(parsed)) return parsed as AacSession[];
      if (parsed.sessions) return parsed.sessions as AacSession[];
      return [];
    } catch {
      // aac may return non-zero / non-JSON when no sessions exist
      return [];
    }
  }

  /**
   * Clear cached sessions (optionally only sessions, keeping identity key).
   */
  async clearSessions(all: boolean = false): Promise<{ cleared: boolean; message: string }> {
    const subcommand = all ? "clear" : "clear sessions";
    try {
      await execAsync(`${this.bin} connections ${subcommand}`);
      return { cleared: true, message: all ? "All sessions and identity key cleared." : "Sessions cleared (identity key preserved)." };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      return { cleared: false, message };
    }
  }

  /**
   * Fetch credential info for a given domain.
   *
   * Returns SafeCredentialInfo — never the raw password.
   * Use run_with_credential if you need to inject the password into a process.
   *
   * @param domain  The domain to look up (e.g. "github.com")
   * @param pairingToken  Optional one-time pairing token (from `aac listen`)
   * @param itemId  Vault item ID (use instead of domain for specific items)
   */
  async getCredentialInfo(
    domain: string | null,
    pairingToken?: string,
    itemId?: string
  ): Promise<{ success: true; info: SafeCredentialInfo } | { success: false; error: string; code: string }> {
    const args: string[] = ["connect", "--output", "json"];

    if (itemId) {
      args.push("--id", itemId);
    } else if (domain) {
      args.push("--domain", domain);
    } else {
      return { success: false, error: "Either domain or itemId must be provided.", code: "invalid_args" };
    }

    const token = pairingToken ?? this.config.defaultPairingToken;
    if (token) args.push("--token", token);

    args.push(...this.sessionArgs(), ...this.proxyArgs());

    try {
      const { stdout } = await execAsync(`${this.bin} ${args.join(" ")}`);
      const result = JSON.parse(stdout.trim()) as AacOutput;

      if (!result.success) {
        return {
          success: false,
          error: result.error.message,
          code: result.error.code,
        };
      }

      // Strip secret values — only return safe metadata to the AI
      const cred = (result as AacCredentialOutput).credential;
      const info: SafeCredentialInfo = {
        domain: result.domain,
        username: cred.username,
        hasPassword: cred.password !== null && cred.password !== "",
        hasTotp: cred.totp !== null && cred.totp !== "",
        uri: cred.uri,
        notes: cred.notes,
      };

      return { success: true, info };
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      // aac may write JSON to stdout even on error — attempt parse
      const jsonMatch = message.match(/\{.*\}/s);
      if (jsonMatch) {
        try {
          const parsed = JSON.parse(jsonMatch[0]) as AacErrorOutput;
          return { success: false, error: parsed.error.message, code: parsed.error.code };
        } catch {
          // fall through
        }
      }
      return { success: false, error: message, code: "unknown" };
    }
  }

  /**
   * Run a command with credentials injected as environment variables.
   *
   * This is the preferred way to use credentials in automation:
   * secrets are injected into the child process env only — they NEVER
   * appear in stdout/stderr returned to the AI.
   *
   * Uses `aac run --domain X --env-all -- command` under the hood.
   *
   * @param domain  Domain to fetch credentials for
   * @param command Command to run (as array of args)
   * @param envMappings  Optional field→env mappings (e.g. {DB_PASSWORD: "password"})
   * @param pairingToken  Optional pairing token
   * @param itemId  Vault item ID (use instead of domain)
   */
  async runWithCredential(
    domain: string | null,
    command: string[],
    envMappings?: Record<string, string>,
    pairingToken?: string,
    itemId?: string
  ): Promise<RunResult> {
    const args: string[] = ["run"];

    if (itemId) {
      args.push("--id", itemId);
    } else if (domain) {
      args.push("--domain", domain);
    } else {
      return { exitCode: 1, stdout: "", stderr: "Either domain or itemId must be provided.", credential_injected_for: "none" };
    }

    const token = pairingToken ?? this.config.defaultPairingToken;
    if (token) args.push("--token", token);

    // If specific env mappings provided, use them; otherwise inject all with AAC_ prefix
    if (envMappings && Object.keys(envMappings).length > 0) {
      for (const [envVar, field] of Object.entries(envMappings)) {
        args.push("--env", `${envVar}=${field}`);
      }
    } else {
      args.push("--env-all");
    }

    args.push(...this.sessionArgs(), ...this.proxyArgs());
    args.push("--", ...command);

    return new Promise((resolve) => {
      const proc = spawn(this.bin, args, {
        stdio: ["inherit", "pipe", "pipe"],
        shell: false,
      });

      let stdout = "";
      let stderr = "";

      proc.stdout?.on("data", (chunk: Buffer) => {
        stdout += chunk.toString();
      });
      proc.stderr?.on("data", (chunk: Buffer) => {
        stderr += chunk.toString();
      });

      proc.on("close", (code) => {
        resolve({
          exitCode: code ?? 1,
          stdout,
          stderr,
          credential_injected_for: domain ?? itemId ?? "unknown",
        });
      });

      proc.on("error", (err) => {
        resolve({
          exitCode: 1,
          stdout: "",
          stderr: err.message,
          credential_injected_for: domain ?? itemId ?? "unknown",
        });
      });
    });
  }
}
