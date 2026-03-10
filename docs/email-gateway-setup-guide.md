# Email Gateway Setup Guide — Power Automate + Shared Mailbox

> **Issue:** #259  
> **Goal:** Create an email address your wife can use to trigger actions: print, calendar events, reminders, and general requests.  
> **Time to complete:** ~30 minutes  
> **Prerequisites:** Microsoft 365 admin access, Power Automate license (included with M365)

---

## Architecture Overview

```
Wife sends email to: tamir.requests@<yourdomain>.com
         │
         ▼
   Shared Mailbox (Exchange Online)
         │
         ▼
   Power Automate checks keywords in subject
         │
    ┌────┼────────┬──────────────┐
    ▼    ▼        ▼              ▼
  Print  Calendar  Reminder    Catch-all
  Flow   Flow      Flow        (GitHub Issue)
    │      │         │              │
    ▼      ▼         ▼              ▼
Forward  Create    Create        Create
to HP    Outlook   To Do         GitHub
ePrint   Event     Task          Issue
```

---

## Phase 1: Shared Mailbox + Core Flows

### Step 1: Create the Shared Mailbox

1. Go to **[Microsoft 365 Admin Center](https://admin.microsoft.com)**
2. In the left sidebar: **Teams & groups** → **Shared mailboxes**
3. Click **+ Add a shared mailbox**
4. Fill in:
   - **Name:** `Tamir Requests` (or whatever you prefer)
   - **Email address:** `tamir.requests` (choose your prefix)
5. Click **Add** → **Add members**
6. Add **yourself** (Tamir) as a member so you can monitor the mailbox
7. Click **Close**

> **📧 Note:** Write down the full email address (e.g., `tamir.requests@yourdomain.com`). This is what your wife will email.

#### Verify the Mailbox Works

1. Open **[Outlook Web](https://outlook.office.com)**
2. Right-click **Folders** in the left panel → **Add shared folder**
3. Type the shared mailbox email → **Add**
4. You should now see the shared mailbox under your folders
5. Send a test email to the shared mailbox from your personal account to verify it arrives

---

### Step 2: Create the Print Flow

This flow watches for emails with "print" in the subject and forwards attachments to your HP ePrint address.

1. Go to **[Power Automate](https://make.powerautomate.com)**
2. Click **+ Create** → **Automated cloud flow**
3. Name it: `Email Gateway - Print`
4. Search for trigger: **"When a new email arrives in a shared mailbox (V2)"**
5. Click **Create**

#### Configure the Trigger

6. In the trigger box, set:
   - **Original Mailbox Address:** `tamir.requests@yourdomain.com`
   - **Folder:** `Inbox`
   - **Include Attachments:** `Yes`
   - **Subject Filter:** `print`
   
7. Click **+ New step** → search for **"Condition"**
8. Set condition:
   - **Subject** → **contains** → `print`

#### "If yes" Branch

9. Inside the **If yes** branch, click **+ Add an action**
10. Search for: **"Send an email (V2)"** (Office 365 Outlook)
11. Configure:
    - **To:** `Dresherhome@hpeprint.com`
    - **Subject:** Click **Dynamic content** → select **Subject** (from the trigger)
    - **Body:** `Forwarded print request`
    - **Attachments:** Click **Dynamic content** → select **Attachments** (from the trigger)
    
    > ⚠️ If "Attachments" creates an "Apply to each" loop automatically, that's correct — it sends each attachment.

12. (Optional) Add another action: **"Send an email (V2)"** to send a confirmation back:
    - **To:** Click **Dynamic content** → select **From** 
    - **Subject:** `✅ Print request received`
    - **Body:** `Your document has been sent to the printer.`

13. Click **Save**

#### Test It

14. Send an email to the shared mailbox with subject: `print this document`
15. Attach a PDF
16. Check that it arrives at `Dresherhome@hpeprint.com` within a few minutes

---

### Step 3: Create the Calendar Flow

This flow creates Outlook calendar events from emails with calendar-related keywords.

1. Go to **[Power Automate](https://make.powerautomate.com)**
2. Click **+ Create** → **Automated cloud flow**
3. Name it: `Email Gateway - Calendar`
4. Trigger: **"When a new email arrives in a shared mailbox (V2)"**

#### Configure the Trigger

5. Set:
   - **Original Mailbox Address:** `tamir.requests@yourdomain.com`
   - **Folder:** `Inbox`

6. Click **+ New step** → **Condition**
7. Set condition (use **"Or"** group):
   - **Subject** → **contains** → `calendar`
   - **OR Subject** → **contains** → `meeting`
   - **OR Subject** → **contains** → `schedule`
   - **OR Subject** → **contains** → `event`

   > To add OR conditions: click **+ Add** → **Add row** inside the condition, then change the group from "And" to "Or" by clicking the toggle.

#### "If yes" Branch — Parse the Email

8. Inside **If yes**, add action: **"AI Builder - Extract information from text"** (or use a simpler approach below)

**Simple Approach (recommended):** Use the email subject for the event name and body for details:

8. Add action: **"Create event (V2)"** (Office 365 Outlook)
9. Configure:
   - **Calendar id:** `Calendar` (your default calendar)
   - **Subject:** Click **Dynamic content** → **Subject** (then strip the keyword prefix in an expression if desired)
   - **Start time:** You'll need to parse this from the email body (see parsing section below)
   - **End time:** Start time + 1 hour (default)
   - **Body:** Click **Dynamic content** → **Body**

#### Parsing Date/Time from Email Body

For the start time, use a **Compose** action with an expression. The simplest approach:

**Option A — Wife includes date in a standard format:**

Tell your wife to use this format in the email body:
```
Date: 2025-01-15
Time: 14:00
Duration: 1 hour
```

Then use these actions:
1. **Compose** (name it "Parse Date"): 
   ```
   Expression: first(split(last(split(body('When_a_new_email_arrives_in_a_shared_mailbox_(V2)')?['body'], 'Date:')), 'Time:'))
   ```

**Option B — Let AI parse it (easier, recommended):**

1. Add action: **"Create text with GPT using a prompt"** (AI Builder - may need premium)
   - Prompt: `Extract the date, time, and duration from this text. Return in JSON format {"date": "YYYY-MM-DD", "time": "HH:MM", "duration_hours": N}. Text: [Body dynamic content]`
2. Add action: **"Parse JSON"** with the output
3. Use parsed values in the **Create event** action

**Option C — Simple fixed-time approach (simplest):**

Just create the event with the subject line as the event name, put the body as notes, and set a default time. Then Tamir can adjust the time manually.

1. Add **Create event (V2)**:
   - **Subject:** Dynamic content → Subject
   - **Start time:** `utcNow()` (creates it for now — Tamir adjusts)
   - **End time:** Expression: `addHours(utcNow(), 1)`
   - **Body:** Dynamic content → Body
   - **Importance:** `Normal`

> 💡 **Recommendation:** Start with Option C. Your wife writes something like:  
> Subject: `calendar Dentist appointment`  
> Body: `Tuesday Jan 21 at 3pm, 1 hour`  
> The event gets created and you adjust the time. Simple and reliable.

10. (Optional) Add confirmation email back to sender.
11. Click **Save**

---

### Step 4: Create the Reminder/To Do Flow

This flow creates Microsoft To Do tasks from emails with reminder keywords.

1. Go to **[Power Automate](https://make.powerautomate.com)**
2. Click **+ Create** → **Automated cloud flow**
3. Name it: `Email Gateway - Reminders`
4. Trigger: **"When a new email arrives in a shared mailbox (V2)"**

#### Configure the Trigger

5. Set:
   - **Original Mailbox Address:** `tamir.requests@yourdomain.com`
   - **Folder:** `Inbox`

6. Click **+ New step** → **Condition**
7. Set condition (**Or** group):
   - **Subject** → **contains** → `remind`
   - **OR Subject** → **contains** → `todo`
   - **OR Subject** → **contains** → `task`
   - **OR Subject** → **contains** → `remember`

#### "If yes" Branch

8. Add action: **"Add a to-do (V2)"** (Microsoft To Do)
9. Configure:
   - **List:** `Tasks` (or create a dedicated list called "Wife Requests")
   - **Subject:** Dynamic content → **Subject** from trigger
   - **Body Content:** Dynamic content → **Body** from trigger
   - **Importance:** `Normal`
   - **Due Date:** (Optional) Expression: `addDays(utcNow(), 1)` for next day

10. (Optional) Add confirmation email back to sender.
11. Click **Save**

---

### Step 5: Set Up Sender Whitelist (Security)

Restrict the flows to only process emails from your wife's email address.

#### In Each Flow:

1. Open the flow in **Power Automate**
2. Click on the **trigger** step (When a new email arrives...)
3. In the trigger settings, add:
   - **From:** `wife-email@example.com` (replace with your wife's actual email)

This ensures only emails from her address trigger the flows.

#### Alternative — Add a Condition Step:

If the trigger filter doesn't work, add a **Condition** as the first step:
- **From** → **is equal to** → `wife-email@example.com`
- **If no** → **Terminate** (status: Cancelled)

> 🔒 **Important:** Without this filter, anyone who discovers the shared mailbox address could trigger actions.

---

## Phase 2: Squad Integration (Catch-All Flow)

### Step 6: Create the GitHub Issue Flow (Catch-All)

This flow catches any email that doesn't match print/calendar/reminder keywords and creates a GitHub issue for the Squad to process.

#### Option A: Using Power Automate's GitHub Connector (Recommended)

1. Go to **[Power Automate](https://make.powerautomate.com)**
2. Click **+ Create** → **Automated cloud flow**
3. Name it: `Email Gateway - Catch-All (GitHub)`
4. Trigger: **"When a new email arrives in a shared mailbox (V2)"**

#### Configure the Trigger

5. Set:
   - **Original Mailbox Address:** `tamir.requests@yourdomain.com`
   - **From:** `wife-email@example.com`

6. Add **Condition** to exclude already-handled keywords:
   - Use an **And** group with all conditions set to "does not contain":
   - **Subject** → **does not contain** → `print`
   - **AND Subject** → **does not contain** → `calendar`
   - **AND Subject** → **does not contain** → `meeting`
   - **AND Subject** → **does not contain** → `schedule`
   - **AND Subject** → **does not contain** → `event`
   - **AND Subject** → **does not contain** → `remind`
   - **AND Subject** → **does not contain** → `todo`
   - **AND Subject** → **does not contain** → `task`
   - **AND Subject** → **does not contain** → `remember`

#### "If yes" Branch — Create GitHub Issue

7. Add action: **"Create an issue"** (GitHub connector)
8. You'll need to sign in with your GitHub account the first time
9. Configure:
   - **Repository Owner:** `tamirdresher_microsoft` (or your GitHub org/user)
   - **Repository Name:** `tamresearch1`
   - **Title:** Expression: `concat('📧 Wife Request: ', triggerOutputs()?['body/subject'])`
   - **Body:** Use this template:

```
## Request from Wife (via Email Gateway)

**From:** [From dynamic content]
**Date:** [Received Time dynamic content]
**Subject:** [Subject dynamic content]

### Request Details

[Body dynamic content]

---
*This issue was automatically created by the Email Gateway (Power Automate).*
*Original email is in the shared mailbox for reference.*

/cc @tamirdresher_microsoft
```

   - **Labels:** Add label `squad` and `email-gateway` (create these labels first in GitHub)

10. (Optional) Add confirmation email:
    - **To:** Dynamic content → From
    - **Subject:** `✅ Request received — GitHub issue created`
    - **Body:** `Your request has been logged and the Squad will process it.`

11. Click **Save**

#### Option B: Using HTTP Connector (if GitHub connector isn't available)

If the GitHub connector isn't in your Power Automate plan:

7. Add action: **"HTTP"**
8. Configure:
   - **Method:** `POST`
   - **URI:** `https://api.github.com/repos/tamirdresher_microsoft/tamresearch1/issues`
   - **Headers:**
     ```
     Authorization: Bearer ghp_YOUR_PERSONAL_ACCESS_TOKEN
     Accept: application/vnd.github.v3+json
     Content-Type: application/json
     ```
   - **Body:**
     ```json
     {
       "title": "📧 Wife Request: @{triggerOutputs()?['body/subject']}",
       "body": "## Request from Wife\n\n**Date:** @{triggerOutputs()?['body/receivedDateTime']}\n\n### Details\n\n@{triggerOutputs()?['body/bodyPreview']}\n\n---\n*Auto-created by Email Gateway*",
       "labels": ["squad", "email-gateway"]
     }
     ```

> ⚠️ **Security:** If using Option B, store the GitHub token as a Power Automate secret/environment variable, not directly in the flow.

---

## Testing Checklist

After setting up all flows, test each one:

| # | Test | Email Subject | Expected Result | ✅ |
|---|------|--------------|-----------------|-----|
| 1 | Print | `print grocery list` + attach PDF | PDF forwarded to `Dresherhome@hpeprint.com` | ☐ |
| 2 | Calendar | `calendar Dentist Jan 21 3pm` | Outlook event created | ☐ |
| 3 | Reminder | `remind Pick up dry cleaning` | To Do task created | ☐ |
| 4 | Task | `todo Buy birthday gift` | To Do task created | ☐ |
| 5 | Catch-all | `Can you fix the kitchen light?` | GitHub issue created | ☐ |
| 6 | Wrong sender | (Send from different email) | No action triggered | ☐ |
| 7 | Confirmation | Any of above | Sender gets confirmation reply | ☐ |

---

## Troubleshooting

### Flow not triggering?
- **Check the shared mailbox address** is exactly right in the trigger
- **Check the From filter** — make sure your wife's email matches exactly
- **Wait 5 minutes** — shared mailbox triggers can have a slight delay
- Go to **Power Automate** → **My flows** → click the flow → **Run history** to see if it ran and any errors

### Email arrives but no action?
- Check **Run history** for the flow — click the failed run to see which step failed
- Verify the **condition** — check if the subject keyword matching is case-sensitive (it shouldn't be by default)
- For the Calendar flow: check date parsing

### GitHub issue not created?
- **GitHub connector:** Make sure your GitHub connection is still authorized
- **HTTP connector:** Check the token hasn't expired
- Check the repository name is correct

### Attachments not forwarding?
- Make sure **Include Attachments** is set to `Yes` in the trigger
- Check the attachment size — HP ePrint may have limits (usually 10MB)

### Too many triggers / duplicate actions?
- Each flow should have the keyword filter in the **trigger** (not just in conditions)
- This prevents the flow from running at all for non-matching emails

---

## Maintenance

- **Monthly:** Check Power Automate → **My flows** to ensure all flows show "On"
- **If wife changes email:** Update the From filter in all 4 flows
- **If HP ePrint address changes:** Update the Print flow's To address
- **GitHub token expiry (Option B only):** Rotate every 90 days

---

## Optional Enhancements (Future)

1. **Smart parsing with AI Builder:** Use GPT to parse natural language dates for calendar events
2. **Teams notification:** Add a Teams message step so Tamir sees requests in real-time
3. **Priority support:** If subject contains "urgent", set high importance on tasks/events
4. **Photo sharing:** Forward photos to OneDrive automatically
5. **Shopping list:** "buy" keyword → add to Microsoft To Do shopping list
