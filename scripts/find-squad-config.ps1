#Requires -Version 7.0
<#
.SYNOPSIS
    Discovers the active Squad config for a given file or directory by walking up the directory tree.

.DESCRIPTION
    Implements monorepo area discovery as described in .squad/docs/monorepo-support.md.
    Each sub-area of a monorepo can have its own .squad/ config directory.
    This script walks up from the target path to the repo root, finding the nearest config.

.NOTES
    Issue: #1146
    Branch: squad/1146-find-squad-config-TAMIRDRESHER
#>

<#
.SYNOPSIS
    Finds the active Squad config directory for a given path.

.DESCRIPTION
    Walks up from -Path toward -RepoRoot. At each level:
      1. Checks for a .squad/ directory (full area config)
      2. If none found all the way to repo root, returns the repo root .squad/

.PARAMETER Path
    The file or directory to start discovery from. Defaults to current directory.

.PARAMETER RepoRoot
    The repository root. Defaults to the output of `git rev-parse --show-toplevel`.

.OUTPUTS
    PSObject with:
      - ConfigPath   : Full path to the .squad/ directory
      - ConfigRoot   : Directory containing the .squad/ directory
      - IsAreaConfig : $true if the config is not the repo root config
      - AreaName     : Relative path from RepoRoot to ConfigRoot (empty string for root)
#>
function Find-SquadConfig {
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).Path,
        [string] $RepoRoot = ''
    )

    # Resolve RepoRoot
    if (-not $RepoRoot) {
        $gitOutput = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Could not determine git repo root. Are you inside a git repository? ($gitOutput)"
        }
        $RepoRoot = $gitOutput.Trim()
    }

    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path.TrimEnd([IO.Path]::DirectorySeparatorChar)

    # Resolve the starting directory
    if (Test-Path -LiteralPath $Path) {
        $resolved = (Resolve-Path -LiteralPath $Path).Path
        # If Path is a file, start from its parent directory
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            $current = Split-Path $resolved -Parent
        } else {
            $current = $resolved
        }
    } else {
        # Path doesn't exist — use its parent if possible, otherwise fail
        $parent = Split-Path $Path -Parent
        if ($parent -and (Test-Path -LiteralPath $parent)) {
            $current = (Resolve-Path -LiteralPath $parent).Path
        } else {
            throw "Path not found and cannot resolve parent: $Path"
        }
    }

    $current = $current.TrimEnd([IO.Path]::DirectorySeparatorChar)

    # Walk up from $current toward $RepoRoot
    while ($true) {
        $squadDir = Join-Path $current '.squad'
        if (Test-Path -LiteralPath $squadDir -PathType Container) {
            # Found a .squad/ directory — determine if it's the root or an area config
            $isRoot = ($current -eq $RepoRoot)
            $areaName = if ($isRoot) {
                ''
            } else {
                # Compute relative path from repo root
                $rel = $current.Substring($RepoRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar)
                $rel -replace [regex]::Escape([IO.Path]::DirectorySeparatorChar), '/'
            }

            return [PSCustomObject]@{
                ConfigPath   = $squadDir
                ConfigRoot   = $current
                IsAreaConfig = -not $isRoot
                AreaName     = $areaName
            }
        }

        # Stop if we've reached the repo root (repo root .squad/ not found yet — unusual, but handle it)
        if ($current -eq $RepoRoot) {
            break
        }

        # Walk up one level
        $parent = Split-Path $current -Parent
        if (-not $parent -or $parent -eq $current) {
            # Reached filesystem root without finding repo root — stop
            break
        }

        # Don't walk above the repo root
        if ($parent.Length -lt $RepoRoot.Length) {
            $current = $RepoRoot
        } else {
            $current = $parent.TrimEnd([IO.Path]::DirectorySeparatorChar)
        }
    }

    # Fallback: return repo root .squad/ even if it doesn't exist (callers can check)
    $rootSquadDir = Join-Path $RepoRoot '.squad'
    return [PSCustomObject]@{
        ConfigPath   = $rootSquadDir
        ConfigRoot   = $RepoRoot
        IsAreaConfig = $false
        AreaName     = ''
    }
}

