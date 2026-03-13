# Kusto MCP Server

An MCP (Model Context Protocol) server that provides tools for querying Azure Data Explorer (Kusto) clusters.

## Tools

| Tool | Description |
|------|-------------|
| `kusto_query` | Execute a KQL query against a cluster/database |
| `kusto_list_databases` | List available databases on a cluster |
| `kusto_list_tables` | List tables in a database |
| `kusto_get_schema` | Get table schema (columns, types) |

## Target Clusters

| Alias | Cluster URL |
|-------|------------|
| `azureportalrp` | `https://azureportalrp.westus.kusto.windows.net` |
| `icmdatawarehouse` | `https://icmdatawarehouse.kusto.windows.net` |

You can also pass a full cluster URL or any cluster name (it will be resolved to `https://{name}.kusto.windows.net`).

## Prerequisites

- **Node.js** >= 18
- **Azure credentials** configured for `DefaultAzureCredential` (Azure CLI login, managed identity, etc.)

## Setup

```bash
cd mcp-servers/kusto
npm install
npm run build
```

## Usage

### Run directly (development)

```bash
npm run dev
```

### Run compiled

```bash
npm run build
npm start
```

### MCP Configuration

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "kusto": {
      "command": "node",
      "args": ["mcp-servers/kusto/dist/index.js"]
    }
  }
}
```

Or for development with `tsx`:

```json
{
  "mcpServers": {
    "kusto": {
      "command": "npx",
      "args": ["tsx", "mcp-servers/kusto/src/index.ts"]
    }
  }
}
```

## Authentication

Uses `@azure/identity` `DefaultAzureCredential`, which tries (in order):

1. Environment variables (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_CLIENT_SECRET`)
2. Azure CLI (`az login`)
3. Azure PowerShell (`Connect-AzAccount`)
4. Managed Identity (on Azure VMs, App Service, etc.)

Make sure you have access to the target Kusto clusters before using this server.

## Example Queries

```
# List databases on the portal telemetry cluster
kusto_list_databases(cluster: "azureportalrp")

# List tables in a database
kusto_list_tables(cluster: "icmdatawarehouse", database: "IcmDataWarehouse")

# Get schema of a table
kusto_get_schema(cluster: "icmdatawarehouse", database: "IcmDataWarehouse", table: "Incidents")

# Run a KQL query
kusto_query(cluster: "azureportalrp", database: "AzurePortal", query: "PageViews | take 10")
```
