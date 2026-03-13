#!/usr/bin/env node

/**
 * ICM MCP Server — Incident Management
 *
 * Exposes ICM REST API operations as MCP tools so that AI assistants
 * can search, view, and update incidents directly.
 *
 * Auth: Azure AD via @azure/identity DefaultAzureCredential.
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
  type CallToolResult,
} from "@modelcontextprotocol/sdk/types.js";
import { DefaultAzureCredential } from "@azure/identity";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const ICM_BASE_URL =
  process.env.ICM_BASE_URL ?? "https://icm.ad.msft.net/api/cert";
const ICM_SCOPE =
  process.env.ICM_SCOPE ?? "https://icm.ad.msft.net/.default";

// ---------------------------------------------------------------------------
// Azure AD token helper
// ---------------------------------------------------------------------------

const credential = new DefaultAzureCredential();

async function getAccessToken(): Promise<string> {
  const token = await credential.getToken(ICM_SCOPE);
  if (!token?.token) {
    throw new Error("Failed to acquire Azure AD token for ICM");
  }
  return token.token;
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

interface IcmRequestOptions {
  path: string;
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: unknown;
  queryParams?: Record<string, string>;
}

async function icmRequest<T = unknown>(
  opts: IcmRequestOptions
): Promise<T> {
  const token = await getAccessToken();

  const url = new URL(`${ICM_BASE_URL}${opts.path}`);
  if (opts.queryParams) {
    for (const [k, v] of Object.entries(opts.queryParams)) {
      url.searchParams.set(k, v);
    }
  }

  const response = await fetch(url.toString(), {
    method: opts.method ?? "GET",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "unknown error");
    throw new Error(
      `ICM API error ${response.status} ${response.statusText}: ${errorText}`
    );
  }

  return (await response.json()) as T;
}

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

const TOOLS: Tool[] = [
  {
    name: "icm_get_incident",
    description:
      "Get full details of a specific ICM incident by its numeric ID.",
    inputSchema: {
      type: "object" as const,
      properties: {
        incidentId: {
          type: "string",
          description: "The numeric incident ID (e.g. '123456789').",
        },
      },
      required: ["incidentId"],
    },
  },
  {
    name: "icm_search_incidents",
    description:
      "Search ICM incidents using an OData filter expression. Useful for finding incidents by severity, status, owning team, title keywords, etc.",
    inputSchema: {
      type: "object" as const,
      properties: {
        filter: {
          type: "string",
          description:
            "OData $filter expression, e.g. \"Severity eq 2 and Status eq 'Active' and OwningTeamId eq 'MyTeam'\".",
        },
        top: {
          type: "number",
          description: "Maximum number of results to return (default 25).",
        },
        orderBy: {
          type: "string",
          description:
            "OData $orderby expression, e.g. 'CreateDate desc' (default: 'CreateDate desc').",
        },
        select: {
          type: "string",
          description:
            "Comma-separated list of fields to return. If omitted, all fields are returned.",
        },
      },
      required: ["filter"],
    },
  },
  {
    name: "icm_get_timeline",
    description:
      "Get timeline entries (notes, status changes, communications) for an ICM incident.",
    inputSchema: {
      type: "object" as const,
      properties: {
        incidentId: {
          type: "string",
          description: "The numeric incident ID.",
        },
        top: {
          type: "number",
          description:
            "Maximum number of timeline entries to return (default 50).",
        },
      },
      required: ["incidentId"],
    },
  },
  {
    name: "icm_list_recent",
    description:
      "List recent incidents for a given owning team or service. Returns the most recently created incidents.",
    inputSchema: {
      type: "object" as const,
      properties: {
        owningTeamId: {
          type: "string",
          description:
            "The owning team identifier (e.g. 'MyOrg\\MyTeam').",
        },
        top: {
          type: "number",
          description:
            "Maximum number of incidents to return (default 20).",
        },
        status: {
          type: "string",
          description:
            "Filter by status: 'Active', 'Mitigated', 'Resolved', or leave empty for all.",
        },
      },
      required: ["owningTeamId"],
    },
  },
  {
    name: "icm_get_mitigation",
    description:
      "Get mitigation details for a specific ICM incident, including mitigation status and notes.",
    inputSchema: {
      type: "object" as const,
      properties: {
        incidentId: {
          type: "string",
          description: "The numeric incident ID.",
        },
      },
      required: ["incidentId"],
    },
  },
  {
    name: "icm_update_incident",
    description:
      "Update fields on an existing ICM incident (severity, status, title, owning team, summary, etc.).",
    inputSchema: {
      type: "object" as const,
      properties: {
        incidentId: {
          type: "string",
          description: "The numeric incident ID to update.",
        },
        severity: {
          type: "number",
          description: "New severity level (0–4).",
        },
        status: {
          type: "string",
          description:
            "New status: 'Active', 'Mitigated', 'Resolved'.",
        },
        title: {
          type: "string",
          description: "Updated incident title.",
        },
        summary: {
          type: "string",
          description: "Updated incident summary / description.",
        },
        owningTeamId: {
          type: "string",
          description: "Transfer to a different owning team.",
        },
      },
      required: ["incidentId"],
    },
  },
  {
    name: "icm_add_timeline_entry",
    description:
      "Add a note or entry to an ICM incident timeline.",
    inputSchema: {
      type: "object" as const,
      properties: {
        incidentId: {
          type: "string",
          description: "The numeric incident ID.",
        },
        text: {
          type: "string",
          description: "The text content of the timeline entry / note.",
        },
        isCustomerImpacting: {
          type: "boolean",
          description:
            "Whether this entry relates to customer impact (default false).",
        },
      },
      required: ["incidentId", "text"],
    },
  },
];

// ---------------------------------------------------------------------------
// Tool handlers
// ---------------------------------------------------------------------------

type ToolArgs = Record<string, unknown>;

function ok(data: unknown): CallToolResult {
  return {
    content: [
      {
        type: "text",
        text: typeof data === "string" ? data : JSON.stringify(data, null, 2),
      },
    ],
  };
}

function fail(message: string): CallToolResult {
  return {
    content: [{ type: "text", text: message }],
    isError: true,
  };
}

// ---- individual handlers ----

async function getIncident(args: ToolArgs): Promise<CallToolResult> {
  const incidentId = String(args.incidentId);
  const data = await icmRequest({
    path: `/incidents/${encodeURIComponent(incidentId)}`,
  });
  return ok(data);
}

async function searchIncidents(args: ToolArgs): Promise<CallToolResult> {
  const filter = String(args.filter);
  const top = Number(args.top) || 25;
  const orderBy = String(args.orderBy || "CreateDate desc");
  const queryParams: Record<string, string> = {
    $filter: filter,
    $top: String(top),
    $orderby: orderBy,
  };
  if (args.select) {
    queryParams.$select = String(args.select);
  }
  const data = await icmRequest({
    path: "/incidents",
    queryParams,
  });
  return ok(data);
}

async function getTimeline(args: ToolArgs): Promise<CallToolResult> {
  const incidentId = String(args.incidentId);
  const top = Number(args.top) || 50;
  const data = await icmRequest({
    path: `/incidents/${encodeURIComponent(incidentId)}/timeline`,
    queryParams: { $top: String(top) },
  });
  return ok(data);
}

async function listRecent(args: ToolArgs): Promise<CallToolResult> {
  const owningTeamId = String(args.owningTeamId);
  const top = Number(args.top) || 20;
  const filterParts = [`OwningTeamId eq '${owningTeamId}'`];
  if (args.status) {
    filterParts.push(`Status eq '${String(args.status)}'`);
  }
  const data = await icmRequest({
    path: "/incidents",
    queryParams: {
      $filter: filterParts.join(" and "),
      $top: String(top),
      $orderby: "CreateDate desc",
    },
  });
  return ok(data);
}

async function getMitigation(args: ToolArgs): Promise<CallToolResult> {
  const incidentId = String(args.incidentId);
  const data = await icmRequest({
    path: `/incidents/${encodeURIComponent(incidentId)}/mitigation`,
  });
  return ok(data);
}

async function updateIncident(args: ToolArgs): Promise<CallToolResult> {
  const incidentId = String(args.incidentId);

  const patchBody: Record<string, unknown> = {};
  if (args.severity !== undefined) patchBody.Severity = Number(args.severity);
  if (args.status !== undefined) patchBody.Status = String(args.status);
  if (args.title !== undefined) patchBody.Title = String(args.title);
  if (args.summary !== undefined) patchBody.Summary = String(args.summary);
  if (args.owningTeamId !== undefined)
    patchBody.OwningTeamId = String(args.owningTeamId);

  if (Object.keys(patchBody).length === 0) {
    return fail("No update fields provided. Supply at least one field to update.");
  }

  const data = await icmRequest({
    path: `/incidents/${encodeURIComponent(incidentId)}`,
    method: "PATCH",
    body: patchBody,
  });
  return ok(data);
}

async function addTimelineEntry(args: ToolArgs): Promise<CallToolResult> {
  const incidentId = String(args.incidentId);
  const text = String(args.text);
  const isCustomerImpacting = Boolean(args.isCustomerImpacting ?? false);

  const body = {
    Text: text,
    IsCustomerImpacting: isCustomerImpacting,
  };

  const data = await icmRequest({
    path: `/incidents/${encodeURIComponent(incidentId)}/timeline`,
    method: "POST",
    body,
  });
  return ok(data);
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

const HANDLER_MAP: Record<string, (args: ToolArgs) => Promise<CallToolResult>> = {
  icm_get_incident: getIncident,
  icm_search_incidents: searchIncidents,
  icm_get_timeline: getTimeline,
  icm_list_recent: listRecent,
  icm_get_mitigation: getMitigation,
  icm_update_incident: updateIncident,
  icm_add_timeline_entry: addTimelineEntry,
};

async function handleToolCall(
  name: string,
  args: ToolArgs | undefined
): Promise<CallToolResult> {
  const handler = HANDLER_MAP[name];
  if (!handler) {
    return fail(`Unknown tool: ${name}`);
  }
  try {
    return await handler(args ?? {});
  } catch (error: unknown) {
    const message =
      error instanceof Error ? error.message : String(error);
    return fail(`Error calling ${name}: ${message}`);
  }
}

// ---------------------------------------------------------------------------
// Server bootstrap
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const server = new Server(
    {
      name: "icm-mcp-server",
      version: "1.0.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    return handleToolCall(
      request.params.name,
      request.params.arguments as ToolArgs | undefined
    );
  });

  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("ICM MCP server running on stdio");
}

main().catch((err) => {
  console.error("Fatal error starting ICM MCP server:", err);
  process.exit(1);
});
