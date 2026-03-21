# Tamir Dresher — Blog Voice & Style Guide

> *"Read ALL existing blog posts before writing. Voice consistency matters more than any individual post."*  
> — Troi charter, `.squad/agents/troi/charter.md`

**Purpose:** Reference for any agent (Troi) or human writing blog content in Tamir's voice. Covers tone, structure, visual style, topics, and a voice checklist.

---

## 1. Who Tamir Is (on the page)

Tamir writes like someone who has been in the trenches and wants to give you the unfiltered version — the real decisions, the real bugs, the real 3am Teams alerts. His blog is a field diary of someone building AI-native engineering workflows at Microsoft, told as story first and tech breakdown second.

The persona is: **senior engineer, skeptical optimist, genuinely funny, occasionally embarrassed about code they shipped**.

He doesn't write documentation. He doesn't write tutorials. He writes essays — technical essays with narrative arc, honest reflection, and a tendency to discover that he accidentally reinvented a 1970s distributed systems paper.

---

## 2. Tone Characteristics

### Conversational but precise
Writes like talking to a colleague who codes. Sentences are short and direct. Complexity lives in the ideas, not the prose.

> *"The fix wasn't 'make the org chart lookup smarter.' The fix was rethinking the entire question of how agents decide where to send things."*

### Self-deprecating
Regularly acknowledges bad decisions, embarrassing bugs, and code that has no defense.

> *"The file header says: `# Keep-DevBox-Alive v2 — Yes, this is exactly as dumb as it sounds.`"*

### Honest about failure
Every series has at least one post about what broke, why, and what it actually was (usually a distributed systems classic).

> *"I did not have things under control."*

### Genuinely funny — not forced
Humor comes from specificity and timing, not jokes. The punchline is usually a real thing that happened.

> *"He called me immediately, extremely concerned, believing 'Ralph' was a person."*

### Bold assertions followed by elaboration
States the point first. Explains second. Never buries the lede.

> *"Your AI team isn't **like** a distributed system. It IS one. And the implications of that are enormous."*

### Italicized inner monologue
Uses *italics* for his inner voice, direct thoughts, and parenthetical asides.

> *I lay there in the dark thinking: I have built an AI team and given them a habitat that goes to sleep.*

### Code comments as humor
Comments in code blocks are often the funniest lines in the post.

```powershell
# TODO: replace with something that isn't a crime against engineering
```

---

## 3. Signature Phrases and Structures

| Pattern | Example |
|---|---|
| "What could go wrong?" | Rhetorical, immediately followed by what went wrong |
| "That's not X. That's Y." | Used to reframe a concept as something deeper |
| "Sound familiar?" | Connects his specific situation to a universal CS pattern |
| "I stared at that line for a while." | Marks a moment of genuine insight or elegance |
| The `Keep-X-Alive` naming convention | His shorthand for "shameful but working" hacks |
| "The TODO is six weeks old. It has company." | Honest about technical debt |
| "Resistance is futile. 🟩⬛" | Borg-themed sign-off for the "Scaling AI" series |
| The italicized confession | Opens many sections with a personal admission before the technical content |

---

## 4. Post Structure

Every post follows roughly this arc:

### Standard "Scaling AI" series post

```
1. YAML front matter
   - layout, title, date, tags, series, series_part

2. Star Trek epigraph
   - Block quote with attribution
   - TNG, Voyager, TOS, or DS9 — always relevant to the theme

3. Series callback + hook
   - 1-2 paragraphs recapping the previous post and anchoring the reader
   - Ends with the tension/question this post addresses

4. Incident story
   - Named with a date or specific context ("Sunday, March 16th, 2026...")
   - What happened → what it looked like → what it actually was
   - Often includes real terminal output or notification text as code blocks

5. The realization / "The moment it clicked"
   - Single key insight, stated plainly and then unpacked
   - Often connects a home-grown hack to a named CS pattern (Raft, CRDT, Paxos...)

6. Technical deep-dive sections
   - 3–5 H2 sections with code, tables, diagrams
   - Each section has a concrete story or example, not just theory
   - Code comments are frequently the most important part

7. "What broke" section
   - Specific failures encountered during implementation
   - Presented as stories, not bullet points
   - Ends with the actual fix, including what the fix replaced

8. "What works now" or "Honest reflection"
   - Current state, actual metrics, honest caveats
   - Acknowledges overhead and imperfection
   - Ends on a forward-looking note, not a triumphalist one

9. Where this goes
   - Brief next-chapter preview
   - Sets up the next post in the series

10. Series navigation footer
    - Numbered list of all parts, linked
    - Current post marked with "← You are here"
```

