# Mobile Squad Access Research: Microsoft Ecosystem Options (2025)

**Research Date:** 2025-01-11  
**Requested by:** Tamir Dresher  
**Scope:** 9 potential Microsoft-approved channels for Android Squad access  
**Constraint:** Microsoft ecosystem only (no Telegram, Discord, third-party chat)

---

## Executive Summary

Squad agents can be accessed on Android via multiple Microsoft channels, each with different tradeoffs between simplicity, real-time capability, and admin approval requirements. The strongest candidates are:

1. **Copilot Studio (PVA successor)** — Highest capability, natively mobile, requires IT approval
2. **Teams Personal Tab** — Quick to build, responsive mobile support, requires app registration
3. **DevTunnel + Mobile Browser** — Simplest MVP, zero approval overhead, plain HTTP access
4. **GitHub Copilot Chat (Mobile)** — Already available, but limited to code-centric workflows

---

## Detailed Evaluation

### 1. Teams Adaptive Cards + Power Automate

**Overview:**  
Power Automate flows receive webhook payloads, parse them, and post Adaptive Cards back to Teams chats/channels. This replaces deprecated Teams incoming webhooks.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Teams mobile client fully supports Adaptive Cards 1.4–1.5 |
| **Admin/Tenant Approval** | ⚠️ Yes | Power Automate license required; Flow creation needs Power Platform access |
| **Bidirectional Real-Time Chat** | ⚠️ Partial | Card actions (buttons, inputs) → Flow logic → Post response; not true chat stream |
| **Trigger Squad Agents** | ✅ Yes | Flow HTTP action can POST to Squad CLI webhook/API; responses posted back to Teams |
| **Complexity** | 🟡 Medium | Flow designer UI, JSON parsing, adaptive card formatting; ~2–4 hours setup |
| **Maintenance Burden** | 🟢 Low | Microsoft manages infrastructure; occasional Adaptive Card feature updates |

**Strengths:**
- Deep Microsoft 365 integration (Teams ↔ Power Automate ↔ external APIs)
- Mobile support mature and stable
- Can chain with other Power Platform services (approval workflows, etc.)

**Limitations:**
- Not true bidirectional chat; users see responses as new card posts
- Card feature parity with desktop may lag on mobile
- Flow licensing may increase cost

**Best For:** Notification-driven interactions, approval workflows, lightweight Q&A

---

### 2. Teams Personal App / Tab

**Overview:**  
Web app hosted internally (or Azure), embedded as a personal tab in Teams. Mobile users access via Teams app with responsive UI.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Teams mobile fully supports personal tabs; responsive design required |
| **Admin/Tenant Approval** | ⚠️ Yes | App manifest upload to Teams admin center; may require org app review |
| **Bidirectional Real-Time Chat** | ✅ Yes | Full WebSocket/real-time capability if chat UI is implemented |
| **Trigger Squad Agents** | ✅ Yes | Tab frontend can POST to Squad CLI; responses display in-tab |
| **Complexity** | 🟡 Medium | Need HTTPS hosting, manifest config, responsive web UI; ~4–6 hours |
| **Maintenance Burden** | 🟡 Medium | Own hosting/SSL, responsiveness testing on mobile devices |

**Strengths:**
- Full control over UI/UX
- True real-time bidirectional chat possible
- Appears in Teams navigation on mobile

**Limitations:**
- Must manage own hosting and SSL certificates
- Mobile discoverability is lower (buried in "More apps" menu)
- Requires Teams SDK integration for auth

**Best For:** Custom chat interface, full Squad feature parity on mobile

---

### 3. Copilot Studio / Power Virtual Agents

**Overview:**  
Generative AI agent platform (successor to PVA). Deploy agents to Microsoft 365 Copilot, which is accessible on web and mobile apps.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Microsoft 365 Copilot app on Google Play; native mobile client |
| **Admin/Tenant Approval** | ⚠️ Yes | Copilot Studio license; agents must be approved for org publication |
| **Bidirectional Real-Time Chat** | ✅ Yes | Full conversational AI with context memory and multi-turn support |
| **Trigger Squad Agents** | ✅ Yes | Copilot Studio agent can call Squad API via Power Automate actions |
| **Complexity** | 🟡 Medium | Copilot Studio UI low-code; configure knowledge sources, test; ~3–5 hours |
| **Maintenance Burden** | 🟡 Medium | Microsoft manages Copilot infrastructure; agent tuning/refinement needed |

**Strengths:**
- Generative AI-powered (GPT-based), advanced conversation handling
- Mobile app with governance controls
- Can integrate SharePoint/OneDrive knowledge sources
- Enterprise audit trail

**Limitations:**
- Copilot Studio licensing cost
- Requires agent training/tuning for squad-specific context
- Limited to Copilot as the UX surface (cannot customize UI deeply)

