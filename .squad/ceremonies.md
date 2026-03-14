# Ceremonies

> Team meetings that happen before or after work. Each squad configures their own.

## Design Review

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | before |
| **Condition** | multi-agent task involving 2+ agents modifying shared systems |
| **Facilitator** | lead |
| **Participants** | all-relevant |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. Review the task and requirements
2. Agree on interfaces and contracts between components
3. Identify risks and edge cases
4. Assign action items

---

## Retrospective

| Field | Value |
|-------|-------|
| **Trigger** | auto |
| **When** | after |
| **Condition** | build failure, test failure, or reviewer rejection |
| **Facilitator** | lead |
| **Participants** | all-involved |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. What happened? (facts only)
2. Root cause analysis
3. What should change?
4. Action items for next iteration

---

## Model Review

| Field | Value |
|-------|-------|
| **Trigger** | scheduled |
| **When** | after |
| **Condition** | quarterly or when new model releases announced |
| **Facilitator** | lead |
| **Participants** | lead, affected agents |
| **Time budget** | focused |
| **Enabled** | ✅ yes |

**Agenda:**
1. Review new model announcements (tie into tech-news-scanner)
2. Benchmark new models against current agent assignments
3. Evaluate cost vs quality tradeoffs for each agent
4. Recommend model changes where better options exist
5. Document decisions and update agent configurations

**Frequency:**
- **Quarterly:** Scheduled review of model landscape
- **Ad-hoc:** When major model releases occur (GPT-X, Claude Opus/Sonnet updates)
- **Triggered by:** Tech news scanner detecting model announcements

**Process:**
1. Use template at `.squad/templates/model-evaluation.md` for structured analysis
2. Record baseline metrics: current agent/model assignments, costs, quality observations
3. Test new models with representative agent tasks
4. Compare results: quality, speed, cost, capability fit
5. Document decision in `.squad/decisions/inbox/lead-model-change-{agent}.md`
6. Update agent charter if model changes approved
