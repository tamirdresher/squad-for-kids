---
name: outlook-automation
description: Control Microsoft Outlook on Windows via COM automation. Use when the user wants to create meetings, send emails, search emails, read inbox, manage calendar events, or interact with Outlook in any way. Triggers on phrases like "create meeting", "send email", "search emails", "check inbox", "calendar", "schedule", "outlook".
---

# Outlook Automation (Windows COM)

## When to Use

- User wants to create, update, or delete calendar meetings/appointments
- User wants to send, read, search, or manage emails
- User wants to interact with Outlook contacts, folders, or tasks
- Any request involving Outlook data or actions on Windows

## When Not to Use

- User is on macOS or Linux (COM is Windows-only)
- User wants cloud-only access without local Outlook installed (use Microsoft Graph API instead)
- Outlook is not installed on the machine

## Prerequisites

- **Windows** with **Microsoft Outlook** installed and configured with an account
- PowerShell (available by default)

## Core Concepts

Outlook COM exposes these key object types:

| OlItemType Value | Type | Description |
|------------------|------|-------------|
| 0 | MailItem | Email messages |
| 1 | AppointmentItem | Calendar events / meetings |
| 2 | ContactItem | Contacts |
| 3 | TaskItem | Tasks |
| 4 | JournalItem | Journal entries |
| 6 | NoteItem | Notes |

### Folder Constants (OlDefaultFolders)

| Value | Folder |
|-------|--------|
| 3 | olFolderDeletedItems |
| 4 | olFolderOutbox |
| 5 | olFolderSentMail |
| 6 | olFolderInbox |
| 9 | olFolderCalendar |
| 10 | olFolderContacts |
| 13 | olFolderDrafts |
| 28 | olFolderToDo |

### Meeting Status Constants (OlMeetingStatus)

| Value | Status |
|-------|--------|
| 0 | olNonMeeting (appointment, no attendees) |
| 1 | olMeeting (meeting with attendees) |
| 3 | olMeetingReceived |
| 5 | olMeetingCanceled |

---

## Workflow

### Initialization

Always start by creating the COM object:

```powershell
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNameSpace("MAPI")
```

### Get the current user's email

```powershell
$currentUser = $namespace.CurrentUser
$currentUserEmail = $namespace.Accounts.Item(1).SmtpAddress
Write-Host "Logged in as: $currentUserEmail"
```

---

## Email Operations

### Send an Email

```powershell
$mail = $outlook.CreateItem(0)
$mail.Subject = "Subject here"
$mail.Body = "Plain text body here"
# For HTML body use: $mail.HTMLBody = "<h1>Hello</h1><p>HTML content</p>"
$mail.To = "recipient@example.com"
# $mail.CC = "cc@example.com"
# $mail.BCC = "bcc@example.com"

# Add attachment (optional):
# $mail.Attachments.Add("C:\path\to\file.pdf")

$mail.Send()
Write-Host "Email sent successfully"
```

### Read Inbox Emails

```powershell
$inbox = $namespace.GetDefaultFolder(6)
$messages = $inbox.Items
$messages.Sort("[ReceivedTime]", $true)  # Sort newest first

# Get last N emails
$count = [Math]::Min(10, $messages.Count)
for ($i = 1; $i -le $count; $i++) {
    $msg = $messages.Item($i)
    Write-Host "---"
    Write-Host "From: $($msg.SenderEmailAddress)"
    Write-Host "Subject: $($msg.Subject)"
    Write-Host "Received: $($msg.ReceivedTime)"
    Write-Host "Unread: $($msg.UnRead)"
}
```

### Search Emails

Use the `Restrict` method with DASL or Jet query filters:

