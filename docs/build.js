#!/usr/bin/env node
/**
 * Squad Docs — Static Site Generator
 *
 * Reads markdown files from docs/ and produces a navigable HTML site.
 * Dependencies (installed by the CI workflow):
 *   - markdown-it
 *   - markdown-it-anchor
 *
 * Usage:
 *   node docs/build.js --out _site --base /squad
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);
function flag(name, fallback) {
  const idx = args.indexOf('--' + name);
  return idx !== -1 && args[idx + 1] ? args[idx + 1] : fallback;
}

const OUT_DIR = path.resolve(flag('out', '_site'));
const BASE = flag('base', '/').replace(/\/+$/, '');  // no trailing slash
const DOCS_DIR = path.resolve(__dirname);             // docs/ itself

// ---------------------------------------------------------------------------
// Markdown renderer
// ---------------------------------------------------------------------------
const MarkdownIt = require('markdown-it');
const markdownItAnchor = require('markdown-it-anchor');

const md = new MarkdownIt({
  html: true,
  linkify: true,
  typographer: true,
});
md.use(markdownItAnchor, { permalink: false });

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Recursively collect markdown files under `dir`, returning paths relative to DOCS_DIR. */
function collectMarkdown(dir, rel) {
  rel = rel || '';
  let files = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    const relPath = path.join(rel, entry.name);
    if (entry.isDirectory()) {
      // skip output dirs and hidden dirs
      if (entry.name.startsWith('_') || entry.name.startsWith('.')) continue;
      files = files.concat(collectMarkdown(full, relPath));
    } else if (entry.name.endsWith('.md')) {
      files.push(relPath);
    }
  }
  return files;
}

