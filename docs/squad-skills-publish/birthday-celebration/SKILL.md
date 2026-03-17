---
name: birthday-celebration
description: "Automated team birthday and celebration tracking with privacy-safe registry and scheduled notifications. Use when managing team celebrations."
license: MIT
metadata:
  version: 1.0.0
  adapted_from: Team culture automation patterns
---

# Birthday & Celebration System

**Automated team celebration tracking** with a privacy-safe registry and scheduled notifications. Never miss a teammate's birthday or milestone again.

---

## Triggers

| Phrase | Priority |
|--------|----------|
| `birthday`, `team birthday` | HIGH — Check/manage birthdays |
| `upcoming birthdays`, `who has a birthday` | HIGH — Lookup |
| `celebration`, `celebrate` | MEDIUM — General celebration |
| `work anniversary`, `milestone` | MEDIUM — Other events |

---

## Registry Format

Store team member celebrations in a JSON file. **Only store month and day** — no birth year, for privacy.

### `celebrations.json`

```json
{
  "team": "Your Team Name",
  "description": "Birthday registry. Only month/day stored for privacy.",
  "members": [
    {
      "name": "Alice Chen",
      "birthday": "03-15",
      "role": "Senior Engineer",
      "contact": "alice@example.com"
    },
    {
      "name": "Bob Martinez",
      "birthday": "07-22",
      "role": "Product Manager",
      "contact": "bob@example.com"
    },
    {
      "name": "Carol Singh",
      "birthday": "11-08",
      "role": "Designer",
      "contact": "carol@example.com"
    }
  ]
}
```

### Fields

| Field | Required | Format | Notes |
|-------|----------|--------|-------|
| `name` | Yes | String | Display name |
| `birthday` | Yes | `MM-DD` | Month-Day only (privacy) |
| `role` | No | String | Job title |
| `contact` | No | String | Email or messaging handle |

---

## Checking for Upcoming Birthdays

### PowerShell

```powershell
function Get-UpcomingBirthdays {
    param(
        [string]$RegistryPath = "celebrations.json",
        [int]$DaysAhead = 7
    )

    $registry = Get-Content $RegistryPath | ConvertFrom-Json
    $today = Get-Date
    $upcoming = @()

    foreach ($member in $registry.members) {
        if ($member.birthday -eq "MM-DD") { continue }  # Skip placeholders

        $birthday = [datetime]::ParseExact(
            "$($today.Year)-$($member.birthday)",
            "yyyy-MM-dd",
            $null
        )

        # Handle year boundary (Dec checking for Jan birthdays)
        if ($birthday -lt $today.Date) {
            $birthday = $birthday.AddYears(1)
        }

        $daysUntil = ($birthday - $today.Date).Days

        if ($daysUntil -ge 0 -and $daysUntil -le $DaysAhead) {
            $upcoming += [PSCustomObject]@{
                Name      = $member.name
                Birthday  = $member.birthday
                DaysUntil = $daysUntil
                Role      = $member.role
            }
        }
    }

    return $upcoming | Sort-Object DaysUntil
}

# Usage
$upcoming = Get-UpcomingBirthdays -DaysAhead 14
if ($upcoming) {
    Write-Host "🎂 Upcoming birthdays:"
    $upcoming | Format-Table Name, Birthday, DaysUntil, Role
} else {
    Write-Host "No birthdays in the next 14 days."
}
```

### Python

```python
import json
from datetime import datetime, timedelta

def get_upcoming_birthdays(registry_path="celebrations.json", days_ahead=7):
    with open(registry_path) as f:
        registry = json.load(f)

    today = datetime.now().date()
    upcoming = []

    for member in registry["members"]:
        if member["birthday"] == "MM-DD":
            continue

        month, day = map(int, member["birthday"].split("-"))
        birthday = today.replace(month=month, day=day)

        if birthday < today:
            birthday = birthday.replace(year=today.year + 1)

        days_until = (birthday - today).days

        if 0 <= days_until <= days_ahead:
            upcoming.append({
                "name": member["name"],
                "birthday": member["birthday"],
                "days_until": days_until,
                "role": member.get("role", "")
            })

    return sorted(upcoming, key=lambda x: x["days_until"])
```

---

## Celebration Message Templates

### Birthday

```
🎂 Happy Birthday, {name}! 🎉

Wishing you an amazing day! The whole {team} team celebrates with you.

🎁 May your code compile on the first try and your tests all pass green!
```

### Work Anniversary

```
🏆 Congratulations, {name}! 🎊

Today marks {years} year(s) with {team}. Thank you for everything you bring to the team!
```

### Milestone

```
⭐ Milestone Achievement! ⭐

{name} has reached {milestone}. Let's celebrate this incredible accomplishment!
```

---

## Delivery Options

### Option A: Webhook (Teams, Slack, Discord)

```powershell
$webhookUrl = $env:CELEBRATION_WEBHOOK_URL
$message = @{ text = "🎂 Happy Birthday, Alice! 🎉" } | ConvertTo-Json
Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json" -Body $message
```

### Option B: Email

```powershell
Send-MailMessage -To "team@example.com" -Subject "🎂 Team Birthday!" -Body $message
```

### Option C: GitHub Issue

```bash
gh issue create --title "🎂 Happy Birthday Alice!" --body "$message" --label "celebration"
```

---

## Scheduled Checking

Add birthday checking to your daily/weekly automation loop:

```json
{
  "schedule": {
    "birthday_check": {
      "frequency": "daily",
      "time": "09:00",
      "action": "check_upcoming_birthdays",
      "days_ahead": 7,
      "notify_channel": "team-general"
    }
  }
}
```

---

## Privacy Considerations

1. **No birth year** — Only store MM-DD to avoid age disclosure
2. **Opt-in only** — Members choose to add their birthday
3. **Registry access** — Limit who can read the celebrations file
4. **No public posting** — Only post to private team channels
5. **Respect preferences** — Some people don't want birthday attention

---

## See Also

- [News Broadcasting](../news-broadcasting/) — Deliver celebration announcements
- [Notification Routing](../notification-routing/) — Route celebrations to the right channel
