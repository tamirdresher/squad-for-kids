# Welcome to the BasePlatformRP Project — Complete Onboarding Guide for Meir

---

## 1. Welcome & Context

Hi Meir! Welcome to the team. You're joining us on a critical initiative to build **BasePlatformRP**, an Azure Resource Provider abstraction layer that unifies governance, deployment, and lifecycle management across our cloud-native infrastructure ecosystem.

**What you're getting into:**
- **BasePlatformRP** is an emerging ARM Resource Provider that sits above both **DK8S** (Kubernetes platform) and traditional **Azure Infrastructure** as a unified governance layer
- The project combines infrastructure-as-code, security compliance (FedRAMP), Kubernetes orchestration, and Azure cloud patterns
- You'll be working with a distributed AI agent team that coordinates across multiple repositories using structured decision-making and continuous learning

**Where to start:** This guide has everything you need—repos, docs, Teams channels, access steps, and key contacts.

---

## 2. GitHub Repositories & Access

### **Core Repositories**

#### **tamresearch1** (This repo)
- **Purpose:** Central coordination hub for research, analysis, and squad orchestration
- **URL:** [mtp-microsoft or Azure DevOps repo — ask Tamir for exact link]
- **What's here:** Squad configuration, agent charters, decisions, documentation
- **Your role:** Reference this for project context, architecture decisions, and continuous learning patterns
- **Access:** Request to be added to the organization or set up GitHub CLI access

#### **tamresearch1-dk8s-investigations** (Private)
- **Purpose:** Deep-dive research on DK8S platform architecture and infrastructure
- **URL:** [mtp-microsoft repo TBD — ask Tamir for exact link]
- **What's here:**
  - Architecture reports and infrastructure guides
  - DK8S platform knowledge base
  - RP registration research & guides
  - Aurora adoption research
  - Workload migration documentation
- **Your role:** Go-to resource for understanding DK8S architecture and RP registration patterns
- **Access:** Request private repo access from Tamir

#### **idk8s-infrastructure** (Azure DevOps / GitHub mirror)
- **Purpose:** Production infrastructure-as-code for DK8S platform
- **Location:** Azure DevOps + mirrored to GitHub
- **What's here:** Bicep templates, Kubernetes manifests, deployment automation
- **Your role:** Reference for production patterns and infrastructure decisions
- **Access:** Request access through Azure DevOps or GitHub, depending on where you'll work

#### **BasePlatformRP** (TBD - new repo or branch)
- **Purpose:** The actual RP implementation (currently in planning)
- **Expected content:** ARM manifest, TypeSpec schema, registration workflow
- **Your role:** Core implementation work
- **Status:** To be confirmed with Tamir

---

## 3. Documentation & Essential Guides

### **Start Here (Onboarding Priority)**

1. **README.md** (this repo)
   - Project overview and quick reference
   - Squad structure and agent roles
   - How decisions are made

2. **EXECUTIVE_SUMMARY.md**
   - Technology assessment for Squad enhancements
   - Research findings on integrations and patterns

3. **.squad/decisions.md**
   - Team decisions you need to respect
   - Architecture patterns, security findings, infrastructure standards
   - Read sections on RP and Infrastructure Patterns (Decision 2)

### **RP Registration & Architecture (Critical for RP Work)**

Located in `tamresearch1-dk8s-investigations`:
- **rp-registration-guide.md** (35K characters)
  - Complete Azure Resource Provider registration process
  - Three RP models: RPaaS (managed), Direct (custom), Hybrid
  - TypeSpec requirements (mandatory since Jan 2024)
  - Compliance, testing, regional deployment
  - DK8S-specific recommendations
  - **Why you need this:** Authoritative guide for RP implementation decisions

- **rp-registration-status.md**
  - Current status of BasePlatformRP registration
  - Blocking issues and workarounds
  - Timeline and prerequisites

- **cross-repo-analysis-idk8s-to-baseplatformrp.md**
  - How DK8S relates to BasePlatformRP
  - Architectural connections and data flows

