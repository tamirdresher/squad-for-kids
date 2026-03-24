# Decision: Cross-Machine-Coordination Skill Contributed Upstream

**Date:** 2026-03-22  
**Issue:** #1309  
**Decision by:** Picard  

## Decision

The `cross-machine-coordination` skill has been contributed upstream to [bradygaster/squad](https://github.com/bradygaster/squad) via PR.

**PR:** https://github.com/bradygaster/squad/pull/513  
**Branch:** `tamirdresher/squad:feat/cross-machine-coordination` → `bradygaster/squad:dev`

## What Was Contributed

`.squad/skills/cross-machine-coordination/SKILL.md` — sanitized version of our local skill.

**Sanitization applied:**
- Personal machine name (`CPC-tamir-WCBED`) → `laptop-machine`
- Personal S3 paths → generic `/path/to/artifacts/...`
- Personal name references in migration section → generic terms

## Skill Content Summary

- Git-based task queue protocol (YAML task/result files in `.squad/cross-machine/`)
- Security validation pipeline (schema, command whitelist, resource limits, audit trail)
- Ralph Watch loop integration (automatic poll-execute-result cycle)
- GitHub Issues channel for urgent tasks (`squad:machine-{name}` labels)
- Error/timeout/network failure handling
- Configuration schema for `.squad/config.json`
- Full worked examples

## Status

Issue #1309 closed. Awaiting PR review by @bradygaster.
