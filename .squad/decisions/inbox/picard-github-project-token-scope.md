---
date: 2026-03-20
author: picard
status: implemented
issue: 1243
---

# Decision: GitHub Project Token Requires 'project' Scope

## Context

The SQUAD_PROJECT_TOKEN GitHub Actions secret was failing to update project board items in CI workflows. The token lacked the `project` scope needed for board management.

## Decision

Regenerate SQUAD_PROJECT_TOKEN with the following scopes:
- `project` (manage GitHub Projects)
- `repo` (access repositories)
- `workflow` (update workflow files)

## Rationale

Board sync is a P1 blocker. Without the `project` scope, CI cannot update project board status, breaking the squad heartbeat workflow.

## Impact

- tamirdresher_microsoft/tamresearch1: CI board sync restored
- dk8s-tetragon: CI board sync enabled
- All repos using this token: Project board automation now functional

## Implementation

1. Regenerated token at GitHub Settings → Developer Settings → Personal Access Tokens
2. Updated SQUAD_PROJECT_TOKEN secret in affected repositories
3. Verified workflow runs after update

## Follow-up

Token regeneration is a manual action requiring GitHub account access. Documented in this decision for future reference.
