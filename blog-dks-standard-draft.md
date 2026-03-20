---
layout: post
title: "ADR-001 — How We Built AI Team Governance for 10 Engineers"
date: 2026-03-20
tags: [ai-agents, squad, governance, kubernetes, dk8s, adr, platform-engineering, ai-teams]
series: "Scaling AI-Native Software Engineering"
series_part: 5
---

> *"The strength of the wolf is the pack, and the strength of the pack is the wolf."*
> — Rudyard Kipling (not Star Trek, but it applies)

Adir walked into my office — well, he appeared in my chat window, it's 2026, nobody walks anywhere — and said something I wasn't expecting.

"We need a baseline. Every engineer is doing their own thing with AI agents. Some have three agents, some have twelve. Nobody knows what the others configured. One team has Picard as lead, another renamed him to 'Alex.' Worf in one squad has full Azure access; Worf in another has none. We're running in circles. Fix this."

That conversation became ADR-001: *The DK8S Standard for AI Team Governance*.

This post is about what we built, why we built it, and what we learned building it for a team of ten engineers running Squad on a shared Kubernetes platform.

---

## The Governance Vacuum

Let me describe what "ten engineers doing their own thing" actually looks like in practice.

Engineer 1: Three agents (Picard, Data, Ralph). Ralph checks issues every 10 minutes. Data auto-merges passing PRs.

Engineer 2: Twelve agents, including a custom "Chakotay" nobody else has ever heard of. Chakotay apparently handles meeting scheduling. Personal squad names every agent after *Star Trek: DS9* characters.

Engineer 3: Two agents, both named generically, with a squad config that overwrites the shared `routing.md` on every run.

Engineer 4: No agents. Pure skeptic. "I'll do it myself."

Engineer 5 through 10: Somewhere on that spectrum.

This is what I privately called the **governance vacuum**. We had the same problem software teams had in 2015 with microservices: everyone was experimenting, nobody was talking to each other, and the experiments were starting to interfere.

The specific failures:

- **Duplicate automation**: Three engineers independently built "check for stale PRs and ping the author" workflows. They ran simultaneously on shared repos. PR authors got triple-pinged.
- **Conflicting configs**: Two squads had different routing rules for security-related issues. One routed them to Worf. One routed them to the human. Security incidents got handled inconsistently.
- **Skills siloing**: When Seven on my squad figured out the right way to write ADR templates in our org's format, exactly one team benefited: mine. Engineer 7 was still writing ADRs by hand.
- **The "works on my machine" problem for AI teams**: My Ralph claims issues with `TAMIRDESHER-PC` in the branch name. Engineer 3's Ralph uses `WORKSTATION-007`. When a stale claim needed to be reclaimed, nobody knew whose machine was whose.

The vacuum wasn't a critique of the engineers. Everyone was doing exactly what you do when there's no standard: figure it out yourself, optimize for your own workflow, and move on. The problem was that the shared infrastructure — the Kubernetes cluster, the GitHub org, the issue queues — was getting ten different experimental AI setups thrown at it simultaneously.

Adir was right. We needed a baseline.

---

## What ADR-001 Actually Is

ADR-001 is not a long document. It's four pages. What makes it significant isn't length — it's the questions it answers definitively.

**What does every engineer get by default?**

A standard Squad with a fixed core: Picard (lead), Ralph (monitor), Worf (security), Seven (docs), Data (code). These five are non-negotiable. Every engineer on the team starts with this. Not optional. Not configurable at the personal level.

Why five? Because these five represent the irreducible minimum for safe, auditable AI automation:
- Picard: decision-making and decomposition
- Ralph: work queue management and rate limiting
- Worf: security review gate (mandatory for auth and networking changes)
- Seven: documentation of decisions
- Data: code changes

You cannot remove Worf. You cannot remove Ralph. This was the most contentious part of ADR-001 — some engineers wanted full flexibility. We held the line.

**What can each engineer customize?**

Everything else. Want to add Troi for blog posts? Add her. Want a custom agent named Chakotay for meeting scheduling? Fine — as long as Chakotay doesn't have more than read-only calendar access without going through Worf's review. Want to rename Picard to "Alex" because it fits your mental model better? That's a `displayName` override, knock yourself out.