```powershell
$inbox = $namespace.GetDefaultFolder(6)

# Search by subject (contains)
$filter = "@SQL=""urn:schemas:httpmail:subject"" LIKE '%search term%'"
$results = $inbox.Items.Restrict($filter)

# Search by sender
$filter = "@SQL=""urn:schemas:httpmail:fromemail"" = 'sender@example.com'"
$results = $inbox.Items.Restrict($filter)

# Search by date range
$startDate = (Get-Date).AddDays(-7).ToString("MM/dd/yyyy HH:mm")
$filter = "[ReceivedTime] >= '$startDate'"
$results = $inbox.Items.Restrict($filter)

# Search unread only
$filter = "[UnRead] = True"
$results = $inbox.Items.Restrict($filter)

# Combine filters with AND/OR
$filter = "@SQL=""urn:schemas:httpmail:subject"" LIKE '%project%' AND ""urn:schemas:httpmail:hasattachment"" = 1"
$results = $inbox.Items.Restrict($filter)

foreach ($item in $results) {
    Write-Host "$($item.ReceivedTime) | $($item.SenderEmailAddress) | $($item.Subject)"
}
Write-Host "Found $($results.Count) matching emails"
```

### Search Across All Folders

```powershell
$scope = "'Inbox','Sent Items','Drafts'"
$advancedSearch = $outlook.AdvancedSearch($scope, "urn:schemas:httpmail:subject LIKE '%keyword%'", $false, "SearchTag")
Start-Sleep -Seconds 3  # Wait for search to complete
$results = $advancedSearch.Results
foreach ($item in $results) {
    Write-Host "$($item.Subject) - $($item.ReceivedTime)"
}
```

### Reply / Forward

```powershell
$inbox = $namespace.GetDefaultFolder(6)
$email = $inbox.Items.GetFirst()

# Reply
$reply = $email.Reply()
$reply.Body = "Reply text`n" + $reply.Body
$reply.Send()

# Reply All
$replyAll = $email.ReplyAll()
$replyAll.Body = "Reply all text`n" + $replyAll.Body
$replyAll.Send()

# Forward
$fwd = $email.Forward()
$fwd.To = "someone@example.com"
$fwd.Body = "FYI`n" + $fwd.Body
$fwd.Send()
```

---

## Calendar Operations

### Create an Appointment (no attendees)

```powershell
$appt = $outlook.CreateItem(1)
$appt.Subject = "My Appointment"
$appt.Body = "Description here"
$appt.Start = [DateTime]"2026-03-15 10:00"
$appt.Duration = 60  # minutes
$appt.Location = "Room 101"
$appt.ReminderSet = $true
$appt.ReminderMinutesBeforeStart = 15
$appt.Save()
Write-Host "Appointment created: $($appt.Subject) at $($appt.Start)"
```

### Create a Meeting (with attendees)

```powershell
$meeting = $outlook.CreateItem(1)
$meeting.MeetingStatus = 1  # olMeeting
$meeting.Subject = "Team Sync"
$meeting.Body = "Weekly sync meeting"
$meeting.Start = [DateTime]"2026-03-15 14:00"
$meeting.Duration = 30
$meeting.Location = "Conference Room A"

# Add required attendees
$meeting.Recipients.Add("attendee1@example.com")
$meeting.Recipients.Add("attendee2@example.com")

# Add optional attendee
$optionalAttendee = $meeting.Recipients.Add("optional@example.com")
$optionalAttendee.Type = 2  # olOptional (1=Required, 2=Optional, 3=Resource)

$meeting.Recipients.ResolveAll()

# Set as Teams meeting (if Teams add-in is available):
# $meeting.Location = "Microsoft Teams Meeting"

$meeting.Send()  # Use .Save() to save without sending invites
Write-Host "Meeting invitation sent: $($meeting.Subject)"
```

### Create a Recurring Meeting

```powershell
$meeting = $outlook.CreateItem(1)
$meeting.Subject = "Daily Standup"
$meeting.Start = [DateTime]"2026-03-16 09:00"
$meeting.Duration = 15

$recurrence = $meeting.GetRecurrencePattern()
$recurrence.RecurrenceType = 1  # 0=Daily, 1=Weekly, 2=Monthly, 3=MonthNth, 5=Yearly
$recurrence.Interval = 1
$recurrence.DayOfWeekMask = 62  # Mon-Fri (2+4+8+16+32)
$recurrence.PatternStartDate = [DateTime]"2026-03-16"
$recurrence.PatternEndDate = [DateTime]"2026-06-30"