<#
.SYNOPSIS
    Reads Squad context for the given path from the nearest .squad-context.md file.

.DESCRIPTION
    Locates the active Squad config via Find-SquadConfig, then reads .squad-context.md
    from that config directory. Parses YAML frontmatter (if present) and returns a PSObject.

.PARAMETER Path
    The file or directory to start context discovery from. Defaults to current directory.

.PARAMETER Property
    If specified, returns only the value of this property from the parsed context.

.OUTPUTS
    PSObject with parsed context properties, or the value of -Property if specified.
    Returns $null if .squad-context.md is not found.
#>
function Get-SquadContext {
    [CmdletBinding()]
    param(
        [string] $Path = (Get-Location).Path,
        [string] $Property = '',
        [string] $RepoRoot = ''
    )

    $findParams = @{ Path = $Path }
    if ($RepoRoot) { $findParams['RepoRoot'] = $RepoRoot }
    $config = Find-SquadConfig @findParams

    $contextFile = Join-Path $config.ConfigPath '.squad-context.md'
    if (-not (Test-Path -LiteralPath $contextFile -PathType Leaf)) {
        if ($Property) {
            return $null
        }
        return $null
    }

    $content = Get-Content -LiteralPath $contextFile -Raw

    # Parse YAML frontmatter (between --- delimiters) if present
    $frontmatter = @{}
    $body = $content

    if ($content -match '(?s)^---\s*\r?\n(.+?)\r?\n---\s*\r?\n?(.*)$') {
        $yamlBlock = $Matches[1]
        $body = $Matches[2]

        # Simple YAML key: value parser (no nested objects or arrays)
        foreach ($line in ($yamlBlock -split '\r?\n')) {
            if ($line -match '^\s*([^#][^:]*?)\s*:\s*(.+?)\s*$') {
                $key = $Matches[1].Trim()
                $val = $Matches[2].Trim().Trim('"').Trim("'")
                $frontmatter[$key] = $val
            }
        }
    }

    # Also parse Markdown heading-style fields from body (## Key\n value)
    $sections = @{}
    $currentSection = $null
    $sectionLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in ($body -split '\r?\n')) {
        if ($line -match '^##\s+(.+)$') {
            if ($currentSection) {
                $sections[$currentSection] = ($sectionLines -join "`n").Trim()
            }
            $currentSection = $Matches[1].Trim()
            $sectionLines = [System.Collections.Generic.List[string]]::new()
        } elseif ($currentSection) {
            $sectionLines.Add($line)
        }
    }
    if ($currentSection) {
        $sections[$currentSection] = ($sectionLines -join "`n").Trim()
    }

    # Build result object: frontmatter wins over section content for same keys
    $result = [PSCustomObject]@{
        ConfigPath  = $config.ConfigPath
        ConfigRoot  = $config.ConfigRoot
        IsAreaConfig = $config.IsAreaConfig
        AreaName    = $config.AreaName
        RawContent  = $content
        Body        = $body
        Sections    = $sections
    }

    # Merge frontmatter properties onto result
    foreach ($key in $frontmatter.Keys) {
        $result | Add-Member -NotePropertyName $key -NotePropertyValue $frontmatter[$key] -Force
    }

    # Merge section properties (only if not already set by frontmatter)
    foreach ($key in $sections.Keys) {
        $safeName = $key -replace '\s+', '_' -replace '[^a-zA-Z0-9_]', ''
        if (-not ($result.PSObject.Properties[$safeName])) {
            $result | Add-Member -NotePropertyName $safeName -NotePropertyValue $sections[$key] -Force
        }
    }

    if ($Property) {
        if ($result.PSObject.Properties[$Property]) {
            return $result.$Property
        }
        return $null
    }

    return $result
}

# Export both functions (only valid when loaded as a module, not when dot-sourced)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript' -and $MyInvocation.ScriptName -ne '') {
    # Script is being dot-sourced or run directly — skip Export-ModuleMember
} else {
    try {
        Export-ModuleMember -Function Find-SquadConfig, Get-SquadContext
    } catch {
        # Silently ignore: script was dot-sourced, not imported as a module
    }
}
