# Troi — History

## Project Context

- **Project:** tamresearch1 — Tamir Dresher's AI-augmented work repository
- **User:** Tamir Dresher
- **Stack:** Node.js, PowerShell, GitHub Actions, Jekyll blog (tamirdresher.com)
- **Blog repo:** tamirdresher/tamirdresher.github.io (personal GitHub account)
- **Blog URL:** https://www.tamirdresher.com/blog/{year}/{month}/{day}/{slug}
- **Squad universe:** Star Trek TNG/Voyager

## Key Context

- Tamir's blog series: Part 0 ("Organized by AI"), Part 1 ("From Personal Repo to Work Team"), Part 2 (upcoming — human squad members)
- Blog must use flowing prose, not bullet points
- First-person, conversational, funny, personal voice
- NEVER mention DK8S, Distributed Kubernetes, or FedRAMP in public blog posts
- Always use generic terms: "my team at Microsoft", "infrastructure platform team"
- Blog URL format: https://www.tamirdresher.com/blog/{year}/{month}/{day}/{slug} — NO .html extension
- Push to personal GitHub account (tamirdresher), not EMU account (tamirdresher_microsoft)
- Previous blog revisions had issues with: standalone intro (should be continuation), wrong squad roster names, DK8S references, bullet-point heavy sections

## Learnings

- Created 2026-03-12. Studying Tamir's voice from existing blog posts and issue discussions.
- **2026-03-12 — Part 1 Revision (Issue #313):**
  - Tamir's voice signature: confession-style openings, self-deprecating humor about being disorganized, bold text for emphasis, "Here's the thing" / "Here's what's different" transitions, parenthetical asides that add humor.
  - Part 0 is the gold standard. Key pattern: story-driven sections that flow into each other, not isolated feature lists. Every technical concept is wrapped in a personal anecdote.
  - The narrative arc matters more than feature coverage. Human Squad Members is the climax of Part 1 because it's the bridge from "personal toy" to "real team tool" — the same emotional arc as Part 0's "first system I didn't abandon."
  - Features section works best as flowing paragraphs with bold feature names, not H3 subsections with bullet points. Part 0 uses prose paragraphs exclusively.
  - Honest Reflection sections are essential to Tamir's voice — he always ends with genuine self-assessment, acknowledging both the magic and the mess. Never pure hype.
  - Published blog URL format confirmed: `/blog/{year}/{month}/{day}/{slug}` — no `.html`. Part 0 on the live site still has `.html` in its own footer but Part 1 (published later) corrected this.
  - Star Trek references should be woven naturally into the narrative, not forced. The Borg/assimilation metaphor works because it maps to genuine parallel execution — the metaphor earns itself.
  - Squad roster for all public content: Picard (Lead), Data (Code), Worf (Security), Seven (Docs/Research), B'Elanna (Infra), Ralph (Monitor). Never use Riker, Troi, Geordi or other wrong roster names.
  - Decision: Cut "Adding More Expertise" and "Onboarding" sections from Part 1 — Part 0 already covered onboarding in detail. Part 1 should assume the reader did the onboarding and is now seeing the team *work*.

- **2026-03-12 — Part 2 Refresh (Issue #313):**
  - Part 2 is the bridge from personal playground to real work team. The emotional arc: "Can Squad work where real stakes exist?"
  - Started with existing draft that had good structure but over-indexed on work-specific details (DK8S, FedRAMP). Needed to make it relatable to any team, not just infrastructure/compliance.
  - Key narrative shift: led with "The First Attempt (Spoiler: It Didn't Work)" — showing that you can't just copy-paste personal Squad to work. This builds credibility.
  - Human squad members are the hero of Part 2, not just a feature mention. Showed them in practice with real example (auth token bug with parallel AI analysis + human decision).
  - Maintained Tamir's voice patterns: conversational flow, self-deprecating honesty ("some days I spend more time correcting AI mistakes"), specific examples over generic claims.
  - Removed all DK8S/Distributed Kubernetes/FedRAMP references as per sanitization rules. Used "my team at Microsoft" and "infrastructure platform team" instead.
  - "Honest Reflection" section is critical — Tamir always ends with genuine self-assessment, acknowledging rough edges alongside wins.
  - Part 3 teaser: organizational knowledge, Squad upstreams, multiple teams learning from each other. The series is scaling: personal → team → org.
  - Flowing prose throughout. No bullet point sections except where listing specific routing examples or metrics table (which Part 1 didn't have, so I kept metrics as prose).
  - Series footer uses consistent URL format: /blog/{year}/{month}/{day}/{slug} with no .html extension.

---

## 2026-03-12 Round 1 Team Updates

**Data (Code Expert):** Completed multi-machine Ralph coordination implementation (#346). GitHub-native coordination protocol using issue assignments, labels, and heartbeat comments. Spec documented with 15-minute stale threshold, 2-minute heartbeat interval, machine-specific branch naming. PR #353 created on `squad/346-ralph-multi-machine` branch, awaiting review.

**Neelix (Comms):** Teams morning briefing sent with 3 urgent items, 8 pending, full squad progress. Board state synchronized. Tech news scanned. All squad-monitor issues closed.

**Board State:** Issues #344–#349 added to backlog. Board reconciliation clean, no mismatches.
