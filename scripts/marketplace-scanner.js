#!/usr/bin/env node

/**
 * AI Marketplace Scanner
 * Monitors https://aka.ms/ai/marketplace for new tools/offerings
 * Issue #283
 */

import { readFile, writeFile } from 'fs/promises';
import { existsSync } from 'fs';
import { execSync } from 'child_process';

const CACHE_FILE = '.squad/marketplace-cache.json';
const MARKETPLACE_URL = 'https://aka.ms/ai/marketplace';

async function fetchMarketplaceContent() {
  try {
    // Use curl to follow redirects and get final content
    console.log('Fetching marketplace content...');
    const content = execSync(
      `curl -sL "${MARKETPLACE_URL}"`,
      { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }
    );
    
    // Check if page requires authentication
    if (content.includes('single sign-on') || content.includes('Sign in') || content.includes('authenticate')) {
      console.warn('⚠️  Marketplace page requires authentication');
      console.warn('    Using alternate method: GitHub Marketplace API');
      return await fetchGitHubMarketplace();
    }
    
    // Extract tool/app listings from HTML
    // Look for common patterns: headings, links, product names
    const listings = [];
    
    // Extract h1, h2, h3 headings
    const headingMatches = content.matchAll(/<h[123][^>]*>(.*?)<\/h[123]>/gi);
    for (const match of headingMatches) {
      const text = match[1].replace(/<[^>]+>/g, '').trim();
      if (text && text.length > 3 && text.length < 200) {
        listings.push({ type: 'heading', text });
      }
    }
    
    // Extract links that might be tools/products
    const linkMatches = content.matchAll(/<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)<\/a>/gi);
    for (const match of linkMatches) {
      const href = match[1];
      const text = match[2].replace(/<[^>]+>/g, '').trim();
      if (text && text.length > 3 && text.length < 200 && 
          (href.includes('marketplace') || href.includes('app') || href.includes('tool'))) {
        listings.push({ type: 'link', text, href });
      }
    }
    
    // Create a fingerprint of the page for comparison
    const fingerprint = {
      timestamp: new Date().toISOString(),
      url: MARKETPLACE_URL,
      itemCount: listings.length,
      listings: listings.slice(0, 50), // Keep first 50 items
      contentHash: createSimpleHash(content)
    };
    
    return fingerprint;
  } catch (error) {
    console.error('Error fetching marketplace:', error.message);
    return null;
  }
}

async function fetchGitHubMarketplace() {
  try {
    // Fetch GitHub Marketplace apps (AI-related)
    const categories = ['ai', 'machine-learning', 'code-quality', 'copilot'];
    const listings = [];
    
    for (const category of categories) {
      try {
        const result = execSync(
          `gh api "search/repositories?q=topic:${category}+topic:marketplace&per_page=10&sort=updated"`,
          { encoding: 'utf8' }
        );
        const data = JSON.parse(result);
        
        if (data.items) {
          data.items.forEach(item => {
            listings.push({
              type: 'repo',
              text: item.name,
              description: item.description || '',
              href: item.html_url,
              stars: item.stargazers_count,
              updated: item.updated_at
            });
          });
        }
      } catch (err) {
        console.warn(`Could not fetch category ${category}:`, err.message);
      }
    }
    
    // Also try to get GitHub Apps/Actions
    try {
      const actionsResult = execSync(
        `gh api "search/repositories?q=github-action+ai+OR+copilot&per_page=20&sort=updated"`,
        { encoding: 'utf8' }
      );
      const actionsData = JSON.parse(actionsResult);
      
      if (actionsData.items) {
        actionsData.items.slice(0, 10).forEach(item => {
          listings.push({
            type: 'action',
            text: item.name,
            description: item.description || '',
            href: item.html_url,
            stars: item.stargazers_count,
            updated: item.updated_at
          });
        });
      }
    } catch (err) {
      console.warn('Could not fetch GitHub Actions:', err.message);
    }
    
    // Deduplicate by URL
    const uniqueListings = [];
    const seenUrls = new Set();
    for (const item of listings) {
      if (!seenUrls.has(item.href)) {
        seenUrls.add(item.href);
        uniqueListings.push(item);
      }
    }
    
    return {
      timestamp: new Date().toISOString(),
      url: 'GitHub Marketplace (AI/ML tools)',
      itemCount: uniqueListings.length,
      listings: uniqueListings.slice(0, 50),
      contentHash: createSimpleHash(JSON.stringify(uniqueListings))
    };
  } catch (error) {
    console.error('Error fetching GitHub Marketplace:', error.message);
    return null;
  }
}

