#!/usr/bin/env node
// scripts/notify.js — Multi-channel notification router for Squad
// Zero external dependencies. Routes messages to channels based on content tags.

import fs from 'node:fs';
import path from 'node:path';
import https from 'node:https';
import http from 'node:http';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ---------------------------------------------------------------------------
// Config loading
// ---------------------------------------------------------------------------

const DEFAULT_CONFIG_PATH = path.join(__dirname, '..', '.squad', 'notification-routes.json');

function loadConfig(configPath) {
  const raw = fs.readFileSync(configPath, 'utf8');
  return JSON.parse(raw);
}

function resolveEnvVars(str) {
  if (typeof str !== 'string') return str;
  return str.replace(/\$\{([^}]+)\}/g, (_, varName) => process.env[varName] || '');
}

// ---------------------------------------------------------------------------
// Channel resolution
// ---------------------------------------------------------------------------

/**
 * Parse an explicit "CHANNEL: <key>" prefix from the message.
 * Returns { channelKey, body } where body is the message without the tag.
 */
function parseChannelTag(message) {
  const match = message.match(/^CHANNEL:\s*(\S+)\s*([\s\S]*)$/);
  if (match) {
    return { channelKey: match[1].toLowerCase(), body: match[2].trim() };
  }
  return { channelKey: null, body: message.trim() };
}

/**
 * Auto-detect channel from message content using keyword routing rules.
 */
function detectChannel(body, routingRules) {
  if (!routingRules) return null;
  const lowerBody = body.toLowerCase();
  for (const [channel, keywords] of Object.entries(routingRules)) {
    for (const kw of keywords) {
      if (lowerBody.includes(kw.toLowerCase())) {
        return channel;
      }
    }
  }
  return null;
}

function resolveChannel(message, config) {
  const { channelKey, body } = parseChannelTag(message);

  // Explicit tag takes priority
  if (channelKey && config.channels[channelKey]) {
    return { channel: channelKey, body };
  }

  // Auto-detect from routing keywords
  const detected = detectChannel(body || message, config.routing);
  if (detected && config.channels[detected]) {
    return { channel: detected, body: body || message.trim() };
  }

  // Fall back to default
  return { channel: config.defaultChannel, body: body || message.trim() };
}

// ---------------------------------------------------------------------------
// Message formatting (Teams-compatible markdown)
// ---------------------------------------------------------------------------

function formatForTeams(body, channelName) {
  const timestamp = new Date().toISOString().replace('T', ' ').slice(0, 19) + ' UTC';
  const lines = [
    `**📢 Squad Notification** → *${channelName}*`,
    '',
    body,
    '',
    `---`,
    `_Routed at ${timestamp}_`,
  ];
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

function sendConsole(formatted, channelName) {
  console.log(`[${channelName}] ${formatted}`);
  return Promise.resolve({ ok: true, provider: 'console' });
}

function sendWebhook(formatted, webhookUrl) {
  return new Promise((resolve, reject) => {
    const url = resolveEnvVars(webhookUrl);
    if (!url) {
      return reject(new Error('Webhook URL is empty after env var substitution'));
    }

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
            text: formatted,
            wrap: true,
          }],
        },
      }],
    });

    const parsedUrl = new URL(url);
    const transport = parsedUrl.protocol === 'https:' ? https : http;

    const req = transport.request(parsedUrl, {
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
          resolve({ ok: true, provider: 'webhook', status: res.statusCode });
        } else {
          reject(new Error(`Webhook returned ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

function sendTeamsMcp(formatted, channelDef) {
  // Output a command string that a Teams MCP tool can consume
  const cmd = {
    action: 'teams-post-channel-message',
    channelId: channelDef.channelId || null,
    teamId: channelDef.teamId || null,
    content: formatted,
    contentType: 'html',
  };
  console.log(JSON.stringify(cmd));
  return Promise.resolve({ ok: true, provider: 'teams-mcp' });
}

// ---------------------------------------------------------------------------
// Main dispatch
// ---------------------------------------------------------------------------

async function dispatch(message, config, providerOverride) {
  const { channel, body } = resolveChannel(message, config);
  const channelDef = config.channels[channel];
  const channelName = channelDef.name || channel;
  const provider = providerOverride || config.provider || 'console';

  const formatted = formatForTeams(body, channelName);

  try {
    switch (provider) {
      case 'webhook': {
        const webhookUrl = channelDef.webhookUrl;
        return await sendWebhook(formatted, webhookUrl);
      }
      case 'teams-mcp':
        return await sendTeamsMcp(formatted, channelDef);
      case 'console':
        return await sendConsole(formatted, channelName);
      default:
        console.error(`Unknown provider "${provider}", falling back to console`);
        return await sendConsole(formatted, channelName);
    }
  } catch (err) {
    // Graceful degradation: fall back to console on webhook failure
    if (provider !== 'console') {
      console.error(`Provider "${provider}" failed: ${err.message}. Falling back to console.`);
      return await sendConsole(formatted, channelName);
    }
    throw err;
  }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { message: null, provider: null, config: null };
  for (let i = 2; i < argv.length; i++) {
    if ((argv[i] === '--message' || argv[i] === '-m') && argv[i + 1]) {
      args.message = argv[++i];
    } else if ((argv[i] === '--provider' || argv[i] === '-p') && argv[i + 1]) {
      args.provider = argv[++i];
    } else if ((argv[i] === '--config' || argv[i] === '-c') && argv[i + 1]) {
      args.config = argv[++i];
    } else if (argv[i] === '--help' || argv[i] === '-h') {
      console.log(`
Usage: notify.js [options]

Options:
  --message, -m <text>    Message to send (reads stdin if omitted)
  --provider, -p <type>   Provider: webhook | teams-mcp | console (default: from config)
  --config, -c <path>     Path to notification-routes.json
  --help, -h              Show this help

Message format:
  Prefix with "CHANNEL: <key>" to target a specific channel.
  Example: "CHANNEL: wins 🎉 PR #42 merged!"

  Without a tag, keyword-based routing is used. If no match, the
  default channel from the config is used.
`);
      process.exit(0);
    }
  }
  return args;
}

function readStdin() {
  return new Promise((resolve) => {
    if (process.stdin.isTTY) {
      return resolve(null);
    }
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data.trim() || null));
  });
}

async function main() {
  const args = parseArgs(process.argv);

  // Load config
  const configPath = args.config || DEFAULT_CONFIG_PATH;
  let config;
  try {
    config = loadConfig(configPath);
  } catch (err) {
    console.error(`Failed to load config from ${configPath}: ${err.message}`);
    process.exit(1);
  }

  // Get message from --message flag or stdin
  let message = args.message;
  if (!message) {
    message = await readStdin();
  }
  if (!message) {
    console.error('No message provided. Use --message or pipe via stdin.');
    process.exit(1);
  }

  try {
    const result = await dispatch(message, config, args.provider);
    if (result.ok) {
      process.exit(0);
    }
  } catch (err) {
    console.error(`Notification failed: ${err.message}`);
    process.exit(1);
  }
}

// ESM entry point detection
const isMain = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(__filename);
if (isMain) {
  main();
}

export { loadConfig, parseChannelTag, detectChannel, resolveChannel, formatForTeams, dispatch };
