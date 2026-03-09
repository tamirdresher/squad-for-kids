# Sanitization Script for Squad Demo Repository
# Issue: #225
# Purpose: Automated find-and-replace for sensitive data patterns

param(
    [string]$SourcePath = (Get-Location),
    [string]$OutputPath = "$SourcePath\..\squad-demo-sanitized",
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

Write-Host "Squad Demo Repository Sanitization Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE: No files will be modified" -ForegroundColor Yellow
    Write-Host ""
}

# Sanitization patterns (order matters - most specific first)
$patterns = @(
    # Personal Information
    @{ Pattern = 'tamirdresher_microsoft'; Replacement = 'demo-org'; Description = 'GitHub org name' }
    @{ Pattern = 'tamirdresher'; Replacement = 'demo-user'; Description = 'GitHub username' }
    @{ Pattern = 'Tamir Dresher'; Replacement = 'Demo User'; Description = 'Full name' }
    @{ Pattern = 'tamir'; Replacement = 'demo'; Description = 'First name' }
    
    # Azure DevOps
    @{ Pattern = 'msazure'; Replacement = 'demo-org'; Description = 'Azure DevOps org' }
    
    # Internal Microsoft Services
    @{ Pattern = 'idk8s-infrastructure'; Replacement = 'platform-infrastructure'; Description = 'Internal repo name' }
    @{ Pattern = 'DK8S'; Replacement = 'K8S-Platform'; Description = 'Service acronym' }
    @{ Pattern = 'idk8s'; Replacement = 'platform-k8s'; Description = 'Service name' }
    @{ Pattern = 'Aurora'; Replacement = 'ServiceA'; Description = 'Internal service' }
    
    # URLs and Endpoints
    @{ Pattern = 'https://[a-zA-Z0-9\-\.]+\.contoso\.com'; Replacement = 'https://api.example.com'; Description = 'Internal URLs'; Regex = $true }
    @{ Pattern = 'fedramp-dashboard\.contoso\.com'; Replacement = 'dashboard.example.com'; Description = 'Dashboard URL' }
    
    # Azure Resources
    @{ Pattern = 'fedramp-dashboard-dev'; Replacement = 'demo-dashboard-dev'; Description = 'CosmosDB name' }
    @{ Pattern = 'fedramp-kv-dev'; Replacement = 'demo-kv-dev'; Description = 'KeyVault name' }
    @{ Pattern = 'fedramp-functions-dev'; Replacement = 'demo-functions-dev'; Description = 'Function App name' }
    @{ Pattern = 'fedramp-api-dev'; Replacement = 'demo-api-dev'; Description = 'API name' }
    @{ Pattern = 'fedrampstodev'; Replacement = 'demostoragedev'; Description = 'Storage account' }
    @{ Pattern = 'fedramp-logs-dev'; Replacement = 'demo-logs-dev'; Description = 'Log Analytics' }
    @{ Pattern = 'fedramp-appinsights-dev'; Replacement = 'demo-appinsights-dev'; Description = 'App Insights' }
    @{ Pattern = 'infrastructure-team@contoso\.com'; Replacement = 'team@example.com'; Description = 'Team email' }
    
    # GitHub Project IDs (replace with placeholders)
    @{ Pattern = 'PVT_kwHOC0L5c84BRG-P'; Replacement = '<YOUR_PROJECT_ID>'; Description = 'Project ID' }
    @{ Pattern = 'PVTSSF_lAHOC0L5c84BRG-Pzg_CIuc'; Replacement = '<YOUR_STATUS_FIELD_ID>'; Description = 'Field ID' }
    
    # Repository references
    @{ Pattern = 'tamresearch1'; Replacement = 'squad-demo'; Description = 'Repo name' }
)

# Files/directories to exclude from sanitization
$excludePatterns = @(
    '.git',
    'node_modules',
    '.ralph-watch.lock',
    '.ralph-state.json',
    '.playwright-cli',
    'cli-tunnel-hub-output-latest.txt',
    'package-lock.json',
    '*.log'
)

# Files to completely exclude from output
$excludeFiles = @(
    # Agent histories (contain personal work)
    '.squad/agents/*/history.md',
    '.squad/identity/now.md',
    '.squad/scripts/workiq-queries/*',
    
    # Azure/Infrastructure
    'infrastructure/*',
    '.azure-pipelines/*',
    '.azuredevops/*',
    
    # Project-specific code
    'api/*',
    'functions/*',
    'dashboard-ui/*',
    'tests/fedramp-validation/*',
    
    # Research docs
    'FEDRAMP_P0_NGINX_INGRESS_ASSESSMENT.md',
    'PATENT_*.md',
    'krishna-review-findings.md',
    'ISSUE_*_SUMMARY.md',
    
    # Temporary files
    '.ralph-watch.lock',
    '.ralph-state.json',
    'cli-tunnel-hub-output-latest.txt',
    '.squad/commit-*.txt',
    '.squad/COMMIT_*.txt',
    
    # Training
    'training/*'
)

