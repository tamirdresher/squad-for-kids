---
layout: post
title: "The Platform Standard — Running Your AI Team Like Production Software"
date: 2026-03-21
tags: [ai-agents, squad, github-copilot, kubernetes, platform-engineering, governance, configgen, argocd, helm, compliance]
series: "Scaling AI-Native Software Engineering"
series_part: 5
---

## A Conversation I Was Not Expecting

It was a Tuesday afternoon standup when one of my colleagues asked, half-joking: "So when we deploy your AI agents, do they go through the same review process as everything else?"

I paused. Longer than I should have.

The honest answer was: "Technically, they run on my laptop." Which, on a team that deploys production Kubernetes infrastructure for thousands of engineers at Microsoft, lands with roughly the energy of saying you committed directly to main.

That conversation stuck with me. I work on a platform team that runs a managed Kubernetes environment — the kind that powers real production workloads, with real compliance requirements. We have ConfigGen for cluster configuration. We have ArgoCD for GitOps deployment. We have admission webhooks that will flatly reject a container if it tries to run as root. We have network policies so strict that even talking to the wrong endpoint requires a pull request.

And I was running my entire AI team — [Ralph](/blog/2026/03/10/organized-by-ai), Picard, Data, Worf, Seven, and the rest of the crew — on my developer machine, using my personal credentials, no audit trail, no certificate rotation, no network policy, no nothing.

If a junior engineer deployed software this way, we'd have a very awkward conversation. I decided I needed to have that conversation with myself.

---

## What the Platform Actually Requires

Let me explain what "production-grade" means in our environment, because it's more specific than "it works."

Every application that runs in our clusters is described declaratively using **ConfigGen** — a C# library (`ConfigurationGeneration.*`) that generates cluster configuration from strongly-typed code. The idea is that cluster config isn't YAML templates you eyeball and hope are right — it's code, with types, compilation errors, and code review. If your config doesn't compile, it doesn't deploy.

Every deployment goes through **ArgoCD**. There's no `kubectl apply` in production. You commit to a git repo, ArgoCD detects the change, diffs against current state, and applies it. Drift is automatically reconciled. Manual changes get overwritten. This is not a suggestion; it's how the system works.

Every workload runs under strict **security contexts**: non-root, read-only root filesystem, all Linux capabilities dropped. Network policies are default-deny — you have to explicitly declare which endpoints your pod is allowed to talk to. Admission webhooks enforce these constraints at deploy time. Try to deploy a privileged container and you'll get a very polite rejection from the API server.

And all of this is auditable. Certificate rotation happens automatically. Every API call is logged. Every configuration change has a commit SHA attached to it.

This is a good system. It's a great system. It took years to build. And it makes running software on it genuinely safer than the "I'll just kubectl it" alternative.

So I set out to make my AI team a first-class citizen of this system.

---

## ConfigGen for Your AI Crew

The first step was expressing my Squad agents as ConfigGen applications. This sounds fancier than it is — it just means describing Ralph and friends using the same C# configuration model we use for everything else.

Here's what a basic Squad agent deployment looks like in ConfigGen:

```csharp
using ConfigurationGeneration.Dk8sApplication;
using ConfigurationGeneration.Networking;
using ConfigurationGeneration.Security;

public class RalphAgentConfig : ApplicationConfig
{
    public override Dk8sApplication Configure(ApplicationContext ctx) =>
        new Dk8sApplicationBuilder(ctx)
            .WithName("squad-ralph")
            .WithNamespace("squad-agents")
            .WithImage("ghcr.io/tamirdresher/squad-ralph:v1.2.0")
            .WithReplicas(1)
            .WithResources(r => r
                .WithRequests(cpu: "200m", memory: "512Mi")
                .WithLimits(cpu: "1000m", memory: "1Gi"))
            .WithSecurityContext(s => s
                .RunAsNonRoot()
                .WithUserId(1001)
                .WithReadOnlyRootFilesystem()
                .WithDropAllCapabilities())
            .WithNetworkPolicy(np => np
                .AllowEgressTo("api.github.com", port: 443)
                .AllowEgressTo("github.com", port: 443)
                .AllowEgressTo("login.microsoftonline.com", port: 443)
                .DenyAllIngress())
            .WithSecret("github-app-credentials",
                SecretRef.FromVault("squad/github-app-ralph"))
            .WithConfigMap("squad-team-config",
                ConfigMapRef.FromPath(".squad/"))
            .Build();
}
```