### Non-series "framework analysis" post

```
1. YAML front matter (dev.to style: published, description, cover_image, tags)
2. Provocative opening thesis (no epigraph)
3. Named gaps / problems (3–5, numbered)
4. For each gap: The Problem → Why Standard Frameworks Fail → How Squad Solves It
5. Honest "what doesn't work yet" section
6. Call to action (try it, read more)
```

---

## 5. Structural Conventions

### Series front matter
```yaml
---
layout: post
title: "Title with Em Dash — Subtitle"
date: YYYY-MM-DD
tags: [ai-agents, squad, github-copilot, topic1, topic2, star-trek, borg]
series: "Scaling AI-Native Software Engineering"
series_part: N
---
```

### Epigraph convention
Always a Star Trek quote. Always attributed. Often from TNG Borg episodes, Voyager, or TOS depending on theme.

### Code block language tagging
Always tag: `powershell`, `dockerfile`, `yaml`, `json`, `bash`, `typescript`, `markdown`. Pseudocode uses no tag or plain text.

### Section headers
H2 (`##`) for major sections. H3 (`###`) for subsections. Rarely uses H4. Never just a list where a section could do more work.

### ASCII diagrams
Used for channel trees, routing structures, and anything where the visual shape communicates meaning.

```
squads (Teams Team)
│
├── #tamir-squads-notifications   ← catch-all, low-priority
├── #PR-and-Code                  ← CI failures, reviews needed
└── #Ralph-Alerts                 ← health, errors, restarts
```

### Comparison tables
Appear whenever Tamir is mapping "what we built" to "what it's actually called in CS literature." This is a recurring pattern.

| What We Built | What It's Called |
|---|---|
| Git mutex file | Leader election |
| Heartbeat JSON | Health check / liveness probe |
| `decisions/inbox/` drop-box | Write-ahead log |

---

## 6. Visual / Image Style

### Primary visual: code blocks
The blog is code-heavy. Code blocks are the primary visual element — Dockerfile, Helm YAML, PowerShell, JSON configs.

### ASCII art for structure
Used for directory trees, channel architectures, routing flows. Prefer box-drawing characters (`│`, `├──`, `└──`).

### Mermaid or D2 for flowcharts
When a process needs a proper flowchart (e.g., routing logic, auth flow), use Mermaid or D2 diagram-as-code. Never hand-drawn raster images.

### Tables for mapping and comparison
Always used for concept mappings, pattern tables, feature comparisons.

### No stock photos, no marketing imagery
Posts don't include decorative images. When there are images, they're meaningful screenshots (Teams notification, terminal output, GitHub issues view) — not hero images.

### Star Trek references can be visual metaphors but are never images
The TNG/Voyager/TOS references are text and tone, not actual images of the show.

---

## 7. Topics Tamir Writes About

| Topic | Context |
|---|---|
| **Squad / GitHub Copilot CLI** | The core subject — his own multi-agent team setup |
| **AI agents in production** | Real failures, real fixes, not demos |
| **Distributed systems patterns** | Raft, Paxos, CRDT, circuit breakers — always discovered by accident |
| **Azure Kubernetes Service / Helm** | Where agents run; operational realities |
| **Multi-machine coordination** | Laptop, DevBox, AKS — how work moves between them |
| **.NET / C# / PowerShell** | Implementation language; often scripts and watchers |
| **Teams / GitHub / DevOps** | Notifications, PRs, issues as primitive communication |
| **Communication architecture** | Channel routing, blast radius, approval workflows |
| **Personal productivity** | WhatsApp monitor, family print queue, home automation |
| **Developer tools** | MCP servers, GitHub CLI, Azure CLI |

### Topics Tamir NEVER mentions by name
- DK8S (Distributed Kubernetes)
- FedRAMP
- Any internal Microsoft product names that are not public

Use: "my team at Microsoft", "my infrastructure platform team", "the platform we run at work."

---

## 8. What Tamir Doesn't Write

- ❌ Corporate speak ("leverage", "empower", "synergize")
- ❌ Generic AI hype ("AI is transforming everything", "the future is here")
- ❌ Bullet-point-heavy posts with no narrative thread
- ❌ Numbered step-by-step tutorials without story
- ❌ Unqualified success stories — there's always an honest caveat
- ❌ Long intros that don't hook — first sentence establishes tension

---

## 9. Voice Checklist for Blog PRs

Before submitting a blog draft for review:

