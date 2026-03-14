<#
.SYNOPSIS
    Parses exam schedule from YAML and returns structured data.

.DESCRIPTION
    Reads schedule.yaml and returns exam information for all students.
    Supports Hebrew content (RTL) and calculates days until each exam.

.PARAMETER SchedulePath
    Path to schedule.yaml file. Defaults to schedule.yaml in script directory.

.EXAMPLE
    .\Get-ExamSchedule.ps1
    Returns all exams with days-until calculation.

.EXAMPLE
    .\Get-ExamSchedule.ps1 | Where-Object { $_.DaysUntil -le 7 }
    Returns only exams in the next 7 days.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SchedulePath = "$PSScriptRoot\schedule.yaml"
)

# Check if powershell-yaml module is installed
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Warning "powershell-yaml module not found. Installing..."
    try {
        Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AllowClobber
        Write-Host "✓ Installed powershell-yaml module" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install powershell-yaml module. Please install manually: Install-Module powershell-yaml"
        exit 1
    }
}

Import-Module powershell-yaml

# Read and parse YAML
if (-not (Test-Path $SchedulePath)) {
    Write-Error "Schedule file not found: $SchedulePath"
    exit 1
}

$yamlContent = Get-Content -Path $SchedulePath -Raw -Encoding UTF8
$schedule = ConvertFrom-Yaml $yamlContent

$today = Get-Date

# Process and flatten exam data
$allExams = @()
foreach ($student in $schedule.students) {
    foreach ($exam in $student.exams) {
        $examDate = [datetime]::Parse($exam.date)
        $daysUntil = ($examDate - $today).Days
        
        $allExams += [PSCustomObject]@{
            StudentName   = $student.name
            Grade         = $student.grade
            Subject       = $exam.subject
            ExamDate      = $examDate
            DaysUntil     = $daysUntil
            Topics        = $exam.topics
            MaterialsUrl  = $exam.materials_url
            Notes         = $exam.notes
            Status        = if ($daysUntil -lt 0) { "Past" } 
                           elseif ($daysUntil -eq 0) { "Today" }
                           elseif ($daysUntil -le 3) { "Urgent" }
                           elseif ($daysUntil -le 7) { "Soon" }
                           else { "Upcoming" }
        }
    }
}

# Sort by exam date
$allExams | Sort-Object ExamDate

Write-Verbose "Processed $($allExams.Count) exams from $($schedule.students.Count) students"