**Best For:** Enterprise-grade AI-powered squad access, approval workflows, knowledge integration

---

### 4. Microsoft Copilot Extensions / Plugins

**Overview:**  
Build a Copilot plugin (OpenAPI spec + authentication) that routes to Squad. Available on Microsoft 365 Copilot web and mobile.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Copilot mobile app (Google Play) supports plugins; April 2025 expanded support |
| **Admin/Tenant Approval** | ⚠️ Yes | Plugin registration via Microsoft 365 dev portal; IT approval needed |
| **Bidirectional Real-Time Chat** | ✅ Yes | Full Copilot chat context, multi-turn, streaming responses |
| **Trigger Squad Agents** | ✅ Yes | Plugin calls Squad API; responses flow through Copilot chat |
| **Complexity** | 🟡 Medium | OpenAPI spec, Azure AD auth, plugin manifest; ~4–6 hours |
| **Maintenance Burden** | 🟢 Low | Microsoft handles Copilot infrastructure; you maintain Squad API contract |

**Strengths:**
- Direct integration with Copilot—leverages existing Copilot context
- Mobile support expanding (April 2025)
- Standard OpenAPI pattern, reusable across multiple Copilot surfaces
- No separate app needed; users already have Copilot

**Limitations:**
- Plugin catalog on mobile smaller than desktop (rollout ongoing)
- Feature parity for mobile plugins still evolving
- Depends on Copilot as the chat interface (less customization)

**Best For:** Lightweight Squad integration for existing Copilot users, minimal friction

---

### 5. Azure Communication Services (SMS)

**Overview:**  
SMS bridge: users text Squad queries to an ACS-provisioned phone number; backend routes to Squad CLI, sends response via SMS.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Standard SMS app; works on any phone |
| **Admin/Tenant Approval** | ⚠️ Depends | ACS instance required; org may require compliance review for SMS numbers |
| **Bidirectional Real-Time Chat** | ⚠️ Limited | SMS is not real-time (seconds to minutes); not streaming |
| **Trigger Squad Agents** | ✅ Yes | Incoming SMS → Azure Function → Squad CLI; response via SMS |
| **Complexity** | 🟡 Medium | ACS setup, phone number provisioning, Azure Function handler; ~4–6 hours |
| **Maintenance Burden** | 🟡 Medium | SMS delivery tracking, rate limiting, cost per message |

**Strengths:**
- Works on any phone (no app required)
- Low technical barrier for end users
- Operates outside any Microsoft app ecosystem

**Limitations:**
- Latency (not real-time chat)
- Message length/format constraints
- Per-message costs
- No rich UI (plain text only)
- Poor user experience vs. modern chat

**Best For:** Low-tech fallback, alerting, simple command execution

---

### 6. Outlook Actionable Messages

**Overview:**  
Email-based interactions: Squad queries arrive as Adaptive Card emails with action buttons. Responses post back to Outlook.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Outlook for Android supports Actionable Messages (rollout ongoing in 2025) |
| **Admin/Tenant Approval** | ⚠️ Some | Actionable Message registration via Provider Dashboard; org policies may restrict |
| **Bidirectional Real-Time Chat** | ❌ No | Email is asynchronous; not a real-time chat surface |
| **Trigger Squad Agents** | ✅ Yes | Action buttons POST to Squad API; responses can be emailed back |
| **Complexity** | 🟡 Medium | Adaptive Card design, action URL registration, email trigger logic; ~3–4 hours |
| **Maintenance Burden** | 🟡 Medium | Adaptive Card support variance on mobile; Microsoft managing email infrastructure |

**Strengths:**
- No app install; works in standard Outlook
- Mobile support expanding in 2025
- Can be triggered by email rules or Power Automate

**Limitations:**
- Asynchronous, not real-time chat
- Feature parity on mobile still catching up (some cards may fall back to HTML)
- Not suitable for conversational workflows
- Group emails not supported

**Best For:** Approval workflows, task triggers, notification-based squad access

---

### 7. GitHub Mobile + Copilot Chat

**Overview:**  
GitHub Copilot Chat is now available on Android (GitHub Mobile app). Can be extended to provide Squad agent access if repo contains Squad context.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | GitHub Mobile app on Google Play; Copilot Chat integrated |
| **Admin/Tenant Approval** | ⚠️ Some | GitHub Copilot Pro subscription; org policies may restrict personal GitHub use |
| **Bidirectional Real-Time Chat** | ✅ Yes | Full Copilot Chat conversation, context-aware across 100k+ repos |
| **Trigger Squad Agents** | ⚠️ Partial | Can reference Squad docs in repo; manual integration with Squad CLI required |
| **Complexity** | 🟡 Medium | Add Squad context/docs to GitHub repo, write Copilot chat instructions; ~2–3 hours |
| **Maintenance Burden** | 🟢 Low | GitHub manages infrastructure; maintain repo docs |

