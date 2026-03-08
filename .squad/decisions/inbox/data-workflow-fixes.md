# Decision: GitHub Actions Workflow Bug Fixes

**Date:** 2026-03-13  
**Agent:** Data  
**Issues:** #170, #173, #174  
**PR:** #176

## Context

Two categories of workflow failures were blocking Squad automation:
1. Guard workflow returning 403 errors when checking PR file changes
2. Member name matching failures for team members with special characters (apostrophes)

## Decisions

### 1. Explicit Permissions Declaration for Guard Workflow

**Decision:** Add explicit `permissions:` section to `squad-main-guard.yml` workflow.

**Rationale:**
- GitHub Actions default permissions are restrictive
- API calls like `github.rest.pulls.listFiles()` require explicit permission grants
- Even though workflow runs in-repo, it doesn't automatically inherit all access

**Implementation:**
```yaml
permissions:
  pull-requests: read
  contents: read
```

**Impact:** Guard workflow can now successfully read PR file lists without 403 errors.

### 2. Name Normalization Function for Label Matching

**Decision:** Implement consistent name normalization across all workflows that parse team.md by stripping non-alphanumeric characters.

**Rationale:**
- Team member display names can contain special characters (apostrophes, unicode, hyphens, etc.)
- GitHub labels are lowercase and typically alphanumeric
- Case-insensitive comparison alone is insufficient
- Need deterministic transformation from display name → label → back to display name

**Implementation:**
```javascript
const normalize = (s) => s.toLowerCase().replace(/[^a-z0-9]/g, '');
```

**Applied to:**
- `squad-issue-assign.yml` - member lookup when label applied
- `sync-squad-labels.yml` - label generation from team roster
- `squad-triage.yml` - member list display and assignment

**Example:**
- Display name: "B'Elanna"
- Label: `squad:belanna`
- Normalized: "belanna" (matches both)

**Impact:** Issues labeled `squad:belanna` now correctly route to "B'Elanna" team member.

## Alternatives Considered

### For Bug 1 (Permissions)
- **Use GITHUB_TOKEN with elevated permissions:** Rejected because default token should be sufficient; explicit declaration is better than token escalation
- **Switch to PAT:** Rejected because this is unnecessary complexity for read-only operations

### For Bug 2 (Name Matching)
- **Require team.md names to be alphanumeric only:** Rejected because it restricts naming conventions (Star Trek characters have apostrophes)
- **URL-encode special characters in labels:** Rejected because GitHub labels don't support URL encoding, and it would make labels unreadable
- **Strip only apostrophes:** Rejected because it wouldn't handle other special characters (hyphens, accents, unicode) that might appear in names

## Future Considerations

1. **Validation on team.md changes:** Could add a workflow that validates all team member names normalize to unique label names (no collisions)
2. **Centralized normalize function:** If workflows grow more complex, extract normalize() into a shared GitHub Action
3. **Monitor for other permission issues:** Guard workflow fix suggests other workflows may have similar implicit permission assumptions

## References

- Issue #170: Member name matching with apostrophes
- Issue #173: Guard workflow 403 on pulls.listFiles()
- Issue #174: Duplicate of #173
- PR #176: Fix workflow bugs: guard permissions and member name matching
