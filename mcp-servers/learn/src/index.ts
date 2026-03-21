#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const CATALOG_API = "https://learn.microsoft.com/api/catalog/";
const CONTENT_API = "https://learn.microsoft.com/api/";
const USER_AGENT = "learn-mcp-server/1.0";

function authHeaders(): Record<string, string> {
  const key = process.env.LEARN_API_KEY;
  if (key) {
    return { "api-key": key };
  }
  return {};
}

async function fetchJson<T>(url: string): Promise<T> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "application/json",
      ...authHeaders(),
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} from ${url}: ${body}`);
  }
  return (await res.json()) as T;
}

async function fetchText(url: string): Promise<string> {
  const res = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "text/html, application/json",
      ...authHeaders(),
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} from ${url}: ${body}`);
  }
  return res.text();
}

// ---------------------------------------------------------------------------
// Type helpers
// ---------------------------------------------------------------------------

interface CatalogModule {
  uid: string;
  title: string;
  summary: string;
  url: string;
  duration_in_minutes?: number;
  units?: string[];
  products?: string[];
  levels?: string[];
  roles?: string[];
}

interface CatalogUnit {
  uid: string;
  title: string;
  duration_in_minutes?: number;
}

interface CatalogResult {
  modules?: CatalogModule[];
  units?: CatalogUnit[];
  learningPaths?: Array<{
    uid: string;
    title: string;
    summary: string;
    url: string;
    duration_in_minutes?: number;
    modules?: string[];
  }>;
}

interface SearchResult {
  results: Array<{
    title: string;
    url: string;
    description: string;
    lastUpdatedDate?: string;
  }>;
  count: number;
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "learn-mcp-server",
  version: "1.0.0",
});

// ---- Tool 1: learn_search ------------------------------------------------

server.tool(
  "learn_search",
  "Search Microsoft Learn content by query. Returns titles, URLs, and descriptions.",
  {
    query: z.string().describe("Search query text"),
    products: z
      .array(z.string())
      .optional()
      .describe("Filter by product names (e.g. ['azure', 'dotnet'])"),
    languages: z
      .array(z.string())
      .optional()
      .describe("Filter by programming languages (e.g. ['csharp', 'python'])"),
    top: z
      .number()
      .int()
      .min(1)
      .max(50)
      .optional()
      .describe("Number of results to return (default 10, max 50)"),
  },
  async ({ query, products, languages, top }) => {
    const params = new URLSearchParams();
    params.set("search", query);
    params.set("$top", String(top ?? 10));
    params.set("locale", "en-us");
    if (products?.length) {
      params.set("$filter", products.map((p) => `products/any(p: p eq '${p}')`).join(" and "));
    }
    if (languages?.length) {
      params.set("facet", languages.map((l) => `languages:${l}`).join(","));
    }

    const url = `https://learn.microsoft.com/api/search?${params.toString()}`;
    const data = await fetchJson<SearchResult>(url);

    if (!data.results?.length) {
      return {
        content: [{ type: "text" as const, text: `No results found for "${query}".` }],
      };
    }

    const lines = data.results.map(
      (r, i) =>
        `${i + 1}. **${r.title}**\n   ${r.url}\n   ${r.description ?? ""}${
          r.lastUpdatedDate ? `\n   Updated: ${r.lastUpdatedDate}` : ""
        }`
    );

    return {
      content: [
        {
          type: "text" as const,
          text: `Found ${data.count} results (showing ${data.results.length}):\n\n${lines.join("\n\n")}`,
        },
      ],
    };
  }
);

// ---- Tool 2: learn_get_article -------------------------------------------

