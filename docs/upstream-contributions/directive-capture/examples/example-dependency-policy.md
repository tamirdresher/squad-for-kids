### 2025-06-17T08:30:00Z: Use pnpm instead of npm

**Captured:** 2025-06-17
**By:** Tamir (via Data)
**Severity:** standard

## Directive

Use pnpm instead of npm for all JavaScript and TypeScript projects. Remove any package-lock.json files and replace with pnpm-lock.yaml. Update CI pipelines accordingly.

## Context

Stated after investigating disk usage and install times across multiple projects — pnpm's content-addressable storage saves significant time and space.
