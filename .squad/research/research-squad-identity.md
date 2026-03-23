# TAM Research Squad — Brand & Identity Guide

> *"Where engineering meets inquiry. We don't just build — we understand."*

---

## 1. Organization Name & Tagline

| Element | Value |
|---------|-------|
| **Full Name** | TAM Research Squad |
| **Short Name** | TAMRS |
| **Tagline** | *"Where engineering meets inquiry."* |
| **Secondary Tagline** | *"Building tomorrow's systems, publishing today's insights."* |
| **URL Slug** | `tamrs` / `tam-research` |

---

## 2. Mission Statement

The TAM Research Squad is an internal AI-driven research organization operating within the Microsoft engineering network. We investigate emerging patterns in AI agent orchestration, distributed systems, and developer tooling — and we publish our findings as first-class research artifacts.

We exist at the intersection of **engineering practice** and **academic rigor**: every system we build is a potential research paper, and every paper we publish is grounded in real production code.

---

## 3. Color Palette

The TAMRS palette is inspired by deep-space observation and academic precision — dark, focused, with sharp signal colors for findings.

| Color | Hex | Usage |
|-------|-----|-------|
| **Void Black** | `#0d0d1a` | Primary background |
| **Research Blue** | `#1a73e8` | Primary brand color, headings, links |
| **Signal Green** | `#00e676` | Findings, results, positive indicators |
| **Amber Alert** | `#ffab00` | Hypotheses, warnings, open questions |
| **Chalk White** | `#f8f9fa` | Body text |
| **Slate Gray** | `#8a8fa8` | Captions, secondary text, metadata |
| **Deep Card** | `#141428` | Panel and card backgrounds |
| **Microsoft Red** | `#d13438` | Microsoft integration indicators only |

### ASCII Logo (Text-Based)

```
╔════════════════════════════════════╗
║  ████████  █████  ███  ███  ██████ ║
║     ██    ██   ██ ████████ ██      ║
║     ██    ███████ ██ █ ██  ██████  ║
║     ██    ██   ██ ██   ██       ██ ║
║     ██    ██   ██ ██   ██  ██████  ║
║                                    ║
║     R E S E A R C H  S Q U A D    ║
╚════════════════════════════════════╝
```

### Inline Badge (Markdown)

```
[ TAMRS · TAM Research Squad · Where engineering meets inquiry ]
```

---

## 4. Typography

| Use | Font | Fallback |
|-----|------|----------|
| **Paper Titles** | IBM Plex Serif Bold | Georgia |
| **Section Headers** | IBM Plex Sans SemiBold | Arial Bold |
| **Body Text** | IBM Plex Sans Regular | Arial |
| **Code & Data** | IBM Plex Mono | Consolas |
| **Captions** | IBM Plex Sans Light Italic | Arial Italic |

*Rationale: IBM Plex is a Microsoft-adjacent open-source typeface designed for technical documentation. It signals seriousness without sacrificing readability.*

---

## 5. Voice & Tone

### Writing Principles

1. **Precision over verbosity.** One clear sentence beats a paragraph of hedging.
2. **Show the data.** Every claim gets a citation, a benchmark, or a code snippet.
3. **Acknowledge uncertainty.** Open questions are a feature, not a bug.
4. **Internal-first language.** We write for Microsoft engineers. No jargon explanation theater.

### DO Write
- "Our experiments show a 40% reduction in context switching with persistent session caches."
- "Hypothesis: agent fanout beyond 8 parallel tasks degrades coherence in GPT-4o."
- "See `.squad/research/distributed-systems-deep-dive.md` for full methodology."

### DON'T Write
- "In this paper, we will explore..." (Just explore it.)
- "It is worth noting that..." (Everything in a paper is worth noting.)
- Marketing adjectives: groundbreaking, revolutionary, paradigm-shifting

---

## 6. Website Structure (GitHub Pages / Internal Wiki)

