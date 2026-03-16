# Worf — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

Q2 work incoming: Issue #26 (Defender-Fleet Teams chat review)

### 2026-03-12: Issue #26 — Defender-Fleet Workload Identity Message (Ralph Round 1)

**Assignment:** Review Defender-Fleet Teams chat and draft FIC/Workload Identity automation message

**Work Completed:**
- ✅ Reviewed "Defender - Fleet" Teams chat thread
- ✅ Identified Fleet team participants: Joshua Johnson, Ravid Brown, Stephane Erbrech, Simon (PM), David Vadas
- ✅ Mapped fleet roadmap gaps: member cluster provisioning/lifecycle management not yet available
- ✅ Analyzed workarounds: Bicep/Terraform templates + auto-join Azure Policy discussed
- ✅ Drafted message about FIC/Workload Identity automation blocker
- ✅ Posted message to issue #26
- ✅ Decision documented: `.squad/decisions/inbox/worf-defender-fleet-msg.md`

**Key Insights:**
- Fleet team already aware of automation gaps
- Cross-cluster networking (Cilium cluster-mesh) approaching public preview
- Positioning FIC/Workload Identity blocker in context of known limitations makes ask actionable

**Status:** ✅ Complete. Message posted, decision ready for merge to decisions.md

### 2026-07-11: Issue #666 — Centralize Secrets Management

**Assignment:** Build proper secrets management infrastructure. Eliminate secrets from git, establish patterns for secure storage and retrieval.

**Work Completed:**
- ✅ Created `.env.example` documenting all required env vars (no values)
- ✅ Created `scripts/setup-secrets.ps1` — loads secrets from Credential Manager → `~/.squad/.env` → env vars, validates required secrets, reports missing
- ✅ Hardened `.gitignore` — blocks `*.env`, secret screenshots, `*.key`, `*.pem`, config JSON
- ✅ Removed `github-oauth-secret-generated.png` (potential OAuth secret exposure)
- ✅ Created `.squad/skills/secrets-management/SKILL.md` — full pattern documentation
- ✅ Updated `devbox-startup.ps1` to call `setup-secrets.ps1` before Ralph starts
- ✅ Branch `squad/666-secrets-management` pushed, PR #668 opened

