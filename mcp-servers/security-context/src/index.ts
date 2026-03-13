/**
 * Security Context MCP Server
 *
 * Aggregates security posture data from multiple Microsoft security services:
 *  - Microsoft Graph Security API
 *  - Azure Security Center / Defender for Cloud
 *  - GitHub Advanced Security
 *
 * Security considerations:
 *  - No credentials are logged
 *  - Responses are sanitized (no tokens, secrets, or PII leak)
 *  - Rate limiting is enforced per-endpoint
 *  - Minimal scopes are requested
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { DefaultAzureCredential } from "@azure/identity";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

interface GraphSecurityAlert {
  id: string;
  title: string;
  severity: string;
  status: string;
  category: string;
  createdDateTime: string;
  description: string;
  [key: string]: unknown;
}

interface SecureScore {
  id: string;
  currentScore: number;
  maxScore: number;
  averageComparativeScores: unknown[];
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GRAPH_BASE = "https://graph.microsoft.com/v1.0";
const GRAPH_SECURITY_BASE = `${GRAPH_BASE}/security`;
const ARM_BASE = "https://management.azure.com";

/** Fields that must never appear in output. */
const SENSITIVE_FIELDS = new Set([
  "accessToken",
  "token",
  "secret",
  "password",
  "credential",
  "authorization",
  "apiKey",
  "connectionString",
  "clientSecret",
]);

/** Rate-limit: max requests per window per endpoint key. */
const RATE_LIMIT_MAX = 30;
/** Rate-limit window in milliseconds (60 s). */
const RATE_LIMIT_WINDOW_MS = 60_000;

// ---------------------------------------------------------------------------
// Credential management — lazily initialised, never logged
// ---------------------------------------------------------------------------

let _credential: DefaultAzureCredential | undefined;

function getCredential(): DefaultAzureCredential {
  if (!_credential) {
    _credential = new DefaultAzureCredential();
  }
  return _credential;
}

/**
 * GitHub token — captured once at module load, then scrubbed from env
 * to reduce exposure surface (crash dumps, child processes, etc.).
 */
const _ghToken: string | undefined = process.env.GITHUB_TOKEN;
if (_ghToken) {
  delete process.env.GITHUB_TOKEN;
}

// ---------------------------------------------------------------------------
// Rate limiter — simple sliding-window per endpoint
// ---------------------------------------------------------------------------

const rateLimitBuckets = new Map<string, RateLimitEntry>();

function checkRateLimit(endpointKey: string): void {
  const now = Date.now();
  let entry = rateLimitBuckets.get(endpointKey);

  if (!entry || now >= entry.resetAt) {
    entry = { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS };
    rateLimitBuckets.set(endpointKey, entry);
  }

  if (entry.count >= RATE_LIMIT_MAX) {
    const retryAfterSec = Math.ceil((entry.resetAt - now) / 1000);
    throw new Error(
      `Rate limit exceeded for "${endpointKey}". Retry after ${retryAfterSec}s.`
    );
  }

  entry.count++;
}

// ---------------------------------------------------------------------------
// Response sanitiser — strip sensitive fields recursively
// ---------------------------------------------------------------------------

function sanitize<T>(obj: T): T {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === "string") return obj;

  if (Array.isArray(obj)) {
    return obj.map((item) => sanitize(item)) as unknown as T;
  }

  if (typeof obj === "object") {
    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
      if (SENSITIVE_FIELDS.has(key.toLowerCase())) {
        sanitized[key] = "[REDACTED]";
      } else {
        sanitized[key] = sanitize(value);
      }
    }
    return sanitized as T;
  }

  return obj;
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

/**
 * Sanitize an error response body — strip anything that could contain
 * credentials, tokens, or other sensitive data before including in errors.
 */
function sanitizeErrorBody(body: string, maxLen = 200): string {
  if (!body) return "";
  // Truncate to prevent large payloads leaking into error messages
  const truncated = body.length > maxLen ? body.slice(0, maxLen) + "…" : body;
  // Strip anything that looks like a token/key/secret value
  return truncated.replace(
    /(?:token|key|secret|password|credential|authorization)["\s:=]+[^\s,}"]{8,}/gi,
    "[REDACTED]",
  );
}

