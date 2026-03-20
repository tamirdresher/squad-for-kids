#Requires -Version 7.0
<#
.SYNOPSIS
    Pester tests for scripts/find-squad-config.ps1

.DESCRIPTION
    Covers the four required scenarios:
      1. Root-level path returns repo root .squad/
      2. Path inside an area with .squad/ returns area config
      3. Path in nested subdir bubbles up to nearest .squad/
      4. Missing .squad-context.md returns null gracefully
#>

BeforeAll {
    # Dot-source the script to load functions (not as a module)
    . (Join-Path $PSScriptRoot '../scripts/find-squad-config.ps1')
}

Describe 'Find-SquadConfig' {

    BeforeAll {
        # Create a temp directory tree that simulates a monorepo
        $script:TestRoot = Join-Path ([IO.Path]::GetTempPath()) "squad-test-$([System.Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $script:TestRoot -ItemType Directory -Force

        # Initialize a bare git repo so git rev-parse works
        git -C $script:TestRoot init -q 2>&1 | Out-Null

        # Repo root .squad/
        $null = New-Item -Path (Join-Path $script:TestRoot '.squad') -ItemType Directory -Force

        # Area config: src/platform/.squad/
        $null = New-Item -Path (Join-Path $script:TestRoot 'src/platform/.squad') -ItemType Directory -Force

        # Nested dir inside platform area (no .squad/ of its own)
        $null = New-Item -Path (Join-Path $script:TestRoot 'src/platform/auth/handlers') -ItemType Directory -Force

        # A top-level dir with no .squad/
        $null = New-Item -Path (Join-Path $script:TestRoot 'docs') -ItemType Directory -Force

        # A file in the area
        $null = New-Item -Path (Join-Path $script:TestRoot 'src/platform/auth/handler.go') -ItemType File -Force
    }

    AfterAll {
        if (Test-Path $script:TestRoot) {
            Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Root-level path returns repo root .squad/' {
        It 'Returns repo root config when starting from repo root' {
            $result = Find-SquadConfig -Path $script:TestRoot -RepoRoot $script:TestRoot
            $result | Should -Not -BeNullOrEmpty
            $result.ConfigRoot | Should -Be $script:TestRoot
            $result.IsAreaConfig | Should -Be $false
            $result.AreaName | Should -Be ''
            $result.ConfigPath | Should -Be (Join-Path $script:TestRoot '.squad')
        }

        It 'Returns repo root config when starting from a top-level dir with no .squad/' {
            $docsPath = Join-Path $script:TestRoot 'docs'
            $result = Find-SquadConfig -Path $docsPath -RepoRoot $script:TestRoot
            $result | Should -Not -BeNullOrEmpty
            $result.IsAreaConfig | Should -Be $false
            $result.ConfigRoot | Should -Be $script:TestRoot
            $result.AreaName | Should -Be ''
        }
    }

    Context 'Path inside an area with .squad/ returns area config' {
        It 'Returns area config when Path is the area root itself' {
            $areaRoot = Join-Path $script:TestRoot 'src/platform'
            $result = Find-SquadConfig -Path $areaRoot -RepoRoot $script:TestRoot
            $result | Should -Not -BeNullOrEmpty
            $result.IsAreaConfig | Should -Be $true
            $result.ConfigRoot | Should -Be $areaRoot
            $result.AreaName | Should -Be 'src/platform'
            $result.ConfigPath | Should -Be (Join-Path $areaRoot '.squad')
        }

        It 'Returns area config when Path is a file directly inside area root' {
            $filePath = Join-Path $script:TestRoot 'src/platform/auth/handler.go'
            $result = Find-SquadConfig -Path $filePath -RepoRoot $script:TestRoot
            $result | Should -Not -BeNullOrEmpty
            $result.IsAreaConfig | Should -Be $true
            $result.ConfigRoot | Should -Be (Join-Path $script:TestRoot 'src/platform')
        }
    }

    Context 'Path in nested subdir bubbles up to nearest .squad/' {
        It 'Bubbles up from deeply nested directory to the nearest area .squad/' {
            $deepPath = Join-Path $script:TestRoot 'src/platform/auth/handlers'
            $result = Find-SquadConfig -Path $deepPath -RepoRoot $script:TestRoot
            $result | Should -Not -BeNullOrEmpty
            $result.IsAreaConfig | Should -Be $true
            # Should find src/platform/.squad/, not repo root
            $result.ConfigRoot | Should -Be (Join-Path $script:TestRoot 'src/platform')
            $result.AreaName | Should -Be 'src/platform'
        }
    }

    Context 'AreaName is a forward-slash relative path' {
        It 'Uses forward slashes in AreaName regardless of OS path separator' {
            $areaRoot = Join-Path $script:TestRoot 'src/platform'
            $result = Find-SquadConfig -Path $areaRoot -RepoRoot $script:TestRoot
            $result.AreaName | Should -Not -Match '\\'
            $result.AreaName | Should -Be 'src/platform'
        }
    }
}

Describe 'Get-SquadContext' {

    BeforeAll {
        $script:CtxRoot = Join-Path ([IO.Path]::GetTempPath()) "squad-ctx-test-$([System.Guid]::NewGuid().ToString('N'))"
        $null = New-Item -Path $script:CtxRoot -ItemType Directory -Force
        git -C $script:CtxRoot init -q 2>&1 | Out-Null

        # Repo root .squad/ with a context file
        $rootSquad = Join-Path $script:CtxRoot '.squad'
        $null = New-Item -Path $rootSquad -ItemType Directory -Force

        $rootContextContent = @"
---
title: Root Squad Context
owner: Picard
---

# Squad Context — Root

## Owner
- **Primary agent:** Picard

## Purpose
Root context for the repository.

## Area Label
``area:root``
"@
        Set-Content -Path (Join-Path $rootSquad '.squad-context.md') -Value $rootContextContent -Encoding UTF8

        # Area with NO context file
        $areaNoCtx = Join-Path $script:CtxRoot 'src/no-context'
        $null = New-Item -Path (Join-Path $areaNoCtx '.squad') -ItemType Directory -Force

        # A plain subdir (no .squad/ of its own)
        $null = New-Item -Path (Join-Path $script:CtxRoot 'docs') -ItemType Directory -Force
    }

    AfterAll {
        if (Test-Path $script:CtxRoot) {
            Remove-Item -Path $script:CtxRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Missing .squad-context.md returns null gracefully' {
        It 'Returns null when area .squad/ exists but has no .squad-context.md' {
            $areaPath = Join-Path $script:CtxRoot 'src/no-context'
            $result = Get-SquadContext -Path $areaPath -RepoRoot $script:CtxRoot
            $result | Should -BeNullOrEmpty
        }

        It 'Returns null for -Property when context file is missing' {
            $areaPath = Join-Path $script:CtxRoot 'src/no-context'
            $result = Get-SquadContext -Path $areaPath -RepoRoot $script:CtxRoot -Property 'owner'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Reads and parses .squad-context.md from found config' {
        It 'Returns a non-null object when .squad-context.md exists' {
            $result = Get-SquadContext -Path $script:CtxRoot -RepoRoot $script:CtxRoot
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Parses YAML frontmatter properties' {
            $result = Get-SquadContext -Path $script:CtxRoot -RepoRoot $script:CtxRoot
            $result.title | Should -Be 'Root Squad Context'
            $result.owner | Should -Be 'Picard'
        }

        It 'Returns specific property when -Property is specified' {
            $result = Get-SquadContext -Path $script:CtxRoot -RepoRoot $script:CtxRoot -Property 'title'
            $result | Should -Be 'Root Squad Context'
        }

        It 'Returns null for -Property that does not exist' {
            $result = Get-SquadContext -Path $script:CtxRoot -RepoRoot $script:CtxRoot -Property 'nonexistent_field'
            $result | Should -BeNullOrEmpty
        }

        It 'Populates IsAreaConfig and AreaName on the returned object' {
            $result = Get-SquadContext -Path $script:CtxRoot -RepoRoot $script:CtxRoot
            $result.IsAreaConfig | Should -Be $false
            $result.AreaName | Should -Be ''
        }
    }
}
