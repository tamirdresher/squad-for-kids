# Mobile Squad Access — Technical Research Report
**Author:** Data (Code Expert)  
**Date:** 2026-03-14  
**Issue:** #489  

## Executive Summary

After comprehensive research into 8 viable options for Android-based squad access, I recommend **Discord Bot with Socket Mode** as the optimal solution. It provides the best balance of security (zero firewall holes), developer experience (2-4h setup), mobile UX (9/10), and maintainability (stable API, low overhead).

**Time to working prototype:** 3-4 hours  
**Deployment complexity:** Low (runs alongside Ralph on DevBox)  
**Security posture:** Excellent (no public exposure, OAuth-like auth)  

---

## Option Comparison Matrix

| Option | Setup Time | Security | Android UX | Maintenance | Cost | Recommendation |
|--------|-----------|----------|------------|-------------|------|----------------|
| **Discord Bot** | 2-4h | 🟢 Excellent | 9/10 | Low | Free | ✅ **RECOMMENDED** |
| **Telegram Bot** | 2-3h | 🟢 Excellent | 9/10 | Low | Free | 🥈 Strong alternative |
| **Signal Bot** | 3-4h | 🟢 Best-in-class | 9/10 | Medium | Free | Privacy-first option |
| **ttyd Web Terminal** | 30min | 🟡 Moderate | 6/10 | Low | Free | Quick & dirty |
| **GitHub Issues as Chat** | 1h | 🟢 Good | 3/10 | Low | Free | ❌ UX too poor |
| **WhatsApp Business API** | 4-6h | 🟢 Excellent | 10/10 | Medium | Paid | Costs money |
| **Matrix/Element** | 4-7 days | 🟢 Excellent | 8/10 | High | Free | ❌ Too complex |
| **Custom PWA** | 4-8h | 🟡 Moderate | 8/10 | High | Free | ❌ Overkill |

---

## Detailed Analysis

### 🏆 Option 1: Discord Bot (RECOMMENDED)

#### Why Discord Wins
1. **Socket Mode = Zero Firewall Holes**
   - Bot connects outbound to Discord (no inbound ports)
   - No public IP exposure, no certificate management
   - Perfect for DevBox behind corporate firewall

2. **Natural Command Routing**
   ```
   /ask @Picard should we use Kafka or RabbitMQ?
   /data optimize src/parser.ts
   /seven document the authentication flow
   ```
   - Slash commands map perfectly to squad agent routing
   - Threads for conversation sessions
   - Mentions for explicit agent targeting

3. **Rich Mobile UX (9/10)**
   - Native Android app, mature and fast
   - Markdown rendering, code blocks, syntax highlighting
   - Inline buttons (e.g., "🔄 Retry", "✅ Approve", "❌ Cancel")
   - Reactions for quick feedback
   - Voice notes supported
   - File attachments (logs, screenshots)

4. **Developer Experience**
   - Excellent Node.js SDK: `discord.js` (most popular, 25M downloads/month)
   - Python SDK: `discord.py` (if preferred)
   - Comprehensive docs, large community
   - Built-in rate limiting, reconnection logic

5. **Free Tier**
   - No message limits
   - No bot limits
   - No slash command limits
   - 8MB file uploads (enough for logs)

#### Setup Steps (2-4h total)
```
1. Create Discord Bot Application (10 min)
   - Visit discord.com/developers/applications
   - Create app → Add bot → Copy token
   - Enable "Message Content Intent" in Bot settings
   - Generate OAuth2 URL with bot scope + permissions
   - Invite bot to personal Discord server

2. Build Squad Bridge (2-3h)
   - Initialize Node.js project with discord.js
   - Implement Socket Mode connection (uses Gateway API)
   - Parse slash commands → route to Copilot CLI
   - Capture Copilot responses → post back to Discord
   - Handle threads for conversation sessions

3. Deploy (30 min)
   - Run alongside Ralph (same PM2/systemd setup)
   - Store bot token in .env file
   - Test on Android Discord app

4. Register Slash Commands (15 min)
   - Define command schemas (agent names, descriptions)
   - Register with Discord API (one-time setup)
```

#### Security Model
- **Authentication:** Bot token (treat like password, store in env)
- **Authorization:** Restrict bot to single private Discord server
- **User Identification:** Discord user ID whitelist (only Tamir can command)
- **Message Encryption:** Discord uses TLS for transport
- **No Public Exposure:** Socket Mode = outbound connections only

