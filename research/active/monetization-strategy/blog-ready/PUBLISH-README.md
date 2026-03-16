# Publishing Guide: Affiliate Blog Posts for tamirdresher.com

## Overview

This folder contains 3 finalized blog posts, an affiliate disclosure page, and a recommended resources page — all ready to publish on tamirdresher.com (Jekyll/GitHub Pages).

---

## Files

| File | Type | Destination in Jekyll Repo |
|------|------|---------------------------|
| `2026-06-15-ai-development-stack-2026.md` | Blog post | `_posts/2026-06-15-ai-development-stack-2026.md` |
| `2026-06-22-best-resources-learning-ai-agents.md` | Blog post | `_posts/2026-06-22-best-resources-learning-ai-agents.md` |
| `2026-06-29-ai-squad-complete-tool-list.md` | Blog post | `_posts/2026-06-29-ai-squad-complete-tool-list.md` |
| `affiliate-disclosure.md` | Static page | Root of Jekyll repo (e.g., `affiliate-disclosure.md` or `pages/affiliate-disclosure.md`) |
| `resources.md` | Static page | Root of Jekyll repo (e.g., `resources.md` or `pages/resources.md`) |

---

## Step-by-Step Publishing Instructions

### 1. Copy Blog Posts to `_posts/`

```bash
cp 2026-06-15-ai-development-stack-2026.md  /path/to/jekyll-repo/_posts/
cp 2026-06-22-best-resources-learning-ai-agents.md  /path/to/jekyll-repo/_posts/
cp 2026-06-29-ai-squad-complete-tool-list.md  /path/to/jekyll-repo/_posts/
```

Each post has Jekyll front matter (`layout: post`, `title`, `date`, `categories`, `tags`). They should render immediately with your existing Jekyll theme.

### 2. Add the Affiliate Disclosure Page

```bash
cp affiliate-disclosure.md /path/to/jekyll-repo/
```

This creates `tamirdresher.com/affiliate-disclosure/` (based on the `permalink` in front matter). Verify it's linked from your site footer or navigation.

### 3. Add the Resources Page

```bash
cp resources.md /path/to/jekyll-repo/
```

This creates `tamirdresher.com/resources/`. Consider adding it to your site's main navigation in `_config.yml` or your navigation include.

### 4. Add Images (Optional)

The posts reference placeholder images in their front matter (`image:` field). Create or source appropriate images:
- `/assets/images/ai-stack-2026.png`
- `/assets/images/learning-ai-agents.png`
- `/assets/images/ai-squad-tools.png`

If you don't have images ready, remove the `image:` line from each post's front matter.

---

## Replacing Affiliate Placeholders

Once you have actual affiliate IDs, do a global find-and-replace across ALL files:

### Amazon Associates
```
Find:    tamirdresher2-20
Replace: your-actual-amazon-tag-20
```
Example: `?tag=tamirdresher2-20` → `?tag=tamirdresher-20`

### Manning Publications
```
Find:    8ec75026
Replace: your-actual-manning-aid

Find:    BANNER_ID
Replace: your-actual-manning-banner-id
```
Example: `?a_aid=8ec75026&a_bid=BANNER_ID` → `?a_aid=tamirdresher&a_bid=abc123`

### JetBrains Content Creators
```
Find:    JETBRAINS_AID
Replace: your-actual-jetbrains-tracking-params
```
Example: `?JETBRAINS_AID` → `?affiliate=tamirdresher` (exact format depends on JetBrains program)

### Commission Junction (Pluralsight)
```
Find:    CJ_AID
Replace: your-actual-cj-tracking-id
```
Example: `?clickid=CJ_AID` → `?clickid=abc123xyz` (exact format depends on CJ program)

### Quick Replace Commands

**PowerShell (Windows):**
```powershell
$files = Get-ChildItem -Path "_posts","affiliate-disclosure.md","resources.md" -Recurse -Filter "*.md"
foreach ($file in $files) {
    (Get-Content $file.FullName) `
        -replace 'tamirdresher2-20', 'your-actual-tag-20' `
        -replace '8ec75026', 'your-actual-aid' `
        -replace 'BANNER_ID', 'your-actual-bid' `
        -replace 'JETBRAINS_AID', 'your-jetbrains-params' `
        -replace 'CJ_AID', 'your-cj-id' |
    Set-Content $file.FullName
}
```

**Bash/Mac/Linux:**
```bash
find . -name "*.md" -exec sed -i '' \
  -e 's/tamirdresher2-20/your-actual-tag-20/g' \
  -e 's/8ec75026/your-actual-aid/g' \
  -e 's/BANNER_ID/your-actual-bid/g' \
  -e 's/JETBRAINS_AID/your-jetbrains-params/g' \
  -e 's/CJ_AID/your-cj-id/g' {} +
```

---

## Affiliate Link Marker Format

All affiliate links use a consistent marker format for easy identification:

```
[AFFILIATE:provider:product_name](url?tracking_params)
```

Where `provider` is one of: `amazon`, `manning`, `jetbrains`, `cj`

**After replacing IDs**, you should also strip the `[AFFILIATE:provider:product_name]` markers and convert them to normal markdown links. For example:

```
Before: [AFFILIATE:amazon:DDIA](https://www.amazon.com/dp/1449373321?tag=tamirdresher-20)
After:  [Designing Data-Intensive Applications](https://www.amazon.com/dp/1449373321?tag=tamirdresher-20)
```

The markers exist specifically so you can audit all affiliate links before publishing.

---

## Publishing Schedule (Suggested)

| Date | Post | Notes |
|------|------|-------|
| June 15, 2026 | "My AI Development Stack in 2026" | General audience, tool overview |
| June 22, 2026 | "Best Resources for Learning AI Agents" | Learning-focused, book/course heavy |
| June 29, 2026 | "How I Built an AI Squad — Complete Tool List" | Deep dive, complete inventory |

Stagger by one week each to maintain engagement and avoid overwhelming subscribers.

---

## Pre-Publish Checklist

- [ ] All `tamirdresher2-20` placeholders replaced with real tag
- [ ] All `8ec75026` and `BANNER_ID` placeholders replaced
- [ ] All `JETBRAINS_AID` placeholders replaced
- [ ] All `CJ_AID` placeholders replaced
- [ ] `[AFFILIATE:...]` markers converted to clean markdown links
- [ ] Affiliate disclosure page is accessible at `/affiliate-disclosure/`
- [ ] Resources page is accessible at `/resources/`
- [ ] All Amazon links tested (correct ASIN, correct product)
- [ ] All JetBrains links tested (correct product pages)
- [ ] Disclosure page linked in site footer
- [ ] Resources page added to main navigation
- [ ] Images added or `image:` front matter removed
- [ ] Posts preview correctly in local Jekyll (`bundle exec jekyll serve`)
- [ ] FTC disclosure visible at bottom of each post

---

## Notes

- All content is written in Tamir's voice — conversational, first-person, self-deprecating humor.
- FTC disclosure appears at the bottom of every post AND on the standalone disclosure page.
- The resources page serves as a permanent, SEO-friendly hub for all affiliate links.
- Posts are designed to be genuinely useful technical content first, monetization second.


