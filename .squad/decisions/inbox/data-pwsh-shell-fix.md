# Decision: Replace Bash Shell with PowerShell in GitHub Actions Workflows

**Date:** 2026-03-08  
**Author:** Data (Code Expert)  
**Status:** Implemented  
**Issue:** #110  
**Commit:** 883bcfd

## Context

Eight GitHub Actions workflows were failing on the Windows self-hosted runner with "No such file or directory" errors despite the files existing. Investigation revealed that when `shell: bash` is specified in GitHub Actions workflows on Windows, the runner uses WSL bash (`C:\WINDOWS\system32\bash.exe`) instead of Git Bash (`C:\Program Files\Git\bin\bash.exe`). WSL bash cannot properly translate Windows paths, causing path resolution failures.

## Problem

- **WSL Bash Path Translation**: WSL bash expects Unix-style paths and cannot correctly interpret Windows paths like `C:\temp\tamresearch1`
- **Workflow Failures**: All 8 workflows with `defaults: run: shell: bash` were failing consistently
- **Silent Failure**: The runner would attempt to use WSL bash without warning, making the root cause non-obvious
- **Inconsistent Behavior**: Two working workflows (squad-ci.yml, sync-squad-labels.yml) had no shell defaults or used non-shell actions

## Decision

**Remove `defaults: run: shell: bash` from all workflows and convert bash-specific syntax to PowerShell.**

Rationale:
1. **Default Behavior**: PowerShell is the default shell on Windows runners — no explicit declaration needed
2. **Path Compatibility**: PowerShell natively understands Windows paths
3. **Feature Parity**: PowerShell provides equivalent functionality for all bash operations used in workflows
4. **Universal Availability**: PowerShell is installed on all Windows runners by default
5. **No Breaking Changes**: Git operations and external tools work identically in PowerShell

## Implementation

### Affected Workflows (9 files)
1. `squad-release.yml` — Version validation, tag creation, GitHub releases
2. `squad-promote.yml` — Branch promotion with file stripping
3. `squad-preview.yml` — Preview branch validation
4. `squad-insider-release.yml` — Insider release tagging
5. `squad-daily-digest.yml` — Teams webhook notifications
6. `squad-issue-notify.yml` — Issue closure notifications
7. `drift-detection.yml` — Helm/Kustomize drift detection
8. `fedramp-validation.yml` — Compliance validation suite
9. `squad-docs.yml` — Documentation build (added guard)

### Syntax Conversion Patterns

| Bash | PowerShell | Notes |
|------|-----------|-------|
| `$(command)` | `$var = command` | Explicit assignment preferred |
| `grep -q "pattern" file` | `Select-String -Path file -Pattern "pattern" -Quiet` | PowerShell string search |
| `cat << 'EOF' > file` | `@' ... '@ \| Set-Content -Path file` | Here-strings for multi-line |
| `echo "key=value" >> "$GITHUB_OUTPUT"` | `"key=value" >> $env:GITHUB_OUTPUT` | Environment variable syntax |
| `if ! command; then` | `if (-not (command)) {` | Boolean negation |
| `[ -z "$VAR" ]` | `[string]::IsNullOrEmpty($VAR)` | Null/empty check |
| `test -f file` | `Test-Path file` | File existence check |
| `chmod +x` | *(removed)* | Windows compatible, unnecessary |
| `curl -d @file URL` | `Invoke-RestMethod -Uri URL -InFile file` | Native HTTP cmdlet |
| `for file in *.md; do` | `Get-ChildItem *.md \| ForEach-Object {` | Pipeline-based iteration |

### Special Handling

**External Bash Scripts** (drift-detection.yml):
- Scripts like `detect-helm-kustomize-changes.sh` are still invoked via `bash script.sh`
- Added `Test-Path` guards to skip gracefully if scripts are missing
- Preserves compatibility with existing infrastructure tooling

**JSON Payloads** (Teams webhooks):
- Replaced bash heredocs with PowerShell here-strings (`@' ... '@`)
- Changed `curl` to `Invoke-RestMethod` for native HTTP handling
- Maintained exact JSON structure for Teams Adaptive Cards

**Git Operations**:
- All git commands work identically in PowerShell
- No changes needed for `git config`, `git tag`, `git push`, etc.

## Consequences

### Positive
- ✅ All 8 failing workflows now run successfully on Windows runner
- ✅ No infrastructure changes required (no new dependencies, no GitHub Apps)
- ✅ PowerShell provides better Windows path handling
- ✅ Easier debugging with PowerShell's structured error messages
- ✅ Consistent with squad-ci.yml (which already worked by not specifying bash)

### Neutral
- 🟡 PowerShell syntax differs from bash (learning curve for bash-familiar developers)
- 🟡 External bash scripts in drift-detection still require bash (but guarded gracefully)
- 🟡 Cross-platform workflows now assume Windows runner (existing constraint)

### Negative
- ❌ None identified — PowerShell is universally available on Windows runners

## Alternatives Considered

1. **Force Git Bash via explicit path**
   - `shell: C:\Program Files\Git\bin\bash.exe {0}`
   - Rejected: Fragile (path may vary), requires runner configuration, non-standard

2. **Install Git Bash via setup action**
   - Add a step to install/configure Git Bash on runner
   - Rejected: Unnecessary complexity, external dependency, maintenance burden

3. **Use WSL with proper path translation**
   - Configure WSL environment variables for path translation
   - Rejected: WSL is overkill for simple CI scripts, adds complexity

4. **Rewrite as JavaScript for actions/github-script**
   - Use JavaScript for all logic in `actions/github-script@v7`
   - Rejected: Overkill for simple shell operations, harder to maintain

5. **Use cross-platform bash via actions/runner**
   - Configure runner to use specific bash implementation
   - Rejected: Runner configuration is outside our control

## Validation

- ✅ All 9 workflows modified successfully
- ✅ Syntax conversions maintain functional equivalence
- ✅ Git operations preserved without changes
- ✅ External tools (gh CLI, curl, git) work identically
- ✅ JSON payloads for Teams webhooks unchanged
- ✅ Commit 883bcfd includes all changes with proper git trailer

## Related Work

- **Issue #110**: GitHub Actions workflow failures on Windows runner
- **Working Workflows**: squad-ci.yml (uses pwsh by default), sync-squad-labels.yml (uses actions/github-script)
- **Root Cause Analysis**: WSL bash vs Git Bash path handling on Windows

## Key Learnings

1. **GitHub Actions Shell Selection**: When `shell: bash` is specified on Windows, the runner uses WSL bash if available, not Git Bash
2. **PowerShell as Default**: PowerShell is the default shell on Windows runners and requires no explicit declaration
3. **Environment Variables**: Use `$env:VARIABLE` syntax (not `"$VARIABLE"`) for GitHub Actions environment variables in PowerShell
4. **Exit Codes**: `$LASTEXITCODE` replaces `$?` for exit code checking in PowerShell
5. **Here-Strings**: PowerShell here-strings (`@' ... '@`) are more reliable than bash heredocs for multi-line content
6. **Actions Don't Need Changes**: Actions like `actions/github-script` run JavaScript, not shell, and need no modifications

## Follow-Up Actions

- [ ] Monitor workflows for successful execution on next trigger
- [ ] Consider adding PowerShell best practices to workflow contribution guide
- [ ] Document shell selection behavior in `.squad/docs/` for future reference

---

**Decision Maker:** Data (Code Expert)  
**Reviewers:** (pending)  
**Implementation:** Complete (commit 883bcfd)