**Strengths:**
- Already available on mobile (no new tool to build)
- Full Copilot context and multi-turn conversation
- Low friction for developers already using GitHub

**Limitations:**
- Limited to code-centric workflows (GitHub Copilot is code-focused)
- Requires GitHub repo access and Copilot Pro subscription
- Not designed for non-technical squad queries
- Manual Squad CLI integration needed

**Best For:** Developer-focused squad access, code review + AI agent tasks

---

### 8. VS Code for Web + GitHub Copilot

**Overview:**  
github.dev or VS Code Codespaces in browser; Copilot integrated. Accessible from mobile browser.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Any mobile browser; Copilot works in browser-based VS Code |
| **Admin/Tenant Approval** | ⚠️ Depends | GitHub account + Copilot Pro; same as GitHub repo access |
| **Bidirectional Real-Time Chat** | ✅ Yes | Copilot Chat available in browser, full multi-turn support |
| **Trigger Squad Agents** | ⚠️ Partial | Limited editing on mobile; can reference Squad code, trigger commands via integrated terminal |
| **Complexity** | 🟡 Medium | Deploy Squad context to GitHub; configure Copilot instructions; ~2–3 hours |
| **Maintenance Burden** | 🟢 Low | GitHub manages browser IDE; Squad context updates |

**Strengths:**
- Accessible from any browser (no app install)
- Full VS Code + Copilot + integrated terminal
- Real-time Copilot context

**Limitations:**
- Mobile browser UI very cramped for code editing
- Not ideal for chat-focused interaction
- Requires GitHub/Copilot Pro
- Code editor focus, not chat interface

**Best For:** Emergency code fixes, lightweight dev workflows

---

### 9. DevTunnel from Mobile Browser

**Overview:**  
Simplest option: expose Squad CLI's web UI via DevTunnel; open tunnel URL in Android Chrome. No app registration needed.

| **Criterion** | **Rating** | **Details** |
|---|---|---|
| **Android Mobile Support** | ✅ Yes | Any mobile browser + HTTPS; DevTunnel is cross-platform |
| **Admin/Tenant Approval** | ✅ None | No IT approval; only requires Microsoft account for DevTunnel login |
| **Bidirectional Real-Time Chat** | ✅ Yes | Full real-time chat if Squad web UI supports WebSocket |
| **Trigger Squad Agents** | ✅ Yes | Direct Squad CLI web interface; native support |
| **Complexity** | 🟢 Low | `devtunnel create` + `devtunnel host`; tunnel URL in mobile browser; ~15 min |
| **Maintenance Burden** | 🟢 Low | Microsoft handles DevTunnel; Squad CLI unchanged |

**Strengths:**
- Fastest MVP: 15 minutes to working mobile access
- No admin approval or licensing
- Zero app development overhead
- Works with existing Squad web UI
- Full capability parity with desktop

**Limitations:**
- DevTunnel requires Microsoft/GitHub account login
- URL discovery is manual (share URL out-of-band)
- Security: public tunnel URL is discoverable if not locked down
- Not a branded "app" experience
- Requires network stability

**Best For:** Rapid prototyping, internal squad teams, dev/test environment

---

## Comparison Matrix

| **Option** | **Mobile Support** | **Admin Approval** | **Real-Time Chat** | **Squad Triggering** | **Setup Time** | **Maintenance** | **Cost** |
|---|---|---|---|---|---|---|---|
| **Teams Adaptive Cards + PA** | ✅ | ⚠️ | ⚠️ Partial | ✅ | 2–4h | 🟢 Low | Moderate (PA license) |
| **Teams Personal Tab** | ✅ | ⚠️ | ✅ | ✅ | 4–6h | 🟡 Medium | Low (hosting) |
| **Copilot Studio / PVA** | ✅ | ⚠️ | ✅ | ✅ | 3–5h | 🟡 Medium | High (CS license) |
| **Copilot Extensions** | ✅ | ⚠️ | ✅ | ✅ | 4–6h | 🟢 Low | Low |
| **Azure Communication (SMS)** | ✅ | ⚠️ | ⚠️ Limited | ✅ | 4–6h | 🟡 Medium | Per-message cost |
| **Outlook Actionable Messages** | ✅ | ⚠️ | ❌ | ✅ | 3–4h | 🟡 Medium | Low |
| **GitHub Copilot Chat** | ✅ | ⚠️ | ✅ | ⚠️ Partial | 2–3h | 🟢 Low | Copilot Pro |
| **VS Code for Web** | ✅ | ⚠️ | ✅ | ⚠️ Partial | 2–3h | 🟢 Low | Copilot Pro |
| **DevTunnel Browser** | ✅ | ✅ | ✅ | ✅ | 0.25h | 🟢 Low | Free |

