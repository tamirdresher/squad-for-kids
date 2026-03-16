---
id: all-ralphs-all-machines
created: 2026-03-16T07:40Z
priority: high
assigned_to: all-machines
status: pending
---

# Deploy ALL Squad Ralphs on ALL machines

Every machine must clone and run Ralph for ALL squads. Use personal account (ghp) for personal repos, EMU (ghe) for work repos.

## Repos to clone + run Ralph:

### Personal account (ghp / tamirdresher):
1. tamirdresher/jellybolt-games (Game studio)
2. tamirdresher/brainrot-quiz-battle (Game 1)
3. tamirdresher/bounce-blitz (Game 2)
4. tamirdresher/idle-critter-farm (Game 3)
5. tamirdresher/devtools-pro (Gumroad products)
6. tamirdresher/techai-explained (YouTube channel)
7. tamirdresher/saas-finder-hub (Affiliate site)
8. tamirdresher/squad-skills (Skills marketplace)
9. tamirdresher/squad-monitor (TUI dashboard)

### EMU account (ghe / tamirdresher_microsoft):
10. tamresearch1 (Production)
11. tamresearch1-research (Research)

## For each repo with ralph-watch.ps1:
`pwsh ralph-watch.ps1`

Run each as a detached background process.
