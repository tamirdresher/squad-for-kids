# Wiki Helper Functions for Squad
# Source: .squad/skills/wiki-write/wiki-helper.ps1
# Usage: . .squad/skills/wiki-write/wiki-helper.ps1

$script:WikiRepoUrl = "https://github.com/tamirdresher_microsoft/tamresearch1.wiki.git"
$script:WikiDir = "$env:TEMP\tamresearch1-wiki"

function Initialize-Wiki {
    <#
    .SYNOPSIS
    Clone or pull the wiki repo to a local working directory.
    #>
    $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"

    if (Test-Path $script:WikiDir) {
        Push-Location $script:WikiDir
        git pull --quiet 2>&1 | Out-Null
        Pop-Location
        Write-Host "Wiki updated at $script:WikiDir"
    } else {
        git clone $script:WikiRepoUrl $script:WikiDir --quiet 2>&1
        if ($LASTEXITCODE -ne 0) {
            New-Item -ItemType Directory -Path $script:WikiDir -Force | Out-Null
            Push-Location $script:WikiDir
            git init --quiet
            git remote add origin $script:WikiRepoUrl
            Pop-Location
        }
        Write-Host "Wiki cloned to $script:WikiDir"
    }
}

function Get-WikiPage {
    <#
    .SYNOPSIS
    Read a wiki page by name.
    .PARAMETER PageName
    Page name without .md extension (e.g., "ADC-Research").
    #>
    param([Parameter(Mandatory)][string]$PageName)

    Initialize-Wiki
    $filePath = Join-Path $script:WikiDir "$PageName.md"

    if (Test-Path $filePath) {
        Get-Content $filePath -Raw
    } else {
        Write-Warning "Wiki page '$PageName' not found."
        return $null
    }
}

function Update-WikiPage {
    <#
    .SYNOPSIS
    Create or overwrite a wiki page and push.
    .PARAMETER PageName
    Page name without .md extension.
    .PARAMETER Content
    Markdown content for the page.
    .PARAMETER CommitMessage
    Git commit message.
    #>
    param(
        [Parameter(Mandatory)][string]$PageName,
        [Parameter(Mandatory)][string]$Content,
        [string]$CommitMessage = "Update: $PageName"
    )

    $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
    Initialize-Wiki

    $filePath = Join-Path $script:WikiDir "$PageName.md"
    $Content | Out-File -FilePath $filePath -Encoding utf8 -Force

    Push-Location $script:WikiDir
    git add "$PageName.md"
    git commit -m "$CommitMessage`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" --quiet 2>&1
    git push --quiet 2>&1
    Pop-Location

    Write-Host "Wiki page '$PageName' updated and pushed."
}

function Append-WikiPage {
    <#
    .SYNOPSIS
    Append content to an existing wiki page and push.
    .PARAMETER PageName
    Page name without .md extension.
    .PARAMETER Content
    Markdown content to append.
    .PARAMETER CommitMessage
    Git commit message.
    #>
    param(
        [Parameter(Mandatory)][string]$PageName,
        [Parameter(Mandatory)][string]$Content,
        [string]$CommitMessage = "Append to: $PageName"
    )

    $env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
    Initialize-Wiki

    $filePath = Join-Path $script:WikiDir "$PageName.md"
    if (-not (Test-Path $filePath)) {
        Write-Warning "Wiki page '$PageName' not found. Use Update-WikiPage to create it."
        return
    }

    Add-Content -Path $filePath -Value "`n$Content" -Encoding utf8

    Push-Location $script:WikiDir
    git add "$PageName.md"
    git commit -m "$CommitMessage`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" --quiet 2>&1
    git push --quiet 2>&1
    Pop-Location

    Write-Host "Content appended to wiki page '$PageName' and pushed."
}

function Get-WikiPages {
    <#
    .SYNOPSIS
    List all wiki pages.
    #>
    Initialize-Wiki
    Get-ChildItem -Path $script:WikiDir -Filter "*.md" | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.BaseName
            Size = "{0:N1} KB" -f ($_.Length / 1KB)
            Modified = $_.LastWriteTime.ToString("yyyy-MM-dd")
        }
    }
}
