# Research: microsoft/waza — AI Agent Skill Evaluator

**Date:** 2026-06-14  
**Author:** Seven (Research & Docs)  
**Requested by:** Tamir Dresher  
**Status:** Research Complete  
**Repo:** https://github.com/microsoft/waza  
**Version:** 0.21.0  

---

## What Waza Is

Waza (技 — Japanese for "technique/skill") is a **Go CLI tool for evaluating AI agent skills**. It lets you scaffold eval suites, run benchmarks against real LLMs (via Copilot SDK), grade outcomes with multiple validator types (code assertions, regex, LLM-as-judge, diff, behavior constraints), and compare results across models. It also ships as an `azd` extension and exposes an **MCP server** (`waza serve`) with 10 tools for programmatic eval orchestration.

Built by Microsoft (Spencer Boyer, Craig Loewen, Richard Park), it targets the `SKILL.md` skill format used in GitHub Copilot's skills ecosystem.

---

## Architecture & Stack

| Component | Technology |
|-----------|-----------|
| Core CLI | Go 1.26 (`cmd/waza/`) |
| Agent execution | `github.com/github/copilot-sdk/go` — calls Copilot Chat API |
| Config | `.waza.yaml` (YAML, JSON Schema-validated) |
| Eval specs | `eval.yaml` per skill |
| Graders | code, regex, text, file, diff, behavior, action_sequence, prompt (LLM-as-judge), trigger_heuristic, tool_constraint, skill_invocation |
| Dashboard | Web UI (`web/`) with Aspire-style trajectory waterfall |
| MCP Server | `waza serve` — stdio transport, 10 tools |
| CI Integration | GitHub Actions workflows, JUnit XML output, PR comment reporter |
| Distribution | Binary releases (linux/darwin/windows), Docker, `azd` extension |

---

## Key Features (Relevant to Squad)

### 1. A/B Baseline Testing (v0.9.0) ✅ EXACTLY WHAT WE NEED

The `--baseline` flag runs each task **with and without a skill**, then computes weighted improvement scores across:
- Quality
- Token usage
- Turn count
- Time to completion
- Task completion rate

This directly answers: **"Does this skill actually help?"**

### 2. Pairwise LLM Judging (v0.9.0)

`pairwise` mode on the `prompt` grader compares two outputs head-to-head with **position-swap bias mitigation**. Three modes: pairwise, independent, both. Magnitude scoring from much-better to much-worse.

### 3. Multi-Model Comparison

`waza compare results-gpt4.json results-sonnet.json` — side-by-side comparison of eval results across models. Also `--model gpt-4o,claude-sonnet-4` for matrix runs in one command.

### 4. Trigger Accuracy Testing

`trigger_tests.yaml` auto-discovery measures whether a skill triggers on the right prompts (should_trigger / should_not_trigger). Metrics: accuracy, precision, recall, F1. Confidence weighting: high (1.0) vs medium (0.5).

### 5. Statistical Confidence Intervals (v0.8.0)

Bootstrap CI with 10K resamples, 95% confidence, normalized gain. Dashboard shows CI bands and significance badges.

### 6. Skill Compliance Scoring

`waza dev` and `waza check` evaluate SKILL.md quality on a scale: Low → Medium → Medium-High → High. Checks frontmatter, USE FOR/DO NOT USE FOR triggers, routing clarity, token budgets.

### 7. MCP Server

`waza serve` exposes eval operations as MCP tools — our agents could invoke it directly.

---

## Answers to Tamir's Questions

### Q1: Could Waza automatically evaluate whether a skill improves agent outcomes?

**YES — this is its primary purpose.** The `--baseline` flag (v0.9.0) runs tasks with vs. without a skill and computes weighted improvement scores. This would replace our manual "bump confidence when agents report success" approach with data-driven evaluation.

### Q2: Could it benchmark agent performance with vs without a specific skill?

**YES.** The A/B baseline testing feature does exactly this. Run `waza run eval.yaml --baseline` and it produces a before/after comparison with quality, tokens, turns, time, and completion metrics.

### Q3: Does it support A/B testing of agent configurations?

**YES.** Multiple approaches:
- `--baseline` flag for with/without skill comparison
- `--model model1,model2` for cross-model testing
- `pairwise` LLM judging for head-to-head comparison
- `waza compare` for side-by-side result analysis

### Q4: Is it compatible with our Copilot CLI / task-based agent architecture?

**PARTIALLY.** Waza's executor uses the `copilot-sdk` (Go), which calls the same Copilot Chat API our agents use. However:
- Our agents run via Copilot CLI (`copilot -p "..."`) with the `task` tool spawning sub-agents
- Waza's executor wraps `copilot-sdk/go` directly, not the CLI
- Our skills are in `.squad/skills/{name}/SKILL.md` — Waza expects the same `SKILL.md` format ✅
- Waza discovers skills under `.github/skills/` by default, but this is configurable in `.waza.yaml`

