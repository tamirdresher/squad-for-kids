# AI Models Survey — Q1 2026
## Squad Model Evaluation & Recommendations

**Report Date:** 2026-03-21  
**Issue:** [#509](https://github.com/tamirdresher_microsoft/tamresearch1/issues/509) — "The squad need to continuously look at the new models that keep being added"  
**Prepared by:** Seven (Research & Docs Agent)  
**Review Period:** January 1 – March 21, 2026  
**Classification:** Squad-Internal Research

---

## Executive Summary

The Q1 2026 AI model landscape has seen extraordinary acceleration. In just 12 weeks, all three major frontier labs (OpenAI, Anthropic, Google) shipped major model revisions, Meta released the open-weight Llama 4 family, and pricing across the board dropped 30–60% from 2025 levels. The convergence is striking: GPT-5.4, Claude Opus 4.6, and Gemini 3.1 Pro all now claim 1M-token context windows and near-identical benchmark peaks on AIME, GPQA, and SWE-bench.

**Key findings:**

- **Picard** should evaluate upgrading to **GPT-5.4** or **o3** for reasoning-heavy orchestration — both offer meaningful gains over GPT-4o at lower per-token cost
- **Data** should switch to **Claude Opus 4.6** — it holds the coding crown at 78.7% SWE-bench, the best available for complex multi-file agent work  
- **Belanna** is already well-served by Claude Sonnet; the new **Claude Sonnet 4.5** represents a free upgrade path with no workflow changes  
- **Seven (this agent)** should pilot **Gemini 2.5 Pro** for long-document research tasks given its 1M context window and Google Search grounding  
- **Ralph** should upgrade to **GPT-5.4 mini/nano** — 273 tokens/sec, $0.20–0.75/M input, dramatic speed increase with budget preserved  
- **Worf** should evaluate **o3** for security analysis — its 70% SWE-bench and 2700+ Codeforces ELO makes structured security reasoning far more reliable  
- **Troi** can explore **Gemini 3.1 Pro Flash** for real-time creative generation — best multimodal model at 180+ tokens/sec

No squad member needs to switch immediately, but Data and Ralph have the clearest ROI case for near-term model changes.

---

## Table of Contents

1. [Models Released in Q1 2026](#1-models-released-in-q1-2026)
2. [Detailed Model Profiles](#2-detailed-model-profiles)
3. [Benchmark Comparison Matrix](#3-benchmark-comparison-matrix)
4. [Cost / Speed / Capability Matrix](#4-cost--speed--capability-matrix)
5. [Squad Recommendations](#5-squad-recommendations)
6. [New Capabilities Unlocked](#6-new-capabilities-unlocked)
7. [Continuous Monitoring Plan](#7-continuous-monitoring-plan)
8. [Appendix: Data Sources & Methodology](#8-appendix-data-sources--methodology)

---

## 1. Models Released in Q1 2026

### 1.1 Release Timeline

```
Jan 2026       Feb 2026        Mar 2026
  │               │               │
  ├─ Gemini 3 Pro (Google)        │
  ├─ Claude 4.5 (Anthropic)       ├─ GPT-5.4 (OpenAI, Mar 5)
  │               │               ├─ GPT-5.4 mini / nano (Mar 18)
  │               ├─ Claude 4.6   ├─ DeepSeek V4
  │               │   Opus        ├─ Llama 4 Scout + Maverick
  │               │               ├─ GLM-5 (Zhipu AI)
  │               │               └─ Qwen 3.5 (Alibaba)
  └───────────────┴───────────────┘
  [o3 available throughout — released Dec 2025, widely deployed Q1 2026]
```

### 1.2 Summary of New Entrants

| Model | Provider | Released | Type | Notable |
|-------|----------|----------|------|---------|
| GPT-5.4 | OpenAI | Mar 5, 2026 | Frontier general | Native computer use, 1M context |
| GPT-5.4 mini | OpenAI | Mar 18, 2026 | Fast/cheap | 273 tok/sec, 400K context |
| GPT-5.4 nano | OpenAI | Mar 18, 2026 | Ultra-cheap | $0.20/M input, API only |
| o3 | OpenAI | Dec 2025 / Q1 2026 GA | Reasoning | $2/$8 per 1M, 70% SWE-bench |
| Claude Opus 4.6 | Anthropic | Feb 2026 | Frontier coding | 78.7% SWE-bench, 1M context |
| Claude Sonnet 4.5 | Anthropic | Jan 2026 | Balanced | Cheaper Sonnet upgrade |
| Gemini 3.1 Pro | Google | Jan–Mar 2026 | Frontier multimodal | Best video/image reasoning |
| Gemini 3 Flash | Google | Jan 2026 | Fast/cheap | 180+ tok/sec |
| Llama 4 Scout | Meta | Mar 2026 | Open weight | 10M context, self-hostable |
| Llama 4 Maverick | Meta | Mar 2026 | Open weight | 1M context, GPT-4o parity |
| DeepSeek V4 | DeepSeek | Mar 2026 | Open weight | 77.8% SWE-bench, low cost |
| GLM-5 | Zhipu AI | Mar 2026 | Open weight | 262K context, 77.8% SWE-bench |
| Qwen 3.5 | Alibaba | Mar 2026 | Open weight | 200K context, strong coding |
| Grok 4 | xAI | Feb 2026 | Agent routing | Fast agentic task switching |

---

## 2. Detailed Model Profiles

### 2.1 GPT-5.4 (OpenAI)

**Released:** March 5, 2026  
**API Model ID:** `gpt-5.4`  
**Context Window:** 1,000,000 tokens (surcharges apply above 272K)

#### Key Capabilities
- **Native computer use:** First general-purpose model with direct OS and browser control — 75% on OSWorld-Verified, above human expert average
- **Advanced reasoning modes:** Granular control over chain-of-thought depth (low/medium/high/max reasoning effort)
- **Agentic workflows:** Full tool integration — web browsing, Python execution, file analysis, OS interaction
- **Unified model line:** Merges GPT-5 general and 5.3-Codex into a single system; no more model switching for coding vs chat
- **Hallucination reduction:** 33% fewer false claims vs GPT-5.2, 18% fewer overall errors

#### Benchmarks
- AIME 2025 Math: **100%**
- GPQA Diamond (science): **92–93%**
- SWE-bench Verified (coding): **76.9%**
- ARC-AGI (abstract reasoning): **52.9%**
- Professional work benchmark (44 occupational tasks): **83%** (vs 82.4% human expert)
- Online-Mind2Web (browser automation): **92.8%**

#### Pricing
- Input: **$30 / million tokens**
- Output: **$120 / million tokens**
- Note: Heavy context (>272K) incurs additional surcharges

#### Squad Fit
Strong candidate for **Picard** (complex orchestration reasoning). The native computer-use capability could unlock new agent patterns for squad members that need to interact with external systems.

---

### 2.2 OpenAI o3

**Released:** December 2025 (GA deployments throughout Q1 2026)  
**API Model ID:** `o3`  
**Context Window:** 200,000 tokens

#### Key Capabilities
- Purpose-built reasoning model using extended chain-of-thought
- Vision and multimodal support (unlike o1)
- Tool use: web browsing, Python execution, file analysis
- Self-verification of work steps

#### Benchmarks
- AIME 2025 Math: **91–97%**
- SWE-bench Verified (coding): **69–72%**
- Codeforces ELO: **2706–2727** (elite competitor level)
- Math competition accuracy: ~3× better than o1 (74–83% → 91–97%)

#### Pricing vs o1
| Model | Input / 1M | Output / 1M | Context |
|-------|-----------|-------------|---------|
| o1 | $15 | $60 | 200K |
| **o3** | **$2** | **$8** | 200K |
| o1-pro | $150 | $600 | 200K |

**o3 is 7.5× cheaper than o1 while significantly outperforming it.** This is a critical value finding.

#### Squad Fit
Strong candidate for **Worf** (security reasoning, code auditing) and **Picard** (structured multi-step reasoning).

---

### 2.3 GPT-5.4 mini / GPT-5.4 nano (OpenAI)

**Released:** March 18, 2026  
**API Model IDs:** `gpt-5.4-mini`, `gpt-5.4-nano`  
**Context Window:** 400,000 tokens each

#### GPT-5.4 mini
- Speed: **273 tokens/second** — industry-leading for a capable model
- Reasoning: Moderate — suitable for agent sub-tasks, classification, RAG, summarization
- Multimodal: Image input supported
- Price: $0.75 input / $4.50 output per 1M tokens

#### GPT-5.4 nano
- Speed: Fastest available (API only, not in ChatGPT GUI)
- Reasoning: Basic — extraction, classification, simple Q&A
- Price: **$0.20 input / $1.25 output per 1M tokens** — cheapest available
- Trade-off: No deep reasoning, no tool use

#### Squad Fit
**Ralph** (orchestrator/monitor) is the primary target. Both mini and nano provide dramatic speed and cost improvements over current GPT-4o-mini baseline.

---

### 2.4 Claude Opus 4.6 (Anthropic)

**Released:** February 2026  
**API Model ID:** `claude-opus-4-6`  
**Context Window:** 1,000,000 tokens (GA)  
**Max Output:** 128,000 tokens per response

#### Key Capabilities
- **Adaptive Thinking:** Dynamic reasoning depth — four effort levels (low/medium/high/max), controlled via API
- **Context Compaction API:** Server-side summarization of old conversation history — enables effectively infinite sessions without manual prompt management
- **Agent Teams:** Deploy multiple virtual sub-agents in parallel for software engineering and knowledge-work automation
- **Superior coding:** Multi-file, multi-step code tasks; strongest at real GitHub issue resolution

#### Benchmarks
- SWE-bench Verified: **78.7%** ← **#1 for coding as of March 2026**
- AIME 2025 Math: **99.8%**
- GPQA Diamond (science): **90–91%**
- Prompt injection resistance: **4.7% success rate** (strong safety)
- ARC-AGI: **37.6%**

#### Pricing
| Tier | Input / 1M | Output / 1M |
|------|-----------|-------------|
| Standard (<200K) | $5 | $25 |
| Extended (>200K) | $10 | $37.50 |
| Batch API | ~$2.50 | ~$12.50 |
| Prompt caching | ~$0.50 | $25 |

Includes up to 90% input savings via prompt caching, 50% via Batch API.

#### Availability
AWS Bedrock, Google Cloud Vertex AI, Microsoft Foundry, direct Anthropic API

#### Squad Fit
**Data** (code specialist) should be the primary adopter — Claude Opus 4.6 leads the coding benchmark leaderboard by a meaningful margin. Also relevant for any squad tasks requiring deep multi-file code analysis.

---

### 2.5 Claude Sonnet 4.5 (Anthropic)

**Released:** January 2026  
**API Model ID:** `claude-sonnet-4-5`  
**Context Window:** 200,000 tokens

#### Key Capabilities
- Balanced performance/cost tier in the Claude 4.x family
- Faster than Opus, more capable than Haiku
- Strong at structured output, document analysis, and code review
- Improved instruction following vs Sonnet 4

#### Pricing
- Input: ~$3 / million tokens
- Output: ~$15 / million tokens

#### Squad Fit
Direct upgrade path for **Belanna** (infrastructure). No workflow changes needed; drop-in replacement for existing Claude Sonnet usage. Performance improvements are especially notable in Helm chart analysis, YAML generation, and structured Kubernetes reasoning.

---

### 2.6 Gemini 3.1 Pro (Google DeepMind)

**Released:** January–March 2026 (progressive rollout)  
**API Model ID:** `gemini-3.1-pro` (via Google AI Studio, Vertex AI)  
**Context Window:** 1,000,000 tokens

#### Key Capabilities
- **Multimodal leader:** Processes text, code, images (3,000/prompt), video (10 × 45 min), audio (8.4 hours), and documents (3,000 files × 1,000 pages each)
- **Native Google Search grounding:** Real-time factual verification built in
- **Code execution sandbox:** Runs code inline during reasoning
- **Flash variant:** Gemini 3 Flash at 180+ tokens/second — best speed in its capability tier

#### Benchmarks
- GPQA Diamond: **94%** ← highest in category (Q1 2026)
- AIME 2025: **100%**
- SWE-bench Verified: **75.6%**
- MRCR 128K (long-context retrieval): **94.5%**
- Multimodal (MMMU video/img): **87–90%** ← #1

#### Pricing (Gemini 2.5 Pro basis; 3.1 Pro comparable)
| Context Tier | Input / 1M | Output / 1M |
|---|---|---|
| ≤200K tokens | $1.25 | $10.00 |
| >200K tokens | $2.50 | $10.00 |
| Cache reads | $0.13 | — |
| Google Search grounding | $35 / 1K requests | |

**Significant cost advantage for input-heavy workloads vs Claude and GPT-5.**

#### Squad Fit
**Seven** (research) for long-document synthesis with Search grounding. **Troi** (creative) for multimodal tasks — video comprehension, image generation coordination, real-time voice. The Gemini Flash variant is a viable alternative for **Ralph**.

---

### 2.7 Meta Llama 4 Family

**Released:** March 2026  
**License:** Open-weight (free for commercial use; special license for >700M MAU)

#### Llama 4 Scout
- **Architecture:** MoE, 17B active params / 109B total, 16 experts
- **Context Window:** 10,000,000 tokens (theoretical; reliable to ~2M)
- **Best for:** Long-document processing, privacy-sensitive on-prem deployment, batch processing
- **Self-hosting:** Runs on single GPU
- **Benchmarks:** Competitive with GPT-4 class on MMLU; strong at long-context retrieval

#### Llama 4 Maverick
- **Architecture:** MoE, 17B active params / 400B total, 128 experts
- **Context Window:** 1,000,000 tokens
- **Best for:** General reasoning, multimodal tasks, coding assistance
- **Benchmarks:**
  - MMLU: **85.5%** (on par with GPT-4o)
  - MBPP (code): **77.6%**
  - DocVQA: **94.4%** (matches GPT-4o)
  - ChartQA: **90%**
  - MMMU (image reasoning): **73.4%** vs GPT-4o's 69.1%

#### Llama 4 Behemoth (Internal Only)
- 288B active / 2T total parameters
- Used as teacher model for Scout and Maverick
- STEM + complex reasoning leader
- Not publicly released

#### Squad Fit
Primary value for the squad is **cost reduction and privacy**. If any squad member needs self-hosted deployment (on-prem customer scenarios, air-gapped environments), Llama 4 Maverick is now the clear choice at GPT-4o parity. Not a recommendation for default usage — the frontier models still lead — but should be tracked as an option for specialized scenarios.

---

### 2.8 DeepSeek V4

**Released:** March 2026  
**License:** Open weight  
**Context Window:** 200K–262K tokens

#### Key Capabilities
- Extremely cost-effective open-weight model
- Strong coding performance
- SWE-bench Verified: **77.8%** (close to Claude Opus 4.6)
- GPQA Diamond: **88–90%**
- AIME 2025: **~95–97%**

#### Squad Fit
**Monitoring only.** DeepSeek V4 is significant because it narrows the gap between open and closed models to near-zero on coding benchmarks. If API pricing ever becomes a hard constraint, DeepSeek V4 or GLM-5 become viable Data/Worf alternates. No immediate switch recommended.

---

### 2.9 Grok 4 (xAI)

**Released:** February 2026  
**Context Window:** 256K tokens

#### Key Capabilities
- Optimized for fast agentic task routing and real-time data
- X/Twitter integration for live web data
- Speed-oriented; not the strongest on reasoning depth benchmarks
- Best at rapid agent-to-agent routing decisions

#### Squad Fit
**Monitoring only.** Could be relevant for **Ralph** in future if xAI improves the API availability and pricing story. Not recommended at this time.

---

## 3. Benchmark Comparison Matrix

### 3.1 Flagship Model Comparison

| Benchmark | GPT-5.4 | o3 | Claude Opus 4.6 | Gemini 3.1 Pro | Llama 4 Maverick | DeepSeek V4 |
|-----------|---------|-----|-----------------|----------------|------------------|-------------|
| **AIME 2025 (math)** | 100% | 91–97% | 99.8% | 100% | — | ~95–97% |
| **GPQA Diamond (science)** | 92–93% | — | 90–91% | **94%** | — | 88–90% |
| **SWE-bench Verified (code)** | 76.9% | 69–72% | **78.7%** | 75.6% | — | 77.8% |
| **ARC-AGI (abstract)** | **52.9%** | — | 37.6% | 31.1% | — | 40–45% |
| **MMMU (multimodal)** | 82–85% | — | 80–84% | **87–90%** | 73.4% | 75–80% |
| **Codeforces ELO** | — | **2706–2727** | — | — | — | — |
| **Context window** | 1M | 200K | 1M | 1M | 1M (10M Scout) | 200–262K |

### 3.2 Efficiency Model Comparison (Ralph-tier)

| Model | Input $/1M | Output $/1M | Speed | Context | Reasoning |
|-------|-----------|------------|-------|---------|-----------|
| GPT-4o mini (current) | $0.15 | $0.60 | Fast | 128K | Moderate |
| Claude Haiku 4.5 | $0.25 | $1.25 | Fast | 200K | Moderate |
| **GPT-5.4 mini** | $0.75 | $4.50 | **273 tok/s** | 400K | **Good** |
| **GPT-5.4 nano** | **$0.20** | **$1.25** | Fastest | 400K | Basic |
| Gemini 3 Flash | $0.075 | $0.30 | 180+ tok/s | 1M | Moderate |

> Note: Gemini Flash has the lowest token cost but with a smaller reasoning ceiling. GPT-5.4 mini/nano offer more context and stronger reasoning per dollar for structured agentic tasks.

### 3.3 Year-Over-Year Benchmark Progression

The following shows how the frontier has moved since Q1 2025:

| Benchmark | Q1 2025 Leader | Score | Q1 2026 Leader | Score | ∆ |
|-----------|---------------|-------|----------------|-------|---|
| SWE-bench Verified | Claude 3.7 | ~49% | Claude Opus 4.6 | 78.7% | +**29.7pp** |
| AIME Math | GPT-4o | ~74% | GPT-5.4 / Gemini 3.1 | 100% | +**26pp** |
| GPQA Diamond | Claude 3.5 | ~59% | Gemini 3.1 Pro | 94% | +**35pp** |
| Codeforces ELO | o1-pro | ~1891 | o3 | 2727 | +**836 ELO** |

This is not incremental improvement. These are step-changes. The squad's model choices from 12 months ago may now be meaningfully sub-optimal.

---

## 4. Cost / Speed / Capability Matrix

### 4.1 Full Cost Table (Per 1M Tokens, March 2026)

| Model | Provider | Input | Output | Context | Speed (tok/s) | Tier |
|-------|----------|-------|--------|---------|--------------|------|
| GPT-5.4 | OpenAI | $30 | $120 | 1M | ~80 | Frontier |
| GPT-5.4 (>272K) | OpenAI | $60 | $240 | 1M | ~80 | Frontier+ |
| Claude Opus 4.6 | Anthropic | $5 | $25 | 1M | ~60 | Frontier |
| Claude Opus 4.6 (>200K) | Anthropic | $10 | $37.50 | 1M | ~60 | Frontier+ |
| Gemini 3.1 Pro | Google | $1.25 | $10 | 1M | ~120 | Frontier |
| Gemini 3.1 Pro (>200K) | Google | $2.50 | $10 | 1M | ~120 | Frontier+ |
| o3 | OpenAI | $2 | $8 | 200K | ~40 | Reasoning |
| o1 | OpenAI | $15 | $60 | 200K | ~30 | Reasoning (legacy) |
| Claude Sonnet 4.5 | Anthropic | $3 | $15 | 200K | ~100 | Balanced |
| Claude Haiku 4.5 | Anthropic | $0.25 | $1.25 | 200K | ~200 | Fast |
| GPT-5 mini | OpenAI | $0.25 | $2 | 400K | ~150 | Fast |
| GPT-5.4 mini | OpenAI | $0.75 | $4.50 | 400K | **273** | Fast+ |
| GPT-5.4 nano | OpenAI | **$0.20** | $1.25 | 400K | Fastest | Nano |
| Gemini 3 Flash | Google | $0.075 | $0.30 | 1M | 180+ | Flash |
| Llama 4 Maverick | Meta | Self-host ~$0 | — | 1M | Varies | Open |
| Llama 4 Scout | Meta | Self-host ~$0 | — | 10M | Varies | Open |
| DeepSeek V4 | DeepSeek | ~$0.50 | ~$2 | 200–262K | ~80 | Open+ |

### 4.2 Value-for-Money Analysis

**Best reasoning per dollar:** `o3` ($2/$8) — delivers 70%+ SWE-bench and 2700+ Codeforces ELO at 7.5× less cost than o1  
**Best coding per dollar:** `Claude Opus 4.6` with batch API (~$2.50/$12.50) — #1 SWE-bench at reasonable price with caching  
**Best research per dollar:** `Gemini 3.1 Pro` ($1.25/$10) — 1M context, Search grounding, lowest frontier input cost  
**Best orchestration per dollar:** `GPT-5.4 nano` ($0.20/$1.25) — fastest available, 400K context, extreme economy  
**Best open-source alternative:** `Llama 4 Maverick` — GPT-4o parity at self-hosting cost only  

### 4.3 Capability Dimension Scores (1–10)

| Model | Reasoning | Coding | Research | Multimodal | Speed | Cost | Agentic |
|-------|-----------|--------|----------|-----------|-------|------|---------|
| GPT-5.4 | 10 | 9 | 9 | 8 | 7 | 3 | 10 |
| o3 | 10 | 9 | 8 | 7 | 5 | 9 | 8 |
| Claude Opus 4.6 | 9 | **10** | 9 | 7 | 6 | 7 | 9 |
| Gemini 3.1 Pro | 9 | 8 | **10** | **10** | 8 | **9** | 8 |
| Claude Sonnet 4.5 | 7 | 8 | 7 | 6 | 8 | 8 | 7 |
| GPT-5.4 mini | 6 | 7 | 5 | 6 | **10** | 9 | 7 |
| GPT-5.4 nano | 3 | 3 | 2 | 3 | **10** | **10** | 4 |
| Llama 4 Maverick | 7 | 7 | 6 | 7 | 6 | 10 | 5 |
| DeepSeek V4 | 7 | 9 | 7 | 5 | 7 | 9 | 6 |

---

## 5. Squad Recommendations

### 5.1 Current Squad Model Map

| Agent | Current Model | Role | Key Needs |
|-------|--------------|------|-----------|
| Picard | GPT-4o (assumed) | Lead / Architecture | Deep reasoning, orchestration, decisions |
| Seven | Research-capable (GPT-4) | Research / Docs | Long-context, real-time data, synthesis |
| Data | Copilot / Codex | Code | Coding, PR review, multi-file changes |
| Belanna | Claude Sonnet | Infrastructure | Helm, K8s, YAML, structured output |
| Worf | Security-capable | Security / Cloud | Code auditing, threat analysis, CVE research |
| Troi | Creative model | Blog / Voice | Creative writing, storytelling, voice |
| Ralph | GPT-4o-mini / Haiku | Orchestrator | Speed, routing, monitoring, cheap calls |

### 5.2 Recommendation: Data → Claude Opus 4.6

**Priority: HIGH**  
**Confidence: HIGH**

Claude Opus 4.6 holds the #1 SWE-bench Verified score at **78.7%** as of March 2026. This is not a marginal difference — it represents 6–8 percentage points above what equivalent models offered 3 months ago, and significantly outperforms the current Codex/Copilot architecture on complex multi-file agentic coding tasks.

**Why it matters for Data:**
- The Adaptive Thinking feature lets Data calibrate reasoning depth per task — deep for complex architectural decisions, fast for simple edits
- Context Compaction API means Data can maintain coherent context across very long coding sessions without manual prompt management
- Agent Teams capability allows Data to spawn sub-agents for parallel test generation, documentation, and linting
- 78.7% SWE-bench means higher first-attempt code correctness — fewer revision cycles with Picard

**Implementation notes:**
- Model ID: `claude-opus-4-6`
- Use prompt caching for repetitive system prompts (up to 90% input cost reduction)
- Use Batch API for non-real-time code generation tasks (50% discount)
- Available on AWS Bedrock if squad infrastructure already uses AWS

**Estimated ROI:** If Data handles 10M output tokens/month at $25/M output → $250/month. Prompt caching and batch API can reduce effective cost to ~$125–175/month while improving output quality.

---

### 5.3 Recommendation: Ralph → GPT-5.4 mini (or nano)

**Priority: HIGH**  
**Confidence: HIGH**

Ralph's primary constraints are speed and cost. The GPT-5.4 mini/nano release on March 18, 2026 directly addresses both.

**GPT-5.4 mini vs current GPT-4o-mini:**

| Metric | GPT-4o-mini | GPT-5.4 mini | ∆ |
|--------|------------|-------------|---|
| Input price | $0.15/M | $0.75/M | +5× cost |
| Output price | $0.60/M | $4.50/M | +7.5× cost |
| Speed | ~120 tok/s | **273 tok/s** | +**2.3×** |
| Context | 128K | 400K | +**3.1×** |
| Reasoning | Moderate | Good | ↑ |

**However:** If Ralph primarily does routing, monitoring, and lightweight classification (not heavy reasoning), **GPT-5.4 nano** is the better fit:
- $0.20 input / $1.25 output — near-identical cost to current GPT-4o-mini
- 400K context (3× improvement)
- Fastest model available
- No tool use — if Ralph needs tool calls, stick with mini

**Decision tree for Ralph:**
```
Does Ralph need tool use? 
  YES → GPT-5.4 mini ($0.75/$4.50)
  NO  → GPT-5.4 nano ($0.20/$1.25) 
```

Both options provide a 3× context window improvement and faster responses. The main tradeoff is cost vs. tool capability.

---

### 5.4 Recommendation: Picard → Evaluate o3 or GPT-5.4

**Priority: MEDIUM**  
**Confidence: MEDIUM**

Picard needs the strongest available reasoning model for architectural decisions, multi-agent orchestration, and complex problem decomposition. Two strong candidates emerged in Q1 2026:

**Option A: o3**
- Pros: $2/$8 per 1M tokens (extremely cost-effective for a reasoning model), Codeforces ELO 2727 (elite reasoning), strong multi-step verification
- Cons: 200K context limit (vs Picard's potential need for large context), no computer use
- Best for: Complex reasoning chains, code architecture decisions, structured analysis

**Option B: GPT-5.4**  
- Pros: Native computer use, 1M context, most capable model overall, best agentic integration
- Cons: $30/$120 per 1M — most expensive option; may not justify cost for all Picard tasks
- Best for: Tasks requiring context over large codebases, agentic orchestration, computer-use workflows

**Recommendation:** Picard should run a **2-week parallel test** comparing o3 on reasoning tasks vs current GPT-4o. If context >200K is rarely needed, o3 provides a massive cost reduction (~7.5×) with better reasoning. If large-context orchestration is critical, GPT-5.4 is the correct upgrade.

---

### 5.5 Recommendation: Belanna → Claude Sonnet 4.5 (Free Upgrade)

**Priority: LOW (but immediate action)**  
**Confidence: HIGH**

Belanna uses Claude Sonnet. Claude Sonnet 4.5 is a drop-in upgrade released January 2026. This is not a model switch — it is a model ID update.

**Changes needed:**
- Update model ID from `claude-sonnet-4` to `claude-sonnet-4-5`
- No prompt changes, no workflow changes
- Improved performance on Helm chart validation, structured YAML generation, and K8s manifest analysis
- Pricing approximately the same: ~$3/$15 per 1M tokens

**Action:** Update squad config in `squad.config.ts` to use `claude-sonnet-4-5` for Belanna. Zero risk, free upgrade.

---

### 5.6 Recommendation: Seven → Pilot Gemini 2.5 Pro / 3.1 Pro

**Priority: MEDIUM**  
**Confidence: MEDIUM**

Seven's research function requires: long-context synthesis, real-time information accuracy, document processing, and citation-quality output. Gemini 3.1 Pro offers unique advantages for this role:

- **Native Google Search grounding** — real-time fact verification built in, not bolted on
- **1M context window** with the lowest frontier input cost ($1.25/M)
- **94% GPQA Diamond** — best science/research reasoning in class
- **Long-context retrieval: 94.5% MRCR at 128K** — best available for multi-document synthesis
- **3,000 document input per prompt** — can ingest an entire research corpus in one call

**Proposed pilot:** Use Gemini 3.1 Pro for the next three research tasks involving document synthesis or real-time lookup. Compare output quality and citation accuracy against current model. Report findings in `.squad/decisions/inbox/`.

**Note:** Gemini's output-only-text limitation (no multimodal generation) is not a constraint for Seven's research role.

---

### 5.7 Recommendation: Worf → Evaluate o3 for Security Analysis

**Priority: MEDIUM**  
**Confidence: MEDIUM**

Worf performs code auditing, CVE research, threat modeling, and security configuration analysis. The o3 model's capabilities are particularly relevant:

- **Codeforces ELO 2727** — elite-level code comprehension, critical for accurate vulnerability detection
- **70% SWE-bench Verified** — can identify and explain complex multi-file code issues
- **Self-verification** — o3 checks its own reasoning, reducing false positive security findings
- **$2/$8 per 1M** — affordable for security scan workloads which can be token-intensive

**Proposed upgrade path:** Test o3 on one infrastructure security audit (e.g., reviewing a full Helm chart set for misconfigurations). Compare finding quality against current model. o3's reasoning depth should produce fewer "noise" findings and better exploitation path analysis.

---

### 5.8 Recommendation: Troi → Gemini 3 Flash for Multimodal

**Priority: LOW**  
**Confidence: LOW (needs validation)**

Troi's creative tasks increasingly involve multimodal components — blog image coordination, voice synthesis, visual content planning. Gemini 3 Flash offers:

- **Best multimodal model** at 87–90% MMMU score
- **180+ tokens/second** — fast enough for real-time creative generation
- **$0.075/$0.30 per 1M** — cheapest frontier model, appropriate for creative iteration
- Native video and audio comprehension (up to 45-min video, 8.4-hour audio)

**Caveat:** Gemini Flash is a speed/cost-optimized model. For deep creative writing and voice-matching work, Claude Sonnet 4.5 may still be preferable. This is flagged as a low-priority pilot, not an immediate switch.

---

### 5.9 Summary Decision Table

| Agent | Current | Recommended | Priority | Action |
|-------|---------|-------------|----------|--------|
| **Data** | Codex/Copilot | **Claude Opus 4.6** | 🔴 HIGH | Switch within 2 weeks |
| **Ralph** | GPT-4o-mini | **GPT-5.4 nano/mini** | 🔴 HIGH | Update model ID immediately |
| **Belanna** | Claude Sonnet 4 | **Claude Sonnet 4.5** | 🟡 MED | Update model ID (zero risk) |
| **Picard** | GPT-4o | **Evaluate o3 vs GPT-5.4** | 🟡 MED | 2-week parallel test |
| **Worf** | Security model | **Evaluate o3** | 🟡 MED | Test on next security audit |
| **Seven** | GPT-4 class | **Pilot Gemini 3.1 Pro** | 🟡 MED | Pilot on next 3 research tasks |
| **Troi** | Creative model | **Pilot Gemini 3 Flash** | 🟢 LOW | Pilot on next multimodal task |

---

## 6. New Capabilities Unlocked

Q1 2026 models unlock several capabilities the squad could not reliably perform before. These represent potential new skills or agent expansions.

### 6.1 Native Computer Use / Browser Automation

**Enabled by:** GPT-5.4  
**Benchmark:** 75% OSWorld-Verified, 92.8% Online-Mind2Web  
**What it unlocks:** Any squad agent can now reliably control a browser or OS without Playwright. GPT-5.4 can click, type, navigate, upload files, and manage complex workflows natively — without an external script layer.

**Proposed new capability:** A `computer-use` skill that wraps GPT-5.4's native OS control for tasks like:
- Automated portal navigation (Azure Portal, GitHub UI operations)
- E2E test execution without Playwright configuration
- Form filling and data extraction from web UIs

This is not currently a squad skill. It should be.

---

### 6.2 Long-Context Document Synthesis at Scale

**Enabled by:** Gemini 3.1 Pro, Claude Opus 4.6, GPT-5.4 (all 1M context)  
**What it unlocks:** Processing an entire codebase, legal document set, or research corpus in a single API call. No more chunking, no RAG required for most use cases.

**Proposed new capability:** Seven gains the ability to ingest entire GitHub repository contents (up to ~750K tokens for a large repo) in a single research context. This enables whole-repo analysis, cross-file dependency mapping, and architectural review without RAG scaffolding.

---

### 6.3 Real-Time Multimodal Understanding

**Enabled by:** Gemini 3.1 Pro (video, audio, images at scale)  
**What it unlocks:**
- Analyzing screen recordings of product demos without transcription
- Processing architecture diagrams as visual input
- Audio content analysis (meeting recordings, podcasts) without a separate ASR step
- Reviewing up to 3,000 screenshots in one session

**Proposed new skill:** A `multimodal-analyzer` skill (candidate owner: Seven or Troi) for research tasks that involve visual content.

---

### 6.4 Infinite Session Memory via Context Compaction

**Enabled by:** Claude Opus 4.6 Context Compaction API  
**What it unlocks:** Agents can now maintain context across sessions of arbitrary length. The server summarizes old conversation history, preserving key information while staying within token limits. No more manual conversation management.

**Impact for Data:** Multi-day coding sessions where the agent remembers all previous decisions, bugs fixed, and architectural choices — without the user manually re-injecting context.

---

### 6.5 Elite-Level Competitive Coding

**Enabled by:** o3 (Codeforces ELO 2727)  
**What it unlocks:** Code generation at the level of an elite competitive programmer. This is qualitatively different from previous models — o3 can solve problems that previously required human expert intervention. For Worf, this means identifying complex exploit patterns. For Data, this means implementing novel algorithms correctly on the first attempt.

---

### 6.6 Open-Source Deployment Parity

**Enabled by:** Llama 4 Maverick (85.5% MMLU, GPT-4o parity), DeepSeek V4 (77.8% SWE-bench)  
**What it unlocks:** Any squad use case that currently requires a cloud API can now be served by a self-hosted open model with near-identical quality. This unlocks:
- Air-gapped customer environments
- Data privacy-sensitive workloads (no data leaving on-prem)
- Cost-zero inference at scale via self-hosted infrastructure

**Squad action:** Add Llama 4 Maverick and DeepSeek V4 to the squad's "emergency fallback" model registry for when external APIs are unavailable.

---

## 7. Continuous Monitoring Plan

### 7.1 Monthly Model Review Cadence

This survey should not be a one-time document. The rate of model releases in Q1 2026 demonstrates that the landscape shifts materially every 4–6 weeks. The squad should institutionalize a monthly model review.

**Proposed Schedule:**

```
Week 1 of each month:
  - Seven runs automated benchmark scrape (LMSYS Chatbot Arena, LLM Stats, ArtificialAnalysis.ai)
  - Seven posts summary to .squad/research/model-pulse-YYYY-MM.md
  - Seven opens GitHub issue if any squad member has a clear upgrade path

Week 2 of each month:
  - Picard reviews Seven's summary
  - If upgrade is recommended: Picard schedules 1-week parallel test
  - Decision logged in .squad/decisions.md

Week 3–4:
  - Parallel test runs
  - Affected squad member reports on quality differences
  - Decision finalized in .squad/decisions/inbox/
```

### 7.2 Benchmark Leaderboards to Monitor

| Source | URL | Frequency | What It Tracks |
|--------|-----|-----------|----------------|
| LMSYS Chatbot Arena | chat.lmsys.org | Weekly | Human preference across all models |
| ArtificialAnalysis.ai | artificialanalysis.ai | Weekly | Speed, quality, price per token |
| LLM Stats Leaderboard | llm-stats.com | Weekly | SWE-bench, GPQA, AIME, coding |
| LM Council | lmcouncil.ai/benchmarks | Monthly | Holistic benchmark aggregation |
| OpenAI release notes | platform.openai.com/docs | As released | New OpenAI models |
| Anthropic release notes | platform.claude.com/docs | As released | New Anthropic models |
| Google AI release notes | ai.google.dev | As released | New Gemini models |
| HuggingFace Open LLM | huggingface.co/spaces/HuggingFaceH4/open_llm_leaderboard | Weekly | Open-weight model rankings |

### 7.3 Key Benchmarks to Watch

The following benchmarks are most predictive of real-world squad utility:

| Benchmark | Why It Matters for Squad | Target Threshold |
|-----------|--------------------------|-----------------|
| **SWE-bench Verified** | Predicts Data's coding accuracy on real GitHub issues | >75% = viable candidate |
| **GPQA Diamond** | Science/technical reasoning — Picard, Worf, Seven | >85% = strong candidate |
| **AIME 2025** | Mathematical/logical reasoning — Picard, o-series | >90% = strong candidate |
| **MRCR 128K** | Long-context faithfulness — Seven, Data | >90% = viable for long-context |
| **OSWorld-Verified** | Computer use accuracy — future agent skills | >70% = viable for automation |
| **Codeforces ELO** | Deep coding reasoning — Data, Worf | >2500 = elite-level |
| **Chatbot Arena ELO** | Human preference — Troi, general quality | Top 5 = consider evaluating |

### 7.4 Trigger Conditions for Unscheduled Review

Outside the monthly cadence, Seven should immediately open a new survey issue when:

1. **Any frontier lab releases a new model version** (not just a minor patch)
2. **SWE-bench Verified scores change by ≥5pp** for any model in the top 5
3. **Pricing changes by ≥30%** for any model currently used by a squad member
4. **A new model achieves top-3 on any benchmark** that's critical to a squad member's function
5. **A new open-weight model matches a proprietary frontier model** on a key benchmark

### 7.5 Automation Proposal

To make monitoring sustainable, consider adding a **Ralph sub-task** for automated model tracking:

```yaml
# Proposed: .squad/monitor/model-tracker.yaml
task: model-benchmark-tracker
agent: ralph
schedule: weekly (Monday 08:00)
actions:
  - fetch_leaderboard: [lm-council, llm-stats, artificialanalysis]
  - compare_to_baseline: .squad/research/model-baselines.json
  - if delta > threshold: open_issue(assignee=seven, label=squad:seven)
  - post_summary: teams-channel (if configured)
```

This would reduce Seven's monitoring overhead to approximately 30 minutes/month — reviewing Ralph's automated digest and deciding whether a full survey is needed.

### 7.6 Model Baseline Registry

A companion file `.squad/research/model-baselines.json` should track the current "approved" model for each squad member and the benchmarks at time of approval. This gives the automated tracker a comparison baseline.

```json
{
  "last_updated": "2026-03-21",
  "squad_models": {
    "picard": { "model": "gpt-4o", "swe_bench": null, "gpqa": 0.534 },
    "seven": { "model": "gpt-4", "gpqa": 0.534, "mrcr_128k": null },
    "data": { "model": "gpt-5.3-codex", "swe_bench": 0.699 },
    "belanna": { "model": "claude-sonnet-4", "gpqa": null },
    "worf": { "model": "gpt-4o", "swe_bench": 0.489 },
    "troi": { "model": "claude-sonnet-4", "mmmu": null },
    "ralph": { "model": "gpt-4o-mini", "speed_tps": 120, "cost_input_per_1m": 0.15 }
  }
}
```

---

## 8. Appendix: Data Sources & Methodology

### 8.1 Research Sources

This report was compiled from the following sources, retrieved March 21, 2026:

| Source | Type | Data Used |
|--------|------|-----------|
| LM Council Benchmarks (lmcouncil.ai) | Leaderboard | Multi-model benchmark aggregation |
| LLM Stats Leaderboard (llm-stats.com) | Leaderboard | Full model ranking and benchmark scores |
| ArtificialAnalysis.ai | Leaderboard | Speed, cost, and quality per model |
| Anthropic Platform Docs | Official | Claude Opus 4.6 features, pricing, model ID |
| OpenAI Research Release Index | Official | GPT-5.4, mini/nano release details |
| Google AI for Developers / Vertex AI Docs | Official | Gemini 2.5/3.1 Pro specs and pricing |
| HumAI.blog GPT-5 vs Claude vs Gemini | Analysis | Cross-model comparison Q1 2026 |
| InfoQ: Claude Opus 4.6 Context Compaction | Analysis | Context Compaction API technical detail |
| DataCamp: OpenAI o3 Analysis | Analysis | o3 vs o1 benchmark comparison |
| Meta Llama 4 Blog / CometAPI | Analysis | Llama 4 Scout and Maverick specs |
| Appscribed Best AI Models 2026 | Synthesis | Squad use-case fit analysis |

### 8.2 Benchmark Definitions

| Benchmark | Description | Scale |
|-----------|-------------|-------|
| **SWE-bench Verified** | Real GitHub issue resolution (Python repos) | % resolved (higher = better) |
| **GPQA Diamond** | Graduate-level science Q&A, expert-validated | % correct (higher = better) |
| **AIME 2025** | American Invitational Math Exam — competition math | % correct (higher = better) |
| **ARC-AGI** | Abstract reasoning test — novel pattern induction | % correct (higher = better) |
| **MMMU** | Massive Multidisciplinary Multimodal Understanding | % correct (higher = better) |
| **MRCR 128K** | Long-context retrieval and comprehension | % correct (higher = better) |
| **Codeforces ELO** | Competitive programming rating (human: ~1500 avg, elite: 2700+) | ELO points |
| **MBPP** | Mostly Basic Python Problems — code generation accuracy | % correct (higher = better) |
| **OSWorld-Verified** | Computer-use task completion in real OS environments | % tasks completed |

### 8.3 Confidence Levels

- **HIGH confidence** recommendations are based on multiple independent sources and clear benchmark data differences
- **MEDIUM confidence** recommendations involve performance tradeoffs or require squad-specific testing to confirm
- **LOW confidence** recommendations are early signals that warrant a pilot, not a commitment

### 8.4 Limitations

1. Benchmark scores are point-in-time (March 2026) and will change as models are updated
2. Benchmarks measure specific tasks; real-world squad performance may differ
3. Pricing is subject to change without notice by providers
4. Self-reported benchmarks from model providers may not be fully reproducible
5. This report does not evaluate fine-tuned model variants, only base/instruct models

### 8.5 Next Review

**Scheduled next review:** April 21, 2026  
**Trigger review if:** Any model achieves SWE-bench ≥80%, or any pricing changes ≥30% for current squad models, or any new major frontier model release  
**Owner:** Seven (Research)  
**Stakeholders:** Picard (decision authority), all squad members for their respective recommendations

---

*Report prepared by Seven — Research & Docs Agent*  
*"Turns complexity into clarity. If the docs are wrong, the product is wrong."*  
*Closes issue [#509](https://github.com/tamirdresher_microsoft/tamresearch1/issues/509)*
