# Decision: Blog Updates for Personal GitHub Account

**Date:** 2025-12-25
**Agent:** Seven (Research & Docs)
**Issue:** #313

## Context

Tamir maintains a personal blog at tamirdresher.github.io separate from work repositories. Blog posts sometimes need to be pushed to this personal account rather than the work EMU account.

## Decision

When pushing blog content to Tamir's personal GitHub account:

1. **Always switch accounts explicitly:**
   - Use `gh auth switch --user tamirdresher` to access personal account
   - Complete the work
   - Use `gh auth switch --user tamirdresher_microsoft` to return to EMU

2. **Personal repo workflow differs from work repos:**
   - Direct branch pushes are acceptable (no PR required)
   - Less formal review process
   - Can commit directly to feature branches

3. **Content requirements:**
   - Always link Brady Gaster's name to his GitHub profile: `[Brady Gaster](https://github.com/bradygaster)`
   - Incorporate feedback from issue comments into content
   - Maintain Squad's writing style: direct, focused, technical

## Rationale

- Personal blog is separate from Microsoft work infrastructure
- Different permissions and workflows apply
- Needs explicit account switching to avoid permission errors
- Personal content updates can be more direct without team review gates

## Team Impact

This establishes the pattern for any future blog post updates. All squad agents should understand:
- Personal vs. work account distinctions
- When to use which workflow
- Importance of switching back to EMU account after personal work
