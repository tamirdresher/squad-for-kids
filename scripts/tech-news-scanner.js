#!/usr/bin/env node

/**
 * Tech News Scanner
 * Scans HackerNews, Reddit, Morning Dew (alvinashcraft.com), Architecture Notes (architecturenotes.co),
 * ThoughtWorks Radar, and bradygaster/squad GitHub repo for relevant tech stories and product updates.
 * Also checks Brady Gaster's blog for Squad-related posts.
 * Filters by topics: AI, vibecoding, .NET, Go, Kubernetes, cloud native, developer tools, Squad
 * 
 * Posts digest to both Teams channels:
 * - squads > Tech News (Tamir's squad notifications)
 * - Squad > Squad Tech News (Brady's product team)
 * 
 * Deduplication:
 * - Checks if a Tech News Digest issue already exists for today before creating
 * - Tracks reported URLs in .squad/monitoring/tech-news-state.json to avoid reposting
 */

import https from 'https';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const KEYWORDS = [
  'ai', 'artificial intelligence', 'machine learning', 'ml', 'llm', 'gpt', 'copilot',
  'vibecoding', 'vibe coding',
  '.net', 'dotnet', 'c#', 'csharp', 'aspnet', 'blazor',
  'golang', 'go lang',
  'kubernetes', 'k8s', 'cloud native', 'cncf',
  'developer tools', 'devtools', 'ide', 'vscode', 'github',
  'architecture',
  'tech radar', 'thoughtworks',
  'squad',
  // AWS keywords — added for issue #931
  'aws', 'amazon web services', 'lambda', 'serverless', 'ec2', 's3', 'dynamodb',
  'cloudformation', 'cdk', 'eks', 'ecs', 'fargate', 'bedrock', 'sagemaker',
  'step functions', 'eventbridge', 'api gateway', 'cognito', 'iam',
  'well-architected', 'multi-region', 'elasticache', 'rds', 'aurora',
  'graviton', 'outposts', 'wavelength', 'cloudfront', 'route 53'
];

// ─── Relevance scoring ────────────────────────────────────────────────────────
// HIGH  = directly impacts our work (squads, .NET, K8s, AI agents, Azure, MCP)
// MEDIUM = adjacent tech worth monitoring
// LOW    = filtered out of the digest entirely
const HIGH_RELEVANCE_KEYWORDS = [
  'squad', 'k8s', 'kubernetes', '.net', 'dotnet', 'c#', 'csharp', 'aspnet', 'blazor', 'aspire',
  'ai agent', 'ai agents', 'agentic', 'github copilot', 'copilot', 'copilot workspace',
  'azure', 'aks', 'azure kubernetes', 'mcp', 'model context protocol',
  'semantic kernel', 'dapr', 'microsoft', 'opentelemetry', 'otel',
];

const MEDIUM_RELEVANCE_KEYWORDS = [
  'ai', 'machine learning', 'llm', 'gpt', 'claude', 'openai', 'anthropic', 'gemini',
  'cloud native', 'cncf', 'docker', 'container', 'helm', 'gitops', 'argocd', 'flux',
  'github', 'vscode', 'vs code', 'devtools', 'developer tools', 'dev tools',
  'golang', 'rust', 'typescript', 'nodejs',
  'aws', 'gcp', 'serverless', 'lambda', 'security', 'cve', 'vulnerab',
];

function scoreRelevance(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  if (HIGH_RELEVANCE_KEYWORDS.some(kw => text.includes(kw))) return 'HIGH';
  if (MEDIUM_RELEVANCE_KEYWORDS.some(kw => text.includes(kw))) return 'MEDIUM';
  return 'LOW';
}

function getWhyItMatters(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  if (text.includes('squad') && (text.includes('release') || text.includes('update') || text.includes('commit'))) {
    return '⚡ **Direct squad impact** — this is our own tooling evolving.';
  }
  if (text.includes('mcp') || text.includes('model context protocol')) {
    return '🔌 **MCP ecosystem** — affects how our AI agents connect to external tools.';
  }
  if (text.includes('ai agent') || text.includes('ai agents') || text.includes('agentic')) {
    return '🧠 **AI agents** — directly shapes the multi-agent patterns we\'re implementing.';
  }
  if (text.includes('kubernetes') || text.includes('k8s') || text.includes('aks')) {
    return '☸️ **K8s platform** — our deployment infra, fleet management, and AKS upgrade path.';
  }
  if (text.includes('.net') || text.includes('dotnet') || text.includes('csharp') || text.includes('c#') || text.includes('aspnet') || text.includes('blazor') || text.includes('aspire')) {
    return '🔷 **.NET stack** — our primary backend language and runtime.';
  }
  if (text.includes('azure')) {
    return '☁️ **Azure platform** — our cloud home and integration surface.';
  }
  if (text.includes('copilot') || (text.includes('github') && text.includes('ai'))) {
    return '🤖 **GitHub/Copilot** — our dev workflow and AI coding assistant ecosystem.';
  }
  if (text.includes('semantic kernel') || text.includes('dapr')) {
    return '🔗 **Microsoft OSS** — tooling we build on or integrate with directly.';
  }
  if (text.includes('security') || text.includes('cve') || text.includes('vulnerab')) {
    return '🔐 **Security** — action required: check if we\'re exposed.';
  }
  if (text.includes('docker') || text.includes('container') || text.includes('helm')) {
    return '🐳 **Containers/Helm** — runtime and packaging tech we depend on daily.';
  }
  if (text.includes('ai') || text.includes('llm') || text.includes('gpt')) {
    return '🌐 **AI ecosystem** — foundation models powering the features we ship.';
  }
  return '📡 **Tech radar** — worth tracking as the ecosystem evolves.';
}

function generateTldr(story) {
  const title = story.title;
  const lower = title.toLowerCase();

  // If we fetched a real article description, use it directly — far more accurate than title heuristics.
  // Strip HTML tags, truncate gracefully at sentence boundary.
  if (story.description && story.description.length > 40) {
    const desc = story.description.replace(/<[^>]+>/g, '').trim();
    if (desc.length <= 200) return desc;
    const truncated = desc.slice(0, 197);
    const lastPeriod = truncated.lastIndexOf('.');
    return lastPeriod > 60 ? truncated.slice(0, lastPeriod + 1) : truncated + '…';
  }

  const isRelease = /\bv?\d+\.\d+(\.\d+)?/.test(lower)
    || lower.includes('release') || lower.includes('launches') || lower.includes('released') || lower.includes('ships');

  if (isRelease) {
    if (lower.includes('.net') || lower.includes('dotnet') || lower.includes('aspnet') || lower.includes('blazor') || lower.includes('aspire')) {
      return '.NET ecosystem release — check the changelog for breaking changes and new capabilities affecting our services.';
    }
    if (lower.includes('kubernetes') || lower.includes('k8s')) {
      return 'Kubernetes version drop — important for AKS fleet upgrade planning and compatibility checks.';
    }
    if (lower.includes('copilot') || lower.includes('github')) {
      return 'GitHub/Copilot update — new capabilities may be live in our dev workflow today.';
    }
    if (lower.includes('azure')) {
      return 'Azure service release — review for new features or pricing changes that affect our cloud footprint.';
    }
    if (lower.includes('mcp') || lower.includes('model context protocol')) {
      return 'MCP protocol update — new tools or capabilities our agents can leverage.';
    }
    return 'New release worth noting — version bump that may affect our dependencies or toolchain.';
  }

  if (lower.includes('ai agent') || lower.includes('agentic') || lower.includes('multi-agent')) {
    return 'AI agent architecture development — directly relevant to our multi-agent squad system design.';
  }
  if (lower.includes('mcp') || lower.includes('model context protocol')) {
    return 'MCP ecosystem update — could change how our agents connect to tools and data sources.';
  }
  if (lower.includes('kubernetes') || lower.includes('k8s') || lower.includes('aks')) {
    return 'K8s ecosystem development — worth a read for the platform engineering side of our work.';
  }
  if (lower.includes('azure')) {
    return 'Azure news affecting our cloud platform — feature, pricing, or capability change worth tracking.';
  }
  if (lower.includes('.net') || lower.includes('dotnet') || lower.includes('c#') || lower.includes('aspnet')) {
    return '.NET/C# development — directly relevant to our backend services and tooling.';
  }
  if (lower.includes('security') || lower.includes('cve') || lower.includes('vulnerab') || lower.includes('patch')) {
    return 'Security advisory — scan our dependencies and infrastructure for exposure before end of day.';
  }
  if (lower.includes('copilot')) {
    return 'Copilot/AI coding tool update — may change our dev productivity or available features.';
  }
  if (lower.includes('llm') || lower.includes('gpt') || lower.includes('claude') || lower.includes('openai') || lower.includes('anthropic')) {
    return 'Foundation model news — context for the AI capabilities we\'re building on top of.';
  }
  if (lower.includes('docker') || lower.includes('container') || lower.includes('helm')) {
    return 'Container ecosystem update — check for anything affecting our build and deployment pipeline.';
  }
  return 'Notable development in the tech landscape — worth a skim to stay ahead of the curve.';
}

