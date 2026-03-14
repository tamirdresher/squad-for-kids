# Squad Model Assignments — Current Snapshot

> **Last Updated:** 2026-03-13  
> **Review Cadence:** Quarterly (next review: 2026-06-15)

---

## Current Agent Model Assignments

| Agent | Model | Tier | Rationale | Last Changed |
|-------|-------|------|-----------|--------------|
| Picard | claude-sonnet-4.5 | Standard | Architecture decisions require strong reasoning; cost-effective for leadership role | 2026-01-15 |
| Data | claude-sonnet-4.5 | Standard | Code generation quality high; C#/Go expertise benefits from Claude's coding strength | 2026-01-15 |
| Seven | claude-sonnet-4.5 | Standard | Research synthesis and documentation writing; strong at structured analysis | 2026-01-15 |
| B'Elanna | claude-sonnet-4.5 | Standard | K8s/Helm/infrastructure requires reasoning about complex distributed systems | 2026-01-15 |
| Worf | claude-sonnet-4.5 | Standard | Security analysis benefits from careful reasoning; cost acceptable for critical role | 2026-01-15 |
| Q | claude-sonnet-4.5 | Standard | Fact-checking and devil's advocate require strong reasoning and skepticism | 2026-01-15 |
| Troi | claude-sonnet-4.5 | Standard | Blog writing and voice matching; creative tasks benefit from Claude's writing quality | 2026-01-15 |
| Neelix | claude-haiku-4.5 | Fast | Daily briefings are routine, high-volume; Haiku's speed and cost efficiency ideal | 2026-02-01 |
| Kes | claude-sonnet-4.5 | Standard | Calendar/email requires understanding context and user intent; mid-tier appropriate | 2026-01-15 |
| Scribe | claude-haiku-4.5 | Fast | Session logging is template-driven; speed matters more than reasoning depth | 2026-02-01 |
| Podcaster | claude-haiku-4.5 | Fast | TTS script generation is straightforward; fast turnaround valuable | 2026-02-15 |
| Ralph | claude-haiku-4.5 | Fast | Work monitoring is pattern-based; high frequency justifies cost savings | 2026-02-01 |
| @copilot | *Platform Default* | Standard | GitHub Copilot CLI agent; model determined by GitHub platform | N/A |

---

## Model Tier Strategy

### Standard Tier (Primary Workhorse)
**Current:** `claude-sonnet-4.5`  
**Use Cases:** Architecture, code generation, research, security analysis, creative writing  
**Agents:** Picard, Data, Seven, B'Elanna, Worf, Q, Troi, Kes  
**Rationale:** Best balance of quality and cost for complex reasoning tasks

### Fast Tier (High-Frequency / Routine)
**Current:** `claude-haiku-4.5`  
**Use Cases:** Daily briefings, session logging, monitoring, TTS script generation  
**Agents:** Neelix, Scribe, Podcaster, Ralph  
**Rationale:** Speed and cost efficiency for template-driven or high-volume work

### Premium Tier (Not Currently Used)
**Available:** `claude-opus-4.6`, `claude-opus-4.5`  
**Potential Use Cases:** Mission-critical architecture decisions, complex multi-agent orchestration  
**Decision:** Deferred pending cost/benefit analysis — Sonnet 4.5 quality sufficient for current needs

---

## Cost Estimates (Approximate)

| Tier | Model | Est. Cost/1M Tokens | Monthly Agent Usage | Est. Monthly Cost |
|------|-------|---------------------|---------------------|-------------------|
| Standard | claude-sonnet-4.5 | $3.00 (input) / $15.00 (output) | ~10M tokens (8 agents) | $180-240 |
| Fast | claude-haiku-4.5 | $0.25 (input) / $1.25 (output) | ~15M tokens (4 agents) | $20-30 |
| **Total** | | | | **$200-270/month** |

**Notes:**
- Actual usage varies by workload intensity
- Estimates based on typical sprint with 20-30 issues/month
- Premium tier would add ~$400-600/month if adopted for all standard-tier agents

---

## Model Selection Decision Criteria

