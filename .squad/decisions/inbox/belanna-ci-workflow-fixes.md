# CI Workflow Fixes - Windows Self-Hosted Runner Compatibility

**Date:** 2025-01-21  
**Author:** B'Elanna (Infrastructure Expert)  
**Context:** Issues #188, #189 — CI workflow failures

## Decision

GitHub Actions workflows running on self-hosted Windows runners require explicit permissions blocks and defensive checks for directory existence when using Actions designed for Linux/bash environments.

## Implementation Pattern

### 1. Explicit Permissions
Always declare permissions at workflow or job level:
```yaml
permissions:
  contents: write      # For git operations (tags, commits)
  pages: write         # For GitHub Pages deployment
  id-token: write      # For OIDC authentication to Pages
```

### 2. Windows-Safe Directory Checks
Before using GitHub Actions that expect bash (like `upload-pages-artifact`):
```yaml
- name: Build docs site
  id: build
  run: |
    # ... build logic ...
    if (Test-Path "_site") {
      "skip=false" >> $env:GITHUB_OUTPUT
    } else {
      "skip=true" >> $env:GITHUB_OUTPUT
    }

- name: Upload Pages artifact
  if: steps.build.outputs.skip != 'true'
  uses: actions/upload-pages-artifact@v3
```

### 3. Cross-Job Communication
Use job outputs to propagate build results:
```yaml
jobs:
  build:
    outputs:
      skip: ${{ steps.build.outputs.skip }}
  deploy:
    needs: build
    if: needs.build.outputs.skip != 'true'
```

## Rationale

- Self-hosted runners don't have default token permissions
- Actions like `upload-pages-artifact` internally use bash scripts incompatible with Windows
- Defensive checks prevent workflow failures when expected outputs don't exist
- Keeps workflows on self-hosted runner (no migration needed)

## Files Modified
- `.github/workflows/squad-release.yml`
- `.github/workflows/squad-docs.yml`

## References
- PR #190
- Issues #188, #189