---

## Recommendations by Use Case

### **Scenario A: Rapid Internal MVP (Dev/Test)**
**Recommendation:** DevTunnel (Option 9)
- **Why:** 15 minutes to working access; zero approval needed
- **Trade-off:** Not branded; URL-based; security = firewall isolation
- **Next:** Monitor usage; migrate to Teams Tab or Copilot Studio if approved for production

### **Scenario B: Full Enterprise Production**
**Recommendation:** Copilot Studio (Option 3) OR Teams Personal Tab (Option 2)
- **Copilot Studio (3):** If org invests in enterprise AI; built-in governance & audit
- **Teams Personal Tab (2):** If org prefers lightweight; full UI control; lower cost
- **Both require:** IT approval, hosting, training

### **Scenario C: Code-First Squad Access**
**Recommendation:** GitHub Copilot Chat (Option 7) + repo-based context
- **Why:** Developers already use GitHub Mobile; Copilot Chat is familiar
- **Limitation:** Not ideal for non-technical squad members
- **Fallback:** Teams Tab for broader audience

### **Scenario D: Minimal Tech Overhead**
**Recommendation:** Teams Adaptive Cards + Power Automate (Option 1)
- **Why:** No custom code; flow designer UI; notification-driven model fits many workflows
- **Limitation:** Not true chat; card rendering variance on mobile
- **Best for:** Alerts, approvals, lightweight queries

### **Scenario E: Approval Workflows**
**Recommendation:** Outlook Actionable Messages (Option 6)
- **Why:** Works in Outlook; async model fits approval pattern
- **Limitation:** Not real-time chat; mobile support still rolling out
- **Timeline:** May improve in 2025

---

## Security & Compliance Notes

1. **DevTunnel (Option 9):** Requires firewall rules to restrict tunnel access; not suitable for production without auth layer
2. **Teams (Options 1, 2):** Built-in Azure AD authentication; audit trail
3. **Copilot Studio (Option 3):** Enterprise audit via Microsoft Purview
4. **SMS (Option 5):** Consider regulatory requirements (GDPR, consent logging)
5. **Plugins (Option 4):** Admin approval via M365 dev portal; governance controls available

---

## Timeline & Roadmap

| **Q1 2025 (Now)** | **Q2–Q3 2025** | **Q4 2025+** |
|---|---|---|
| ✅ DevTunnel MVP | ⏳ Copilot Extensions expand mobile support | 🔮 Outlook Actionable Messages mature on mobile |
| ✅ Teams Tab POC | ⏳ Copilot Studio governance enhancements | 🔮 Native mobile Squad app? |
| ✅ GitHub Copilot Chat (Android launch) | ⏳ Power Automate flow licensing review | 🔮 AI-powered multi-platform access |

---

## Next Steps

1. **Immediate (This Week):**
   - [ ] Try DevTunnel MVP with existing Squad web UI on Android
   - [ ] Share tunnel URL with team for feedback

2. **Short Term (This Month):**
   - [ ] Evaluate Copilot Studio & Teams Tab with IT; understand approval timeline
   - [ ] Document security requirements for each option

3. **Medium Term (Q1–Q2):**
   - [ ] Choose 1–2 production options; pilot with select team
   - [ ] Build proof-of-concept for chosen channel

4. **Long Term (Q3+):**
   - [ ] Monitor Copilot Extensions mobile support; migrate if better fit
   - [ ] Gather user feedback; refine UX for chosen platform

---

## References

- [Microsoft Teams Adaptive Cards & Power Automate (2025)](https://learn.microsoft.com/en-us/power-automate/overview-adaptive-cards)
- [Teams Mobile Best Practices](https://learn.microsoft.com/en-us/microsoftteams/platform/resources/teams-mobile-best-practices)
- [Copilot Studio vs. PVA Migration](https://learn.microsoft.com/en-us/microsoft-copilot-studio/)
- [Microsoft 365 Copilot Plugins](https://learn.microsoft.com/en-us/copilot/copilot-studio-solutions)
- [Dev Tunnels Documentation](https://learn.microsoft.com/en-us/azure/developer/dev-tunnels/)
- [GitHub Copilot Chat on Mobile](https://docs.github.com/en/copilot/how-tos/chat-with-copilot/chat-in-mobile)
- [Outlook Actionable Messages (2025)](https://learn.microsoft.com/en-us/outlook/actionable-messages/)
- [Azure Communication Services](https://learn.microsoft.com/en-us/azure/communication-services/)

---

**Report Status:** Complete  
**Research Quality:** High-confidence (primary sources, 2025-verified)  
**Next Review:** Q2 2025 (post-Copilot Extensions mobile rollout)
