#!/usr/bin/env node

/**
 * Eyal Links Monitor
 * Monitors Eyal's shared links in the Cloud-Dev-and-Architecture Google Group
 * Extracts content, summarizes, and captures learning for Squad's knowledge management
 * 
 * Flow:
 * 1. Fetch recent posts from Google Group RSS/API
 * 2. Filter for Eyal's posts
 * 3. Extract linked URLs
 * 4. Fetch and summarize content from each link
 * 5. Store in knowledge base with relevance tagging
 * 6. Post digest to Teams channel
 * 
 * State tracking: .squad/monitoring/eyal-links-state.json
 * Knowledge storage: .squad/knowledge/eyal-links/
 */

import https from 'https';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const REPO_ROOT = execSync('git rev-parse --show-toplevel', { encoding: 'utf-8' }).trim();

const CONFIG = {
  googleGroupUrl: 'https://groups.google.com/forum/feed/Cloud-Dev-and-Architecture/msgs/atom.xml?num=50',
  stateFile: path.join(REPO_ROOT, '.squad/monitoring/eyal-links-state.json'),
  knowledgeDir: path.join(REPO_ROOT, '.squad/knowledge/eyal-links'),
  teamsWebhookPath: path.join(process.env.HOME || process.env.USERPROFILE, '.squad-monitor/webhooks/tech-news.url'),
  checkInterval: 3600000, // 1 hour
  eyalIdentifiers: ['eyal', 'eyald', 'dresher.eyal'],
};

// ─── State Management ─────────────────────────────────────────────────────────

function loadState() {
  try {
    if (fs.existsSync(CONFIG.stateFile)) {
      return JSON.parse(fs.readFileSync(CONFIG.stateFile, 'utf-8'));
    }
  } catch (err) {
    console.error('Error loading state:', err.message);
  }
  return {
    lastCheck: null,
    processedPosts: [],
    processedUrls: [],
  };
}

function saveState(state) {
  const dir = path.dirname(CONFIG.stateFile);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(CONFIG.stateFile, JSON.stringify(state, null, 2));
}

// ─── Google Group Fetching ────────────────────────────────────────────────────

async function fetchGoogleGroupFeed() {
  return new Promise((resolve, reject) => {
    https.get(CONFIG.googleGroupUrl, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(data);
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    }).on('error', reject);
  });
}

function parseAtomFeed(xml) {
  const posts = [];
  const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
  let match;

  while ((match = entryRegex.exec(xml)) !== null) {
    const entry = match[1];
    
    const titleMatch = /<title[^>]*>(.*?)<\/title>/s.exec(entry);
    const authorMatch = /<name>(.*?)<\/name>/s.exec(entry);
    const contentMatch = /<content[^>]*>(.*?)<\/content>/s.exec(entry);
    const linkMatch = /<link[^>]*href=["']([^"']+)["']/s.exec(entry);
    const publishedMatch = /<published>(.*?)<\/published>/s.exec(entry);

    if (titleMatch && authorMatch) {
      posts.push({
        title: decodeHtml(titleMatch[1]),
        author: decodeHtml(authorMatch[1]),
        content: contentMatch ? decodeHtml(contentMatch[1]) : '',
        url: linkMatch ? linkMatch[1] : '',
        published: publishedMatch ? publishedMatch[1] : new Date().toISOString(),
      });
    }
  }

  return posts;
}

function decodeHtml(text) {
  return text
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/<[^>]+>/g, '') // Strip HTML tags
    .trim();
}

function isEyalPost(post) {
  const author = post.author.toLowerCase();
  return CONFIG.eyalIdentifiers.some(id => author.includes(id));
}

function extractUrls(content) {
  const urlRegex = /https?:\/\/[^\s<>"']+/g;
  const matches = content.match(urlRegex) || [];
  // Filter out Google Group internal URLs
  return matches.filter(url => !url.includes('groups.google.com'));
}

// ─── Content Fetching & Summarization ─────────────────────────────────────────

async function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    const options = {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Squad Monitor Bot)',
      },
    };

    client.get(url, options, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        // Follow redirect
        return fetchUrl(res.headers.location).then(resolve).catch(reject);
      }

      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: data });
      });
    }).on('error', reject);
  });
}