- [ ] **Reads like a story**, not a tutorial or documentation
- [ ] **Opens with an incident** or a moment that creates tension
- [ ] **First-person throughout** — "I", "my team", "we" — no passive voice hiding the author
- [ ] **Star Trek epigraph** fits thematically (don't force it; if it doesn't fit, skip it)
- [ ] **Series callback** links back to the previous post (for series posts)
- [ ] **At least one thing that broke** is documented honestly
- [ ] **Code blocks are present** and have language tags
- [ ] **No corporate language** — read aloud; would a senior engineer say this to a friend?
- [ ] **Self-deprecating moment** — where did Tamir embarrass himself slightly?
- [ ] **Honest reflection** — is there a caveat, an unresolved TODO, a "this isn't perfect"?
- [ ] **Series footer** is present and accurate (all posts linked, current one marked)
- [ ] **Does NOT mention** DK8S, FedRAMP, or internal product names
- [ ] **Ending has forward momentum** — where does this go next?

---

## 10. Blog Post Ideas from PR #1094

PR #1094 added two blog posts: `blog-communication-patterns.md` ("Hailing Frequencies Open") and `blog-squad-on-kubernetes.md` ("Assimilating the Cloud"). Both contain material worth expanding into standalone posts:

### Idea 1: `concurrencyPolicy: Forbid` — The One Line of YAML That Replaced 300 Lines of PowerShell
*From:* `blog-squad-on-kubernetes.md` — the `concurrencyPolicy: Forbid` revelation  
*Pitch:* A tight, focused post about the moment a single Kubernetes field eliminated an entire engineering saga. Hook: "I stared at that line for a while." Explore the philosophical point: the right abstraction doesn't just solve the problem — it makes the problem disappear.  
*Series fit:* Standalone or Part 5.1 of "Scaling AI"

### Idea 2: The Email Bridge — How to Give AI Agents Email Access Without Losing Sleep
*From:* `blog-communication-patterns.md` — the "agent proposes, human approves" email review queue  
*Pitch:* Practical guide to the "draft → review queue → human approves → agent sends" pattern. Why you should never let agents send external emails autonomously. How the pattern feels in practice (and how low the cognitive load actually is once it's set up).  
*Series fit:* Standalone; useful for anyone building agent communication workflows

### Idea 3: When Your Father-in-Law Gets Your DevBox Alert — WhatsApp as an Agent Notification Channel
*From:* `blog-communication-patterns.md` — the WhatsApp contact resolution bug where the message went to the wrong person  
*Pitch:* Comedy-forward post about the specific challenge of mixing personal and professional automation on the same communication channel. What the Signal protocol has to do with AI agent privacy. The hardcoded contacts list as a philosophical position.  
*Series fit:* "Communication architecture" thread; great social post / shareable

### Idea 4: From 2.1 GB to Useful — Container Optimization for AI Agent Workloads
*From:* `blog-squad-on-kubernetes.md` — the Dockerfile journey from 2.1GB to 890MB, image pull policy  
*Pitch:* Practical container optimization story. The specific choices (PowerShell + Node.js + .NET base = heavy), what was dropped, what stays. The `pullPolicy: IfNotPresent` discovery. Bridges AI agent world to standard Kubernetes operational knowledge.  
*Series fit:* Ops-focused companion to the K8s migration post

### Idea 5: The Duplicate Message That Recalibrated Expectations — Signal-to-Noise in Agent Channels
*From:* `blog-communication-patterns.md` — the double-webhook incident that trained colleagues to expect two messages per PR event  
*Pitch:* Short, punchy post about how agents can break channel expectations not just by sending too much, but by being consistent enough with noise that people adapt to it. The absence of noise becomes confusing. A lesson in channel hygiene and why it matters more than most engineering teams realize.  
*Series fit:* Standalone "communication" post; very shareable for DevOps/platform audiences

---

## 11. Source Files

| File | Purpose |
|---|---|
| `blog-part1-final.md` | Gold standard for "Scaling AI" series voice |
| `blog-part4-draft.md` | Best example of incident → distributed systems insight arc |
| `blog-part5-distributed-systems-draft.md` | Best example of pattern mapping table |
| `blog-squad-machines-capabilities.md` | Best example of architectural insight post |
| `blog-squad-3-things-missing.md` | Best example of non-series framework analysis format |
| `blog-communication-patterns.md` | Best example of complex routing explained through story |
| `blog-squad-on-kubernetes.md` | Best example of migration + "what broke" structure |
| `.squad/agents/troi/charter.md` | Agent charter for the blogger role |
| `.squad/skills/voice-writing/SKILL.md` | Codified voice rules |
| `.squad/skills/blog-writing/SKILL.md` | Writing mechanics |
| `.squad/skills/blog-publishing/SKILL.md` | Publishing workflow |

---

*Created by Seven — Research & Docs. Closes #1111.*
