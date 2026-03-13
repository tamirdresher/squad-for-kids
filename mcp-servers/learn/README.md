# Microsoft Learn MCP Server

An MCP (Model Context Protocol) server that connects to the Microsoft Learn / Docs API, providing tools to search, browse, and retrieve content from Microsoft Learn.

## Tools

| Tool | Description |
|---|---|
| `learn_search` | Search Microsoft Learn content by query, filterable by products/languages |
| `learn_get_article` | Get article content by URL or path |
| `learn_get_module` | Get learning module details and units |
| `learn_browse` | Browse content by product, role, or level |
| `learn_get_code_samples` | Extract code samples from a documentation page |

## Setup

```bash
cd mcp-servers/learn
npm install
npm run build
```

## Usage

### As a stdio MCP server

```bash
npm start
# or during development:
npm run dev
```

### MCP client configuration

Add to your MCP client config (e.g. `.copilot/mcp-config.json`):

```json
{
  "servers": {
    "learn": {
      "type": "stdio",
      "command": "node",
      "args": ["mcp-servers/learn/dist/index.js"]
    }
  }
}
```

## Authentication

The Microsoft Learn API is public and requires no authentication for read-only access. For higher rate limits, set the `LEARN_API_KEY` environment variable:

```bash
export LEARN_API_KEY=your-api-key
```

## Tool Details

### `learn_search`

Search Microsoft Learn content.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `query` | string | Yes | Search query text |
| `products` | string[] | No | Filter by product (e.g. `["azure", "dotnet"]`) |
| `languages` | string[] | No | Filter by programming language (e.g. `["csharp"]`) |
| `top` | number | No | Max results (1–50, default 10) |

### `learn_get_article`

Retrieve article content by URL or path.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `url` | string | Yes | Full URL or path (e.g. `/en-us/dotnet/csharp/tour-of-csharp`) |

### `learn_get_module`

Get training module details including units.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `moduleUid` | string | Yes | Module UID (e.g. `learn.azure.intro-to-azure-fundamentals`) |

### `learn_browse`

Browse the Learn catalog.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `type` | string | No | `"modules"` or `"learningPaths"` (default: modules) |
| `product` | string | No | Product filter (e.g. `"azure"`) |
| `role` | string | No | Role filter (e.g. `"developer"`) |
| `level` | string | No | Level filter (e.g. `"beginner"`) |
| `top` | number | No | Max results (1–50, default 10) |

### `learn_get_code_samples`

Extract code samples from a docs page.

| Parameter | Type | Required | Description |
|---|---|---|---|
| `url` | string | Yes | Full URL or path of the page |
| `language` | string | No | Filter by language (e.g. `"csharp"`) |

## Development

```bash
npm run dev    # Run with tsx (hot-reload friendly)
npm run build  # Compile TypeScript
npm start      # Run compiled output
```
