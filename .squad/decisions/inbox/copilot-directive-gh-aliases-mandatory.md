### 2026-03-15T10:30Z: MANDATORY team directive
**By:** Tamir Dresher (via Copilot)
**What:** ALL agents MUST use `gh-personal` (alias `ghp`) for tamirdresher repos and `gh-emu` (alias `ghe`) for tamirdresher_microsoft repos. NEVER use bare `gh` followed by `gh auth switch`. The aliases auto-switch. Define them at the top of any script: `function gh-personal { gh auth switch --user tamirdresher 2>$null | Out-Null; gh @args }` and `function gh-emu { gh auth switch --user tamirdresher_microsoft 2>$null | Out-Null; gh @args }`
**Why:** Agents constantly fail account switching causing operations on wrong repos. This is the permanent fix.
**Severity:** CRITICAL — violations cause real damage (PRs on wrong repos, failed pushes, auth errors)
