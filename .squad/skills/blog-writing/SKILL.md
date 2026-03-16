# Skill: Blog Writing

> Extracted from the **"Scaling AI-Native Software Engineering"** series (Parts 0–3).
> Confidence: **high** — validated across 4 published English posts + 2 Hebrew translations.

---

## 1. Tamir's Writing Voice

Tamir writes like he talks to another engineer over coffee. The voice is casual but precise — never academic, never marketing-speak.

### Patterns to follow

| Pattern | Example from the series |
|---------|------------------------|
| **Storytelling-first** | Every post opens with a personal story, not a feature list. Part 0 starts with "I'm not an organized person." Part 1 starts with "By now you know the story." |
| **Casual but precise** | Technical claims always have specifics: "52 open tasks," "five investigations launched simultaneously," "9 issues closed in roughly two hours." Never vague. |
| **Real experiments, not theory** | Every concept is backed by something Tamir actually did. "I ran the experiment. This is the story of what worked, what broke." |
| **Dad jokes** | Deployed sparingly but deliberately. "Why did the AI agent fail to pick up the task? Because it had commitment issues — specifically, a `.md` commitment when it needed a `.yaml` one." |
| **Star Trek / Borg metaphors** | Woven through naturally as the series theme. "Your work team will be assimilated. Probably." Used as section titles (Unimatrix Zero, The Collective) and conceptual framing. |
| **Honest reflection sections** | Every post has a "here's what actually broke" moment. Part 0 ends with a full "Honest Reflection" section admitting limits. Part 3 has an explicit "What Broke" section. |
| **TLDR-style hooks** | Opening paragraphs function as TLDRs — state the payoff immediately, then unpack. "Turns out: yes. But not by copy-pasting my personal setup." |
| **Direct address** | "Here's the thing nobody tells you about AI agents." "Every senior engineer reading this is nodding." |
| **Parenthetical asides** | "(If you've managed engineers, you know that last part is the real miracle.)" — conversational interjections. |
| **Emoji as punctuation** | 🖖 at the end. 🟩⬛ for Borg-themed posts. Never overused. |

### Anti-patterns to avoid

- **Marketing voice.** Never "leverage," "unlock," "empower," or "revolutionize."
- **Hedging.** Don't say "it might be useful to consider." Say "here's what I did."
- **Abstract without concrete.** Every claim needs a real example, a real number, or a real failure.
- **Forced humor.** The dad jokes work because they're rare and self-aware. One per post max.

---

## 2. Blog Post Structure

Every post in the series follows a consistent arc. Not rigid sections — more of a storytelling rhythm.

### The Arc

```
Hook → Context → Experiment → What Worked → What Broke → Insight → Solution → What's Next
```

### How each part maps

| Section | Purpose | Example |
|---------|---------|---------|
| **Hook** | Personal story or confession that makes the reader lean in | "I'm not an organized person." / "The second team didn't know *anything* the first team had learned." |
| **Context** | Frame the problem in terms the reader recognizes | "Most real engineering organizations don't live in a monorepo. They have layers." |
| **Experiment** | Describe what you actually tried — repo names, team setup, real configs | "The repo is tamirdresher/squad-tetris. I created 30 GitHub issues across three teams." |
| **What Worked** | Celebrate wins with specifics | "9 issues closed with real, working code... A Tetris game engine with full collision detection." |
| **What Broke** | Honest failures — this is the credibility section | "Label leakage. Merge conflicts. Codespace timeouts." — numbered list with human parallels. |
| **Insight** | The "aha" moment connecting the failure to a deeper truth | "Every single problem is a problem human teams face too." |
| **Solution** | The feature/pattern/approach that emerged | SubSquads, upstream inheritance, human squad members. Always with real config/code. |
| **What's Next** | Tease the next post AND genuine future directions | Short, forward-looking, ends with emoji. Links to next post in series. |

### Structural conventions

- **Horizontal rules (`---`)** separate major sections. Use between every top-level narrative shift.
- **H2 (`##`) for major sections.** H3 (`###`) for sub-sections within. Never H1 in the body.
- **Bolded key sentences** within paragraphs for scanability: `**You make the humans part of the Squad.**`
- **Blockquotes** for Star Trek quotes at the top of posts (Parts 2, 3) and for the series nav at the bottom.
- **Italics** for emphasis on single words or short phrases: "they were *learning*."