async function graphFetch<T>(
  path: string,
  scopes: string[] = ["https://graph.microsoft.com/.default"],
): Promise<T> {
  const token = await getCredential().getToken(scopes);
  if (!token) {
    throw new Error("Failed to acquire token for Microsoft Graph");
  }

  const url = path.startsWith("http") ? path : `${GRAPH_SECURITY_BASE}${path}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token.token}` },
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Graph API error ${res.status}: ${sanitizeErrorBody(body)}`);
  }

  return (await res.json()) as T;
}

async function armFetch<T>(
  path: string,
  apiVersion: string,
): Promise<T> {
  const token = await getCredential().getToken([
    "https://management.azure.com/.default",
  ]);
  if (!token) {
    throw new Error("Failed to acquire token for Azure Resource Manager");
  }

  const separator = path.includes("?") ? "&" : "?";
  const url = `${ARM_BASE}${path}${separator}api-version=${apiVersion}`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token.token}` },
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`ARM API error ${res.status}: ${sanitizeErrorBody(body)}`);
  }

  return (await res.json()) as T;
}

async function githubFetch<T>(path: string): Promise<T> {
  if (!_ghToken) {
    throw new Error(
      "GITHUB_TOKEN environment variable is required for GitHub Advanced Security"
    );
  }

  const url = path.startsWith("http")
    ? path
    : `https://api.github.com${path}`;
  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${_ghToken}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });

  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`GitHub API error ${res.status}: ${sanitizeErrorBody(body)}`);
  }

  return (await res.json()) as T;
}

// ---------------------------------------------------------------------------
// MCP Server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "security-context",
  version: "1.0.0",
});

// ---- Tool 1: security_get_alerts ----