### **FedRAMP Dashboard & Security**

Located in `docs/`:
- **fedramp-dashboard-phase1-data-pipeline.md** — Data ingestion architecture
- **fedramp-dashboard-phase2-api-rbac.md** — API and RBAC design
- **fedramp-dashboard-phase3-react-ui.md** — UI implementation
- **fedramp-dashboard-phase4-alerting.md** — Alerting system
- **fedramp-compensating-controls-*.md** — Security compliance details
- **Why you need this:** BasePlatformRP includes FedRAMP compliance requirements

### **DK8S Platform Knowledge**

Located in `tamresearch1-dk8s-investigations`:
- **dk8s-platform-knowledge.md** — Platform overview, node health, scaling
- **dk8s-stability-runbook-tier1-consolidated.md** — Support patterns and diagnostics
- **dk8s-infrastructure-complete-guide.md** — Full infrastructure reference

### **Project Artifacts & Decision Logs**

- **.squad/decisions.md** — All team decisions (architecture, security, infrastructure)
- **CONTINUOUS_LEARNING_PHASE_1.md** — How the team learns and extracts patterns
- **PATENT_RESEARCH_REPORT.md** — Patent strategy for AI orchestration methodology
- **blog-draft-ai-squad-productivity.md** — Context on Squad's productivity model (useful for understanding team culture)

---

## 4. Teams Channels (Placeholder - Coordinator Will Configure)

**Note:** Tamir will add you to the appropriate Teams channels and configure permissions. Here are the expected channels:

- **#BasePlatformRP** (or similar) — Core project channel for RP work
- **#DK8S-Architecture** — Infrastructure and platform discussions
- **#FedRAMP-Dashboard** — Compliance and security dashboard work
- **#Squad-Coordination** — Squad agent team discussions and digests
- **#RP-Registration** — Resource Provider registration and compliance topics

**You'll also receive:**
- Squad daily digest (automated summary of GitHub activity)
- Agent analysis reports from Data, Worf, B'Elanna, Picard
- Decision notifications when new decisions are adopted

---

## 5. Key Contacts & Team Structure

### **People**

- **Tamir Dresher** — Project lead & user coordinator
- **Data** — Code quality and implementation patterns
- **Worf** — Security, cloud compliance, threat modeling
- **B'Elanna** — Infrastructure architecture and deployment
- **Picard** — System design and cross-repo analysis
- **Seven** (me!) — Research, documentation, and onboarding
- **Ralph** — Orchestration automation and watch loops

### **Roles & How to Reach Them**

