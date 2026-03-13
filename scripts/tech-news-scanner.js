#!/usr/bin/env node

/**
 * Tech News Scanner
 * Scans HackerNews, Reddit, and Morning Dew (alvinashcraft.com) for relevant tech stories
 * Filters by topics: AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools
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
  'developer tools', 'devtools', 'ide', 'vscode', 'github'
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
    const searchTerm = `Tech News Digest: ${date}`;
    const output = execSync(
      `gh issue list --state all --search "${searchTerm}" --json number --jq length`,
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();
    const count = parseInt(output, 10);
    return count > 0;
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

async function scanAllSources() {
  const subreddits = ['programming', 'webdev', 'dotnet', 'golang', 'artificial', 'MachineLearning', 'BlackboxAI_'];
  
  const [hnStories, morningDew, ...redditResults] = await Promise.all([
    fetchHackerNews(),
    fetchMorningDew(),
    ...subreddits.map(sub => fetchReddit(sub))
  ]);
  
  const allStories = [...hnStories, ...morningDew, ...redditResults.flat()];
  
  // Sort by score descending
  allStories.sort((a, b) => b.score - a.score);
  
  return allStories;
}

function formatDigest(stories) {
  const date = new Date().toISOString().split('T')[0];
  
  let digest = `# Tech News Digest - ${date}\n\n`;
  digest += `Found ${stories.length} relevant stories across HackerNews, Reddit, and Morning Dew.\n\n`;
  digest += `**Topics covered:** AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools\n\n`;
  digest += `---\n\n`;
  
  if (stories.length === 0) {
    digest += `No relevant stories found today.\n`;
    return digest;
  }
  
  stories.forEach((story, idx) => {
    digest += `## ${idx + 1}. ${story.title}\n\n`;
    digest += `- **Source:** ${story.source}\n`;
    digest += `- **Score:** ${story.score}\n`;
    digest += `- **Link:** ${story.url}\n\n`;
  });
  
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
    
    const stories = await scanAllSources();
    
    // Filter out URLs that have already been reported
    const reportedUrlsForDate = state.reportedUrls[todayDate] || {};
    const newStories = stories.filter(story => !reportedUrlsForDate[story.url]);
    
    if (newStories.length === 0 && stories.length > 0) {
      console.error('All stories have already been reported. Skipping digest creation.');
      process.exit(0);
    }
    
    const digest = formatDigest(newStories);
    console.log(digest);
    
    // Update state with new URLs
    if (!state.reportedUrls[todayDate]) {
      state.reportedUrls[todayDate] = {};
    }
    newStories.forEach(story => {
      state.reportedUrls[todayDate][story.url] = true;
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