---

## 3. Code Block Rules

### Do

- **Always link to real repos.** Every code block should reference a real file, real PR, or real repo. `[see actual config](https://github.com/tamirdresher/squad-tetris/blob/main/.devcontainer/ui-squad/devcontainer.json)`
- **Keep blocks short.** 5–15 lines ideal. The longest blocks in the series are ~20 lines. If it's longer, trim it and say "(trimmed for readability)."
- **Use the right language tag.** `markdown`, `bash`, `json`, `yaml`, `powershell` — always explicit.
- **Show real output.** Commit messages, config files, directory structures — all from actual repos.

### Don't

- **Never show theoretical/hypothetical code.** If it doesn't exist in a repo, don't show it.
- **Never show full scripts.** Link to the repo instead: `You can see the full script in my demo repo: [ralph-watch.ps1](link)`.
- **Never show credentials, webhook URLs, or tokens.** Use `<url>` placeholders.

### Directory tree format

Use indented text with `├──`, `└──`, and `│` for directory structures:

```
.squad/cross-machine/
├── config.json
├── tasks/
│   ├── blog-part3-review.yaml
│   └── sample-test-task.yaml
└── responses/
    └── blog-part3-CPC-tamir-WCBED.md
```

---

## 4. Series Conventions

### Theme

The "Scaling AI-Native Software Engineering" series uses **Star Trek Borg** as its unifying metaphor:

| Post | Borg Concept | Title |
|------|-------------|-------|
| Part 0 | Personal drone | "Organized by AI" |
| Part 1 | Assimilation | "Resistance is Futile" |
| Part 2 | The Collective | "The Collective" |
| Part 3 | Unimatrix Zero | "Unimatrix Zero" |

### Series navigation blockquote

Every post ends with an identical navigation block. The current post is marked with `← You are here`:

```markdown
> 📚 **Series: Scaling AI-Native Software Engineering**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai) ← You are here
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [The Collective — Organizational Knowledge for AI Teams](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — Many Teams, One Repo with SubSquads](/blog/2026/03/15/scaling-ai-part3-streams)
```

**Critical rule:** When adding a new post to a series, update the nav block in **ALL existing posts** in the series. This was a source of broken cross-links in the original series.

### URL format

```
/blog/YYYY/MM/DD/slug
```

Examples:
- `/blog/2026/03/10/organized-by-ai`
- `/blog/2026/03/11/scaling-ai-part1-first-team`

### Forward/backward links

- Open each post by referencing the previous: "In [Part 1](/blog/...), I showed you..."
- Close each post by teasing the next: "In [Part 2](/blog/...), I'll show how..."
- Part 0 sets the stage with links to all future parts in the intro paragraph.

### Front matter

```yaml
---
layout: post
title: "Subtitle — Descriptive Title"
date: YYYY-MM-DD
tags: [ai-agents, squad, github-copilot, ...]
series: "Series Name"
series_part: N
---
```

---

## 5. Image Rules

### Hero image

Every post has one hero image near the top, placed after the opening narrative and before the first technical section:

```markdown
![Alt text](/assets/series-slug/filename.jpg)
*"Caption in italics — often a joke or Star Trek quote."*
```

### Conventions

| Rule | Detail |
|------|--------|
| **One hero image** | Placed after the hook, before the first `---`. |
| **Inline images** | Additional images placed at section breaks to illustrate concepts (diagrams, screenshots, memes). |
| **Captions in italics** | Always on the line directly below the image, starting with `*` and ending with `*`. |
| **Asset path** | `/assets/{series-slug}/{filename}` or `/assets/img/posts/{category}/{filename}`. |
| **Alt text** | Descriptive, not decorative. "Upstream inheritance hierarchy" not "image1". |
| **Consistent graphic language** | Within a series, use the same style (generated illustrations, diagrams, screenshots). The Scaling AI series uses AI-generated Borg/Star Trek themed illustrations plus clean diagrams. |
| **Blurred screenshots** | When showing real project boards or issues, blur sensitive data. Use `-blurred` suffix: `project-board-blurred.png`. |

