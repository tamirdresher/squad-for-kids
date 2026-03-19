# JellyBolt Game Repos — Verified Operational

**Date:** 2026-03-18  
**From:** B'Elanna (Infrastructure Expert)  
**Re:** Issue #949 — JellyBolt Production Sprint

## Decision / Finding

All 5 JellyBolt game repos were already created on the **tamirdresher** personal GitHub account
in a prior sprint (March 15-18, 2026). No new creation was needed.

## Repo Inventory

| Repo | URL | Last Push |
|------|-----|-----------|
| jellybolt-games (hub) | https://github.com/tamirdresher/jellybolt-games | 2026-03-17 |
| brainrot-quiz-battle | https://github.com/tamirdresher/brainrot-quiz-battle | 2026-03-17 |
| code-conquest | https://github.com/tamirdresher/code-conquest | 2026-03-16 |
| bounce-blitz | https://github.com/tamirdresher/bounce-blitz | 2026-03-18 |
| idle-critter-farm | https://github.com/tamirdresher/idle-critter-farm | 2026-03-18 |

## Auth Pattern (Important)

- `tamirdresher_microsoft` = EMU account — **cannot create personal repos**
- `tamirdresher` = personal account — use `gh auth switch --user tamirdresher` before personal repo ops
- Issue comments on tamresearch1 = use REST API (`gh api`) not GraphQL (`gh issue comment`) — EMU GraphQL has restrictions

## Next Infrastructure Steps

1. **brainrot-quiz-battle** needs CI/CD workflow added (bounce-blitz and idle-critter-farm already have `.github/workflows/ci.yml`)
2. **Expo/EAS** build pipelines needed for Android publishing across all game repos
3. Local scaffold at `tamresearch1/brainrot-quiz-battle/` is empty — remote has all code
4. Consider Helm/ArgoCD if Supabase backend services need K8s deployment
