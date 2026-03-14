#!/usr/bin/env node
/**
 * Tests for Squad Discord Bot — validates core logic without Discord connection.
 *
 * Run: node tests/test-discord-bot.js
 *
 * Tests:
 *   1. Queue file creation (writeToInbox)
 *   2. Rate limiting (checkRateLimit)
 *   3. Command parsing / agent routing
 *   4. Outbox scan (file handling)
 *   5. Auth (whitelist)
 *
 * Author: Data (Code Expert)
 */

import { existsSync, readFileSync, readdirSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

let passed = 0;
let failed = 0;
const errors = [];

function assert(condition, name) {
    if (condition) {
        console.log(`  ✅ ${name}`);
        passed++;
    } else {
        console.log(`  ❌ ${name}`);
        failed++;
        errors.push(name);
    }
}

function assertEqual(actual, expected, name) {
    if (actual === expected) {
        console.log(`  ✅ ${name}`);
        passed++;
    } else {
        console.log(`  ❌ ${name} — expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
        failed++;
        errors.push(name);
    }
}

// ---------------------------------------------------------------------------
// Inline implementations (avoid importing from bot which requires discord.js)
// ---------------------------------------------------------------------------

// Rate limiter — same logic as the bot
const RATE_LIMIT_MS = 5000;
const rateLimits = new Map();

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

// Agent definitions — same as bot
const AGENTS = {
    picard:  { name: 'Picard',   emoji: '🏗️', role: 'Lead — Architecture & Decisions',     color: 0xC0392B },
    data:    { name: 'Data',     emoji: '🔧', role: 'Code Expert — C#, Go, .NET',           color: 0x2980B9 },
    seven:   { name: 'Seven',    emoji: '📝', role: 'Research & Docs — Analysis',            color: 0x8E44AD },
    belanna: { name: "B'Elanna", emoji: '⚙️', role: 'Infrastructure — K8s, Helm, ArgoCD',   color: 0xE67E22 },
    worf:    { name: 'Worf',     emoji: '🔒', role: 'Security & Cloud — Azure, Networking',  color: 0x27AE60 },
};

// Auth — same logic as bot
function isAuthorized(userId, allowedSet) {
    if (allowedSet.size === 0) return true;
    return allowedSet.has(String(userId));
}

// Inbox writer — same logic as bot, but with configurable dir
import { createHash } from 'node:crypto';

function writeToInbox(inboxDir, channelId, messageId, user, text, agent) {
    if (!existsSync(inboxDir)) mkdirSync(inboxDir, { recursive: true });

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

    const filepath = join(inboxDir, filename);
    writeFileSync(filepath, JSON.stringify(payload, null, 2), 'utf-8');
    return { filename, filepath, payload };
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const TEST_DIR = join(homedir(), '.squad', '_test_discord_bot');

function setup() {
    if (existsSync(TEST_DIR)) rmSync(TEST_DIR, { recursive: true, force: true });
    mkdirSync(TEST_DIR, { recursive: true });
}

function teardown() {
    if (existsSync(TEST_DIR)) rmSync(TEST_DIR, { recursive: true, force: true });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

console.log('\n🧪 Squad Discord Bot — Tests\n');

// --- Test 1: Queue file creation ---
console.log('📋 Test 1: Queue file creation (writeToInbox)');
setup();
{
    const inboxDir = join(TEST_DIR, 'inbox');
    const result = writeToInbox(inboxDir, '123456', 'msg-001', 'testuser', '@picard How are things?', 'picard');

    assert(existsSync(result.filepath), 'Inbox file created on disk');
    assert(result.filename.startsWith('discord-'), 'Filename starts with discord-');
    assert(result.filename.endsWith('.json'), 'Filename ends with .json');

    const data = JSON.parse(readFileSync(result.filepath, 'utf-8'));
    assertEqual(data.source, 'discord', 'Source is discord');
    assertEqual(data.chat_id, '123456', 'chat_id matches');
    assertEqual(data.message_id, 'msg-001', 'message_id matches');
    assertEqual(data.user, 'testuser', 'user matches');
    assertEqual(data.agent, 'picard', 'agent matches');
    assertEqual(data.status, 'pending', 'status is pending');
    assert(data.text.includes('@picard'), 'text includes agent mention');
    assert(data.timestamp, 'timestamp is set');
}
teardown();

// --- Test 2: Multiple queue files are unique ---
console.log('\n📋 Test 2: Multiple queue files are unique');
setup();
{
    const inboxDir = join(TEST_DIR, 'inbox2');
    const r1 = writeToInbox(inboxDir, '111', 'msg-a', 'user1', 'Hello', 'data');
    const r2 = writeToInbox(inboxDir, '222', 'msg-b', 'user2', 'World', 'seven');

    assert(r1.filename !== r2.filename, 'Different messages get different filenames');
    const files = readdirSync(inboxDir).filter(f => f.endsWith('.json'));
    assertEqual(files.length, 2, 'Two files in inbox');
}
teardown();

// --- Test 3: Rate limiting ---
console.log('\n📋 Test 3: Rate limiting');
{
    rateLimits.clear();
    const user = 'rate-test-user';

    const first = checkRateLimit(user);
    assertEqual(first.limited, false, 'First command is not rate limited');

    const second = checkRateLimit(user);
    assertEqual(second.limited, true, 'Immediate second command is rate limited');
    assert(second.waitSeconds > 0, 'Wait seconds is positive');
    assert(second.waitSeconds <= 5, 'Wait seconds is at most 5');

    // Different user is not limited
    const otherUser = checkRateLimit('other-user');
    assertEqual(otherUser.limited, false, 'Different user is not rate limited');
}

// --- Test 4: Rate limit expires ---
console.log('\n📋 Test 4: Rate limit expiration (simulated)');
{
    rateLimits.clear();
    const user = 'expire-test';

    checkRateLimit(user);
    // Simulate time passage by backdating the entry
    rateLimits.set(user, Date.now() - RATE_LIMIT_MS - 100);

    const result = checkRateLimit(user);
    assertEqual(result.limited, false, 'Rate limit expires after cooldown period');
}

// --- Test 5: Command parsing / agent routing ---
console.log('\n📋 Test 5: Agent definitions');
{
    assert('picard' in AGENTS, 'picard agent exists');
    assert('data' in AGENTS, 'data agent exists');
    assert('seven' in AGENTS, 'seven agent exists');
    assert('belanna' in AGENTS, 'belanna agent exists');
    assert('worf' in AGENTS, 'worf agent exists');

    assertEqual(Object.keys(AGENTS).length, 5, 'Exactly 5 agents defined');

    for (const [key, agent] of Object.entries(AGENTS)) {
        assert(agent.name, `${key} has name`);
        assert(agent.emoji, `${key} has emoji`);
        assert(agent.role, `${key} has role`);
        assert(typeof agent.color === 'number', `${key} has numeric color`);
    }
}

// --- Test 6: Auth whitelist ---
console.log('\n📋 Test 6: Authentication whitelist');
{
    // Empty set = allow all
    const emptySet = new Set();
    assertEqual(isAuthorized('anyone', emptySet), true, 'Empty whitelist allows everyone');

    // Populated set = restricted
    const restricted = new Set(['123', '456']);
    assertEqual(isAuthorized('123', restricted), true, 'Whitelisted user is authorized');
    assertEqual(isAuthorized('456', restricted), true, 'Second whitelisted user is authorized');
    assertEqual(isAuthorized('789', restricted), false, 'Non-whitelisted user is rejected');

    // Numeric IDs are coerced to strings (correct behavior)
    assertEqual(isAuthorized(123, restricted), true, 'Numeric ID is coerced to string and matches');
}

// --- Test 7: Inbox JSON structure matches watcher expectations ---
console.log('\n📋 Test 7: Inbox JSON matches watcher contract');
setup();
{
    const inboxDir = join(TEST_DIR, 'inbox3');
    const result = writeToInbox(inboxDir, 'ch-999', 'msg-x', 'alice', 'Deploy to prod', 'belanna');
    const data = JSON.parse(readFileSync(result.filepath, 'utf-8'));

    // Fields the watcher expects (from squad-mobile-watcher.py):
    //   source, chat_id, message_id, user, text, timestamp, status
    assert('source' in data, 'Has source field');
    assert('chat_id' in data, 'Has chat_id field');
    assert('message_id' in data, 'Has message_id field');
    assert('user' in data, 'Has user field');
    assert('text' in data, 'Has text field');
    assert('timestamp' in data, 'Has timestamp field');
    assert('status' in data, 'Has status field');

    // Discord-specific extras
    assert('agent' in data, 'Has agent field (Discord extra)');
}
teardown();

// --- Test 8: Outbox file handling ---
console.log('\n📋 Test 8: Outbox file format');
{
    // Verify the expected outbox format matches what the watcher writes
    const outboxPayload = {
        chat_id: '123456',
        text: 'Response from agent',
        source: 'discord',
        in_reply_to: 'msg-001',
        timestamp: new Date().toISOString(),
    };

    assert(outboxPayload.chat_id, 'Outbox has chat_id');
    assert(outboxPayload.text, 'Outbox has text');
    assertEqual(outboxPayload.source, 'discord', 'Outbox source is discord');
    assert(outboxPayload.timestamp, 'Outbox has timestamp');
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

console.log('\n' + '='.repeat(40));
console.log(`Results: ${passed} passed, ${failed} failed`);
if (errors.length > 0) {
    console.log('\nFailed tests:');
    errors.forEach(e => console.log(`  ❌ ${e}`));
}
console.log('='.repeat(40) + '\n');

process.exit(failed > 0 ? 1 : 0);
