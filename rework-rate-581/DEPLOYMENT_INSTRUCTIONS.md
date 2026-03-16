# Rework Rate Metric — Deployment Instructions

**Status:** ✅ Ready for external repo deployment  
**Assigned to:** Tamir Dresher (using personal GitHub account)  
**Deadline:** As soon as possible  
**Issue:** tamirdresher_microsoft/tamresearch1#581  
**External PR target:** bradygaster/squad PR (targeting `dev` branch)

---

## Summary

The rework rate feature (5th DORA metric) has been **fully implemented in TypeScript** to match bradygaster/squad's project conventions. The implementation is complete, tested, and ready to deploy.

### Why a New PR?

The original PR #381 (bradygaster/squad#381) has several issues:
- ❌ Targets `main` instead of `dev`
- ❌ Uses CommonJS/JS instead of TypeScript
- ❌ Has merge conflicts
- ❌ Not following their project structure (monorepo)

The new implementation addresses all these issues and is **ready to merge** into their `dev` branch.

### Why a Personal Account?

The `tamirdresher_microsoft` account is an Enterprise Managed User (EMU) with external repo restrictions:
- Cannot fork external repos
- Cannot push to external repos  
- Cannot comment on external PRs/issues

**Solution:** Use your personal GitHub account (`tamirdresher`).

---

## Step-by-Step Deployment

### Step 1: Clone the Target Repo

Use your personal GitHub account:

```bash
git clone https://github.com/bradygaster/squad.git
cd squad
git fetch origin dev:dev
git checkout dev
```

### Step 2: Apply the Patch

The patch file is ready at: `rework-rate-581/full.patch`

```bash
# From the squad repo directory
git am < ../rework-rate-581/full.patch
```

This will create a commit with:
- TypeScript implementation
- CLI command
- Tests
- Changeset
- Skill template

### Step 3: Verify the Build (Optional but Recommended)

```bash
npm run build
npm run test
```

Expected output: All tests pass (13 new rework rate tests + 83+ existing tests)

### Step 4: Push and Create PR

```bash
# Create a feature branch
git push origin HEAD:feat/rework-rate-ts

# Then create PR on GitHub targeting `dev` branch with:
# Title: "feat(metrics): Add rework rate CLI command (5th DORA metric)"
# Description: See PR body template below
```

### Step 5: Close Old PR #381

On bradygaster/squad PR #381:
1. Add comment (from personal account):
   ```
   Superseded by new PR with proper TypeScript implementation.
   Target branch: `dev` (not `main`)
   Implementation follows all project conventions.
   ```
2. Close as "not planned"

### Step 6: Update Issue #581

Once new PR is created at bradygaster/squad:
1. Comment on issue #581 in tamresearch1 with the new PR link
2. Update status to "done"

---

## PR Body Template

```markdown
## Summary

Adds a `squad rework` CLI subcommand that measures PR rework rate — the emerging 5th DORA metric — by analyzing merged pull requests for post-review revision patterns.

## What is Rework Rate?

Rework Rate measures what percentage of code changes require revision after initial review. It captures:

- **Review Cycles** — How many times a PR goes through changes-requested → push → approval loops
- **Post-review commits** — Commits pushed after the first review
- **Rejection Rate** — Percentage of PRs receiving `changes-requested`
- **Rework Time** — Calendar time spent in rework

## Changes

- `packages/squad-cli/src/cli/core/rework.ts` — Pure calculation functions with TypeScript interfaces
- `packages/squad-cli/src/cli/commands/rework.ts` — CLI command with --days, --limit, --json flags
- `test/rework-rate.test.ts` — 13 Vitest unit tests
- `packages/squad-cli/templates/skills/rework-rate/SKILL.md` — Agent skill template
- `.changeset/add-rework-rate-command.md` — Changeset for versioning
- CLI wiring in `cli-entry.ts` and barrel exports in `index.ts`

## Usage

```bash
# Analyze last 30 days (default)
squad rework

# Custom period and limit
squad rework --days 7 --limit 50

# Machine-readable JSON output
squad rework --json
```

## Design Decisions

- **TypeScript (ESM)** — Follows project conventions with strict mode
- **Zero dependencies** — Uses only Node.js built-ins + `gh` CLI
- **Separated concerns** — Pure calculation logic in core/ for clean testing
- **Vitest** — Matches your test framework with 13 comprehensive tests
- **Monorepo structure** — Properly placed in packages/squad-cli/
- **Changeset included** — For independent CLI versioning

## Tests

All 96 tests pass:
- 13 new rework rate tests ✅
- 83+ existing tests ✅

## Related Issues

Closes tamirdresher_microsoft/tamresearch1#581
Replaces #381 (JS/CommonJS implementation)
```

---

## Verification Checklist

Before pushing, verify:

- [ ] Patch applied cleanly (no merge conflicts)
- [ ] Build passes: `npm run build` ✅
- [ ] Tests pass: `npm run test` ✅  
- [ ] New files in correct locations:
  - [ ] `packages/squad-cli/src/cli/core/rework.ts`
  - [ ] `packages/squad-cli/src/cli/commands/rework.ts`
  - [ ] `test/rework-rate.test.ts`
  - [ ] `packages/squad-cli/templates/skills/rework-rate/SKILL.md`
  - [ ] `.changeset/add-rework-rate-command.md`
- [ ] CLI help shows rework command: `npm run dev -- rework --help`
- [ ] PR targets `dev` branch (not `main`) ✅

---

## Troubleshooting

### Patch Apply Fails

If `git am` fails:

1. Check branch: `git branch` should show `dev`
2. Fetch latest: `git fetch origin dev:dev`
3. Try again: `git am < ../rework-rate-581/full.patch`

### Build Fails

If `npm run build` fails:

1. Ensure Node.js 18+ installed
2. Clear node_modules: `rm -rf node_modules && npm install`
3. Try build again

### Tests Fail

If tests fail:

1. Ensure Vitest is installed: `npm list vitest`
2. Run tests with verbose: `npm run test -- --reporter=verbose`
3. Check for TypeScript errors: `npx tsc --noEmit`

---

## Timeline

- ⏱️ Patch ready: Now
- ⏱️ Expected deployment: Within 24 hours
- ⏱️ Review/merge at bradygaster/squad: Depends on their review cycle

---

## Contacts

- **Issue:** tamirdresher_microsoft/tamresearch1#581
- **Feature:** Rework Rate (5th DORA metric)
- **Original PR:** bradygaster/squad#381 (to be superseded)
- **Related work:** Data, Ralph (contributed to original implementation)

---

## Questions?

If issues arise:
1. Check this deployment guide for troubleshooting
2. Review the patch contents: `git show` after applying
3. Check test output: `npm run test -- rework-rate`
4. Verify TypeScript: `npx tsc --noEmit`
