# 🚀 MCP Server Starter Kit

**A Developer's Guide to Building Model Context Protocol Servers**

> *By Tamir Dresher | tamirdresher.com*
> *Free download — no strings attached (okay, maybe your email)*

---

## What is MCP?

The **Model Context Protocol (MCP)** is an open standard that lets AI agents interact with external tools, APIs, and data sources through a structured interface. Think of it as "USB for AI" — a universal connector that lets any AI model talk to any service.

Instead of writing custom integration code for every AI model + service combination, you write **one MCP server** and every MCP-compatible AI client can use it.

### Why Build MCP Servers?

- **Reusability:** Write once, use with any AI agent (Claude, Copilot, custom agents)
- **Standardization:** Consistent tool interface across your organization
- **Security:** Centralized auth and access control
- **Composability:** Agents can discover and chain tools dynamically

---

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   AI Agent      │     │   MCP Server    │     │   Backend       │
│   (Client)      │────▶│   (Your Code)   │────▶│   Service       │
│                 │◀────│                 │◀────│                 │
│  Claude, Copilot│     │  Tool Registry  │     │  API, DB, etc.  │
│  Custom Agent   │     │  Input/Output   │     │                 │
└─────────────────┘     │  Schema Validation│   └─────────────────┘
                        └─────────────────┘
```

**Key Components:**
1. **Tool Registry** — Declares what tools are available (name, description, parameters)
2. **Request Handler** — Processes tool calls from AI agents
3. **Schema Validation** — Ensures inputs/outputs match the declared schema
4. **Transport Layer** — stdio (local) or HTTP/SSE (remote)

---

## Example 1: Data Query MCP Server

This example shows how to build an MCP server that lets AI agents query structured data — a common enterprise pattern for connecting agents to data warehouses and analytics platforms.

### Project Setup

```bash
mkdir data-query-mcp && cd data-query-mcp
npm init -y
npm install @modelcontextprotocol/sdk zod
```

### Server Implementation

```typescript
// src/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "data-query-mcp",
  version: "1.0.0",
});

// Tool: Execute a data query
server.tool(
  "query_data",
  "Execute a read-only query against the data store",
  {
    query: z.string().describe("The query to execute"),
    database: z.string().describe("Target database name"),
    limit: z.number().optional().default(100).describe("Max rows to return"),
  },
  async ({ query, database, limit }) => {
    // Validate query is read-only (security!)
    if (!isReadOnlyQuery(query)) {
      return {
        content: [{ type: "text", text: "Error: Only read-only queries are allowed." }],
        isError: true,
      };
    }

    try {
      const results = await executeQuery(database, query, limit);
      return {
        content: [{
          type: "text",
          text: JSON.stringify(results, null, 2),
        }],
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Query error: ${error.message}` }],
        isError: true,
      };
    }
  }
);

// Tool: List available databases
server.tool(
  "list_databases",
  "List all databases accessible to this server",
  {},
  async () => {
    const databases = await getDatabaseList();
    return {
      content: [{
        type: "text",
        text: databases.map(db => `- ${db.name} (${db.tables} tables)`).join("\n"),
      }],
    };
  }
);

// Tool: Get schema for a table
server.tool(
  "get_schema",
  "Get the column schema for a specific table",
  {
    database: z.string().describe("Database name"),
    table: z.string().describe("Table name"),
  },
  async ({ database, table }) => {
    const schema = await getTableSchema(database, table);
    return {
      content: [{
        type: "text",
        text: JSON.stringify(schema, null, 2),
      }],
    };
  }
);

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
```

### Key Patterns

1. **Read-only enforcement** — Always validate queries before execution
2. **Schema discovery** — Let agents explore the data model before querying
3. **Row limits** — Prevent accidentally dumping entire tables
4. **Error handling** — Return `isError: true` for graceful agent recovery

---

## Example 2: Incident Management MCP Server

This pattern connects AI agents to incident/ticket management systems — enabling automated triage, status updates, and escalation.

```typescript
// incident-mcp/src/index.ts
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

const server = new McpServer({
  name: "incident-mcp",
  version: "1.0.0",
});

// Search incidents
server.tool(
  "search_incidents",
  "Search for incidents by keyword, severity, or status",
  {
    query: z.string().optional().describe("Search text"),
    severity: z.enum(["1", "2", "3", "4"]).optional(),
    status: z.enum(["Active", "Mitigated", "Resolved"]).optional(),
    limit: z.number().optional().default(20),
  },
  async ({ query, severity, status, limit }) => {
    const incidents = await searchIncidents({ query, severity, status, limit });
    return {
      content: [{
        type: "text",
        text: formatIncidentList(incidents),
      }],
    };
  }
);

// Get incident details
server.tool(
  "get_incident",
  "Get full details for a specific incident by ID",
  {
    incidentId: z.number().describe("The incident ID"),
  },
  async ({ incidentId }) => {
    const incident = await getIncident(incidentId);
    const timeline = await getTimeline(incidentId);
    return {
      content: [{
        type: "text",
        text: formatIncidentDetail(incident, timeline),
      }],
    };
  }
);

// Add timeline entry (agent can document findings)
server.tool(
  "add_timeline_entry",
  "Add a timeline entry to an incident (for documenting investigation findings)",
  {
    incidentId: z.number().describe("The incident ID"),
    message: z.string().describe("Timeline entry text"),
  },
  async ({ incidentId, message }) => {
    await addTimelineEntry(incidentId, `[AI Agent] ${message}`);
    return {
      content: [{ type: "text", text: `Timeline entry added to incident ${incidentId}` }],
    };
  }
);
```

### Design Principles

- **Prefix AI actions** — Mark agent-generated content with `[AI Agent]` tag
- **Read-heavy, write-light** — Agents should mostly read; writes need clear audit trails
- **Scope limits** — Don't let agents close/resolve incidents; that's a human decision

---

## Example 3: Documentation MCP Server

This wraps a documentation platform to let agents search and retrieve content — perfect for building agents that can answer questions from your docs.

```typescript
// docs-mcp/src/index.ts
const server = new McpServer({
  name: "docs-mcp",
  version: "1.0.0",
});

// Search documentation
server.tool(
  "search_docs",
  "Search documentation articles by keyword",
  {
    query: z.string().describe("Search keywords"),
    category: z.string().optional().describe("Filter by category"),
    limit: z.number().optional().default(10),
  },
  async ({ query, category, limit }) => {
    const results = await searchDocumentation(query, { category, limit });
    return {
      content: [{
        type: "text",
        text: results.map(r =>
          `### ${r.title}\n${r.snippet}\n[Read more](${r.url})`
        ).join("\n\n"),
      }],
    };
  }
);

