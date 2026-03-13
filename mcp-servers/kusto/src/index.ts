#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { DefaultAzureCredential } from "@azure/identity";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Known clusters
// ---------------------------------------------------------------------------

const KNOWN_CLUSTERS: Record<string, string> = {
  azureportalrp: "https://azureportalrp.westus.kusto.windows.net",
  icmdatawarehouse: "https://icmdatawarehouse.kusto.windows.net",
};

function resolveClusterUrl(clusterInput: string): string {
  if (clusterInput.startsWith("https://")) {
    return clusterInput.replace(/\/+$/, "");
  }
  const alias = clusterInput.toLowerCase().replace(/[^a-z0-9]/g, "");
  if (KNOWN_CLUSTERS[alias]) {
    return KNOWN_CLUSTERS[alias];
  }
  return `https://${clusterInput}.kusto.windows.net`;
}

// ---------------------------------------------------------------------------
// Kusto REST helpers
// ---------------------------------------------------------------------------

const credential = new DefaultAzureCredential();

async function getAccessToken(clusterUrl: string): Promise<string> {
  const scope = `${clusterUrl}/.default`;
  const tokenResponse = await credential.getToken(scope);
  return tokenResponse.token;
}

interface KustoColumn {
  ColumnName: string;
  DataType: string;
  ColumnType: string;
}

interface KustoTable {
  TableName: string;
  Columns: KustoColumn[];
  Rows: unknown[][];
}

interface KustoResponse {
  Tables: KustoTable[];
}