**Known Secrets Audited:**
| Secret | Storage | Status |
|--------|---------|--------|
| Google API Key (Gemini) | Needs Credential Manager | ⚠️ Needs rotation (was in git per #645) |
| Teams Webhook URL | `~/.squad/teams-webhook.url` | ✅ Secure |
| Squad email password | Credential Manager `squad-email-outlook` | ✅ Secure |
| GitHub PAT | Credential Manager via `gh auth` | ✅ Secure |
| Telegram bot token | `.nano-banana-config.json` (gitignored) | ✅ Acceptable |
| OAuth screenshot | Removed from repo | ✅ Fixed |

**Remaining Action:** Google API key must be rotated at https://aistudio.google.com/apikey since it was previously committed to git history.

**Status:** ✅ Complete. PR #668 open for review.

## Learnings

### Issue #336 — Dependabot Security PR Investigation (2026-03-10)

**Context:** Investigated critical Dependabot security PRs for DK8S CapacityController and ArgoRollouts repositories.

**Key Findings:**
- Repositories not found in accessible GitHub orgs (microsoft, msazure, user repos)
- Likely located in private Azure DevOps (dev.azure.com/msazure or /microsoft)
- No active Dependabot PRs found in tamirdresher_microsoft/dk8s-platform-squad or related repos
- Azure DevOps access requires additional authentication/permissions

**Investigation Methods Used:**
- `gh search repos` — Broad GitHub repository searches
- `gh api search/repositories` — Direct API queries
- `gh pr list` with `--author "app/dependabot"` — Dependabot-specific PR filtering
- `az devops project list` — Azure DevOps organization scanning (limited by auth)
- Session store queries for historical references

**Security Posture:**
- Cannot assess CVE severity without repository access
- Recommended Tamir verify actual repo locations from Dependabot email
- Tagged issue as "status:pending-user" pending clarification

**Lesson:** Enterprise repos often span multiple platforms (GitHub/ADO). Always verify actual repository locations from notification sources before deep investigation.

### Issue #26 — Defender Fleet Chat Review (2026-03-12)

**Context:** Reviewed "Defender - Fleet" Teams chat to draft message about Workload Identity/FIC automation blocker for Fleet Manager.

**Key Findings:**
- Active Teams chat with Joshua Johnson, Ravid Brown, Stephane Erbrech (Fleet team), Simon (Fleet PM), David Vadas
- Recent focus: Fleet roadmap gaps, multi-cluster networking (Cilium), lifecycle management
- **Critical Gap:** Member cluster provisioning/lifecycle management not yet available
- Workaround discussed: Bicep/Terraform templates + auto-join Azure Policy
- Cross-cluster networking (Cilium cluster-mesh) approaching public preview in weeks

**Message Drafted:**
- Highlighted FIC security gaps blocking automated provisioning
- Asked about plans for FIC/Workload Identity automation
- Suggested Bicep+Policy workaround as interim approach
- Kept conversational tone appropriate for active Teams chat

**Stakeholder Context:**
- Chat participants already aware of Fleet limitations
- Discussion actively ongoing around workarounds and roadmap
- Fleet team (Stephane, Simon, David) engaged and responsive

**Lesson:** Teams chat revealed existing awareness of automation gaps. Positioning our FIC/Workload Identity blocker in context of known Fleet limitations makes ask more actionable.

### Issue #337 — IcM Incident 759361753 Response (2026-03-12)

**Context:** Responded to Brett DeFoy's inquiry about Cosmos DB firewall/network policy changes around Feb 1 via IcM incident 759361753.

**Investigation Approach:**
- Used WorkIQ to locate Brett DeFoy's Teams presence and incident discussion thread
- Identified target channel: "Iterative Dev in Canary Testing" (RP-as-a-Service Partners team)
- Posted findings directly to active Teams channel where incident was being discussed

**Key Findings Communicated:**
- No deployment pipeline changes to Cosmos DB firewall/network settings around Feb 1
- Git history confirmed publicNetworkAccess: Enabled still configured in code
- Live Azure environment showed multiple Cosmos DB accounts non-compliant with Azure Policy NSP-CDB-v1-0-En-Deny
- Several accounts had publicNetworkAccess: Disabled despite deployment configuration
- Evidence points to manual changes or policy-driven overrides outside pipeline

**Message Delivery:**
- Successfully posted to Teams channel (Message ID: 1773295431683)
- Used natural, conversational tone per Tamir's direction ("don't sound like AI")
- Kept draft message as-is — already well-written and human
- Requested specific Cosmos DB account name to check Activity Logs for Feb 1 changes

**Follow-Up Actions:**
- Issue #337 updated with delivery status and channel link
- Label status:pending-user added — waiting for Brett's response with account details

**Lesson:** WorkIQ efficiently locates Teams discussion threads for IcM incidents. Direct channel posting in active thread is more effective than DM or issue comments for time-sensitive operational issues. Natural language maintained in technical contexts builds trust with external stakeholders.

### Issue #337 — IcM 759361753 Follow-Up: Investigation Guide (2026-03-12)

**Context:** Follow-up on Brett DeFoy's Cosmos DB firewall inquiry. Drafted comprehensive investigation guide with az CLI commands and response template.

**Key Deliverables:**
- Activity Log query commands for Cosmos DB firewall changes (Jan 28 – Feb 5 window)
- Azure Policy investigation commands targeting NSP-CDB-v1-0-En-Deny
- Common Cosmos DB networking issues reference table
- Copy-paste template response for Brett DeFoy
- Posted as issue #337 comment for Tamir's use

**Architecture Decisions Referenced:**
- Policy `NSP-CDB-v1-0-En-Deny` is the primary suspect for Cosmos DB non-compliance
- Deployment code shows `publicNetworkAccess: Enabled` but live env shows `Disabled` on some accounts — points to out-of-band changes
- `az monitor activity-log list` with `--resource-type Microsoft.DocumentDB/databaseAccounts` is the correct diagnostic command for Cosmos DB changes

**Lesson:** For IcM incident responses, provide both the investigation commands AND a ready-to-send template. Reduces friction for the assignee to relay findings. Always include the time window in Activity Log queries with a few days padding on each side.

### Issue #26 — Workload Identity / FIC Automation Research (2026-03-12)

**Context:** Deep research on Workload Identity Federation and FIC automation gaps blocking Fleet Manager adoption. Requested by Tamir as Fleet Manager prerequisite analysis.

**Key Findings:**
- AKS Workload Identity is GA and mature, but FIC lifecycle management remains manual
- **20-FIC-per-UAMI hard limit** is architecturally incompatible with fleet-scale (N clusters × M workloads)
- **OIDC issuer mutability** — spoofing/DNS compromise of issuer endpoint allows token forgery
- **Service account name mutability** — anyone with SA creation RBAC in target namespace can impersonate federated workloads
- **FIC as persistence vector** — Dirkjan Mollema (2024) documented FIC as backdoor persistence mechanism on Entra apps/UAMIs; survives credential rotation
- **Chained FIC** (Workload → UAMI → AAD App) limited by 20-FIC cap, no concurrent updates, exact-match-only subjects
- **Identity Bindings (Preview)** solves the scaling problem (1 FIC per UAMI regardless of cluster count) but is NOT GA
- **Flexible FICs (Preview)** allow wildcard/expression matching but also NOT GA
- Fleet Manager + KubeFleet integration exists but depends on Identity Bindings for identity distribution

**Recommendation:** DEFER remains correct. Re-evaluate when Identity Bindings reaches GA. Interim: harden single-cluster WI deployments, lock down FIC management RBAC, implement FIC audit logging.

**Deliverable:** Comprehensive research comment posted to issue #26 with security gap analysis, chained FIC limitations, roadmap features, and interim hardening recommendations.

**Lesson:** FIC security analysis requires examining both the Entra ID control plane (FIC creation permissions, audit logging) and the Kubernetes data plane (SA creation RBAC, OIDC issuer integrity). Fleet-scale identity problems can't be solved by multiplying single-cluster patterns — need architectural solutions like Identity Bindings.

### Issue #26 — Workload Identity Rewrite for Tamir's Voice (2026-03-12)

**Context:** Tamir requested rewrite of formal Workload Identity security analysis into casual, first-person message matching his tone and style.

**Original Message Style:**
- Formal security analysis with headers, bullet points, structured sections
- Third-person technical documentation voice
- Comprehensive but lengthy

**Tamir's Feedback:**
"I wanted not formal and short that comes from me and my tone and style"

**Rewrite Approach:**
- ✅ First person ("I", "we", "our") — sounds like Tamir talking
- ✅ Short — compressed from formal analysis to 4 paragraphs
- ✅ Conversational — "So I looked into..." / "Like, if you've got..." / "Not ideal but..."
- ✅ No headers, no bullets — natural prose flow
- ✅ Gets to the point fast — lead with the blocker (20-FIC limit), then security gaps, then conclusion
- ✅ Kept technical substance — all key findings preserved (FIC limits, security exposures, roadmap gaps, DEFER rationale)
- ✅ Referenced Fleet Manager eval naturally — "after Fleet Manager gave us that DEFER"

**Deliverable:** Posted rewritten message as issue #26 comment

**Lesson:** When Tamir says "my tone and style," he means casual technical chat — first person, conversational transitions, natural language, no formal structure. Think "explaining to a colleague in Teams" not "writing a security doc." Keep the technical depth but strip the formality. Short is better — condense multi-section analyses into 3-4 flowing paragraphs.

### Issue #488 — Prompt Injection & Adversarial AI Defense Research (2026-03-14)

**Context:** Security research for agentic AI systems (Squad framework, Agency platform 30k+ users). Requested by Tamir to analyze prompt injection, data exfiltration, and adversarial testing for multi-agent architectures.

**Work Completed:**
- ✅ Researched latest prompt injection vectors for multi-agent AI systems (2025-2026)
- ✅ Analyzed OWASP Top 10 for LLM Applications (focus: injection, data leakage, excessive agency)
- ✅ Reviewed MCP (Model Context Protocol) security vulnerabilities and CVEs
- ✅ Analyzed Squad framework attack surface (coordinator, drop-box pattern, MCP tool access, history files)
- ✅ Identified 8 critical attack vectors specific to multi-agent systems
- ✅ Documented existing mitigations in Squad (role boundaries, reviewer gates, audit logging)
- ✅ Identified 6 critical gaps (memory poisoning, MCP RBAC, input sanitization, real-time monitoring)
- ✅ Created prioritized defense roadmap (Phase 1-4, immediate to strategic)
- ✅ Designed 8 adversarial test scenarios for validation
- ✅ Mapped Squad to OWASP Agentic AI Top 10 compliance (6/10 controls present)
- ✅ Comprehensive report posted to issue #488

**Key Findings:**

**Critical Attack Vectors:**
1. **Indirect Prompt Injection via GitHub Issues/PRs** — Malicious issue bodies can inject adversarial instructions that agents execute autonomously (🔴 CRITICAL)
2. **Memory Poisoning via Drop-Box Pattern** — `.squad/decisions/inbox/` is append-only, agent-writable, trusted by all agents. Single compromised agent can poison all future agents persistently (🔴 CRITICAL)
3. **MCP Tool Authority Escalation** — Agents have full access to all MCP tools. Kes (calendar) can delete GitHub repos. No least-privilege RBAC (🔴 CRITICAL)
4. **History File Manipulation** — Agent history files are trusted, no provenance or tamper detection (🟠 HIGH)
5. **Cross-Agent Context Propagation** — Malicious content spreads via Scribe logs, orchestration logs, decisions.md ("infectious prompt injection") (🟠 HIGH)
6. **Session Store Poisoning** — SQLite FTS5 session store ingests all content without sanitization. Historical contamination persists (🟡 MEDIUM)

**Existing Mitigations (Strong Foundation):**
- ✅ Role-Based Access Control — Domain boundaries enforced by coordinator
- ✅ Reviewer Gating — Lockout semantics prevent adversarial optimization loops
- ✅ Explicit Spawn Boundaries — No inline simulation, coordinator can't generate code
- ✅ Audit Logging — Forensic capability via Scribe + orchestration logs
- ✅ Human-in-the-Loop — @copilot capability profile prevents autonomous security-sensitive work

**Critical Gaps:**
1. 🔴 **No input sanitization** on drop-box pattern (decisions/inbox/)
2. 🔴 **MCP tool permissions** — no least-privilege RBAC
3. 🔴 **History files** — no provenance or tamper detection
4. 🟠 **Session store** — no content sanitization
5. 🟡 **Real-time anomaly detection** — logs only useful post-incident
6. 🟡 **Issue/PR content validation** — treated as trusted user input

**Recommended Defenses (Prioritized Roadmap):**

**Phase 1 — Immediate (Zero-Code, 30 days):**
- R1: Decision review gate (human approval for security-sensitive keywords)
- R2: MCP tool access audit (document current access matrix)
- R3: Session store query logging (forensic capability)

**Phase 2 — Near-Term (30 days):**
- R4: Tool-level RBAC (MCP authorization with agent-to-tool permission mapping)
- R5: History provenance chain (cryptographic signatures on history entries)
- R6: Issue content sanitization (pre-routing scan for adversarial patterns)

**Phase 3 — Strategic (90 days):**
- R7: Real-time behavioral monitoring (anomaly detection on tool calls, context writes)
- R8: Session store content attestation (trust scoring + provenance tagging)
- R9: Drop-box decision validation (semantic validation before merge)

**Phase 4 — Ongoing:**
- R10: Quarterly red team exercises (Microsoft Foundry AI Red Teaming Agent)
- R11: Vulnerability disclosure program (responsible disclosure channel)
- R12: Continuous threat intelligence (OWASP/MCP CVE monitoring)

**Adversarial Test Plan:**
- Test 1: Malicious issue injection (verify issue sanitization)
- Test 2: Memory poisoning via drop-box (verify decision validation)
- Test 3: Tool authority escalation (verify MCP RBAC)
- Test 4: History file tampering (verify provenance detection)
- Test 5: Cross-agent context propagation (verify output sanitization)
- Test 6: Lethal trifecta detection (verify behavioral monitoring)
- Test 7: Session store contamination (verify historical sanitization)
- Test 8: Reviewer escalation gaming (verify lockout limits)

**OWASP Agentic AI Top 10 Compliance:**
- Squad achieves **6/10 controls present** (Good foundation)
- 🟢 Strong: Sensitive info disclosure, model authorization, autonomous action risk
- 🟡 Partial: Prompt injection, insecure tool use
- 🔴 Critical Gaps: Excessive agency, memory poisoning, tool authority escalation

**Research Sources:**
- OWASP Top 10 for LLM Applications 2025 (owasp.org)
- CSA Agentic AI Red Teaming Guide (Cloud Security Alliance, 2026)
- MCP Security Research (Marmelab, Microsoft, HiddenLayer, 2026)
- CVE-2025-64439 (LangGraph RCE via persistent memory poisoning)
- CVE-2026-25536 (MCP server spoofing)
- arXiv 2511.15759 (Securing AI Agents Against Prompt Injection Attacks)
- Trail of Bits: "Hijacking Multi-Agent Systems in Your PajaMAS" (2025)
- Security Boulevard: "Infectious Prompt Injection" (2025)

**Deliverable:** Comprehensive security research report posted to issue #488 (https://github.com/tamirdresher_microsoft/tamresearch1/issues/488#issuecomment-4059827911)

**Next Steps:**
1. Review with Picard (Lead) — prioritize roadmap
2. Assign Phase 1 tasks (R1, R2, R3) to squad members
3. Schedule red team exercise for validation

**Lesson — Multi-Agent Security Paradigm Shift:**

Multi-agent systems require **fundamentally different security thinking** than single-model deployments:

1. **Persistent Contamination:** Unlike single-model prompt injection (ephemeral, session-scoped), multi-agent memory poisoning **persists across sessions and propagates across agents**. Drop-box patterns, history files, and session stores are high-value persistence vectors.

2. **The Lethal Trifecta:** Agents with (1) private data access + (2) untrusted content exposure + (3) external tool access achieve 67% data exfiltration success rate. Squad's MCP integrations (GitHub, Azure, Teams) create this exact exposure.

3. **Infectious Injection:** Malicious content spreads via agent outputs (decisions, logs, orchestration context) like a virus — compromising one agent can "infect" downstream agents without direct prompt injection. Cross-agent context sharing is both Squad's strength (collaboration) and weakness (attack surface).

4. **Tool Authority Escalation:** MCP tools have broad permissions with no least-privilege enforcement. Calendar agent (Kes) can delete GitHub repos. Security agent (Worf) can send Teams messages to entire org. Need agent-to-tool RBAC, not just agent-to-domain boundaries.

5. **Memory as Attack Surface:** History files, decision inbox, session store are **trusted by default**. No provenance tracking, no tamper detection, no sanitization. Append-only patterns enable "exploits that wait" — injected content triggers hours/days later when context is retrieved.

6. **Reviewer Gates ≠ Defense-in-Depth:** Lockout semantics prevent adversarial optimization loops (strong!), but reviewers only see code diffs, not context contamination. Need semantic validation of decisions/history, not just output artifacts.

7. **OWASP Compliance is Baseline, Not Sufficient:** Squad's 6/10 OWASP Agentic AI Top 10 coverage is **good for foundational security**, but 4 critical gaps (memory poisoning, MCP RBAC, input sanitization, real-time monitoring) expose Squad to high-severity attacks documented in 2025-2026 research.

**Security Design Principles for Multi-Agent Systems:**

- **Zero Trust Memory:** Treat all persistent context (history, decisions, session store) as untrusted until provenance verified
- **Defense-in-Depth:** Layer input sanitization + tool RBAC + behavioral monitoring + human gates
- **Least Privilege Tools:** Agent-to-tool permission mapping, not blanket MCP access
- **Provenance Chains:** Cryptographic signatures on history entries, decision attribution, session attestation
- **Behavioral Baselines:** Real-time anomaly detection on tool calls, context writes, cross-agent propagation patterns
- **Adversarial Testing as Routine:** Quarterly red team exercises, not one-time audits

**Strategic Takeaway:**

Squad's **foundational security is strong** (role boundaries, reviewer gates, audit logging), but **memory poisoning and tool authority escalation are systemic risks** in multi-agent architectures. The recommended defense roadmap (R1-R12) addresses these gaps with **immediate zero-code mitigations (30 days)** and **strategic architectural changes (90 days)**. Risk assessment: HIGH → MEDIUM (30 days) → LOW (90 days + ongoing).

The future of agentic AI security is **continuous validation, not static defenses**. Squad needs operational excellence (R10-R12) — quarterly red team, vulnerability disclosure, threat intelligence — to maintain security posture as attack landscape evolves.

### Issue #547 — Telegram Bot Token Rotation Assessment (2026-03-15)

**Context:** GitHub Secret Scanning detected exposed Telegram bot token. Ralph performed initial remediation. Worf assigned to verify security posture and document findings.

**Work Completed:**
- ✅ Reviewed codebase for hardcoded tokens (none found in committed code)
- ✅ Verified `.gitignore` properly excludes `telegram-bot-token` file
- ✅ Confirmed token storage architecture uses secure resolution chain (env var → file → config → credential manager)
- ✅ Validated Ralph's remediation actions (issue #543 redacted, secret scanning alert resolved, GitHub Actions secret created)
- ✅ Verified no token patterns in current working tree or recent git history
- ✅ Confirmed token file exists outside repo (`~/.squad/telegram-bot-token`)

**Security Assessment:**

**✅ Good Architecture:**
1. Token storage follows defense-in-depth — multiple secure sources, priority resolution chain
2. Token file in `~/.squad/` (outside repo) — no git commit risk
3. `.gitignore` explicitly blocks `telegram-bot-token` — prevents accidental commits
4. Scripts (`squad-telegram-bot.py`, `setup-telegram-bot.ps1`) never hardcode tokens
5. GitHub Actions secret created for CI/CD workflows

**⚠️ Attack Vector:**
- Original token exposure was via **issue body paste** (issue #543)
- This is a **human process failure**, not a code vulnerability
- Ralph correctly redacted the exposed token from issue #543 body

**🔴 Remaining Risk:**
- **Old token still valid until manually revoked via BotFather**
- Token was public for ~9 minutes (21:43:43Z detection → 22:32:58Z redaction)
- Anyone who saw issue #543 during exposure window has the token
- Telegram bot tokens don't expire — must be manually revoked

**Required Actions (Manual — Requires Tamir):**
1. **CRITICAL:** Revoke old token via @BotFather on Telegram:
   - Open Telegram, search for @BotFather
   - Send `/revoke`
   - Select @tamir_squad_bot
   - Confirm revocation
2. Generate new token via @BotFather:
   - Send `/newtoken`
   - Select @tamir_squad_bot
   - Copy new token
3. Update GitHub Actions secret:
   - `gh secret set TELEGRAM_BOT_TOKEN` (paste new token)
4. Update local token file:
   - Edit `~/.squad/telegram-bot-token` with new token
5. Dismiss GitHub secret scanning alert after rotation:
   - https://github.com/tamirdresher_microsoft/tamresearch1/security/secret-scanning

**Code Review Results:**
- ✅ No hardcoded tokens in Python scripts
- ✅ No hardcoded tokens in PowerShell scripts
- ✅ No hardcoded tokens in config files committed to repo
- ✅ All token references use environment variables or external file reads
- ✅ `.gitignore` properly configured

**Lessons:**
- **Issue bodies are public** in private EMU repos — treat as unsanitized user input
- Secret scanning detection lag (~9 minutes) allows brief exposure window
- **Telegram bot tokens are bearer credentials** — no additional auth required for API access
- Token rotation must be **manual** — no automated BotFather API
- GitHub secret scanning is **detective control**, not preventative — always redact secrets before posting

**Status:** ✅ Code security posture verified. Issue closed by Ralph. Remaining action is human-performed token rotation via BotFather (documented above).

