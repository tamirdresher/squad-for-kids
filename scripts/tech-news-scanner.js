#!/usr/bin/env node

/**
 * Tech News Scanner
 * Scans HackerNews, Reddit, Morning Dew (alvinashcraft.com), Architecture Notes (architecturenotes.co),
 * ThoughtWorks Radar, and bradygaster/squad GitHub repo for relevant tech stories and product updates.
 * Also checks Brady Gaster's blog for Squad-related posts.
 * Filters by topics: AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools, Squad
 * 
 * Posts digest to both Teams channels:
 * - squads > Tech News (Tamir's squad notifications)
 * - Squad > Squad Tech News (Brady's product team)
 * 
 * Deduplication:
 * - Checks if a Tech News Digest issue already exists for today before creating
 * - Tracks reported URLs in .squad/monitoring/tech-news-state.json to avoid reposting
 */

import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const KEYWORDS = [
  'ai', 'artificial intelligence', 'machine learning', 'ml', 'llm', 'gpt', 'copilot',
  'vibecoding', 'vibe coding',
  '.net', 'dotnet', 'c#', 'csharp', 'aspnet', 'blazor',
  'golang', 'go lang',
  'kubernetes', 'k8s', 'cloud native', 'cncf',
  'developer tools', 'devtools', 'ide', 'vscode', 'github',
  'architecture',
  'tech radar', 'thoughtworks',
  'squad',
  // AWS keywords — added for issue #931
  'aws', 'amazon web services', 'lambda', 'serverless', 'ec2', 's3', 'dynamodb',
  'cloudformation', 'cdk', 'eks', 'ecs', 'fargate', 'bedrock', 'sagemaker',
  'step functions', 'eventbridge', 'api gateway', 'cognito', 'iam',
  'well-architected', 'multi-region', 'elasticache', 'rds', 'aurora',
  'graviton', 'outposts', 'wavelength', 'cloudfront', 'route 53'
];

// ─── Relevance scoring ────────────────────────────────────────────────────────
// HIGH  = directly impacts our work (squads, .NET, K8s, AI agents, Azure, MCP)
// MEDIUM = adjacent tech worth monitoring
// LOW    = filtered out of the digest entirely
const HIGH_RELEVANCE_KEYWORDS = [
  'squad', 'k8s', 'kubernetes', '.net', 'dotnet', 'c#', 'csharp', 'aspnet', 'blazor', 'aspire',
  'ai agent', 'ai agents', 'agentic', 'github copilot', 'copilot', 'copilot workspace',
  'azure', 'aks', 'azure kubernetes', 'mcp', 'model context protocol',
  'semantic kernel', 'dapr', 'microsoft', 'opentelemetry', 'otel',
];

const MEDIUM_RELEVANCE_KEYWORDS = [
  'ai', 'machine learning', 'llm', 'gpt', 'claude', 'openai', 'anthropic', 'gemini',
  'cloud native', 'cncf', 'docker', 'container', 'helm', 'gitops', 'argocd', 'flux',
  'github', 'vscode', 'vs code', 'devtools', 'developer tools', 'dev tools',
  'golang', 'rust', 'typescript', 'nodejs',
  'aws', 'gcp', 'serverless', 'lambda', 'security', 'cve', 'vulnerab',
];

function scoreRelevance(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  if (HIGH_RELEVANCE_KEYWORDS.some(kw => text.includes(kw))) return 'HIGH';
  if (MEDIUM_RELEVANCE_KEYWORDS.some(kw => text.includes(kw))) return 'MEDIUM';
  return 'LOW';
}

function getWhyItMatters(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  if (text.includes('squad') && (text.includes('release') || text.includes('update') || text.includes('commit'))) {
    return '⚡ **Direct squad impact** — this is our own tooling evolving.';
  }
  if (text.includes('mcp') || text.includes('model context protocol')) {
    return '🔌 **MCP ecosystem** — affects how our AI agents connect to external tools.';
  }
  if (text.includes('ai agent') || text.includes('ai agents') || text.includes('agentic')) {
    return '🧠 **AI agents** — directly shapes the multi-agent patterns we\'re implementing.';
  }
  if (text.includes('kubernetes') || text.includes('k8s') || text.includes('aks')) {
    return '☸️ **K8s platform** — our deployment infra, fleet management, and AKS upgrade path.';
  }
  if (text.includes('.net') || text.includes('dotnet') || text.includes('csharp') || text.includes('c#') || text.includes('aspnet') || text.includes('blazor') || text.includes('aspire')) {
    return '🔷 **.NET stack** — our primary backend language and runtime.';
  }
  if (text.includes('azure')) {
    return '☁️ **Azure platform** — our cloud home and integration surface.';
  }
  if (text.includes('copilot') || (text.includes('github') && text.includes('ai'))) {
    return '🤖 **GitHub/Copilot** — our dev workflow and AI coding assistant ecosystem.';
  }
  if (text.includes('semantic kernel') || text.includes('dapr')) {
    return '🔗 **Microsoft OSS** — tooling we build on or integrate with directly.';
  }
  if (text.includes('security') || text.includes('cve') || text.includes('vulnerab')) {
    return '🔐 **Security** — action required: check if we\'re exposed.';
  }
  if (text.includes('docker') || text.includes('container') || text.includes('helm')) {
    return '🐳 **Containers/Helm** — runtime and packaging tech we depend on daily.';
  }
  if (text.includes('ai') || text.includes('llm') || text.includes('gpt')) {
    return '🌐 **AI ecosystem** — foundation models powering the features we ship.';
  }
  return '📡 **Tech radar** — worth tracking as the ecosystem evolves.';
}