The thing I love about this pattern is that the network policy is **right there** in the config. You can't accidentally forget it. You can't hand-wave the egress rules. If Ralph needs to talk to GitHub, you write it down. If someone adds a new external dependency later and the code doesn't compile, that's a good thing — it means the change is visible and reviewed.

For each agent, I created a similar config class: `PicardAgentConfig`, `DataAgentConfig`, and so on. They inherit common security defaults from a base class, and each one explicitly declares its specific network requirements. Worf, predictably, has the most restrictive egress policy. Data has extra memory limits because sometimes code expert agents are memory enthusiasts.

---

## The App-of-Apps

Once each agent is described in ConfigGen, the next step is tying them all together in ArgoCD.

The pattern we use is **app-of-apps**: one parent ArgoCD application that manages child applications, one per agent. This means deploying or updating the entire Squad team is a single ArgoCD operation. You commit a change to any agent's config, ArgoCD reconciles that specific agent. You want to update all agents? Tag a new release, update the image references, commit. ArgoCD handles the rollout.

Here's what the Squad app-of-apps looks like in practice:

```yaml
# squad-team-app.yaml — ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: squad-team
  namespace: argocd
spec:
  project: platform-engineering
  source:
    repoURL: https://github.com/tamirdresher_microsoft/tamresearch1
    targetRevision: HEAD
    path: deploy/squad
  destination:
    server: https://kubernetes.default.svc
    namespace: squad-agents
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

The `deploy/squad/` directory contains the rendered Helm charts for each agent — generated by ConfigGen's output stage. When Ralph's image is updated, the ConfigGen C# changes, the generated Helm chart changes, the PR merges, ArgoCD sees the diff, and Ralph gets a rolling update. No one runs any commands. The system just works.

We also use this setup for **blue-green deployments** between agent versions. If I'm testing a new version of the Picard orchestrator, I can deploy it as `squad-picard-canary` alongside the existing `squad-picard`, route a percentage of work to the canary, and monitor before promoting. This is the same pattern we use for any other service. AI agents are not special. They're workloads.

---

## What You Get for Free

This is the part nobody talks about when they describe AI agent deployments: the compliance wins that come from running on a well-governed platform.

**Certificate rotation happens automatically.** Every agent that talks to external services uses a managed identity backed by automatically-rotated credentials. I don't think about certificate expiry. The platform thinks about it.

**Network policy enforcement is real.** When Worf tried to call an external threat intelligence API during a security scan, the connection was refused at the network layer — because I hadn't declared that egress in his ConfigGen config. That sounds annoying, but it's actually exactly what should happen. I made a PR, added the egress rule, it got reviewed, it got approved. Now the audit log shows who approved what and when.

**Admission webhooks mean no privileged containers, ever.** I genuinely cannot deploy a Squad agent that runs as root. The API server will reject it. This is comforting in the same way seatbelts are comforting: you don't notice them until something goes wrong.

**Everything is audited.** Every API call made by every agent is logged. When Picard orchestrated a PR merge at 3am because Ralph woke him up for a hot fix, there's a complete audit trail: which agent called which API, what credentials it used, what the response was. This is enormously useful when something unexpected happens and you need to understand why.

The thing I didn't expect was how much easier incident response became. When something goes wrong with a Squad agent, I don't debug it by asking the agent what it did. I look at the logs. I check the ArgoCD sync history. I grep the audit trail. The debugging workflow is the same as any other production service. Which is exactly the point.

---

## What Actually Breaks

I want to be honest about what was hard, because the framing of "just run your AI agents like production software" glosses over a genuinely annoying problem: **interactive authentication**.

The GitHub Copilot CLI — which is how Squad agents run — was designed for humans. It has a browser-based OAuth flow. It expects a human to open a URL, click "Authorize," and copy a device code. This workflow does not survive containerization.

The first time I tried to deploy Ralph as a container, he sat in CrashLoopBackOff, silently waiting for a browser that would never open.

The solution was to stop treating agents as human users. Instead, each agent runs as a **non-human identity** — a GitHub App installation or a service account with a scoped Personal Access Token (PAT) stored in Vault, rotated automatically, with exactly the permissions the agent needs and nothing more. Ralph gets `read:issues`, `write:issues`, `read:pull_requests`, `write:pull_requests` — that's it. He can't touch anything else.

This required rethinking how credentials flow through the system:

```
Vault (rotated credentials)
  └── Kubernetes Secret (synced by External Secrets Operator)
        └── Mounted into pod as environment variable
              └── Copilot CLI picks up GH_TOKEN from environment
                    └── Agent authenticates as service account
