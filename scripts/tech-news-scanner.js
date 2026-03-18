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
  
  let digest = `# Tech News Digest - ${date}\n\n`;
  digest += `Found ${stories.length} relevant stories across HackerNews, Reddit, Morning Dew, Architecture Notes, ThoughtWorks Radar, and AWS Blogs.\n\n`;
  digest += `**Topics covered:** AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools, AWS architecture & announcements\n\n`;

  // Squad product updates section — only include in private digests
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
  
  if (stories.length === 0 && (isPublic || squadUpdates.length === 0)) {
    digest += `No relevant stories found today.\n`;
    return digest;
  }

  if (stories.length > 0) {
    digest += `## 📰 Tech News\n\n`;
    stories.forEach((story, idx) => {
      digest += `### ${idx + 1}. ${story.title}\n\n`;
      digest += `- **Source:** ${story.source}\n`;
      digest += `- **Score:** ${story.score}\n`;
      digest += `- **Link:** ${story.url}\n\n`;
    });
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
    
    // Log public digest info for public channel posting
    console.error(`\nPublic digest (sanitized) available for Squad > Tech News channel.`);
    console.error(`Public channels strip: issue numbers, repo names, internal refs.`);
    console.error(`Private webhook gets: full content with all references.\n`);
    
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
