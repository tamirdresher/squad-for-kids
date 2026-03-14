# Model Evaluation Template

> Use this template when evaluating new models for squad agents during Model Review ceremony.

## Evaluation Context

**Date:** YYYY-MM-DD  
**Trigger:** [Quarterly / New Model Release / Performance Issue]  
**Models Under Review:** [List models being evaluated]  
**Agents Affected:** [List agents whose models might change]

---

## Current Baseline

### Agent Model Assignments

| Agent | Current Model | Tier | Monthly Est. Cost | Quality Score | Notes |
|-------|--------------|------|-------------------|---------------|-------|
| Picard | claude-sonnet-4.5 | Standard | $X | 8/10 | Architecture decisions require reasoning |
| Data | claude-sonnet-4.5 | Standard | $X | 9/10 | Code generation quality high |
| Seven | claude-sonnet-4.5 | Standard | $X | 8/10 | Research synthesis strong |
| ... | ... | ... | ... | ... | ... |

**Cost Calculation Notes:**
- Estimate based on: [average tokens per task × tasks per month × model pricing]
- Actual usage tracked via: [OTel metrics / platform logs / manual tracking]

---

## New Models Available

### Model Catalog (as of evaluation date)

**Premium Tier:**
- `claude-opus-4.6` — Latest, highest quality reasoning
- `claude-opus-4.5` — Previous generation flagship

**Standard Tier:**
- `claude-sonnet-4.6` — [if released] Next-gen mid-tier
- `claude-sonnet-4.5` — Current workhorse
- `claude-sonnet-4` — Previous generation
- `gpt-5.4` — [if released] Latest OpenAI flagship
- `gpt-5.3-codex` — Code-specialized
- `gpt-5.2-codex`, `gpt-5.2` — Mature generation
- `gpt-5.1-codex-max`, `gpt-5.1-codex`, `gpt-5.1` — Stable baseline
- `gemini-3-pro-preview` — Google's offering

**Fast/Cheap Tier:**
- `claude-haiku-4.5` — Fast inference, lower cost
- `gpt-5.1-codex-mini` — Code-focused, budget
- `gpt-5-mini` — General purpose budget
- `gpt-4.1` — Legacy fast option

---

## Benchmark Tasks

> Define representative tasks for each agent role. Test with current model vs. candidate models.

### Task 1: [Agent Name] — [Task Type]

**Scenario:** [Brief description of test task]  
**Input:** [Sample prompt or work description]  
**Expected Output:** [What a good result looks like]

**Results:**

| Model | Quality (1-10) | Speed | Cost | Notes |
|-------|----------------|-------|------|-------|
| [current] | X/10 | Xms | $X | Baseline |
| [candidate 1] | X/10 | Xms | $X | [observations] |
| [candidate 2] | X/10 | Xms | $X | [observations] |

**Winner:** [Model] — [Reasoning]

---

### Task 2: [Agent Name] — [Task Type]

[Repeat structure above]

---

## Cost vs Quality Analysis

### Per-Agent Recommendations

#### Agent: [Name]

**Current Model:** [model]  
**Recommended Model:** [model or "no change"]  
**Reasoning:**
- Quality: [assessment]
- Cost impact: [$ change per month]
- Capability fit: [how well model matches agent's domain]
- Risk: [any concerns with switching]

**Decision:** [Approve Change / Keep Current / Defer]

---

## Model Selection Criteria

### Quality Factors (Weight: 60%)
- [ ] Task completion rate
- [ ] Output accuracy
- [ ] Reasoning depth (for architecture/decisions)
- [ ] Code quality (for code agents)
- [ ] Research synthesis (for research agents)

### Cost Factors (Weight: 25%)
- [ ] Price per 1M tokens (input/output)
- [ ] Estimated monthly spend per agent
- [ ] Cost vs. quality tradeoff acceptable

### Capability Fit (Weight: 15%)
- [ ] Model strengths align with agent domain
- [ ] Context window sufficient for agent tasks
- [ ] Response speed appropriate for agent role

---

## Platform Constraints

**Model Availability:**
- [ ] Model available in production environment
- [ ] Model accessible via current auth/credentials
- [ ] Model supports required context window sizes

**Integration:**
- [ ] Squad framework supports model override
- [ ] Agent charter can specify model preference
- [ ] Coordinator respects per-agent model assignments

---

## Decision Summary

**Models Approved for Change:**

| Agent | Old Model | New Model | Rationale | Effective Date |
|-------|-----------|-----------|-----------|----------------|
| [Agent] | [old] | [new] | [1-2 sentence justification] | YYYY-MM-DD |

**Models Staying Same:**

| Agent | Model | Reason to Keep |
|-------|-------|----------------|
| [Agent] | [model] | [why no change needed] |

---

## Action Items

- [ ] Update agent charters with new model assignments
- [ ] Update `.squad/routing.md` model selection guidance
- [ ] Record decision in `.squad/decisions/inbox/lead-model-change-{date}.md`
- [ ] Monitor first week of new model usage for quality issues
- [ ] Track cost changes in first billing cycle
- [ ] Schedule follow-up review in [timeframe] if needed

---

## Next Review

**Scheduled:** [Date — typically +3 months for quarterly]  
**Triggered If:** [Conditions that would trigger earlier review]
- Major model release (GPT-6, Claude Opus 5, etc.)
- Quality degradation observed in current models
- Cost exceeds budget threshold
- Agent capability gaps identified

---

## Notes

[Any additional context, observations, or considerations for future reviews]