#### Architecture Diagram
```
┌─────────────┐         WebSocket          ┌──────────────┐
│   Android   │◄───────(Socket Mode)───────►│   Discord    │
│ Discord App │                             │   Gateway    │
└─────────────┘                             └──────┬───────┘
                                                   │
                                            Slash commands,
                                            messages, threads
                                                   │
                                            ┌──────▼───────┐
                                            │ Discord Bot  │
                                            │  (Node.js)   │
                                            │              │
                                            │ - Parse cmds │
                                            │ - Route to   │
                                            │   agents     │
                                            │ - Format     │
                                            │   responses  │
                                            └──────┬───────┘
                                                   │
                                            spawn process
                                            with prompt
                                                   │
                                            ┌──────▼───────┐
                                            │ Copilot CLI  │
                                            │              │
                                            │ gh copilot   │
                                            │ --agent=DATA │
                                            │ --prompt=... │
                                            └──────────────┘
```

#### Code Sketch (Minimal Prototype)
```typescript
// discord-squad-bridge.ts
import { Client, GatewayIntentBits } from 'discord.js';
import { spawn } from 'child_process';
import dotenv from 'dotenv';

dotenv.config();

const client = new Client({ 
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ] 
});

// Agent routing map
const AGENTS = {
  'picard': 'Lead — Architecture, distributed systems',
  'data': 'Code Expert — C#, Go, .NET',
  'seven': 'Research & Docs',
  'belanna': 'Infrastructure — K8s, Helm, ArgoCD',
  'worf': 'Security & Cloud',
  // ... other agents
};

client.on('ready', () => {
  console.log(`Logged in as ${client.user.tag}`);
  registerSlashCommands();
});

// Handle slash commands
client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;
  
  const { commandName, options } = interaction;
  const agent = commandName; // e.g., /picard, /data
  const prompt = options.getString('task');
  
  // Verify authorized user
  if (interaction.user.id !== process.env.AUTHORIZED_USER_ID) {
    await interaction.reply('❌ Unauthorized');
    return;
  }
  
  await interaction.deferReply(); // "Bot is thinking..."
  
  // Spawn Copilot CLI
  const result = await invokeSquadAgent(agent, prompt);
  
  // Post response (split into chunks if needed, max 2000 chars/message)
  await interaction.editReply({
    content: formatResponse(result),
    components: [
      // Add action buttons: Retry, More Details, etc.
    ]
  });
});

async function invokeSquadAgent(agent: string, prompt: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn('gh', [
      'copilot',
      '--agent', agent.toUpperCase(),
      '--prompt', prompt
    ], {
      cwd: process.env.SQUAD_ROOT,
      env: process.env
    });
    
    let output = '';
    child.stdout.on('data', (data) => output += data.toString());
    child.stderr.on('data', (data) => console.error(data.toString()));
    
    child.on('close', (code) => {
      if (code === 0) resolve(output);
      else reject(new Error(`Agent ${agent} failed with code ${code}`));
    });
  });
}

function registerSlashCommands() {
  // Register /picard, /data, /seven, etc. with Discord API
  // This runs once at startup or via separate registration script
}

function formatResponse(text: string): string {
  // Split long responses into multiple messages
  // Add code blocks, markdown formatting
  // Truncate if > 2000 chars
  return text.substring(0, 2000);
}

client.login(process.env.DISCORD_BOT_TOKEN);
```

#### Deployment Alongside Ralph
```powershell
# Add to start-all-ralphs.ps1 or separate script
Write-Host "Starting Discord Squad Bridge..." -ForegroundColor Cyan
Start-Process pwsh.exe -ArgumentList @(
  "-NoProfile",
  "-Command",
  "cd C:\temp\tamresearch1\discord-bridge; npm start"
) -WindowStyle Normal
```

Or use PM2 for process management:
```bash
pm2 start discord-squad-bridge.ts --name squad-discord
pm2 startup  # auto-start on reboot
pm2 save
```

---

### 🥈 Option 2: Telegram Bot

#### Strengths
- Even simpler API than Discord
- Excellent mobile app, very lightweight
- Inline keyboards for interactive responses
- Voice message support
- Bot commands with `/` prefix feel natural

#### Why Second Place
- Less rich than Discord (no threads, embeds are basic)
- No slash command registration (just text parsing)
- Routing is manual: parse `/ask @picard ...` from text

#### Setup Time
2-3 hours (slightly faster than Discord due to simpler API)