function Should-Exclude {
    param([string]$Path, [string]$BasePath)
    
    $relativePath = $Path.Replace($BasePath, "").TrimStart('\', '/')
    
    foreach ($pattern in $excludeFiles) {
        if ($relativePath -like $pattern) {
            return $true
        }
    }
    
    foreach ($pattern in $excludePatterns) {
        if ($relativePath -like "*$pattern*") {
            return $true
        }
    }
    
    return $false
}

function Sanitize-Content {
    param([string]$Content)
    
    $result = $Content
    $changesApplied = @()
    
    foreach ($p in $patterns) {
        $oldContent = $result
        
        if ($p.Regex) {
            $result = $result -replace $p.Pattern, $p.Replacement
        } else {
            $result = $result -replace [regex]::Escape($p.Pattern), $p.Replacement
        }
        
        if ($oldContent -ne $result) {
            $changesApplied += $p.Description
        }
    }
    
    return @{
        Content = $result
        Changes = $changesApplied
    }
}

# Main execution
if (-not $DryRun) {
    if (Test-Path $OutputPath) {
        Write-Host "Output path already exists: $OutputPath" -ForegroundColor Yellow
        $confirm = Read-Host "Delete and recreate? (y/n)"
        if ($confirm -ne 'y') {
            Write-Host "Aborted." -ForegroundColor Red
            exit 1
        }
        Remove-Item $OutputPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

Write-Host "Scanning files in: $SourcePath" -ForegroundColor Green
Write-Host ""

$stats = @{
    FilesScanned = 0
    FilesSanitized = 0
    FilesExcluded = 0
    TotalChanges = 0
}

Get-ChildItem -Path $SourcePath -Recurse -File | ForEach-Object {
    $stats.FilesScanned++
    
    if (Should-Exclude -Path $_.FullName -BasePath $SourcePath) {
        $stats.FilesExcluded++
        if ($Verbose) {
            Write-Host "EXCLUDED: $($_.FullName.Replace($SourcePath, ''))" -ForegroundColor DarkGray
        }
        return
    }
    
    # Only sanitize text files
    $textExtensions = @('.md', '.ps1', '.yml', '.yaml', '.json', '.ts', '.js', '.cs', '.txt', '.sh', '.bicep')
    if ($textExtensions -notcontains $_.Extension) {
        if ($Verbose) {
            Write-Host "SKIPPED (binary): $($_.FullName.Replace($SourcePath, ''))" -ForegroundColor DarkGray
        }
        
        if (-not $DryRun) {
            $destPath = $_.FullName.Replace($SourcePath, $OutputPath)
            $destDir = Split-Path $destPath -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item $_.FullName -Destination $destPath -Force
        }
        return
    }
    
    try {
        $content = Get-Content $_.FullName -Raw -ErrorAction Stop
        $result = Sanitize-Content -Content $content
        
        if ($result.Changes.Count -gt 0) {
            $stats.FilesSanitized++
            $stats.TotalChanges += $result.Changes.Count
            
            Write-Host "SANITIZED: $($_.FullName.Replace($SourcePath, ''))" -ForegroundColor Green
            if ($Verbose) {
                foreach ($change in $result.Changes) {
                    Write-Host "  - $change" -ForegroundColor Cyan
                }
            }
            
            if (-not $DryRun) {
                $destPath = $_.FullName.Replace($SourcePath, $OutputPath)
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                $result.Content | Out-File -FilePath $destPath -Encoding utf8 -Force
            }
        } else {
            if ($Verbose) {
                Write-Host "NO CHANGES: $($_.FullName.Replace($SourcePath, ''))" -ForegroundColor DarkGray
            }
            
            if (-not $DryRun) {
                $destPath = $_.FullName.Replace($SourcePath, $OutputPath)
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item $_.FullName -Destination $destPath -Force
            }
        }
    } catch {
        Write-Host "ERROR: Failed to process $($_.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Sanitization Complete" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host "Files Scanned:    $($stats.FilesScanned)" -ForegroundColor White
Write-Host "Files Sanitized:  $($stats.FilesSanitized)" -ForegroundColor Green
Write-Host "Files Excluded:   $($stats.FilesExcluded)" -ForegroundColor Yellow
Write-Host "Total Changes:    $($stats.TotalChanges)" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN: No files were actually modified" -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "Output directory: $OutputPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Manual review of sanitized output" -ForegroundColor White
Write-Host "2. Search for remaining sensitive patterns" -ForegroundColor White
Write-Host "3. Create public-facing README.md" -ForegroundColor White
Write-Host "4. Test repository setup from scratch" -ForegroundColor White