// Neelix personality commentary — grouped by relevance tier.
// Neelix is Star Trek Voyager's enthusiastic chef/morale officer: witty, warm, occasionally
// over-the-top, always genuine. He loves analogies to food, space travel, and strange aliens.
const NEELIX_QUIPS = {
  HIGH: [
    "Now THIS is what I call a hearty serving of relevance! Straight to the crew's reading list. 🍲",
    "Captain, I'd put this one on the *essential menu* — as important as keeping the replicators running. 🚀",
    "Direct hit on our tech stack. The kind of story that separates a well-prepared crew from a hungry one.",
    "I've seen a lot of strange things in the Delta Quadrant, but THIS level of relevance? Truly remarkable.",
    "As my Talaxian grandmother always said: when the tech matters, you read it *twice*.",
    "Computer, flag this for the senior staff briefing. We're on course heading for this one. 🖖",
    "I wouldn't interrupt the captain's dinner for most things — but for this? Absolutely.",
    "Call this the plomeek soup of tech news: nourishing, slightly acquired taste, absolutely essential. 🍵",
  ],
  MEDIUM: [
    "A solid side dish — not the main course, but don't you dare skip it.",
    "Keep this one warm on the back burner. Could be useful before end of quarter. 🔥",
    "Medium relevance, but in the Delta Quadrant, a 'side dish' has saved this ship more than once.",
    "The crew should glance at this between missions. Knowledge is the best ration pack.",
    "Not an emergency, but absolutely worth a coffee-break read. ☕",
    "Situational awareness, ensign — that's what separates good engineers from great navigators.",
    "I wouldn't interrupt dinner for this, but I'd mention it over dessert. You've been warned. 🍮",
    "Think of it as leola root stew: nobody's excited, but later they're grateful they had it.",
  ],
};

/**
 * Return a Neelix quip for a story.
 *
 * Bug fixed (was: every story got the SAME quip every day):
 *   Old formula: `(getDate() + quips.length) % quips.length`
 *   Since `quips.length` is a constant, `% quips.length` always yielded the
 *   same index regardless of story — quip[0] for every item, every run.
 *
 * Fix: fold a simple hash of the story URL (or title) into the seed so each
 * story deterministically picks a *different* quip while remaining stable
 * across repeated runs on the same day.
 *
 * @param {string} relevance - 'HIGH' or 'MEDIUM'
 * @param {{ url?: string, title?: string }} story - the story being annotated
 */
function getNeelixQuip(relevance, story) {
  const quips = NEELIX_QUIPS[relevance] || NEELIX_QUIPS.MEDIUM;
  // Build a per-story hash from the URL (stable, unique per story)
  const storyKey = (story && (story.url || story.title)) || '';
  let hash = 0;
  for (let i = 0; i < storyKey.length; i++) {
    // djb2-style hash — fast, no deps, good distribution
    hash = (hash * 31 + storyKey.charCodeAt(i)) & 0xffff;
  }
  // Combine with day-of-month so the mapping rotates daily (still deterministic
  // within a day so re-runs produce the same digest)
  const seed = (new Date().getDate() + hash) % quips.length;
  return quips[seed];
}

// ─── Story-specific Neelix take (issue #1032) ────────────────────────────────
// More opinionated and story-aware than the generic tier quips.
// Uses the story's actual content to produce relevant, witty commentary.
// Falls back to the tier quips (with per-story hash) when no specific match.
function _storyHash(story) {
  const key = story.url || story.title || '';
  let h = 0;
  for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) & 0xffff;
  return h;
}

