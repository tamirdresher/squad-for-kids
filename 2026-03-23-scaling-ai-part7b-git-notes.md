---
layout: post
title: "The Invisible Layer — Git Notes, Orphan Branches, and the Squad State Solution"
date: 2026-03-25
tags: [ai-agents, squad, github-copilot, git, git-notes, gerrit, distributed-systems, state-management]
series: "Scaling AI-Native Software Engineering"
series_part: "7b"
---

> *"We are the Borg. Lower your shields and surrender your ships. We will add your biological and technological distinctiveness to our own. Your culture will adapt to service us. Resistance is futile."*
> — The Borg Collective

> *(The Borg also did not pollute their commit history with agent session logs. Just saying.)*

I published Part 7 three days ago. Meir's 97-file PR. The three approaches — orphan branch, separate repo, auto-bootstrap worktree. All of them defensible. None of them *satisfying*.

I should have let it go. I had other things to work on.

I did not let it go.

At around 1am I was still mentally running the tradeoffs. Orphan branch: correct isolation, but every new developer who clones the repo needs to learn about the existence of this hidden branch before Squad works. Separate repo: true isolation, but now "what decision did we make about auth last month" requires you to remember which of your two repos has the answer. Worktrees: elegant, but fragile in CI and utterly confusing to explain.

None of these felt like the *right* answer. They felt like compromises I could live with.

I hate compromises I can live with. They have a way of becoming permanent.

---

## The Blog Post I Almost Skipped

Two days later I was searching for something adjacent to the problem. Not "how to fix squad state in git" — I'd already read everything on that. I was searching for "git store metadata out of band" and "attach metadata to commits without polluting history." The kind of search that surfaces weird corners of the internet.

One result was a long post comparing code review systems at scale — specifically Gerrit vs. GitHub, written by someone who'd worked on both. I almost closed the tab. I've never used Gerrit in production. At Microsoft, everyone uses GitHub. Gerrit has always been that thing I vaguely knew existed because Android and Chromium use it, but that felt as relevant to my daily life as CVS.

Then I saw this line, mid-paragraph:

> *"Gerrit stores review state in `refs/notes/review` — a parallel ref namespace that attaches metadata to commits without ever appearing in the working tree or diff output."*

I stopped.

`refs/notes`.

I knew git had a notes feature. I had used it exactly once, in 2019, to annotate a release commit, and then immediately forgotten about it because nothing in my toolchain surfaced the notes automatically. I'd filed it under "git trivia" and moved on.

But *Gerrit* had been using it in production. For Android. For Chromium. At Google scale. Since approximately 2009.

That was the rabbit hole.

[meme: "One does not simply walk past a 'refs/notes/review' mention when debugging a distributed state problem at 1am"]

---

## What Git Notes Actually Are

Here's the short version for people who, like me, vaguely knew git notes existed but never thought hard about them.

Git notes are a parallel ref namespace — `refs/notes/*`. You can attach an arbitrary blob of text or JSON to *any* git object (commits, trees, tags) without that attachment ever appearing in the working tree, in `git diff`, in PR reviews, or anywhere else in the normal code review flow.

```bash
# Attach a note to the current commit
git notes --ref=squad/decisions add \
  -m '{"agent":"Data","decision":"use JWT for auth","reasoning":"existing pattern in codebase"}' \
  HEAD

# Read it back
git notes --ref=squad/decisions show HEAD

# List all objects that have notes in this namespace
git notes --ref=squad/decisions list
```

The note is stored as a blob, indexed by the commit SHA. It lives in `refs/notes/squad/decisions`. It does not appear in `git status`. It does not show up in pull request diffs. Your colleague opens the PR, sees 57 changed files, and none of them are squad decision logs.

This is the property I'd been looking for. It's invisible in the places that matter to human reviewers, but it's *there* — attached to the commit that caused the decision, traveling with the repo.

There's a real gotcha, though, and Q caught it immediately when I shared the approach.

**Explicit fetch required.** Git does not fetch notes by default. When someone clones your repo and runs `git fetch`, `refs/notes/*` is not included. You need to add the refspec explicitly:

```bash
# Fetch notes from remote — this is NOT part of default fetch
git fetch origin 'refs/notes/*:refs/notes/*'

# Or add it to your git config permanently
git config --add remote.origin.fetch 'refs/notes/*:refs/notes/*'
```

Ralph-watch handles this — it runs the explicit fetch before every work round. But a human developer cloning the repo fresh will not get the notes unless they know to ask for them. This is a real limitation and I'm not going to pretend it isn't.

