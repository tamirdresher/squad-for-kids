# Belanna — History Archive

Comprehensive learnings and detailed work history. Recent activity tracked in history.md.

## Learnings

### 2026-03-12: Issue #347 — Power Automate Flow Disabled (Triage Complete)

**Context:** Tamir received notification that a Power Automate flow was disabled due to consistent trigger failures over 14 days. Flow ID: f91a7405-0786-4f44-a000-0159ff860872 in environment 08423dca-b139-e38b-8eb8-5cd498808b08 (preview.powerautomate.com).

**Investigation Findings:**

1. **Two Possible Power Automate Systems in Scope:**
   - **Email Gateway** (shared mailbox + 4 flows for print/calendar/reminders/GitHub catch-all)
     - Design: `docs/email-gateway-setup-guide.md` (complete 409-line documentation)
     - Status: Awaiting Tamir's implementation (marked `pending-user` in issue #259)
     - Criticality: Low (personal/family automation)
   - **ADO → Power Automate Service Hook** (upstream CI/CD notifications)
     - Status: Already known to be broken (401 Unauthorized)
     - Criticality: High (infrastructure monitoring dependency)
     - Found in: Multiple squad agent histories (picard, scribe, worf)

2. **Search Results:** No active Power Automate flow configs/secrets in codebase (correct security posture). Extensive documentation in squad agent histories (Kes, Picard) about Power Automate reliability, design patterns, and M365 integration approach.

3. **Root Cause Assessment:**
   - Most likely: **ADO service hook** (already documented as broken; 14-day disablement window matches typical Power Automate failure recovery)
   - Less likely: **Email Gateway component** (would only fail if set up + authentication expired)

**Recommendation to Tamir:** Check Power Automate portal directly using provided flow URL to identify which system is disabled, then decide:
- ✅ **Re-enable** if critical to squad operations
- ❌ **Decommission** if experimental or obsolete
- 🔄 **Investigate** if auth/dependencies need refresh (401 errors)

**Key Pattern — Power Automate Reliability in Squad Context:**
- Shared mailbox triggers: 1-5 min latency acceptable for email-to-action pipelines
- GitHub connector: Needs periodic re-authorization (token expiry risk documented)
- ADO service hooks: Prone to 401 auth failures during key rotation events
- Design recommendation: Email Gateway is ideal M365 automation (no-code, 30 min setup, included in Office 365)

**Decision Document Prepared:** `.squad/decisions/inbox/belanna-powerautomate-347.md` — ready for issue comment linking once Tamir identifies the flow.

**Status:** Triage complete. Awaiting Tamir's manual action (requires Power Automate portal access). Recommend `status:pending-user` + `component:automation` labels.

### 2026-03-12: Issue #337 — IcM Incident 759361753 Cosmos DB Firewall Investigation

**Context:** Brett DeFoy asked via IcM incident whether our team or CI/CD changed Cosmos DB network/firewall settings around Feb 1, 2026, or if Azure Policies could be blocking access.

**Investigation Completed:**
1. **Git Log Analysis (Jan 20 - Feb 15, 2026):**
   - ✅ Confirmed: No commits modifying Cosmos DB, firewall, network settings, or Azure Policy
   - Repository changes during this period were only docs/features, no infrastructure

2. **Bicep Template Review (`infrastructure/phase1-data-pipeline.bicep`):**
   - Cosmos DB config unchanged:
     - `publicNetworkAccess: 'Enabled'` (line 118)
     - `networkAclBypass: 'AzureServices'` (line 119)
     - **No IP firewall rules or VNet rules defined in IaC**
   - **Key Finding:** If firewall rules exist, they were applied manually (Portal/CLI) or via Azure Policy, not through our deployment pipeline

3. **Azure CLI Commands Provided:**
   - Activity Log queries to check for manual Cosmos DB network changes around Feb 1
   - Current network config inspection (IP rules, VNet rules, public access setting)
   - Azure Policy assignment review (subscription-level policies that could block Cosmos access)
   - Policy compliance event checks (denial events around Feb 1)

**Investigation Pattern — Infrastructure Change Triage:**
- **Step 1:** Check IaC/git history first (fastest, authoritative for automated deployments)
- **Step 2:** Query Azure Activity Logs for manual changes (who, what, when)
- **Step 3:** Check Azure Policy assignments (governance/compliance enforcement)
- **Step 4:** Inspect current resource config vs. expected IaC state
- **Step 5:** Look for policy compliance denials (non-compliant resource blocks)