function generateTldr(story) {
  const title = story.title;
  const lower = title.toLowerCase();

  const isRelease = /\bv?\d+\.\d+(\.\d+)?/.test(lower)
    || lower.includes('release') || lower.includes('launches') || lower.includes('released') || lower.includes('ships');

  if (isRelease) {
    if (lower.includes('.net') || lower.includes('dotnet') || lower.includes('aspnet') || lower.includes('blazor') || lower.includes('aspire')) {
      return '.NET ecosystem release — check the changelog for breaking changes and new capabilities affecting our services.';
    }
    if (lower.includes('kubernetes') || lower.includes('k8s')) {
      return 'Kubernetes version drop — important for AKS fleet upgrade planning and compatibility checks.';
    }
    if (lower.includes('copilot') || lower.includes('github')) {
      return 'GitHub/Copilot update — new capabilities may be live in our dev workflow today.';
    }
    if (lower.includes('azure')) {
      return 'Azure service release — review for new features or pricing changes that affect our cloud footprint.';
    }
    if (lower.includes('mcp') || lower.includes('model context protocol')) {
      return 'MCP protocol update — new tools or capabilities our agents can leverage.';
    }
    return 'New release worth noting — version bump that may affect our dependencies or toolchain.';
  }

  if (lower.includes('ai agent') || lower.includes('agentic') || lower.includes('multi-agent')) {
    return 'AI agent architecture development — directly relevant to our multi-agent squad system design.';
  }
  if (lower.includes('mcp') || lower.includes('model context protocol')) {
    return 'MCP ecosystem update — could change how our agents connect to tools and data sources.';
  }
  if (lower.includes('kubernetes') || lower.includes('k8s') || lower.includes('aks')) {
    return 'K8s ecosystem development — worth a read for the platform engineering side of our work.';
  }
  if (lower.includes('azure')) {
    return 'Azure news affecting our cloud platform — feature, pricing, or capability change worth tracking.';
  }
  if (lower.includes('.net') || lower.includes('dotnet') || lower.includes('c#') || lower.includes('aspnet')) {
    return '.NET/C# development — directly relevant to our backend services and tooling.';
  }
  if (lower.includes('security') || lower.includes('cve') || lower.includes('vulnerab') || lower.includes('patch')) {
    return 'Security advisory — scan our dependencies and infrastructure for exposure before end of day.';
  }
  if (lower.includes('copilot')) {
    return 'Copilot/AI coding tool update — may change our dev productivity or available features.';
  }
  if (lower.includes('llm') || lower.includes('gpt') || lower.includes('claude') || lower.includes('openai') || lower.includes('anthropic')) {
    return 'Foundation model news — context for the AI capabilities we\'re building on top of.';
  }
  if (lower.includes('docker') || lower.includes('container') || lower.includes('helm')) {
    return 'Container ecosystem update — check for anything affecting our build and deployment pipeline.';
  }
  return 'Notable development in the tech landscape — worth a skim to stay ahead of the curve.';
}

// Neelix personality commentary — grouped by relevance tier.
// Neelix is Star Trek Voyager's enthusiastic chef/morale officer: witty, warm, occasionally
// over-the-top, always genuine. He loves analogies to food, space travel, and strange aliens.
const NEELIX_QUIPS = {
  HIGH: [
    "Now THIS is what I call a hearty serving of relevance! Straight to the crew's reading list. 🍲",
    "Captain, I'd put this one on the *essential menu* — as important as keeping the replicators running. 🚀",
    "Direct hit on our tech stack. The kind of story that separates a well-prepared crew from a hungry one.",
    "I've seen a lot of strange things in the Delta Quadrant, but THIS level of relevance? Truly remarkable.",
    "As my Talaxian grandmother always said: when the tech matters, you read it *twice*.",
    "Computer, flag this for the senior staff briefing. We're on course heading for this one. 🖖",
    "I wouldn't interrupt the captain's dinner for most things — but for this? Absolutely.",
    "Call this the plomeek soup of tech news: nourishing, slightly acquired taste, absolutely essential. 🍵",
  ],
  MEDIUM: [
    "A solid side dish — not the main course, but don't you dare skip it.",
    "Keep this one warm on the back burner. Could be useful before end of quarter. 🔥",
    "Medium relevance, but in the Delta Quadrant, a 'side dish' has saved this ship more than once.",
    "The crew should glance at this between missions. Knowledge is the best ration pack.",
    "Not an emergency, but absolutely worth a coffee-break read. ☕",
    "Situational awareness, ensign — that's what separates good engineers from great navigators.",
    "I wouldn't interrupt dinner for this, but I'd mention it over dessert. You've been warned. 🍮",
    "Think of it as leola root stew: nobody's excited, but later they're grateful they had it.",
  ],
};

function getNeelixQuip(relevance) {
  const quips = NEELIX_QUIPS[relevance] || NEELIX_QUIPS.MEDIUM;
  // Use a deterministic-ish pick so repeated runs don't change the digest mid-day
  const seed = (new Date().getDate() + quips.length) % quips.length;
  return quips[seed];
}