---

## The Gerrit Validation That Made Me Take This Seriously

Gerrit is Google's code review tool. It has been using `refs/notes/review` since around 2009 — roughly 17 years at the time of writing — to store review state: scores, labels, submit records. The Android Open Source Project. Chromium. Projects measured in millions of lines of code and thousands of daily commits.

I want to be precise here, because I'm not claiming Gerrit uses git notes for *everything*. Gerrit later built NoteDb, which is an actual database using git as a storage backend in a more sophisticated way. But the original `refs/notes/review` pattern — attaching review metadata to commits via git notes — was production-validated at scale for years.

That's what matters to me. This isn't a pattern I invented at 1am. This is a pattern that Google ran on Android for 17 years. When you're evaluating an architectural approach, "Google did this for 17 years on Android" is about as strong a validation as you're going to find short of a formal proof.

I'd never used Gerrit in production, but I recognized the pattern immediately.

---

## What Q Found (The Honest Version)

Before I started building anything, I ran the approach past Q — Squad's devil's advocate agent, whose job is specifically to find problems with ideas that seem good at 1am.

Q found three real issues.

**One: explicit fetch required.** Already covered above. It's the biggest UX problem. Ralph handles it for agents, but humans won't get notes automatically after a fresh clone. Any tooling that consumes notes needs to document this loudly.

**Two: one note per namespace per object.** Each `refs/notes/REFNAME` namespace holds at most one note per commit. If two agents both try to annotate the same commit in the `refs/notes/squad/decisions` namespace, the second one overwrites the first. The fix is either per-agent namespaces (`refs/notes/squad/data`, `refs/notes/squad/worf`) or append-mode notes:

```bash
# Append to an existing note instead of overwriting it
git notes --ref=squad/data append \
  -m '{"timestamp":"2026-03-25T02:14:00Z","note":"verified auth JWT approach matches codebase pattern"}' \
  HEAD
```

**Three: merge conflicts.** Notes stored as blobs can conflict if two agents modify the same commit's note concurrently. Git has a notes merge strategy (`git notes merge`), but it's not well-known and requires explicit invocation. In practice, per-agent namespaces sidestep most of this — two agents rarely annotate the exact same commit in the exact same namespace at the same time.

**Q's verdict:** The approach is sound for commit-scoped metadata. Use it for the thin "why did we do THIS on this specific commit" layer. Don't use it as the primary state store for everything Squad needs to remember.

That verdict is exactly right. And it pointed me toward the architecture that actually works.

---

## The Two-Layer Architecture

Here's what I've landed on. Squad state lives in two places, for two different purposes.

```
┌─────────────────────────────────────────────┐
│               MAIN REPO                      │
│                                              │
│  src/ ──────────────────► PR ► Code Review  │
│  .squad/copilot-instructions.md  (stays)    │
│  .squad/routing.md               (stays)    │
│  .squad/agents/                  (stays)    │
│  .squad/upstream.json            (NEW)      │
│                                              │
│  refs/notes/squad/*   ◄── invisible layer   │
│  (never appears in diffs or PRs)            │
└──────────────────┬──────────────────────────┘
                   │ Ralph-watch
                   │ reads upstream.json on startup
                   │ syncs before every work round
                   │ promotes important notes after
                   ▼
┌─────────────────────────────────────────────┐
│            SQUAD STATE REPO                  │
│         (orphan branch or separate repo)     │
│                                              │
│  decisions.md        (append-only log)      │
│  agent-histories/    (per-agent context)    │
│  ralph/work-queue    (task state)           │
│  ceremonies/         (retros, reviews)      │
└─────────────────────────────────────────────┘
```

The `.squad/` folder doesn't disappear from the main repo. It still holds everything GitHub Copilot needs to understand the team: the copilot-instructions.md, routing config, agent charters. What changes is the addition of `upstream.json` — a pointer to where the *live* state actually lives:

```json
{
  "stateRepo": "tamirdresher/squad-state",
  "branch": "squad/state",
  "syncOnStartup": true
}
```

Ralph-watch reads `upstream.json` on startup, syncs the live decisions and histories from the state repo before every work round, and — this is the part that ties the two layers together — **promotes important git notes to `decisions.md`** after a round completes.

The git notes layer is the thin "why did we make this specific choice on this specific commit" layer. Commit-scoped context that travels with the code. When Data makes an interesting architectural decision while working a PR — not just "I chose JWT" but "I chose JWT *because* the existing auth middleware already uses it and adding a second strategy would require refactoring auth.go lines 47-89" — that gets written as a note on the commit. It's attached to the code change that caused it. It lives right there, invisible in the PR, but retrievable when you're debugging six months later and wondering why auth works the way it does.

