#!/usr/bin/env node

/**
 * Daily arXiv Research Scanner
 * Fetches recent papers (last 2 days) from arXiv in categories:
 *   cs.AI, cs.LG, cs.MA, cs.SE, cs.NE
 *
 * Filters by relevance to our work (agents, MCP, .NET, K8s, code LLMs, etc.),
 * deduplicates against .squad/monitoring/arxiv-state.json, creates a GitHub
 * issue titled "Research Digest: YYYY-MM-DD", and posts a Teams notification.
 *
 * Implements issue #1308.
 */

import http from 'http';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

// ─── Paths ────────────────────────────────────────────────────────────────────

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);
const stateDir   = path.join(__dirname, '..', '.squad', 'monitoring');
const stateFile  = path.join(stateDir, 'arxiv-state.json');

// ─── arXiv API config ─────────────────────────────────────────────────────────

const ARXIV_API_URL =
  'http://export.arxiv.org/api/query' +
  '?search_query=cat:cs.AI+OR+cat:cs.LG+OR+cat:cs.MA+OR+cat:cs.SE+OR+cat:cs.NE' +
  '&start=0&max_results=50&sortBy=submittedDate&sortOrder=descending';

const ARXIV_TIMEOUT_MS = 20000;

// ─── Relevance keywords ───────────────────────────────────────────────────────

// HIGH: always include when found in title or abstract
const HIGH_KEYWORDS = [
  'agent', 'multi-agent', 'multiagent', 'agentic',
  'squad',
  'kubernetes', 'k8s',
  'code llm', 'code generation',
  'copilot',
  'mcp', 'model context protocol',
  '.net', 'dotnet',
  'aspire',
];

// MEDIUM: include if ≥2 matches in title+abstract
const MEDIUM_KEYWORDS = [
  'ai', 'llm', 'language model', 'benchmark',
  'tool use', 'tool-use',
  'planning', 'reasoning', 'workflow',
];

// ─── Relevance scoring ────────────────────────────────────────────────────────

function scorePaper(paper) {
  const text = `${paper.title} ${paper.abstract}`.toLowerCase();

  const highMatches = HIGH_KEYWORDS.filter(kw => text.includes(kw));
  if (highMatches.length > 0) return { relevance: 'HIGH', matched: highMatches };

  const mediumMatches = MEDIUM_KEYWORDS.filter(kw => text.includes(kw));
  if (mediumMatches.length >= 2) return { relevance: 'MEDIUM', matched: mediumMatches };

  return { relevance: 'LOW', matched: [] };
}

// ─── arXiv Atom XML parsing ───────────────────────────────────────────────────

/**
 * Extract the text content between open and close tags (first match).
 * Handles optional CDATA and strips surrounding whitespace.
 */
function extractTag(block, tag) {
  const re = new RegExp(`<${tag}[^>]*>(?:<\\!\\[CDATA\\[)?([\\s\\S]*?)(?:\\]\\]>)?<\\/${tag}>`, 'i');
  const m = block.match(re);
  return m ? m[1].trim() : '';
}

/**
 * Extract the value of an attribute from a tag.
 * e.g. extractAttr('<category term="cs.AI"/>', 'category', 'term') → "cs.AI"
 */
function extractAttr(block, tag, attr) {
  const re = new RegExp(`<${tag}[^>]+${attr}=["']([^"']+)["']`, 'gi');
  const results = [];
  let m;
  while ((m = re.exec(block)) !== null) {
    results.push(m[1]);
  }
  return results;
}

/**
 * Parse arXiv Atom feed XML into an array of paper objects.
 * @param {string} xml - Raw Atom XML from arXiv API
 * @returns {Array<{id, title, abstract, firstAuthor, categories, submitted}>}
 */
function parseAtomFeed(xml) {
  const papers = [];
  const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
  let match;

  while ((match = entryRegex.exec(xml)) !== null) {
    const block = match[1];

    // id is like http://arxiv.org/abs/2303.12345v1
    const rawId = extractTag(block, 'id');
    if (!rawId) continue;

    // Normalise to canonical abs URL (strip version suffix)
    const arxivId = rawId.replace(/v\d+$/, '').trim();

    const title    = extractTag(block, 'title').replace(/\s+/g, ' ');
    const abstract = extractTag(block, 'summary').replace(/\s+/g, ' ');
    const submitted = extractTag(block, 'published');

    // First author
    const authorBlock = block.match(/<author>([\s\S]*?)<\/author>/);
    const firstAuthor = authorBlock ? extractTag(authorBlock[1], 'name') : 'Unknown';

    // All categories
    const categories = extractAttr(block, 'category', 'term');

    if (title && arxivId) {
      papers.push({ id: arxivId, title, abstract, firstAuthor, categories, submitted });
    }
  }

  return papers;
}

