#!/usr/bin/env node

/**
 * Tech News Scanner
 * Scans HackerNews and Reddit for relevant tech stories
 * Filters by topics: AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools
 */

import https from 'https';

const KEYWORDS = [
  'ai', 'artificial intelligence', 'machine learning', 'ml', 'llm', 'gpt', 'copilot',
  'vibecoding', 'vibe coding',
  '.net', 'dotnet', 'c#', 'csharp', 'aspnet', 'blazor',
  'golang', 'go lang',
  'kubernetes', 'k8s', 'cloud native', 'cncf',
  'developer tools', 'devtools', 'ide', 'vscode', 'github'
];

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

async function scanAllSources() {
  const subreddits = ['programming', 'webdev', 'dotnet', 'golang', 'artificial', 'MachineLearning'];
  
  const [hnStories, ...redditResults] = await Promise.all([
    fetchHackerNews(),
    ...subreddits.map(sub => fetchReddit(sub))
  ]);
  
  const allStories = [...hnStories, ...redditResults.flat()];
  
  // Sort by score descending
  allStories.sort((a, b) => b.score - a.score);
  
  return allStories;
}

function formatDigest(stories) {
  const date = new Date().toISOString().split('T')[0];
  
  let digest = `# Tech News Digest - ${date}\n\n`;
  digest += `Found ${stories.length} relevant stories across HackerNews and Reddit.\n\n`;
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
    console.error('Starting tech news scan...');
    const stories = await scanAllSources();
    const digest = formatDigest(stories);
    console.log(digest);
    console.error('Tech news scan completed successfully!');
  } catch (error) {
    console.error('Error during scan:', error);
    process.exit(1);
  }
}

main();
