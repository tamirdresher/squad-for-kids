# Mobile Squad Chat Architecture — Azure Native Solution

**Author:** Picard (Lead)  
**Date:** 2025-03-11  
**Issue:** #489  
**Requested by:** Tamir Dresher

---

## Executive Summary

**Recommendation:** **Option A — Azure Static Web App + Azure Functions + SignalR** (PWA approach)

**Rationale:**
- ✅ **Best UX:** Feels like a native chat app, installable to Android home screen
- ✅ **Real-time:** SignalR provides bidirectional push notifications
- ✅ **Zero approval:** All services available to MS employees by default
- ✅ **Low cost:** Free tier covers this use case entirely ($0/month estimated)
- ✅ **Low maintenance:** Serverless auto-scales, no servers to manage
- ✅ **Secure:** Azure AD/Entra SSO (Microsoft account login), private endpoints possible
- ✅ **Fast to MVP:** Can have working prototype in 1-2 days

**MVP Timeline:** 1-2 days for basic chat, 3-5 days for full agent routing

---

## Table of Contents

1. [Decision Matrix — All Options Compared](#decision-matrix)
2. [Architecture Design (Recommended: Option A)](#architecture-design)
3. [Data Flow & Components](#data-flow)
4. [Authentication & Security](#authentication)
5. [Cost Analysis](#cost-analysis)
6. [MVP Build Plan (Step-by-Step)](#mvp-build-plan)
7. [Future Enhancements](#future-enhancements)
8. [Appendix: Alternative Options Analysis](#appendix)

---

## Decision Matrix

### Option Comparison

| Criteria | **A: Static Web App + SignalR (PWA)** | B: ACS Chat | C: Bot Service + Teams | D: Container App + Open WebUI |
|----------|----------------------------------------|-------------|------------------------|-------------------------------|
| **UX Quality** | ⭐⭐⭐⭐⭐ Native-like PWA | ⭐⭐⭐⭐ Good mobile SDK | ⭐⭐⭐ Teams client | ⭐⭐⭐ Web UI in browser |
| **Setup Time** | ⭐⭐⭐⭐ 1-2 days | ⭐⭐⭐ 2-3 days | ⭐⭐ 3-5 days (approval wait) | ⭐⭐⭐ 2-3 days |
| **Maintenance** | ⭐⭐⭐⭐⭐ Serverless auto-scaling | ⭐⭐⭐⭐ Managed service | ⭐⭐⭐ Managed bot | ⭐⭐ Container restarts needed |
| **Cost (monthly)** | **$0** (free tier) | $50-100 (ACS charges) | $0 (free tier bot) | $15-30 (container always-on) |
| **Auth** | ⭐⭐⭐⭐⭐ Azure AD SSO built-in | ⭐⭐⭐⭐ ACS identity | ⭐⭐⭐⭐ Microsoft account | ⭐⭐⭐ Custom auth needed |
| **Approval Needed** | ✅ None | ✅ None | ⚠️ Tenant admin for org-wide bot | ✅ None |
| **Real-time** | ⭐⭐⭐⭐⭐ SignalR push | ⭐⭐⭐⭐ ACS push | ⭐⭐⭐⭐ Teams push | ⭐⭐⭐ WebSocket |
| **Offline Mode** | ⭐⭐⭐⭐⭐ PWA service worker | ⭐⭐⭐ SDK caching | ⭐⭐⭐⭐ Teams offline | ❌ None |
| **Installable** | ✅ Yes (Add to Home Screen) | ✅ Yes (native SDK) | ✅ Yes (Teams app) | ❌ No (just a URL) |
| **Squad Integration** | Custom Azure Function bridge | Custom bridge | Bot Framework bridge | Direct CLI spawn |
| **Microsoft Services** | 100% Azure native | 100% Azure native | 100% Azure native | Hybrid (container + Azure) |

**Winner:** **Option A — Static Web App + SignalR** (best balance of UX, cost, speed, and maintenance)

---

## Architecture Design

### Recommended: Option A — Azure Static Web App + Azure Functions + SignalR (PWA)

#### Component Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────┐
│                         ANDROID PHONE                           │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  PWA Chat UI (installable, feels like native app)        │  │
│  │  - React 18 + Material-UI                                │  │
│  │  - Service Worker (offline support)                      │  │
│  │  - LocalStorage (chat history cache)                     │  │
│  │  - SignalR client (real-time push)                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│           │                                    ▲                 │
│           │ HTTPS                              │ SignalR         │
│           │ (POST /api/send)                   │ (push response) │
└───────────┼────────────────────────────────────┼─────────────────┘
            │                                    │
            │                                    │
┌───────────▼────────────────────────────────────┼─────────────────┐
│                      AZURE CLOUD                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Azure Static Web App (free tier)                           │ │
│  │ - Hosts PWA (HTML/CSS/JS)                                  │ │
│  │ - Auto-deploys from GitHub                                 │ │
│  │ - Built-in Azure AD auth                                   │ │
│  │ - Custom domain support                                    │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                    │                             │
│                                    │ API proxy                   │
│                                    ▼                             │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │ Azure Functions (Consumption Plan — free tier)             │ │
│  │                                                             │ │
│  │  [Function: SendMessage]                                   │ │
│  │    - HTTP trigger (POST /api/send)                         │ │
│  │    - Validates Azure AD token                              │ │
│  │    - Parses message, detects agent routing                 │ │
│  │    - Spawns Copilot CLI process OR calls MCP bridge       │ │
│  │    - Returns response via SignalR                          │ │
│  │                                                             │ │
│  │  [Function: GetHistory]                                    │ │
│  │    - HTTP trigger (GET /api/history)                       │ │
│  │    - Retrieves chat log from CosmosDB                      │ │
│  │                                                             │ │
│  │  [Function: SignalRNegotiate]                              │ │
│  │    - SignalR connection endpoint                           │ │
│  │                                                             │ │
│  └──────┬──────────────────────────┬───────────────────────────┘ │
│         │                          │                             │
│         │ spawn process            │ store/retrieve              │
│         ▼                          ▼                             │
│  ┌─────────────────────┐   ┌─────────────────────┐              │
│  │ Copilot CLI         │   │ CosmosDB (Serverless)│              │
│  │ - Installed in      │   │ - Chat history       │              │
│  │   Azure Function    │   │ - User sessions      │              │
│  │ - Accesses .squad/  │   │ - Message log        │              │
│  │   via GitHub API    │   │ - FREE tier: 1000 RU │              │
│  └─────────────────────┘   └─────────────────────┘              │
│         │                          ▲                             │
│         │ reads squad files        │ pushes response             │
│         ▼                          │                             │
│  ┌─────────────────────────────────┴───────────────────────────┐ │
│  │ Azure SignalR Service (Free tier: 20 concurrent)           │ │
│  │ - Real-time bidirectional push                             │ │
│  │ - Sends responses back to phone instantly                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
            │
            │ reads/writes via GitHub API
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    GITHUB REPOSITORY                             │
│  .squad/                                                         │
│    ├── team.md                                                   │
│    ├── routing.md                                                │
│    ├── agents/                                                   │
│    └── orchestration-log/                                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### User Sends Message

```
1. User types: "@picard What's the status of issue #489?"
   └─ PWA → HTTPS POST /api/send
      └─ Azure Function [SendMessage]
         ├─ Validates Azure AD JWT token
         ├─ Parses message:
         │  └─ Detects "@picard" → route to Picard agent
         ├─ Spawns Copilot CLI:
         │  └─ `gh copilot --agent=picard "What's the status of issue #489?"`
         ├─ Waits for CLI response (or timeout 30s)
         ├─ Stores message in CosmosDB
         └─ Pushes response to SignalR
            └─ SignalR → Android Phone (real-time)
               └─ PWA displays: "Picard: Issue #489 is pending user input..."
```

### Agent Routing Logic (in Azure Function)

```javascript
function routeMessage(text) {
  // Check for explicit @mention
  if (text.includes('@picard')) return 'picard';
  if (text.includes('@data')) return 'data';
  if (text.includes('@seven')) return 'seven';
  if (text.includes('@belanna')) return 'belanna';
  if (text.includes('@worf')) return 'worf';
  
  // Smart routing based on keywords (reads .squad/routing.md)
  if (/bug|error|crash|fix/i.test(text)) return 'data';
  if (/research|document|analyze/i.test(text)) return 'seven';
  if (/kubernetes|cluster|deploy|infrastructure/i.test(text)) return 'belanna';
  if (/security|compliance|audit/i.test(text)) return 'worf';
  
  // Default to Picard (Lead) for orchestration
  return 'picard';
}
```

### Offline Support (PWA Service Worker)

```
1. User sends message while offline
   └─ PWA service worker intercepts
      ├─ Stores message in IndexedDB (local queue)
      └─ Shows "Message queued (offline)" toast
2. Phone reconnects to network
   └─ Service worker detects online event
      ├─ Flushes IndexedDB queue
      └─ Sends all queued messages to API
         └─ SignalR pushes responses
```

---

## Authentication

### Azure AD / Entra ID SSO Flow

```
1. User opens PWA: https://squad-chat.azurestaticapps.net
   └─ Static Web App checks auth cookie
      ├─ If not authenticated:
      │  └─ Redirect to Azure AD login (Microsoft account)
      │     └─ User signs in: tamir@microsoft.com
      │        └─ Azure AD returns JWT token
      │           └─ Redirect back to PWA with token
      │              └─ PWA stores token in sessionStorage
      └─ If authenticated:
         └─ Load chat UI

2. User sends message
   └─ PWA includes token in Authorization header:
      └─ Authorization: Bearer <JWT>
         └─ Azure Function validates token:
            ├─ Checks signature (Azure AD public key)
            ├─ Verifies expiration
            ├─ Extracts user identity (email, name)
            └─ Checks if user has "squad.user" role
               ├─ If valid → process message
               └─ If invalid → 401 Unauthorized
```

### Role-Based Access Control (RBAC)

**Roles:**
- `squad.user` — Can chat with squad, read responses
- `squad.admin` — Can trigger orchestration rounds, view all user chats
- `squad.viewer` — Read-only access to squad health dashboard

**Azure AD App Registration:**
1. Create App Registration: "Squad Mobile Chat"
2. Add App Roles:
   - `squad.user` (default for all Microsoft employees)
   - `squad.admin` (assigned to Tamir)
3. Configure Static Web App to require authentication
4. Function validates roles from JWT `roles` claim

---

## Cost Analysis

### Azure Services — Free Tier Breakdown

| Service | Free Tier | Usage Estimate | Monthly Cost |
|---------|-----------|----------------|--------------|
| **Azure Static Web App** | 100 GB bandwidth/month | 1 GB/month (PWA is tiny) | **$0** |
| **Azure Functions (Consumption)** | 1M requests + 400k GB-s | ~10k requests/month | **$0** |
| **Azure SignalR Service** | Free tier: 20 concurrent, 20k msg/day | 1 user, <1k msg/day | **$0** |
| **Azure CosmosDB (Serverless)** | Free tier: 1000 RU/s, 25 GB | <100 RU/s, <1 GB | **$0** |
| **Azure AD (Entra ID)** | Included with Microsoft account | N/A | **$0** |

**Total Monthly Cost:** **$0** (stays within free tier limits)

**Scaling Estimate (if team grows to 10 users):**
- Still free tier for Static Web App
- Still free tier for Functions (~100k requests/month)
- SignalR: May need Basic tier ($49/month for 1000 concurrent)
- CosmosDB: Still free tier (<10k RU/s)
- **Total for 10 users:** ~$50/month

---

## MVP Build Plan

### Day 1: Frontend (PWA Chat UI)

**Goal:** Get a working chat interface that feels native on Android

**Tasks:**
1. **Create React PWA scaffold**
   ```bash
   npx create-react-app squad-chat --template pwa-typescript
   cd squad-chat
   npm install @mui/material @emotion/react @emotion/styled
   npm install @microsoft/signalr axios
   ```

2. **Build chat UI components**
   - `ChatWindow.tsx` — Message list with avatars for each agent
   - `MessageInput.tsx` — Text input with send button
   - `AgentSelector.tsx` — Quick select buttons (@picard, @data, @seven)
   - `TypingIndicator.tsx` — Shows "Picard is thinking..." while waiting

3. **Add PWA manifest** (`public/manifest.json`)
   ```json
   {
     "short_name": "Squad Chat",
     "name": "Tamir's AI Squad",
     "icons": [
       { "src": "picard-icon-192.png", "sizes": "192x192", "type": "image/png" },
       { "src": "picard-icon-512.png", "sizes": "512x512", "type": "image/png" }
     ],
     "start_url": ".",
     "display": "standalone",
     "theme_color": "#9B8FCC",
     "background_color": "#1E1E1E"
   }
   ```

4. **Test on Android**
   - Deploy to GitHub Pages temporarily
   - Open in Chrome on Android
   - Click "Add to Home Screen"
   - Verify it launches like a native app

**Deliverable:** PWA that loads on phone, displays mock chat UI

---

### Day 2: Backend (Azure Functions + SignalR)

**Goal:** Connect PWA to real Squad CLI via serverless backend

**Tasks:**
1. **Create Azure Function App**
   ```bash
   func init squad-chat-api --typescript
   cd squad-chat-api
   func new --name SendMessage --template "HTTP trigger"
   func new --name GetHistory --template "HTTP trigger"
   npm install @azure/functions @azure/signalr
   ```

2. **Implement `SendMessage` function**
   ```typescript
   // SendMessage/index.ts
   import { AzureFunction, Context, HttpRequest } from '@azure/functions';
   import { exec } from 'child_process';
   import { promisify } from 'util';
   
   const execAsync = promisify(exec);
   
   const httpTrigger: AzureFunction = async function (context: Context, req: HttpRequest) {
     const { message, agent } = req.body;
     
     // Validate Azure AD token (middleware already did this)
     const user = req.headers['x-ms-client-principal-name']; // Azure Static Web App provides this
     
     // Route to agent
     const agentFlag = agent ? `--agent=${agent}` : '';
     const command = `gh copilot ${agentFlag} "${message}"`;
     
     try {
       const { stdout } = await execAsync(command, { 
         timeout: 30000, // 30s timeout
         env: { 
           GITHUB_TOKEN: process.env.GITHUB_TOKEN,
           SQUAD_ROOT: '/tmp/squad-cache/.squad' // Clone .squad/ to temp on first run
         }
       });
       
       // Push response via SignalR
       context.bindings.signalRMessages = [{
         target: 'receiveMessage',
         arguments: [{ 
           agent: agent || 'picard', 
           text: stdout,
           timestamp: new Date().toISOString()
         }]
       }];
       
       context.res = { status: 200, body: { success: true } };
     } catch (error) {
       context.res = { status: 500, body: { error: error.message } };
     }
   };
   
   export default httpTrigger;
   ```

3. **Configure SignalR binding** (`function.json`)
   ```json
   {
     "bindings": [
       {
         "type": "httpTrigger",
         "direction": "in",
         "name": "req"
       },
       {
         "type": "signalR",
         "direction": "out",
         "name": "signalRMessages",
         "hubName": "squadChat",
         "connectionStringSetting": "AzureSignalRConnectionString"
       }
     ]
   }
   ```

4. **Deploy to Azure**
   ```bash
   az login
   az group create --name squad-chat-rg --location westus2
   az functionapp create --name squad-chat-api --resource-group squad-chat-rg \
     --consumption-plan-location westus2 --runtime node --runtime-version 18
   func azure functionapp publish squad-chat-api
   ```

5. **Connect PWA to backend**
   ```typescript
   // src/services/squadApi.ts
   import * as signalR from '@microsoft/signalr';
   
   const API_BASE = 'https://squad-chat-api.azurewebsites.net';
   
   const connection = new signalR.HubConnectionBuilder()
     .withUrl(`${API_BASE}/api`)
     .withAutomaticReconnect()
     .build();
   
   connection.on('receiveMessage', (message) => {
     // Update chat UI with new message
     console.log('Received:', message);
   });
   
   export async function sendMessage(text: string, agent?: string) {
     const token = sessionStorage.getItem('azure_ad_token');
     const response = await fetch(`${API_BASE}/api/send`, {
       method: 'POST',
       headers: {
         'Authorization': `Bearer ${token}`,
         'Content-Type': 'application/json'
       },
       body: JSON.stringify({ message: text, agent })
     });
     return response.json();
   }
   ```

**Deliverable:** Working chat where messages sent from phone get responses from Copilot CLI

---

### Day 3-5: Polish & Production

**Tasks:**
1. **Add CosmosDB for chat history**
   - Store all messages with timestamps
   - Implement `GET /api/history` endpoint
   - Display conversation history when PWA loads

2. **Improve agent routing**
   - Parse `.squad/routing.md` in Azure Function
   - Implement smart keyword-based routing
   - Add visual indicators for which agent is responding

3. **Enhanced UX**
   - Add agent avatars (Picard, Data, Seven icons)
   - Typing indicators while waiting for response
   - Toast notifications for errors
   - Dark mode (squad color scheme: #9B8FCC purple)

4. **Security hardening**
   - Add rate limiting (max 100 messages/hour per user)
   - Validate message length (max 2000 chars)
   - Sanitize input to prevent injection
   - Add CORS restrictions

5. **Deploy to production**
   - Configure custom domain: `squad.tamirdresher.dev`
   - Enable HTTPS (auto via Azure Static Web Apps)
   - Set up GitHub Actions CI/CD
   - Test on Android in production

**Deliverable:** Production-ready mobile Squad chat

---

## Future Enhancements

### Phase 2: Rich Media
- **Voice messages:** Record audio on Android → Azure Speech-to-Text → send as text message
- **File sharing:** Upload files (logs, screenshots) → Azure Blob Storage → attach to message
- **Image generation:** Integrate DALL-E for visual responses
- **Code snippets:** Syntax-highlighted code blocks in chat

### Phase 3: Collaboration
- **Multi-device sync:** Use CosmosDB as single source of truth, sync across laptop + phone
- **Shared chat sessions:** Multiple users can chat with same squad instance
- **Conversation threads:** Branch conversations for different topics

### Phase 4: Proactive Notifications
- **Push notifications:** Azure Notification Hubs for Android push (agent mentions you, urgent issues)
- **Daily standup:** Squad sends morning summary of overnight activity
- **CI/CD alerts:** Build failures, PR reviews pushed to mobile

### Phase 5: Advanced Features
- **Voice mode:** Full voice conversation (Speech-to-Text + Text-to-Speech)
- **Agent status:** See which agents are currently working, queue depth
- **Context switching:** "Show me all conversations about issue #489"
- **Search:** Full-text search across all past chats

---

## Appendix: Alternative Options Analysis

### Option B: Azure Communication Services (ACS) Chat

**Pros:**
- Native mobile SDK (official Android library)
- Built-in chat UI components
- Push notifications out-of-box
- Message read receipts, typing indicators

**Cons:**
- **Cost:** Not free — $0.40 per 1000 messages (adds up fast)
- **Complexity:** Requires ACS identity management on top of Azure AD
- **Less flexible:** Harder to customize UI to feel "squad-like"
- **Overkill:** Designed for multi-tenant customer chat, not personal assistant

**Verdict:** ❌ Too expensive and over-engineered for single-user Squad chat

---

### Option C: Azure Bot Service + Teams

**Pros:**
- Built on Bot Framework (well-documented)
- Integrates with Microsoft Teams (already on phone)
- Adaptive Cards for rich UI
- Free tier (1000 messages/month)

**Cons:**
- **Approval wall:** Requires tenant admin to approve custom bot for org (Tamir tried, got blocked)
- **Limited conversational AI:** Bot Framework designed for stateless request/response, not continuous conversation
- **Teams overhead:** Full Teams client is heavy, not as snappy as lightweight chat
- **Personal bot limitations:** If deployed as personal bot (no admin approval), loses some features

**Verdict:** ⚠️ Possible but bureaucratic; Tamir already tried and hit approval issues

---

### Option D: Azure Container App + Open WebUI

**Pros:**
- Full control over UI (can clone Open WebUI or ChatGPT-style interface)
- Supports WebSocket for real-time
- Can bundle Copilot CLI in container
- Mature open-source chat UIs available

**Cons:**
- **Not free:** Container Apps require always-on container (minimum $15-30/month)
- **Maintenance:** Need to manage container lifecycle, restarts, updates
- **Not PWA:** Just a web page, not installable as app
- **Auth complexity:** Need to implement Azure AD auth manually (not built-in like Static Web App)

**Verdict:** ⚠️ Works but higher cost and maintenance than Option A

---

### Option E: Telegram/Discord Bot (from issue #489)

**Pros:**
- ✅ **Fastest to build:** Bot APIs are dead simple
- ✅ **Best UX:** Telegram/Discord apps are polished, rich features
- ✅ **Free:** No Azure costs at all
- ✅ **Rich media:** Voice, files, markdown, inline keyboards native

**Cons:**
- ❌ **Not Azure native:** Tamir specifically requested Azure services
- ❌ **External dependency:** Relies on Telegram/Discord infrastructure
- ⚠️ **Security:** Bot token is the only auth (no Azure AD SSO)

**Verdict:** 🤔 **Actually the pragmatic winner** if we ignore the "Azure native" requirement. For a personal Squad chat, Telegram bot is superior in every way except corporate compliance.

**Compromise Hybrid Approach:**
- Use **Telegram Bot for frontend** (best UX)
- **Azure Function as backend bridge** (satisfies Azure requirement)
- Telegram → Azure Function → Copilot CLI → Azure Function → Telegram

---

## Recommendation Summary

### Primary: Option A (Azure Static Web App + Functions + SignalR)
- Best balance of Azure-native, UX, cost, and maintenance
- Meets all requirements in the issue
- MVP in 1-2 days, production-ready in 5 days

### Pragmatic Alternative: Telegram Bot + Azure Function Bridge
- If Tamir is open to non-Azure frontend, this is **objectively better UX**
- Telegram app is already on phone, polished, supports rich media
- Still uses Azure for backend (Function processes messages)
- **Fastest path to working solution (can build in 4 hours)**

**Recommended Path Forward:**
1. Build **Telegram bot** first (4-hour MVP)
2. If Tamir loves it → keep it, add Azure Function backend
3. If corporate compliance requires pure Azure → migrate to Option A PWA

---

## Questions for Tamir

1. **Flexibility on frontend:** Must it be 100% Azure, or is Telegram/Discord frontend acceptable if backend uses Azure?
2. **Multi-user future:** Will other team members need Squad mobile access, or just you?
3. **Existing Azure subscription:** Do you already have an Azure subscription, or need to set one up?
4. **Custom domain:** Do you own `tamirdresher.dev` or similar for hosting?
5. **Android version:** What Android version (affects PWA features)?

---

**Next Steps:**
- [ ] Get Tamir's answers to questions above
- [ ] Prototype Telegram bot (4 hours) as proof-of-concept
- [ ] If approved, build Azure Static Web App MVP (2 days)
- [ ] Deploy to production (1 day)
- [ ] Iterate on agent routing and UX polish

**Estimated Total Effort:** 5-7 days to production-ready mobile Squad chat

---

**End of Architecture Document**