function generateActionItems(stories) {
  const actions = [];
  for (const story of stories) {
    if (story.relevance !== 'HIGH') continue;
    const text = story.title.toLowerCase();

    if (/\bv?\d+\.\d+/.test(text) && (text.includes('.net') || text.includes('dotnet'))) {
      actions.push(`🔷 **Review .NET release**: [${story.title}](${story.url}) — check changelog for breaking changes affecting our services`);
    } else if (/\bv?\d+\.\d+/.test(text) && (text.includes('kubernetes') || text.includes('k8s'))) {
      actions.push(`☸️ **Plan K8s upgrade window**: [${story.title}](${story.url}) — assess AKS fleet compatibility`);
    } else if (text.includes('security') || text.includes('cve') || text.includes('vulnerab')) {
      actions.push(`🔐 **Security check**: [${story.title}](${story.url}) — verify our stack is not exposed`);
    } else if (text.includes('mcp') || text.includes('model context protocol')) {
      actions.push(`🔌 **Evaluate for agent tooling**: [${story.title}](${story.url}) — MCP compatibility and adoption potential`);
    } else if (text.includes('copilot') && (text.includes('feature') || text.includes('update') || text.includes('new'))) {
      actions.push(`🤖 **Try new Copilot capability**: [${story.title}](${story.url})`);
    } else if (text.includes('azure') && (text.includes('aks') || text.includes('kubernetes'))) {
      actions.push(`☁️ **Azure/AKS review**: [${story.title}](${story.url}) — check impact on our cluster configuration`);
    } else if (text.includes('squad') && (text.includes('release') || text.includes('update'))) {
      actions.push(`⚡ **Squad product update**: [${story.title}](${story.url}) — our own tooling, stay current!`);
    }
  }
  return actions.slice(0, 6);
}

// Brady's Squad repo monitoring config
const SQUAD_REPO = { owner: 'bradygaster', repo: 'squad' };
const BRADY_BLOG_URL = 'https://bradygaster.com';

// Teams channel targets for posting digests
// public: true  = shared with external collaborators — NO issue numbers, repo names, or internal refs
// public: false = Tamir's private notifications — full content with issue links and internal refs
const TEAMS_CHANNELS = [
  { teamId: '5f93abfe-b968-44ea-bd0a-6f155046ccc7', channelId: '19:bfe3224e8e764c2785e81e7cb3cc944d@thread.tacv2', label: 'squads > Tech News', public: false },
  { teamId: '1de78cdf-3f73-4447-9601-a940bd98b80d', channelId: '19:c940af255e22486882c069d7b38a6204@thread.tacv2', label: 'Squad > Squad Tech News', public: true }
];

// Setup state file path
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const stateDir = path.join(__dirname, '..', '.squad', 'monitoring');
const stateFile = path.join(stateDir, 'tech-news-state.json');

// Ensure state directory exists
function ensureStateDir() {
  if (!fs.existsSync(stateDir)) {
    fs.mkdirSync(stateDir, { recursive: true });
  }
}

// Load state from file
function loadState() {
  try {
    if (fs.existsSync(stateFile)) {
      const data = fs.readFileSync(stateFile, 'utf8');
      return JSON.parse(data);
    }
  } catch (e) {
    console.error(`Warning: Could not load state file: ${e.message}`);
  }
  return { lastScanDate: null, reportedUrls: {} };
}

// Save state to file
function saveState(state) {
  try {
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2), 'utf8');
  } catch (e) {
    console.error(`Warning: Could not save state file: ${e.message}`);
  }
}

// Get today's date in YYYY-MM-DD format
function getTodayDate() {
  return new Date().toISOString().split('T')[0];
}

// Check if an issue already exists for today
function issueExistsForToday(date) {
  try {
    const searchTerm = `Tech News Digest: ${date} in:title`;
    const output = execFileSync(
      'gh', ['issue', 'list', '--state', 'all', '--search', searchTerm, '--json', 'number,title'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();
    const issues = JSON.parse(output || '[]');
    // Exact title match to avoid false positives from fuzzy search
    const exactMatch = issues.some(i => i.title && i.title.includes(`Tech News Digest: ${date}`));
    return exactMatch;
  } catch (e) {
    console.error(`Warning: Could not check for existing issues: ${e.message}`);
    return false;
  }
}

function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'TechNewsScanner/1.0' } }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    }).on('error', reject);
  });
}

function matchesKeywords(text) {
  if (!text) return false;
  const lowerText = text.toLowerCase();
  return KEYWORDS.some(keyword => lowerText.includes(keyword));
}

async function fetchHackerNews() {
  console.error('Fetching HackerNews top stories...');
  const topStoryIds = await httpsGet('https://hacker-news.firebaseio.com/v0/topstories.json');
  
  // Fetch top 30 stories
  const storyPromises = topStoryIds.slice(0, 30).map(id =>
    httpsGet(`https://hacker-news.firebaseio.com/v0/item/${id}.json`)
  );
  
  const stories = await Promise.all(storyPromises);
  
  // Filter for relevant stories
  const filtered = stories.filter(story => 
    story && story.title && matchesKeywords(story.title)
  ).map(story => ({
    title: story.title,
    url: story.url || `https://news.ycombinator.com/item?id=${story.id}`,
    score: story.score,
    source: 'HackerNews'
  }));
  
  console.error(`Found ${filtered.length} relevant HackerNews stories`);
  return filtered;
}