async function executeKustoQuery(
  clusterUrl: string,
  database: string,
  query: string,
  properties?: Record<string, unknown>,
): Promise<KustoResponse> {
  const token = await getAccessToken(clusterUrl);
  const url = `${clusterUrl}/v1/rest/query`;

  const body: Record<string, unknown> = { db: database, csl: query };
  if (properties) {
    body.properties = JSON.stringify(properties);
  }

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Kusto query failed (${response.status} ${response.statusText}): ${errorText}`,
    );
  }

  return (await response.json()) as KustoResponse;
}

async function executeManagementCommand(
  clusterUrl: string,
  database: string,
  command: string,
): Promise<KustoResponse> {
  const token = await getAccessToken(clusterUrl);
  const url = `${clusterUrl}/v1/rest/mgmt`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ db: database, csl: command }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(
      `Kusto management command failed (${response.status} ${response.statusText}): ${errorText}`,
    );
  }

  return (await response.json()) as KustoResponse;
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

function formatResultTable(kustoResponse: KustoResponse): string {
  const primaryTable = kustoResponse.Tables?.[0];
  if (!primaryTable || primaryTable.Rows.length === 0) {
    return "No results returned.";
  }

  const columns = primaryTable.Columns.map((c) => c.ColumnName);
  const rows = primaryTable.Rows;

  // Build markdown table
  const header = `| ${columns.join(" | ")} |`;
  const separator = `| ${columns.map(() => "---").join(" | ")} |`;
  const dataRows = rows.map(
    (row) =>
      `| ${row.map((cell) => (cell === null ? "" : String(cell))).join(" | ")} |`,
  );

  return [header, separator, ...dataRows].join("\n");
}

function tableToObjects(table: KustoTable): Record<string, unknown>[] {
  const columns = table.Columns.map((c) => c.ColumnName);
  return table.Rows.map((row) => {
    const obj: Record<string, unknown> = {};
    columns.forEach((col, i) => {
      obj[col] = row[i];
    });
    return obj;
  });
}

// ---------------------------------------------------------------------------
// MCP Server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "kusto-mcp-server",
  version: "1.0.0",
});

// Tool 1: kusto_query
server.tool(
  "kusto_query",
  "Execute a KQL query against an Azure Data Explorer (Kusto) cluster and database. " +
    "Supports any valid KQL query. Results are returned as a markdown table.",
  {
    cluster: z
      .string()
      .describe(
        "Cluster name, alias, or full URL. Known aliases: azureportalrp, icmdatawarehouse",
      ),
    database: z.string().describe("Database name to query against"),
    query: z.string().describe("KQL query to execute"),
    limit: z
      .number()
      .optional()
      .default(100)
      .describe("Maximum rows to return (default 100, applied via take operator if no limit in query)"),
  },
  async ({ cluster, database, query, limit }) => {
    try {
      const clusterUrl = resolveClusterUrl(cluster);

      // If the query doesn't already contain a limit/take, append one
      const lowerQuery = query.toLowerCase().trim();
      let finalQuery = query;
      if (
        limit &&
        !lowerQuery.includes("| take ") &&
        !lowerQuery.includes("| limit ") &&
        !lowerQuery.includes("| top ")
      ) {
        finalQuery = `${query} | take ${limit}`;
      }

      const result = await executeKustoQuery(clusterUrl, database, finalQuery);
      const formatted = formatResultTable(result);
      const rowCount = result.Tables?.[0]?.Rows?.length ?? 0;

      return {
        content: [
          {
            type: "text" as const,
            text: `Query executed against ${clusterUrl} / ${database}\nRows returned: ${rowCount}\n\n${formatted}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Error: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// Tool 2: kusto_list_databases
server.tool(
  "kusto_list_databases",
  "List all databases available on an Azure Data Explorer (Kusto) cluster.",
  {
    cluster: z
      .string()
      .describe(
        "Cluster name, alias, or full URL. Known aliases: azureportalrp, icmdatawarehouse",
      ),
  },
  async ({ cluster }) => {
    try {
      const clusterUrl = resolveClusterUrl(cluster);
      const result = await executeManagementCommand(
        clusterUrl,
        "",
        ".show databases",
      );

      const table = result.Tables?.[0];
      if (!table || table.Rows.length === 0) {
        return {
          content: [
            { type: "text" as const, text: "No databases found on the cluster." },
          ],
        };
      }

      const databases = tableToObjects(table);
      const dbList = databases
        .map(
          (db) =>
            `- **${db["DatabaseName"]}** (PrettyName: ${db["PrettyName"] || "N/A"})`,
        )
        .join("\n");

      return {
        content: [
          {
            type: "text" as const,
            text: `Databases on ${clusterUrl}:\n\n${dbList}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Error: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// Tool 3: kusto_list_tables
server.tool(
  "kusto_list_tables",
  "List all tables in a specific database on an Azure Data Explorer (Kusto) cluster.",
  {
    cluster: z
      .string()
      .describe(
        "Cluster name, alias, or full URL. Known aliases: azureportalrp, icmdatawarehouse",
      ),
    database: z.string().describe("Database name"),
  },
  async ({ cluster, database }) => {
    try {
      const clusterUrl = resolveClusterUrl(cluster);
      const result = await executeManagementCommand(
        clusterUrl,
        database,
        ".show tables",
      );

      const table = result.Tables?.[0];
      if (!table || table.Rows.length === 0) {
        return {
          content: [
            {
              type: "text" as const,
              text: `No tables found in database '${database}'.`,
            },
          ],
        };
      }

      const tables = tableToObjects(table);
      const tableList = tables
        .map(
          (t) =>
            `- **${t["TableName"]}** (Folder: ${t["Folder"] || "/"}, DocString: ${t["DocString"] || "N/A"})`,
        )
        .join("\n");

      return {
        content: [
          {
            type: "text" as const,
            text: `Tables in ${database} on ${clusterUrl}:\n\n${tableList}\n\nTotal: ${tables.length} tables`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Error: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// Tool 4: kusto_get_schema
server.tool(
  "kusto_get_schema",
  "Get the schema (columns and types) of a specific table in a Kusto database.",
  {
    cluster: z
      .string()
      .describe(
        "Cluster name, alias, or full URL. Known aliases: azureportalrp, icmdatawarehouse",
      ),
    database: z.string().describe("Database name"),
    table: z.string().describe("Table name to get schema for"),
  },
  async ({ cluster, database, table: tableName }) => {
    try {
      const clusterUrl = resolveClusterUrl(cluster);
      const result = await executeManagementCommand(
        clusterUrl,
        database,
        `.show table ${tableName} schema as json`,
      );

      const responseTable = result.Tables?.[0];
      if (!responseTable || responseTable.Rows.length === 0) {
        return {
          content: [
            {
              type: "text" as const,
              text: `No schema found for table '${tableName}'.`,
            },
          ],
        };
      }

      // The schema JSON is in the first row, first column
      const schemaJson = responseTable.Rows[0][0] as string;
      let schema: {
        Name: string;
        OrderedColumns: Array<{ Name: string; Type: string; CslType: string }>;
      };

      try {
        schema = JSON.parse(schemaJson);
      } catch {
        // Fallback: return raw content
        return {
          content: [
            {
              type: "text" as const,
              text: `Schema for ${tableName}:\n\n${formatResultTable(result)}`,
            },
          ],
        };
      }

      const columns = schema.OrderedColumns || [];
      const header = "| Column | Type | CslType |";
      const separator = "| --- | --- | --- |";
      const rows = columns.map(
        (col) => `| ${col.Name} | ${col.Type} | ${col.CslType} |`,
      );

      return {
        content: [
          {
            type: "text" as const,
            text: `Schema for **${schema.Name || tableName}** in ${database} on ${clusterUrl}:\n\n${[header, separator, ...rows].join("\n")}\n\nTotal columns: ${columns.length}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Error: ${error instanceof Error ? error.message : String(error)}`,
          },
        ],
        isError: true,
      };
    }
  },
);

// ---------------------------------------------------------------------------
// Start server
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Kusto MCP server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