function generateNeelixTake(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();

  // Security / CVE — urgent and dramatic
  if (text.includes('security') || text.includes('cve') || text.includes('vulnerab') || text.includes('breach') || text.includes('exploit')) {
    const takes = [
      "Red alert, all hands! I don't care if you're mid-meal — this one deserves your full attention. 🚨",
      "As a Talaxian who once survived a Vidiian raid, I know when to stop cooking and start running. This is one of those times.",
      "The replicators can wait. Go patch your stack. I'll keep the soup warm. 🔐",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // Squad product updates — proud chef energy
  if (story.title.startsWith('[Squad') || story.title.startsWith('[Brady Blog]')) {
    const takes = [
      "This is our own kitchen! The crew cooked this. Go see what Brady and the team have been brewing. 🍲",
      "Squad news is the BEST news. I love it when we make our own headlines. 🚀",
      "When your own product makes the digest — that's a good day. Even I couldn't have planned a better menu. ⚡",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // MCP / Model Context Protocol
  if (text.includes('mcp') || text.includes('model context protocol')) {
    const takes = [
      "Ah, the connective tissue of the AI agent world. Every new MCP tool is a new ingredient in the pantry. 🔌",
      "MCP is how our agents shake hands with the universe. This handshake might be worth taking. 🤝",
      "More MCP? More power to our agents. The kitchen is expanding — always a good sign. 🍳",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // AI agents / agentic / multi-agent
  if (text.includes('ai agent') || text.includes('agentic') || text.includes('multi-agent') || text.includes('autonomous agent')) {
    const takes = [
      "Fellow travellers in the agent space! The more agents, the merrier the starship. 🧠",
      "This is the kind of research that makes our squad architecture smarter. Read it and feed your brain. 🤖",
      "Agentic patterns are our bread and butter. This is practically a recipe card for our own work. 📋",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // GitHub rate limits — specific pain point for our scanner
  if (text.includes('rate limit') && text.includes('github')) {
    return "Ah yes, GitHub rate limits — our old frenemy. This might have a workaround worth stealing for our own scanner. 👀";
  }

  // KEDA / autoscaling
  if (text.includes('keda') || (text.includes('autoscal') && (text.includes('kubernetes') || text.includes('k8s')))) {
    return "KEDA and event-driven scaling are how we keep the starship from overloading the engines. Platform team, this one's for you. ⚖️";
  }

  // .NET releases
  if ((text.includes('.net') || text.includes('dotnet') || text.includes('aspnet') || text.includes('blazor') || text.includes('aspire')) &&
      (/\bv?\d+\.\d+/.test(text) || text.includes('releases') || text.includes('launched') || text.includes('ships'))) {
    return "A .NET release! Check the changelog before the next deployment window. Consider this a mandatory pre-flight checklist. 🔷";
  }

  // .NET general
  if (text.includes('.net') || text.includes('dotnet') || text.includes('csharp') || text.includes('c#') || text.includes('aspnet') || text.includes('blazor') || text.includes('aspire')) {
    const takes = [
      "The .NET ecosystem never sleeps — and neither should our attention to it. 🔷",
      "C# and .NET: our bread and butter. Good fundamentals in cooking AND in code. 🍞",
      "Microsoft's flagship stack is making moves. The backend crew should take note. ⚙️",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // Kubernetes / K8s / AKS
  if (text.includes('kubernetes') || text.includes('k8s') || text.includes('aks')) {
    const takes = [
      "The fleet management platform speaks! When Kubernetes updates, the whole galaxy should listen. ☸️",
      "K8s news affects our entire deployment pipeline. Like turbulence on a warp jump — know about it early. 🚀",
      "AKS and K8s form the bones of our infrastructure. Platform team: your reading assignment awaits. 🏗️",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // Azure
  if (text.includes('azure')) {
    const takes = [
      "Our cloud home is talking. New features or deprecated services — both matter to the stack. ☁️",
      "Azure updates can sneak up on you like a Hirogen hunting party. Better to be informed. 🌐",
      "When the cloud changes, our architecture feels it. Keep your eyes on this one. 🔭",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // GitHub Copilot
  if (text.includes('copilot') || (text.includes('github') && (text.includes('ai') || text.includes('coding')))) {
    return "GitHub Copilot is practically a crew member at this point. Stay current with what your digital sous-chef can do. 🤖";
  }

  // Semantic Kernel / Dapr
  if (text.includes('semantic kernel') || text.includes('dapr')) {
    return "Microsoft OSS tooling we build on directly. Changes here ripple through our services — worth a look before they surprise us. 🔗";
  }

  // LLM / foundation models
  if (text.includes('llm') || text.includes('gpt') || text.includes('claude') || text.includes('gemini') || text.includes('openai') || text.includes('anthropic')) {
    const takes = [
      "The foundation models powering our features are evolving again. Like adjusting the replicator matrix — worth knowing what changed. 🌐",
      "An update to the brains beneath the operation. Worth tracking which direction the LLM universe is drifting. 🧠",
      "These models are the warp core of our AI features. Knowing the state of the art keeps us competitive. ⚡",
    ];
    return takes[_storyHash(story) % takes.length];
  }

  // Docker / containers / Helm / GitOps
  if (text.includes('docker') || text.includes('container') || text.includes('helm') || text.includes('gitops') || text.includes('argocd') || text.includes('flux')) {
    return "Container ecosystem news. Not glamorous, but vital — like the ship's air recyclers. Check for anything that touches our build pipeline. 🐳";
  }

  // Fall back to tier quips with per-story hash (different story = different quip)
  const quips = NEELIX_QUIPS[story.relevance] || NEELIX_QUIPS.MEDIUM;
  return quips[_storyHash(story) % quips.length];
}

// ─── Read / Skip recommendation (issue #1032) ────────────────────────────────
// "You should look at this because..." or "Skip this, here's why..."
function generateRecommendation(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  const isReleaseLike = /\bv?\d+\.\d+/.test(text) || text.includes('releases') || text.includes('launched') || text.includes('ships');

  if (story.relevance === 'HIGH') {
    if (text.includes('security') || text.includes('cve') || text.includes('vulnerab') || text.includes('exploit')) {
      return "🔴 **Read it now** — Security issues don't wait for convenient timing. Verify we're not exposed before end of day.";
    }
    if (story.title.startsWith('[Squad') || text.includes('squad')) {
      return "⚡ **Read it** — This is our own product. Staying current with Squad changes is non-optional for the team.";
    }
    if (text.includes('mcp') || text.includes('model context protocol')) {
      return "✅ **Read it** — MCP is core to our agent architecture. New tools or spec changes can ship directly into our stack.";
    }
    if ((text.includes('.net') || text.includes('dotnet') || text.includes('aspnet')) && isReleaseLike) {
      return "✅ **Read it** — .NET releases can carry breaking changes. Review the changelog before the next deployment window.";
    }
    if (text.includes('kubernetes') || text.includes('k8s') || text.includes('aks')) {
      return "✅ **Read it** — K8s and AKS changes affect our entire fleet. Platform team: this is required reading.";
    }
    if (text.includes('azure')) {
      return "✅ **Read it** — Azure is our cloud home. Feature changes, deprecations, and pricing shifts all affect the stack.";
    }
    if (text.includes('copilot')) {
      return "✅ **Read it** — Copilot changes land immediately in our developer workflow. Know what's new before tomorrow's sprint.";
    }
    if (text.includes('ai agent') || text.includes('agentic') || text.includes('multi-agent')) {
      return "✅ **Read it** — Multi-agent patterns are central to what we build. Likely has directly applicable ideas.";
    }
    return "✅ **Read it** — High signal for our work. Budget 10 minutes — it'll pay off.";
  }

  if (story.relevance === 'MEDIUM') {
    if (text.includes('security') || text.includes('cve') || text.includes('vulnerab')) {
      return "⚠️ **Worth checking** — Security news ignores relevance tiers. Quick scan recommended even at MEDIUM.";
    }
    if (text.includes('ai') || text.includes('llm') || text.includes('agent')) {
      return "📖 **Worth a skim** — AI moves fast. Staying aware of the broader landscape prevents nasty surprises.";
    }
    if (text.includes('github') || text.includes('vscode') || text.includes('devtools') || text.includes('developer tool')) {
      return "📖 **Skim it** — Developer tooling affects daily flow. A coffee-break read is enough.";
    }
    if (text.includes('docker') || text.includes('container') || text.includes('helm')) {
      return "📖 **Skim it** — Container ecosystem change. Worth knowing before it surprises us in a deployment.";
    }
    return "📖 **Worth a skim** — Adjacent to our work. Good for maintaining ecosystem awareness. Coffee-break material.";
  }

  return "⏭️ **Skip unless specifically interested** — Low direct relevance to current sprint work.";
}

// ─── Keyword match transparency (issue #1032) ────────────────────────────────
// Shows WHICH keywords triggered the HIGH / MEDIUM classification.
function getMatchedKeywords(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  const highMatches = HIGH_RELEVANCE_KEYWORDS.filter(kw => text.includes(kw));
  if (highMatches.length > 0) return highMatches.slice(0, 4);
  return MEDIUM_RELEVANCE_KEYWORDS.filter(kw => text.includes(kw)).slice(0, 4);
}

function generateActionItems(stories) {
  const actions = [];
  for (const story of stories) {
    if (story.relevance !== 'HIGH') continue;
    const text = story.title.toLowerCase();

    if (/\bv?\d+\.\d+/.test(text) && (text.includes('.net') || text.includes('dotnet'))) {
      actions.push(`🔷 **Review .NET release**: [${story.title}](${story.url}) — check changelog for breaking changes affecting our services`);
    } else if (/\bv?\d+\.\d+/.test(text) && (text.includes('kubernetes') || text.includes('k8s'))) {
      actions.push(`☸️ **Plan K8s upgrade window**: [${story.title}](${story.url}) — assess AKS fleet compatibility`);
    } else if (text.includes('security') || text.includes('cve') || text.includes('vulnerab')) {
      actions.push(`🔐 **Security check**: [${story.title}](${story.url}) — verify our stack is not exposed`);
    } else if (text.includes('mcp') || text.includes('model context protocol')) {
      actions.push(`🔌 **Evaluate for agent tooling**: [${story.title}](${story.url}) — MCP compatibility and adoption potential`);
    } else if (text.includes('copilot') && (text.includes('feature') || text.includes('update') || text.includes('new'))) {
      actions.push(`🤖 **Try new Copilot capability**: [${story.title}](${story.url})`);
    } else if (text.includes('azure') && (text.includes('aks') || text.includes('kubernetes'))) {
      actions.push(`☁️ **Azure/AKS review**: [${story.title}](${story.url}) — check impact on our cluster configuration`);
    } else if (text.includes('squad') && (text.includes('release') || text.includes('update'))) {
      actions.push(`⚡ **Squad product update**: [${story.title}](${story.url}) — our own tooling, stay current!`);
    }
  }
  return actions.slice(0, 6);
}

/**
 * Generate a per-story inline action item (used in rich digest format).
 * More specific than the bulk generateActionItems — one targeted recommendation per story.
 */
function generatePerStoryActionItem(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();

  if (text.includes('security') || text.includes('cve') || text.includes('vulnerab') || text.includes('breach') || text.includes('exploit')) {
    return '🔐 **Audit now** — check our dependencies and infra for exposure before end of day.';
  }
  if (/\bv?\d+\.\d+/.test(text) && (text.includes('.net') || text.includes('dotnet') || text.includes('aspnet') || text.includes('blazor') || text.includes('aspire'))) {
    return '🔷 **Review changelog** — check for breaking changes before bumping our service dependencies.';
  }
  if (/\bv?\d+\.\d+/.test(text) && (text.includes('kubernetes') || text.includes('k8s'))) {
    return '☸️ **Schedule upgrade review** — assess AKS fleet compatibility and plan an upgrade window.';
  }
  if (text.includes('mcp') || text.includes('model context protocol')) {
    return '🔌 **Evaluate adoption** — assess MCP compatibility for our agent tooling pipeline.';
  }
  if (text.includes('copilot') && (text.includes('new') || text.includes('feature') || text.includes('update') || text.includes('release'))) {
    return '🤖 **Try it today** — test the new Copilot capability in your next dev session.';
  }
  if (text.includes('azure') && (text.includes('aks') || text.includes('kubernetes'))) {
    return '☁️ **Check cluster impact** — review against our AKS cluster configuration.';
  }
  if (text.includes('squad') && (text.includes('release') || text.includes('update') || text.includes('new') || text.includes('commit'))) {
    return '⚡ **Pull and update** — our own tooling evolved, stay current!';
  }
  if (text.includes('ai agent') || text.includes('agentic') || text.includes('multi-agent')) {
    return '🧠 **Consider adoption** — explore if this improves our multi-agent squad architecture.';
  }
  if (text.includes('semantic kernel') || text.includes('dapr')) {
    return '🔗 **Check compatibility** — verify against the Microsoft OSS libs we depend on.';
  }
  if (story.relevance === 'HIGH') {
    return '📖 **Read this** — directly impacts our stack. Worth 10 minutes of your time.';
  }
  return '👀 **Keep an eye on this** — worth a quick skim to stay ahead of the curve.';
}

/**
 * Map a story to a category emoji + label for the rich digest format.
 * Used as the section header for each story block.
 */
function getCategoryLabel(story) {
  const text = `${story.title} ${story.description || ''}`.toLowerCase();
  if (story.title.startsWith('[Squad') || text.includes('squad')) return '⚡ SQUAD';
  if (text.includes('mcp') || text.includes('model context protocol')) return '🔌 MCP';
  if (text.includes('ai agent') || text.includes('agentic') || text.includes('multi-agent')) return '🧠 AI AGENTS';
  if (text.includes('copilot') || (text.includes('github') && text.includes('ai'))) return '🤖 COPILOT';
  if (text.includes('kubernetes') || text.includes('k8s') || text.includes('aks')) return '☸️ KUBERNETES';
  if (text.includes('azure') || (text.includes('microsoft') && !text.includes('squad'))) return '⭐ AZURE';
  if (text.includes('.net') || text.includes('dotnet') || text.includes('csharp') || text.includes('c#') || text.includes('aspnet') || text.includes('blazor') || text.includes('aspire')) return '🔷 .NET';
  if (text.includes('security') || text.includes('cve') || text.includes('vulnerab')) return '🔐 SECURITY';
  if (text.includes('docker') || text.includes('container') || text.includes('helm')) return '🐳 CONTAINERS';
  if (text.includes('aws') || text.includes('amazon web services')) return '☁️ AWS';
  if (text.includes('opentelemetry') || text.includes('otel') || text.includes('observ')) return '📊 OBSERVABILITY';
  if (text.includes('ai') || text.includes('llm') || text.includes('gpt') || text.includes('claude') || text.includes('openai') || text.includes('gemini')) return '🌐 AI/ML';
  return '📡 TECH';
}

// Brady's Squad repo monitoring config
const SQUAD_REPO = { owner: 'bradygaster', repo: 'squad' };
const BRADY_BLOG_URL = 'https://bradygaster.com';

// Teams channel targets for posting digests
// public: true  = shared with external collaborators — NO issue numbers, repo names, or internal refs
// public: false = Tamir's private notifications — full content with issue links and internal refs
const TEAMS_CHANNELS = [
  { teamId: '5f93abfe-b968-44ea-bd0a-6f155046ccc7', channelId: '19:bfe3224e8e764c2785e81e7cb3cc944d@thread.tacv2', label: 'squads > Tech News', public: false },
  { teamId: '1de78cdf-3f73-4447-9601-a940bd98b80d', channelId: '19:c940af255e22486882c069d7b38a6204@thread.tacv2', label: 'Squad > Squad Tech News', public: true }
];

// Setup state file path
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const stateDir = path.join(__dirname, '..', '.squad', 'monitoring');
const stateFile = path.join(stateDir, 'tech-news-state.json');

// Ensure state directory exists
function ensureStateDir() {
  if (!fs.existsSync(stateDir)) {
    fs.mkdirSync(stateDir, { recursive: true });
  }
}

// Load state from file
function loadState() {
  try {
    if (fs.existsSync(stateFile)) {
      const data = fs.readFileSync(stateFile, 'utf8');
      return JSON.parse(data);
    }
  } catch (e) {
    console.error(`Warning: Could not load state file: ${e.message}`);
  }
  return { lastScanDate: null, reportedUrls: {} };
}

// Save state to file
function saveState(state) {
  try {
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2), 'utf8');
  } catch (e) {
    console.error(`Warning: Could not save state file: ${e.message}`);
  }
}

// Get today's date in YYYY-MM-DD format
function getTodayDate() {
  return new Date().toISOString().split('T')[0];
}

// Check if an issue already exists for today
function issueExistsForToday(date) {
  try {
    const searchTerm = `Tech News Digest: ${date} in:title`;
    const output = execFileSync(
      'gh', ['issue', 'list', '--state', 'all', '--search', searchTerm, '--json', 'number,title'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
    ).trim();
    const issues = JSON.parse(output || '[]');
    // Exact title match to avoid false positives from fuzzy search
    const exactMatch = issues.some(i => i.title && i.title.includes(`Tech News Digest: ${date}`));
    return exactMatch;
  } catch (e) {
    console.error(`Warning: Could not check for existing issues: ${e.message}`);
    return false;
  }
}

function httpsGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'TechNewsScanner/1.0' } }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    }).on('error', reject);
  });
}

/**
 * Decode common HTML entities in a string (used when cleaning up meta descriptions).
 */
function decodeHtmlEntities(str) {
  return str
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code, 10)));
}

/**
 * Fetch the meta description (og:description or name=description) from an article URL.
 * Returns the description string, or null if unavailable/timed out.
 * Skips Reddit and HN URLs (no useful meta descriptions there).
 *
 * @param {string} url - Article URL to fetch
 * @param {number} [timeoutMs=5000] - Timeout in milliseconds
 * @returns {Promise<string|null>}
 */
async function fetchArticleSnippet(url, timeoutMs = 5000) {
  return new Promise((resolve) => {
    try {
      const parsedUrl = new URL(url);

      // Skip aggregator/community pages — no useful meta descriptions
      if (
        parsedUrl.hostname.includes('reddit.com') ||
        parsedUrl.hostname.includes('ycombinator.com') ||
        parsedUrl.hostname.includes('news.ycombinator.com')
      ) {
        resolve(null);
        return;
      }

      const lib = parsedUrl.protocol === 'https:' ? https : http;
      let req;
      const timer = setTimeout(() => {
        try { req && req.destroy(); } catch (_) {}
        resolve(null);
      }, timeoutMs);

      req = lib.get(url, {
        headers: {
          'User-Agent': 'TechNewsScanner/1.0',
          'Accept': 'text/html,application/xhtml+xml',
        },
      }, (res) => {
        // Follow single redirect
        if ((res.statusCode === 301 || res.statusCode === 302 || res.statusCode === 303) && res.headers.location) {
          clearTimeout(timer);
          resolve(fetchArticleSnippet(res.headers.location, timeoutMs - 500));
          return;
        }

        let data = '';
        res.on('data', (chunk) => {
          data += chunk;
          // Stop reading once we have enough HTML to find meta tags (~40KB)
          if (data.length > 40000) {
            try { req.destroy(); } catch (_) {}
          }
        });

        res.on('end', () => {
          clearTimeout(timer);
          // Try og:description first (usually the best quality)
          const ogMatch =
            data.match(/<meta[^>]+property=["']og:description["'][^>]+content=["']([^"']{10,300}?)["']/i) ||
            data.match(/<meta[^>]+content=["']([^"']{10,300}?)["'][^>]+property=["']og:description["']/i);
          if (ogMatch) { resolve(decodeHtmlEntities(ogMatch[1].trim())); return; }

          // Try name="description"
          const metaMatch =
            data.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']{10,300}?)["']/i) ||
            data.match(/<meta[^>]+content=["']([^"']{10,300}?)["'][^>]+name=["']description["']/i);
          if (metaMatch) { resolve(decodeHtmlEntities(metaMatch[1].trim())); return; }

          resolve(null);
        });
        res.on('error', () => { clearTimeout(timer); resolve(null); });
        res.on('close', () => { /* end already fires */ });
      });

      req.on('error', () => { clearTimeout(timer); resolve(null); });
    } catch (e) {
      resolve(null);
    }
  });
}

function matchesKeywords(text) {
  if (!text) return false;
  const lowerText = text.toLowerCase();
  return KEYWORDS.some(keyword => lowerText.includes(keyword));
}

async function fetchHackerNews() {
  console.error('Fetching HackerNews top stories...');
  const topStoryIds = await httpsGet('https://hacker-news.firebaseio.com/v0/topstories.json');
  
  // Fetch top 30 stories
  const storyPromises = topStoryIds.slice(0, 30).map(id =>
    httpsGet(`https://hacker-news.firebaseio.com/v0/item/${id}.json`)
  );
  
  const stories = await Promise.all(storyPromises);
  
  // Filter for relevant stories
  const filtered = stories.filter(story => 
    story && story.title && matchesKeywords(story.title)
  ).map(story => ({
    title: story.title,
    url: story.url || `https://news.ycombinator.com/item?id=${story.id}`,
    score: story.score,
    source: 'HackerNews'
  }));
  
  console.error(`Found ${filtered.length} relevant HackerNews stories`);
  return filtered;
}

async function fetchReddit(subreddit) {
  console.error(`Fetching Reddit: ${subreddit}...`);
  try {
    const data = await httpsGet(`https://www.reddit.com/r/${subreddit}/hot.json?limit=25`);
    
    if (!data.data || !data.data.children) {
      console.error(`No data from r/${subreddit}`);
      return [];
    }
    
    const posts = data.data.children
      .map(child => child.data)
      .filter(post => post.title && matchesKeywords(post.title))
      .map(post => ({
        title: post.title,
        url: `https://www.reddit.com${post.permalink}`,
        score: post.score,
        source: `Reddit: r/${subreddit}`
      }));
    
    console.error(`Found ${posts.length} relevant posts in r/${subreddit}`);
    return posts;
  } catch (e) {
    console.error(`Error fetching r/${subreddit}: ${e.message}`);
    return [];
  }
}

async function fetchMorningDew() {
  console.error('Fetching Morning Dew (alvinashcraft.com)...');
  try {
    const xml = await httpsGet('https://www.alvinashcraft.com/feed/');

    if (typeof xml !== 'string') {
      console.error('Unexpected response from Morning Dew feed');
      return [];
    }

    // Parse RSS <item> entries with simple regex
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/) || [])[1]
        || (block.match(/<title>(.*?)<\/title>/) || [])[1]
        || '';
      const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
      const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

      if (title && link) {
        items.push({ title: title.trim(), url: link.trim(), pubDate });
      }
    }

    // Filter by keywords
    const filtered = items
      .filter(item => matchesKeywords(item.title))
      .map(item => ({
        title: item.title,
        url: item.url,
        score: 50, // base score for RSS items (no upvote data)
        source: 'Morning Dew'
      }));

    console.error(`Found ${filtered.length} relevant Morning Dew items`);
    return filtered;
  } catch (e) {
    console.error(`Error fetching Morning Dew: ${e.message}`);
    return [];
  }
}

async function fetchArchitectureNotes() {
  console.error('Fetching Architecture Notes (architecturenotes.co)...');
  try {
    const xml = await httpsGet('https://architecturenotes.co/feed');

    if (typeof xml !== 'string') {
      console.error('Unexpected response from Architecture Notes feed');
      return [];
    }

    // Parse RSS <item> entries with simple regex
    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/) || [])[1]
        || (block.match(/<title>(.*?)<\/title>/) || [])[1]
        || '';
      const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
      const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

      if (title && link) {
        items.push({ title: title.trim(), url: link.trim(), pubDate });
      }
    }

    // Filter by keywords
    const filtered = items
      .filter(item => matchesKeywords(item.title))
      .map(item => ({
        title: item.title,
        url: item.url,
        score: 50, // base score for RSS items (no upvote data)
        source: 'Architecture Notes'
      }));

    console.error(`Found ${filtered.length} relevant Architecture Notes items`);
    return filtered;
  } catch (e) {
    console.error(`Error fetching Architecture Notes: ${e.message}`);
    return [];
  }
}

async function fetchThoughtWorksRadar() {
  console.error('Fetching ThoughtWorks Technology Radar...');
  const feedUrls = [
    'https://www.thoughtworks.com/content/dam/thoughtworks/documents/radar/tw_radar.rss',
    'https://www.thoughtworks.com/rss',
    'https://www.thoughtworks.com/radar/rss',
    'https://feeds.feedburner.com/ThoughtworksRadar'
  ];

  for (const feedUrl of feedUrls) {
    try {
      const xml = await httpsGet(feedUrl);

      if (typeof xml !== 'string') {
        continue;
      }

      // Parse RSS <item> entries with simple regex (same approach as other RSS sources)
      const items = [];
      const itemRegex = /<item>([\s\S]*?)<\/item>/g;
      let match;
      while ((match = itemRegex.exec(xml)) !== null) {
        const block = match[1];
        const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>|<title>(.*?)<\/title>/) || [])[1]
          || (block.match(/<title>(.*?)<\/title>/) || [])[1]
          || '';
        const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
        const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

        if (title && link) {
          items.push({ title: title.trim(), url: link.trim(), pubDate });
        }
      }

      if (items.length === 0) {
        continue;
      }

      // Filter by keywords
      const filtered = items
        .filter(item => matchesKeywords(item.title))
        .map(item => ({
          title: item.title,
          url: item.url,
          score: 75, // higher base score — curated expert content
          source: 'ThoughtWorks Radar'
        }));

      console.error(`Found ${filtered.length} relevant ThoughtWorks Radar items (from ${feedUrl})`);
      return filtered;
    } catch (e) {
      console.error(`Error fetching ThoughtWorks Radar from ${feedUrl}: ${e.message}`);
    }
  }

  console.error('Could not fetch ThoughtWorks Radar from any feed URL');
  return [];
}

