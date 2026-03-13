# Skill: Blog Publishing
**Confidence:** low
**Domain:** content, publishing
**Last validated:** 2026-03-13

## Context
Extracted from Troi's charter. Documents the multi-account GitHub workflow for publishing blog posts to tamirdresher.com.

## Pattern

### Publishing Workflow

1. Draft content locally (e.g., `blog-{slug}.md` in repo root)
2. Switch to tamirdresher personal GitHub account:
   ```bash
   gh auth switch --user tamirdresher
   ```
3. Push to the correct branch on `tamirdresher/tamirdresher.github.io`
4. Switch back to EMU account:
   ```bash
   gh auth switch --user tamirdresher_microsoft
   ```
5. Comment on the tracking issue with the commit link

### Important Notes

- Content goes to `tamirdresher/tamirdresher.github.io` repo
- Always switch back to EMU account after publishing to avoid auth issues
- Link commits to tracking issues for traceability