### When to Use Standard Tier (Sonnet)
- ✅ Complex reasoning required (architecture, security, multi-step planning)
- ✅ Code generation quality critical
- ✅ Creative writing or synthesis tasks
- ✅ Domain expertise needed (K8s, distributed systems, C#/Go patterns)
- ✅ Infrequent but high-value tasks

### When to Use Fast Tier (Haiku)
- ✅ High-frequency, routine tasks (daily briefings, monitoring)
- ✅ Template-driven or pattern-based work (logging, formatting)
- ✅ Speed matters more than reasoning depth
- ✅ Cost efficiency critical (background agents)
- ✅ Output structure well-defined

### When to Consider Premium Tier (Opus)
- ✅ Mission-critical decisions with high cost of error
- ✅ Complex multi-agent orchestration requiring deep reasoning
- ✅ Novel problem spaces where Sonnet quality insufficient
- ✅ Research requiring cutting-edge reasoning capabilities
- ❌ **Not justified for routine work** — cost vs. quality delta too small

---

## Recent Model Changes

### 2026-02-15: Podcaster → Haiku
**Reason:** TTS script generation is straightforward; Haiku speed improves user experience  
**Result:** ✅ Quality maintained, 5x cost reduction, faster audio generation

### 2026-02-01: Ralph, Scribe, Neelix → Haiku
**Reason:** High-frequency background agents; template-driven work  
**Result:** ✅ ~$150/month savings, no quality degradation observed

### 2026-01-15: Squad Genesis
**Reason:** Initial model assignment for all agents  
**Result:** Sonnet 4.5 chosen as default; strong quality/cost balance for launch

---

## Model Evaluation Triggers

### Scheduled Reviews
- **Quarterly:** Next review 2026-06-15
- **Agenda:** Re-evaluate all agents against new model releases

### Ad-Hoc Reviews (Immediate)
- 🚨 Major model release (GPT-6, Claude Opus 5, Sonnet 4.6)
- 🚨 Quality degradation in current models (observed via agent output)
- 🚨 Cost spike exceeding budget threshold (+50% over baseline)
- 🚨 Agent capability gap identified (task requires better model)

### Tech News Integration
- **Scanner:** Tech-news-scanner monitors HackerNews, Reddit for model announcements
- **Flow:** Announcement detected → Neelix flags in briefing → Picard triggers evaluation
- **SLA:** Evaluate within 1 week of major model release

---

## Model Availability Reference

**Premium:**
- `claude-opus-4.6` — Latest flagship (highest quality, highest cost)
- `claude-opus-4.5` — Previous flagship (proven quality)

**Standard:**
- `claude-sonnet-4.6` — [Not yet released as of 2026-03-13]
- `claude-sonnet-4.5` — **Current primary** (best balance)
- `claude-sonnet-4` — Previous generation (legacy support)
- `gpt-5.4` — [Check if released]
- `gpt-5.3-codex` — OpenAI code-specialized
- `gpt-5.2-codex`, `gpt-5.2` — Mature OpenAI generation
- `gpt-5.1-codex-max`, `gpt-5.1-codex`, `gpt-5.1` — Stable OpenAI baseline
- `gemini-3-pro-preview` — Google's offering

**Fast/Cheap:**
- `claude-haiku-4.5` — **Current fast tier** (best speed/cost)
- `gpt-5.1-codex-mini` — Budget code option
- `gpt-5-mini` — Budget general option
- `gpt-4.1` — Legacy fast option

---

## Next Steps

1. **Monitor Usage:** Track token consumption per agent via OTel metrics
2. **Quality Feedback:** Collect observations from squad members on model performance
3. **Cost Tracking:** Monthly spend review; alert if >$300/month
4. **Evaluation Prep:** Prepare benchmark tasks for Q2 Model Review (2026-06-15)
5. **Tech News:** Rely on tech-news-scanner to flag model announcements early

---

## References

- **Ceremonies:** `.squad/ceremonies.md` — Model Review ceremony definition
- **Evaluation Template:** `.squad/templates/model-evaluation.md`
- **Decisions Log:** `.squad/decisions.md` — Historical model change decisions
- **Agent Charters:** `.squad/agents/*/charter.md` — Per-agent model preferences (if overridden)