Ralph promotes the important ones up to `decisions.md` in the state repo, so they're preserved in the full team memory and don't require knowledge of git notes to access.

The state repo (or orphan branch — either works here, and I'm still testing both) handles the persistent, long-lived state: the full decision log, agent histories, work queue, retrospectives. None of it ever touches a PR.

---

## Meir's PR, Revisited

Let's run Meir's scenario again, with this architecture in place.

Data picks up a feature. Works a PR. Makes some interesting choices along the way — writes git notes on the relevant commits. Opens the pull request.

Meir opens the PR. What does he see?

- Feature files changed: 57
- Squad decision logs: 0
- Agent histories: 0
- `.squad/upstream.json`: 0 changes (it didn't change — the pointer is stable)
- Git notes: 0 (invisible in the PR diff by design)

57 files. All code. Meir reviews in 15 minutes, approves, goes to lunch.

Later that week, a different engineer wonders why Data chose JWT for the new endpoint rather than the service's existing API key auth. They look at the commit, run `git notes --ref=squad/data show <commit-sha>`, and find the exact reasoning, timestamp, and agent that made the call.

The context traveled with the code. It just didn't bother anyone while they were reviewing.

---

## What This Is and What It Isn't

I want to be honest here: **this is not a complete implementation yet**.

I have the two-layer architecture sketched out. Ralph-watch has the git notes fetch logic. The `upstream.json` pointer is real and in use. The promotion from notes to `decisions.md` is partially implemented. But I haven't battle-tested this across a month of real Squad work, and I haven't fully solved the "developer clones fresh and doesn't know to fetch notes" UX problem.

What I *have* is a direction that feels architecturally right, for reasons I can articulate:

- The git notes pattern is validated by 17 years of Gerrit on Android. I didn't invent it.
- Q reviewed it and the objections are *manageable* rather than *fatal*. That's a meaningful distinction.
- The two-layer split — invisible commit-scoped notes + external persistent state — matches the actual information architecture of what Squad needs. Commit-scoped context belongs with commits. Long-lived team memory belongs somewhere durable.

I shared the approach on LinkedIn earlier this week and the response was interesting — a few people who'd worked on Gerrit in past jobs jumped in to confirm the `refs/notes/review` pattern and add nuances I hadn't considered (including one comment about notes merge strategies that I need to read more carefully). That kind of signal matters.

The full implementation and a proper retrospective are coming in a future post. But I wanted to share the direction now, because Part 7 left the series on a cliffhanger and you deserve to know where I think this is going.

The Borg have a saying about distributed knowledge: every unit of information should be accessible to the collective, attached to where it originated, and invisible to those who don't need it.

Okay, they don't actually have that saying. But they should.

🖖

---

> 📜 **Series: Scaling AI-Native Software Engineering**
> - **Part 0**: [Organized by AI — How Squad Changed My Daily Workflow](/blog/2026/03/10/organized-by-ai)
> - **Part 1**: [Resistance is Futile — Your First AI Engineering Team](/blog/2026/03/11/scaling-ai-part1-first-team)
> - **Part 2**: [When the Collective Meets Enterprise](/blog/2026/03/12/scaling-ai-part2-collective)
> - **Part 3**: [Unimatrix Zero — When Your AI Squad Becomes a Distributed System](/blog/2026/03/15/scaling-ai-part3-streams)
> - **Part 4**: [When Eight Ralphs Fight Over One Login](/blog/2026/03/17/scaling-ai-part4-distributed)
> - **Part 5**: [The Vinculum — Eight Distributed Systems Lessons My AI Team Taught Me the Hard Way](/blog/2026/03/18/scaling-ai-part5-evolution)
> - **Part 6**: [9 AI Agents, One API Quota — The Rate Limiting Problem](/blog/2026/03/20/rate-limiting-multi-agent)
> - **Part 7**: [When Git Is Your Database — The Enterprise State Problem Nobody Warned Me About](/blog/2026/03/23/scaling-ai-part7-enterprise-state)
> - **Part 7b**: The Invisible Layer — Git Notes, Orphan Branches, and the Squad State Solution ← You are here

*Git notes have existed since git 1.6.6 (2010). Gerrit has been using them in production for longer than most people reading this have been using git. Your AI team's state management problem has a 17-year-old precedent. You're welcome.*