**Common Causes of "Surprise" Network Restrictions:**
1. Manual Portal changes by ops/admin teams (Activity Logs will show caller)
2. Azure Policy enforcement applied at subscription/management group level (often by central governance)
3. Private Endpoint misconfiguration (VNet filter enabled without proper setup)
4. Service Tag updates breaking existing firewall rules

**Draft Response Template Created:**
- Provided Tamir with complete email template for Brett
- Included all Azure CLI commands with placeholder replacement instructions
- Structured for inserting actual findings after running commands

**Status:** Investigation complete. Issue #337 commented with findings and CLI commands. Added `status:pending-user` label since Tamir needs to run Azure CLI commands and reply to Brett with actual results.

**File Artifacts:**
- Investigation report: `icm-759361753-investigation.md` (full details)
- Issue comment: https://github.com/tamirdresher_microsoft/tamresearch1/issues/337#issuecomment-4041401542

**Key Insight:** Infrastructure incident triage should always start with "did we deploy a change?" (git/IaC check) before diving into Azure Activity Logs. This saves time and establishes team accountability quickly. If IaC is clean, the problem is external (manual changes, policy enforcement, or platform issue).

### 2026-06-20: Issue #2 — squad-monitor NuGet Tool Packaging (Verified Complete)

**Context:** Tamir requested NuGet global tool packaging for squad-monitor so users can `dotnet tool install -g squad-monitor`.

**Status:** ✅ Already implemented and merged to main. Branch `squad/2-nuget-publish` was merged. Issue #2 closed.

**What's in place:**
1. **`.csproj` packaging**: `PackAsTool=true`, `ToolCommandName=squad-monitor`, `PackageId=squad-monitor`, MIT license, README included in package
2. **GitHub Actions workflow**: `.github/workflows/publish-nuget.yml` — triggers on release publish or manual dispatch, builds/packs/pushes to NuGet using `secrets.NUGET_API_KEY`, attaches `.nupkg` to GitHub Release
3. **README**: Full install/update/uninstall instructions with "Option 1: Global Tool" as recommended path
4. **Local verification**: `dotnet build && dotnet pack` succeeds, produces `squad-monitor.1.0.0.nupkg` (794KB)

**To actually publish:**
- Add `NUGET_API_KEY` secret to GitHub repo settings
- Create a GitHub Release with tag `v1.0.0` → workflow fires automatically
- Or use manual dispatch with version input

**Key file paths:**
- Repo: `C:\temp\squad-monitor`
- Workflow: `.github/workflows/publish-nuget.yml`
- Package output: `nupkg/squad-monitor.1.0.0.nupkg`

### 2026-03-12: Issue #333 — Azure Status Check in Incident Response