function createSimpleHash(str) {
  let hash = 0;
  for (let i = 0; i < Math.min(str.length, 10000); i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return hash.toString(36);
}

async function loadCache() {
  if (!existsSync(CACHE_FILE)) {
    return null;
  }
  try {
    const data = await readFile(CACHE_FILE, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error loading cache:', error.message);
    return null;
  }
}

async function saveCache(data) {
  try {
    await writeFile(CACHE_FILE, JSON.stringify(data, null, 2), 'utf8');
    console.log('Cache updated');
  } catch (error) {
    console.error('Error saving cache:', error.message);
  }
}

function compareFingerprints(oldData, newData) {
  if (!oldData) return { hasChanges: true, newItems: newData.listings };
  
  const oldHash = oldData.contentHash;
  const newHash = newData.contentHash;
  
  if (oldHash === newHash) {
    return { hasChanges: false, newItems: [] };
  }
  
  // Find new listings
  const oldTexts = new Set(oldData.listings.map(l => l.text.toLowerCase()));
  const newItems = newData.listings.filter(l => !oldTexts.has(l.text.toLowerCase()));
  
  return {
    hasChanges: true,
    newItems,
    removedCount: oldData.itemCount - newData.itemCount
  };
}

async function createGitHubIssue(changes, newData) {
  const date = new Date().toISOString().split('T')[0];
  const title = `AI Marketplace Update: ${date}`;
  
  let body = `# AI Marketplace Changes Detected\n\n`;
  body += `Scanned: ${MARKETPLACE_URL}\n`;
  body += `Timestamp: ${newData.timestamp}\n\n`;
  
  if (changes.newItems.length > 0) {
    body += `## New Items (${changes.newItems.length})\n\n`;
    changes.newItems.slice(0, 20).forEach(item => {
      if (item.href) {
        body += `- [${item.text}](${item.href})`;
        if (item.description) {
          body += ` - ${item.description.substring(0, 100)}`;
        }
        if (item.stars) {
          body += ` ⭐${item.stars}`;
        }
        body += '\n';
      } else {
        body += `- ${item.text}\n`;
      }
    });
    if (changes.newItems.length > 20) {
      body += `\n_...and ${changes.newItems.length - 20} more items_\n`;
    }
  }
  
  body += `\n## Summary\n`;
  body += `- Total items found: ${newData.itemCount}\n`;
  body += `- Previous count: ${changes.removedCount !== undefined ? newData.itemCount - changes.removedCount : 'N/A'}\n`;
  body += `\n---\n_Auto-generated by marketplace-scanner (Issue #283)_`;
  
  try {
    console.log('Creating GitHub issue...');
    const result = execSync(
      `gh issue create --title "${title}" --body "${body.replace(/"/g, '\\"')}" --label "squad,squad:seven" --repo tamirdresher_microsoft/tamresearch1`,
      { encoding: 'utf8' }
    );
    console.log('Issue created:', result.trim());
    return true;
  } catch (error) {
    console.error('Error creating issue:', error.message);
    return false;
  }
}

async function main() {
  console.log('=== AI Marketplace Scanner ===');
  console.log(`Checking: ${MARKETPLACE_URL}\n`);
  
  const newData = await fetchMarketplaceContent();
  if (!newData) {
    console.error('Failed to fetch marketplace content');
    process.exit(1);
  }
  
  console.log(`Found ${newData.itemCount} items\n`);
  
  const oldData = await loadCache();
  const changes = compareFingerprints(oldData, newData);
  
  if (!changes.hasChanges) {
    console.log('✓ No new marketplace items');
    process.exit(0);
  }
  
  console.log(`✓ Changes detected: ${changes.newItems.length} new items`);
  
  await saveCache(newData);
  
  // Create issue if running in GitHub Actions
  if (process.env.GITHUB_ACTIONS) {
    await createGitHubIssue(changes, newData);
  } else {
    console.log('\nNew items:');
    changes.newItems.slice(0, 10).forEach(item => {
      console.log(`  - ${item.text}`);
    });
    console.log('\n(Run in GitHub Actions to create issue)');
  }
  
  process.exit(0);
}

main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