| Role | Expertise | How to Contact |
|------|-----------|---|
| **Tamir** | Product decisions, timelines, scope | Direct DM or Teams mention |
| **Data** | Code patterns, testing, quality | Code reviews or #squad-code |
| **Worf** | Security compliance, FedRAMP | #fedramp or security questions |
| **B'Elanna** | Infrastructure, Kubernetes, ARM manifests | #dk8s-architecture |
| **Picard** | Architecture decisions, cross-repo impacts | Design phase discussions |
| **Seven** | Documentation, research, onboarding (that's me!) | Questions about what's what |
| **Ralph** | Automation, watch loops, orchestration status | Operational questions |

---

## 6. Getting Started — Week 1 Checklist

### **Day 1: Access & Orientation**

- [ ] Request GitHub org access (or confirm credentials for existing access)
- [ ] Request access to private repos:
  - tamresearch1-dk8s-investigations
  - tamresearch1-agent-analysis (optional, for background context)
- [ ] Request Azure DevOps access for `idk8s-infrastructure`
- [ ] Ensure your GitHub SSH key is configured locally

**Verify with:**
```bash
git clone [mtp-microsoft repo URL — ask Tamir]
cd tamresearch1
git log --oneline | head -5
```

### **Day 2: Core Knowledge**

- [ ] Read **README.md** in tamresearch1 (15 min)
- [ ] Skim **.squad/decisions.md** sections 1-3 (20 min)
- [ ] Read **EXECUTIVE_SUMMARY.md** TL;DR section (10 min)
- [ ] Bookmark **rp-registration-guide.md** for reference (will read fully in Day 3-4)

**Time investment:** ~45 minutes

### **Day 3-4: Deep Dive**

- [ ] Read **.squad/decisions/Decision 2: Infrastructure Patterns** in full (key RP architectural standards)
- [ ] Read **.squad/decisions/Decision 3: Security Findings** (what compliance constraints apply)
- [ ] Read **rp-registration-guide.md** sections 1-6 (process, models, TypeSpec, manifest)
- [ ] Identify which RP model makes sense for your work (RPaaS vs Direct vs Hybrid)

**Time investment:** ~2-3 hours (this is your RP foundation)

### **Day 5: Connect**

- [ ] Schedule 30-min onboarding sync with Tamir
- [ ] Ask your first substantive question in #BasePlatformRP or relevant channel
- [ ] Identify your first task/issue to pick up
- [ ] Connect with team member owning that area (B'Elanna for infra, Worf for security, etc.)

---

## 7. Key Architectural Concepts You Need to Know

### **Three RP Models — Which One Are We Using?**

BasePlatformRP will likely use **Hybrid RP** (mix of managed RPaaS + custom Direct logic):

1. **RPaaS (Recommended for new services)**
   - Microsoft-managed control plane callbacks
   - Simpler onboarding, automatic CRUD operations
   - Limits complex business logic to callback patterns
   - **Constraint:** Requires exception for custom workflows

2. **Direct RP (Full custom control)**
   - You implement the entire control plane
   - Maximum flexibility
   - Requires exception approval
   - **Higher effort, but no workflow constraints**

3. **Hybrid (Emerging pattern)**
   - Managed types via RPaaS + direct types for complex workflows
   - Best balance for DK8S-like platforms
   - **Recommended for BasePlatformRP**

**Decision:** Read `seven-rp-registration.md` decision proposal for Tamir's thinking.

### **Infrastructure Standards (Decision 2)**

Every RP deployment must follow:
- Bicep templates (infrastructure-as-code standard)
- EV2 stamps for parallelism and state tracking
- Progressive rings: Test → PPE → Prod
- Tag-based releases (no branch-based deployments)
- Helm chart values following standard schema
- Explicit dependency declaration

**Why this matters:** Your RP code must integrate with these patterns from day one.

### **Security Requirements (Decision 3)**

6 critical/high severity findings identified:
- Manual certificate rotation risks (see Worf's analysis)
- Network policy enforcement
- WAF rule coverage
- OPA policy compliance
- FedRAMP compensating controls
- Data encryption standards

**Why this matters:** Your RP design must incorporate these from the start, not retrofit later.

### **Continuous Learning Model**

This team learns by:
1. Observing patterns in Teams channels
2. Extracting high-confidence patterns with 3+ examples
3. Formalizing as "skills" in .squad/skills/
4. Using those skills across agents
5. Looping insights back to decisions.md

**Why this matters:** Your work will be captured as patterns and reused. Document your decisions & learnings.

---

## 8. First Week Work Suggestions

**Pick One Based on Your Background:**

### **If You're Infrastructure-Focused:**
- [ ] Audit existing `idk8s-infrastructure` Bicep templates
- [ ] Map DK8S infrastructure to BasePlatformRP requirements
- [ ] Draft ARM manifest skeleton for BasePlatformRP
- [ ] Start task: Issue #TBD (Tamir will assign)

### **If You're API/RP Registration-Focused:**
- [ ] Study the rp-registration-guide.md
- [ ] Evaluate RPaaS vs Direct vs Hybrid for BasePlatformRP use cases
- [ ] Draft TypeSpec schema for core resource types
- [ ] Start task: Issue #TBD (Tamir will assign)

### **If You're Security/Compliance-Focused:**
- [ ] Review FedRAMP compensating controls documentation
- [ ] Map FedRAMP requirements to RP API surface
- [ ] Work with Worf on threat modeling
- [ ] Start task: Issue #TBD (Tamir will assign)

### **If You're Platform/General:**
- [ ] Complete core knowledge Days 1-4 above
- [ ] Schedule deep-dive sync with Tamir
- [ ] Pick first task based on discussion
- [ ] Connect with relevant team member (B'Elanna, Worf, Picard, etc.)

---

## 9. Tools & Workflows You'll Use

### **GitHub & Git**

- **Repository:** All code in GitHub (tamresearch1 org)
- **Branching:** `squad/NNN-brief-description` for feature branches
- **PRs:** Link to issues, request reviews from relevant agents (Data, Worf, B'Elanna)
- **Labels:** `squad:*`, `status:*`, `area:*` drive squad automation

### **Azure DevOps**

- **Infrastructure repo:** idk8s-infrastructure (may be mirrored or primary)
- **Pipelines:** CI/CD for Bicep, Kubernetes manifests, function apps
- **Work items:** Tracked alongside GitHub issues

### **Decision Making**

- **Decisions go in:** `.squad/decisions.md` (structured format)
- **How they're proposed:** `.squad/decisions/inbox/seven-*.md` (draft before adopting)
- **When to propose:** Architecture choices, patterns, blockers that affect team

### **Squad Agent Coordination**

- **Ralph orchestration watch:** `ralph-watch.ps1` (runs in background, processes issues)
- **Squad config:** `squad.config.ts` (agent definitions and permissions)
- **Agent history:** `.squad/agents/*/history.md` (what each agent learned)

---

## 10. Resources & How to Find Answers

### **Find Documentation**

- **Project overview:** README.md (this repo)
- **Decisions & patterns:** .squad/decisions.md
- **RP registration:** `tamresearch1-dk8s-investigations/rp-registration-guide.md`
- **Infrastructure:** `.squad/agents/belanna/history.md` or `idk8s-infrastructure` Bicep templates
- **Security & compliance:** `.squad/agents/worf/history.md` or FedRAMP docs in docs/

### **Ask Questions**

1. **"How does X work?"** → Check agent history or decision logs first
2. **"What do I do about Y?"** → Ask relevant agent (B'Elanna, Worf, Picard, Data)
3. **"Is my approach right?"** → Start GitHub discussion or Teams channel
4. **"Who should I talk to?"** → See "Key Contacts" section

### **Report Issues**

- **Bugs in code:** GitHub issue with `type:bug` label
- **Documentation gaps:** GitHub issue with `type:docs` label or DM Seven
- **Blockers:** GitHub issue with `status:blocked` + explanation
- **Decisions needed:** Comment on relevant issue or create new issue with `decision-needed` label

---

## 11. Final Checklist Before Your First Day

- [ ] GitHub access confirmed (can clone tamresearch1)
- [ ] Private repos access requested (dk8s-investigations, agent-analysis)
- [ ] Azure DevOps access confirmed (for infrastructure repo)
- [ ] Teams channels joined (BasePlatformRP, DK8S, FedRAMP, Squad-Coordination, RP-Registration)
- [ ] SSH key configured locally
- [ ] `.squad/decisions.md` bookmarked
- [ ] `rp-registration-guide.md` location noted
- [ ] First team sync scheduled with Tamir
- [ ] Introductions sent to relevant team members (B'Elanna, Worf, Data, Picard)

---

## Questions?

If anything is unclear:
1. **Check:** Has someone documented this? (search `.squad/` directory, docs/, README files)
2. **Ask:** DM relevant agent or Tamir
3. **Document:** If you find a gap, let Seven know so we can improve this guide

**Welcome aboard, Meir!** 🚀

---

**Document prepared by:** Seven (Research & Docs)  
**Date:** March 2026  
**Version:** 1.0 (Initial Onboarding)  
**To be updated:** As BasePlatformRP repo is created and access is finalized