**Gap:** Waza evaluates skills in isolation — it sends a prompt to an LLM with a skill attached and checks the output. Our agents have complex multi-step workflows with MCP tools, sub-agents, and squad state. Waza can test "does this skill improve code explanation?" but not "does this skill help Picard coordinate a 5-agent pipeline?"

### Q5: What would integration look like?

Three viable integration paths (increasing complexity):

**Option A: CLI Tool (easiest)**
```bash
# Install the binary
curl -fsSL https://raw.githubusercontent.com/microsoft/waza/main/install.sh | bash

# Evaluate a squad skill
waza run .squad/skills/blog-publishing/eval/eval.yaml --baseline -v

# Compare skill with vs without
waza compare results-with-skill.json results-without-skill.json
```

**Option B: MCP Server (medium — recommended)**
```jsonc
// Add to mcp-config.json
{
  "waza": {
    "command": "waza",
    "args": ["serve"],
    "transport": "stdio"
  }
}
```
Then agents can call `eval.run`, `results.summary`, `skill.check` directly.

**Option C: azd Extension**
```bash
azd ext source add waza https://github.com/microsoft/waza
azd waza run eval.yaml
```

---

## Fit Analysis for Squad

### Strong Fit ✅

| Squad Need | Waza Feature |
|------------|-------------|
| Evaluate skill effectiveness | `--baseline` A/B testing |
| Automate confidence scoring | Trigger accuracy metrics + compliance scoring |
| Validate SKILL.md quality | `waza check` / `waza dev` with compliance levels |
| Compare models for skills | `waza compare` / multi-model `--model` flag |
| CI/CD for skills | GitHub Actions workflows, JUnit output |
| Token budget management | `waza tokens count`, `waza tokens compare --strict` |

### Gaps / Concerns ⚠️

| Gap | Detail |
|-----|--------|
| Multi-agent orchestration | Waza tests single-skill single-agent. Cannot evaluate Picard→B'Elanna→Seven coordination pipelines. |
| MCP tool integration | Our agents rely heavily on MCP tools (ADO, Teams, Mail, etc). Waza's mock executor doesn't simulate these. |
| Copilot SDK dependency | Uses Go SDK; we use Copilot CLI. Different entry points, though same underlying API. |
| Go toolchain required | Need Go 1.26+ to build from source (binary installs available). |
| Early-stage project | v0.21.0, started Feb 2026. Active development but not battle-tested. |
| Skill path convention | Defaults to `.github/skills/` — we use `.squad/skills/`. Configurable via `.waza.yaml`. |

---

## Recommendation: **MAYBE → Adopt for Single-Skill Evaluation**

### Rationale

Waza is a strong fit for **individual skill quality assessment** — testing whether a SKILL.md triggers correctly, produces good output, and improves over baseline. It's NOT a fit for evaluating our multi-agent orchestration pipeline.

### Recommended Approach: Phased Adoption

**Phase 1 — Evaluate (1 week):**
1. Install waza binary on Tamir's machine
2. Write `eval.yaml` for 2-3 simple skills (blog-publishing, code-explainer, outlook-automation)
3. Run `waza check` on all 50+ skills to get compliance scores
4. Run `waza run --baseline` to see if skills actually improve outcomes

**Phase 2 — Integrate (if Phase 1 succeeds):**
1. Add `waza serve` as MCP server for Seven (Research agent)
2. Create a `skill-evaluation` skill that wraps waza for on-demand skill assessment
3. Wire `waza check` into PR workflow for skill changes

**Phase 3 — Build what's missing:**
1. For multi-agent evaluation, we'd need a custom orchestration evaluator
2. Could use waza's grading primitives (code, regex, LLM-as-judge) as building blocks
3. The `tool_constraint` grader could validate MCP tool usage patterns

### If We Don't Adopt

We'd need to build:
- A/B testing framework for skills (waza has this)
- Trigger accuracy measurement (waza has this)
- Compliance scoring for SKILL.md quality (waza has this)
- Statistical confidence intervals (waza has this)

**Bottom line:** Don't reinvent the wheel for single-skill eval. Use waza for what it's good at, and build custom tooling only for multi-agent orchestration gaps.

---

## References

- Repo: https://github.com/microsoft/waza
- Docs: https://microsoft.github.io/waza/
- PRD: https://github.com/microsoft/waza/blob/main/docs/PRD.md
- CI Integration: https://github.com/microsoft/waza/blob/main/docs/SKILLS_CI_INTEGRATION.md
- Skill Best Practices: https://github.com/microsoft/waza/blob/main/docs/SKILL-BEST-PRACTICES.md
- CHANGELOG: https://github.com/microsoft/waza/blob/main/CHANGELOG.md