// Fetch releases from bradygaster/squad via GitHub API
async function fetchSquadReleases() {
  console.error('Fetching bradygaster/squad releases...');
  try {
    const output = execFileSync(
      'gh', ['api', `repos/${SQUAD_REPO.owner}/${SQUAD_REPO.repo}/releases`, '--jq', '.[0:10]'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const releases = JSON.parse(output || '[]');
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recent = releases
      .filter(r => new Date(r.published_at || r.created_at) > oneDayAgo)
      .map(r => ({
        title: `[Squad Release] ${r.name || r.tag_name}`,
        url: r.html_url,
        score: 100,
        source: 'bradygaster/squad',
        body: (r.body || '').slice(0, 300)
      }));
    console.error(`Found ${recent.length} recent Squad releases`);
    return recent;
  } catch (e) {
    console.error(`Error fetching Squad releases: ${e.message}`);
    return [];
  }
}

// Fetch recent discussions from bradygaster/squad
async function fetchSquadDiscussions() {
  console.error('Fetching bradygaster/squad discussions...');
  try {
    const query = `query { repository(owner:"${SQUAD_REPO.owner}", name:"${SQUAD_REPO.repo}") { discussions(first:10, orderBy:{field:CREATED_AT, direction:DESC}) { nodes { title url createdAt category { name } } } } }`;
    const output = execFileSync(
      'gh', ['api', 'graphql', '-f', `query=${query}`],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const data = JSON.parse(output || '{}');
    const discussions = data?.data?.repository?.discussions?.nodes || [];
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const recent = discussions
      .filter(d => new Date(d.createdAt) > oneDayAgo)
      .map(d => ({
        title: `[Squad Discussion] ${d.title}`,
        url: d.url,
        score: 80,
        source: 'bradygaster/squad',
        category: d.category?.name || 'General'
      }));
    console.error(`Found ${recent.length} recent Squad discussions`);
    return recent;
  } catch (e) {
    console.error(`Error fetching Squad discussions: ${e.message}`);
    return [];
  }
}

// Fetch recent commits from bradygaster/squad
async function fetchSquadCommits() {
  console.error('Fetching bradygaster/squad commits...');
  try {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const output = execFileSync(
      'gh', ['api', `repos/${SQUAD_REPO.owner}/${SQUAD_REPO.repo}/commits?since=${since}&per_page=10`],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    const commits = JSON.parse(output || '[]');
    const items = commits.map(c => ({
      title: `[Squad Commit] ${(c.commit?.message || '').split('\n')[0]}`,
      url: c.html_url,
      score: 60,
      source: 'bradygaster/squad',
      author: c.commit?.author?.name || 'unknown'
    }));
    console.error(`Found ${items.length} recent Squad commits`);
    return items;
  } catch (e) {
    console.error(`Error fetching Squad commits: ${e.message}`);
    return [];
  }
}

// Fetch Brady Gaster's blog RSS for Squad-related posts
async function fetchBradyBlog() {
  console.error('Fetching Brady Gaster blog for Squad posts...');
  try {
    const xml = await httpsGet(`${BRADY_BLOG_URL}/feed/`);
    if (typeof xml !== 'string') {
      // Try alternate feed path
      const xml2 = await httpsGet(`${BRADY_BLOG_URL}/index.xml`);
      if (typeof xml2 !== 'string') {
        console.error('Unexpected response from Brady blog feed');
        return [];
      }
      return parseBlogFeed(xml2);
    }
    return parseBlogFeed(xml);
  } catch (e) {
    console.error(`Error fetching Brady blog: ${e.message}`);
    return [];
  }
}

function parseBlogFeed(xml) {
  const items = [];
  const itemRegex = /<item>([\s\S]*?)<\/item>/g;
  let match;
  while ((match = itemRegex.exec(xml)) !== null) {
    const block = match[1];
    const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>/) || [])[1]
      || (block.match(/<title>(.*?)<\/title>/) || [])[1]
      || '';
    const link = (block.match(/<link>(.*?)<\/link>/) || [])[1] || '';
    const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';
    const description = (block.match(/<description><!\[CDATA\[(.*?)\]\]>/) || [])[1]
      || (block.match(/<description>(.*?)<\/description>/) || [])[1]
      || '';

    if (title && link) {
      items.push({ title: title.trim(), url: link.trim(), pubDate, description: description.trim() });
    }
  }

  // Filter for Squad-related posts
  const squadKeywords = ['squad', 'ai team', 'ai agents', 'copilot workspace'];
  const filtered = items.filter(item => {
    const text = `${item.title} ${item.description}`.toLowerCase();
    return squadKeywords.some(kw => text.includes(kw));
  }).map(item => ({
    title: `[Brady Blog] ${item.title}`,
    url: item.url,
    score: 90,
    source: 'bradygaster.com'
  }));

  console.error(`Found ${filtered.length} Squad-related Brady blog posts`);
  return filtered;
}

// AWS blog sources — added for issue #931
const AWS_BLOGS = [
  { name: 'AWS Architecture Blog',    feedUrl: 'https://aws.amazon.com/blogs/architecture/feed/',   category: 'cloud/aws', score: 80 },
  { name: 'AWS News Blog',            feedUrl: 'https://aws.amazon.com/blogs/aws/feed/',            category: 'cloud/aws', score: 85 },
  { name: 'AWS Compute Blog',         feedUrl: 'https://aws.amazon.com/blogs/compute/feed/',        category: 'cloud/aws', score: 75 },
  { name: 'AWS Developer Tools Blog', feedUrl: 'https://aws.amazon.com/blogs/developer/feed/',      category: 'cloud/aws', score: 70 },
  { name: 'AWS Containers Blog',      feedUrl: 'https://aws.amazon.com/blogs/containers/feed/',     category: 'cloud/aws', score: 75 },
];

/**
 * Fetch a single AWS blog RSS feed.
 * All AWS blogs use the same WordPress RSS structure.
 */
async function fetchAwsBlog({ name, feedUrl, category, score }) {
  console.error(`Fetching ${name}...`);
  try {
    const xml = await httpsGet(feedUrl);

    if (typeof xml !== 'string') {
      console.error(`Unexpected response from ${name}`);
      return [];
    }

    const items = [];
    const itemRegex = /<item>([\s\S]*?)<\/item>/g;
    let match;
    while ((match = itemRegex.exec(xml)) !== null) {
      const block = match[1];
      // AWS feeds use CDATA-wrapped titles
      const title = (block.match(/<title><!\[CDATA\[(.*?)\]\]>/) || [])[1]
        || (block.match(/<title>(.*?)<\/title>/) || [])[1]
        || '';
      // AWS feeds use <link> as a direct URL (no CDATA) but sometimes wrapped in CDATA
      const link = (block.match(/<link><!\[CDATA\[(.*?)\]\]>/) || [])[1]
        || (block.match(/<link>(.*?)<\/link>/) || [])[1]
        || '';
      const pubDate = (block.match(/<pubDate>(.*?)<\/pubDate>/) || [])[1] || '';

      if (title && link) {
        items.push({ title: title.trim(), url: link.trim(), pubDate });
      }
    }

    // AWS blogs are always cloud-relevant; still filter by keyword to avoid noise
    // but fall back to including all items from Architecture/News blogs (high signal)
    const isHighSignal = name === 'AWS Architecture Blog' || name === 'AWS News Blog';
    const filtered = items
      .filter(item => isHighSignal || matchesKeywords(item.title))
      .map(item => ({
        title: item.title,
        url: item.url,
        score,
        source: name,
        category,
      }));

    console.error(`Found ${filtered.length} relevant items from ${name}`);
    return filtered;
  } catch (e) {
    console.error(`Error fetching ${name}: ${e.message}`);
    return [];
  }
}

async function scanAllSources() {
  const subreddits = ['programming', 'webdev', 'dotnet', 'golang', 'artificial', 'MachineLearning', 'BlackboxAI_', 'GithubCopilot'];
  
  const [hnStories, morningDew, archNotes, twRadar, squadReleases, squadDiscussions, squadCommits, bradyBlog, ...rest] = await Promise.all([
    fetchHackerNews(),
    fetchMorningDew(),
    fetchArchitectureNotes(),
    fetchThoughtWorksRadar(),
    fetchSquadReleases(),
    fetchSquadDiscussions(),
    fetchSquadCommits(),
    fetchBradyBlog(),
    // AWS blogs (issue #931) — fetch all in parallel with other sources
    ...AWS_BLOGS.map(blog => fetchAwsBlog(blog)),
    ...subreddits.map(sub => fetchReddit(sub))
  ]);
  
  // rest = [awsArch, awsNews, awsCompute, awsDev, awsContainers, ...redditResults]
  const awsResults = rest.slice(0, AWS_BLOGS.length);
  const redditResults = rest.slice(AWS_BLOGS.length);

  const allStories = [
    ...hnStories,
    ...morningDew,
    ...archNotes,
    ...twRadar,
    ...awsResults.flat(),
    ...redditResults.flat(),
  ];
  const squadUpdates = [...squadReleases, ...squadDiscussions, ...squadCommits, ...bradyBlog];
  
  // Sort by score descending
  allStories.sort((a, b) => b.score - a.score);
  squadUpdates.sort((a, b) => b.score - a.score);
  
  return { stories: allStories, squadUpdates };
}

/**
 * Score, deduplicate, select top N stories, then fetch article descriptions in parallel.
 * This is the "deep analysis" pipeline that runs BEFORE formatting.
 *
 * Pipeline:
 *   1. Score each story (HIGH/MEDIUM/LOW) — drops LOW immediately
 *   2. Sort: HIGH first, then by source score
 *   3. Slice to maxStories
 *   4. Fetch meta description from each article URL (best-effort, 5s timeout)
 *   5. Enrich each story with: description, TL;DR, why it matters, Neelix quip, action item
 *
 * @param {Array} stories - Raw stories from scanAllSources
 * @param {number} [maxStories=10] - Max stories to deeply analyse
 * @returns {Promise<Array>} Enriched story objects
 */
async function enrichStoriesWithDescriptions(stories, maxStories = 10) {
  // Score and filter LOW-relevance
  const scored = stories
    .map(s => ({ ...s, relevance: scoreRelevance(s) }))
    .filter(s => s.relevance !== 'LOW');

  // Sort: HIGH first, then by source score
  scored.sort((a, b) => {
    const tier = { HIGH: 0, MEDIUM: 1 };
    const tierDiff = (tier[a.relevance] || 2) - (tier[b.relevance] || 2);
    if (tierDiff !== 0) return tierDiff;
    return (b.score || 0) - (a.score || 0);
  });

  const top = scored.slice(0, maxStories);

  // Fetch article descriptions in parallel — best effort, never block the digest
  console.error(`Fetching article descriptions for top ${top.length} stories…`);
  const descResults = await Promise.allSettled(
    top.map(s => fetchArticleSnippet(s.url))
  );

  return top.map((s, i) => {
    const desc = descResults[i].status === 'fulfilled' ? descResults[i].value : null;
    const enriched = { ...s, description: desc || s.description || null };
    return {
      ...enriched,
      tldr:         generateTldr(enriched),
      whyItMatters: getWhyItMatters(enriched),
      neelixQuip:   getNeelixQuip(enriched.relevance, enriched),
      actionItem:   generatePerStoryActionItem(enriched),
      category:     getCategoryLabel(enriched),
    };
  });
}


/**
 * Strips GitHub issue numbers (#XXX), repo names (tamresearch1), internal Squad references,
 * and any private repo URLs so nothing internal leaks to shared channels.
 */
function sanitizeForPublic(text) {
  return text
    // Remove issue references like #920, Issue #123, issue #45
    .replace(/\b[Ii]ssue\s*#\d+/g, '')
    // Remove standalone #NNN references (but not inside URLs)
    .replace(/(?<![/\w])#\d+\b/g, '')
    // Remove repo name references
    .replace(/\btamresearch1\b/gi, '')
    // Remove GitHub URLs pointing to private repos
    .replace(/https?:\/\/github\.com\/[^/]+\/tamresearch1[^\s)>]*/g, '')
    // Remove internal scanner/script references
    .replace(/\bscanner script\b/gi, '')
    // Remove Squad internal metadata labels
    .replace(/\bsquad:(copilot|review|triage)\b/gi, '')
    // Clean up leftover empty parentheses or brackets from removed refs
    .replace(/\(\s*\)/g, '')
    .replace(/\[\s*\]/g, '')
    // Collapse multiple blank lines
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/**
 * Format a single story block in the rich Neelix digest style.
 *
 * Format:
 *   ### CATEGORY EMOJI
 *   **Title** *(Source)*
 *   > 📖 TL;DR: ...
 *   🎙️ Neelix says: "..."
 *   💡 Action: ... (private only)
 *   🔗 URL
 */
function formatStoryBlock(story, { isTopStory = false, isPublic = false } = {}) {
  const categoryHeader = isTopStory ? '🔥 TOP STORY' : (story.category || getCategoryLabel(story));
  let block = '';

  block += `### ${categoryHeader}\n\n`;
  block += `**${story.title}** *(${story.source})*\n\n`;
  block += `> 📖 **TL;DR:** ${story.tldr}\n\n`;

  if (story.neelixQuip) {
    block += `🎙️ *Neelix says: "${story.neelixQuip}"*\n\n`;
  }

  if (!isPublic && story.actionItem) {
    block += `💡 **Action:** ${story.actionItem}\n\n`;
  }

  block += `🔗 ${story.url}\n\n`;
  return block;
}

/**
 * Format the tech news digest using pre-enriched stories (from enrichStoriesWithDescriptions).
 *
 * New rich format (issue #1032):
 *   🔥 TOP STORY — spotlight on the #1 HIGH-relevance pick
 *   🔴 HIGH RELEVANCE — remaining HIGH stories with category labels
 *   🟡 MEDIUM RELEVANCE — MEDIUM stories
 *   🚀 Squad Product Updates — private digests only
 *
 * Each story block includes: TL;DR, Neelix commentary, inline action item.
 *
 * @param {Array}  enrichedStories - Pre-enriched story objects (from enrichStoriesWithDescriptions)
 * @param {Array}  [squadUpdates=[]] - Squad product updates
 * @param {object} [opts]
 * @param {boolean} [opts.isPublic=false] - Sanitize for public channels
 */
function formatDigest(enrichedStories, squadUpdates = [], { isPublic = false } = {}) {
  const date = new Date().toISOString().split('T')[0];

  // ── enrichedStories already scored/filtered by enrichStoriesWithDescriptions ─
  // Add any fields that enrichStoriesWithDescriptions doesn't generate yet.
  const enriched = enrichedStories.map(story => ({
    ...story,
    neelixTake:      story.neelixTake      || generateNeelixTake(story),
    recommendation:  story.recommendation  || generateRecommendation(story),
    matchedKeywords: story.matchedKeywords || getMatchedKeywords(story),
  }));

  const highStories   = enriched.filter(s => s.relevance === 'HIGH');
  const mediumStories = enriched.filter(s => s.relevance === 'MEDIUM');
  const topStory      = highStories[0] || null;
  const otherHigh     = highStories.slice(1);
  const actionItems   = generateActionItems(enriched);

  let digest = `# 🛸 Tech News Digest — ${date}\n\n`;
  digest += `> _Curated by your friendly neighbourhood tech chef. Today's menu: ${highStories.length} HIGH and ${mediumStories.length} MEDIUM relevance stories — each with a TL;DR, Neelix's take, and a recommendation._\n\n`;

  // Squad product updates — private digests only
  if (!isPublic && squadUpdates.length > 0) {
    digest += `---\n\n`;
    digest += `## 🚀 Squad Product Updates (bradygaster/squad)\n\n`;
    squadUpdates.slice(0, 5).forEach((item, idx) => {
      digest += `### ${idx + 1}. ${item.title}\n\n`;
      digest += `- **Source:** ${item.source}\n`;
      digest += `- **Link:** ${item.url}\n`;
      if (item.body) digest += `- **Details:** ${item.body.slice(0, 300)}\n`;
      if (item.category) digest += `- **Category:** ${item.category}\n`;
      if (item.author) digest += `- **Author:** ${item.author}\n`;
      digest += `\n`;
    });
  }

  if (enrichedStories.length === 0 && (isPublic || squadUpdates.length === 0)) {
    digest += `---\n\n_No relevant stories found today — the Delta Quadrant is quiet. Enjoy the respite._\n`;
    return isPublic ? sanitizeForPublic(digest) : digest;
  }

  // ── TOP STORY — spotlight treatment ─────────────────────────────────────
  if (topStory) {
    digest += `---\n\n`;
    digest += `## 🏆 TOP STORY\n\n`;
    digest += `### ${topStory.title}\n\n`;
    digest += `> 📖 **TL;DR:** ${topStory.tldr}\n\n`;
    digest += `${topStory.whyItMatters}\n\n`;
    digest += `${topStory.recommendation}\n\n`;
    digest += `> 🎙️ **Neelix's take:** _"${topStory.neelixTake}"_\n\n`;
    if (!isPublic && topStory.matchedKeywords && topStory.matchedKeywords.length > 0) {
      digest += `> 🏷️ _Relevance signals: ${topStory.matchedKeywords.map(k => `\`${k}\``).join(', ')}_\n\n`;
    }
    digest += `- **Source:** ${topStory.source}`;
    if (topStory.score) digest += ` | **Score:** ${topStory.score}`;
    digest += `\n`;
    digest += `- **Link:** ${topStory.url}\n\n`;
  }

  // ── Remaining HIGH relevance stories ─────────────────────────────────────
  if (otherHigh.length > 0) {
    digest += `---\n\n`;
    digest += `## 🔴 HIGH Relevance — Read These Now\n\n`;
    otherHigh.forEach((story, idx) => {
      digest += `### ${idx + 1}. ${story.title}\n\n`;
      digest += `> 📖 **TL;DR:** ${story.tldr}\n\n`;
      digest += `${story.whyItMatters}\n\n`;
      digest += `${story.recommendation}\n\n`;
      digest += `> 🎙️ **Neelix's take:** _"${story.neelixTake}"_\n\n`;
      if (!isPublic && story.matchedKeywords && story.matchedKeywords.length > 0) {
        digest += `> 🏷️ _Relevance signals: ${story.matchedKeywords.map(k => `\`${k}\``).join(', ')}_\n\n`;
      }
      digest += `- **Source:** ${story.source}`;
      if (story.score) digest += ` | **Score:** ${story.score}`;
      digest += `\n`;
      digest += `- **Link:** ${story.url}\n\n`;
    });
  }

  // ── MEDIUM relevance stories ──────────────────────────────────────────────
  if (mediumStories.length > 0) {
    digest += `---\n\n`;
    digest += `## 🟡 MEDIUM Relevance — Worth a Glance\n\n`;
    mediumStories.forEach((story, idx) => {
      digest += `### ${idx + 1}. ${story.title}\n\n`;
      digest += `> 📖 **TL;DR:** ${story.tldr}\n\n`;
      digest += `${story.whyItMatters}\n\n`;
      digest += `${story.recommendation}\n\n`;
      digest += `> 🎙️ **Neelix's take:** _"${story.neelixTake}"_\n\n`;
      digest += `- **Source:** ${story.source}`;
      if (story.score) digest += ` | **Score:** ${story.score}`;
      digest += `\n`;
      digest += `- **Link:** ${story.url}\n\n`;
    });
  }

  if (isPublic) {
    digest = sanitizeForPublic(digest);
  }

  return digest;
}

/**
 * Create a GitHub issue with the tech news digest body.
 * Returns the created issue URL, or null on failure.
 */
function createGitHubIssue(title, body) {
  try {
    // Attempt with 'tech-news' label (may not exist on every repo)
    const output = execFileSync(
      'gh', ['issue', 'create', '--title', title, '--body', body, '--label', 'tech-news'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
    ).trim();
    console.error(`Created GitHub issue: ${output}`);
    return output;
  } catch (_labelErr) {
    // Retry without the label if it doesn't exist
    try {
      const output = execFileSync(
        'gh', ['issue', 'create', '--title', title, '--body', body],
        { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 30000 }
      ).trim();
      console.error(`Created GitHub issue (no label): ${output}`);
      return output;
    } catch (e) {
      console.error(`Warning: Could not create GitHub issue: ${e.message}`);
      return null;
    }
  }
}


async function postToTeamsWebhook(digest) {
  const home = process.env.USERPROFILE || process.env.HOME || '';
  
  // Per-channel webhook resolution (Issue #821)
  // Priority: tech-news channel file → general channel file → legacy file
  let webhookUrl = null;
  const channelFile = path.join(home, '.squad', 'teams-webhooks', 'tech-news.url');
  const generalFile = path.join(home, '.squad', 'teams-webhooks', 'general.url');
  const legacyFile  = path.join(home, '.squad', 'teams-webhook.url');

  for (const file of [channelFile, generalFile, legacyFile]) {
    if (fs.existsSync(file)) {
      const url = fs.readFileSync(file, 'utf8').trim();
      if (url) { webhookUrl = url; break; }
    }
  }

  if (!webhookUrl) {
    console.error('No Teams webhook URL found (checked tech-news, general, legacy), skipping Teams post');
    return;
  }

  // Truncate for Teams card limit
  const summary = digest.length > 2000
    ? digest.slice(0, 2000) + '\n\n_...truncated. See GitHub issue for full digest._'
    : digest;

  const payload = JSON.stringify({
    type: 'message',
    attachments: [{
      contentType: 'application/vnd.microsoft.card.adaptive',
      content: {
        '$schema': 'http://adaptivecards.io/schemas/adaptive-card.json',
        type: 'AdaptiveCard',
        version: '1.4',
        body: [{
          type: 'TextBlock',
          text: summary,
          wrap: true,
        }],
      },
    }],
  });

  return new Promise((resolve) => {
    try {
      const parsedUrl = new URL(webhookUrl);
      const req = https.request(parsedUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(payload),
        },
      }, (res) => {
        let data = '';
        res.on('data', (chunk) => { data += chunk; });
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.error(`Posted digest to Teams webhook (status: ${res.statusCode})`);
          } else {
            console.error(`Teams webhook returned ${res.statusCode}: ${data}`);
          }
          resolve();
        });
      });

      req.on('error', (err) => {
        console.error(`Failed to post to Teams webhook: ${err.message}`);
        resolve();
      });

      req.write(payload);
      req.end();
    } catch (err) {
      console.error(`Failed to post to Teams webhook: ${err.message}`);
      resolve();
    }
  });
}