#### Code Sketch
```typescript
// telegram-squad-bridge.ts
import TelegramBot from 'node-telegram-bot-api';
import { spawn } from 'child_process';

const bot = new TelegramBot(process.env.TELEGRAM_BOT_TOKEN, { polling: true });

bot.onText(/\/(\w+)\s+(.+)/, async (msg, match) => {
  const chatId = msg.chat.id;
  const agent = match[1]; // e.g., 'picard', 'data'
  const prompt = match[2];
  
  // Verify authorized user
  if (msg.from.id !== parseInt(process.env.AUTHORIZED_USER_ID)) {
    bot.sendMessage(chatId, '❌ Unauthorized');
    return;
  }
  
  bot.sendMessage(chatId, `🤖 ${agent.toUpperCase()} is thinking...`);
  
  const result = await invokeSquadAgent(agent, prompt);
  bot.sendMessage(chatId, result, { parse_mode: 'Markdown' });
});

bot.on('polling_error', console.error);
```

---

### 🔒 Option 3: Signal Bot

#### Strengths
- Best-in-class security (E2E encryption, open-source protocol)
- No corporate ties (non-profit Signal Foundation)
- Zero metadata collection
- Great Android app

#### Why Third Place
- No official bot API (uses signal-cli, third-party)
- signal-cli is Java-based, more setup friction
- Limited rich messaging features
- Higher maintenance (unofficial tooling)

#### Setup Time
3-4 hours (signal-cli setup + Node.js wrapper)

#### When to Choose Signal
If privacy is paramount (e.g., discussing confidential architecture, handling PII in prompts). For most dev workflows, Discord/Telegram are sufficient.

---

### ⚡ Option 4: ttyd Web Terminal

#### Concept
- Install `ttyd` (web-based terminal emulator)
- Expose via dev tunnel with auth
- Access from Android browser
- Direct terminal access to Copilot CLI

#### Strengths
- Fastest setup: 30 minutes
- Zero custom code (off-the-shelf tool)
- Direct terminal = full CLI access

#### Weaknesses
- UX is poor (terminal in mobile browser)
- Not chat-like (no threading, history is terminal scrollback)
- Awkward on small screens

#### When to Use
Quick hack for temporary access. Not suitable for daily use.

---

### ❌ Option 5: GitHub Issues as Chat

#### Concept
- Use issue comments as chat messages
- Ralph watches issue, posts responses as comments
- GitHub Mobile app for Android access

#### Why Rejected
- UX is abysmal (3/10)
- Latency (polling, not real-time)
- Not conversational (no threading)
- Clutters issue tracker

#### Only viable if
You need audit trail of all squad interactions in GitHub.

---

### 💸 Option 6: WhatsApp Business API

#### Strengths
- Best mobile UX (10/10) — everyone knows WhatsApp
- Rich messaging (media, documents, voice notes)
- End-to-end encryption
- Verified business profile (green check)

#### Why Not Recommended
- **Costs money** (pricing varies by provider: Twilio, Infobip)
- Approval process (Meta business verification)
- Overkill for personal use
- 4-6h setup (more complex onboarding)

#### When to Use
If building a product for external users. For personal squad access, free options suffice.

---

### 🛠️ Option 7: Matrix/Element Protocol

#### Strengths
- Open protocol, self-hosted
- E2E encryption (like Signal)
- Federation (can connect multiple servers)
- Element Android app is solid

#### Why Rejected
- **4-7 days setup time** (Matrix server + Element client config)
- High maintenance (self-hosting Synapse server)
- Overkill for single-user use case

#### When to Use
If building a platform for a team/org that needs self-hosted, federated chat with strong privacy.

---

### 🎨 Option 8: Custom PWA with WebSocket

#### Concept
- Build custom web chat UI (React/Vue)
- WebSocket server for real-time
- Install as PWA on Android (app-like)
- Custom UX tailored to squad workflow

#### Why Rejected
- 4-8h dev time (custom build)
- High maintenance (own code, updates, bugs)
- Unnecessary complexity

#### When to Use
If you need features no existing platform provides (e.g., custom visualizations, squad-specific UI patterns). For MVP, use Discord/Telegram.

---

## Security Deep Dive

### Threat Model
| Threat | Discord | Telegram | Signal |
|--------|---------|----------|--------|
| Token leakage | Regenerate token in dev portal (5 min) | Regenerate token via @BotFather (5 min) | Re-register number (15 min) |
| Unauthorized user | User ID whitelist in code | User ID whitelist in code | Phone number whitelist |
| Message interception | TLS (no E2E, but Discord-hosted) | TLS (no E2E, but Telegram-hosted) | Full E2E encryption |
| Prompt injection | Sanitize user input before CLI spawn | Sanitize user input | Sanitize user input |
| Public exposure | Zero (Socket Mode) | Zero (polling mode) | Zero (Signal CLI) |

