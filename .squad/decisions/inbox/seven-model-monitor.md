# Decision: Model Monitor Script & Sonnet 4.6 Evaluation

**Date:** 2026-03-14  
**Author:** Seven (Research & Docs)  
**Issue:** #509 — Continuous Model Monitoring  
**Status:** RECOMMENDATION FOR PICARD REVIEW

## What Changed

1. Created `scripts/model-monitor.ps1` — a runnable script that compares current squad model assignments against all 18 platform-available models and outputs upgrade recommendations.

2. Discovered that **Claude Sonnet 4.6** and **GPT-5.4** are now available in the platform (March 2026 releases).

## Recommendation

All 8 standard-tier agents (Picard, Data, Seven, B'Elanna, Worf, Q, Troi, Kes) currently on `claude-sonnet-4.5` should be evaluated for upgrade to `claude-sonnet-4.6`. This is a medium-priority item — Sonnet 4.6 is the direct successor.

Fast-tier agents (Neelix, Scribe, Podcaster, Ralph) on `claude-haiku-4.5` need no change.

## Impact

- Squad-wide: affects model preferences in all charter.md files and `model-assignments-snapshot.md`
- Ralph: should integrate `model-monitor.ps1` into periodic monitoring
- Picard: owns the approval decision for model migration
