# Email Pipeline Setup Guide - Issue #259

**Status:** Ready for Implementation  
**Decision Date:** 2025-06-08  
**Decision Maker:** Picard (Lead)  
**Estimated Setup Time:** 20-25 minutes

## Overview

This guide provides step-by-step instructions to create a family email automation system using a Microsoft 365 shared mailbox and Power Automate flows. The system will route emails from Gabi (wife) to different handlers based on keywords.

## Architecture Summary

- **Shared Mailbox:** `family-requests@microsoft.com`
- **Authorized Sender:** gabrielayael@gmail.com only
- **Handlers:** 4 Power Automate flows (print, calendar, reminder, general)
- **Security:** All flows validate sender before processing

---

## Part 1: Create the Shared Mailbox

**Location:** Microsoft 365 Admin Center → Teams & groups → Shared mailboxes

### Steps

1. **Navigate to Shared Mailboxes**
   - Go to https://admin.microsoft.com
   - Select **Teams & groups** → **Shared mailboxes**
   - Click **+ Add a shared mailbox**

2. **Configure Basic Settings**
   - **Name:** Family Requests
   - **Email address:** family-requests
   - **Domain:** @microsoft.com (auto-selected)
   - Click **Add**

3. **Add Yourself as a Member**
   - Once created, click on **Family Requests**
   - Go to **Members** tab
   - Click **+ Add members**
   - Search for and add: **Tamir Dresher** (tamirdresher@microsoft.com)
   - Set permission: **Full access** and **Send as**

4. **Configure Send Permissions**
   - Remain in the mailbox settings
   - Verify **Send as** permission is enabled for your account
   - This allows Power Automate to send replies from the shared mailbox

5. **Test Access**
   - Open Outlook (web or desktop)
   - Look for **Family Requests** in your folder list (may take 2-3 minutes)
   - Send a test email to family-requests@microsoft.com from your personal account
   - Verify it arrives in the shared mailbox

**Completion Check:** ✅ Shared mailbox visible in Outlook, test email received

---

## Part 2: Create Power Automate Flows

**Location:** https://make.powerautomate.com

### Important: Connection Setup (Do Once)

Before creating flows:
1. Go to **Data** → **Connections**
2. Ensure you have connections for:
   - **Office 365 Outlook** (connected as tamirdresher@microsoft.com)
   - **Office 365 Users** (for validation)
3. If missing, create them now

---

## Flow 1: Print Handler

**Purpose:** Route print jobs to the home printer

### Trigger
- **Type:** When a new email arrives (V3)
- **Mailbox address:** family-requests@microsoft.com
- **Folder:** Inbox
- **Subject filter:** `@print`
- **Include attachments:** Yes

### Flow Definition

```
TRIGGER: When a new email arrives (V3)
├─ Mailbox: family-requests@microsoft.com
├─ Folder: Inbox
├─ Subject Filter: @print
└─ Include Attachments: Yes

CONDITION: Check sender is authorized
├─ Field: triggerOutputs()?['body/from']
├─ Operator: contains
└─ Value: gabrielayael@gmail.com

IF YES:
│
├─ ACTION: Forward email
│  ├─ To: Dresherhome@hpeprint.com
│  ├─ Subject: @{triggerOutputs()?['body/subject']}
│  ├─ Body: @{triggerOutputs()?['body/body']}
│  └─ Attachments: @{triggerOutputs()?['body/attachments']}
│
└─ ACTION: Send confirmation reply
   ├─ To: @{triggerOutputs()?['body/from']}
   ├─ From: family-requests@microsoft.com
   ├─ Subject: ✅ Print job sent
   └─ Body: 
      Your print job has been forwarded to the home printer.
      Subject: @{triggerOutputs()?['body/subject']}
      Attachments: @{length(triggerOutputs()?['body/attachments'])} file(s)

IF NO:
│
└─ ACTION: Send rejection reply
   ├─ To: @{triggerOutputs()?['body/from']}
   ├─ From: family-requests@microsoft.com
   ├─ Subject: ⛔ Unauthorized sender
   └─ Body: 
      This mailbox only accepts emails from authorized senders.
      Your email was not processed.
```