function extractMetadata(html, url) {
  const titleMatch = /<title[^>]*>(.*?)<\/title>/is.exec(html);
  const descMatch = /<meta[^>]*name=["']description["'][^>]*content=["']([^"']+)["']/i.exec(html);
  const ogTitleMatch = /<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']/i.exec(html);
  const ogDescMatch = /<meta[^>]*property=["']og:description["'][^>]*content=["']([^"']+)["']/i.exec(html);

  return {
    url,
    title: decodeHtml(ogTitleMatch?.[1] || titleMatch?.[1] || 'No title'),
    description: decodeHtml(ogDescMatch?.[1] || descMatch?.[1] || ''),
    contentPreview: extractTextPreview(html, 500),
  };
}

function extractTextPreview(html, maxLength) {
  // Strip scripts, styles, and HTML tags
  let text = html
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  
  if (text.length > maxLength) {
    text = text.substring(0, maxLength) + '...';
  }
  return text;
}

function scoreRelevance(metadata) {
  const text = `${metadata.title} ${metadata.description} ${metadata.contentPreview}`.toLowerCase();
  
  const highKeywords = [
    'kubernetes', 'k8s', 'azure', 'aks', 'cloud', 'architecture', 'distributed systems',
    '.net', 'dotnet', 'c#', 'microservices', 'devops', 'ci/cd', 'observability',
    'ai', 'machine learning', 'copilot', 'github', 'security', 'reliability',
  ];

  const matches = highKeywords.filter(kw => text.includes(kw));
  
  if (matches.length >= 3) return 'HIGH';
  if (matches.length >= 1) return 'MEDIUM';
  return 'LOW';
}

// ─── Knowledge Storage ────────────────────────────────────────────────────────

function saveToKnowledgeBase(post, links) {
  if (!fs.existsSync(CONFIG.knowledgeDir)) {
    fs.mkdirSync(CONFIG.knowledgeDir, { recursive: true });
  }

  const timestamp = new Date().toISOString().split('T')[0];
  const filename = `${timestamp}-${sanitizeFilename(post.title)}.md`;
  const filepath = path.join(CONFIG.knowledgeDir, filename);

  const content = `# ${post.title}

**Author:** ${post.author}  
**Published:** ${post.published}  
**Source:** ${post.url}

## Original Post

${post.content}

## Shared Links

${links.map(link => `
### ${link.title}

**URL:** ${link.url}  
**Relevance:** ${link.relevance}

${link.description}

**Preview:**
${link.contentPreview}

`).join('\n---\n')}

## Captured On

${new Date().toISOString()}
`;

  fs.writeFileSync(filepath, content);
  console.log(`✅ Saved to knowledge base: ${filename}`);
}

function sanitizeFilename(str) {
  return str
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .substring(0, 50);
}

// ─── Teams Notification ───────────────────────────────────────────────────────

function getTeamsWebhookUrl() {
  try {
    if (fs.existsSync(CONFIG.teamsWebhookPath)) {
      return fs.readFileSync(CONFIG.teamsWebhookPath, 'utf-8').trim();
    }
  } catch (err) {
    console.error('Error reading Teams webhook URL:', err.message);
  }
  return null;
}

async function postToTeams(post, links) {
  const webhookUrl = getTeamsWebhookUrl();
  if (!webhookUrl) {
    console.log('⚠️ Teams webhook not configured, skipping notification');
    return;
  }

  const highLinks = links.filter(l => l.relevance === 'HIGH');
  const mediumLinks = links.filter(l => l.relevance === 'MEDIUM');

  const message = {
    "@type": "MessageCard",
    "@context": "https://schema.org/extensions",
    "summary": `Eyal shared ${links.length} link(s)`,
    "themeColor": "0078D7",
    "title": `📚 Eyal's Latest Links: ${post.title}`,
    "sections": [
      {
        "activityTitle": `Posted by ${post.author}`,
        "activitySubtitle": new Date(post.published).toLocaleString(),
        "text": post.content.substring(0, 200) + (post.content.length > 200 ? '...' : ''),
      },
      highLinks.length > 0 ? {
        "title": `🔥 High Relevance (${highLinks.length})`,
        "facts": highLinks.map(link => ({
          name: link.title.substring(0, 80),
          value: `[Link](${link.url}) - ${link.description.substring(0, 100)}`,
        })),
      } : null,
      mediumLinks.length > 0 ? {
        "title": `📖 Medium Relevance (${mediumLinks.length})`,
        "facts": mediumLinks.slice(0, 3).map(link => ({
          name: link.title.substring(0, 80),
          value: `[Link](${link.url})`,
        })),
      } : null,
    ].filter(Boolean),
    "potentialAction": [
      {
        "@type": "OpenUri",
        "name": "View Original Post",
        "targets": [{ "os": "default", "uri": post.url }],
      },
    ],
  };

  return new Promise((resolve, reject) => {
    const url = new URL(webhookUrl);
    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('✅ Posted to Teams');
          resolve();
        } else {
          console.error(`⚠️ Teams notification failed: HTTP ${res.statusCode}`);
          reject(new Error(`HTTP ${res.statusCode}`));
        }
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(message));
    req.end();
  });
}

// ─── Main Logic ───────────────────────────────────────────────────────────────

async function processNewPosts() {
  console.log('🔍 Checking for new posts from Eyal...');

  const state = loadState();
  
  try {
    // Fetch Google Group feed
    const feedXml = await fetchGoogleGroupFeed();
    const allPosts = parseAtomFeed(feedXml);
    
    // Filter for Eyal's posts
    const eyalPosts = allPosts.filter(isEyalPost);
    console.log(`Found ${eyalPosts.length} posts from Eyal`);

    // Process only new posts
    const newPosts = eyalPosts.filter(post => !state.processedPosts.includes(post.url));
    console.log(`${newPosts.length} new posts to process`);

    for (const post of newPosts) {
      console.log(`\n📬 Processing: ${post.title}`);
      
      // Extract URLs from post content
      const urls = extractUrls(post.content + ' ' + post.title);
      console.log(`Found ${urls.length} URLs`);

      // Fetch and analyze each URL
      const links = [];
      for (const url of urls) {
        if (state.processedUrls.includes(url)) {
          console.log(`  ⏭️  Already processed: ${url}`);
          continue;
        }

        try {
          console.log(`  📥 Fetching: ${url}`);
          const response = await fetchUrl(url);
          
          if (response.statusCode === 200) {
            const metadata = extractMetadata(response.body, url);
            metadata.relevance = scoreRelevance(metadata);
            links.push(metadata);
            state.processedUrls.push(url);
            console.log(`  ✅ ${metadata.relevance}: ${metadata.title}`);
          } else {
            console.log(`  ⚠️  HTTP ${response.statusCode}, skipping`);
          }
        } catch (err) {
          console.error(`  ❌ Error fetching ${url}:`, err.message);
        }

        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000));
      }

      if (links.length > 0) {
        // Save to knowledge base
        saveToKnowledgeBase(post, links);

        // Post to Teams
        try {
          await postToTeams(post, links);
        } catch (err) {
          console.error('Teams notification error:', err.message);
        }
      }

      state.processedPosts.push(post.url);
    }

    state.lastCheck = new Date().toISOString();
    saveState(state);

    console.log('\n✅ Monitoring cycle complete');
  } catch (err) {
    console.error('❌ Error during monitoring:', err.message);
    throw err;
  }
}

// ─── Continuous Mode ──────────────────────────────────────────────────────────

async function continuousMonitor() {
  console.log('🚀 Starting continuous monitoring of Eyal\'s shared links');
  console.log(`Check interval: ${CONFIG.checkInterval / 1000}s`);

  while (true) {
    try {
      await processNewPosts();
    } catch (err) {
      console.error('Monitoring error:', err);
    }

    console.log(`\n⏰ Next check in ${CONFIG.checkInterval / 60000} minutes...\n`);
    await new Promise(resolve => setTimeout(resolve, CONFIG.checkInterval));
  }
}

// ─── CLI Entry Point ──────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const mode = args[0] || 'once';

if (mode === 'continuous') {
  continuousMonitor().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
} else {
  processNewPosts()
    .then(() => {
      console.log('Done.');
      process.exit(0);
    })
    .catch(err => {
      console.error('Fatal error:', err);
      process.exit(1);
    });
}