$meeting.Save()
Write-Host "Recurring meeting created"
```

### List Upcoming Calendar Events

```powershell
$calendar = $namespace.GetDefaultFolder(9)
$items = $calendar.Items
$items.Sort("[Start]")
$items.IncludeRecurrences = $true

$startDate = (Get-Date).ToString("MM/dd/yyyy")
$endDate = (Get-Date).AddDays(7).ToString("MM/dd/yyyy")
$filter = "[Start] >= '$startDate' AND [Start] <= '$endDate'"
$upcoming = $items.Restrict($filter)

foreach ($event in $upcoming) {
    Write-Host "$($event.Start) - $($event.End) | $($event.Subject) | $($event.Location)"
}
```

### Find and Modify a Meeting

```powershell
$calendar = $namespace.GetDefaultFolder(9)
$filter = "@SQL=""urn:schemas:httpmail:subject"" = 'Team Sync'"
$found = $calendar.Items.Restrict($filter)

if ($found.Count -gt 0) {
    $meeting = $found.GetFirst()
    $meeting.Start = [DateTime]"2026-03-15 15:00"  # Reschedule
    $meeting.Duration = 45
    $meeting.Save()  # or $meeting.Send() to notify attendees
    Write-Host "Meeting updated"
}
```

### Delete/Cancel a Meeting

```powershell
$calendar = $namespace.GetDefaultFolder(9)
$filter = "[Subject] = 'Team Sync'"
$found = $calendar.Items.Restrict($filter)

if ($found.Count -gt 0) {
    $meeting = $found.GetFirst()
    $meeting.Delete()
    Write-Host "Meeting deleted"
}
```

---

## Contact Operations

### Create a Contact

```powershell
$contact = $outlook.CreateItem(2)
$contact.FullName = "John Doe"
$contact.Email1Address = "john.doe@example.com"
$contact.BusinessTelephoneNumber = "+1-555-0100"
$contact.CompanyName = "Contoso"
$contact.JobTitle = "Engineer"
$contact.Save()
```

### Search Contacts

```powershell
$contacts = $namespace.GetDefaultFolder(10)
$filter = "[FullName] = 'John Doe'"
$results = $contacts.Items.Restrict($filter)
foreach ($c in $results) {
    Write-Host "$($c.FullName) - $($c.Email1Address)"
}
```

---

## Task Operations

### Create a Task

```powershell
$task = $outlook.CreateItem(3)
$task.Subject = "Review PR #42"
$task.Body = "Review and approve the pull request"
$task.DueDate = (Get-Date).AddDays(2)
$task.Importance = 2  # 0=Low, 1=Normal, 2=High
$task.Save()
```

---

## Folder Operations

### List All Folders

```powershell
function List-OutlookFolders($folder, $indent = 0) {
    $prefix = " " * $indent
    Write-Host "$prefix$($folder.Name) ($($folder.Items.Count) items)"
    foreach ($subfolder in $folder.Folders) {
        List-OutlookFolders $subfolder ($indent + 2)
    }
}

$root = $namespace.Folders
foreach ($store in $root) {
    List-OutlookFolders $store
}
```

### Move Email to Folder

```powershell
$inbox = $namespace.GetDefaultFolder(6)
$targetFolder = $inbox.Folders.Item("Archive")  # subfolder of Inbox
$email = $inbox.Items.GetFirst()
$email.Move($targetFolder)
```

---

## Tips and Error Handling

- **Security prompts**: Outlook may show security dialogs when accessing certain properties (like `.Body` of emails from external senders). This is by design.
- **COM cleanup**: After heavy COM usage, release objects:
  ```powershell
  [System.Runtime.InteropServices.Marshal]::ReleaseComObject($outlook) | Out-Null
  ```
- **Outlook must be running**: The COM object connects to a running Outlook instance or starts one. Ensure Outlook is configured with an account.
- **Date formats**: Use the system's date format or explicit `[DateTime]` casting to avoid locale issues.
- **Large mailboxes**: Use `.Restrict()` filters instead of iterating all items for performance.
- **Error handling pattern**:
  ```powershell
  try {
      $outlook = New-Object -ComObject Outlook.Application
      # ... operations ...
  } catch {
      Write-Error "Outlook COM error: $_"
  }
  ```
