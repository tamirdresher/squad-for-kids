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
import { execSync } from 'child_process';

const KEYWORDS = [
  'ai', 'artificial intelligence', 'machine learning', 'ml', 'llm', 'gpt', 'copilot',
  'vibecoding', 'vibe coding',
  '.net', 'dotnet', 'c#', 'csharp', 'aspnet', 'blazor',
  'golang', 'go lang',
  'kubernetes', 'k8s', 'cloud native', 'cncf',
  'developer tools', 'devtools', 'ide', 'vscode', 'github',
  'architecture',
  'tech radar', 'thoughtworks',
  'squad'
];

// Brady's Squad repo monitoring config
const SQUAD_REPO = { owner: 'bradygaster', repo: 'squad' };
const BRADY_BLOG_URL = 'https://bradygaster.com';

// Teams channel targets for posting digests
const TEAMS_CHANNELS = [
  { teamId: '5f93abfe-b968-44ea-bd0a-6f155046ccc7', channelId: '19:bfe3224e8e764c2785e81e7cb3cc944d@thread.tacv2', label: 'squads > Tech News' },
  { teamId: '1de78cdf-3f73-4447-9601-a940bd98b80d', channelId: '19:c940af255e22486882c069d7b38a6204@thread.tacv2', label: 'Squad > Squad Tech News' }
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
    const output = execSync(
      `gh issue list --state all --search "${searchTerm}" --json number,title`,
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
    const output = execSync(
      `gh api repos/${SQUAD_REPO.owner}/${SQUAD_REPO.repo}/releases --jq ".[0:10]" 2>/dev/null || echo "[]"`,
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
    const output = execSync(
      `gh api graphql -f query='${query.replace(/'/g, "'\\''")}'`,
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
    const output = execSync(
      `gh api "repos/${SQUAD_REPO.owner}/${SQUAD_REPO.repo}/commits?since=${since}&per_page=10" 2>/dev/null || echo "[]"`,
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

async function scanAllSources() {
  const subreddits = ['programming', 'webdev', 'dotnet', 'golang', 'artificial', 'MachineLearning', 'BlackboxAI_'];
  
  const [hnStories, morningDew, archNotes, twRadar, squadReleases, squadDiscussions, squadCommits, bradyBlog, ...redditResults] = await Promise.all([
    fetchHackerNews(),
    fetchMorningDew(),
    fetchArchitectureNotes(),
    fetchThoughtWorksRadar(),
    fetchSquadReleases(),
    fetchSquadDiscussions(),
    fetchSquadCommits(),
    fetchBradyBlog(),
    ...subreddits.map(sub => fetchReddit(sub))
  ]);
  
  const allStories = [...hnStories, ...morningDew, ...archNotes, ...twRadar, ...redditResults.flat()];
  const squadUpdates = [...squadReleases, ...squadDiscussions, ...squadCommits, ...bradyBlog];
  
  // Sort by score descending
  allStories.sort((a, b) => b.score - a.score);
  squadUpdates.sort((a, b) => b.score - a.score);
  
  return { stories: allStories, squadUpdates };
}

function formatDigest(stories, squadUpdates = []) {
  const date = new Date().toISOString().split('T')[0];
  
  let digest = `# Tech News Digest - ${date}\n\n`;
  digest += `Found ${stories.length} relevant stories across HackerNews, Reddit, Morning Dew, Architecture Notes, and ThoughtWorks Radar.\n\n`;
  digest += `**Topics covered:** AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools\n\n`;

  // Squad product updates section
  if (squadUpdates.length > 0) {
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
  
  if (stories.length === 0 && squadUpdates.length === 0) {
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
  
  return digest;
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
    console.log(digest);
    
    // Log Teams channel targets for posting
    console.error('Digest should be posted to the following Teams channels:');
    for (const ch of TEAMS_CHANNELS) {
      console.error(`  - ${ch.label} (team: ${ch.teamId}, channel: ${ch.channelId})`);
    }
    
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