### Step-by-Step Creation

1. **Create New Flow**
   - Click **+ Create** → **Automated cloud flow**
   - Name: `Family Print Handler`
   - Skip trigger selection (we'll add manually)

2. **Add Trigger**
   - Search: `When a new email arrives V3`
   - Select **Office 365 Outlook**
   - Configure:
     - Mailbox Address: `family-requests@microsoft.com`
     - Folder: `Inbox`
     - Click **Show advanced options**
     - Subject Filter: `@print`
     - Include Attachments: `Yes`

3. **Add Condition**
   - Click **+ New step** → **Condition**
   - Left side: Click in field → **Expression** tab → Enter:
     ```
     triggerOutputs()?['body/from']
     ```
   - Operator: `contains`
   - Right side: `gabrielayael@gmail.com`

4. **Configure "If yes" Branch**
   
   **Action 1: Forward to Printer**
   - Click **Add an action** under "If yes"
   - Search: `Send an email V2`
   - Select **Office 365 Outlook**
   - Configure:
     - To: `Dresherhome@hpeprint.com`
     - Subject: Click → **Expression** → `triggerOutputs()?['body/subject']`
     - Body: Click → **Expression** → `triggerOutputs()?['body/body']`
     - Click **Show advanced options**
     - Attachments: Click → **Expression** → `triggerOutputs()?['body/attachments']`
     - From (Send as): `family-requests@microsoft.com`

   **Action 2: Send Confirmation**
   - Click **Add an action**
   - Search: `Send an email V2`
   - Configure:
     - To: Click → **Expression** → `triggerOutputs()?['body/from']`
     - From (Send as): `family-requests@microsoft.com`
     - Subject: `✅ Print job sent`
     - Body:
       ```
       Your print job has been forwarded to the home printer.
       
       Subject: {Dynamic content: Subject from trigger}
       
       The document will print shortly at Dresher Home.
       ```

5. **Configure "If no" Branch**
   - Click **Add an action** under "If no"
   - Search: `Send an email V2`
   - Configure:
     - To: Click → **Expression** → `triggerOutputs()?['body/from']`
     - From (Send as): `family-requests@microsoft.com`
     - Subject: `⛔ Unauthorized sender`
     - Body:
       ```
       This mailbox only accepts emails from authorized senders.
       Your email was not processed.
       
       If you believe this is an error, please contact Tamir.
       ```

6. **Save and Test**
   - Click **Save** (top right)
   - Send test email from gabrielayael@gmail.com to family-requests@microsoft.com
   - Subject: `@print Test document`
   - Verify: Confirmation received, printer receives email

---

## Flow 2: Calendar Event Handler

**Purpose:** Create calendar events from email requests

### Trigger
- **Type:** When a new email arrives (V3)
- **Mailbox address:** family-requests@microsoft.com
- **Folder:** Inbox
- **Subject filter:** `@calendar`

### Flow Definition

```
TRIGGER: When a new email arrives (V3)
├─ Mailbox: family-requests@microsoft.com
├─ Folder: Inbox
└─ Subject Filter: @calendar

CONDITION: Check sender is authorized
├─ Field: triggerOutputs()?['body/from']
├─ Operator: contains
└─ Value: gabrielayael@gmail.com

IF YES:
│
├─ ACTION: Create calendar event
│  ├─ Calendar: Tamir's primary calendar
│  ├─ Subject: @{triggerOutputs()?['body/subject']} (without @calendar)
│  ├─ Start time: Parse from email body or default to tomorrow 9 AM
│  ├─ End time: Start time + 1 hour
│  ├─ Body: @{triggerOutputs()?['body/body']}
│  └─ Location: From email body if specified
│
└─ ACTION: Send confirmation reply
   ├─ To: @{triggerOutputs()?['body/from']}
   ├─ From: family-requests@microsoft.com
   ├─ Subject: ✅ Calendar event created
   └─ Body: 
      Calendar event has been created.
      Event: @{triggerOutputs()?['body/subject']}
      When: @{outputs('Create_event')?['body/start']}

IF NO:
│
└─ ACTION: Send rejection reply (same as Flow 1)
```

### Step-by-Step Creation

1. **Create New Flow**
   - Name: `Family Calendar Handler`
   - Add trigger: `When a new email arrives V3`
   - Mailbox: `family-requests@microsoft.com`
   - Subject Filter: `@calendar`

2. **Add Condition** (Same as Flow 1)
   - Sender contains `gabrielayael@gmail.com`

3. **Configure "If yes" Branch**
   
   **Action 1: Create Calendar Event**
   - Search: `Create event V4`
   - Select **Office 365 Outlook**
   - Configure:
     - Calendar id: (Select your primary calendar)
     - Subject: Click → **Expression** → 
       ```
       replace(triggerOutputs()?['body/subject'], '@calendar', '')
       ```
     - Start time: Click → **Expression** → 
       ```
       addDays(utcNow(), 1, 'yyyy-MM-ddT09:00:00')
       ```
       *(Tomorrow at 9 AM - Gabi can override by specifying date/time in email body)*
     - End time: Click → **Expression** → 
       ```
       addDays(utcNow(), 1, 'yyyy-MM-ddT10:00:00')
       ```
     - Body: Dynamic content → **Body** from trigger
     - Time zone: `(UTC+02:00) Jerusalem`

   **Action 2: Send Confirmation**
   - Search: `Send an email V2`
   - Configure:
     - To: Expression → `triggerOutputs()?['body/from']`
     - From: `family-requests@microsoft.com`
     - Subject: `✅ Calendar event created`
     - Body:
       ```
       Your calendar event has been created.
       
       Event: {Dynamic: Subject from Create event action}
       When: {Dynamic: Start from Create event action}
       
       Check Tamir's calendar for details.
       ```

4. **Configure "If no" Branch** (Same as Flow 1)

5. **Save and Test**

**Enhancement Note:** For more sophisticated date/time parsing from email body, add an intermediate step using AI Builder's "Extract information from text" action to parse natural language dates like "next Thursday at 3 PM".

---

## Flow 3: Reminder Handler

**Purpose:** Create tasks/reminders in Microsoft To Do

### Trigger
- **Type:** When a new email arrives (V3)
- **Mailbox address:** family-requests@microsoft.com
- **Folder:** Inbox
- **Subject filter:** `@reminder`

### Flow Definition

```
TRIGGER: When a new email arrives (V3)
├─ Mailbox: family-requests@microsoft.com
├─ Folder: Inbox
└─ Subject Filter: @reminder

CONDITION: Check sender is authorized
├─ Field: triggerOutputs()?['body/from']
├─ Operator: contains
└─ Value: gabrielayael@gmail.com

IF YES:
│
├─ ACTION: Create To Do task
│  ├─ List: Tasks (default list)
│  ├─ Title: @{triggerOutputs()?['body/subject']} (without @reminder)
│  ├─ Body: @{triggerOutputs()?['body/body']}
│  └─ Due date: Tomorrow
│
└─ ACTION: Send confirmation reply
   ├─ To: @{triggerOutputs()?['body/from']}
   ├─ From: family-requests@microsoft.com
   ├─ Subject: ✅ Reminder created
   └─ Body: 
      Reminder has been created in Tamir's To Do list.
      Task: @{triggerOutputs()?['body/subject']}
      Due: Tomorrow

IF NO:
│
└─ ACTION: Send rejection reply (same as Flow 1)
```

### Step-by-Step Creation

1. **Create New Flow**
   - Name: `Family Reminder Handler`
   - Add trigger: `When a new email arrives V3`
   - Mailbox: `family-requests@microsoft.com`
   - Subject Filter: `@reminder`

2. **Add Connection for Microsoft To Do**
   - When adding the create task action, you'll need to authorize connection
   - Use your tamirdresher@microsoft.com account

3. **Add Condition** (Same as Flow 1)

4. **Configure "If yes" Branch**
   
   **Action 1: Create To Do Task**
   - Search: `Create a task`
   - Select **Microsoft To Do**
   - Configure:
     - List: `Tasks` (or create a new list called "Family Requests")
     - Title: Expression → 
       ```
       replace(triggerOutputs()?['body/subject'], '@reminder', '')
       ```
     - Body: Dynamic content → **Body** from trigger
     - Due date: Expression → 
       ```
       addDays(utcNow(), 1, 'yyyy-MM-dd')
       ```
     - Importance: `normal`

   **Action 2: Send Confirmation**
   - Search: `Send an email V2`
   - Configure:
     - To: Expression → `triggerOutputs()?['body/from']`
     - From: `family-requests@microsoft.com`
     - Subject: `✅ Reminder created`
     - Body:
       ```
       Your reminder has been created in Tamir's To Do list.
       
       Task: {Dynamic: Title from Create task action}
       Due: Tomorrow
       
       Tamir will see this in his To Do app.
       ```

5. **Configure "If no" Branch** (Same as Flow 1)

6. **Save and Test**

---

## Flow 4: General Handler

**Purpose:** Forward general messages to Tamir and notify Gabi

### Trigger
- **Type:** When a new email arrives (V3)
- **Mailbox address:** family-requests@microsoft.com
- **Folder:** Inbox
- **NO subject filter** (catches everything without keywords)

### Flow Definition

```
TRIGGER: When a new email arrives (V3)
├─ Mailbox: family-requests@microsoft.com
└─ Folder: Inbox

CONDITION: Check sender is authorized
├─ Field: triggerOutputs()?['body/from']
├─ Operator: contains
└─ Value: gabrielayael@gmail.com

IF YES:
│
├─ CONDITION: Check if already handled by other flows
│  ├─ Field: triggerOutputs()?['body/subject']
│  ├─ Operator: does not contain
│  └─ Values: @print, @calendar, @reminder
│
│  IF YES (general message):
│  │
│  ├─ ACTION: Forward to Tamir
│  │  ├─ To: tamirdresher@microsoft.com
│  │  ├─ Subject: [Family] @{triggerOutputs()?['body/subject']}
│  │  ├─ Body: 
│  │  │  From: Gabi (gabrielayael@gmail.com)
│  │  │  ---
│  │  │  @{triggerOutputs()?['body/body']}
│  │  └─ Mark as important: Yes
│  │
│  └─ ACTION: Send confirmation reply
│     ├─ To: @{triggerOutputs()?['body/from']}
│     ├─ From: family-requests@microsoft.com
│     ├─ Subject: ✅ Message forwarded to Tamir
│     └─ Body: 
│        Your message has been forwarded to Tamir.
│        He will see it in his primary inbox.
│        
│        For faster handling, use keywords:
│        @print - Print documents
│        @calendar - Create calendar event
│        @reminder - Create reminder/task
│
│  IF NO (handled by other flow):
│  │
│  └─ ACTION: Do nothing (other flow will handle)

IF NO (unauthorized sender):
│
└─ ACTION: Send rejection reply (same as Flow 1)
```

### Step-by-Step Creation

1. **Create New Flow**
   - Name: `Family General Handler`
   - Add trigger: `When a new email arrives V3`
   - Mailbox: `family-requests@microsoft.com`
   - **Important:** Leave Subject Filter EMPTY

2. **Add Condition 1: Check Authorization** (Same as Flow 1)

3. **Add Condition 2: Check Not Already Handled**
   - Under "If yes" branch, add **New step** → **Condition**
   - Configure as compound condition:
     - Left: Expression → `triggerOutputs()?['body/subject']`
     - Operator: `does not contain`
     - Right: `@print`
     - Click **Add** → **And**
     - Left: Expression → `triggerOutputs()?['body/subject']`
     - Operator: `does not contain`
     - Right: `@calendar`
     - Click **Add** → **And**
     - Left: Expression → `triggerOutputs()?['body/subject']`
     - Operator: `does not contain`
     - Right: `@reminder`

4. **Configure Inner "If yes" Branch** (general message)
   
   **Action 1: Forward to Tamir**
   - Search: `Send an email V2`
   - Configure:
     - To: `tamirdresher@microsoft.com`
     - Subject: Expression → 
       ```
       concat('[Family] ', triggerOutputs()?['body/subject'])
       ```
     - Body: Expression and Dynamic content → 
       ```
       From: Gabi (gabrielayael@gmail.com)
       Received: {Dynamic: Received Time}
       
       ---
       
       {Dynamic: Body from trigger}
       ```
     - Importance: `High`

   **Action 2: Send Confirmation**
   - Search: `Send an email V2`
   - Configure:
     - To: Expression → `triggerOutputs()?['body/from']`
     - From: `family-requests@microsoft.com`
     - Subject: `✅ Message forwarded to Tamir`
     - Body:
       ```
       Your message has been forwarded to Tamir's inbox.
       He will see it marked as important.
       
       💡 TIP: For faster automated handling, use keywords in subject:
       • @print - Print documents at home
       • @calendar - Create calendar event
       • @reminder - Create task/reminder
       
       Example: "@calendar Doctor appointment next Monday 2 PM"
       ```

5. **Configure Inner "If no" Branch** (already handled)
   - Leave empty or add a **Terminate** action with status "Succeeded"
   - This branch is reached when subject contains @print, @calendar, or @reminder
   - Those emails are handled by the specialized flows

6. **Configure Outer "If no" Branch** (unauthorized sender)
   - Same rejection email as Flow 1

7. **Important: Set Flow Priority**
   - After saving, go to flow settings
   - This flow should run LAST (after the other 3 flows complete)
   - Consider adding a 30-second delay at the start to ensure specialized flows run first

8. **Save and Test**
   - Test with a regular email (no keywords)
   - Test with email containing @print (should be handled by print flow, this flow should terminate)

---

## Part 3: Testing the Complete System

### Test Matrix

| Test Case | From | Subject | Expected Result | Verification |
|-----------|------|---------|-----------------|--------------|
| Print job | gabrielayael@gmail.com | @print Monthly bills | ✅ Forwarded to printer + confirmation | Check printer, check Gabi's inbox |
| Calendar | gabrielayael@gmail.com | @calendar Family dinner Friday | ✅ Event created + confirmation | Check calendar, check Gabi's inbox |
| Reminder | gabrielayael@gmail.com | @reminder Buy milk | ✅ To Do task created + confirmation | Check To Do, check Gabi's inbox |
| General | gabrielayael@gmail.com | Don't forget the keys | ✅ Forwarded to Tamir + confirmation | Check Tamir's inbox, check Gabi's inbox |
| Unauthorized | random@gmail.com | Any subject | ⛔ Rejection email | Check rejection received |
| Multiple keywords | gabrielayael@gmail.com | @print @calendar | ⚠️ Print flow handles (first match) | Should go to printer |

### Testing Procedure

1. **Enable All Flows**
   - Go to https://make.powerautomate.com
   - Verify all 4 flows show "On" status
   - If any are off, click flow → **Turn on**

2. **Run Test Cases**
   - Send each test email from Gabi's account (gabrielayael@gmail.com)
   - Wait 30-60 seconds for processing
   - Verify expected results

3. **Check Flow Run History**
   - For each test, click on the flow in Power Automate
   - Click on the run history entry
   - Verify all actions completed successfully (green checkmarks)
   - If any action failed, click on it to see error details

4. **Troubleshooting Common Issues**
   
   **Issue:** Flow doesn't trigger
   - Check: Is flow enabled?
   - Check: Is shared mailbox accessible in Outlook?
   - Check: Did email arrive in Inbox folder?
   
   **Issue:** "Send as" permission denied
   - Fix: Go back to M365 Admin Center → Shared mailbox → Members
   - Ensure "Send as" permission is checked for your account
   - Wait 5-10 minutes for permission propagation
   
   **Issue:** Condition not working
   - Check: Sender email exact match (case-insensitive)
   - Debug: Add a "Compose" action before condition to see actual sender value
   
   **Issue:** Multiple flows handling same email
   - Fix: Ensure General Handler has 30-second delay at start
   - Or: Add unique subject requirements (specialized flows run first by default)

---

## Part 4: Security & Maintenance

### Security Considerations

1. **Sender Validation**
   - ✅ All flows check sender = gabrielayael@gmail.com
   - ⚠️ This is email-level validation (spoofing possible but unlikely)
   - 🔒 For higher security, enable M365 transport rules to block spoofed external emails

2. **Data Access**
   - ✅ Shared mailbox is only accessible to Tamir
   - ✅ Power Automate runs under Tamir's account with his permissions
   - ⚠️ If adding more members, ensure they're trusted

3. **Printer Security**
   - ⚠️ Emails forwarded to Dresherhome@hpeprint.com are processed by HP cloud
   - ✅ Printer only prints emails from registered senders (configure in HP ePrint settings)

### Maintenance Tasks

**Weekly:**
- Check flow run history for failures
- Review shared mailbox for stuck emails

**Monthly:**
- Review calendar events created (ensure accuracy)
- Check To Do list for completed reminders

**As Needed:**
- Add more authorized senders (update all 4 flows)
- Adjust calendar default times
- Add more keyword handlers

### Adding More Authorized Senders

If you want to add more family members:

1. Update **all 4 flows**:
   - Edit condition → Change to:
     ```
     @or(
       contains(triggerOutputs()?['body/from'], 'gabrielayael@gmail.com'),
       contains(triggerOutputs()?['body/from'], 'newfamily@example.com')
     )
     ```

2. Or create a SharePoint list of authorized senders and check against it:
   - More scalable for 3+ senders
   - Centralized management

---

## Part 5: Future Enhancements

### Easy Wins (15 min each)

1. **Natural Language Date Parsing for Calendar**
   - Add AI Builder's "GPT for text" action
   - Parse phrases like "next Thursday at 3 PM" from email body
   - Use parsed date for event creation

2. **Attachment Validation for Print**
   - Add condition to check attachment count > 0
   - Send error message if @print used without attachments

3. **Reminder Priority Levels**
   - Parse "high", "medium", "low" from subject
   - Map to To Do importance levels

### Advanced Features (1-2 hours each)

1. **Smart Routing with AI**
   - Use AI Builder to analyze email body
   - Auto-suggest keywords if none provided
   - Send preview: "Looks like a calendar request - resend with @calendar?"

2. **Calendar Conflict Detection**
   - Before creating event, check for existing events at that time
   - Send confirmation: "Conflict detected with [existing event]. Create anyway?"

3. **Receipt/Document Archiving**
   - Add @receipt keyword
   - Save attachments to OneDrive/SharePoint folder
   - Apply metadata for easy search

4. **Family Dashboard**
   - Create Power Apps app
   - Show recent requests, status, statistics
   - Allow Gabi to track what's been processed

---

## Summary

**What You've Built:**
- 1 shared mailbox: `family-requests@microsoft.com`
- 4 Power Automate flows handling print, calendar, reminders, and general messages
- Security validation on all flows
- Confirmation emails for all actions

**Email Address for Gabi:** `family-requests@microsoft.com`

**Keywords:**
- `@print` - Print documents
- `@calendar` - Create calendar event
- `@reminder` - Create task/reminder
- No keyword - Forward to Tamir

**Total Setup Time:** 20-25 minutes  
**Ongoing Maintenance:** < 5 minutes/month  
**Cost:** $0 (included in M365 license)

---

## Support & Troubleshooting

**Flow Run History:** https://make.powerautomate.com → My flows → [Flow name] → Run history

**Common Fixes:**
- Flow not triggering: Check it's enabled and mailbox is accessible
- Permission errors: Verify "Send as" permission on shared mailbox
- Wrong handling: Check subject keywords and flow order

**Questions?** Review flow run history first - it shows exactly what happened and why.

---

**Document Version:** 1.0  
**Last Updated:** 2025-06-08  
**Owner:** Picard (Lead, Squad)  
**Related Issue:** #259