// Get full article content
server.tool(
  "get_article",
  "Retrieve the full content of a documentation article",
  {
    articleId: z.string().describe("Article identifier or URL path"),
  },
  async ({ articleId }) => {
    const article = await getArticle(articleId);
    return {
      content: [{
        type: "text",
        text: `# ${article.title}\n\n${article.content}\n\nLast updated: ${article.lastModified}`,
      }],
    };
  }
);

// Get code samples for a topic
server.tool(
  "get_code_samples",
  "Get code samples for a specific topic or API",
  {
    topic: z.string().describe("Topic or API name"),
    language: z.enum(["csharp", "python", "typescript", "go"]).optional(),
  },
  async ({ topic, language }) => {
    const samples = await getCodeSamples(topic, { language });
    return {
      content: [{
        type: "text",
        text: samples.map(s =>
          `### ${s.title}\n\`\`\`${s.language}\n${s.code}\n\`\`\``
        ).join("\n\n"),
      }],
    };
  }
);
```

---

## Registering Your MCP Server

### For GitHub Copilot CLI

Add to your MCP configuration (`.copilot/mcp-config.json` or VS Code settings):

```json
{
  "mcpServers": {
    "data-query": {
      "command": "node",
      "args": ["path/to/data-query-mcp/dist/index.js"],
      "env": {
        "DATA_ENDPOINT": "https://your-data-cluster.example.com",
        "AUTH_TOKEN": "${env:DATA_AUTH_TOKEN}"
      }
    }
  }
}
```

### For Claude Desktop

Add to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "data-query": {
      "command": "node",
      "args": ["path/to/data-query-mcp/dist/index.js"]
    }
  }
}
```

---

## Security Best Practices

1. **Never expose write operations without audit trails**
2. **Use environment variables for secrets** — Never hardcode tokens
3. **Implement rate limiting** — Agents can be chatty
4. **Validate all inputs** — Use Zod schemas (shown above)
5. **Principle of least privilege** — Read-only by default
6. **Log all tool invocations** — You need observability
7. **Use managed identity where possible** — Avoid API keys entirely

---

## Testing Your MCP Server

```bash
# Quick test with the MCP Inspector
npx @modelcontextprotocol/inspector node dist/index.js

# Or test with a simple client
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node dist/index.js
```

---

## What's Next?

- **Build a production MCP server** for your team's most-used API
- **Explore the MCP specification** at https://modelcontextprotocol.io
- **Join the community** — MCP is evolving fast with new capabilities
- **Read my blog** at tamirdresher.com for more AI agent architecture patterns

---

## About the Author

**Tamir Dresher** is a software architect specializing in AI agent systems and .NET. He's the author of "Rx.NET in Action" (Manning) and builds AI agent teams that ship production code autonomously. His Squad framework has delivered 14 merged PRs in 48 hours with zero manual prompts.

📧 Subscribe at tamirdresher.com for more guides like this.

---

*© 2026 Tamir Dresher. This guide is free to share with attribution.*
