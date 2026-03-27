# Decision: Private Staging Repo Workflow

**Date:** 2026-03-25
**Status:** Approved
**Author:** Tamir

## Decision

All development work for Squad for Kids happens in the **private staging repo** (`tdsquadAI/squad-for-kids-staging`). The public repo (`tdsquadAI/squad-for-kids`) is the **release target** — only reviewed, approved changes get pushed there.

## Workflow

1. **Work in staging** (`origin` remote = `squad-for-kids-staging`, private)
2. **Review** — Q audits for leaks/quality, Worf audits security
3. **Push to public** (`public` remote = `squad-for-kids`) only after approval
4. **Never commit directly to the public repo**

## Remotes Setup

```bash
git remote -v
# origin  = https://github.com/tdsquadAI/squad-for-kids-staging.git (private, work here)
# public  = https://github.com/tdsquadAI/squad-for-kids.git (public, push after review)
```

## Push to Public Checklist

Before `git push public main`:
- [ ] Q audit passed (no secrets, no personal info, no internal Microsoft content)
- [ ] Worf security audit passed (no hardcoded tokens, safe workflows, COPPA compliant)
- [ ] README is parent-friendly
- [ ] No debug/temp files committed
- [ ] Demo videos are clean (no internal URLs visible)
- [ ] Base repo has NO pre-configured agents (they're hired dynamically)

## Rationale

The public repo is a template for parents. It must be:
- **Clean** — no internal references or leaked issues
- **Safe** — reviewed for child safety and security
- **Professional** — high quality, clear documentation
- **Minimal** — only what parents need, nothing extra