/** Derive a human-readable title from a markdown file's first heading or filename. */
function extractTitle(mdContent, relPath) {
  const match = mdContent.match(/^#\s+(.+)$/m);
  if (match) return match[1].replace(/[*_`]/g, '').trim();
  return path.basename(relPath, '.md')
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

/** Extract the first bold metadata line (Owner, Status, Issue, Date) if present. */
function extractMeta(mdContent) {
  const meta = {};
  const patterns = [
    { key: 'issue',  re: /\*\*Issue[:\s]*\*\*\s*#?(\d+)/i },
    { key: 'owner',  re: /\*\*(?:Owner|Created by|Author)[:\s]*\*\*\s*(.+)/i },
    { key: 'status', re: /\*\*Status[:\s]*\*\*\s*(.+)/i },
    { key: 'date',   re: /\*\*(?:Date|Last Updated)[:\s]*\*\*\s*(.+)/i },
  ];
  for (const { key, re } of patterns) {
    const m = mdContent.match(re);
    if (m) meta[key] = m[1].trim();
  }
  return meta;
}

/** Categorise a doc based on its relative path and filename. */
function categorise(relPath) {
  const lower = relPath.toLowerCase();
  if (lower.startsWith('compliance')) return 'Compliance';
  if (lower.startsWith('fedramp'))    return 'FedRAMP';
  if (lower.includes('research'))     return 'Research';
  if (lower.includes('security') || lower.includes('waf') || lower.includes('dri'))
    return 'Security & Operations';
  if (lower.includes('voice') || lower.includes('podcast') || lower.includes('tts') || lower.includes('f5'))
    return 'Voice & Podcasting';
  if (lower.includes('setup') || lower.includes('guide') || lower.includes('devbox') || lower.includes('email'))
    return 'Setup Guides';
  return 'General';
}

/** Convert a relative .md path to its output .html path. */
function htmlPath(relMd) {
  return relMd.replace(/\.md$/i, '.html');
}

/** Ensure parent directories exist. */
function mkdirp(filePath) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

// ---------------------------------------------------------------------------
// CSS
// ---------------------------------------------------------------------------
const CSS = `
:root {
  --brand: #1a73e8;
  --brand-dark: #0d47a1;
  --bg: #f8f9fa;
  --card: #ffffff;
  --text: #202124;
  --muted: #5f6368;
  --border: #dadce0;
  --code-bg: #f1f3f4;
  --sidebar-w: 280px;
}
*, *::before, *::after { box-sizing: border-box; }
html { font-size: 16px; scroll-behavior: smooth; }
body {
  margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, sans-serif;
  color: var(--text); background: var(--bg); line-height: 1.6;
}

/* --- Header --- */
.site-header {
  background: var(--brand); color: #fff; padding: 0 1.5rem;
  display: flex; align-items: center; height: 56px; position: sticky; top: 0; z-index: 100;
  box-shadow: 0 2px 4px rgba(0,0,0,.12);
}
.site-header a { color: #fff; text-decoration: none; }
.site-header .logo { font-size: 1.25rem; font-weight: 700; display: flex; align-items: center; gap: .5rem; }
.site-header .logo svg { width: 28px; height: 28px; }
.site-header nav { margin-left: auto; display: flex; gap: 1rem; font-size: .9rem; }
.site-header nav a:hover { text-decoration: underline; }

/* --- Layout --- */
.layout { display: flex; min-height: calc(100vh - 56px); }

/* --- Sidebar --- */
.sidebar {
  width: var(--sidebar-w); background: var(--card); border-right: 1px solid var(--border);
  padding: 1.25rem 0; overflow-y: auto; position: sticky; top: 56px;
  height: calc(100vh - 56px); flex-shrink: 0;
}
.sidebar h3 {
  font-size: .7rem; text-transform: uppercase; letter-spacing: .08em;
  color: var(--muted); padding: .5rem 1.25rem; margin: .75rem 0 .25rem;
}
.sidebar a {
  display: block; padding: .35rem 1.25rem; color: var(--text); text-decoration: none;
  font-size: .85rem; border-left: 3px solid transparent; transition: background .15s;
}
.sidebar a:hover { background: var(--bg); }
.sidebar a.active { border-left-color: var(--brand); color: var(--brand); font-weight: 600; background: #e8f0fe; }

/* --- Main content --- */
.content { flex: 1; max-width: 900px; padding: 2rem 2.5rem; }
.content h1 { font-size: 2rem; margin-top: 0; border-bottom: 2px solid var(--brand); padding-bottom: .4rem; }
.content h2 { margin-top: 2rem; color: var(--brand-dark); }
.content h3 { margin-top: 1.5rem; }
.content a { color: var(--brand); }
.content img { max-width: 100%; border-radius: 4px; }
.content table { border-collapse: collapse; width: 100%; margin: 1rem 0; }
.content th, .content td { border: 1px solid var(--border); padding: .5rem .75rem; text-align: left; }
.content th { background: var(--code-bg); font-weight: 600; }
.content tr:nth-child(even) { background: var(--bg); }
.content code { background: var(--code-bg); padding: .15em .35em; border-radius: 3px; font-size: .9em; }
.content pre { background: #263238; color: #eeffff; padding: 1rem 1.25rem; border-radius: 6px; overflow-x: auto; }
.content pre code { background: none; color: inherit; padding: 0; }
.content blockquote {
  border-left: 4px solid var(--brand); margin: 1rem 0; padding: .5rem 1rem;
  background: #e8f0fe; color: var(--brand-dark);
}
.content hr { border: none; border-top: 1px solid var(--border); margin: 2rem 0; }

/* Meta badge row */
.meta { display: flex; flex-wrap: wrap; gap: .5rem; margin-bottom: 1rem; }
.meta span {
  background: var(--code-bg); padding: .2rem .6rem; border-radius: 12px;
  font-size: .78rem; color: var(--muted);
}

/* --- Index page cards --- */
.card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; margin-top: 1rem; }
.card {
  background: var(--card); border: 1px solid var(--border); border-radius: 8px;
  padding: 1rem 1.25rem; text-decoration: none; color: var(--text);
  transition: box-shadow .2s, transform .15s;
}
.card:hover { box-shadow: 0 4px 12px rgba(0,0,0,.1); transform: translateY(-2px); }
.card h3 { margin: 0 0 .4rem; font-size: 1rem; color: var(--brand); }
.card .cat { font-size: .72rem; text-transform: uppercase; color: var(--muted); letter-spacing: .06em; }

/* --- Responsive --- */
@media (max-width: 860px) {
  .sidebar { display: none; }
  .content { padding: 1.5rem 1rem; }
}

/* --- Footer --- */
.site-footer {
  text-align: center; padding: 1.5rem; color: var(--muted); font-size: .8rem;
  border-top: 1px solid var(--border); background: var(--card);
}
`;

// ---------------------------------------------------------------------------
// HTML template
// ---------------------------------------------------------------------------
function htmlPage({ title, body, sidebar, activePath }) {
  const activeNorm = (activePath || '').replace(/\\/g, '/');
  const sidebarHtml = sidebar.map(g => {
    const links = g.items.map(i => {
      const href = BASE + '/' + i.href.replace(/\\/g, '/');
      const cls = i.href.replace(/\\/g, '/') === activeNorm ? ' class="active"' : '';
      return `<a href="${href}"${cls}>${escapeHtml(i.title)}</a>`;
    }).join('\n');
    return `<h3>${escapeHtml(g.category)}</h3>\n${links}`;
  }).join('\n');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)} — Squad Docs</title>
<style>${CSS}</style>
</head>
<body>
<header class="site-header">
  <a class="logo" href="${BASE}/">
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
    Squad Docs
  </a>
  <nav>
    <a href="${BASE}/">Home</a>
    <a href="https://github.com/nicktamir/tamresearch1">GitHub</a>
  </nav>
</header>
<div class="layout">
  <aside class="sidebar">${sidebarHtml}</aside>
  <main class="content">${body}</main>
</div>
<footer class="site-footer">
  Built with Squad Docs &middot; Generated ${new Date().toISOString().slice(0, 10)}
</footer>
</body>
</html>`;
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ---------------------------------------------------------------------------
// Build
// ---------------------------------------------------------------------------
function build() {
  console.log(`[build] docs dir : ${DOCS_DIR}`);
  console.log(`[build] output   : ${OUT_DIR}`);
  console.log(`[build] base path: ${BASE || '/'}`);

  // Collect all markdown files
  const mdFiles = collectMarkdown(DOCS_DIR, '').sort();
  console.log(`[build] found ${mdFiles.length} markdown files`);

  if (mdFiles.length === 0) {
    console.error('[build] No markdown files found. Nothing to build.');
    process.exit(1);
  }

  // Parse every file
  const pages = mdFiles.map(relPath => {
    const raw = fs.readFileSync(path.join(DOCS_DIR, relPath), 'utf8');
    const title = extractTitle(raw, relPath);
    const meta = extractMeta(raw);
    const category = categorise(relPath);
    const html = md.render(raw);
    const href = htmlPath(relPath);
    return { relPath, title, meta, category, html, href };
  });

  // Build sidebar groups
  const catMap = new Map();
  for (const p of pages) {
    if (!catMap.has(p.category)) catMap.set(p.category, []);
    catMap.get(p.category).push({ title: p.title, href: p.href });
  }
  const sidebar = Array.from(catMap.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([category, items]) => ({ category, items }));

  // Ensure output dir
  if (fs.existsSync(OUT_DIR)) fs.rmSync(OUT_DIR, { recursive: true });
  fs.mkdirSync(OUT_DIR, { recursive: true });

  // Render individual pages
  for (const p of pages) {
    const metaBadges = Object.entries(p.meta)
      .map(([k, v]) => `<span><strong>${k}:</strong> ${escapeHtml(v)}</span>`)
      .join('');
    const metaRow = metaBadges ? `<div class="meta">${metaBadges}</div>` : '';
    const body = metaRow + p.html;
    const out = path.join(OUT_DIR, p.href);
    mkdirp(out);
    fs.writeFileSync(out, htmlPage({ title: p.title, body, sidebar, activePath: p.href }));
  }
  console.log(`[build] wrote ${pages.length} HTML pages`);

  // Render index page
  const catSections = Array.from(catMap.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([category, items]) => {
      const cards = items.map(i => {
        const href = BASE + '/' + i.href.replace(/\\/g, '/');
        return `<a class="card" href="${href}"><span class="cat">${escapeHtml(category)}</span><h3>${escapeHtml(i.title)}</h3></a>`;
      }).join('\n');
      return `<h2>${escapeHtml(category)}</h2>\n<div class="card-grid">${cards}</div>`;
    }).join('\n');

  const indexBody = `
<h1>Squad Documentation</h1>
<p>Welcome to the Squad team documentation site. Browse the categories below or use the sidebar to navigate.</p>
<p style="color:var(--muted);font-size:.9rem;">${pages.length} documents across ${catMap.size} categories.</p>
${catSections}`;

  fs.writeFileSync(
    path.join(OUT_DIR, 'index.html'),
    htmlPage({ title: 'Home', body: indexBody, sidebar, activePath: null })
  );
  console.log(`[build] wrote index.html`);
  console.log('[build] done ✓');
}

build();