**Who decides what's shared vs. personal?**

The three-layer topology.

---

## The Topology: Three Layers of Squad

If you've worked with Kubernetes, this will feel familiar. If you haven't, think of it like this: you have company policies, team practices, and personal preferences. Three concentric circles. Inner circles can customize. They can't override the outer ones on safety-critical settings.

Here's the actual topology from ADR-001:

```
┌─────────────────────────────────────────────────────┐
│  ORG LEVEL  (.squad/org-config.ts)                  │
│  • Approved tool list                               │
│  • Security policies (Worf mandatory gate)          │
│  • Network egress allowlist                         │
│  • Required agents (Picard, Ralph, Worf, Seven, Data│
│  • Shared skills library                            │
└──────────────────┬──────────────────────────────────┘
                   │ inherits
┌──────────────────▼──────────────────────────────────┐
│  SWIMLANE LEVEL  (.squad/swimlane-config.ts)        │
│  • Team-specific agents (Troi, B'Elanna, etc.)      │
│  • Repo watchlist                                   │
│  • Triage rules                                     │
│  • Ceremony schedules (standups, retros)            │
│  • Team naming conventions                          │
└──────────────────┬──────────────────────────────────┘
                   │ inherits
┌──────────────────▼──────────────────────────────────┐
│  PERSONAL LEVEL  (~/.squad/personal-config.ts)      │
│  • Custom agents                                    │
│  • Personal repo overrides                          │
│  • Schedule preferences                             │
│  • Display name overrides (yes, rename Picard)      │
└─────────────────────────────────────────────────────┘
```

The conflict resolution rule is: **personal > swimlane > org**, with one hard exception: org-level security policies are immutable. You can override display names. You cannot override "Worf reviews all auth changes."

When I first explained this to the team, Engineer 6 said: "That's CSS."

She was right. It's the CSS cascade model applied to AI agent governance. The org config is like the browser's default stylesheet. The swimlane config is your framework's base styles. The personal config is your custom overrides. The `!important` declarations are Worf's security gates — they win no matter what.

---

## Upstream Inheritance: How It Actually Works

The mechanism that makes this practical is what we call **upstream inheritance**. Here's a real example.

The org-level config defines the skill for "create an ADR":

```typescript
// .squad/org-config.ts  (simplified)
export const orgConfig: OrgSquadConfig = {
  requiredAgents: ['picard', 'ralph', 'worf', 'seven', 'data'],
  
  securityGates: {
    authChanges: { reviewer: 'worf', humanApprovalRequired: true },
    networkPolicyChanges: { reviewer: 'worf', humanApprovalRequired: true },
    secretRotation: { reviewer: 'worf', humanApprovalRequired: true },
  },
  
  sharedSkills: [
    'create-adr',         // uses org's ADR template
    'triage-security',    // Worf's security triage flow
    'update-changelog',   // standard changelog format
  ],
  
  approvedTools: [
    'github-cli',
    'azure-devops-mcp',
    'enghub-search',
    // ... 
  ],
};
```

The swimlane config for my team extends this:

```typescript
// .squad/swimlane-config.ts
export const swimlaneConfig: SwimlaneSquadConfig = {
  extends: 'org',  // inherit everything above
  
  additionalAgents: ['troi', 'belanna', 'podcaster'],
  
  repoWatchlist: [
    'tamirdresher_microsoft/tamresearch1',
    'tamirdresher_microsoft/dk8s-platform',
  ],
  
  triage: {
    k8sIssues: { route: 'belanna' },
    blogContent: { route: 'troi' },
    securityAlerts: { route: 'worf' },  // can't remove this, org config makes it mandatory
  },
};
```

And my personal config:

```typescript
// ~/.squad/personal-config.ts
export const personalConfig: PersonalSquadConfig = {
  extends: 'swimlane',  // inherit swimlane which already inherited org
  
  // I can add custom agents
  additionalAgents: ['neelix'],
  
  // I can override display names
  agentAliases: {
    'seven': 'Seven of Nine',  // cosmetic, no functional change
  },
  
  // I can override Ralph's schedule
  ralphSchedule: {
    checkIntervalMinutes: 5,   // swimlane default is 10
    quietHours: { start: '23:00', end: '07:00' },
  },
  
  // What I CANNOT override (blocked by org config):
  // - securityGates (Worf's mandatory reviews)
  // - approvedTools (can't add unapproved tools)
  // - requiredAgents (can't remove the core five)
};
```