```

It's more ceremony than `gh auth login`, but it's also auditable, rotatable, and doesn't depend on any human's active browser session. More importantly, it means I can go on vacation and the agents keep working — because they're not authenticating with my personal credentials that might expire while I'm eating shawarma in Tel Aviv.

The ADO (Azure DevOps) authentication challenge was similar but had a nicer resolution: service principals with scoped ADO PATs. Picard now has an ADO identity that can create work items and read pipelines, but can't approve PRs or touch release environments. Principle of least privilege, automated.

---

## The Governance Insight

Here's what I've come to understand after going through this exercise: the compliance requirements that feel like friction are actually the floor for trustworthy AI.

When Worf runs a security scan and the result is stored in an audit log, that log matters. It means I can answer the question "did your AI agent actually check this?" with a timestamped, signed record, not "I mean, I think it did, it said it did." When Picard orchestrates a deployment and that deployment was rejected by an admission webhook, I can show the webhook rejection log. When Ralph merges a PR at midnight, I can show the commit, the ArgoCD sync, the audit trail of API calls.

Running your AI team under the same standards as your production software isn't overhead. It's the thing that lets you trust them.

There's also an organizational dynamics piece here. When my colleagues ask "how do the AI agents access production systems?" — and they do ask, repeatedly, often with slightly narrowed eyes — I can now answer: "Same way everything else does. ConfigGen config, ArgoCD deployment, Vault-managed credentials, network policies scoped to declared endpoints, admission webhooks enforcing non-root." The raised eyebrow goes away. Because those are the same words I'd use to describe a microservice my team built.

The AI team is not exceptional. It's just a workload. A workload I happen to talk to.

---

## Where This Is Heading

The next step for us is extending this model to the full [SubSquad hierarchy](/blog/2026/03/15/scaling-ai-part3-streams) — org-level shared agents, swimlane-level specialist agents, personal agents. Each level runs on the same platform, with the same governance, but with different resource quotas and network policies scoped to what that level actually needs.

We're also looking at adding **agent-specific admission policies**: just like you can have a policy that says "production workloads must have resource limits," you could have a policy that says "Squad agents must have a declared set of approved MCP servers in their ConfigGen config." If an agent tries to add an unapproved MCP tool, the admission webhook rejects it at deploy time. That's a conversation we're still having.

But the core insight holds regardless of how far you take it: if you're running AI agents on infrastructure that matters, the question isn't "should they have governance?" The question is "how do I make the governance as low-friction as possible while keeping the guarantees?" ConfigGen and ArgoCD, it turns out, are pretty good answers to that question.

I just had to get past the initial shock of running my Star Trek crew through change management.

> *This post is part of the [Scaling AI-Native Software Engineering](/blog/tag/scaling-ai) series. Previous: [Part 4 — When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-distributed)*
