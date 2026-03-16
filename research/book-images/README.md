# Book Images — Squad: Building an AI Team That Works While You Sleep

Generated diagrams and mockups for all chapters. 30 images total.

## Chapter 1: Why Everything Else Failed

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 1.1 | The Productivity System Graveyard | Concept Art | — | ⏳ Requires AI image gen (DALL-E/Midjourney) |
| 1.2 | Personal Repo Stats Before & After | Comparison Table | `fig-1-2-before-after-squad.png` | ✅ Generated |
| 1.3 | The Squad Roster | Character Illustration | — | ⏳ Requires AI image gen |
| 1.4 | Ralph's 5-Minute Watch Loop | Mermaid Flowchart | `fig-1-4-ralph-watch-loop.png` | ✅ Generated |

## Chapter 2: The System That Doesn't Need You

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 2.1 | Ralph's Architecture — The Watch Loop | Mermaid Flowchart | `fig-2-1-ralph-architecture.png` | ✅ Generated |
| 2.2 | Decision Compounding Over Time | Mermaid Timeline | `fig-2-2-decision-compounding.png` | ✅ Generated |
| 2.3 | Routing Rules Matrix | Styled Table | `fig-2-3-routing-rules-matrix.png` | ✅ Generated |
| 2.4 | Auto-Merge Criteria Decision Tree | Mermaid Flowchart | `fig-2-4-auto-merge-criteria.png` | ✅ Generated |

## Chapter 3: Meeting the Crew

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 3.1 | The Agent Specialization Spectrum | Mermaid Flowchart | `fig-3-1-agent-specialization.png` | ✅ Generated |
| 3.2 | Picard's Orchestration Flow | Mermaid Flowchart | `fig-3-2-picard-orchestration.png` | ✅ Generated |
| 3.3 | Agent Persona Cards | Styled HTML Cards | `fig-3-3-agent-persona-cards.png` | ✅ Generated |
| 3.4 | Knowledge Compounding: Three Agents, One Decision | Mermaid Flowchart | `fig-3-4-knowledge-compounding.png` | ✅ Generated |

## Chapter 4: Watching the Borg Assimilate Your Backlog

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 4.1 | The "Team" vs "Agent" Difference | Mermaid Comparison | `fig-4-1-team-vs-agent.png` | ✅ Generated |
| 4.2 | Rate Limiting Task Breakdown (Real Log) | Terminal Output | `fig-4-2-rate-limiting-log.png` | ✅ Generated |
| 4.3 | Parallel Execution Streams Converging | Mermaid Flowchart | `fig-4-3-parallel-execution.png` | ✅ Generated |
| 4.4 | My Morning Routine: Before vs After | Timeline Comparison | `fig-4-4-morning-routine.png` | ✅ Generated |

## Chapter 5: The Question You Can't Avoid

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 5.1 | Personal Squad vs Work Team Squad | Mermaid Architecture | `fig-5-1-personal-vs-work-squad.png` | ✅ Generated |
| 5.2 | The Three-Step Workflow | Mermaid Flowchart | `fig-5-2-three-step-workflow.png` | ✅ Generated |
| 5.3 | Team Roster Matrix (Human + AI) | Styled Table | `fig-5-3-team-roster-matrix.png` | ✅ Generated |
| 5.4 | Escalation Decision Tree | Mermaid Flowchart | `fig-5-4-escalation-decision-tree.png` | ✅ Generated |

## Chapter 6: Humans in the Squad

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 6.1 | The Pause Mechanism | Mermaid Sequence | `fig-6-1-pause-mechanism.png` | ✅ Generated |
| 6.2 | Capability Profile (Green/Yellow/Red) | Styled Matrix | `fig-6-2-capability-profile.png` | ✅ Generated |
| 6.3 | Three-Week Rollout Plan | Mermaid Flowchart | `fig-6-3-three-week-rollout.png` | ✅ Generated |
| 6.4 | Integration Test Example (Real PR Flow) | PR Mockup | `fig-6-4-integration-test-pr.png` | ✅ Generated |

## Chapter 7: When the Work Team Becomes a Squad

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 7.1 | Squad Roster: Humans + AI | Mermaid Org Chart | `fig-7-1-squad-roster-humans-ai.png` | ✅ Generated |
| 7.2 | The Helm Chart Bug Fix | Mermaid Flowchart | `fig-7-2-helm-chart-bug-fix.png` | ✅ Generated |
| 7.3 | Routing Rules for Work Team | Styled Table | `fig-7-3-routing-rules-work-team.png` | ✅ Generated |
| 7.4 | Trust Building Over Time (Metrics) | Metrics Dashboard | `fig-7-4-trust-building-metrics.png` | ✅ Generated |

## Chapter 8: What Still Needs Humans

| Figure | Title | Type | File | Status |
|--------|-------|------|------|--------|
| 8.1 | The Spinner Bug (Over-Engineering Example) | Comparison | `fig-8-1-spinner-bug.png` | ✅ Generated |
| 8.2 | Architecture Trade-Off (JWT vs Session) | Two-Column | `fig-8-2-jwt-vs-session.png` | ✅ Generated |
| 8.3 | Production Incident Triage (2 AM) | Mermaid Decision Tree | `fig-8-3-production-incident.png` | ✅ Generated |
| 8.4 | Cost Equation (Squad vs Alternatives) | Three-Column | `fig-8-4-cost-equation.png` | ✅ Generated |

---

## Summary

| Metric | Count |
|--------|-------|
| **Total PNG images** | 30 |
| **Mermaid diagrams** | 17 |
| **HTML mockups** | 13 |
| **Pending (AI art)** | 2 (Fig 1.1, 1.3 — need DALL-E/Midjourney) |
| **Generated successfully** | 30 / 32 (94%) |

## Source Files

All `.mmd` (Mermaid) and `.html` source files are preserved alongside the PNGs for future editing.

To re-render Mermaid files: `mmdc -i file.mmd -o file.png -w 1200 -b white`

To re-render HTML files: use `render-html.cjs` script (requires `playwright` npm package).

## Design Notes

- **Color scheme**: Consistent across all figures per `book-image-plan.md`
  - Human/Lead: `#c8e6c9` (green)
  - AI Orchestration: `#fff9c4` (yellow)
  - Code/Data: `#e3f2fd` (light blue)
  - Security: `#fce4ec` (pink)
  - Infrastructure: `#fff3e0` (light orange)
  - Success: `#c8e6c9` / `#a5d6a7` (green)
  - Error: `#ffcdd2` (light red)
- **Width**: 1200px minimum for print quality
- **Background**: White for all images