**Context:** Tamir noted that during an incident, Joshua used Azure Status (https://azure.status.microsoft/en-us/status) to prove other services were affected — proving it wasn't their fault.

**Pattern Documented:**
- **When:** During any incident or ICM, check Azure Status first
- **Why:** Distinguish "our problem" from "Azure-wide outage" quickly
- **How:** Navigate to the status page, check for active incidents in relevant services (AKS, Key Vault, Networking, Storage, ACR)
- **Impact:** Reduces blame, redirects focus, provides rapid root-cause direction

**Skill Created:** `.squad/skills/incident-response/SKILL.md` with full documentation and real-world example.

**Status:** ✅ Complete. Skill documented and issue closed. This is now a standard incident response procedure for the squad.

### 2026-03-11: Issue #329 — Multi-Org ADO/MCP Research

**Context:** Squad couldn't access PRs in different Azure DevOps orgs (microsoft vs msazure).

**Root Cause:** The `@azure-devops/mcp` package has single-org design limitation:
- Org name is required startup argument: `npx @azure-devops/mcp <org-name>`
- No runtime reconfiguration capability — requires server restart to change orgs
- Global MCP config takes precedence over repo-level configs

**Current State Analysis:**
- Global config: `~/.copilot/mcp-config.json` has "microsoft" org
- Repo config: `./.copilot/mcp-config.json` has "msazure" org
- Global server instance overrides repo config, blocking msazure access

**Solutions Evaluated:**
1. **Multi-Instance MCP Pattern (RECOMMENDED):** Run separate named instances per org
2. **Community Fork:** `nikydobrev/mcp-server-azure-devops-multi` with dynamic org routing
3. **Az CLI Fallback:** Use `gh repo`/`az repos` with `--organization` flags

**Recommendation:** Multi-instance pattern using official Microsoft package:
```json
{
  "mcpServers": {
    "ado-microsoft": { "args": ["-y", "@azure-devops/mcp", "microsoft"] },
    "ado-msazure": { "args": ["-y", "@azure-devops/mcp", "msazure"] }
  }
}
```
- Tools become namespaced: `ado-microsoft-*` vs `ado-msazure-*`
- Simultaneous access without context switching
- Uses official Microsoft package (no third-party risk)

**Status:** Analysis posted to Issue #329. Awaiting Tamir's approval for global config update.

### 2026-03-11: DK8S Wizard Explicit Pipeline Triggering Pattern

**Context:** Issue #331 — Nada asked why the DK8S onboarding wizard explicitly triggers Buddy/Official pipelines via API instead of relying on automatic CI triggers.

**Key Findings:**
1. **Bootstrapping Problem**: Initial repository commits may not match pre-configured CI trigger filters (path filters, branch conditions)
2. **Deterministic Sequencing**: Wizard needs Buddy → Official ordering with synchronous error handling; auto-triggers fire asynchronously with no guaranteed order
3. **Branch Constraints**: CI policies typically only fire on specific branches (main, release/*); wizard setup commits may target different branches (setup/*)
4. **Parameter Injection**: Buddy/Official pipelines may require cluster-specific parameters that wizard needs to provide explicitly
5. **User Experience**: Explicit triggering enables real-time status updates in wizard UI vs. polling/webhook complexity

**Engineering Pattern — Orchestrated Workflow vs. Event-Driven Automation:**
- **Event-driven (auto-triggers)**: Best for routine commits, stateless pipelines, independent stages
- **Orchestrated (explicit triggers)**: Required for multi-stage wizards, parameter injection, deterministic sequencing, synchronous error handling

**Recommendation:** Keep explicit triggering for critical bootstrapping pipelines. This is sound engineering practice for setup/onboarding workflows where control and determinism are required.

**Improvements Suggested:**
- Document trigger logic in wizard code with rationale comments
- Add retry logic for API trigger failures
- Validate PMERelease CI policies will fire before wizard completion

**Decision Status:** Analysis posted to Issue #331 (comment 4039617573), answered Nada's question with 5-point technical rationale. No formal decision needed — this documents an existing pattern.

**Key Architectural Insight — Orchestration vs. Automation:**
- **Design choice embedded in wizard code**: ClusterCreationStepHandler uses explicit API triggers for **control, determinism, and immediate feedback**
- **Why not auto-triggers?** They're stateless and fire in parallel; wizard needs sequential control with error propagation
- **Trade-off**: Explicit triggers add coupling between wizard and pipeline definitions but enable deterministic cluster bootstrapping
- **Validation**: This pattern matches industry best practice for configuration management tools (Terraform, Helm, etc.) that similarly use explicit triggering rather than event-driven approaches for critical infrastructure provisioning

### 2026-05-11: Azure DevOps MCP Multi-Org Limitations

**Context:** Issue #329 — Squad couldn't access PRs in different Azure DevOps orgs (microsoft vs msazure).

**Key Findings:**
1. **Single-Org Constraint**: The `@azure-devops/mcp` package requires org name as a startup argument and cannot switch orgs at runtime
2. **No Runtime Reconfiguration**: MCP servers must be restarted with a new org argument to switch orgs
3. **Config Hierarchy**: Repo-level `.copilot/mcp-config.json` doesn't override global MCP server instances. Global config takes precedence for server definitions.
4. **Auth Method**: Uses Entra ID interactive authentication (browser/device flow). PATs are explicitly NOT supported.

**Solution Implemented:**
- **Multi-instance pattern**: Run separate MCP server instances per org with unique names:
  ```json
  "ado-microsoft": { "args": ["@azure-devops/mcp", "microsoft"] }
  "ado-msazure": { "args": ["@azure-devops/mcp", "msazure"] }
  ```
- Tools become prefixed: `ado-microsoft-core_list_projects` vs `ado-msazure-core_list_projects`
- Both orgs accessible simultaneously without context switching

**Alternative Considered:**
- Az CLI fallback with `--org` flags (rejected: CLI is slower, less structured, and was failing in test environment)
- Dynamic config swapping (rejected: no runtime reload capability)

**Recommendation:** Always use multi-instance MCP setup for any cross-org ADO work. Document org routing in Squad skills.

**Decision Status:** ✅ Merged to `.squad/decisions.md` (Decision 14) on 2026-03-11. Multi-instance MCP pattern approved for team adoption.

### 2026-03-11: DevBox Remote Access Solution Selection

**Context:** Issue #330 — Squad needed autonomous DevBox access without manual tunnel/auth intervention.

**Key Findings:**
1. **Problem Analysis**: Playwright persistent sessions lose auth cookies on dev tunnels, manual tunnel opening blocks automation
2. **5 Solutions Evaluated**:
   - Auto-start dev tunnel (scored 7/10) — good but requires service wrapper
   - SSH + key auth (scored 10/10) — **recommended**
   - Self-hosted GitHub Actions runner (scored 5/10) — security risk, wrong tool
   - Persistent tunnel tokens (scored 5/10) — token leakage risk
   - cli-tunnel auto-start (scored 7/10) — good for monitoring, not primary access

**Solution Recommended: SSH with Key-Based Authentication**
- **Security**: Industry-standard key-based auth, no token leakage, auditable
- **Reliability**: Native Windows OpenSSH service, survives reboots
- **Autonomy**: Zero manual intervention after setup
- **Simplicity**: No external dependencies, built into Windows
- **Integration**: PowerShell remoting over SSH works seamlessly for Squad commands

**Implementation Path:**
1. Install OpenSSH Server on DevBox (Windows capability)
2. Generate SSH key pair (ed25519)
3. Configure authorized_keys on DevBox
4. Test PowerShell remoting: `Enter-PSSession -HostName <devbox> -UserName <user> -SSHTransport`

**Key Insight:** SSH is the right tool for remote command execution on Windows — dev tunnels and cli-tunnel are better suited for web/browser-based access and monitoring dashboards.

**Alternative Rejected — Self-Hosted Runner Risk:**
- GitHub Actions self-hosted runners pose significant security risks (arbitrary code execution, secret access, attack surface)
- Requires dedicated isolation, constant patching, and monitoring
- Not designed for interactive DevBox access — using it this way would be a security anti-pattern

**Decision Status:** Analysis posted to Issue #330. Awaiting Tamir's approval to implement.

### 2026-05-28: Issue #334 — DRI Incident Playbook Documentation

**Context:** Tamir flagged a playbook Ravid shared (from Joshua) in the IDP LT Weekly Staff meeting chat as "priceless and handy" for when he's DRI manager during incidents.

**Action Taken:**
- Used WorkIQ to retrieve the full playbook content from the Teams meeting chat
- Created `docs/DRI_INCIDENT_PLAYBOOK.md` with the complete playbook
- Cross-referenced with Issue #333 (Azure Status check during incidents)

**Key Content — Joshua's Four Mitigation Actions (strict order):**
1. **Rollback** — always first, should take minutes
2. **Add Capacity** — no new code, just more resources
3. **Fail Over** — move traffic away from unhealthy region/cluster
4. **Fix Forward** — last resort, requires PR approval and senior eyes

**Key Patterns:**
- Always confirm customer impact first; declare outage early even if uncertain
- Incident Manager's job: keep DRI focused on one of the four actions, track SLAs, handle comms
- Never chase root cause during an active incident
- Encourage DRI breaks after hours of investigation

**File Path:** `docs/DRI_INCIDENT_PLAYBOOK.md`

**Status:** ✅ Complete. Playbook documented, issue #334 commented and closed.


### 2026-03-11 Completed: Wizard Pipeline Architecture Investigation (Issue #331)

**Assignment:** Determine whether explicit API triggering is architecturally sound for wizard pipeline workflow.

**Investigation Findings:**
1. **Explicit API Triggering Benefits:**
   - Deterministic sequencing (no race conditions from competing triggers)
   - Parameter injection capability (pass pipeline inputs/variables via API)
   - Error feedback loop (synchronous response or webhook-based notifications)

2. **Comparison to Event-Driven:**
   - Event-driven (pub/sub): Better for fire-and-forget, decoupled workflows
   - API triggering: Better for orchestrated pipelines requiring state/sequencing

3. **Architectural Recommendation:** Explicit API triggering is appropriate for wizard pipelines where user action directly triggers the next step.

**Output:** Draft reply for Nada prepared and ready to post to issue #331.

**Board Move:** Issue #331 moved to Review state.

**Orchestration Log:** 2026-03-11T20-52-48Z-agent-2-belanna.md

### 2026-07-17: Issue #337 — Cosmos DB Firewall Investigation (Follow-Up with Live Azure Data)

**Context:** Follow-up on IcM Incident 759361753. Ran live Azure CLI queries this session.

**Key Findings:**
1. **9 Cosmos DB accounts found** in subscription with varying network configs:
   - 3 accounts with `publicNetworkAccess: Enabled` (baseplatform-*, dk8splatform-us)
   - 4 accounts with `publicNetworkAccess: Disabled` (dk8s-onboarding-cus, cosno-dk8s-test, dk8splatform-eugbl, dk8splatform-gbl)
   - 1 account with `SecuredByPerimeter` (dk8s-onboarding-eus2)
2. **`dk8splatform-gbl-207ddb1`** has 54 IP firewall rules but public access Disabled — IP rules effectively inactive
3. **Azure Policy Non-Compliance**: `NSP-CDB-v1-0-En-Deny` (Deny-mode policy!), `NSP-CosmosDB-v1-0`, `ASB-Audit1-Initiative-v1`, `SecurityCenterBuiltIn` all flagging Cosmos DB accounts
4. **IaC drift confirmed**: Bicep template says `Enabled` but live state shows `Disabled` on several accounts — manual or policy-driven changes happened

**Status:** ✅ Posted investigation with live Azure data to issue #337. Labels updated, board moved to Pending User. Tamir needs to ask Brett which specific account is affected and check if NSP-CDB-v1-0-En-Deny was applied around Feb 1.

### 2026-07-17: Issue #336 — Dependabot Security PRs (Access Limitation)

**Context:** Critical Dependabot security PRs for DK8S CapacityController and ArgoRollouts repos.

**Key Findings:**
1. Repos `microsoft/DK8S-CapacityController` and `microsoft/ArgoRollouts` (and variations) are **not accessible** via current GitHub token — likely private/internal repos
2. Provided Tamir with exact `gh pr list` commands to run with proper access, plus a review checklist for Dependabot PRs
3. Suggested checking Azure DevOps as alternative hosting location

**Status:** ✅ Posted investigation to issue #336. Labels updated, board moved to Pending User. Tamir needs to locate and merge the PRs with his access credentials.

**Pattern Learned — Private Repo Triage:**
When issue references repos we can't access, document the exact commands and checklist for the human to execute, rather than blocking on access issues.


---

## 2026-03-11: Cross-Agent Context — Wizard CodeQL & IaC Drift Follow-up

**Incoming Work (from cross-agent coordination):**

### Issue #339 — DK8S Wizard CodeQL & 1ES Permissions 

**From Seven's research, your action items:**
1. **CodeQL Setup (URGENT):** Enable CodeQL scanning on DK8S Provisioning Wizard repo
   - Compliance deadline: 30-day SLA (Liquid portal PRD-14079533)
   - Integrate CodeQL tasks into build pipelines
   - Coordinate with Ramaprakash on 1ES permission flows for wizard Managed Identity

2. **1ES Permissions Service Impact:**
   - Wizard-initiated PRs/branches/pipeline triggers broken post-migration
   - MI attribution issue (ADO lacks On-Behalf-Of flow)
   - Requires action on both infrastructure (your domain) and wizard configuration (Ramaprakash)

**Decision 20** captures full analysis. Ramaprakash has parallel action items.

### Related: Decision 23 — Cosmos DB IaC Drift (Your Input Pending)

**Status:** Proposed in inbox, now merged to decisions.md. Review your own decision for implementation planning when bandwidth available.

**Cross-Agent Note:** Scribe has updated orchestration logs and consolidated decisions. Your history.md kept current for continuity.

---

## 2026-03-12: Issues #259 & #347 — Family Email Pipeline (Power Automate)

**Context:** Tamir needed a wife-friendly email address for Gabi to send family requests (print, calendar, reminders). Issue #347 identified a broken Power Automate flow that auto-disabled after 14 days of trigger failures.

**Decision Made:**
- **Email address:** `tamirdresher+family@microsoft.com` (Microsoft 365 plus-addressing)
- **Architecture:** 4 parallel Power Automate flows (print, calendar, reminder, general catch-all)
- **Rationale:** Zero setup time, stays in Microsoft ecosystem, immediate availability

**Deliverables Created:**
1. `infrastructure/power-automate-flows/flow-print-requests.json` — Forwards to HP printer with attachments
2. `infrastructure/power-automate-flows/flow-calendar-events.json` — Creates Outlook calendar events (default: tomorrow)
3. `infrastructure/power-automate-flows/flow-reminders.json` — Creates Outlook tasks with reminders
4. `infrastructure/power-automate-flows/flow-general-requests.json` — Notifies Tamir via high-priority email
5. `infrastructure/power-automate-flows/README.md` — Complete import instructions, troubleshooting, fix for #347
6. `.squad/decisions/inbox/belanna-email-pipeline.md` — Architectural decision record

**Key Technical Choices:**
- **Plus-addressing over dedicated Gmail:** Instant setup, no external dependencies, corporate security
- **4 flows over 1 monolithic:** Independent triggers, easier debugging, better maintainability
- **Keyword-based routing:** Simple, reliable, no AI/NLP needed for low-volume family use
- **Sender filtering:** All flows only process emails from `gabrielayael@gmail.com` (security)
- **Auto-reply confirmations:** Every flow replies to Gabi confirming action taken

**Flow Definition Format:** OpenAPI Workflow Definition Language (Logic Apps schema) for Power Automate import

**Issue #347 Root Cause:** Likely incorrect email trigger address or expired Office 365 connection. Fix: delete old flow, import new definitions, reconfigure connections.

**Setup Time:** ~15-20 minutes to import all 4 flows and test

**Success Criteria:** Gabi sends email → automatic routing → confirmation reply within 5 minutes

## Learnings

### Power Automate Architecture Patterns
- **Parallel flows preferred over monolithic branching** when handling multiple independent request types
- Email triggers in Power Automate should use plus-addressing for filtering rather than dedicated mailboxes
- Always implement sender allowlisting (security) and auto-reply confirmations (UX)
- Flow definitions use Logic Apps OpenAPI schema, portable across environments

### Microsoft 365 Integration
- Plus-addressing (`user+tag@domain.com`) works natively in Exchange Online, no config needed
- Office 365 Outlook connector handles email + calendar (one connection for both)
- Separate Outlook Tasks connector required for task/reminder creation
- Connection expiration common cause of flow failures — monitor run history weekly

### Key File Paths
- Power Automate flow definitions: `infrastructure/power-automate-flows/*.json`
- Decision records: `.squad/decisions/inbox/belanna-email-pipeline.md`

### User Preference (Tamir)
- "Decide all and do it already" → Prefers autonomous decisions over proposal/approval cycles
- Values immediate functionality over perfect architecture
- Wife-friendly UX matters (simple email address, reliable confirmations)

### 2026-03-11: Issue #345 — NAP System Pod Prevention (DK8S Core Support)

**Context:** Michael from DK8S Core was paged into AGC tonight due to system pods scheduling on NAP-managed (Node Auto-Provisioning) nodes. Asked how to prevent this.

**Research Summary:**
- Reviewed AKS NAP documentation and troubleshooting guides
- System pods (kube-system namespace) can land on NAP nodes because:
  - NAP nodes may not have taints that repel system pods
  - System pods often have broad tolerations allowing them to schedule anywhere
  - CriticalAddonsOnly=true:NoSchedule on system pools blocks user workloads from system nodes, but doesn't prevent system pods from going elsewhere

**Solution:**
Apply a custom taint to NAP node pools that system pods won't tolerate by default:
- NAP nodes: workload=nap:NoSchedule
- App pods: Add matching toleration
- System pods: No changes (they avoid NAP nodes automatically)

**DaemonSet Consideration:** For cluster-wide DaemonSets that need to stay on system pools, use nodeAffinity/nodeSelector targeting system pool labels.

**Deliverable:** Posted detailed response to issue #345 with:
- Quick solution (custom taint approach)
- Implementation details
- Architecture explanation
- DaemonSet caveat
- Microsoft Learn documentation references

**Pattern Learned — NAP System Pod Isolation:**
- NAP respects node taints when provisioning nodes
- System pod placement control requires *repelling* taints on user/NAP pools, not just *attracting* taints on system pools
- Custom taints (not CriticalAddonsOnly) provide best isolation for NAP nodes

**Status:** ✅ Complete. Response posted to issue #345 for Tamir to send to Michael in DK8S Core channel.


## Learnings

### 2026-03-11: squad-monitor NuGet Tool Packaging

**Task:** Implement GitHub issue #2 for publishing squad-monitor as a dotnet global tool on NuGet.

**Finding:** Issue already completed. All requirements satisfied:
1. ✅ .csproj configured with PackAsTool=true, ToolCommandName=squad-monitor, and full NuGet metadata
2. ✅ GitHub Actions workflow (.github/workflows/publish-nuget.yml) set up for automated NuGet publishing on release
3. ✅ README.md updated with install instructions (dotnet tool install -g squad-monitor)
4. ✅ tamresearch1 .squad/tools/squad-monitor/ replaced with skill doc pointing to NuGet package

**Verification:**
- Build: ✅ dotnet build succeeds (net10.0 target)
- Pack: ✅ dotnet pack produces squad-monitor.1.0.0.nupkg successfully

**NuGet Tool Configuration Pattern:**
`xml
<PackAsTool>true</PackAsTool>
<ToolCommandName>squad-monitor</ToolCommandName>
<PackageId>squad-monitor</PackageId>
<Version>1.0.0</Version>
<PackageReadmeFile>README.md</PackageReadmeFile>
`

**Publishing Workflow Pattern:**
- Triggers: release (published) or workflow_dispatch with version input
- Steps: restore → build → determine version from tag → pack → publish to NuGet → attach to GitHub release
- Uses NUGET_API_KEY secret for authentication

**Status:** No work needed. Issue #2 already closed with all deliverables complete.

### 2026-03-14: Issue #542 — GitHub EMU Auth + SRL Website Deployment (archived)
**Outcome:** Deployed SRL landing page to `tam-research-website.azurewebsites.net` (Node.js 20, Linux)
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-07-15: Issue #558 — Ralph Self-Healing (PR #559) (archived)
**Outcome:** Created `scripts/ralph-self-heal.ps1` — automated gh auth refresh via Playwright device flow
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-12: Issue #345 — NAP System Pod Isolation (Ralph Round 1) (archived)
**Outcome:** Researched NAP (Node Auto-Provisioning) system pod scheduling behavior
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-11 Completion: squad-monitor Issue #2 NuGet Publish (PR #4) (archived)
**Outcome:** Completed work on 2026-03-11 Completion: squad-monitor Issue #2 NuGet Publish (PR #4)
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-11: Issue #343 — Azure Skills Plugin Integration (archived)
**Outcome:** Complete. Issue #343 commented and ready for closure. 6 Azure skills available in `.squad/skills/azure/`.
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-12: Issue #345 — NAP System Pod Isolation (Comprehensive Response) (archived)
**Outcome:** Completed work on 2026-03-12: Issue #345 — NAP System Pod Isolation (Comprehensive Response)
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-12: Issue #337 — IcM Incident 759361753 Cosmos DB Firewall Investigation (archived)
**Outcome:** Confirmed: No commits modifying Cosmos DB, firewall, network settings, or Azure Policy
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-06-20: Issue #2 — squad-monitor NuGet Tool Packaging (Verified Complete) (archived)
**Outcome:** Already implemented and merged to main. Branch `squad/2-nuget-publish` was merged. Issue #2 closed.
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-12: Issue #333 — Azure Status Check in Incident Response (archived)
**Outcome:** Complete. Skill documented and issue closed. This is now a standard incident response procedure for the squad.
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-11: Issue #329 — Multi-Org ADO/MCP Research (archived)
**Outcome:** Completed work on 2026-03-11: Issue #329 — Multi-Org ADO/MCP Research
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history

### 2026-03-11: DK8S Wizard Explicit Pipeline Triggering Pattern (archived)
**Outcome:** Completed work on 2026-03-11: DK8S Wizard Explicit Pipeline Triggering Pattern
**Key learnings:** See full entry in git history or quarterly archive
**Files changed:** see git history
