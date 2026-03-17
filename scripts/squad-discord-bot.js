#!/usr/bin/env node
/**
 * Squad Discord Bot — Mobile interface for your AI Squad.
 *
 * Listens for slash commands via Discord gateway (Socket Mode),
 * writes them to ~/.squad/mobile-inbox/,
 * watches ~/.squad/mobile-outbox/ for responses, and sends them back as rich embeds.
 *
 * Usage:
 *     node squad-discord-bot.js
 *     # or via start-discord-bot.ps1
 *
 * Token sources (checked in order):
 *     1. Environment variable DISCORD_BOT_TOKEN
 *     2. ~/.squad/discord-config.json  {"bot_token": "..."}
 *     3. Windows Credential Manager: squad-discord-bot
 *
 * Author: Data (Code Expert)
 */

import { Client, GatewayIntentBits, SlashCommandBuilder, REST, Routes,
         EmbedBuilder, ChannelType, PermissionFlagsBits } from 'discord.js';
import { readFileSync, writeFileSync, existsSync, mkdirSync, readdirSync,
         renameSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const SQUAD_DIR    = join(homedir(), '.squad');
const INBOX_DIR    = join(SQUAD_DIR, 'mobile-inbox');
const OUTBOX_DIR   = join(SQUAD_DIR, 'mobile-outbox');
const CONFIG_FILE  = join(SQUAD_DIR, 'discord-config.json');
const STATE_FILE   = join(SQUAD_DIR, 'discord-bot-state.json');
const LOG_FILE     = join(SQUAD_DIR, 'discord-bot.log');

const OUTBOX_POLL_MS   = 2000;   // 2s between outbox scans
const RATE_LIMIT_MS    = 5000;   // 5s cooldown between commands per user
const MAX_RESPONSE_LEN = 4000;   // Discord embed description limit

// Agent definitions — the squad roster
const AGENTS = {
    picard:  { name: 'Picard',   emoji: '🏗️', role: 'Lead — Architecture & Decisions',     color: 0xC0392B },
    data:    { name: 'Data',     emoji: '🔧', role: 'Code Expert — C#, Go, .NET',           color: 0x2980B9 },
    seven:   { name: 'Seven',    emoji: '📝', role: 'Research & Docs — Analysis',            color: 0x8E44AD },
    belanna: { name: "B'Elanna", emoji: '⚙️', role: 'Infrastructure — K8s, Helm, ArgoCD',   color: 0xE67E22 },
    worf:    { name: 'Worf',     emoji: '🔒', role: 'Security & Cloud — Azure, Networking',  color: 0x27AE60 },
};

// Allowed user IDs (empty set = allow all)
let ALLOWED_USER_IDS = new Set();

// Rate limiter state: userId → last command timestamp
const rateLimits = new Map();

// Pending messages: messageId → { channelId, threadId, timestamp }
const pending = new Map();

// ---------------------------------------------------------------------------
// Logging
// ---------------------------------------------------------------------------

function ensureDir(dir) {
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

import { appendFileSync } from 'node:fs';

function logInfo(...args)    { _log('INFO', ...args); }
function logWarn(...args)    { _log('WARN', ...args); }
function logError(...args)   { _log('ERROR', ...args); }

function _log(level, ...args) {
    const ts = new Date().toISOString();
    const msg = `${ts} [${level}] ${args.join(' ')}`;
    console.log(msg);
    try {
        ensureDir(SQUAD_DIR);
        appendFileSync(LOG_FILE, msg + '\n', 'utf-8');
    } catch { /* best-effort */ }
}

// ---------------------------------------------------------------------------
// Token resolution
// ---------------------------------------------------------------------------

function getConfig() {
    if (existsSync(CONFIG_FILE)) {
        try {
            return JSON.parse(readFileSync(CONFIG_FILE, 'utf-8'));
        } catch { /* fall through */ }
    }
    return {};
}

function getToken() {
    // 1. Environment variable
    const envToken = (process.env.DISCORD_BOT_TOKEN || '').trim();
    if (envToken) {
        logInfo('Token loaded from environment variable');
        return envToken;
    }

    // 2. Config file
    const cfg = getConfig();
    if (cfg.bot_token) {
        logInfo(`Token loaded from ${CONFIG_FILE}`);
        if (Array.isArray(cfg.allowed_user_ids)) {
            cfg.allowed_user_ids.forEach(id => ALLOWED_USER_IDS.add(String(id)));
        }
        return cfg.bot_token;
    }

    // 3. Windows Credential Manager
    if (process.platform === 'win32') {
        try {
            const ps = `(New-Object System.Net.NetworkCredential('', ` +
                `(Get-StoredCredential -Target 'squad-discord-bot').Password)).Password`;
            const result = execFileSync('powershell', ['-NoProfile', '-Command', ps],
                { encoding: 'utf-8', timeout: 5000 }).trim();
            if (result && !result.startsWith('Get-StoredCredential')) {
                logInfo('Token loaded from Windows Credential Manager');
                return result;
            }
        } catch { /* fall through */ }
    }

    return '';
}

function getAppId() {
    const cfg = getConfig();
    return (process.env.DISCORD_APP_ID || cfg.app_id || '').trim();
}

// ---------------------------------------------------------------------------
// Slash command definitions
// ---------------------------------------------------------------------------

function buildSlashCommands() {
    const commands = [];

    // Agent commands
    for (const [key, agent] of Object.entries(AGENTS)) {
        commands.push(
            new SlashCommandBuilder()
                .setName(key)
                .setDescription(`${agent.emoji} Ask ${agent.name} (${agent.role})`)
                .addStringOption(opt =>
                    opt.setName('message')
                        .setDescription('Your message to the agent')
                        .setRequired(true))
        );
    }

    // Utility commands
    commands.push(
        new SlashCommandBuilder()
            .setName('status')
            .setDescription('📊 Check Squad inbox/outbox status'),
        new SlashCommandBuilder()
            .setName('issues')
            .setDescription('🐛 List recent issues from the Squad queue'),
        new SlashCommandBuilder()
            .setName('help')
            .setDescription('❓ Show available Squad commands'),
    );

    return commands;
}

async function registerCommands(token, appId) {
    const rest = new REST({ version: '10' }).setToken(token);
    const commands = buildSlashCommands().map(c => c.toJSON());

    logInfo(`Registering ${commands.length} slash commands...`);
    try {
        await rest.put(Routes.applicationCommands(appId), { body: commands });
        logInfo('Slash commands registered globally.');
    } catch (err) {
        logError('Failed to register commands:', err.message);
        throw err;
    }
}

// ---------------------------------------------------------------------------
// Rate limiter
// ---------------------------------------------------------------------------

function checkRateLimit(userId) {
    const now = Date.now();
    const last = rateLimits.get(userId) || 0;
    if (now - last < RATE_LIMIT_MS) {
        const wait = Math.ceil((RATE_LIMIT_MS - (now - last)) / 1000);
        return { limited: true, waitSeconds: wait };
    }
    rateLimits.set(userId, now);
    return { limited: false, waitSeconds: 0 };
}

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

function isAuthorized(userId) {
    if (ALLOWED_USER_IDS.size === 0) return true;
    return ALLOWED_USER_IDS.has(String(userId));
}

// ---------------------------------------------------------------------------
// Inbox / Outbox
// ---------------------------------------------------------------------------

export function writeToInbox(source, channelId, messageId, user, text, agent) {
    ensureDir(INBOX_DIR);

    const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
    const hash = createHash('md5')
        .update(`${channelId}${messageId}`)
        .digest('hex')
        .slice(0, 6);
    const filename = `discord-${ts}_${hash}.json`;

    const payload = {
        source: 'discord',
        chat_id: channelId,
        message_id: String(messageId),
        user,
        text,
        agent: agent || null,
        timestamp: new Date().toISOString(),
        status: 'pending',
    };

    const filepath = join(INBOX_DIR, filename);
    writeFileSync(filepath, JSON.stringify(payload, null, 2), 'utf-8');
    logInfo(`Inbox: "${text.slice(0, 50)}" from ${user} → ${filename}`);
    return { filename, messageId: String(messageId) };
}

export function scanOutbox(client) {
    ensureDir(OUTBOX_DIR);

    let files;
    try {
        files = readdirSync(OUTBOX_DIR)
            .filter(f => f.endsWith('.json'))
            .sort();
    } catch {
        return;
    }

    for (const file of files) {
        const filepath = join(OUTBOX_DIR, file);
        try {
            const data = JSON.parse(readFileSync(filepath, 'utf-8'));

            // Only handle discord-sourced responses
            if (data.source && data.source !== 'discord') continue;

            const chatId = data.chat_id;
            const text = data.text || '';
            if (!chatId || !text) {
                logWarn(`Outbox file missing chat_id or text: ${file}`);
                continue;
            }

            sendResponse(client, chatId, text, data)
                .then(() => {
                    // Move to .sent
                    const sentPath = filepath.replace('.json', '.sent');
                    renameSync(filepath, sentPath);
                    logInfo(`Sent response for ${file}`);
                })
                .catch(err => {
                    logError(`Failed to send response for ${file}: ${err.message}`);
                });
        } catch (err) {
            logError(`Error processing outbox ${file}: ${err.message}`);
        }
    }
}

async function sendResponse(client, channelId, text, data) {
    try {
        const channel = await client.channels.fetch(channelId);
        if (!channel) {
            logWarn(`Channel ${channelId} not found`);
            return;
        }

        // Build rich embed
        const agentKey = data.agent || 'picard';
        const agent = AGENTS[agentKey] || AGENTS.picard;

        // Truncate if needed
        const content = text.length > MAX_RESPONSE_LEN
            ? text.slice(0, MAX_RESPONSE_LEN - 20) + '\n\n…(truncated)'
            : text;

        const embed = new EmbedBuilder()
            .setTitle(`${agent.emoji} ${agent.name}`)
            .setDescription(content)
            .setColor(agent.color)
            .setFooter({ text: `Squad Mobile • ${agent.role}` })
            .setTimestamp();

        await channel.send({ embeds: [embed] });
    } catch (err) {
        logError(`sendResponse error: ${err.message}`);
    }
}

// ---------------------------------------------------------------------------
// Help text
// ---------------------------------------------------------------------------

function buildHelpEmbed() {
    const agentLines = Object.entries(AGENTS)
        .map(([key, a]) => `\`/${key}\` — ${a.emoji} ${a.name}: ${a.role}`)
        .join('\n');

    return new EmbedBuilder()
        .setTitle('🤖 Squad Mobile Bot — Commands')
        .setDescription(
            `**Agent Commands**\n${agentLines}\n\n` +
            `**Utility Commands**\n` +
            `\`/status\` — 📊 Inbox/outbox status\n` +
            `\`/issues\` — 🐛 Recent Squad issues\n` +
            `\`/help\` — ❓ This help text\n\n` +
            `Each command creates a thread for the conversation.\n` +
            `Rate limit: one command per ${RATE_LIMIT_MS / 1000}s.`
        )
        .setColor(0x3498DB)
        .setFooter({ text: 'Squad Mobile • בוט הסקוואד לנייד' })
        .setTimestamp();
}

function buildStatusEmbed() {
    ensureDir(INBOX_DIR);
    ensureDir(OUTBOX_DIR);

    let inboxCount = 0;
    let outboxCount = 0;
    try {
        inboxCount = readdirSync(INBOX_DIR).filter(f => f.endsWith('.json')).length;
        outboxCount = readdirSync(OUTBOX_DIR).filter(f => f.endsWith('.json')).length;
    } catch { /* dirs may not exist yet */ }

    return new EmbedBuilder()
        .setTitle('📊 Squad Status')
        .addFields(
            { name: '📥 Pending inbox',  value: String(inboxCount),  inline: true },
            { name: '📤 Pending outbox', value: String(outboxCount), inline: true },
            { name: '⏰ Bot',            value: 'Running ✅',        inline: true },
        )
        .setColor(0x2ECC71)
        .setTimestamp();
}

// ---------------------------------------------------------------------------
// Interaction handler
// ---------------------------------------------------------------------------

async function handleInteraction(interaction) {
    if (!interaction.isChatInputCommand()) return;

    const userId = interaction.user.id;
    const userName = interaction.user.username;
    const commandName = interaction.commandName;

    logInfo(`Command /${commandName} from ${userName} (${userId})`);

    // Auth check
    if (!isAuthorized(userId)) {
        logWarn(`Blocked unauthorized user: ${userName} (${userId})`);
        await interaction.reply({
            content: `⛔ Unauthorized. Your user ID: \`${userId}\``,
            ephemeral: true,
        });
        return;
    }

    // Rate limit check
    const rl = checkRateLimit(userId);
    if (rl.limited) {
        await interaction.reply({
            content: `⏳ Rate limited. Try again in ${rl.waitSeconds}s.`,
            ephemeral: true,
        });
        return;
    }

    // Handle utility commands
    if (commandName === 'help') {
        await interaction.reply({ embeds: [buildHelpEmbed()], ephemeral: false });
        return;
    }

    if (commandName === 'status') {
        await interaction.reply({ embeds: [buildStatusEmbed()], ephemeral: false });
        return;
    }

    if (commandName === 'issues') {
        await interaction.reply({
            embeds: [new EmbedBuilder()
                .setTitle('🐛 Recent Issues')
                .setDescription('Checking Squad issue queue...')
                .setColor(0xE74C3C)
                .setTimestamp()
            ],
        });
        // Write issues request to inbox
        writeToInbox(
            'discord',
            interaction.channelId,
            interaction.id,
            userName,
            'List recent open issues from the backlog. Keep it concise for mobile.',
            'picard'
        );
        return;
    }

    // Agent commands — must be a known agent
    const agent = AGENTS[commandName];
    if (!agent) {
        await interaction.reply({ content: `Unknown command: /${commandName}`, ephemeral: true });
        return;
    }

    const message = interaction.options.getString('message');
    if (!message) {
        await interaction.reply({ content: 'Please provide a message.', ephemeral: true });
        return;
    }

    // Create a thread for this conversation
    let thread = null;
    try {
        const channel = interaction.channel;
        if (channel && channel.type === ChannelType.GuildText) {
            const threadName = `${agent.emoji} ${agent.name}: ${message.slice(0, 60)}`;
            // Reply first, then create thread from the reply
            await interaction.reply({
                embeds: [new EmbedBuilder()
                    .setTitle(`${agent.emoji} ${agent.name}`)
                    .setDescription(`📨 Message sent to ${agent.name}.\n\n> ${message}`)
                    .setColor(agent.color)
                    .setFooter({ text: 'Waiting for response...' })
                    .setTimestamp()
                ],
            });

            const reply = await interaction.fetchReply();
            thread = await reply.startThread({
                name: threadName.slice(0, 100),
                autoArchiveDuration: 60,
            });
        } else {
            // DM or thread channel — just reply inline
            await interaction.reply({
                embeds: [new EmbedBuilder()
                    .setTitle(`${agent.emoji} ${agent.name}`)
                    .setDescription(`📨 Message sent to ${agent.name}.\n\n> ${message}`)
                    .setColor(agent.color)
                    .setFooter({ text: 'Waiting for response...' })
                    .setTimestamp()
                ],
            });
        }
    } catch (err) {
        logError(`Thread creation failed: ${err.message}`);
        // If we haven't replied yet, reply now
        if (!interaction.replied && !interaction.deferred) {
            await interaction.reply({
                content: `📨 Message sent to ${agent.name}. (Thread creation failed)`,
            });
        }
    }

    // Write to inbox — use thread channelId if available, else original channel
    const targetChannelId = thread ? thread.id : interaction.channelId;

    const prefixed = `@${commandName} ${message}`;
    const result = writeToInbox(
        'discord',
        targetChannelId,
        interaction.id,
        userName,
        prefixed,
        commandName
    );

    // Track pending message
    pending.set(result.messageId, {
        channelId: targetChannelId,
        agent: commandName,
        timestamp: Date.now(),
    });
}

// ---------------------------------------------------------------------------
// Outbox polling
// ---------------------------------------------------------------------------

function startOutboxPoller(client) {
    setInterval(() => {
        try {
            scanOutbox(client);
        } catch (err) {
            logError(`Outbox poll error: ${err.message}`);
        }
    }, OUTBOX_POLL_MS);
    logInfo(`Outbox poller started (every ${OUTBOX_POLL_MS}ms)`);
}

// Clean up stale pending entries (older than 10 minutes)
function cleanPending() {
    const cutoff = Date.now() - 10 * 60 * 1000;
    for (const [id, entry] of pending) {
        if (entry.timestamp < cutoff) pending.delete(id);
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
    logInfo('='.repeat(60));
    logInfo('Squad Discord Bot starting...');
    logInfo('='.repeat(60));

    // Resolve token
    const token = getToken();
    if (!token) {
        logError(
            'No Discord bot token found!\n' +
            'Set it via one of:\n' +
            `  1. Environment variable: DISCORD_BOT_TOKEN\n` +
            `  2. Config file: ${CONFIG_FILE}\n` +
            `  3. Run: scripts/setup-discord-bot.ps1`
        );
        process.exit(1);
    }

    const appId = getAppId();
    if (!appId) {
        logError(
            'No Discord application ID found!\n' +
            `Set DISCORD_APP_ID env var or app_id in ${CONFIG_FILE}`
        );
        process.exit(1);
    }

    // Ensure directories
    ensureDir(INBOX_DIR);
    ensureDir(OUTBOX_DIR);

    // Register slash commands
    await registerCommands(token, appId);

    // Create client
    const client = new Client({
        intents: [
            GatewayIntentBits.Guilds,
            GatewayIntentBits.GuildMessages,
        ],
    });

    client.once('ready', () => {
        logInfo(`Bot connected: ${client.user.tag} (${client.user.id})`);
        logInfo('Listening for slash commands... (Ctrl+C to stop)');
        logInfo(`Inbox:  ${INBOX_DIR}`);
        logInfo(`Outbox: ${OUTBOX_DIR}`);

        // Start outbox polling
        startOutboxPoller(client);

        // Periodic cleanup
        setInterval(cleanPending, 60_000);
    });

    client.on('interactionCreate', async (interaction) => {
        try {
            await handleInteraction(interaction);
        } catch (err) {
            logError(`Interaction error: ${err.message}`);
            try {
                const reply = { content: '❌ An error occurred.', ephemeral: true };
                if (interaction.replied || interaction.deferred) {
                    await interaction.followUp(reply);
                } else {
                    await interaction.reply(reply);
                }
            } catch { /* can't recover */ }
        }
    });

    // Graceful shutdown
    const shutdown = () => {
        logInfo('Bot shutting down...');
        client.destroy();
        process.exit(0);
    };
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);

    // Connect
    await client.login(token);
}

main().catch(err => {
    logError(`Fatal: ${err.message}`);
    process.exit(1);
});
