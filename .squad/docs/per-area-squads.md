# Per-Area Squad Configuration for Monorepos

This document describes how to use per-area `.squads/` directories to manage squad configurations in large monorepo setups.

## Overview

In monorepos with multiple domains or subsystems, different areas may need different squad configurations while still inheriting from the root team structure. The `.squads/` pattern enables area-specific routing, team assignments, and conventions.

## Directory Structure

```
repo-root/
├── .squad/                      # Root squad configuration
│   ├── team.md
│   ├── routing.md
│   ├── schemas/
│   │   └── squads-config.schema.json
│   └── docs/
│       └── per-area-squads.md
│
└── src/
    ├── platform/                # Area 1
    │   ├── .squads/
    │   │   └── config.json      # Area-specific config
    │   ├── README.md
    │   └── services/
    │
    └── api/                     # Area 2
        ├── .squads/
        │   └── config.json
        └── handlers/
```

## Configuration Schema

Each area's `.squads/config.json` must conform to the JSON schema at `.squad/schemas/squads-config.schema.json`.

### Minimal Example

```json
{
  "version": 1,
  "area": {
    "name": "platform",
    "path": "src/platform",
    "owner": "B'Elanna"
  }
}
```

### Complete Example

See `examples/platform-area/.squads/config.json` for a full-featured example.

## Schema Fields

### Required Fields

- **`version`** (integer): Must be `1`
- **`area.name`** (string): Lowercase identifier (e.g., `platform`, `api-gateway`)
- **`area.path`** (string): Relative path from repo root

### Optional Fields

#### Area Metadata

- **`area.displayName`**: Human-readable name
- **`area.description`**: Brief purpose statement
- **`area.owner`**: Primary responsible party

#### Team Configuration

```json
{
  "team": {
    "inheritsRoot": true,
    "members": [
      {
        "name": "B'Elanna",
        "role": "Infrastructure Lead",
        "areaSpecialization": "K8s orchestration, CI/CD"
      }
    ]
  }
}
```

- **`inheritsRoot`**: Whether to inherit root squad roster (default: true)
- **`members`**: Area-specific team assignments

#### Routing Rules

Routing rules are **additive** to root routing — they extend, not replace.

```json
{
  "routing": {
    "defaultOwner": "B'Elanna",
    "labels": {
      "area:platform:infra": {
        "assignTo": "B'Elanna"
      },
      "breaking-change": {
        "requiresGate": ["Picard", "B'Elanna"]
      }
    },
    "paths": {
      "helm/": {
        "owner": "B'Elanna",
        "requiresReview": ["Worf"]
      }
    },
    "filePatterns": {
      "**/*.tf": "B'Elanna",
      "**/secrets.yaml": "Worf"
    }
  }
}
```

**Important**: HQ security gates (Worf, Crusher) **cannot be overridden** by area routing.

#### Capabilities

Declare machine capabilities required for work in this area:

```json
{
  "capabilities": {
    "required": ["emu-gh", "browser"],
    "preferred": ["azure-speech"]
  }
}
```

Valid capabilities: `whatsapp`, `browser`, `gpu`, `personal-gh`, `emu-gh`, `teams-mcp`, `onedrive`, `azure-speech`

#### Conventions

Document area-specific development practices:

```json
{
  "conventions": {
    "codeStyle": "Go with gofmt",
    "testingFramework": "Go testing + testify",
    "ciWorkflow": "platform-ci.yml",
    "customRules": [
      "All Helm charts must have schema validation",
      "No hardcoded credentials"
    ]
  }
}
```

#### Context

Link to key documentation and files:

```json
{
  "context": {
    "readme": "src/platform/README.md",
    "architecture": "docs/platform-arch.md",
    "keyFiles": [
      "helm/values.yaml",
      "terraform/main.tf"
    ]
  }
}
```

## Validation

All `.squads/config.json` files are validated on every push and PR.

### Local Validation

```powershell
# Validate all configs in repository
./scripts/validate-squads-config.ps1

# Validate a specific config
./scripts/validate-squads-config.ps1 -Path src/platform/.squads/config.json

# Quiet mode (errors only)
./scripts/validate-squads-config.ps1 -Quiet
```

### CI Validation

The workflow `.github/workflows/validate-squad-configs.yml` runs automatically when:
- Any `.squads/config.json` file changes
- The schema changes
- The validation script changes

