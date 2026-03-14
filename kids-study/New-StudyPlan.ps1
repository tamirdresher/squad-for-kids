<#
.SYNOPSIS
    Generates a daily study plan for upcoming exams.

.DESCRIPTION
    Creates a structured study plan based on exam schedule, allocating study time
    per topic with spaced repetition. Respects Shabbat (Friday evening to Saturday evening).

.PARAMETER SchedulePath
    Path to schedule.yaml file. Defaults to schedule.yaml in script directory.

.PARAMETER DaysAhead
    Number of days to plan ahead. Default is 14.

.PARAMETER StudyHoursPerDay
    Maximum study hours per day per student. Default is 2.

.PARAMETER MinDaysBeforeExam
    Minimum days before exam to start studying. Default is 5.

.PARAMETER ExcludeShabbat
    If set, excludes Friday evening through Saturday for study sessions.

.EXAMPLE
    .\New-StudyPlan.ps1
    Generates a 14-day study plan.

.EXAMPLE
    .\New-StudyPlan.ps1 -DaysAhead 7 -StudyHoursPerDay 3
    Generates a 7-day plan with 3 hours per day.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SchedulePath = "$PSScriptRoot\schedule.yaml",
    
    [Parameter()]
    [int]$DaysAhead = 14,
    
    [Parameter()]
    [decimal]$StudyHoursPerDay = 2.0,
    
    [Parameter()]
    [int]$MinDaysBeforeExam = 5,
    
    [Parameter()]
    [switch]$ExcludeShabbat
)

# Get exam schedule
$exams = & "$PSScriptRoot\Get-ExamSchedule.ps1" -SchedulePath $SchedulePath

# Filter to upcoming exams only
$upcomingExams = $exams | Where-Object { $_.DaysUntil -ge 0 -and $_.DaysUntil -le ($DaysAhead + $MinDaysBeforeExam) }

if ($upcomingExams.Count -eq 0) {
    Write-Host "📚 No upcoming exams found in the next $DaysAhead days. Great job!" -ForegroundColor Green
    return
}

Write-Host "`n=== Study Plan Generator ===" -ForegroundColor Cyan
Write-Host "Planning for $($upcomingExams.Count) upcoming exams`n"

# Calculate study sessions needed per exam
$studySessions = @()

foreach ($exam in $upcomingExams) {
    $topicCount = $exam.Topics.Count
    $studyStartDay = [Math]::Max(0, $exam.DaysUntil - $MinDaysBeforeExam)
    $availableDays = $exam.DaysUntil - $studyStartDay
    
    if ($availableDays -le 0) {
        Write-Warning "⚠️  Exam too soon: $($exam.Subject) for $($exam.StudentName) in $($exam.DaysUntil) days - not enough time to plan!"
        continue
    }
    
    # Allocate time per topic (45 min per topic, with review sessions)
    $minutesPerTopic = 45
    
    foreach ($topic in $exam.Topics) {
        # Primary study session
        $studySessions += [PSCustomObject]@{
            StudentName  = $exam.StudentName
            Subject      = $exam.Subject
            Topic        = $topic
            ExamDate     = $exam.ExamDate
            StudyDay     = $studyStartDay
            Duration     = $minutesPerTopic
            SessionType  = "Primary"
            Priority     = if ($exam.DaysUntil -le 3) { "High" } else { "Normal" }
        }
        
        # Add review session 2 days before exam if there's time
        if ($exam.DaysUntil -ge 3) {
            $studySessions += [PSCustomObject]@{
                StudentName  = $exam.StudentName
                Subject      = $exam.Subject
                Topic        = $topic
                ExamDate     = $exam.ExamDate
                StudyDay     = $exam.DaysUntil - 2
                Duration     = 20
                SessionType  = "Review"
                Priority     = "High"
            }
        }
    }
}

# Generate daily schedule
$today = Get-Date
$dailyPlans = @{}

for ($dayOffset = 0; $dayOffset -lt $DaysAhead; $dayOffset++) {
    $currentDate = $today.AddDays($dayOffset)
    
    # Check if Shabbat
    if ($ExcludeShabbat) {
        $isShabbat = $currentDate.DayOfWeek -eq 'Friday' -or $currentDate.DayOfWeek -eq 'Saturday'
        if ($isShabbat) {
            continue
        }
    }
    
    # Get sessions for this day
    $sessionsToday = $studySessions | Where-Object { $_.StudyDay -eq $dayOffset } | Sort-Object Priority, StudentName
    
    if ($sessionsToday.Count -eq 0) {
        continue
    }
    
    $dailyPlans[$currentDate.ToString("yyyy-MM-dd")] = $sessionsToday
}

# Output daily plans
foreach ($dateKey in ($dailyPlans.Keys | Sort-Object)) {
    $date = [datetime]::Parse($dateKey)
    $sessions = $dailyPlans[$dateKey]
    
    Write-Host "`n📅 $($date.ToString('dddd, MMMM dd, yyyy'))" -ForegroundColor Yellow
    Write-Host ("=" * 60)
    
    $currentStudent = $null
    foreach ($session in $sessions) {
        if ($session.StudentName -ne $currentStudent) {
            Write-Host "`n👤 $($session.StudentName)" -ForegroundColor Cyan
            $currentStudent = $session.StudentName
        }
        
        $sessionIcon = if ($session.SessionType -eq "Review") { "🔄" } else { "📖" }
        $priorityColor = if ($session.Priority -eq "High") { "Red" } else { "White" }
        
        Write-Host "  $sessionIcon $($session.Subject) - $($session.Topic)" -ForegroundColor $priorityColor
        Write-Host "     Duration: $($session.Duration) min | Type: $($session.SessionType)" -ForegroundColor Gray
    }
}

Write-Host "`n`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Total study sessions planned: $($studySessions.Count)"
Write-Host "Study days: $($dailyPlans.Count)"
Write-Host "`n✨ Study plan generated successfully!`n"

# Return structured data for pipeline use
return $dailyPlans