async function fetchReddit(subreddit) {
  console.error(`Fetching Reddit: ${subreddit}...`);
  try {
    const data = await httpsGet(`https://www.reddit.com/r/${subreddit}/hot.json?limit=25`);
    
    if (!data.data || !data.data.children) {
      console.error(`No data from r/${subreddit}`);
      return [];
    }
    
    const posts = data.data.children
      .map(child => child.data)
      .filter(post => post.title && matchesKeywords(post.title))
      .map(post => ({
        title: post.title,
        url: `https://www.reddit.com${post.permalink}`,
        score: post.score,
        source: `Reddit: r/${subreddit}`
      }));
    
    console.error(`Found ${posts.length} relevant posts in r/${subreddit}`);
    return posts;
  } catch (e) {
    console.error(`Error fetching r/${subreddit}: ${e.message}`);
    return [];
  }
}

async function fetchMorningDew() {
  console.error('Fetching Morning Dew (alvinashcraft.com)...');
  try {
    const xml = await httpsGet('https://www.alvinashcraft.com/feed/');

    if (typeof xml !== 'string') {
      console.error('Unexpected response from Morning Dew feed');
      return [];
    }

    // Parse RSS <item> entries with simple regex
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/) || [])[1]
        || (block.match(/<title>(.*?)<\/title>/) || [])[1]
        || '';
      const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
      const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

      if (title && link) {
        items.push({ title: title.trim(), url: link.trim(), pubDate });
      }
    }

    // Filter by keywords
    const filtered = items
      .filter(item => matchesKeywords(item.title))
      .map(item => ({
        title: item.title,
        url: item.url,
        score: 50, // base score for RSS items (no upvote data)
        source: 'Morning Dew'
      }));

    console.error(`Found ${filtered.length} relevant Morning Dew items`);
    return filtered;
  } catch (e) {
    console.error(`Error fetching Morning Dew: ${e.message}`);
    return [];
  }
}

async function fetchArchitectureNotes() {
  console.error('Fetching Architecture Notes (architecturenotes.co)...');
  try {
    const xml = await httpsGet('https://architecturenotes.co/feed');

    if (typeof xml !== 'string') {
      console.error('Unexpected response from Architecture Notes feed');
      return [];
    }

    // Parse RSS <item> entries with simple regex
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/) || [])[1]
        || (block.match(/<title>(.*?)<\/title>/) || [])[1]
        || '';
      const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
      const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

      if (title && link) {
        items.push({ title: title.trim(), url: link.trim(), pubDate });
      }
    }

    // Filter by keywords
    const filtered = items
      .filter(item => matchesKeywords(item.title))
      .map(item => ({
        title: item.title,
        url: item.url,
        score: 50, // base score for RSS items (no upvote data)
        source: 'Architecture Notes'
      }));

    console.error(`Found ${filtered.length} relevant Architecture Notes items`);
    return filtered;
  } catch (e) {
    console.error(`Error fetching Architecture Notes: ${e.message}`);
    return [];
  }
}

async function fetchThoughtWorksRadar() {
  console.error('Fetching ThoughtWorks Technology Radar...');
  const feedUrls = [
    'https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/tw_radar.rss',
    'https://www.thoughtworks.com/rss',
    'https://www.thoughtworks.com/radar/rss',
    'https://feeds.feedburner.com/ThoughtworksRadar'
  ];

  for (const feedUrl of feedUrls) {
    try {
      const xml = await httpsGet(feedUrl);

      if (typeof xml !== 'string') {
        continue;
      }

      // Parse RSS <item> entries with simple regex (same approach as other RSS sources)
      const items = [];
      const itemRegex = /<item>([\s\S]*?)<\/item>/g;
      let match;
      while ((match = itemRegex.exec(xml)) !== null) {
        const block = match[1];
        const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/) || [])[1]
          || (block.match(/<title>(.*?)<\/title>/) || [])[1]
          || '';
        const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
        const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

        if (title && link) {
          items.push({ title: title.trim(), url: link.trim(), pubDate });
        }
      }

      if (items.length === 0) {
        continue;
      }

      // Filter by keywords
      const filtered = items
        .filter(item => matchesKeywords(item.title))
        .map(item => ({
          title: item.title,
          url: item.url,
          score: 75, // higher base score — curated expert content
          source: 'ThoughtWorks Radar'
        }));

      console.error(`Found ${filtered.length} relevant ThoughtWorks Radar items (from ${feedUrl})`);
      return filtered;
    } catch (e) {
      console.error(`Error fetching ThoughtWorks Radar from ${feedUrl}: ${e.message}`);
    }
  }

  console.error('Could not fetch ThoughtWorks Radar from any feed URL');
  return [];
}

