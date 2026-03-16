#!/usr/bin/env node
/**
 * Upstream Monitor — Track parent project for updates.
 *
 * Checks a configurable upstream GitHub repo (default: bradygaster/squad)
 * for new releases, commits, discussions, and issues using the `gh` CLI.
 * Maintains state in .squad/upstream-state.json to avoid duplicates.
 *
 * Usage:
 *   node scripts/upstream-monitor.js            # normal run
 *   node scripts/upstream-monitor.js --reset     # clear state and re-check
 *   node scripts/upstream-monitor.js --dry-run   # check without updating state
 *
 * Exit codes:
 *   0 — success (output present = new items found, empty = nothing new)
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

// ── paths ────────────────────────────────────────────────────────────────────
const ROOT = path.resolve(__dirname, "..");
const CONFIG_PATH = path.join(ROOT, ".squad", "upstream-config.json");
const STATE_PATH = path.join(ROOT, ".squad", "upstream-state.json");

// ── helpers ──────────────────────────────────────────────────────────────────

function loadJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf-8"));
  } catch {
    return null;
  }
}

function saveJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf-8");
}

function gh(args) {
  try {
    const result = execSync(`gh ${args}`, {
      encoding: "utf-8",
      timeout: 30_000,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return result.trim();
  } catch (err) {
    const stderr = err.stderr ? err.stderr.toString().trim() : "";
    // Some gh commands return exit 1 when there are no results (e.g. no discussions)
    if (stderr.includes("Could not resolve") || stderr.includes("not found")) {
      return "";
    }
    // For GraphQL "no discussions" type errors, return empty
    if (err.stdout) return err.stdout.toString().trim();
    return "";
  }
}

function ghJson(args) {
  const raw = gh(args);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString();
}

// cap arrays so the state file doesn't grow unbounded
function capArray(arr, max = 200) {
  return arr.slice(-max);
}

// ── checks ───────────────────────────────────────────────────────────────────

function checkReleases(repo, state) {
  const items = ghJson(
    `release list --repo ${repo} --limit 10 --json tagName,name,publishedAt,url`
  );
  if (!items || !Array.isArray(items) || items.length === 0) return [];

  const seen = new Set(state.seenReleaseIds || []);
  const newReleases = items.filter((r) => !seen.has(r.tagName));
  return newReleases.map((r) => ({
    type: "release",
    id: r.tagName,
    title: r.name || r.tagName,
    date: r.publishedAt,
    url: r.url,
  }));
}

function checkCommits(repo, state, config) {
  const since = daysAgo(config.commitLookbackDays || 7);
  const limit = config.maxCommits || 20;
  const items = ghJson(
    `api repos/${repo}/commits --method GET -f since="${since}" -f per_page=${limit} --jq '.[] | {sha: .sha, message: .commit.message, date: .commit.committer.date, url: .html_url, author: .commit.author.name}'`
  );

  // gh api with --jq on an array returns newline-delimited JSON objects
  let commits = [];
  if (items && typeof items === "object" && !Array.isArray(items)) {
    commits = [items];
  } else if (Array.isArray(items)) {
    commits = items;
  } else if (typeof items === "string") {
    // try parsing newline-delimited JSON
    return [];
  }

  // If ghJson failed, try raw parsing
  if (commits.length === 0) {
    const raw = gh(
      `api repos/${repo}/commits --method GET -f since="${since}" -f per_page=${limit}`
    );
    if (raw) {
      try {
        const parsed = JSON.parse(raw);
        if (Array.isArray(parsed)) {
          commits = parsed.map((c) => ({
            sha: c.sha,
            message: c.commit?.message || "",
            date: c.commit?.committer?.date || "",
            url: c.html_url || "",
            author: c.commit?.author?.name || "",
          }));
        }
      } catch {
        return [];
      }
    }
  }

  const seen = new Set(state.seenCommitShas || []);
  return commits
    .filter((c) => c.sha && !seen.has(c.sha))
    .map((c) => ({
      type: "commit",
      id: c.sha,
      title: (c.message || "").split("\n")[0].substring(0, 120),
      date: c.date,
      url: c.url,
      author: c.author,
    }));
}

function checkDiscussions(repo, state, config) {
  const limit = config.maxDiscussions || 10;
  // gh CLI doesn't have a native discussions list; use the GraphQL API
  const [owner, name] = repo.split("/");
  const query = `query { repository(owner: \\"${owner}\\", name: \\"${name}\\") { discussions(first: ${limit}, orderBy: {field: CREATED_AT, direction: DESC}) { nodes { id number title createdAt url author { login } } } } }`;

  const raw = gh(`api graphql -f query="${query}"`);
  if (!raw) return [];

  let nodes = [];
  try {
    const parsed = JSON.parse(raw);
    nodes = parsed?.data?.repository?.discussions?.nodes || [];
  } catch {
    return [];
  }

  const seen = new Set(state.seenDiscussionIds || []);
  return nodes
    .filter((d) => !seen.has(String(d.number)))
    .map((d) => ({
      type: "discussion",
      id: String(d.number),
      title: d.title,
      date: d.createdAt,
      url: d.url,
      author: d.author?.login || "unknown",
    }));
}

function checkIssues(repo, state, config) {
  const limit = config.maxIssues || 10;
  const items = ghJson(
    `issue list --repo ${repo} --limit ${limit} --state open --json number,title,createdAt,url,author`
  );
  if (!items || !Array.isArray(items) || items.length === 0) return [];

  const seen = new Set(state.seenIssueIds || []);
  return items
    .filter((i) => !seen.has(String(i.number)))
    .map((i) => ({
      type: "issue",
      id: String(i.number),
      title: i.title,
      date: i.createdAt,
      url: i.url,
      author: i.author?.login || "unknown",
    }));
}

// ── formatting ───────────────────────────────────────────────────────────────

function formatItem(item) {
  const date = item.date ? new Date(item.date).toISOString().slice(0, 10) : "";
  const prefix = {
    release: "🏷️  Release",
    commit: "📝 Commit",
    discussion: "💬 Discussion",
    issue: "🐛 Issue",
  }[item.type] || item.type;

  const authorStr = item.author ? ` (by ${item.author})` : "";
  const shortId = item.type === "commit" ? item.id.substring(0, 7) : `#${item.id}`;
  return `  ${prefix} ${shortId}: ${item.title}${authorStr}  [${date}]\n    ${item.url || ""}`;
}

function formatSummary(newItems, repo) {
  if (newItems.length === 0) return "";

  const grouped = {};
  for (const item of newItems) {
    (grouped[item.type] = grouped[item.type] || []).push(item);
  }

  const lines = [
    `## 🔭 Upstream Monitor — ${repo}`,
    `Checked: ${new Date().toISOString()}`,
    `Found **${newItems.length}** new item(s):\n`,
  ];

  const order = ["release", "commit", "discussion", "issue"];
  for (const type of order) {
    const items = grouped[type];
    if (!items || items.length === 0) continue;
    const label = { release: "Releases", commit: "Commits", discussion: "Discussions", issue: "Issues" }[type];
    lines.push(`### ${label} (${items.length})`);
    for (const item of items) {
      lines.push(formatItem(item));
    }
    lines.push("");
  }

  return lines.join("\n");
}

// ── main ─────────────────────────────────────────────────────────────────────

function main() {
  const args = process.argv.slice(2);
  const reset = args.includes("--reset");
  const dryRun = args.includes("--dry-run");

  // Load config
  const config = loadJson(CONFIG_PATH);
  if (!config) {
    console.error(`Error: config not found at ${CONFIG_PATH}`);
    process.exit(1);
  }

  // Load or initialize state
  let state = reset ? {} : loadJson(STATE_PATH) || {};
  if (reset) {
    state = {
      lastChecked: null,
      lastSeenRelease: null,
      lastSeenCommitSha: null,
      lastSeenDiscussionId: null,
      lastSeenIssueId: null,
      seenReleaseIds: [],
      seenCommitShas: [],
      seenDiscussionIds: [],
      seenIssueIds: [],
    };
  }

  const repo = config.repo || "bradygaster/squad";
  const newItems = [];

  // Run checks
  if (config.trackReleases !== false) {
    try {
      const releases = checkReleases(repo, state);
      newItems.push(...releases);
      for (const r of releases) state.seenReleaseIds = capArray([...(state.seenReleaseIds || []), r.id]);
      if (releases.length > 0) state.lastSeenRelease = releases[0].id;
    } catch (err) {
      console.error(`Warning: failed to check releases — ${err.message}`);
    }
  }

  if (config.trackCommits !== false) {
    try {
      const commits = checkCommits(repo, state, config);
      newItems.push(...commits);
      for (const c of commits) state.seenCommitShas = capArray([...(state.seenCommitShas || []), c.id]);
      if (commits.length > 0) state.lastSeenCommitSha = commits[0].id;
    } catch (err) {
      console.error(`Warning: failed to check commits — ${err.message}`);
    }
  }

  if (config.trackDiscussions !== false) {
    try {
      const discussions = checkDiscussions(repo, state, config);
      newItems.push(...discussions);
      for (const d of discussions) state.seenDiscussionIds = capArray([...(state.seenDiscussionIds || []), d.id]);
      if (discussions.length > 0) state.lastSeenDiscussionId = discussions[0].id;
    } catch (err) {
      console.error(`Warning: failed to check discussions — ${err.message}`);
    }
  }

  if (config.trackIssues !== false) {
    try {
      const issues = checkIssues(repo, state, config);
      newItems.push(...issues);
      for (const i of issues) state.seenIssueIds = capArray([...(state.seenIssueIds || []), i.id]);
      if (issues.length > 0) state.lastSeenIssueId = issues[0].id;
    } catch (err) {
      console.error(`Warning: failed to check issues — ${err.message}`);
    }
  }

  // Update state
  state.lastChecked = new Date().toISOString();
  if (!dryRun) {
    saveJson(STATE_PATH, state);
  }

  // Output summary
  const summary = formatSummary(newItems, repo);
  if (summary) {
    console.log(summary);
  } else {
    console.log(`✅ No new upstream changes in ${repo} since last check.`);
  }
}

main();
