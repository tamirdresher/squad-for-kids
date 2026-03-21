#!/usr/bin/env pwsh
# .squad/scripts/setup-area-labels.ps1
# Creates area:* GitHub labels for monorepo routing.
# Usage: .\setup-area-labels.ps1 [-Repo <owner/repo>] [-DryRun]
# Part of issue #1153 implementation.

param(
    [string]$Repo = "tamirdresher_microsoft/tamresearch1",
    [switch]$DryRun
)

$labels = @(
    @{ name="area:platform";          description="Work in src/platform/ — B'Elanna primary";         color="0075ca" },
    @{ name="area:api";               description="Work in src/api/ — Data primary";                  color="0075ca" },
    @{ name="area:frontend";          description="Work in src/frontend/ — TBD primary";              color="0075ca" },
    @{ name="area:shared";            description="Cross-cutting shared code — Picard escalation";    color="0075ca" },
    @{ name="area:infra";             description="Infrastructure, CI/CD, deployment — B'Elanna";     color="0075ca" },
    @{ name="area:docs";              description="Documentation changes — Seven primary";             color="0075ca" },
    @{ name="area:platform:infra";    description="src/platform/infra/ — B'Elanna primary";           color="0075ca" },
    @{ name="area:platform:security"; description="Auth + secrets in platform — Worf primary";        color="0075ca" },
    @{ name="area:api:breaking";      description="Breaking API changes — Data + Picard review";      color="0075ca" },
    @{ name="area:api:security";      description="Auth middleware in API — Worf primary";            color="0075ca" }
)

foreach ($label in $labels) {
    if ($DryRun) {
        Write-Host "[DRY RUN] Would create: $($label.name)"
        continue
    }

    $result = gh label create $label.name `
        --description $label.description `
        --color $label.color `
        --repo $Repo 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Created: $($label.name)"
    } else {
        # Label may already exist — try force
        $result2 = gh label create $label.name `
            --description $label.description `
            --color $label.color `
            --repo $Repo `
            --force 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "🔄 Updated: $($label.name)"
        } else {
            Write-Warning "❌ Failed: $($label.name) — $result"
        }
    }
}

Write-Host "`nDone. See: https://github.com/$Repo/labels"