### Diagrams

For conceptual diagrams (upstream hierarchy, scaling arc, workstreams), use clean line diagrams with labels. Always include a caption explaining what the diagram shows.

---

## 6. Hebrew Translation Rules

Extracted by comparing `2026-03-10-organized-by-ai.md` with `2026-03-10-he-organized-by-ai.md` and `2026-03-11-scaling-ai-part1-first-team.md` with `2026-03-11-he-scaling-ai-part1-first-team.md`.

### What to translate

- All prose (paragraphs, section headings, list items).
- Image captions (translate the caption text, keep the image path).
- Series navigation labels ("Part 0" → "חלק 0", "You are here" → "אתם כאן").
- The "Honest Reflection" section and any editorial commentary.

### What to keep in English

| Category | Examples |
|----------|---------|
| **Code blocks** | All code, commands, config files stay exactly as-is. |
| **Product names** | GitHub, Azure DevOps, Copilot, Teams, Outlook, Planner, Notion, Squad, Aspire. |
| **Technical terms** | repo, PR, merge, deploy, branch, commit, mock, linting, scaffold, pipeline, worktree, CRD, API, webhook, MCP, SBOM, ADR, CI/CD. |
| **Agent names** | Picard, Data, Seven, Worf, Ralph, Neelix, Kes, B'Elanna, Morpheus, Trinity, Switch, Dozer. |
| **File paths** | `.squad/team.md`, `.squad/decisions.md`, `ralph-watch.ps1`, etc. |
| **URLs** | All links stay as-is (though internal links change to `/he/` prefix where Hebrew versions exist). |
| **Acronyms** | TLDR, TODO, JSON, YAML, PID, COM, TTS, MP3. |

### Tone rules

| Rule | Detail |
|------|--------|
| **Casual Israeli tech blogger** | Write like a senior Israeli developer explaining something cool at a meetup. Not formal, not academic. |
| **Never formal Hebrew** | Avoid שפת תקנים (standards-speak). Use spoken Hebrew: "בואו נתחיל בהודאה" not "ברצוני להציג." |
| **Hebrew tech jargon** | Use natural Hebrew tech words: ריפו (repo), לייבל (label), דשבורד (dashboard), לעשות merge (to merge), לעשות deploy (to deploy). |
| **Mixed language is natural** | Hebrew developers mix freely: "עשיתי onboarding ל-Squad." "ה-prompt של Ralph אומר מפורשות..." This is correct — don't force pure Hebrew. |
| **Transliterated terms** | When a term has no Hebrew equivalent, transliterate: פרודוקטיבי (productive), אוטומגית (automagically), פרואקטיבי (proactive). |
| **Gender** | Default to masculine plural for general audience (הם, אתם) following standard Israeli tech writing convention. |

### Front matter for Hebrew

```yaml
---
layout: post-he
title: "Hebrew Title"
date: YYYY-MM-DD
tags: [same as English]
series: "Same series name in English"
series_part: N
lang: he
dir: rtl
permalink: /he/YYYY/MM/DD/slug/
sitemap: false
comments: false
---
```

**Key differences from English front matter:** `layout: post-he`, `lang: he`, `dir: rtl`, custom `permalink` with `/he/` prefix, `sitemap: false`, `comments: false`.

### Hebrew series navigation

Translate labels but keep links pointing to Hebrew versions where they exist:

```markdown
> 📚 **Series: Scaling AI-Native Software Engineering**
> - **חלק 0**: [מאורגן על ידי AI — ...](/he/2026/03/10/organized-by-ai/)
> - **חלק 1**: [ההתנגדות חסרת תועלת — ...](/he/2026/03/11/scaling-ai-part1/) ← אתם כאן
> - **חלק 2**: [הקולקטיב — ...](/he/2026/03/12/scaling-ai-part2-collective/)
> - **חלק 3**: [Unimatrix Zero — ...](/blog/2026/03/15/scaling-ai-part3-streams)
```

**Note:** If a Hebrew version doesn't exist yet, link to the English version. Part 3 above links to `/blog/...` (English) because no Hebrew translation existed at time of writing.

---

## 7. Pre-Publish Checklist

Run through this before merging any blog post PR:

```markdown
- [ ] **Links work** — Every internal link (`/blog/...`) resolves. Every external link returns 200.
- [ ] **Images exist** — Every image path in the markdown has a corresponding file in `/assets/`.
- [ ] **Series nav updated in ALL posts** — Adding Part N means updating the nav block in Parts 0 through N-1 too.
- [ ] **Hebrew version created** — Every English post gets a Hebrew translation.
- [ ] **Hebrew version nav updated** — Hebrew series nav links to `/he/...` versions where they exist.
- [ ] **No "coming soon" placeholders** — Replace with real links or remove.
- [ ] **No leaked HTML** — Check for raw `<div>`, `<span>`, `</output>` tags that should be markdown.
- [ ] **Code blocks have language tags** — Every ``` has a language: ```yaml, ```bash, ```markdown, etc.
- [ ] **Front matter complete** — title, date, tags, series, series_part all present.
- [ ] **Hebrew front matter correct** — layout: post-he, lang: he, dir: rtl, permalink with /he/ prefix.
- [ ] **Captions are italic** — Every image caption uses `*caption text*` format.
- [ ] **No sensitive data** — Webhook URLs, tokens, real email addresses blurred or replaced.
- [ ] **Repo links valid** — Every `github.com/tamirdresher/...` link points to a real, public repo.
- [ ] **Date in filename matches front matter** — `2026-03-15-slug.md` matches `date: 2026-03-15`.
```

---

## 8. What Went Wrong — Lessons Learned

These are real problems that occurred during the creation and publication of the Scaling AI series. Each lesson should inform future blog work.

### Broken cross-links across posts

**What happened:** When Part 2 was published, the series nav in Part 0 and Part 1 still pointed to old slugs or "coming soon" text. Readers clicking through the series hit 404s.

**Lesson:** Always update series navigation in ALL existing posts when publishing a new one. Treat it as a multi-file PR — never merge just the new post alone.

### Leaked HTML tags

**What happened:** Raw `</output>` tags from agent tool output leaked into published markdown (visible at the bottom of Part 1's source). Build tools rendered them as visible text or broke page layout.

**Lesson:** After any agent generates blog content, manually search for `</output>`, `<output>`, `<`, `<function_results>`, and similar XML/HTML artifacts. These are agent tooling residue, not content.

### Robotic Hebrew translation

**What happened:** Early Hebrew translations read like Google Translate output — grammatically correct but unnaturally formal. "ברצוני להציג את" instead of "בואו נתחיל."

**Lesson:** Hebrew translations must sound like an Israeli tech blogger talking, not like a translated document. Read the Hebrew version aloud — if it sounds like a government form, rewrite it. Mix English terms naturally.

### Missing images

**What happened:** Posts referenced images in `/assets/` that hadn't been committed yet. The blog built successfully but showed broken image icons.

**Lesson:** Include image files in the same PR as the blog post. Never merge a post that references images in a future commit.

### Auth confusion between personal and EMU accounts

**What happened:** Git operations failed because the session was authenticated with the wrong GitHub account (personal vs. `_microsoft` EMU). Pushes to the blog repo were rejected with permission errors.

**Lesson:** Before any git push to `tamirdresher.github.io`, verify auth:
```bash
$env:GH_TOKEN = (gh auth token --user tamirdresher_microsoft 2>&1).Trim()
```
The blog repo lives under the personal account but may require specific token auth depending on the machine's git credential configuration.

### Series nav inconsistency between English and Hebrew

**What happened:** English series nav linked all 4 parts correctly, but Hebrew Part 1 nav linked Part 3 to the English URL (`/blog/...`) instead of a Hebrew URL, because no Hebrew Part 3 existed yet.

**Lesson:** This is actually correct behavior — link to what exists. But document it: if a Hebrew version doesn't exist for a post, the Hebrew nav should link to the English version as a fallback. Never link to a non-existent `/he/...` URL.

### Post dating and URL mismatch

**What happened:** Part 3 was initially drafted with a date of `2026-03-13` but published as `2026-03-15`. The slug in other posts' nav blocks still referenced the old date.

**Lesson:** Finalize the publication date before adding forward references in earlier posts. If the date changes, grep the entire `_posts/` directory for the old date string and update all references.