// Fetch releases from bradygaster/squad via GitHub API
async function fetchSquadReleases() {
  console.error('Fetching bradygaster/squad releases...');
  try {
    const output = execFileSync(
      'gh', ['api', `repos/${SQUAD_REPO.owner}/${SQUAD_REPO.repo}/releases`, '--jq', '.[0:10]'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const releases = JSON.parse(output || '[]');
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recent = releases
      .filter(r => new Date(r.published_at || r.created_at) > oneDayAgo)
      .map(r => ({
        title: `[Squad Release] ${r.name || r.tag_name}`,
        url: r.html_url,
        score: 100,
        source: 'bradygaster/squad',
        body: (r.body || '').slice(0, 300)
      }));
    console.error(`Found ${recent.length} recent Squad releases`);
    return recent;
  } catch (e) {
    console.error(`Error fetching Squad releases: ${e.message}`);
    return [];
  }
}

// Fetch recent discussions from bradygaster/squad
async function fetchSquadDiscussions() {
  console.error('Fetching bradygaster/squad discussions...');
  try {
    const query = `query { repository(owner:"${SQUAD_REPO.owner}", name:"${SQUAD_REPO.repo}") { discussions(first:10, orderBy:{field:CREATED_AT, direction:DESC}) { nodes { title url createdAt category { name } } } } }`;
    const output = execFileSync(
      'gh', ['api', 'graphql', '-f', `query=${query}`],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const data = JSON.parse(output || '{}');
    const discussions = data?.data?.repository?.discussions?.nodes || [];
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recent = discussions
      .filter(d => new Date(d.createdAt) > oneDayAgo)
      .map(d => ({
        title: `[Squad Discussion] ${d.title}`,
        url: d.url,
        score: 80,
        source: 'bradygaster/squad',
        category: d.category?.name || 'General'
      }));
    console.error(`Found ${recent.length} recent Squad discussions`);
    return recent;
  } catch (e) {
    console.error(`Error fetching Squad discussions: ${e.message}`);
    return [];
  }
}

// Fetch recent commits from bradygaster/squad
async function fetchSquadCommits() {
  console.error('Fetching bradygaster/squad commits...');
  try {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const output = execFileSync(
      'gh', ['api', `repos/${SQUAD_REPO.owner}/${SQUAD_REPO.repo}/commits?since=${since}&per_page=10`],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const commits = JSON.parse(output || '[]');
    const items = commits.map(c => ({
      title: `[Squad Commit] ${(c.commit?.message || '').split('\n')[0]}`,
      url: c.html_url,
      score: 60,
      source: 'bradygaster/squad',
      author: c.commit?.author?.name || 'unknown'
    }));
    console.error(`Found ${items.length} recent Squad commits`);
    return items;
  } catch (e) {
    console.error(`Error fetching Squad commits: ${e.message}`);
    return [];
  }
}

// Fetch Brady Gaster's blog RSS for Squad-related posts
async function fetchBradyBlog() {
  console.error('Fetching Brady Gaster blog for Squad posts...');
  try {
    const xml = await httpsGet(`${BRADY_BLOG_URL}/feed/`);
    if (typeof xml !== 'string') {
      // Try alternate feed path
      const xml2 = await httpsGet(`${BRADY_BLOG_URL}/index.xml`);
      if (typeof xml2 !== 'string') {
        console.error('Unexpected response from Brady blog feed');
        return [];
      }
      return parseBlogFeed(xml2);
    }
    return parseBlogFeed(xml);
  } catch (e) {
    console.error(`Error fetching Brady blog: ${e.message}`);
    return [];
  }
}

function parseBlogFeed(xml) {
  const items = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let match;
  while ((match = itemRegex.exec(xml)) !== null) {
    const block = match[1];
    const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>/) || [])[1]
      || (block.match(/<title>(.*?)<\/title>/) || [])[1]
      || '';
    const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
    const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';
    const description = (block.match(/<description><!\[CDATA\[(.*?)\]\]>/) || [])[1]
      || (block.match(/<description>(.*?)<\/description>/) || [])[1]
      || '';

    if (title && link) {
      items.push({ title: title.trim(), url: link.trim(), pubDate, description: description.trim() });
    }
  }

  // Filter for Squad-related posts
  const squadKeywords = ['squad', 'ai team', 'ai agents', 'copilot workspace'];
  const filtered = items.filter(item => {
    const text = `${item.title} ${item.description}`.toLowerCase();
    return squadKeywords.some(kw => text.includes(kw));
  }).map(item => ({
    title: `[Brady Blog] ${item.title}`,
    url: item.url,
    score: 90,
    source: 'bradygaster.com'
  }));

  console.error(`Found ${filtered.length} Squad-related Brady blog posts`);
  return filtered;
}

// AWS blog sources — added for issue #931
const AWS_BLOGS = [
  { name: 'AWS Architecture Blog',    feedUrl: 'https://aws.amazon.com/blogs/architecture/feed/',   category: 'cloud/aws', score: 80 },
  { name: 'AWS News Blog',            feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',            category: 'cloud/aws', score: 85 },
  { name: 'AWS Compute Blog',         feedUrl: 'https://aws.amazon.com/blogs/compute/feed/',        category: 'cloud/aws', score: 75 },
  { name: 'AWS Developer Tools Blog', feedUrl: 'https://aws.amazon.com/blogs/developer/feed/',      category: 'cloud/aws', score: 70 },
  { name: 'AWS Containers Blog',      feedUrl: 'https://aws.amazon.com/blogs/containers/feed/',     category: 'cloud/aws', score: 75 },
];

/**
 * Fetch a single AWS blog RSS feed.
 * All AWS blogs use the same WordPress RSS structure.
 */
async function fetchAwsBlog({ name, feedUrl, category, score }) {
  console.error(`Fetching ${name}...`);
  try {
    const xml = await httpsGet(feedUrl);

    if (typeof xml !== 'string') {
      console.error(`Unexpected response from ${name}`);
      return [];
    }

    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      // AWS feeds use CDATA-wrapped titles
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>/) || [])[1]
        || (block.match(/<title>(.*?)<\/title>/) || [])[1]
        || '';
      // AWS feeds use <link> as a direct URL (no CDATA) but sometimes wrapped in CDATA
      const link = (block.match(/<link><!\[CDATA\[(.*?)\]\]>/) || [])[1]
        || (block.match(/<link>(.*?)<\/link>/) || [])[1]
        || '';
      const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

      if (title && link) {
        items.push({ title: title.trim(), url: link.trim(), pubDate });
      }
    }

    // AWS blogs are always cloud-relevant; still filter by keyword to avoid noise
    // but fall back to including all items from Architecture/News blogs (high signal)
    const isHighSignal = name === 'AWS Architecture Blog' || name === 'AWS News Blog';
    const filtered = items
      .filter(item => isHighSignal || matchesKeywords(item.title))
      .map(item => ({
        title: item.title,
        url: item.url,
        score,
        source: name,
        category,
      }));

    console.error(`Found ${filtered.length} relevant items from ${name}`);
    return filtered;
  } catch (e) {
    console.error(`Error fetching ${name}: ${e.message}`);
    return [];
  }
}

