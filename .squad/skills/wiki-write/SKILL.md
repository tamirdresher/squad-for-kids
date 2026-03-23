# Wiki Write Skill

Write to the Squad wiki (long-term memory) from any agent.

## When to Use
- After completing a research investigation
- After a major test session with new findings
- After an architecture decision
- When discovering reusable patterns or workarounds

## How to Write

### Standard: Clone, edit, push
```powershell
$env:GH_CONFIG_DIR = "$env:APPDATA\GitHub CLI"
$wikiDir = "$env:TEMP\tamresearch1-wiki"

# Clone (or pull if exists)
if (Test-Path $wikiDir) {
    cd $wikiDir; git pull
} else {
    git clone https://github.com/tamirdresher_microsoft/tamresearch1.wiki.git $wikiDir
    cd $wikiDir
}

# Edit or create page
$content = @"
# Page Title
Content here...
"@
$content | Out-File -FilePath "Page-Name.md" -Encoding utf8

# Push
git add -A
git commit -m "Update: Page-Name — <brief description>"
git push
```

### Quick: Using wiki-helper.ps1
```powershell
. .squad/skills/wiki-write/wiki-helper.ps1

# Update a single page
Update-WikiPage -PageName "Test-Results" -Content $markdownContent -CommitMessage "Add March test results"

# Append to a page
Append-WikiPage -PageName "Test-Results" -Content $newSection -CommitMessage "Add new test run"

# Read a page
$page = Get-WikiPage -PageName "ADC-Research"
```

## Naming Convention
- Use PascalCase with hyphens for page names: `ADC-Research.md`, `Test-Results.md`
- Use `[[Page Name]]` for wiki internal links (GitHub wiki auto-links these)
- Date entries with ISO format: `2026-03-23`

## Wiki Pages Index
| Page | Content |
|------|---------|
| Home | Landing page with quick links |
| ADC-Research | ADC MCP API findings, tool scorecard |
| Architecture-Patterns | Deployment patterns (ADC, AKS, DevBox) |
| Test-Results | API and integration test logs |
| Agent-Identity | Non-human identity setup status |
| Tool-Catalog | MCP servers, skills inventory |
| Decisions-Index | Key decisions from decisions.md |

## What NOT to Put in Wiki
- Secrets, API keys, tokens
- Large binary files
- Ephemeral status (use issues/todos instead)
- Raw session logs (use `.squad/log/` instead)
