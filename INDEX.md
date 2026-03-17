# Infrastructure Setup - Complete Index

**Prepared by:** B'Elanna, Infrastructure Engineer  
**Date:** 2026-03-16  
**Status:** READY FOR IMPLEMENTATION

---

## 📑 Documentation Overview

This infrastructure setup package contains everything needed to complete three integration tasks. Start with the guide below and follow the documentation appropriate for each task.

### Quick Navigation

| Task | Status | Read First | Estimated Time |
|------|--------|-----------|-----------------|
| **1. Gumroad Verification** | Manual | [Task 1](#task-1) | 5-10 min |
| **2. YouTube Gmail** | Manual | [Task 2](#task-2) | 10-15 min |
| **3. Squad Email SMTP** | Scripts Ready | [Task 3](#task-3) | 5-10 min |

---

## 📄 Primary Documents

### Main Setup Guide
**File:** `INFRASTRUCTURE_SETUP_GUIDE.md`  
**Size:** 6.9 KB  
**Type:** Markdown  
**Purpose:** Complete step-by-step guide for all three tasks  
**Contains:**
- Detailed setup instructions for each task
- Account details and credential information
- Troubleshooting guide
- Security best practices
- Helper script documentation

**→ START HERE** if you're new to this setup

---

### Status Report
**File:** `BELANNA_INFRASTRUCTURE_REPORT.md`  
**Size:** 6.6 KB  
**Type:** Markdown  
**Purpose:** Engineering report with findings and analysis  
**Contains:**
- Task-by-task status
- Blockers and workarounds
- Files created
- Next steps for each task
- Security considerations

**→ READ THIS** to understand what was attempted and why

---

### Quick Checklist
**File:** `INFRASTRUCTURE_SETUP_CHECKLIST.txt`  
**Size:** 3.7 KB  
**Type:** Text  
**Purpose:** Printable checklist for tracking progress  
**Contains:**
- Checkbox format for each task
- Verification criteria
- Timeboxed estimates
- Quick troubleshooting reference

**→ USE THIS** while completing the tasks

---

### Executive Summary
**File:** `INFRASTRUCTURE_SETUP_SUMMARY.txt`  
**Size:** 2 KB  
**Type:** Text  
**Purpose:** One-page overview and action items  
**Contains:**
- Status of each task
- Manual action requirements
- Script availability
- Quick reference

**→ SCAN THIS** for quick overview

---

## 🔧 Helper Scripts

Located in: `scripts/`

### 1. setup-squad-credentials.ps1
**Purpose:** Store Squad email app password in Credential Manager  
**Status:** ✅ Ready to use  
**Usage:**
```powershell
cd scripts
.\setup-squad-credentials.ps1
```
**What it does:**
- Prompts for app password
- Securely stores in Windows Credential Manager
- Validates storage succeeded
- Provides error messages if needed

**When to use:** After obtaining app password from Microsoft account security page

---

### 2. test-squad-email.ps1
**Purpose:** Verify email sending works  
**Status:** ✅ Ready to use  
**Usage:**
```powershell
# Send to yourself
.\test-squad-email.ps1

# Send to specific recipient
.\test-squad-email.ps1 -To "someone@example.com"
```
**What it does:**
- Tests SMTP connection
- Sends test email
- Reports success/failure
- Helps diagnose issues

**When to use:** After setup-squad-credentials.ps1 completes successfully

---

### 3. send-squad-email.ps1 (existing)
**Purpose:** Send emails from Squad account  
**Status:** ✅ Ready to use (after setup)  
**Usage:**
```powershell
.\send-squad-email.ps1 `
    -To "recipient@example.com" `
    -Subject "Email Subject" `
    -Body "Email body text"
```
**Documentation:** See file header for full parameter reference

---

## 📋 Tasks Overview

### <a name="task-1"></a>Task 1: Verify Gumroad

**Objective:** Verify and publish AI Agent Architecture Cheatsheet on Gumroad

**Status:** ⚠️ Manual action required  
**Why:** Security prevents programmatic password retrieval from Credential Manager

**Account:** td-squad-ai-team@outlook.com  
**Expected Result:** Product published on Gumroad

**Documentation:** `INFRASTRUCTURE_SETUP_GUIDE.md` → "Task 1: Verify Gumroad"

**Steps Summary:**
1. Log into Outlook (https://outlook.office.com)
2. Find Gumroad verification email
3. Click verification link
4. Go to Gumroad (https://app.gumroad.com)
5. Publish product

**Time:** 5-10 minutes

---

### <a name="task-2"></a>Task 2: Create YouTube Gmail

**Objective:** Create dedicated Gmail for "TechAI Explained" YouTube channel

**Status:** ⚠️ Manual action required  
**Why:** Google signup form resists browser automation

**Account Details:**
- Email: `tdsquadai@gmail.com` (or similar available)
- First Name: `Tech`
- Last Name: `AI`
- Birthday: `05/15/1990`
- Used for: Faceless YouTube channel

**Expected Result:** Gmail account created and verified

**Documentation:** `INFRASTRUCTURE_SETUP_GUIDE.md` → "Task 2: Create YouTube Gmail"

**Steps Summary:**
1. Navigate to Google signup (https://accounts.google.com/signup)
2. Enter name and email
3. Create password (save it!)
4. Enter birthday and gender
5. Complete phone verification

**Time:** 10-15 minutes

---

### <a name="task-3"></a>Task 3: Squad Email SMTP Configuration

**Objective:** Enable email sending from Squad account via SMTP

**Status:** ✅ Scripts provided and ready  
**Why:** Fully automated with helper scripts

**Account:** td-squad-ai-team@outlook.com  
**Method:** App password + Credential Manager + SMTP

**Expected Result:** Emails send successfully using send-squad-email.ps1

**Documentation:** `INFRASTRUCTURE_SETUP_GUIDE.md` → "Task 3: Squad Email SMTP"

**Steps Summary:**
1. Generate app password from Microsoft account security
2. Run `setup-squad-credentials.ps1`
3. Enter app password when prompted
4. Run `test-squad-email.ps1` to verify
5. Ready to use!

**Time:** 5-10 minutes

---

## 🔒 Security Notes

### Credential Manager
- **Safe:** Only accessible by logged-in user
- **Secure:** Passwords encrypted in Windows secure storage
- **Used by:** setup-squad-credentials.ps1 and send-squad-email.ps1

### App Passwords
- **Why:** Better than main password for specific applications
- **Where to get:** https://account.microsoft.com/security
- **Use:** Only for SMTP, not for general login

### Best Practices
- Never share app passwords
- Store in Credential Manager (not plain text files)
- Regenerate if compromised
- Enable 2-factor authentication on main account

---

## 🆘 Troubleshooting Quick Links

**Issue:** Can't access Outlook  
→ See: `INFRASTRUCTURE_SETUP_GUIDE.md` → Troubleshooting → Gumroad

**Issue:** Gmail form won't progress  
→ See: `INFRASTRUCTURE_SETUP_GUIDE.md` → Troubleshooting → Gmail

**Issue:** Email send fails  
→ See: `INFRASTRUCTURE_SETUP_GUIDE.md` → Troubleshooting → SMTP

**Issue:** Need full error details  
→ Run scripts with: `-Verbose` flag

---

## 📊 Implementation Roadmap

```
START
  ↓
Read: INFRASTRUCTURE_SETUP_GUIDE.md
  ↓
├─→ TASK 1: Gumroad (Manual, 5-10 min)
│     └─→ ✓ Product published
│
├─→ TASK 2: Gmail (Manual, 10-15 min)
│     └─→ ✓ Account created
│
└─→ TASK 3: SMTP (Automated, 5-10 min)
      ├─→ Run: setup-squad-credentials.ps1
      ├─→ Run: test-squad-email.ps1
      └─→ ✓ Email sending verified

  ↓
ALL COMPLETE ✓
```

---

## 📞 Support Resources

### If stuck on Gumroad:
- Check: `INFRASTRUCTURE_SETUP_GUIDE.md` - Task 1
- Verify: Outlook credential exists (confirmed in Credential Manager)
- Try: Private browser window or different browser

### If stuck on Gmail:
- Check: `INFRASTRUCTURE_SETUP_GUIDE.md` - Task 2
- Verify: Account details are exactly as documented
- Try: Different browser or clear cache

### If stuck on SMTP:
- Check: `INFRASTRUCTURE_SETUP_GUIDE.md` - Task 3 - Troubleshooting
- Run: `.\test-squad-email.ps1` with `-Verbose` for details
- Verify: App password from Microsoft account (not regular password)

---

## ✅ Completion Criteria

**Task 1 Complete when:**
- [ ] Gumroad product shows as "Published"

**Task 2 Complete when:**
- [ ] Gmail account tdsquadai@gmail.com receives confirmation email

**Task 3 Complete when:**
- [ ] `test-squad-email.ps1` sends email successfully
- [ ] Email received in inbox

---

## 📚 File Structure

```
C:\temp\tamresearch1\
│
├─ Documentation/
│  ├─ INFRASTRUCTURE_SETUP_GUIDE.md ........... Main guide
│  ├─ BELANNA_INFRASTRUCTURE_REPORT.md ....... Status report
│  ├─ INFRASTRUCTURE_SETUP_CHECKLIST.txt .... Task checklist
│  ├─ INFRASTRUCTURE_SETUP_SUMMARY.txt ...... Quick ref
│  └─ INDEX.md ............................ This file
│
└─ scripts/
   ├─ setup-squad-credentials.ps1 ........... Credential setup
   ├─ test-squad-email.ps1 ................. Email testing
   └─ send-squad-email.ps1 ................. Email sending (existing)
```

---

## 🎯 Next Steps

1. **Read:** `INFRASTRUCTURE_SETUP_GUIDE.md`
2. **Task 1:** Follow Gumroad section
3. **Task 2:** Follow Gmail section
4. **Task 3:** Run helper scripts
5. **Verify:** All tasks complete
6. **Done:** Infrastructure ready!

---

**Total Time Estimate:** 20-35 minutes  
**Difficulty Level:** Low (mostly manual + script running)  
**Prerequisites:** Access to email accounts and Microsoft account security settings

---

*Created: 2026-03-16 | Engineer: B'Elanna | Status: READY*
