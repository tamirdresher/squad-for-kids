# Autonomous Content Pipeline — Architecture Overview

> Full specification: [Issue #770](https://github.com/tamirdresher/tamresearch1/issues/770)

## Purpose

The content pipeline automates the flow from raw research reports (produced by Neelix and other agents) through enrichment, blog drafting, review, publishing, and distribution — with minimal human intervention.

## Components

| # | Component | Owner | Role |
|---|-----------|-------|------|
| 1 | **Content Watcher** | Ralph | Detects new reports, creates batch issues |
| 2 | **Enrichment Engine** | Seven | Extracts themes, generates summaries |
| 3 | **Blog Drafter** | Troi | Writes blog posts from enriched content |
| 4 | **Review Gate** | Human + Seven | Quality check and polish |
| 5 | **Publisher** | Automation | Pushes to tamirdresher.github.io |

## Pipeline Phases

```
Phase 1: Detection ──► Phase 2: Enrichment ──► Phase 3: Draft
    │                                              │
    ▼                                              ▼
ralph-watch-content.ps1               Troi blog drafter agent
creates "content-batch" issue         writes markdown draft
    │                                              │
    └──────────────────────────────────────────────┘
                          │
                          ▼
              Phase 4: Review & Polish
              (human approval gate)
                          │
                          ▼
              Phase 5: Publish to GitHub Pages
                          │
                          ▼
              Phase 6: Distribute
              (podcast, Teams, social)
```

## Phase 1: Content Detection & Triggering (Implemented)

- **Script:** `scripts/ralph-watch-content.ps1`
- **State file:** `~/.squad/content-watch-state.json`
- **Scan directories:** `docs/`, `research/`, `processed/`
- **Issue template:** `.github/ISSUE_TEMPLATE/content-batch.md`

### How it works

1. The watcher polls the repo on a configurable interval (default 30 min)
2. It compares files in scan directories against persisted state
3. New files are grouped into a daily batch
4. A GitHub issue is created with label `content-batch` and a pipeline checklist
5. Downstream agents (Seven, Troi) pick up the issue and advance the pipeline

### Usage

```powershell
# Long-running watcher (default 30 min interval)
pwsh scripts/ralph-watch-content.ps1

# Single scan, no issue creation
pwsh scripts/ralph-watch-content.ps1 -Once -DryRun

# Custom interval and directories
pwsh scripts/ralph-watch-content.ps1 -IntervalMinutes 15 -ReportDirs "docs,research"
```

## Phases 2–6: Planned

See [Issue #770](https://github.com/tamirdresher/tamresearch1/issues/770) for the full specification of upcoming phases.