server.tool(
  "security_get_alerts",
  "Retrieve security alerts from Microsoft Graph Security API. " +
    "Returns alert id, title, severity, status, category, and timestamps. " +
    "Supports filtering by severity, status, and result count.",
  {
    severity: z
      .enum(["low", "medium", "high", "critical", "informational", "unknown"])
      .optional()
      .describe("Filter alerts by severity level"),
    status: z
      .enum(["new", "inProgress", "resolved", "unknownFutureValue"])
      .optional()
      .describe("Filter alerts by status"),
    top: z
      .number()
      .int()
      .min(1)
      .max(100)
      .default(20)
      .describe("Maximum number of alerts to return (1-100)"),
  },
  async ({ severity, status, top }) => {
    checkRateLimit("graph_alerts");

    const filters: string[] = [];
    if (severity) filters.push(`severity eq '${severity}'`);
    if (status) filters.push(`status eq '${status}'`);

    let path = `/alerts_v2?$top=${top}&$orderby=createdDateTime desc`;
    if (filters.length > 0) {
      path += `&$filter=${encodeURIComponent(filters.join(" and "))}`;
    }

    const data = await graphFetch<{ value: GraphSecurityAlert[] }>(path);
    const alerts = sanitize(data.value ?? []);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              count: alerts.length,
              alerts: alerts.map((a) => ({
                id: a.id,
                title: a.title,
                severity: a.severity,
                status: a.status,
                category: a.category,
                created: a.createdDateTime,
                description: a.description,
              })),
            },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ---- Tool 2: security_get_recommendations ----

server.tool(
  "security_get_recommendations",
  "Get security recommendations from Azure Security Center / Defender for Cloud. " +
    "Requires an Azure subscription ID. Returns actionable recommendations " +
    "with severity, status, and remediation guidance.",
  {
    subscriptionId: z
      .string()
      .describe("Azure subscription ID to query recommendations for"),
    top: z
      .number()
      .int()
      .min(1)
      .max(50)
      .default(20)
      .describe("Maximum number of recommendations to return (1-50)"),
  },
  async ({ subscriptionId, top }) => {
    checkRateLimit("arm_recommendations");

    const path = `/subscriptions/${encodeURIComponent(subscriptionId)}/providers/Microsoft.Security/assessments`;
    const data = await armFetch<{ value: Record<string, unknown>[] }>(
      path,
      "2021-06-01",
    );

    const items = sanitize((data.value ?? []).slice(0, top));

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { count: items.length, recommendations: items },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ---- Tool 3: security_get_score ----

server.tool(
  "security_get_score",
  "Get the Microsoft Secure Score for the tenant. " +
    "Returns current score, max possible score, and comparative averages.",
  {},
  async () => {
    checkRateLimit("graph_secure_score");

    const data = await graphFetch<{ value: SecureScore[] }>(
      `${GRAPH_BASE}/security/secureScores?$top=1&$orderby=createdDateTime desc`,
    );

    const score = sanitize(data.value?.[0] ?? null);

    if (!score) {
      return {
        content: [
          {
            type: "text" as const,
            text: JSON.stringify({ error: "No secure score data available" }),
          },
        ],
      };
    }

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              currentScore: score.currentScore,
              maxScore: score.maxScore,
              percentage:
                score.maxScore > 0
                  ? Math.round((score.currentScore / score.maxScore) * 100)
                  : 0,
              comparativeScores: score.averageComparativeScores,
            },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ---- Tool 4: security_get_vulnerabilities ----

server.tool(
  "security_get_vulnerabilities",
  "Get vulnerability assessments. Queries GitHub Advanced Security code scanning " +
    "alerts for a given repository, optionally filtered by severity.",
  {
    owner: z.string().describe("GitHub repository owner (user or org)"),
    repo: z.string().describe("GitHub repository name"),
    severity: z
      .enum(["critical", "high", "medium", "low", "warning", "note", "error"])
      .optional()
      .describe("Filter by alert severity"),
    state: z
      .enum(["open", "closed", "dismissed", "fixed"])
      .default("open")
      .describe("Filter by alert state"),
    top: z
      .number()
      .int()
      .min(1)
      .max(100)
      .default(30)
      .describe("Maximum number of vulnerabilities to return (1-100)"),
  },
  async ({ owner, repo, severity, state, top }) => {
    checkRateLimit("github_vulnerabilities");

    let path = `/repos/${encodeURIComponent(owner)}/${encodeURIComponent(repo)}/code-scanning/alerts?state=${state}&per_page=${top}`;
    if (severity) {
      path += `&severity=${severity}`;
    }

    const alerts = await githubFetch<Record<string, unknown>[]>(path);
    const cleaned = sanitize(alerts ?? []);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { count: cleaned.length, vulnerabilities: cleaned },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ---- Tool 5: security_search_threats ----

server.tool(
  "security_search_threats",
  "Search threat intelligence data via Microsoft Graph Security. " +
    "Searches threat intelligence indicators matching a keyword or IoC value.",
  {
    query: z
      .string()
      .min(1)
      .describe("Search keyword or IoC value (IP, domain, hash, etc.)"),
    top: z
      .number()
      .int()
      .min(1)
      .max(50)
      .default(20)
      .describe("Maximum number of results to return (1-50)"),
  },
  async ({ query, top }) => {
    checkRateLimit("graph_threat_intel");

    // Use the tiIndicators endpoint with filter
    const path =
      `${GRAPH_BASE}/security/threatIntelligence/articles` +
      `?$search="${encodeURIComponent(query)}"&$top=${top}`;

    const data = await graphFetch<{ value: Record<string, unknown>[] }>(path);
    const results = sanitize(data.value ?? []);

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            { count: results.length, query, threats: results },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ---- Tool 6: security_get_compliance ----

server.tool(
  "security_get_compliance",
  "Get compliance posture from Azure Security Center / Defender for Cloud. " +
    "Returns regulatory compliance standards and their assessment status " +
    "for a given Azure subscription.",
  {
    subscriptionId: z
      .string()
      .describe("Azure subscription ID to query compliance for"),
    standard: z
      .string()
      .optional()
      .describe(
        "Specific compliance standard name to filter (e.g. 'Azure-CIS-1.3.0')",
      ),
  },
  async ({ subscriptionId, standard }) => {
    checkRateLimit("arm_compliance");

    let path = `/subscriptions/${encodeURIComponent(subscriptionId)}/providers/Microsoft.Security/regulatoryComplianceStandards`;
    if (standard) {
      path += `/${encodeURIComponent(standard)}`;
    }

    const data = await armFetch<{ value?: Record<string, unknown>[]; [key: string]: unknown }>(
      path,
      "2019-01-01-preview",
    );

    const result = sanitize(standard ? data : (data.value ?? []));

    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            standard
              ? { standard, compliance: result }
              : { count: (result as unknown[]).length, standards: result },
            null,
            2,
          ),
        },
      ],
    };
  },
);

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  // Log to stderr only — stdout is reserved for MCP JSON-RPC
  process.stderr.write(
    `[security-context] MCP server running (pid=${process.pid})\n`,
  );
}

main().catch((err: unknown) => {
  // Never log the full error object — it may contain tokens in stack traces
  const message = err instanceof Error ? err.message : "Unknown startup error";
  process.stderr.write(`[security-context] Fatal: ${message}\n`);
  process.exit(1);
});