// ─── Date filtering ───────────────────────────────────────────────────────────

/**
 * Returns true if the paper was submitted within the last `days` days.
 */
function isRecent(paper, days = 2) {
  if (!paper.submitted) return true; // include if unknown
  try {
    const d = new Date(paper.submitted);
    const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    return d >= cutoff;
  } catch (_) {
    return true;
  }
}

// ─── State management ─────────────────────────────────────────────────────────

function ensureStateDir() {
  if (!fs.existsSync(stateDir)) {
    fs.mkdirSync(stateDir, { recursive: true });
  }
}

function loadState() {
  try {
    if (fs.existsSync(stateFile)) {
      return JSON.parse(fs.readFileSync(stateFile, 'utf8'));
    }
  } catch (e) {
    console.error(`Warning: Could not load arxiv state file: ${e.message}`);
  }
  return { lastScanDate: null, reportedIds: {} };
}

function saveState(state) {
  try {
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2), 'utf8');
  } catch (e) {
    console.error(`Warning: Could not save arxiv state file: ${e.message}`);
  }
}

// ─── Date helper ─────────────────────────────────────────────────────────────

function getTodayDate() {
  return new Date().toISOString().split('T')[0];
}

// ─── HTTP fetch ───────────────────────────────────────────────────────────────

/**
 * Fetch a URL (http or https) and return the response body as a string.
 * Rejects on timeout, network error, or non-2xx status.
 */
function fetchUrl(url, timeoutMs = ARXIV_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    let req;
    const timer = setTimeout(() => {
      try { req && req.destroy(); } catch (_) {}
      reject(new Error(`Request timed out after ${timeoutMs}ms: ${url}`));
    }, timeoutMs);

    const lib = url.startsWith('https') ? https : http;

    req = lib.get(url, { headers: { 'User-Agent': 'ArxivScanner/1.0 (research-digest)' } }, (res) => {
      // Follow single redirect
      if ((res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 303) && res.headers.location) {
        clearTimeout(timer);
        resolve(fetchUrl(res.headers.location, timeoutMs - 1000));
        return;
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        clearTimeout(timer);
        reject(new Error(`HTTP ${res.statusCode} from ${url}`));
        return;
      }

      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => { clearTimeout(timer); resolve(data); });
      res.on('error', (err) => { clearTimeout(timer); reject(err); });
    });

    req.on('error', (err) => { clearTimeout(timer); reject(err); });
  });
}

// ─── arXiv fetch + parse ──────────────────────────────────────────────────────

async function fetchArxivPapers() {
  console.error('Fetching arXiv papers...');
  try {
    const xml = await fetchUrl(ARXIV_API_URL);
    const papers = parseAtomFeed(xml);
    console.error(`Parsed ${papers.length} entries from arXiv feed`);
    return papers;
  } catch (e) {
    console.error(`Error fetching arXiv feed: ${e.message}`);
    return [];
  }
}

// ─── GitHub issue helpers ─────────────────────────────────────────────────────

/**
 * Check if a Research Digest issue already exists for the given date.
 * Returns the issue number, or null if none found.
 */