server.tool(
  "learn_get_article",
  "Get article content from Microsoft Learn by URL or path. Returns the article text in markdown-like format.",
  {
    url: z
      .string()
      .describe(
        "Full URL (e.g. https://learn.microsoft.com/en-us/dotnet/csharp/tour-of-csharp) or path (e.g. /en-us/dotnet/csharp/tour-of-csharp)"
      ),
  },
  async ({ url: rawUrl }) => {
    // Normalise to full URL
    let articleUrl = rawUrl;
    if (!articleUrl.startsWith("http")) {
      articleUrl = `https://learn.microsoft.com${articleUrl.startsWith("/") ? "" : "/"}${articleUrl}`;
    }

    // Try the JSON content API first — append ?view=api if not already present
    const jsonUrl = articleUrl.includes("?")
      ? `${articleUrl}&view=api`
      : `${articleUrl}?view=api`;

    try {
      const data = await fetchJson<{
        title?: string;
        content?: string;
        description?: string;
        metadata?: Record<string, unknown>;
      }>(jsonUrl);

      const parts: string[] = [];
      if (data.title) parts.push(`# ${data.title}\n`);
      if (data.description) parts.push(`> ${data.description}\n`);
      if (data.content) parts.push(data.content);
      else parts.push("(No body content returned by the API.)");

      return {
        content: [{ type: "text" as const, text: parts.join("\n") }],
      };
    } catch {
      // Fallback: fetch raw HTML and return a useful snippet
      const html = await fetchText(articleUrl);
      // Strip HTML tags for a rough text extraction
      const text = html
        .replace(/<script[\s\S]*?<\/script\s*>/gi, "")
        .replace(/<style[\s\S]*?<\/style\s*>/gi, "")
        .replace(/<!--[\s\S]*?-->/g, "")
        .replace(/<[^>]+>/g, " ")
        .replace(/\s{2,}/g, " ")
        .trim()
        .slice(0, 8000);

      return {
        content: [
          {
            type: "text" as const,
            text: `(Rendered from HTML — formatting approximate)\n\n${text}`,
          },
        ],
      };
    }
  }
);

// ---- Tool 3: learn_get_module --------------------------------------------

server.tool(
  "learn_get_module",
  "Get a Microsoft Learn training module with its units. Provide the module UID (e.g. 'learn.azure.intro-to-azure-fundamentals').",
  {
    moduleUid: z.string().describe("Module UID, e.g. 'learn.azure.intro-to-azure-fundamentals'"),
  },
  async ({ moduleUid }) => {
    const data = await fetchJson<CatalogResult>(
      `${CATALOG_API}?type=modules&uid=${encodeURIComponent(moduleUid)}`
    );

    const mod = data.modules?.[0];
    if (!mod) {
      return {
        content: [
          { type: "text" as const, text: `Module "${moduleUid}" not found in the catalog.` },
        ],
      };
    }

    // Resolve unit details if UIDs are present
    let unitDetails: CatalogUnit[] = [];
    if (mod.units?.length) {
      const unitParam = mod.units.map((u) => `uid=${encodeURIComponent(u)}`).join("&");
      const unitData = await fetchJson<CatalogResult>(
        `${CATALOG_API}?type=units&${unitParam}`
      );
      unitDetails = unitData.units ?? [];
    }

    const unitLines =
      unitDetails.length > 0
        ? unitDetails
            .map(
              (u, i) =>
                `  ${i + 1}. ${u.title}${u.duration_in_minutes ? ` (${u.duration_in_minutes} min)` : ""}`
            )
            .join("\n")
        : mod.units?.length
          ? mod.units.map((u, i) => `  ${i + 1}. ${u}`).join("\n")
          : "  (no units listed)";

    const text = [
      `# ${mod.title}`,
      "",
      mod.summary,
      "",
      `**URL:** ${mod.url}`,
      mod.duration_in_minutes ? `**Duration:** ${mod.duration_in_minutes} min` : null,
      mod.products?.length ? `**Products:** ${mod.products.join(", ")}` : null,
      mod.levels?.length ? `**Levels:** ${mod.levels.join(", ")}` : null,
      mod.roles?.length ? `**Roles:** ${mod.roles.join(", ")}` : null,
      "",
      "## Units",
      unitLines,
    ]
      .filter(Boolean)
      .join("\n");

    return { content: [{ type: "text" as const, text }] };
  }
);

// ---- Tool 4: learn_browse ------------------------------------------------

server.tool(
  "learn_browse",
  "Browse Microsoft Learn catalog by product or type. Returns modules and learning paths matching the filter.",
  {
    type: z
      .enum(["modules", "learningPaths"])
      .optional()
      .describe("Content type to browse (default: modules)"),
    product: z
      .string()
      .optional()
      .describe("Filter by product (e.g. 'azure', 'dotnet', 'power-platform')"),
    role: z
      .string()
      .optional()
      .describe("Filter by role (e.g. 'developer', 'administrator')"),
    level: z
      .string()
      .optional()
      .describe("Filter by level (e.g. 'beginner', 'intermediate', 'advanced')"),
    top: z
      .number()
      .int()
      .min(1)
      .max(50)
      .optional()
      .describe("Max results (default 10, max 50)"),
  },
  async ({ type, product, role, level, top }) => {
    const contentType = type ?? "modules";
    const params = new URLSearchParams();
    params.set("type", contentType);
    if (product) params.set("product", product);
    if (role) params.set("role", role);
    if (level) params.set("level", level);

    const data = await fetchJson<CatalogResult>(`${CATALOG_API}?${params.toString()}`);

    const items =
      contentType === "learningPaths" ? data.learningPaths ?? [] : data.modules ?? [];

    const limited = items.slice(0, top ?? 10);

    if (limited.length === 0) {
      return {
        content: [{ type: "text" as const, text: "No items found for the given filters." }],
      };
    }

    const lines = limited.map(
      (item, i) =>
        `${i + 1}. **${item.title}**\n   UID: ${item.uid}\n   ${item.url}\n   ${item.summary?.slice(0, 200) ?? ""}`
    );

    return {
      content: [
        {
          type: "text" as const,
          text: `Showing ${limited.length} of ${items.length} ${contentType}:\n\n${lines.join("\n\n")}`,
        },
      ],
    };
  }
);