### Recommended Security Measures
1. **Bot Token Storage**
   - Store in `.env` file (never commit)
   - Add `.env` to `.gitignore`
   - On DevBox: use restricted file permissions (`chmod 600 .env`)

2. **User Authorization**
   ```typescript
   const AUTHORIZED_USERS = [
     process.env.TAMIR_DISCORD_ID,
     // Add more if needed
   ];
   
   if (!AUTHORIZED_USERS.includes(interaction.user.id)) {
     return interaction.reply('❌ Unauthorized');
   }
   ```

3. **Input Sanitization**
   ```typescript
   function sanitizePrompt(input: string): string {
     // Remove shell metacharacters
     return input.replace(/[;&|`$()]/g, '');
   }
   ```

4. **Rate Limiting**
   ```typescript
   const userCooldowns = new Map();
   const COOLDOWN_MS = 5000; // 5 seconds between commands
   
   if (userCooldowns.has(userId)) {
     const lastUsed = userCooldowns.get(userId);
     const cooldownRemaining = COOLDOWN_MS - (Date.now() - lastUsed);
     if (cooldownRemaining > 0) {
       return interaction.reply(`⏱️ Cooldown: ${cooldownRemaining}ms`);
     }
   }
   userCooldowns.set(userId, Date.now());
   ```

5. **Private Server Only**
   - Create personal Discord server (invite-only)
   - Don't add bot to public servers
   - Limit bot permissions to minimum required

---

## Implementation Plan

### Phase 1: MVP (Week 1)
**Goal:** Basic Discord bot that can invoke Picard and Data

**Tasks:**
1. Create Discord bot application (10 min)
2. Set up Node.js project with TypeScript + discord.js (30 min)
3. Implement basic slash command handler (1h)
4. Integrate with Copilot CLI via `spawn` (1h)
5. Test on Android Discord app (30 min)
6. Deploy alongside Ralph on DevBox (30 min)

**Total: 3-4 hours**

**Success Criteria:**
- `/picard <question>` returns response on Discord
- `/data <task>` spawns Data agent
- Works from Android phone

### Phase 2: Enhanced UX (Week 2)
**Goal:** Threads, rich formatting, all agents

**Tasks:**
1. Add thread support (conversations persist) (1h)
2. Register slash commands for all squad agents (1h)
3. Implement response chunking (handle >2000 char responses) (1h)
4. Add reaction-based interactions ("👍 to retry") (1h)
5. Syntax highlighting for code blocks (30 min)

**Total: 4-5 hours**

### Phase 3: Advanced Features (Week 3)
**Goal:** File attachments, voice notes, context preservation

**Tasks:**
1. Support file uploads (user sends log, bot attaches to prompt) (2h)
2. Voice message transcription (integrate Whisper API) (2h)
3. Conversation context management (store history in SQLite) (2h)
4. Add inline buttons for common actions (1h)

**Total: 7 hours**

### Phase 4: Monitoring & Ops (Week 4)
**Goal:** Production-ready reliability

**Tasks:**
1. Add structured logging (Winston or Pino) (1h)
2. Health check endpoint (express server on localhost) (1h)
3. Graceful shutdown handling (1h)
4. PM2 ecosystem file for auto-restart (30 min)
5. Alert on bot disconnect (post to Teams webhook) (1h)

**Total: 4-5 hours**

---

## Effort Estimates by Option

| Option | Setup | MVP | Production-Ready | Maintenance (monthly) |
|--------|-------|-----|------------------|----------------------|
| Discord Bot | 3-4h | 4h | 5h | 30 min |
| Telegram Bot | 2-3h | 3h | 4h | 30 min |
| Signal Bot | 3-4h | 4h | 6h | 1h |
| ttyd | 30min | N/A | 1h | 15 min |
| GitHub Issues | 1h | 2h | 3h | 15 min |
| WhatsApp Business | 4-6h | 6h | 8h | 1h |
| Matrix/Element | 4-7 days | 8h | 12h | 2h |
| Custom PWA | 4-8h | 12h | 20h | 3h |

---

## Alternative: Telegram Bot Implementation

For completeness, here's a Telegram bot sketch:

```typescript
// telegram-squad-bridge.ts
import TelegramBot from 'node-telegram-bot-api';
import { spawn } from 'child_process';
import dotenv from 'dotenv';

dotenv.config();

const bot = new TelegramBot(process.env.TELEGRAM_BOT_TOKEN, { polling: true });

// Agent routing
const AGENTS = ['picard', 'data', 'seven', 'belanna', 'worf'];