/**
 * Convert a markdown-ish digest to HTML suitable for a Teams channel message.
 * Handles: # headings, **bold**, - list items, URLs → <a> links.
 */
function digestToHtml(markdown) {
  const lines = markdown.split('\n');
  const htmlLines = [];
  let inList = false;

  for (const raw of lines) {
    const line = raw.trimEnd();

    // H1
    if (/^# /.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push(`<h1>${escHtml(line.slice(2))}</h1>`);
      continue;
    }
    // H2
    if (/^## /.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push(`<h2>${escHtml(line.slice(3))}</h2>`);
      continue;
    }
    // H3
    if (/^### /.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push(`<h3>${escHtml(line.slice(4))}</h3>`);
      continue;
    }
    // HR
    if (/^---+$/.test(line)) {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      htmlLines.push('<hr/>');
      continue;
    }
    // List item
    if (/^- /.test(line)) {
      if (!inList) { htmlLines.push('<ul>'); inList = true; }
      htmlLines.push(`<li>${inlineFormat(line.slice(2))}</li>`);
      continue;
    }
    // Blank line
    if (line === '') {
      if (inList) { htmlLines.push('</ul>'); inList = false; }
      continue;
    }
    // Paragraph
    if (inList) { htmlLines.push('</ul>'); inList = false; }
    htmlLines.push(`<p>${inlineFormat(line)}</p>`);
  }
  if (inList) htmlLines.push('</ul>');
  return htmlLines.join('\n');
}

function escHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function inlineFormat(text) {
  // Bold: **text**
  text = text.replace(/\*\*([^*]+)\*\*/g, (_, t) => `<strong>${escHtml(t)}</strong>`);
  // Inline code: `text`
  text = text.replace(/`([^`]+)`/g, (_, t) => `<code>${escHtml(t)}</code>`);
  // Bare URLs (not already inside href=) → clickable links
  text = text.replace(/(?<!href=["'])https?:\/\/[^\s<>"')]+/g, (url) => {
    const cleanUrl = url.replace(/[.,;:!?)]+$/, ''); // strip trailing punctuation
    const display = escHtml(cleanUrl.length > 80 ? cleanUrl.slice(0, 77) + '…' : cleanUrl);
    return `<a href="${escHtml(cleanUrl)}">${display}</a>`;
  });
  return text;
}

/**
 * Get an Azure AD access token for the Graph API via the Azure CLI.
 * Returns the token string, or null if az is unavailable / not logged in.
 */
function getGraphToken() {
  try {
    const raw = execFileSync(
      'az', ['account', 'get-access-token', '--resource', 'https://graph.microsoft.com', '--query', 'accessToken', '-o', 'tsv'],
      { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'], timeout: 15000 }
    ).trim();
    return raw || null;
  } catch (e) {
    console.error(`Warning: Could not obtain Graph API token via az CLI: ${e.message}`);
    return null;
  }
}

/**
 * Post an HTML message to a single Teams channel via the Graph API.
 * teamId / channelId come from TEAMS_CHANNELS config.
 */
function postToTeamsChannelViaGraph(teamId, channelId, htmlBody, token) {
  return new Promise((resolve) => {
    const payload = JSON.stringify({
      body: { contentType: 'html', content: htmlBody }
    });

    const options = {
      hostname: 'graph.microsoft.com',
      path: `/v1.0/teams/${encodeURIComponent(teamId)}/channels/${encodeURIComponent(channelId)}/messages`,
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.error(`Posted digest to Teams channel ${channelId} (status: ${res.statusCode})`);
        } else {
          console.error(`Teams Graph API returned ${res.statusCode} for channel ${channelId}: ${data.slice(0, 200)}`);
        }
        resolve();
      });
    });

    req.on('error', (err) => {
      console.error(`Failed to post to Teams channel ${channelId}: ${err.message}`);
      resolve();
    });

    req.write(payload);
    req.end();
  });
}

/**
 * Post the tech news digest to ALL channels listed in TEAMS_CHANNELS using the
 * Graph API.  Private channels receive the full digest; public channels receive
 * the sanitized version.  Falls back gracefully if az CLI is unavailable.
 */
async function postToBothTeamsChannels(digest, publicDigest) {
  const token = getGraphToken();
  if (!token) {
    console.error('Skipping Graph API channel posts — no access token available.');
    return;
  }

  for (const ch of TEAMS_CHANNELS) {
    const content = ch.public ? publicDigest : digest;
    const html = digestToHtml(content);
    console.error(`Posting to ${ch.label} (teamId: ${ch.teamId})…`);
    await postToTeamsChannelViaGraph(ch.teamId, ch.channelId, html, token);
  }
}

async function main() {
  try {
    ensureStateDir();
    const state = loadState();
    const todayDate = getTodayDate();
    
    console.error('Starting tech news scan...');
    
    // Check if issue already exists for today
    if (issueExistsForToday(todayDate)) {
      console.error(`Tech news digest already exists for today (${todayDate}), skipping.`);
      console.error('To force creation, manually delete the existing issue.');
      process.exit(0);
    }
    
    const { stories, squadUpdates } = await scanAllSources();
    
    // Filter out URLs that have already been reported
    const reportedUrlsForDate = state.reportedUrls[todayDate] || {};
    const newStories = stories.filter(story => !reportedUrlsForDate[story.url]);
    const newSquadUpdates = squadUpdates.filter(item => !reportedUrlsForDate[item.url]);
    
    if (newStories.length === 0 && newSquadUpdates.length === 0 && (stories.length > 0 || squadUpdates.length > 0)) {
      console.error('All stories have already been reported. Skipping digest creation.');
      process.exit(0);
    }
    
    // ── Deep enrichment pipeline (issue #1032) ──────────────────────────────
    // Score → filter → select top 10 → fetch article descriptions → generate
    // TL;DR, Neelix commentary, relevance, and per-story action item.
    console.error('Enriching top stories with article descriptions and analysis…');
    const enrichedStories = await enrichStoriesWithDescriptions(newStories, 10);
    console.error(`Enriched ${enrichedStories.length} stories (${enrichedStories.filter(s => s.description).length} with fetched descriptions).`);

    const digest       = formatDigest(enrichedStories, newSquadUpdates);
    const publicDigest = formatDigest(enrichedStories, newSquadUpdates, { isPublic: true });
    console.log(digest);
    
    // ── Create GitHub issue ──────────────────────────────────────────────────
    const issueTitle = `Tech News Digest: ${todayDate}`;
    createGitHubIssue(issueTitle, digest);

    // Post full digest to private webhook channel (includes issue links, repo refs)
    await postToTeamsWebhook(digest);
    
    // Post to both dedicated Teams channels via Graph API:
    //   - squads > Tech News          (full content, private)
    //   - Squad > Squad Tech News     (sanitized, public)
    await postToBothTeamsChannels(digest, publicDigest);
    
    // Update state with new URLs
    if (!state.reportedUrls[todayDate]) {
      state.reportedUrls[todayDate] = {};
    }
    [...newStories, ...newSquadUpdates].forEach(item => {
      state.reportedUrls[todayDate][item.url] = true;
    });
    state.lastScanDate = todayDate;
    saveState(state);
    
    console.error('Tech news scan completed successfully!');
  } catch (error) {
    console.error('Error during scan:', error);
    process.exit(1);
  }
}

main();
