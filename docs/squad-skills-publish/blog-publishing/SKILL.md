---
name: blog-publishing
description: "Multi-account GitHub workflow for publishing content to GitHub Pages. Use when content is ready to publish and requires account switching between work and personal GitHub accounts."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: GitHub Pages multi-account publishing patterns
---

# Blog Publishing Workflow

**Automate multi-account GitHub publishing for blog content.** Handles the account switching, branch management, and traceability needed when your blog lives on a different GitHub account than your daily work.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `publish blog`, `deploy blog` | HIGH — Content ready |
| `push to blog`, `blog workflow` | MEDIUM — Process question |
| `content publishing`, `blog post` | MEDIUM — Starting workflow |

---

## The Problem

Many developers maintain a personal blog on GitHub Pages under their personal account, while doing daily work under an enterprise/organization account. Publishing requires:

1. Switching GitHub CLI authentication
2. Pushing to the correct repository and branch
3. Switching back to the work account
4. Not accidentally pushing work content to personal repos (or vice versa)

---

## Publishing Workflow

### Step 1: Prepare Content

Draft content locally in your working repository:

```bash
# Content lives in your working repo during drafting
ls blog-{slug}.md
```

### Step 2: Switch to Publishing Account

```bash
# Switch to the account that owns the blog repo
gh auth switch --user {publishing_account}

# Verify you're on the right account
gh auth status
```

### Step 3: Push to Blog Repository

```bash
# Clone or navigate to the blog repo
cd {blog_repo_path}

# Copy content and commit
cp /path/to/blog-{slug}.md _posts/
git add _posts/blog-{slug}.md
git commit -m "Publish: {title}"
git push origin main
```

### Step 4: Switch Back to Work Account

**Critical — do this immediately after publishing:**

```bash
gh auth switch --user {work_account}

# Verify
gh auth status
```

### Step 5: Link for Traceability

Comment on the tracking issue with the published URL:

```bash
gh issue comment {issue_number} --body "Published: https://{blog_url}/blog-{slug}"
```

---

## Configuration

Define your publishing accounts in a config file:

```json
{
  "publishing_account": "your-personal-github",
  "work_account": "your-org-github",
  "blog_repo": "your-personal-github/your-personal-github.github.io",
  "blog_branch": "main",
  "content_dir": "_posts",
  "blog_url": "https://your-personal-github.github.io"
}
```

---

## Safety Rules

1. **Always verify auth** before pushing — `gh auth status`
2. **Always switch back** to work account after publishing
3. **Never push work code** to personal repos
4. **Link commits** to tracking issues for audit trail
5. **Use a checklist** for multi-step publishing to avoid missed steps

## Error Recovery

| Problem | Solution |
|---------|----------|
| Pushed to wrong repo | `git revert` on the wrong repo, re-push to correct repo |
| Forgot to switch back | `gh auth switch --user {work_account}` immediately |
| Auth expired | `gh auth login --hostname github.com` |
| Content in wrong format | Check site generator requirements (Jekyll, Hugo, etc.) |

---

## Automation Script Template

```bash
#!/bin/bash
set -euo pipefail

BLOG_REPO="{blog_repo_path}"
WORK_ACCOUNT="{work_account}"
PUBLISH_ACCOUNT="{publishing_account}"
FILE="$1"
TITLE="$2"

# Pre-flight
gh auth switch --user "$PUBLISH_ACCOUNT"
gh auth status

# Publish
cp "$FILE" "$BLOG_REPO/_posts/"
cd "$BLOG_REPO"
git add _posts/
git commit -m "Publish: $TITLE"
git push origin main

# Cleanup
gh auth switch --user "$WORK_ACCOUNT"
echo "✅ Published and switched back to work account"
```

---

## See Also

- [Voice Writing](../voice-writing/) — Maintain consistent writing voice
- [GitHub Multi-Account](../github-multi-account/) — Manage multiple GitHub identities