// Command: /agent_name prompt
bot.onText(/\/(\w+)\s+(.+)/, async (msg, match) => {
  const chatId = msg.chat.id;
  const agent = match[1].toLowerCase();
  const prompt = match[2];
  
  // Auth check
  if (msg.from.id !== parseInt(process.env.AUTHORIZED_USER_ID)) {
    bot.sendMessage(chatId, '❌ Unauthorized user');
    return;
  }
  
  // Validate agent
  if (!AGENTS.includes(agent)) {
    bot.sendMessage(chatId, `❌ Unknown agent: ${agent}\n\nAvailable: ${AGENTS.join(', ')}`);
    return;
  }
  
  // Indicate processing
  const thinkingMsg = await bot.sendMessage(chatId, `🤖 **${agent.toUpperCase()}** is thinking...`, {
    parse_mode: 'Markdown'
  });
  
  try {
    const result = await invokeAgent(agent, prompt);
    
    // Delete "thinking" message
    await bot.deleteMessage(chatId, thinkingMsg.message_id);
    
    // Send result (split if too long)
    const chunks = splitMessage(result, 4096); // Telegram limit
    for (const chunk of chunks) {
      await bot.sendMessage(chatId, chunk, {
        parse_mode: 'Markdown',
        reply_to_message_id: msg.message_id
      });
    }
  } catch (err) {
    await bot.editMessageText(`❌ **Error:** ${err.message}`, {
      chat_id: chatId,
      message_id: thinkingMsg.message_id
    });
  }
});

// /start command
bot.onText(/\/start/, (msg) => {
  bot.sendMessage(msg.chat.id, `
👋 **Squad Bot Ready**

Available agents:
${AGENTS.map(a => `• /${a} <task>`).join('\n')}

Example: \`/data optimize parser.go\`
  `, { parse_mode: 'Markdown' });
});

async function invokeAgent(agent: string, prompt: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const proc = spawn('gh', ['copilot', '--agent', agent.toUpperCase(), '--prompt', prompt], {
      cwd: process.env.SQUAD_ROOT,
      timeout: 120000 // 2 min timeout
    });
    
    let stdout = '';
    let stderr = '';
    
    proc.stdout.on('data', (data) => stdout += data.toString());
    proc.stderr.on('data', (data) => stderr += data.toString());
    
    proc.on('close', (code) => {
      if (code === 0) resolve(stdout || stderr);
      else reject(new Error(`Exit code ${code}: ${stderr}`));
    });
  });
}

function splitMessage(text: string, maxLength: number): string[] {
  const chunks: string[] = [];
  for (let i = 0; i < text.length; i += maxLength) {
    chunks.push(text.substring(i, i + maxLength));
  }
  return chunks;
}

bot.on('polling_error', (err) => console.error('Polling error:', err));

console.log('Telegram Squad Bot started');
```

**Setup Steps:**
1. Message @BotFather on Telegram
2. `/newbot` → follow prompts → get token
3. Create `.env`: `TELEGRAM_BOT_TOKEN=xxx`, `AUTHORIZED_USER_ID=xxx`
4. `npm install node-telegram-bot-api dotenv`
5. `npm start`

---

## Recommendation Summary

**Go with Discord Bot** for these reasons:

1. **Best balance** of ease, security, UX, and features
2. **Socket Mode** eliminates firewall concerns
3. **Slash commands** map naturally to squad agents
4. **Threads** provide session isolation
5. **Rich UI** on Android (embeds, buttons, reactions)
6. **Free tier** with no limits
7. **Low maintenance** (stable API, large community)

**Telegram Bot** is an excellent alternative if you prefer its simpler API or already use Telegram heavily.

**Signal Bot** if privacy is paramount, but adds operational complexity.

---

## Next Steps

1. **Create Discord bot** (10 min) — I can do this now
2. **Build MVP** (3-4h) — Core bridge functionality
3. **Test on Android** (30 min) — Validate mobile UX
4. **Deploy alongside Ralph** (30 min) — Add to startup scripts
5. **Iterate on UX** (Phase 2+) — Threads, rich formatting, all agents

Ready to proceed with implementation. Awaiting approval to start Phase 1.

---

## References

- [Discord.js Guide](https://discordjs.guide/)
- [Discord Developer Portal](https://discord.com/developers/docs)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Signal CLI GitHub](https://github.com/AsamK/signal-cli)
- [WebSocket Architecture Best Practices](https://ably.com/topic/websocket-architecture-best-practices)
- [Node.js Bot Framework CLI](https://github.com/microsoft/botframework-cli)