// ---- Tool 5: learn_get_code_samples --------------------------------------

server.tool(
  "learn_get_code_samples",
  "Extract code samples from a Microsoft Learn documentation page. Returns fenced code blocks found in the article.",
  {
    url: z
      .string()
      .describe(
        "Full URL or path of the docs page to extract code samples from"
      ),
    language: z
      .string()
      .optional()
      .describe("Filter code blocks by language (e.g. 'csharp', 'python', 'javascript')"),
  },
  async ({ url: rawUrl, language }) => {
    let articleUrl = rawUrl;
    if (!articleUrl.startsWith("http")) {
      articleUrl = `https://learn.microsoft.com${articleUrl.startsWith("/") ? "" : "/"}${articleUrl}`;
    }

    const html = await fetchText(articleUrl);

    // Extract <code> and <pre> blocks
    const codeBlocks: Array<{ lang: string; code: string }> = [];

    // Pattern 1: <pre><code class="lang-xxx">...</code></pre>
    const preCodeRegex = /<pre[^>]*>\s*<code[^>]*class="[^"]*lang-(\w+)[^"]*"[^>]*>([\s\S]*?)<\/code>\s*<\/pre>/gi;
    let match: RegExpExecArray | null;
    while ((match = preCodeRegex.exec(html)) !== null) {
      codeBlocks.push({
        lang: match[1],
        code: decodeHtmlEntities(match[2]),
      });
    }

    // Pattern 2: <code class="lang-xxx">...</code> (standalone)
    const codeRegex = /<code[^>]*class="[^"]*lang-(\w+)[^"]*"[^>]*>([\s\S]*?)<\/code>/gi;
    while ((match = codeRegex.exec(html)) !== null) {
      const code = decodeHtmlEntities(match[2]);
      // Avoid duplicates from pattern 1
      if (!codeBlocks.some((b) => b.code === code)) {
        codeBlocks.push({ lang: match[1], code });
      }
    }

    // Pattern 3: data-lang attribute
    const dataLangRegex = /<code[^>]*data-lang="(\w+)"[^>]*>([\s\S]*?)<\/code>/gi;
    while ((match = dataLangRegex.exec(html)) !== null) {
      const code = decodeHtmlEntities(match[2]);
      if (!codeBlocks.some((b) => b.code === code)) {
        codeBlocks.push({ lang: match[1], code });
      }
    }

    let filtered = codeBlocks;
    if (language) {
      const lang = language.toLowerCase();
      filtered = codeBlocks.filter(
        (b) => b.lang.toLowerCase() === lang || b.lang.toLowerCase().startsWith(lang)
      );
    }

    if (filtered.length === 0) {
      return {
        content: [
          {
            type: "text" as const,
            text: language
              ? `No code samples found for language "${language}" on that page.`
              : "No code samples found on that page.",
          },
        ],
      };
    }

    const formatted = filtered
      .map((b, i) => `### Sample ${i + 1} (${b.lang})\n\`\`\`${b.lang}\n${b.code.trim()}\n\`\`\``)
      .join("\n\n");

    return {
      content: [
        {
          type: "text" as const,
          text: `Found ${filtered.length} code sample(s):\n\n${formatted}`,
        },
      ],
    };
  }
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function decodeHtmlEntities(text: string): string {
  return text
    .replace(/<script[\s\S]*?<\/script\s*>/gi, "")
    .replace(/<style[\s\S]*?<\/style\s*>/gi, "")
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<[^>]+>/g, "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&#x2F;/g, "/")
    .replace(/&amp;/g, "&");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("learn-mcp-server running on stdio");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
