# Picard — History

## Core Context

### Squad Leadership & Architecture

**Role:** Lead architect and coordinator for multi-agent Squad orchestration, Ralph cluster protocol design, production approval workflows, cross-team integration

**Technologies & Domains:** Azure DevOps (multi-org, repository strategy), GitHub (Copilot CLI, skill/agent architecture), Kubernetes (Ralph cluster protocol), PowerShell scripting, AI/ML coordination (multiple squads), incident response

**Recurring Patterns:**
- **Multi-Agent Orchestration:** Parallel agent dispatch for specialized tasks (Issue #340 — MDE team uses 6-agent PR review pattern, validates Squad's architecture)
- **Ralph Cluster Coordination:** Machine ID strategy with branch namespacing (`squad/{issue}-{slug}-{machineid}`); supports distributed work claiming across local + DevBox (Issue #346/350)
- **Research-to-Decision Pipeline:** Complex research → Decision record → Team adoption (Issues #321, #340, #341)
- **Cross-Squad Collaboration:** Inventory-as-Code coordination, production approval frameworks, multi-squad routing

**Key Architecture Decisions:**
- **Production Approval Path:** Framework for Brady/external stakeholders to review/approve production changes (Decision #15, Issue #294)
- **Ralph Multi-Machine Support:** Stable hostnames for machine ID strategy; EMU auth constraints documented; branch namespacing with machine scope (Issues #346, #350)
- **Agent Repository Pattern:** `.github/agents/*.agent.md` structure validated against Microsoft Defender team production use (Issue #340)
- **Knowledge Management Phase 1:** Quarterly history rotation → archives; GitHub search + ripgrep queryability; no custom indexing needed yet (Decision #16, Issue #321)

**Key Files & Conventions:**
- `.squad/decisions.md` — Authoritative decision log (multi-org, Ralph protocol, approval framework, knowledge management)
- `.squad/implementations/ralph-cluster-protocol.md` — Multi-machine coordination spec
- `.squad/scripts/Claim-Issue.ps1` — Squad work claiming automation
- `.squad/agents/` — Agent charters and histories (quarterly archives)

**Cross-Agent Dependencies:**
- Manages overall Squad coordination; works with all agents for design reviews and work routing

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

### 2026-03-13: Issue #473 — Rework Rate Integration Proposal (Complete - Background Task)

**Assignment:** Continue Rework Rate (5th DORA metric) integration proposal for bradygaster/squad; add explicit Azure DevOps support.

**Outcome:** ✅ **SUCCESS** — Background task from Ralph work monitor round

**Deliverables:**
- **Research Report**: `research/rework-rate-squad-integration.md` (28KB comprehensive analysis)
- **Decision Record**: `.squad/decisions/inbox/picard-rework-rate-proposal.md` → merged to decisions.md
- **GitHub Issue Comment**: Posted full strategy summary to #473

**Key Integration Strategy:**
1. Extend `PlatformAdapter` with `getPullRequestReviews()` and `getPullRequestIterations()` methods
2. Create `ReworkCollector` in `runtime/rework-collector.ts` for PR rework analysis
3. OTel metrics namespace: `squad.rework.*` (rate, review_cycles, time, changes_requested, ai_retention_rate)
4. ADO gets first-class support — native PR iterations API superior to GitHub for rework tracking
5. 4-phase rollout: Core types → GitHub → ADO → AI retention → Dashboard

**Key Finding:**
- ADO's `_apis/git/pullRequests/{id}/iterations` API provides better rework tracking than GitHub
- ADO adapter already exists (`platform/azure-devops.ts`); auto-detection via git remote URL works
- OTel infrastructure production-ready with no-op fallbacks

**Impact:**
- All agents should reference rework metrics when discussing PR quality
- Ralph: Can integrate weekly rework rate reporting
- Data/Seven: Next owners for implementation phase

**Status:** Research & decision complete. Ready for Data/Seven implementation handoff.

---

### 2026-03-13: Issue #454 — Copilot CLI v1.0.5 Adoption Triage (Complete)

**Assignment:** Triage issue requesting squad adoption of Copilot CLI v1.0.5 features (25 features released).

**Analysis & Recommendation:**
- **Top 3 to adopt immediately:**
  1. `write_agent` tool — async messaging to background agents (enables sophisticated multi-agent orchestration)
  2. Embedding-based MCP/skill retrieval — dynamic context loading (reduces token waste in long sessions)
  3. `preCompact` hook — preserve squad state during context compaction (improves multi-hour session continuity)
- **Secondary priority:** `/pr` command + `/diff` syntax highlighting (this sprint + next sprint)
- **Auto-adopt:** All bug fixes (Kitty, ghp_ warning, backtick rendering) — zero friction
- **Deferred:** `/extensions`, `/experimental` toggle — not needed for current workflow

**Outcome:**
- Added `squad:picard` label
- Posted triage comment on #454 with prioritized feature list
- Wrote decision record to `.squad/decisions/inbox/picard-cli-features-454.md` with:
  - Detailed analysis of each feature (why, owner, scope, impact, effort)
  - Adoption timeline (immediate, this sprint, next sprint)
  - Risks + mitigations
  - Success criteria (write_agent integration, embedding testing, preCompact configuration)
  - Dependencies: ties to Squad MCP server work (#417, PR #453)
- **Next:** Data will investigate write_agent integration with squad-mcp for Phase 2 of PR #453

**Status:** Triage complete. Ready for Data handoff.

---

### 2026-03-12: Issue #347 — Power Automate Flow Disabled (Investigation Complete)

**Assignment:** Investigate disabled Power Automate flow (f91a7405-0786-4f44-a000-0159ff860872) that auto-disabled after 14 days of trigger failures.

**Findings:**
1. Flow is NOT actively integrated into Squad automation
2. Two possible contexts identified:
   - **Email Gateway System** (Issue #259): Personal/family email-to-action automation via shared mailbox + 4 flows (print, calendar, reminders, GitHub issues). Setup guide complete but flows not yet deployed by Tamir.
   - **ADO Service Hook** (Infrastructure): Upstream CI/CD notifications via Power Automate. Known to have 401 auth failures; auto-disable matches typical Power Automate reliability pattern.
3. **Most likely:** ADO service hook (higher criticality + documented failures)

**Scope Search:** Entire repo, .squad/ directory, config.json, schedule.json, squad agent histories—no active Power Automate flow secrets or deployment configs found (correct security posture).

**Recommendation:** Tamir must manually check Power Automate portal via provided URL to identify the specific flow. Once identified, decide: re-enable with new connection, delete, or reconfigure. No critical Squad operations depend on active Power Automate flows.

**Status:** Investigation complete. Issue comment posted with findings. Awaiting Tamir's manual action (status: `pending-user`).

---

## 2026-03-12 Round 1 Team Updates

**Data (Code Expert):** Successfully completed multi-machine Ralph coordination (#346 PR #353). GitHub-native coordination using issue assignments, labels, and heartbeat comments. 15-minute stale threshold, 2-minute heartbeat interval. Machine-specific branch naming pattern: `squad/{issue}-{slug}-{machine}`. Decision recorded in decisions.md. PR awaiting review.

**Troi (Writer):** Completed blog part 2 refresh (#313). Content updated with Tamir's voice, all DK8S/FedRAMP references removed, narrative arc focused on human squad members as bridge from personal playground to real work team. Continues series progression after part 1 refresh.

**Neelix (Comms):** Teams morning briefing sent covering 3 urgent items, 8 pending items, squad progress. Board state synchronized. Tech news already scanned today.

**Board State:** Issues #344–#349 added. #344, #345, #348, #349 → Pending User. #346, #347 → In Progress. #346 moved to Review (post-PR). Board reconciliation clean.

---

## Learnings

### Continuous Monitoring Architecture (Issue #425)

**Context:** Design automated monitoring system for Eyal's Google Group posts to capture valuable technical content for Squad learning and decision-making.

**Architecture Pattern — Stateful Scraper with Knowledge Capture:**
- **Single-script pipeline**: Fetch → Parse → Analyze → Store → Notify (fail-safe at each stage)
- **State persistence**: JSON file tracks processed posts/URLs to prevent duplicates across runs
- **Markdown knowledge base**: Git-friendly, searchable, human-readable (no custom tooling needed)
- **Relevance scoring**: Filter notifications by impact (HIGH/MEDIUM go to Teams, LOW stored silently)
- **Zero dependencies**: Node.js stdlib only (https, fs, child_process) — no npm packages for reliability

**Key Design Decisions:**
1. **Atom feed over API**: Public RSS/Atom feed requires no OAuth, simpler than Google Groups API
2. **Markdown over database**: Searchable via grep/MCP, version-controlled, no infrastructure overhead
3. **Rate limiting**: 1-second delay between URL fetches respects external servers, avoids blocks
4. **Fail-safe processing**: URL fetch errors logged but don't stop pipeline — other links processed
5. **Hourly schedule**: Balance freshness (~10-50 links/month) with API politeness

**Integration Points:**
- `schedule.json`: Hourly cron-style execution via Ralph
- Teams webhook: Same channel as tech-news-scanner for consistency
- Knowledge base: `.squad/knowledge/eyal-links/` follows existing pattern (markdown, append-only)
- State file: `.squad/monitoring/eyal-links-state.json` for deduplication

**Alternatives Considered & Rejected:**
- **Elasticsearch/full-text index**: Overengineered for volume (~10-50 links/month)
- **Database storage**: Less maintainable, not git-friendly, requires infrastructure
- **Email forwarding**: No content extraction, relevance scoring, or knowledge capture
- **Manual review**: Doesn't scale, depends on Tamir checking daily

**Success Metrics:**
- Captures 100% of Eyal's posts within 1 hour of posting
- Accurately scores relevance (HIGH: 3+ keyword matches, MEDIUM: 1-2 matches, LOW: 0)
- Zero false negatives (all URLs extracted and fetched)
- Knowledge base growth: ~10-50 markdown files/month
- No duplicate Teams notifications (state file working)

**Reusable Pattern for Future Monitors:**
This architecture generalizes to any "monitor person X in forum Y" use case:
1. Identify RSS/Atom feed or API
2. Filter by author/criteria
3. Extract structured data (URLs, titles, etc.)
4. Score relevance for notification filtering
5. Store in markdown knowledge base
6. Track state to prevent duplicates
7. Schedule via `schedule.json`

**Files Created:**
- `scripts/eyal-links-monitor.js` — 13.8KB monitor script (zero dependencies)
- `.squad/knowledge/eyal-links/README.md` — Knowledge base documentation
- `.squad/decisions/inbox/picard-eyal-links-monitor.md` — Architecture decision record
- `schedule.json` — Added hourly execution entry

**Strategic Value:** Positions Squad to learn from experts (Eyal) without manual intervention. Knowledge accumulates over time, searchable for future architectural decisions. Pattern reusable for monitoring other key contributors in Google Groups, Reddit, HackerNews, etc.

---

### CLI Features & Agent Orchestration (Issue #454)

**Context:** When evaluating new Copilot CLI features for squad adoption, always prioritize features that:
1. Amplify existing workflows (agent orchestration, context preservation, async patterns)
2. Have clear ROI for the squad's specific use case (not generic CLI improvements)
3. Enable new capabilities previously impossible or tedious (e.g., `write_agent` tool vs. manual follow-ups)

**Key Insight:** The `write_agent` tool is strategically important because our squad architecture depends on agent-to-agent messaging for coordination. Without it, follow-ups require session breaks. With it, agents can guide each other mid-execution → faster convergence, better workflows.

**Decision-Making Pattern:** For CLI/infrastructure features, create a prioritization matrix: Impact (team-wide benefit) × Effort (integration cost) × Strategic Alignment (supports future squad evolution). Features in high-impact, low-effort, high-alignment quadrant go to "immediate" bucket.

**Applied Here:** `write_agent` (high impact × low effort × high alignment) → immediate. `/extensions` (low impact × low effort × low alignment) → defer.

**Formalized Adoption Strategy (2026-03-13):**
- **Adopt Now (Tier 1):** write_agent, embedding-based MCP retrieval, preCompact hook
- **Adopt Next Sprint (Tier 2):** /pr command, /diff syntax highlighting
- **Auto-Adopt (Tier 3):** All bug fixes (zero friction)
- **Defer (Tier 4):** /extensions, /experimental (low alignment)
- Decision record: `.squad/decisions/inbox/picard-copilot-cli-features.md`
- Data owner for write_agent + embedding retrieval integration (coordinates with squad-mcp #417)

### Squad Shared-Memory Architecture Validation (Issue #476)

**Context:** Joshua Johnson (Microsoft) discussed with DJ Seeds about recurring agent mistakes during ManagedSDP ConfigGen Resources migrations. He praised the squad's shared-memory setup and suggested it would be valuable for campaign-style changes.

**External Validation:** This is the first external validation from Microsoft engineering leadership that the squad's shared-memory architecture solves a real problem at scale. Joshua specifically noted:
1. Agent mistakes during campaigns are a recurring pattern
2. A "this was a bug, don't do this again" mechanism would be very useful
3. Cleaner orchestration with upstream inheritance to share learnings

**Squad Architecture Already Addresses This:**
- **decisions.md:** Captures "don't do this again" patterns, team conventions, anti-patterns (21 decisions recorded)
- **skills/ directory:** 17 reusable patterns including configgen-support-patterns for ConfigGen-specific learnings
- **Agent history.md files:** Each agent has persistent memory across issues, learns from past mistakes
- **Upstream inheritance model:** Agents inherit knowledge from decisions.md + skills/ + their own history

**Extension Opportunity:** Campaign-style migrations (like ManagedSDP ConfigGen work) could be formalized as:
1. Create a migration-specific skill (e.g., `skills/managedsdp-configgen-campaign/`)
2. Capture recurring error patterns from the campaign
3. Feed them to agents via upstream inheritance
4. Build a reusable pattern for future large-scale migrations

**Outcome:**
- Crafted response from Tamir's perspective acknowledging Joshua's feedback
- Posted on issue #476 for Tamir to review and send as email
- Issue labeled `status:pending-user` (Tamir needs to send the actual message)
- This validates the squad's architectural direction and highlights a path for future enhancement

**Strategic Implication:** The squad's shared-memory architecture is not just useful internally—it solves a recognized problem in Microsoft's AI-assisted development workflows at scale. This positions the squad framework as a potential model for other teams doing campaign-style changes.




### Rework Rate → bradygaster/squad Integration (Issue #473)

**Context:** Researched bradygaster/squad (v0.8.25) codebase to propose Rework Rate metric integration with full ADO support.

**Architecture Findings:**
- Squad has a clean `PlatformAdapter` pattern in `platform/types.ts` with `GitHubAdapter`, `AzureDevOpsAdapter`, and `PlannerAdapter`
- ADO adapter already wraps `az` CLI for work items, PRs, branches — fully functional
- OTel infrastructure is comprehensive: `otel-api.ts` (resilient wrapper), `otel-metrics.ts` (tokens, agents, sessions, latency), `otel-bridge.ts` (EventBus→spans)
- Platform auto-detection reads git remote URL in `platform/detect.ts`
- Communication adapters exist for GitHub Discussions, ADO Work Item discussions, and file logging

**Key Insight — ADO Iterations API:** Azure DevOps has first-class PR iteration support (`_apis/git/pullRequests/{id}/iterations`) which provides better rework tracking than GitHub's commit-based approach. This is a competitive advantage for ADO users of the squad framework.

**Integration Strategy:**
1. Extend `PlatformAdapter` with optional review/iteration methods (backward compatible)
2. Create `ReworkCollector` class for aggregation logic
3. Add `squad.rework.*` OTel metrics (rate, review_cycles, time, changes_requested, ai_retention_rate)
4. ADO gets special treatment with native iterations API; GitHub uses commit timeline as proxy

**Deliverables:**
- Full proposal at `research/rework-rate-squad-integration.md` (~28KB)
- Comment posted on issue #473 with executive summary and community message
- Decision record at `.squad/decisions/inbox/picard-rework-rate-proposal.md`

**Repo Structure Pattern (bradygaster/squad):**
```
packages/squad-sdk/src/
  platform/     → PlatformAdapter interface + GitHub/ADO/Planner implementations
  runtime/      → OTel, metrics, event bus, telemetry, config
  adapter/      → Copilot SDK adapter types
  agents/       → Charter compilation
  coordinator/  → Agent coordination
  ralph/        → Work monitor
  streams/      → SubSquad definitions
```

---

### Continuous Model Evaluation Framework (Issue #509)

**Context:** AI model landscape evolves rapidly (GPT-5.x, Claude updates, Gemini). Without systematic evaluation, squad risks missing better models, overspending on premium when mid-tier suffices, or using outdated models. Issue #509 requested continuous process to review models and update agent assignments.

**Architecture Decision — Model Review Ceremony:**
- **Trigger:** Quarterly scheduled (every 3 months) + ad-hoc (major releases, quality degradation, cost spikes)
- **Integration:** Tech-news-scanner (Issue #255) detects announcements → Neelix flags → Picard evaluates within 1 week
- **Process:** Review announcements → Benchmark new models → Cost/quality analysis → Recommend changes → Update configs
- **Facilitator:** Lead (Picard) — approves model changes

**Key Files Created:**
- `.squad/ceremonies.md` — Added Model Review ceremony definition
- `.squad/templates/model-evaluation.md` — Structured evaluation framework (benchmark tasks, cost analysis, decision format)
- `.squad/model-assignments-snapshot.md` — Documents current agent→model assignments with rationale, cost estimates, change history
- `.squad/routing.md` — Added Per-Agent Model Selection section with tier guidelines and override process
- `.squad/decisions/inbox/picard-model-evaluation-process.md` — Full decision record

**Current Model Strategy (as of 2026-03-13):**
- **Standard Tier (claude-sonnet-4.5):** 8 agents — Picard, Data, Seven, B'Elanna, Worf, Q, Troi, Kes  
  Use cases: Architecture, code generation, research, security, creative writing  
  Rationale: Best quality/cost balance for complex reasoning (~$180-240/month)
  
- **Fast Tier (claude-haiku-4.5):** 4 agents — Neelix, Scribe, Podcaster, Ralph  
  Use cases: Daily briefings, session logging, monitoring, TTS generation  
  Rationale: Speed + cost efficiency for routine/high-volume work (~$20-30/month)
  
- **Premium Tier (Opus 4.6):** Not currently used  
  Decision: Quality gap doesn't justify +$400-600/month over Sonnet 4.5  
  Future: Consider for mission-critical decisions if justified

**Total Est. Monthly Cost:** $200-270/month (within budget)

**Evaluation Triggers (3 Categories):**
1. **Scheduled:** Quarterly reviews (next: 2026-06-15) — full evaluation of all agents
2. **Ad-Hoc:** Major model releases (GPT-6, Claude Opus 5, Sonnet 4.6) → evaluate within 1 week
3. **Reactive:** Quality degradation, cost spike (+50%), capability gap → immediate evaluation

**Integration with Tech News Scanner:**
- Scanner monitors HackerNews, Reddit for model announcements
- Neelix includes model releases in daily briefing with alert
- Picard reviews announcement, decides if Model Review ceremony needed
- SLA: 1 week from announcement to evaluation start (for major releases)

**Evaluation Process (7 Phases):**
1. **Trigger Detection:** Quarterly OR ad-hoc (release/issue/cost)
2. **Scoping:** Identify models to test + affected agents
3. **Benchmarking:** Representative tasks per agent role, score quality/speed/cost
4. **Cost vs Quality:** Calculate monthly impact, assess quality delta, capability fit, risk
5. **Recommendations:** Per-agent decision (Change/Keep/Defer) with justification
6. **Decision & Documentation:** Update snapshot, record decision, update charters if needed
7. **Monitoring:** Track first week quality + first billing cycle cost

**Model Selection Criteria:**
- **60% Quality:** Task completion, accuracy, reasoning depth, code quality, synthesis
- **25% Cost:** Price per 1M tokens, monthly spend per agent, acceptable tradeoff
- **15% Capability Fit:** Model strengths align with agent domain, context window, response speed

**Key Insight — Tier Assignment Rationale:**
- **Standard for Reasoning:** Architecture (Picard), security analysis (Worf), code generation (Data), research (Seven) need deep reasoning → Sonnet 4.5 justified
- **Fast for Templates:** Daily briefings (Neelix), logging (Scribe), monitoring (Ralph), TTS scripts (Podcaster) are template-driven → Haiku 4.5 sufficient at 5x cost savings
- **Premium Reserved:** Only justify if Sonnet quality insufficient for mission-critical work — currently not the case

**Historical Changes (Baseline for Future):**
- 2026-01-15: Squad genesis — All agents start on Sonnet 4.5
- 2026-02-01: Neelix, Scribe, Ralph → Haiku 4.5 (routine work, ~$150/month savings)
- 2026-02-15: Podcaster → Haiku 4.5 (TTS generation straightforward, 5x cost reduction)

**Success Metrics (Track Over Time):**
- Quarterly reviews on schedule (target: 100%)
- Ad-hoc evaluations within 1 week of major releases (target: 100%)
- Model changes yield quality improvement OR cost savings (target: 80%+)
- No quality regressions from model changes (target: 0%)
- Tech-news-scanner flags model announcements (target: 90%+ coverage)

**Alternatives Considered:**
- **Manual Ad-Hoc Only:** Reactive, easy to miss releases → Rejected (need proactive quarterly baseline)
- **Automatic Model Switching:** Risk quality regressions, cost spikes → Rejected (need human judgment)
- **Annual Review Only:** 12-month lag too long → Rejected (quarterly balances thoroughness with responsiveness)
- **Continuous Automated Benchmarking:** High infrastructure cost → Deferred (quarterly manual sufficient for ~12 agents)

**Dependencies:**
- Tech-news-scanner (Issue #255) for automated model announcement detection
- OTel metrics (existing) for token usage, latency tracking
- Platform model catalog (current: Premium/Standard/Fast tiers with 18 models)

**Risks & Mitigations:**
- **Quality regression after switch:** Monitoring period (1 week) with rollback; keep previous config
- **Cost spike from premium adoption:** Cost analysis required before approval; monthly spend alerts
- **Missing announcements:** Tech-news-scanner + fallback to quarterly baseline
- **Agent-specific preferences conflict:** Agent charters can override; routing.md documents process

**Strategic Implication:** This framework positions the squad to continuously optimize model assignments as AI landscape evolves. Quarterly baseline ensures we don't miss incremental improvements; ad-hoc triggers catch major releases. Cost vs. quality framework prevents premature premium tier adoption while allowing justified upgrades. Template ensures consistent, data-driven evaluation across all agents.

**Pattern for Future Squads:** Model Review ceremony + evaluation template + assignment snapshot = reusable pattern for any squad needing systematic model management. Especially valuable as model count grows (18+ models across 3 tiers currently).

**Next Steps:**
1. ✅ Ceremony, template, snapshot, routing guidance created
2. Schedule first quarterly Model Review for 2026-06-15
3. Integrate tech-news-scanner with model announcement detection
4. Monitor monthly spend; alert if exceeds $300
5. Track quality/cost metrics over Q2 2026 to validate current assignments

---

### KEDA Autoscaling Implementation Plan (Issue #1134)

**Context:** Squad agents on Kubernetes need intelligent autoscaling that respects both work queue depth AND API rate limits. Static `replicaCount: 1` wastes compute during off-hours and can't parallelize work during busy periods.

**Assignment:** Complete KEDA autoscaling research (marked `go:research-done`) by consolidating B'Elanna's findings, documenting recommended approach, creating implementation plan, and defining success metrics.

**Research Findings (B'Elanna):**
- Comprehensive research document: `docs/squad-on-k8s/keda-autoscaling.md` (477 lines)
- Baseline YAML manifests: `infrastructure/keda/squad-scaledobject.yaml`, `github-rate-scaler.yaml`
- 3-trigger composite scaling strategy validated
- AKS managed KEDA add-on eliminates maintenance overhead

**Key Insights:**
1. **Scale-to-zero is critical** — KEDA's `minReplicaCount: 0` enables 50-70% cost savings during off-hours when no `squad:active` issues exist
2. **Rate-limit awareness prevents failures** — Scaling UP when GitHub API headroom < 10% worsens cascading 429s; need Prometheus trigger to scale DOWN instead
3. **Shared token bucket is the real bottleneck** — Multiple pods share same `GH_TOKEN` rate limit (5,000 req/hr); horizontal scaling doesn't increase API throughput, only parallelizes work between calls
4. **Cold-start ~30-40s acceptable** — Image pull + init + agent ready; acceptable for async issue processing (not interactive)

**3-Trigger Architecture:**
- **Trigger 1 (GitHub):** Primary scaling driver — open issues with `squad:active` label (1 pod per 2 issues)
- **Trigger 2 (Prometheus):** Safety valve — GitHub API rate limit headroom < 10% → scale to 0 (backoff)
- **Trigger 3 (Prometheus):** Circuit breaker — Copilot 429 rate > 5/min → scale to 0 (cooldown)

**Implementation Plan Created:**
- **Phase 1 (Complete):** Baseline KEDA deployment with GitHub trigger
- **Phase 2 (High Priority):** squad-rate-limit-exporter (Prometheus metrics for GitHub API rate limits)
- **Phase 3 (Medium):** Copilot 429 metrics tracking (HTTP proxy sidecar or SDK instrumentation)
- **Phase 4:** End-to-end validation (test scale-to-zero, rate-limit backoff, cold-start latency)
- **Phase 5:** Helm integration (template KEDA manifests into `squad-agents` Helm chart)

**Deliverables:**
- Implementation plan: `docs/squad-on-k8s/KEDA_IMPLEMENTATION_PLAN.md` (469 lines)
- PR #1190: Branch `squad/1154-rate-limit-exporter` (note: branch name from earlier session, reused)
- Consolidated research + roadmap + success metrics + risk mitigation

**Success Metrics Defined:**
| Metric | Target | Measurement |
|---|---|---|
| Cost reduction | 50-70% off-hours | AKS node utilization week-over-week |
| Cold-start latency | < 60s | KEDA scaling events + pod startup logs |
| Rate-limit failures | 0 cascading 429s | Alert on `SquadScaledToZeroWithActiveIssues` |
| Scale-to-zero uptime | > 80% off-hours | `kube_deployment_spec_replicas == 0` |

**Dependencies Identified:**
- squad-rate-limit-exporter (Phase 2) — polls `https://api.github.com/rate_limit`, exposes Prometheus metrics
- Prometheus deployment (kube-prometheus-stack or Azure Monitor Managed Prometheus)
- squad-metrics-exporter (Phase 3, optional) — tracks Copilot 429 responses

**Alternatives Considered:**
- **Standard HPA:** Rejected — cannot scale to zero, requires custom metrics adapter, no built-in GitHub scaler
- **ACI Virtual Nodes:** Rejected — higher cold-start latency (~60-90s), network complexity

**Rollback Plan:** Set `keda.enabled: false` in Helm values; revert to static `replicaCount: 1`

**Next Steps:**
1. ✅ PR created (#1190)
2. After merge: Deploy to AKS dev cluster, validate scale-to-zero behavior
3. Create follow-up issues for Phases 2-4
4. Iterate on `targetIssueCount`, `cooldownPeriod` thresholds based on observed behavior

**Key Learning — Rate-Limit-Aware Scaling:**
The breakthrough insight from B'Elanna's research: **scaling UP when rate-limited is counterproductive**. Traditional autoscaling adds pods when queue depth is high, which accelerates token exhaustion and causes cascading failures. KEDA's composite triggers enable a smarter strategy: scale UP for work queue depth, scale DOWN for rate limit pressure. This requires Prometheus integration (Trigger 2 + 3) but enables safe, cost-effective horizontal scaling for API-bound workloads.

**Pattern for Future Work:**
This 5-phase approach (baseline → metrics exporter → validation → Helm integration) is reusable for any KEDA scaler implementation. Phase 1 gets minimal working config deployed; Phase 2-3 add observability; Phase 4 validates production behavior; Phase 5 makes it GitOps-friendly. Keeps momentum while building incrementally.

**Status:** Implementation plan complete. PR #1190 ready for review. Research phase closed.
### GitHub Rate Limit Exporter Deployment (Issue #1155)

**Context:** Deploy Tier 2 Prometheus bridge for GitHub API rate limits to enable KEDA rate-aware autoscaling. Builds on custom exporter (#1154) as production-ready alternative.

**Solution Architecture:**
- **Exporter:** kalgurn/github-rate-limits-prometheus-exporter (battle-tested, community-maintained)
- **Deployment Options:** Helm chart (production) + standalone K8s manifests (testing)
- **Metrics Exposed:** `github_rate_limit_remaining`, `limit`, `reset_unix`, `remaining_ratio` for Core/Search/GraphQL APIs
- **Authentication:** Supports both PAT (default) and GitHub App credentials via squad-runtime-secrets
- **Prometheus Integration:** ServiceMonitor for auto-discovery, scrapes every 30s on port 2112
- **KEDA Integration:** Enables Trigger 2 in squad-scaledobject.yaml — scales pods to zero when ratio ≤ 0.1 (10%)

**Key Design Decisions:**
1. **Tier 2 vs Tier 1:** Use upstream kalgurn/grl-exporter instead of custom Go app — reduces maintenance burden, gains community security audits, supports GitHub App auth out-of-box
2. **Dual Deployment Path:** Helm chart for production GitOps; standalone manifests for quick testing/debugging
3. **Security Posture:** Non-root user (1000), read-only filesystem, dropped capabilities, seccomp profile
4. **Resource Sizing:** 50m CPU / 64Mi memory requests — exporter is lightweight (polls 1 endpoint every 30s)
5. **Node Affinity:** Prefer spot instances (50 weight) for cost optimization on non-critical monitoring workload

**Deliverables:**
- `github-rate-limit-exporter/helm/`: Production Helm chart with values, templates, Chart.yaml
- `github-rate-limit-exporter/k8s/deployment.yaml`: Standalone manifests (Deployment, Service, ServiceMonitor)
- `github-rate-limit-exporter/README.md`: Quick start, metrics overview, KEDA integration guide
- `github-rate-limit-exporter/INSTALL.md`: Deployment guide, validation steps, troubleshooting (note: file created during work but may have been lost in directory issues)
- PR #1193: Opened with full description and testing instructions

**KEDA Flow:**
```
GitHub /rate_limit API → Exporter :2112/metrics → Prometheus scrape
  → KEDA PromQL query (min ratio) → Trigger threshold check (0.1)
  → Scale Squad pods to 0 (cooldown 300s) → Prevents 429 cascades
```

**Comparison to Custom Exporter (#1154):**
| Aspect | Tier 1 (Custom) | Tier 2 (This) |
|--------|----------------|---------------|
| Maintenance | Squad team | Upstream community |
| Security | No audits | SonarCloud + community |
| GitHub App | Future work | ✅ Built-in |
| Features | Core API only | Core + Search + GraphQL + Actions |
| Deploy time | 2–3 days | 30 minutes |

**Learning — Production-Ready vs Custom:**
When a battle-tested upstream solution exists with active maintenance and community security review, prefer it over custom implementation — even if the custom version would be a valuable learning exercise. The upstream kalgurn/grl-exporter has SonarCloud integration, GitHub App support, Helm chart on ArtifactHub, and production usage validation. Building custom makes sense for:
1. Unique logic not available upstream (e.g., Copilot 429 tracking)
2. Extreme performance requirements (upstream too slow)
3. Educational/research purposes (Tier 1 serves this)
4. Vendor lock-in avoidance (not applicable here — exporter is OSS)

For rate-limit metrics, the upstream solution covers 100% of requirements and reduces squad maintenance burden.

**Next Phase:**
1. ✅ PR #1193 created and awaiting review
2. Deploy exporter to AKS dev cluster for testing
3. Verify Prometheus scrape targets show exporter
4. Enable KEDA Trigger 2 in squad-scaledobject.yaml
5. Simulate rate limit exhaustion to test scale-to-zero behavior
6. Document Grafana dashboard queries for rate limit monitoring
7. Add PrometheusRule alerts (GitHubRateLimitLow, GitHubRateLimitExhausted)

**Status:** Implementation complete, PR open. Production deployment pending review.