## Routing Resolution

When an issue or PR affects a file in an area with a `.squads/` config:

1. **Discover area**: Walk up from file path to find nearest `.squads/config.json`
2. **Load config**: Parse and validate the config
3. **Merge routing**: Combine area routing with root routing (area rules take precedence)
4. **Apply labels**: Match against `routing.labels` table
5. **Check paths**: Match file paths against `routing.paths` and `routing.filePatterns`
6. **Enforce gates**: Apply required reviewers (HQ gates cannot be removed)

### Discovery Script

```powershell
# Which area owns this file?
./scripts/find-squad-config.ps1 -Path "src/platform/auth/handler.go" -ShowArea

# List all registered areas
./scripts/find-squad-config.ps1 -All
```

## Best Practices

### 1. Start Minimal

Begin with just area metadata and expand as needed:

```json
{
  "version": 1,
  "area": {
    "name": "my-area",
    "path": "src/my-area",
    "owner": "Agent"
  }
}
```

### 2. Inherit Root Team

Unless you have area-specific agents, set `team.inheritsRoot: true` and use `members` to highlight key assignments.

### 3. Document Conventions

Use `conventions.customRules` to capture tribal knowledge:

```json
{
  "conventions": {
    "customRules": [
      "Database migrations require DBA review",
      "API changes need OpenAPI spec update",
      "Performance-sensitive code needs benchmark"
    ]
  }
}
```

### 4. Link Key Context

Help agents understand the area quickly:

```json
{
  "context": {
    "readme": "README.md",
    "keyFiles": [
      "schema.sql",
      "api-spec.yaml",
      "config/default.json"
    ]
  }
}
```

### 5. Use Path Routing for Subfolders

Fine-grained control for different subfolders:

```json
{
  "routing": {
    "paths": {
      "migrations/": {
        "owner": "Data",
        "requiresReview": ["DBA-team"]
      },
      "public-api/": {
        "requiresReview": ["API-design-team", "Worf"]
      }
    }
  }
}
```

## Migration Guide

### Step 1: Create Schema

Already done — schema is at `.squad/schemas/squads-config.schema.json`.

### Step 2: Identify Areas

Map your repository structure:

```
src/
├── platform/     → "platform" area
├── api/          → "api" area
├── frontend/     → "frontend" area
└── shared/       → (no area, uses root routing)
```

### Step 3: Create Configs

For each area:

```bash
mkdir -p src/platform/.squads
cat > src/platform/.squads/config.json << 'EOF'
{
  "version": 1,
  "area": {
    "name": "platform",
    "path": "src/platform",
    "owner": "B'Elanna"
  }
}
EOF
```

### Step 4: Validate

```powershell
./scripts/validate-squads-config.ps1
```

### Step 5: Test Routing

Open an issue labeled `area:platform` and verify correct routing.

## Troubleshooting

### Schema Validation Fails

**Error**: "Missing required field: area.name"

**Fix**: Ensure your config has both `version` and `area` at the top level:

```json
{
  "version": 1,
  "area": { ... }
}
```

### Invalid Label Format

**Error**: "Invalid label format: Area:Platform"

**Fix**: Labels must be lowercase with hyphens:
- ❌ `Area:Platform`
- ✅ `area:platform`

### Routing Not Applied

Check the following:
1. Config file is at `.squads/config.json` (not `squads/config.json`)
2. Area path matches actual directory
3. Issue has appropriate `area:*` label
4. Validation passes (`./scripts/validate-squads-config.ps1`)

### HQ Gate Overridden

**Issue**: Trying to remove Worf from security review

**Remember**: HQ security gates (Worf, Crusher) are **mandatory** and cannot be removed by area configs. Area routing can only **add** reviewers.

## Examples

See `examples/platform-area/.squads/config.json` for a reference implementation.

## Related Documentation

- [Work Routing](.squad/routing.md) - Root routing rules
- [Monorepo Support](.squad/docs/monorepo-support.md) - Full monorepo guide (if exists)
- [Machine Capabilities](.squad/routing.md#machine-capability-routing) - Capability requirements

## Schema Reference

Full JSON schema: `.squad/schemas/squads-config.schema.json`

Online schema: `https://squad.dev/schemas/squads-config.schema.json` (when published)