function findExistingDigestIssue(date) {
  try {
    const output = execFileSync(
      'gh',
      ['issue', 'list', '--label', 'squad,research', '--search', `Research Digest: ${date}`, '--json', 'number,title'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const issues = JSON.parse(output || '[]');
    const exact = issues.find(i => i.title && i.title.includes(`Research Digest: ${date}`));
    return exact ? exact.number : null;
  } catch (e) {
    console.error(`Warning: Could not check for existing digest issue: ${e.message}`);
    return null;
  }
}

/**
 * Create a GitHub issue. Returns the issue URL or null on failure.
 */
function createGitHubIssue(title, body) {
  try {
    const output = execFileSync(
      'gh',
      ['issue', 'create', '--title', title, '--body', body, '--label', 'squad,squad:seven,research'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    console.error(`Created GitHub issue: ${output}`);
    return output;
  } catch (_labelErr) {
    // Retry without labels if they don't exist
    try {
      const output = execFileSync(
        'gh',
        ['issue', 'create', '--title', title, '--body', body],
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
      ).trim();
      console.error(`Created GitHub issue (no labels): ${output}`);
      return output;
    } catch (e) {
      console.error(`Warning: Could not create GitHub issue: ${e.message}`);
      return null;
    }
  }
}

/**
 * Add a comment to an existing GitHub issue.
 */
function addIssueComment(issueNumber, body) {
  try {
    execFileSync(
      'gh',
      ['issue', 'comment', String(issueNumber), '--body', body],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    );
    console.error(`Added comment to issue #${issueNumber}`);
  } catch (e) {
    console.error(`Warning: Could not add comment to issue #${issueNumber}: ${e.message}`);
  }
}

// ─── Digest formatting ────────────────────────────────────────────────────────

/**
 * Truncate abstract to ~300 chars, ending at a sentence boundary.
 */
function truncateAbstract(text, maxLen = 300) {
  if (!text || text.length <= maxLen) return text || '';
  const truncated = text.slice(0, maxLen);
  const lastPeriod = truncated.lastIndexOf('.');
  return lastPeriod > 100 ? truncated.slice(0, lastPeriod + 1) : truncated + '…';
}

/**
 * Format the primary category from a categories array.
 * Returns just the first one, e.g. "cs.AI".
 */
function primaryCategory(categories) {
  return (categories && categories.length > 0) ? categories[0] : 'cs.?';
}

/**
 * Build the GitHub issue body for the research digest.
 */
function formatDigestBody(date, papers) {
  const highPapers   = papers.filter(p => p.relevance === 'HIGH');
  const mediumPapers = papers.filter(p => p.relevance === 'MEDIUM');

  let body = `# 📚 Research Digest — ${date}\n\n`;
  body += `> _Daily arXiv scan across cs.AI, cs.LG, cs.MA, cs.SE, cs.NE — `;
  body += `${papers.length} relevant paper${papers.length !== 1 ? 's' : ''} found `;
  body += `(${highPapers.length} HIGH, ${mediumPapers.length} MEDIUM)._\n\n`;

  // ── Full table ─────────────────────────────────────────────────────────────
  body += `## All Relevant Papers\n\n`;
  body += `| Title | First Author | Category | Relevance | Link |\n`;
  body += `|-------|-------------|----------|-----------|------|\n`;
  for (const p of papers) {
    const cat    = primaryCategory(p.categories);
    const relBadge = p.relevance === 'HIGH' ? '🔴 HIGH' : '🟡 MED';
    const shortTitle = p.title.length > 80 ? p.title.slice(0, 77) + '…' : p.title;
    body += `| ${shortTitle} | ${p.firstAuthor} | ${cat} | ${relBadge} | [abs](${p.id}) |\n`;
  }
  body += '\n';

  // ── Summaries for top HIGH-relevance papers ────────────────────────────────
  const topHigh = highPapers.slice(0, 3);
  if (topHigh.length > 0) {
    body += `---\n\n## 🔴 Top HIGH-Relevance Papers\n\n`;
    for (const p of topHigh) {
      body += `### ${p.title}\n\n`;
      body += `- **Authors:** ${p.firstAuthor} et al.\n`;
      body += `- **Categories:** ${p.categories.join(', ')}\n`;
      body += `- **Submitted:** ${p.submitted ? p.submitted.split('T')[0] : 'unknown'}\n`;
      body += `- **Matched keywords:** ${p.matched.slice(0, 5).join(', ')}\n`;
      body += `- **Link:** ${p.id}\n\n`;
      if (p.abstract) {
        body += `> ${truncateAbstract(p.abstract)}\n\n`;
      }
    }
  }

  body += `---\n\n_Generated by [arxiv-scanner.js](../scripts/arxiv-scanner.js) · issue #1308_\n`;
  return body;
}

// ─── Teams notification ───────────────────────────────────────────────────────

async function postToTeamsWebhook(date, papers, issueUrl) {
  const home = process.env.USERPROFILE || process.env.HOME || '';
  const webhookFile = path.join(home, '.squad', 'teams-webhook.url');

  if (!fs.existsSync(webhookFile)) {
    console.error(`Teams webhook file not found at ${webhookFile}, skipping Teams post`);
    return;
  }

  const webhookUrl = fs.readFileSync(webhookFile, 'utf8').trim();
  if (!webhookUrl) {
    console.error('Teams webhook URL is empty, skipping Teams post');
    return;
  }

  const highPapers = papers.filter(p => p.relevance === 'HIGH').slice(0, 3);
  const paperLines = highPapers.length > 0
    ? highPapers.map(p => `• [${p.title.slice(0, 80)}](${p.id})`).join('\n')
    : '_No HIGH-relevance papers today_';

  const issueRef = issueUrl ? `\n🔗 [Full digest](${issueUrl})` : '';

  const messageText = [
    `CHANNEL: research`,
    `**📚 Daily Research Digest: ${date}**`,
    `${papers.length} relevant papers (${papers.filter(p=>p.relevance==='HIGH').length} HIGH, ${papers.filter(p=>p.relevance==='MEDIUM').length} MEDIUM)`,
    '',
    paperLines,
    issueRef,
  ].join('\n');

  const payload = JSON.stringify({
    type: 'message',
    attachments: [{
      contentType: 'application/vnd.microsoft.card.adaptive',
      content: {
        '$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
        type: 'AdaptiveCard',
        version: '1.4',
        body: [{
          type: 'TextBlock',
          text: messageText,
          wrap: true,
        }],
      },
    }],
  });

  return new Promise((resolve) => {
    try {
      const parsedUrl = new URL(webhookUrl);
      const req = https.request(parsedUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      }, (res) => {
        let data = '';
        res.on('data', chunk => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.error(`Posted research digest to Teams webhook (status: ${res.statusCode})`);
          } else {
            console.error(`Teams webhook returned ${res.statusCode}: ${data.slice(0, 200)}`);
          }
          resolve();
        });
      });

      req.on('error', (err) => {
        console.error(`Failed to post to Teams webhook: ${err.message}`);
        resolve();
      });

      req.write(payload);
      req.end();
    } catch (err) {
      console.error(`Failed to post to Teams webhook: ${err.message}`);
      resolve();
    }
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  try {
    ensureStateDir();
    const state = loadState();
    const todayDate = getTodayDate();

    console.error(`Starting arXiv scan for ${todayDate}...`);

    // 1. Fetch papers from arXiv
    const allPapers = await fetchArxivPapers();

    // 2. Filter to recent (last 2 days)
    const recentPapers = allPapers.filter(p => isRecent(p, 2));
    console.error(`${recentPapers.length} papers submitted in the last 2 days`);

    // 3. Score relevance and filter out LOW
    const scoredPapers = recentPapers
      .map(p => ({ ...p, ...scorePaper(p) }))
      .filter(p => p.relevance !== 'LOW');
    console.error(`${scoredPapers.length} papers pass relevance filter (HIGH+MEDIUM)`);

    // 4. Deduplicate against state
    const alreadyReported = state.reportedIds || {};
    const newPapers = scoredPapers.filter(p => !alreadyReported[p.id]);
    console.error(`${newPapers.length} new papers (not yet reported)`);

    if (newPapers.length === 0) {
      console.error('No new relevant papers to report. Exiting.');
      process.exit(0);
    }

    // Sort: HIGH first, then by submitted date (newest first)
    newPapers.sort((a, b) => {
      const tierA = a.relevance === 'HIGH' ? 0 : 1;
      const tierB = b.relevance === 'HIGH' ? 0 : 1;
      if (tierA !== tierB) return tierA - tierB;
      return (b.submitted || '').localeCompare(a.submitted || '');
    });

    // Print summary to stdout
    console.log(`\nArXiv Research Digest — ${todayDate}`);
    console.log(`${'='.repeat(60)}`);
    console.log(`Found ${newPapers.length} new relevant papers:`);
    newPapers.forEach((p, i) => {
      console.log(`  ${i + 1}. [${p.relevance}] ${p.title}`);
      console.log(`     ${p.id}`);
    });
    console.log('');

    // 5. Create GitHub issue (if ≥3 new papers) or add comment to existing
    let issueUrl = null;

    if (newPapers.length >= 3) {
      const issueTitle = `Research Digest: ${todayDate}`;
      const issueBody  = formatDigestBody(todayDate, newPapers);

      const existingIssueNumber = findExistingDigestIssue(todayDate);

      if (existingIssueNumber) {
        console.error(`Issue already exists for today (#${existingIssueNumber}), adding comment...`);
        addIssueComment(existingIssueNumber, issueBody);
        // Try to get the issue URL
        try {
          const urlOut = execFileSync(
            'gh', ['issue', 'view', String(existingIssueNumber), '--json', 'url', '--jq', '.url'],
            { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 15000 }
          ).trim();
          issueUrl = urlOut || null;
        } catch (_) {}
      } else {
        issueUrl = createGitHubIssue(issueTitle, issueBody);
      }
    } else {
      console.error(`Only ${newPapers.length} new paper(s) — need ≥3 to create GitHub issue. Skipping issue creation.`);
    }

    // 6. Post Teams notification
    await postToTeamsWebhook(todayDate, newPapers, issueUrl);

    // 7. Update state with newly reported IDs
    const updatedIds = { ...alreadyReported };
    for (const p of newPapers) {
      updatedIds[p.id] = todayDate;
    }
    state.reportedIds   = updatedIds;
    state.lastScanDate  = todayDate;
    state.lastScanCount = newPapers.length;
    saveState(state);

    console.error(`arXiv scan completed. ${newPapers.length} paper(s) processed.`);
  } catch (err) {
    console.error('Fatal error during arXiv scan:', err);
    process.exit(1);
  }
}

main();