The config resolver merges these three layers at runtime. If my personal config says `ralphSchedule.checkIntervalMinutes = 5` but the org config had said `ralphSchedule.minInterval = 10` as a floor, the resolver enforces the floor. This is the "you can always override, but you can't break safety" promise.

---

## SubSquads: The Part Nobody Asked For

Here's the piece of ADR-001 that generated the most debate in review and ended up being the most valuable in production.

A **SubSquad** is a Squad that inherits from a parent Squad. Personal squads inherit from swimlane squads. Swimlane squads inherit from the org squad. Each level can add agents and routing rules. No level can remove parent-level security policies.

This sounds obvious until you see what it enables.

When B'Elanna writes a new Helm validation skill for the platform team's swimlane, every engineer in the swimlane gets it automatically. They don't need to copy-paste. They don't need to read a wiki. They inherit it. Their personal config gets the skill next time their local Squad syncs with the swimlane config.

When I improve the `create-adr` skill at the org level — because I realized the template was missing the "Alternatives Considered" section — every Squad in the org gets the improved template. Not next quarter. Next sync.

This is the feature that made the skeptics convert. Engineer 4 (the "I'll do it myself" holdout) caved when he realized he could inherit the platform-team's triage rules without understanding how they worked. He just added `extends: 'platform-swimlane'` and suddenly his Squad knew how to route K8s issues to the right people.

The "you can always override" promise made adoption easy. Nobody feels trapped. If you inherit a skill you don't want, you suppress it:

```typescript
suppressedSkills: ['create-adr'],  // we use a different ADR format in my area
```

The skill doesn't run for your Squad. Everything else still inherits.

---

## How Squad Maps to the DK8S Platform

Now here's where this gets interesting from a platform-engineering perspective.

The DK8S platform — our internal Kubernetes platform — already has concepts for org-level governance: namespaces, RBAC, resource quotas, network policies. What ADR-001 did was extend those concepts upward into the AI agent layer.

Every Squad running on DK8S is a Kubernetes workload. That means:

**Pod-per-Agent.** Each agent (Ralph, Picard, Worf, etc.) runs as its own pod. Ralph is a StatefulSet (he needs stable identity for the claim protocol). Picard and Seven run as Jobs, spawned on demand. B'Elanna is a long-running Deployment when active work is happening in her domain.

**CRDs for team definitions.** The `SquadTeam` and `SquadAgent` custom resources replace filesystem-based `.squad/` state. A Squad operator reconciles these. Your swimlane config becomes a `SquadTeam` manifest checked into the platform repo. The org config becomes cluster-level policy.

**Node selectors replace machine capabilities.** Remember the `needs:*` label system from [Part 3](/blog/2026/03/18/scaling-ai-part3-distributed)? `needs:gpu` maps directly to `nvidia.com/gpu` node selectors in K8s. The capability-discovery DaemonSet that runs on each node writes these labels automatically. Your Squad gets routed to capable nodes without any manual configuration.

**Workload Identity for Copilot auth.** No PATs. No credentials in pods. Azure Workload Identity provides the credential sourcing; a sidecar auth-proxy handles token refresh and rate limiting. This was Worf's non-negotiable contribution to the design. Static credentials in AI pods is a supply-chain risk. Workload Identity is not optional.

Here's what the Squad manifest looks like in the DK8S world:

```yaml
apiVersion: squad.github.com/v1alpha1
kind: SquadTeam
metadata:
  name: tamirdresher-team
  namespace: engineering-platform
spec:
  inheritsFrom: org/default          # points to org-level SquadConfig
  requiredAgents:                    # inherited from org, explicit here for clarity
    - picard
    - ralph
    - worf
    - seven
    - data
  additionalAgents:
    - troi
    - belanna
  securityPolicy:
    worfGateRequired: true           # cannot be false — admission webhook enforces this
    humanApprovalFor:
      - auth-changes
      - network-policy-changes
  resources:
    default:
      requests: { cpu: "100m", memory: "256Mi" }
      limits: { cpu: "500m", memory: "512Mi" }
    ralph:                           # Ralph gets more — he's the monitor
      requests: { cpu: "200m", memory: "512Mi" }
```

