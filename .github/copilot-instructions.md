# GitHub Copilot Instructions for Squad

## Working on Issues

When assigned to an issue via `squad:copilot` label:

1. **Read Context First:**
   - Check `.squad/team.md` for the team roster and capability profile
   - Read `.squad/routing.md` to understand work routing
   - Review `.squad/decisions.md` (if accessible) for past decisions

2. **Follow Project Conventions:**
   - Use branch naming: `squad/{issue-number}-{brief-description}`
   - Write clear commit messages with issue reference
   - Update relevant documentation if your changes affect it

3. **Capability Boundaries:**
   - **🟢 Good Fit:** Bug fixes, test additions, dependency updates, well-defined small tasks
   - **🟡 Needs Review:** Small features with clear specs (PR review required before merge)
   - **🔴 Not Suitable:** Architecture changes, security-sensitive code, design decisions → escalate to squad members

4. **Pull Request Guidelines:**
   - Title: Brief description + issue reference `(#123)`
   - Body: Link the issue with `Closes #123`
   - Request review from appropriate squad member based on work type
   - Add `squad:review` label for 🟡 complexity work

5. **Testing:**
   - Run existing tests before committing
   - Add tests for bug fixes and new features
   - Verify builds pass locally

6. **When to Escalate:**
   - Unclear requirements → comment on issue, tag @picard (Lead)
   - Security concerns → tag @worf (Security & Cloud)
   - Architecture questions → tag @picard
   - Infrastructure/deployment → tag @belanna

## PR Review Behavior

When reviewing squad member PRs:

- Focus on bugs, logic errors, test coverage, obvious issues
- Don't nitpick style if linting passes
- Approve straightforward changes quickly
- Request changes for bugs or missing tests
- Tag relevant squad member for design/architecture questions

## Communication

- Keep comments concise and actionable
- Use issue comments for questions
- Tag humans when blocked or uncertain
- Update issue status with progress notes

## Debugging Failed Copilot Sessions

When a `squad:copilot` task produces unexpected results or gets stuck:
1. Check the session log URL (posted by Ralph when task starts)
2. Expand the subagent activity logs to see what files were researched
3. Look for setup step failures in the initialization logs
4. Check if the agent firewall blocked a needed dependency

Before escalating to the squad lead, always check:
- Did Copilot read `.squad/routing.md`?
- Did Copilot read the relevant agent charter (`.squad/agents/{agent}/charter.md`)?
- Were all setup steps successful?