```
tamrs/
├── index.md                    → Home: mission, latest papers, team
├── papers/
│   ├── index.md                → All papers, tagged and sorted
│   ├── 2026-03-distributed-systems.md
│   ├── 2026-03-persistent-sessions.md
│   └── 2026-03-multi-machine-coordination.md
├── projects/
│   ├── index.md                → Active research projects
│   └── {project-slug}/
│       ├── README.md
│       └── findings.md
├── team/
│   └── index.md                → Agent roster + research interests
├── methods/
│   └── index.md                → How we do research (methodology docs)
└── about/
    └── index.md                → Charter, access policy, contact
```

---

## 7. Microsoft Internal Network Access

### Access Model

TAMRS content is hosted in this GitHub repository, which is accessible to authenticated Microsoft employees via:

1. **GitHub Enterprise (preferred):** If migrated to `github.com/microsoft`, restrict via CODEOWNERS + org membership.
2. **Private Repository:** Keep `tamirdresher_microsoft/tamresearch1` private — only Microsoft-affiliated accounts have access.
3. **GitHub Pages (restricted):** Use GitHub Pages with authentication enforcement via Microsoft Entra ID (SSO) — only users in the `@microsoft.com` tenant can access.
4. **DevTunnel (current fallback):** Use Azure DevTunnel with Microsoft identity gate for live preview during active research.

### Access Policy

```yaml
access_policy:
  visibility: Microsoft Internal Only
  auth_provider: Microsoft Entra ID (Azure AD)
  allowed_tenants:
    - microsoft.com
  github_org_requirement: tamirdresher_microsoft
  external_access: Denied
  exception_process: Issue request reviewed by maintainer
```

---

## 8. Research Publishing Workflow

### Step-by-Step

```
1. DISCOVERY
   └── Agent identifies a research question during regular work
   └── Creates issue: "Research: [topic]"

2. INVESTIGATION
   └── Dedicated research session in .squad/research/
   └── Raw notes → {topic}-notes.md
   └── Experiments → {topic}-experiments.md

3. SYNTHESIS
   └── Seven drafts formal paper using Research Paper Template
   └── Picard reviews for architectural correctness
   └── Q challenges assumptions (devil's advocate pass)

4. PUBLICATION
   └── Final paper committed to .squad/research/papers/
   └── Wiki page created on GitHub wiki
   └── Summary posted to internal Teams channel
   └── Issue closed with link to paper

5. MAINTENANCE
   └── Ralph monitors for outdated findings
   └── Papers get versioned: v1.0, v1.1, etc.
   └── Deprecated findings marked with ⚠️ SUPERSEDED
```

---

## 9. File & Naming Conventions

| Artifact | Pattern | Example |
|----------|---------|---------|
| Research notes | `{topic}-notes.md` | `agent-fanout-notes.md` |
| Experiments | `{topic}-experiments.md` | `agent-fanout-experiments.md` |
| Final paper | `YYYY-MM-{topic}.md` | `2026-03-agent-fanout.md` |
| Dataset | `{topic}-data.json` | `agent-fanout-data.json` |
| Wiki page | Same as paper name | `2026-03-Agent-Fanout` |

---

## 10. Visual Identity Assets

Store all brand assets at: `.squad/research/brand-assets/`

| Asset | Description |
|-------|-------------|
| `logo-ascii.txt` | ASCII art logo (above) |
| `logo-svg-concept.md` | SVG path description for future rendering |
| `paper-template.md` | Standard research paper template |
| `slide-template.md` | Presentation structure |
| `badge-template.md` | Markdown badges for papers |

---

## 11. Research Paper Badge System

Papers are tagged with status badges:

```
🔬 [ACTIVE RESEARCH]   — Investigation ongoing
📋 [DRAFT]             — Written, under review
✅ [PUBLISHED]         — Reviewed and finalized
⚠️ [SUPERSEDED]        — Replaced by newer paper
🏗️ [IMPLEMENTED]       — Findings implemented in production
```

---

*Last updated: 2026-03-23 | Maintained by: Seven (Research & Docs)*
*Access: Microsoft Internal Only*