An admission webhook rejects any `SquadTeam` manifest that sets `worfGateRequired: false`. You cannot deploy a Squad on DK8S without Worf's security gate active. This is enforced at the platform level, not by trust.

---

## What ADR-001 Taught Us About AI Governance

We've revised it three times in two weeks. That's not a bad sign — it means the document is living, which means people are actually using it. Here's what the revisions were about:

**Engineers resist standardization until they see what they get for free.** The first draft of ADR-001 read like a list of restrictions: "You must have these five agents. You cannot override these gates." Adoption was slow. The second draft led with what you *get*: shared skills, auto-synced triage rules, platform-level security compliance handled for you. Adoption picked up.

**"You can always override" is load-bearing.** The promise that personal configs override swimlane configs which override org configs — with safety exceptions clearly documented — made engineers comfortable. Nobody felt locked in. Ironically, most people barely use the override capability. They inherit the defaults and it just works.

**Shared skills are the killer feature.** Not agents. Not routing rules. Skills. When Engineer 7 wrote a skill for extracting action items from meeting transcripts, she published it to the swimlane skill library. Within a week, six other engineers were using it without knowing she had written it. That's knowledge propagation at zero marginal cost.

**The naming controversy is real and dumb but you have to address it.** Three engineers had strong opinions about Star Trek character names. Two others wanted generic names. One wanted to use Tolkien characters. We added `displayName` overrides to personal config on day one and never discussed it again. Pick your battles. Let people name their robots.

**ADR-001 is a living document.** The third revision happened after Engineer 9 tried to add `needs:whatsapp` to his Squad and the capability wasn't in the approved tools list. We updated the org config and published the change. Every Squad inherited the updated allowlist. That's the feedback loop working as designed.

---

## The Governance Insight

Here's what I want you to take from ADR-001, regardless of whether you're using Squad, Kubernetes, or anything I've described.

When you have a team of humans sharing infrastructure, you build governance: org charts, access controls, change management processes. When you have a team of AI agents sharing infrastructure, you need the exact same thing — but you can encode it as executable policy instead of documentation nobody reads.

The difference between "ten engineers each doing their own AI thing" and "ten engineers running a coherent AI platform team" is not headcount. It's not tooling. It's one four-page document that answers:
- What does everyone get by default?
- What can you change?
- What can you never change, and why?
- How do changes propagate across the team?

Kubernetes solved this for containers in 2015 with namespaces, RBAC, and resource quotas. ADR-001 is the same idea applied one layer up: to the AI agents running on top of the containers.

Adir asked for a baseline. What we built was an inheritance model — one that makes good defaults free, customization easy, and safety non-optional.

Running a Star Trek crew through change management isn't glamorous. But it turns out governance is exactly what keeps the crew from flying the ship into a nebula.

---

## What's Next

ADR-001 covers the governance model. But governance is only as good as its enforcement. In the next post, I'll cover the admission webhooks, OPA policies, and audit trail that make the DK8S Standard not just a document but a system that enforces itself — and how we handle the invariable "but I just need to bypass this one rule" request in a way that doesn't break everything.

---

*Part 4: [The DK8S Production Deployment](/blog/2026/03/19/scaling-ai-part4-dk8s-production)*  
*Part 3: [When Your AI Squad Becomes a Distributed System](/blog/2026/03/18/scaling-ai-part3-distributed)*  
*Part 2: [Collective Intelligence — Taking AI Teams to Work](/blog/2026/03/12/scaling-ai-part2-collective)*  
*Part 1: [First Contact — Building My First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)*

---

*Tamir Dresher is a Senior Architect at Microsoft, speaker, and the author of [Rx.NET in Action](https://www.manning.com/books/rx-dot-net-in-action). He runs Squad, an open-source AI team framework, in production at [github.com/tamirdresher/tamresearch1](https://github.com/tamirdresher_microsoft/tamresearch1).*
