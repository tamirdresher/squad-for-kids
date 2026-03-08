# Decision Proposal: Environment Variable Pattern for User Content in GitHub Actions Scripts

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Status:** Proposed  
**Scope:** Team Standard  
**Related Issue:** #179  
**Related PR:** #180

## Context

The squad-issue-notify.yml workflow was failing with `SyntaxError: Unexpected identifier 'squad'` when issue bodies contained backticks, code blocks, or special JavaScript characters. The root cause was direct interpolation of user-controlled content into JavaScript template literals within `actions/github-script@v7`.

## Decision

**Standard Pattern for User Content in GitHub Actions Scripts:**

When using `actions/github-script` with user-controlled content (issue bodies, PR descriptions, comments, commit messages), ALWAYS pass content through environment variables instead of inline interpolation.

### Anti-Pattern (Vulnerable to SyntaxError):
```yaml
- uses: actions/github-script@v7
  with:
    script: |
      const title = `${{ github.event.issue.title }}`;  # BREAKS if title has backticks
      const summary = `${{ steps.foo.outputs.summary }}`;  # BREAKS if summary has code blocks
```

### Recommended Pattern (Safe):
```yaml
- uses: actions/github-script@v7
  env:
    ISSUE_TITLE: ${{ github.event.issue.title }}
    SUMMARY: ${{ steps.foo.outputs.summary }}
  with:
    script: |
      const title = process.env.ISSUE_TITLE;  # Safe - reads as plain string
      const summary = process.env.SUMMARY;    # Safe - no parsing
```

## Rationale

1. **Environment variables are passed as plain strings** - GitHub Actions sets them in the process environment without any JavaScript parsing
2. **Special characters remain as data, not code** - Backticks, quotes, braces are literal characters, not syntax
3. **No escaping required** - The environment variable mechanism handles all escaping automatically
4. **Works for all user content** - Issue bodies, PR descriptions, comments, commit messages, file contents

## Applies To

- All workflows using `actions/github-script@v7` (or any version)
- Any script that processes user-controlled content
- Teams notifications, Slack alerts, issue comments, PR comments
- Content from: `github.event.issue.body`, `github.event.comment.body`, `github.event.pull_request.body`, step outputs containing user text

## Does NOT Apply When

- Content is from trusted sources only (e.g., static strings, repository variables)
- Content is already sanitized/escaped by another tool
- Using GitHub Actions expressions outside of inline scripts

## Implementation

When writing or reviewing workflows with `actions/github-script`:
1. Identify all user-controlled content being interpolated
2. Move each piece of content to an `env:` block
3. Replace inline `${{ }}` interpolation with `process.env.VAR_NAME`
4. Test with content containing backticks, quotes, and special characters

## Consequences

✅ **Benefits:**
- Eliminates SyntaxError from special characters in user content
- No escaping logic required (simpler, less error-prone)
- Works universally for all character sets and languages
- Aligns with security best practices (treat user input as data, not code)

⚠️ **Trade-offs:**
- Slightly more verbose (requires env block + process.env references)
- May require refactoring existing workflows

## Related Work

- Fixed: `.github/workflows/squad-issue-notify.yml` (Issue #179, PR #180)
- Audit recommended: Check all other workflows using `actions/github-script` for similar patterns
