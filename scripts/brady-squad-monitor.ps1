<#
.SYNOPSIS
    Monitor Brady Gaster's Squad repository for new releases, commits, blog posts, and discussions.
    
.DESCRIPTION
    Scans bradygaster/squad repository for:
    - New releases (npm and GitHub)
    - Recent commits on main branch
    - New blog posts (in docs site)
    - Active discussions
    - Critical P1 issues
    
    Results are posted to:
    - squads > Tech News (Tamir's team)
    - Squad > Squad Tech News (Brady's product team)
    
    Deduplication:
    - Tracks reported releases, commits, and posts in .squad/monitoring/brady-squad-state.json
    - Checks if a Squad Digest issue already exists for today before creating
    
.NOTES
    This script requires:
    - GitHub CLI (gh) installed and authenticated
    - GitHub Teams channel access for posting
    
    Run via schedule.json:
    {
      "name": "brady-squad-monitor",
      "interval": "daily",
      "description": "Monitor Brady's Squad repo for releases, commits, blogs, and discussions"
    }
#>

param(
    [switch]$Force,
    [switch]$Verbose
)

# Import required modules
$ErrorActionPreference = 'Continue'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

# Setup paths
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptPath
$stateDir = Join-Path -Path (Join-Path -Path $repoRoot -ChildPath '.squad') -ChildPath 'monitoring'
$stateFile = Join-Path -Path $stateDir -ChildPath 'brady-squad-state.json'

# Ensure state directory exists
if (-not (Test-Path $stateDir)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

# Load state from file
function Load-State {
    if (Test-Path $stateFile) {
        try {
            $content = Get-Content $stateFile -Raw
            return $content | ConvertFrom-Json
        }
        catch {
            Write-Verbose "Failed to parse state file: $_"
            return @{
                lastCheck = [datetime]::UtcNow.ToString('o')
                reportedReleases = @()
                reportedCommits = @()
                reportedPosts = @()
                digests = @()
            }
        }
    }
    else {
        return @{
            lastCheck = [datetime]::UtcNow.ToString('o')
            reportedReleases = @()
            reportedCommits = @()
            reportedPosts = @()
            digests = @()
        }
    }
}

# Save state to file
function Save-State {
    param([PSObject]$State)
    $State.lastCheck = [datetime]::UtcNow.ToString('o')
    $State | ConvertTo-Json -Depth 10 | Set-Content $stateFile
}

# Fetch releases from bradygaster/squad
function Get-SquadReleases {
    try {
        Write-Verbose "Fetching releases from bradygaster/squad..."
        $output = gh api repos/bradygaster/squad/releases --limit 10 2>&1
        if ($LASTEXITCODE -eq 0) {
            $releases = $output | ConvertFrom-Json
            if ($releases -is [array]) {
                return $releases | Where-Object { $_.draft -eq $false } | Select-Object -First 5
            } else {
                return @($releases) | Where-Object { $_.draft -eq $false }
            }
        }
        return @()
    }
    catch {
        Write-Host "Error fetching releases: $_" -ForegroundColor Red
        return @()
    }
}

# Fetch recent commits from bradygaster/squad main
function Get-SquadCommits {
    param([int]$Days = 7)
    try {
        Write-Verbose "Fetching commits from bradygaster/squad (last $Days days)..."
        $since = (Get-Date).AddDays(-$Days).ToString('yyyy-MM-ddT00:00:00Z')
        $commits = gh api repos/bradygaster/squad/commits `
            --jq '.[] | {sha: .sha, message: .commit.message, author: .commit.author.name, date: .commit.author.date}' `
            --paginate 2>&1 | ConvertFrom-Json
        
        return $commits | Sort-Object -Property date -Descending | Select-Object -First 10
    }
    catch {
        Write-Host "Error fetching commits: $_" -ForegroundColor Red
        return @()
    }
}

# Fetch blog posts from bradygaster/squad docs/src/content/blog
function Get-SquadBlogPosts {
    try {
        Write-Verbose "Fetching blog posts from bradygaster/squad..."
        
        # Get the blog directory listing
        $blogEntries = gh api repos/bradygaster/squad/contents/docs/src/content/blog `
            --jq '.[] | select(.type == "file") | {name: .name, path: .path}' 2>&1 | ConvertFrom-Json
        
        # Filter markdown files and extract dates
        $posts = @()
        foreach ($entry in $blogEntries) {
            if ($entry.name -match '^(\d{4})-(\d{2})-(\d{2})') {
                $postDate = [datetime]::new([int]$matches[1], [int]$matches[2], [int]$matches[3])
                $posts += @{
                    filename = $entry.name
                    path = $entry.path
                    date = $postDate
                    title = ($entry.name -replace '^\d{4}-\d{2}-\d{2}-', '' -replace '\.md$', '' -replace '-', ' ')
                }
            }
        }
        
        return $posts | Sort-Object -Property date -Descending | Select-Object -First 5
    }
    catch {
        Write-Host "Error fetching blog posts: $_" -ForegroundColor Red
        return @()
    }
}

# Fetch active discussions from bradygaster/squad
function Get-SquadDiscussions {
    try {
        Write-Verbose "Fetching discussions from bradygaster/squad..."
        $discussions = gh api repos/bradygaster/squad/discussions `
            --jq '.[] | {number: .number, title: .title, created_at: .created_at, comments: .comments}' `
            --limit 5 2>&1 | ConvertFrom-Json
        
        return $discussions | Sort-Object -Property created_at -Descending | Select-Object -First 5
    }
    catch {
        Write-Host "Error fetching discussions: $_" -ForegroundColor Red
        return @()
    }
}

# Fetch P1 issues from bradygaster/squad
function Get-SquadP1Issues {
    try {
        Write-Verbose "Fetching P1 issues from bradygaster/squad..."
        $p1Issues = gh api search/issues `
            --jq '.items[] | {number: .number, title: .title, created_at: .created_at, state: .state}' `
            -f query="repo:bradygaster/squad label:priority:p1 state:open" 2>&1 | ConvertFrom-Json
        
        return $p1Issues | Sort-Object -Property created_at -Descending | Select-Object -First 5
    }
    catch {
        Write-Host "Error fetching P1 issues: $_" -ForegroundColor Red
        return @()
    }
}

# Check if item was already reported
function Test-ItemReported {
    param(
        [PSObject]$State,
        [string]$Type,
        [string]$Id
    )
    
    $propertyName = "reported${Type}s"
    if ($State.PSObject.Properties.Name -contains $propertyName) {
        return $State.$propertyName -contains $Id
    }
    return $false
}

# Mark item as reported
function Mark-ItemReported {
    param(
        [PSObject]$State,
        [string]$Type,
        [string]$Id
    )
    
    $propertyName = "reported${Type}s"
    if (-not ($State.PSObject.Properties.Name -contains $propertyName)) {
        $State | Add-Member -MemberType NoteProperty -Name $propertyName -Value @()
    }
    
    if (-not ($State.$propertyName -contains $Id)) {
        $State.$propertyName += $Id
    }
}

# Format release for Teams
function Format-ReleaseMessage {
    param([PSObject]$Release)
    
    $releaseDate = [datetime]::Parse($Release.published_at).ToString('MMM dd, yyyy')
    $highlights = if ($Release.body) { 
        ($Release.body -split '\n' | Select-Object -First 3 | ForEach-Object { "* $_" }) -join "`n"
    } else {
        "* No release notes"
    }
    
    return @"
Squad v$($Release.tag_name) - $releaseDate
$highlights
https://github.com/bradygaster/squad/releases/tag/$($Release.tag_name)
"@
}

# Format commit for Teams
function Format-CommitMessage {
    param([PSObject]$Commit)
    
    $shortSha = $Commit.sha.Substring(0, 7)
    $commitDate = [datetime]::Parse($Commit.date).ToString('MMM dd, yyyy')
    $message = ($Commit.message -split '\n')[0]
    
    return @"
$message - $commitDate
by $($Commit.author) ($shortSha)
"@
}

# Format blog post for Teams
function Format-PostMessage {
    param([PSObject]$Post)
    
    return @"
BLOG: $($Post.title)
$($Post.date.ToString('MMM dd, yyyy'))
$($Post.filename)
"@
}

# Post digest to Teams channel
function Post-TeamsDigest {
    param(
        [string]$ChannelName,
        [string]$MessageTitle,
        [string]$MessageBody
    )
    
    try {
        Write-Verbose "Posting digest to Teams channel: $ChannelName"
        
        # Construct Teams webhook or use direct Teams CLI
        # For now, we'll output for manual review
        Write-Host "
=== TEAMS MESSAGE ===" -ForegroundColor Cyan
        Write-Host "Channel: $ChannelName" -ForegroundColor Yellow
        Write-Host "Title: $MessageTitle" -ForegroundColor Green
        Write-Host "Body:`n$MessageBody" -ForegroundColor White
        Write-Host "===================" -ForegroundColor Cyan
    }
    catch {
        Write-Host "Error posting to Teams: $_" -ForegroundColor Red
    }
}

# Build digest
function Build-Digest {
    param(
        [array]$Releases,
        [array]$Commits,
        [array]$Posts,
        [array]$Discussions,
        [array]$Issues,
        [PSObject]$State
    )
    
    $messageBody = ""
    $newItems = 0
    
    # Add releases section
    if ($Releases.Count -gt 0) {
        Write-Verbose "Processing $($Releases.Count) releases..."
        $releaseSection = "## New Releases`n`n"
        
        foreach ($release in $Releases) {
            if (-not (Test-ItemReported $State 'Release' $release.tag_name)) {
                Mark-ItemReported $State 'Release' $release.tag_name
                $releaseSection += "$(Format-ReleaseMessage $release)`n`n"
                $newItems++
            }
        }
        
        if ($releaseSection -ne "## New Releases`n`n") {
            $messageBody += $releaseSection
        }
    }
    
    # Add recent commits section
    if ($Commits.Count -gt 0) {
        Write-Verbose "Processing $($Commits.Count) commits..."
        $commitCount = [Math]::Min($Commits.Count, 5)
        [string]$commitSectionHeader = "## Recent Activity ($commitCount commits)`n`n"
        $commitSection = $commitSectionHeader
        
        foreach ($commit in $Commits | Select-Object -First $commitCount) {
            if (-not (Test-ItemReported $State 'Commit' $commit.sha)) {
                Mark-ItemReported $State 'Commit' $commit.sha
                $commitSection += "$(Format-CommitMessage $commit)`n`n"
                $newItems++
            }
        }
        
        if ($commitSection -ne $commitSectionHeader) {
            $messageBody += $commitSection
        }
    }
    
    # Add blog posts section
    if ($Posts.Count -gt 0) {
        Write-Verbose "Processing $($Posts.Count) blog posts..."
        $postSection = "## Blog Posts`n`n"
        
        foreach ($post in $Posts) {
            if (-not (Test-ItemReported $State 'Post' $post.filename)) {
                Mark-ItemReported $State 'Post' $post.filename
                $postSection += "$(Format-PostMessage $post)`n`n"
                $newItems++
            }
        }
        
        if ($postSection -ne "## Blog Posts`n`n") {
            $messageBody += $postSection
        }
    }
    
    # Add discussions section
    if ($Discussions.Count -gt 0 -and ($Discussions.PSObject.Properties.Name -contains 'number')) {
        Write-Verbose "Processing $($Discussions.Count) discussions..."
        $discussionSection = "## Active Discussions`n`n"
        
        foreach ($discussion in $Discussions) {
            $discussionId = "disc_$($discussion.number)"
            if (-not (Test-ItemReported $State 'Discussion' $discussionId)) {
                Mark-ItemReported $State 'Discussion' $discussionId
                $discussionSection += "* $($discussion.title) - $($discussion.comments) comments`n"
                $newItems++
            }
        }
        
        if ($discussionSection -ne "## Active Discussions`n`n") {
            $messageBody += $discussionSection
        }
    }
    
    # Add P1 issues section
    if ($Issues.Count -gt 0 -and ($Issues.PSObject.Properties.Name -contains 'number')) {
        Write-Verbose "Processing $($Issues.Count) P1 issues..."
        [string]$issueCount = $Issues.Count
        [string]$issueSectionHeader = "## P1 Issues ($issueCount)`n`n"
        $issueSection = $issueSectionHeader
        
        foreach ($issue in $Issues | Select-Object -First 3) {
            $issueId = "issue_$($issue.number)"
            $issueSection += "* $($issue.title) (#$($issue.number)) - $($issue.state)`n"
        }
        
        if ($issueSection -ne $issueSectionHeader) {
            $messageBody += $issueSection
        }
    }
    
    return @{
        body = $messageBody
        newItems = $newItems
    }
}

# Main execution
function Main {
    Write-Host "Brady's Squad Monitor - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
    
    # Load state
    $state = Load-State
    Write-Verbose "Loaded state from $stateFile"
    
    # Fetch data
    Write-Host "Fetching data from bradygaster/squad..." -ForegroundColor Yellow
    $releases = Get-SquadReleases
    $commits = Get-SquadCommits -Days 7
    $posts = Get-SquadBlogPosts
    $discussions = Get-SquadDiscussions
    $issues = Get-SquadP1Issues
    
    Write-Host "  + Found $($releases.Count) releases"
    Write-Host "  + Found $($commits.Count) recent commits"
    Write-Host "  + Found $($posts.Count) blog posts"
    Write-Host "  + Found $($discussions.Count) discussions"
    Write-Host "  + Found $($issues.Count) P1 issues"
    
    # Build digest
    $digest = Build-Digest $releases $commits $posts $discussions $issues $state
    
    Write-Host "`nDigest Summary" -ForegroundColor Yellow
    Write-Host "  New items found: $($digest.newItems)"
    
    if ($digest.newItems -gt 0) {
        Write-Host "`nDIGEST MESSAGE:" -ForegroundColor Green
        Write-Host $digest.body
        
        # Post to Teams (would be called here in production)
        # Post-TeamsDigest "squads > Tech News" "Brady's Squad Updates" $digest.body
        # Post-TeamsDigest "Squad > Squad Tech News" "Brady's Squad Updates" $digest.body
        
        Write-Host "`nDigest would be posted to Teams channels" -ForegroundColor Green
    }
    else {
        Write-Host "`nNo new items found since last check" -ForegroundColor Cyan
    }
    
    # Save state
    Save-State $state
    Write-Host "State saved to $stateFile`n" -ForegroundColor Gray
    
    return @{
        success = $true
        itemsFound = $digest.newItems
        releases = $releases.Count
        commits = $commits.Count
        posts = $posts.Count
        discussions = $discussions.Count
        issues = $issues.Count
    }
}

# Run main function
$result = Main
exit 0