async function scanAllSources() {
  const subreddits = ['programming', 'webdev', 'dotnet', 'golang', 'artificial', 'MachineLearning', 'BlackboxAI_'];
  
  const [hnStories, morningDew, archNotes, twRadar, squadReleases, squadDiscussions, squadCommits, bradyBlog, ...rest] = await Promise.all([
    fetchHackerNews(),
    fetchMorningDew(),
    fetchArchitectureNotes(),
    fetchThoughtWorksRadar(),
    fetchSquadReleases(),
    fetchSquadDiscussions(),
    fetchSquadCommits(),
    fetchBradyBlog(),
    // AWS blogs (issue #931) — fetch all in parallel with other sources
    ...AWS_BLOGS.map(blog => fetchAwsBlog(blog)),
    ...subreddits.map(sub => fetchReddit(sub))
  ]);
  
  // rest = [awsArch, awsNews, awsCompute, awsDev, awsContainers, ...redditResults]
  const awsResults = rest.slice(0, AWS_BLOGS.length);
  const redditResults = rest.slice(AWS_BLOGS.length);

  const allStories = [
    ...hnStories,
    ...morningDew,
    ...archNotes,
    ...twRadar,
    ...awsResults.flat(),
    ...redditResults.flat(),
  ];
  const squadUpdates = [...squadReleases, ...squadDiscussions, ...squadCommits, ...bradyBlog];
  
  // Sort by score descending
  allStories.sort((a, b) => b.score - a.score);
  squadUpdates.sort((a, b) => b.score - a.score);
  
  return { stories: allStories, squadUpdates };
}

/**
 * Sanitize content for public channels.
 * Strips GitHub issue numbers (#XXX), repo names (tamresearch1), internal Squad references,
 * and any private repo URLs so nothing internal leaks to shared channels.
 */
