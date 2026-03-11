### 2026-03-11: Picard — Weekly Retro Process Improvements

**Date:** 2026-03-11  
**Author:** Picard (Lead)  
**Status:** Proposed  
**Scope:** Team Process

---

## Directive 1: Autonomy Over Dependency

**Rule:** When an issue has sufficient context to make a reasonable decision, agents MUST decide and act instead of setting `status:pending-user`. Only block on Tamir for:
- Budget/cost decisions exceeding $50/month
- Strategic direction changes (e.g., changing architecture, adding new major components)
- External communication on Tamir's behalf (emails to colleagues, public posts)
- Access/permission requests that only Tamir can approve

**For everything else:** Make the call. Document it. Tamir can override later.

**Source:** Tamir directive, 2026-03-11 ("Don't ask — decide and act")

---

## Directive 2: Board Staleness Detection

**Rule:** Ralph MUST flag any issue that has been in `In Progress` status for more than 3 calendar days without a comment or status update. The flag should appear in Ralph's round summary as a "Stale item alert."

**Action on detection:** Add a comment to the issue asking the assigned agent to update status or explain the delay. If no response after 1 additional day, move to backlog with a note.

**Source:** Issue #302 — Tamir caught a stuck item that Ralph missed.

---

## Directive 3: Issue Deduplication Before Creation

**Rule:** Before creating a new issue, Ralph MUST search existing open issues by title keywords. If a substantially similar issue exists, add a comment to the existing issue instead of creating a duplicate.

**Source:** Issues #309 and #312 are duplicates (both "Tech News Digest: 2026-03-11").

---

## Directive 4: Weekly Retrospective Schedule

**Rule:** Every Friday, Picard runs a weekly retrospective following the process documented in `.squad/ceremonies.md`. The retro:
1. Scans orchestration and session logs from the past 7 days
2. Reviews issue comments for Tamir feedback signals
3. Reviews PR feedback for patterns
4. Produces a report at `.squad/log/{date}-weekly-retro.md`
5. Files any new directives to decisions inbox
6. Commits and pushes

**Source:** Tamir directive, 2026-03-11.

---

## Directive 5: Capture "From Now On" Directives Permanently

**Rule:** When Tamir creates an issue starting with "From now on" or containing standing-order language, the assigned agent MUST:
1. Extract the directive
2. File it to `.squad/decisions/inbox/` immediately
3. Confirm on the issue that the directive has been captured
4. Close the issue (the directive lives in decisions.md, not in the issue tracker)

**Source:** Multiple directive issues (#278, #279, #299, #300) that were closed but may not have all been captured as permanent decisions.

---

## Directive 6: Thorough First Attempts

**Rule:** When Tamir asks for something, the first attempt MUST be thorough. Don't return with "no results found" — instead:
1. Try multiple search strategies
2. Expand keywords and try synonyms
3. If still blocked, explain exactly what was tried and what would be needed to succeed
4. Never make Tamir repeat a request

**Source:** Issue #305 — Tamir had to ask twice about Teams chat search.

---

## Skills/Tooling Gaps Identified

1. **Staleness scanner** — Ralph needs a board staleness check added to its round workflow
2. **Issue deduplication** — Needs a pre-creation search step in Ralph's issue creation flow
3. **Pending-user audit** — Automated weekly scan of pending-user issues with age tracking
4. **EMU PR workarounds** — Document known EMU repo limitations in a skill or reference doc
5. **WhatsApp monitoring** — Tamir requested Playwright-based read-only WhatsApp watcher (not yet implemented)