function sanitizeForPublic(text) {
  return text
    // Remove issue references like #920, Issue #123, issue #45
    .replace(/\b[Ii]ssue\s*#\d+/g, '')
    // Remove standalone #NNN references (but not inside URLs)
    .replace(/(?<![/\w])#\d+\b/g, '')
    // Remove repo name references
    .replace(/\btamresearch1\b/gi, '')
    // Remove GitHub URLs pointing to private repos
    .replace(/https?:\/\/github\.com\/[^/]+\/tamresearch1[^\s)>]*/g, '')
    // Remove internal scanner/script references
    .replace(/\bscanner script\b/gi, '')
    // Remove Squad internal metadata labels
    .replace(/\bsquad:(copilot|review|triage)\b/gi, '')
    // Clean up leftover empty parentheses or brackets from removed refs
    .replace(/\(\s*\)/g, '')
    .replace(/\[\s*\]/g, '')
    // Collapse multiple blank lines
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function formatDigest(stories, squadUpdates = [], { isPublic = false } = {}) {
  const date = new Date().toISOString().split('T')[0];

  // ── Enrich stories with relevance, TL;DR, and personality ────────────────
  const enriched = stories
    .map(story => ({
      ...story,
      relevance: scoreRelevance(story),
      tldr: generateTldr(story),
      whyItMatters: getWhyItMatters(story),
      neelixQuip: null, // populated below per tier
    }))
    .filter(story => story.relevance !== 'LOW');

  // Attach Neelix quips (deterministic per relevance tier, not per story)
  enriched.forEach(story => {
    story.neelixQuip = getNeelixQuip(story.relevance);
  });

  const highStories   = enriched.filter(s => s.relevance === 'HIGH');
  const mediumStories = enriched.filter(s => s.relevance === 'MEDIUM');
  const actionItems   = generateActionItems(enriched);

  let digest = `# 🛸 Tech News Digest — ${date}\n\n`;
  digest += `> _Curated by your friendly neighbourhood tech chef. Today's menu: ${highStories.length} HIGH-relevance and ${mediumStories.length} MEDIUM-relevance stories (${stories.length - enriched.length} LOW-relevance items quietly composted)._\n\n`;

  // ── Squad product updates — private digests only ──────────────────────────
  if (!isPublic && squadUpdates.length > 0) {
    digest += `---\n\n`;
    digest += `## 🚀 Squad Product Updates (bradygaster/squad)\n\n`;
    digest += `Found ${squadUpdates.length} updates from Brady's Squad repo and blog.\n\n`;
    squadUpdates.forEach((item, idx) => {
      digest += `### ${idx + 1}. ${item.title}\n\n`;
      digest += `- **Source:** ${item.source}\n`;
      digest += `- **Link:** ${item.url}\n`;
      if (item.body) digest += `- **Details:** ${item.body}\n`;
      if (item.category) digest += `- **Category:** ${item.category}\n`;
      if (item.author) digest += `- **Author:** ${item.author}\n`;
      digest += `\n`;
    });
  }

  digest += `---\n\n`;

  if (enriched.length === 0 && (isPublic || squadUpdates.length === 0)) {
    digest += `_No relevant stories found today — the Delta Quadrant is quiet. Enjoy the respite._\n`;
    return digest;
  }

  // ── HIGH relevance stories ────────────────────────────────────────────────
  if (highStories.length > 0) {
    digest += `## 🔴 HIGH Relevance — Read These Now\n\n`;
    highStories.forEach((story, idx) => {
      digest += `### ${idx + 1}. ${story.title}\n\n`;
      digest += `> 💡 **TL;DR:** ${story.tldr}\n\n`;
      digest += `${story.whyItMatters}\n\n`;
      digest += `> 🍳 _Neelix says: "${story.neelixQuip}"_\n\n`;
      digest += `- **Source:** ${story.source}`;
      if (story.score) digest += ` | **Score:** ${story.score}`;
      digest += `\n`;
      digest += `- **Link:** ${story.url}\n\n`;
    });
  }

  // ── MEDIUM relevance stories ──────────────────────────────────────────────
  if (mediumStories.length > 0) {
    digest += `---\n\n`;
    digest += `## 🟡 MEDIUM Relevance — Worth a Glance\n\n`;
    mediumStories.forEach((story, idx) => {
      digest += `### ${idx + 1}. ${story.title}\n\n`;
      digest += `> 💡 **TL;DR:** ${story.tldr}\n\n`;
      digest += `${story.whyItMatters}\n\n`;
      digest += `> 🍵 _Neelix says: "${story.neelixQuip}"_\n\n`;
      digest += `- **Source:** ${story.source}`;
      if (story.score) digest += ` | **Score:** ${story.score}`;
      digest += `\n`;
      digest += `- **Link:** ${story.url}\n\n`;
    });
  }

  // ── Action items from HIGH-relevance stories ──────────────────────────────
  if (!isPublic && actionItems.length > 0) {
    digest += `---\n\n`;
    digest += `## ✅ Action Items\n\n`;
    digest += `_Neelix recommends acting on these before next shift:_\n\n`;
    actionItems.forEach(item => {
      digest += `- ${item}\n`;
    });
    digest += `\n`;
  }

  // Final sanitization pass for public channels
  if (isPublic) {
    digest = sanitizeForPublic(digest);
  }

  return digest;
}

// Post to private webhook channel (full content with issue links and internal refs)
async function postToTeamsWebhook(digest) {
  const home = process.env.USERPROFILE || process.env.HOME || '';
  
  // Per-channel webhook resolution (Issue #821)
  // Priority: tech-news channel file → general channel file → legacy file
  let webhookUrl = null;
  const channelFile = path.join(home, '.squad', 'teams-webhooks', 'tech-news.url');
  const generalFile = path.join(home, '.squad', 'teams-webhooks', 'general.url');
  const legacyFile  = path.join(home, '.squad', 'teams-webhook.url');

  for (const file of [channelFile, generalFile, legacyFile]) {
    if (fs.existsSync(file)) {
      const url = fs.readFileSync(file, 'utf8').trim();
      if (url) { webhookUrl = url; break; }
    }
  }

  if (!webhookUrl) {
    console.error('No Teams webhook URL found (checked tech-news, general, legacy), skipping Teams post');
    return;
  }

  // Truncate for Teams card limit
  const summary = digest.length > 2000
    ? digest.slice(0, 2000) + '\n\n_...truncated. See GitHub issue for full digest._'
    : digest;

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
          text: summary,
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
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.error(`Posted digest to Teams webhook (status: ${res.statusCode})`);
          } else {
            console.error(`Teams webhook returned ${res.statusCode}: ${data}`);
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

/**
 * Convert a markdown-ish digest to HTML suitable for a Teams channel message.
 * Handles: # headings, **bold**, - list items, URLs → <a> links.
 */
function digestToHtml(markdown) {
  const lines = markdown.split('\n');
  const htmlLines = [];
  let inList = false;

  for (const raw of lines) {
    const line = raw.trimEnd();

    // H1
    if (/^# /.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push(`<h1>${escHtml(line.slice(2))}</h1>`);
      continue;
    }
    // H2
    if (/^## /.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push(`<h2>${escHtml(line.slice(3))}</h2>`);
      continue;
    }
    // H3
    if (/^### /.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push(`<h3>${escHtml(line.slice(4))}</h3>`);
      continue;
    }
    // HR
    if (/^---+$/.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push('<hr/>');
      continue;
    }
    // List item
    if (/^- /.test(line)) {
      if (!inList) { htmlLines.push('<ul>'); inList = true; }
      htmlLines.push(`<li>${inlineFormat(line.slice(2))}</li>`);
      continue;
    }
    // Blank line
    if (line === '') {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      continue;
    }
    // Paragraph
    if (inList) { htmlLines.push('</ul>'); inList = false; }
    htmlLines.push(`<p>${inlineFormat(line)}</p>`);
  }
  if (inList) htmlLines.push('</ul>');
  return htmlLines.join('\n');
}

function escHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function inlineFormat(text) {
  // Bold: **text**
  text = text.replace(/\*\*([^*]+)\*\*/g, (_, t) => `<strong>${escHtml(t)}</strong>`);
  // Inline code: `text`
  text = text.replace(/`([^`]+)`/g, (_, t) => `<code>${escHtml(t)}</code>`);
  // Bare URLs (not already inside href=) → clickable links
  text = text.replace(/(?<!href=["'])https?:\/\/[^\s<>"')]+/g, (url) => {
    const cleanUrl = url.replace(/[.,;:!?)]+$/, ''); // strip trailing punctuation
    const display = escHtml(cleanUrl.length > 80 ? cleanUrl.slice(0, 77) + '…' : cleanUrl);
    return `<a href="${cleanUrl}">${display}</a>`;
  });
  return text;
}

/**
 * Get an Azure AD access token for the Graph API via the Azure CLI.
 * Returns the token string, or null if az is unavailable / not logged in.
 */
function getGraphToken() {
  try {
    const raw = execFileSync(
      'az', ['account', 'get-access-token', '--resource', 'https://graph.microsoft.com', '--query', 'accessToken', '-o', 'tsv'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 15000 }
    ).trim();
    return raw || null;
  } catch (e) {
    console.error(`Warning: Could not obtain Graph API token via az CLI: ${e.message}`);
    return null;
  }
}

/**
 * Post an HTML message to a single Teams channel via the Graph API.
 * teamId / channelId come from TEAMS_CHANNELS config.
 */
function postToTeamsChannelViaGraph(teamId, channelId, htmlBody, token) {
  return new Promise((resolve) => {
    const payload = JSON.stringify({
      body: { contentType: 'html', content: htmlBody }
    });

    const options = {
      hostname: 'graph.microsoft.com',
      path: `/v1.0/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/messages`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.error(`Posted digest to Teams channel ${channelId} (status: ${res.statusCode})`);
        } else {
          console.error(`Teams Graph API returned ${res.statusCode} for channel ${channelId}: ${data.slice(0, 200)}`);
        }
        resolve();
      });
    });

    req.on('error', (err) => {
      console.error(`Failed to post to Teams channel ${channelId}: ${err.message}`);
      resolve();
    });

    req.write(payload);
    req.end();
  });
}

/**
 * Post the tech news digest to ALL channels listed in TEAMS_CHANNELS using the
 * Graph API.  Private channels receive the full digest; public channels receive
 * the sanitized version.  Falls back gracefully if az CLI is unavailable.
 */
async function postToBothTeamsChannels(digest, publicDigest) {
  const token = getGraphToken();
  if (!token) {
    console.error('Skipping Graph API channel posts — no access token available.');
    return;
  }

  for (const ch of TEAMS_CHANNELS) {
    const content = ch.public ? publicDigest : digest;
    const html = digestToHtml(content);
    console.error(`Posting to ${ch.label} (teamId: ${ch.teamId})…`);
    await postToTeamsChannelViaGraph(ch.teamId, ch.channelId, html, token);
  }
}

async function main() {
  try {
    ensureStateDir();
    const state = loadState();
    const todayDate = getTodayDate();
    
    console.error('Starting tech news scan...');
    
    // Check if issue already exists for today
    if (issueExistsForToday(todayDate)) {
      console.error(`Tech news digest already exists for today (${todayDate}), skipping.`);
      console.error('To force creation, manually delete the existing issue.');
      process.exit(0);
    }
    
    const { stories, squadUpdates } = await scanAllSources();
    
    // Filter out URLs that have already been reported
    const reportedUrlsForDate = state.reportedUrls[todayDate] || {};
    const newStories = stories.filter(story => !reportedUrlsForDate[story.url]);
    const newSquadUpdates = squadUpdates.filter(item => !reportedUrlsForDate[item.url]);
    
    if (newStories.length === 0 && newSquadUpdates.length === 0 && (stories.length > 0 || squadUpdates.length > 0)) {
      console.error('All stories have already been reported. Skipping digest creation.');
      process.exit(0);
    }
    
    const digest = formatDigest(newStories, newSquadUpdates);
    const publicDigest = formatDigest(newStories, newSquadUpdates, { isPublic: true });
    console.log(digest);
    
    // Post full digest to private webhook channel (includes issue links, repo refs)
    await postToTeamsWebhook(digest);
    
    // Post to both dedicated Teams channels via Graph API:
    //   - squads > Tech News          (full content, private)
    //   - Squad > Squad Tech News     (sanitized, public)
    await postToBothTeamsChannels(digest, publicDigest);
    
    // Update state with new URLs
    if (!state.reportedUrls[todayDate]) {
      state.reportedUrls[todayDate] = {};
    }
    [...newStories, ...newSquadUpdates].forEach(item => {
      state.reportedUrls[todayDate][item.url] = true;
    });
    state.lastScanDate = todayDate;
    saveState(state);
    
    console.error('Tech news scan completed successfully!');
  } catch (error) {
    console.error('Error during scan:', error);
    process.exit(1);
  }
}

main();
