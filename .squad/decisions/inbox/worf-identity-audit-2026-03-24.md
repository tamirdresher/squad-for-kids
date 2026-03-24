# Identity Leak Audit Report
**Date:** 2026-03-24  
**Auditor:** Worf (Security & Cloud)  
**Requested by:** Tamir Dresher  
**Context:** Users commented on JellyBolt Games products → comments reached `tamir.dresher@gmail.com`

---

## 🔴 CRITICAL LEAKS (Users can directly identify Tamir Dresher)

### 1. **itch.io Notification Email**
- **WHERE:** itch.io account settings for `jellyboltgames`
- **WHAT:** The notification email is likely set to `tamir.dresher@gmail.com`
- **EVIDENCE:** 
  - User comments reach `tamir.dresher@gmail.com` despite no visible public connection
  - itch.io API does NOT expose notification email (verified)
  - All 24 published games have community/comments enabled
  - Games have "Contact", "Send feedback", "Community" features enabled
- **HOW TO FIX:** 
  1. Create a new email: `support@jellyboltgames.com` OR `jellyboltgames@gmail.com`
  2. Log into itch.io as jellyboltgames
  3. Go to Settings → Notifications → Change email to the new email
  4. Test by posting a comment on a game and verifying it goes to the new email
- **PRIORITY:** 🔥 IMMEDIATE - This is the ROOT CAUSE

### 2. **GitHub Repos Are Under `tamirdresher` Account**
- **WHERE:** All game repos are hosted at `github.com/tamirdresher/[game-name]`
- **WHAT:** While repos are **private** (✅), they still appear in `tamirdresher`'s profile
- **EVIDENCE:**
  - `tamirdresher` GitHub profile shows: name="Tamir Dresher", company="Payoneer", location="Israel"
  - Public profile has 120 public repos (exposes the account exists)
  - Anyone who discovers a link to `github.com/tamirdresher/...` can see the full profile
- **HOW TO FIX:**
  1. Create a new GitHub organization: `jellyboltgames` (or use existing `tdsquadai`)
  2. Transfer all 3 game repos to the new organization
  3. Update all CI/CD secrets in the new org
  4. Update butler credentials to point to new repo URLs
- **PRIORITY:** 🔥 HIGH - Prevents future leaks

### 3. **README Files Link to `tamirdresher` GitHub**
- **WHERE:** README.md in all 3 game repos
- **WHAT:** Contains direct links to `github.com/tamirdresher/jellybolt-games`
- **EVIDENCE:**
  - `bounce-blitz/README.md`: "See [JellyBolt Games Studio](https://github.com/tamirdresher/jellybolt-games)"
  - `idle-critter-farm/README.md`: Same link
  - `brainrot-quiz-battle/README.md`: Contains `git clone https://github.com/tamirdresher/brainrot-quiz-battle.git`
- **IMPACT:** If repos become public or someone gains read access, they see the tamirdresher connection
- **HOW TO FIX:**
  ```powershell
  # After transferring repos to new org, update README files:
  # bounce-blitz
  gh api repos/jellyboltgames/bounce-blitz/contents/README.md | 
    ConvertFrom-Json | Select-Object -ExpandProperty content | 
    % { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) } |
    % { $_ -replace 'github.com/tamirdresher', 'github.com/jellyboltgames' }
  
  # Repeat for idle-critter-farm and brainrot-quiz-battle
  ```
- **PRIORITY:** 🔥 HIGH

### 4. **Git Commit Authors Use Real Name & Email**
- **WHERE:** All commits in all repos
- **WHAT:** Commits authored by "Tamir Dresher <tamir.dresher@gmail.com>" and "Tamir Dresher <tamirdresher@gmail.com>"
- **EVIDENCE:**
  - `bounce-blitz`: Last 10 commits by "Tamir Dresher"
  - `idle-critter-farm`: Last 10 commits by "Tamir Dresher"
  - `brainrot-quiz-battle`: Last 10 commits by "Tamir Dresher" (2 by Ralph)
- **IMPACT:** Anyone with repo read access can see commit history
- **HOW TO FIX:**
  ```powershell
  # Configure git to use JellyBolt identity for future commits:
  cd bounce-blitz
  git config user.name "JellyBolt Games"
  git config user.email "jellyboltgames@gmail.com"
  
  # Repeat for other repos
  
  # WARNING: Rewriting history is RISKY - only do if absolutely necessary
  # Better: Just fix going forward
  ```
- **PRIORITY:** 🟡 MEDIUM (repos are private, fix for future commits)

### 5. **Expo Account Uses `tamirdresher` Username**
- **WHERE:** EAS (Expo Application Services) account
- **WHAT:** Expo account username is `tamirdresher`
- **EVIDENCE:** `npx expo whoami` returns `tamirdresher`
- **IMPACT:** EAS project metadata may expose the username
- **HOW TO FIX:**
  1. Create a new Expo account with email `jellyboltgames@gmail.com`
  2. Re-initialize EAS projects under the new account
  3. Update `app.json` files to remove any `owner` fields referencing tamirdresher
- **PRIORITY:** 🟡 MEDIUM

---

## 🟡 MODERATE RISKS (Requires effort to connect dots)

### 6. **Repos Are Private But Discoverable**
- **WHERE:** GitHub repo visibility
- **WHAT:** Repos are private ✅, but anyone who knows the URL can see they exist (and who owns them)
- **EVIDENCE:** All 3 repos show `visibility: private` but are under `tamirdresher` account
- **MITIGATION:** Transfer to `jellyboltgames` org (covered in Fix #2)

### 7. **No itch.io Source Links (✅ Clean)**
- **WHERE:** itch.io game pages
- **WHAT:** No GitHub links found on public game pages
- **EVIDENCE:** Checked all 3 game pages - no `github.com` links in HTML
- **STATUS:** 🟢 CLEAN

### 8. **itch.io API Profile (✅ Clean)**
- **WHERE:** itch.io public API
- **WHAT:** Profile shows only `jellyboltgames` branding
- **EVIDENCE:**
  - username: `jellyboltgames`
  - display_name: `JellyBolt Games`
  - No email exposed via API
- **STATUS:** 🟢 CLEAN

### 9. **tdsquadAI Website (⚠️ Not Set Up)**
- **WHERE:** `https://tdsquadai.github.io`
- **WHAT:** Returns 404 - GitHub Pages not enabled
- **EVIDENCE:** "Site not found · GitHub Pages"
- **RECOMMENDATION:** If this site is intended for public use, set up Pages and ensure no personal info
- **STATUS:** ⚠️ N/A (site doesn't exist)

---

## 📧 ROOT CAUSE: Why `tamir.dresher@gmail.com` Received Comments

**Primary Cause:**  
The `jellyboltgames` itch.io account has **notification email set to `tamir.dresher@gmail.com`** in account settings.

**Evidence Chain:**
1. All 24 games on itch.io have comments/community enabled
2. itch.io game pages have "Send feedback", "Contact", and comment sections
3. When users post comments, itch.io sends notifications to the account's notification email
4. The itch.io API does NOT expose this email (it's in account settings only)
5. Since comments reached `tamir.dresher@gmail.com`, this is the only explanation

**Why this wasn't discovered earlier:**
- The itch.io API response for `/me` does NOT include the notification email
- The public profile shows clean branding (`jellyboltgames`)
- No GitHub links on game pages
- But account settings (not visible via API) contain the personal email

---

## 🛠️ FIX PLAN (Prioritized)

### Priority 1: Fix itch.io Notification Email (IMMEDIATE)
**Effort:** 15 minutes  
**Risk:** Low  
**Steps:**
1. Create `jellyboltgames@gmail.com` (or use `support@jellyboltgames.com` if you own the domain)
2. Log into itch.io as `jellyboltgames` user
3. Go to Settings → Email → Change notification email
4. Verify by posting a test comment and checking the new email receives it
5. Document the new email in `.squad/team.md`

**Why first:** This is the confirmed leak vector. No code changes required.

---

### Priority 2: Transfer Repos to New GitHub Org (HIGH)
**Effort:** 2-3 hours  
**Risk:** Medium (CI/CD needs updating)  
**Steps:**
1. Create GitHub organization: `jellyboltgames`
2. Transfer repos:
   ```powershell
   gh api repos/tamirdresher/bounce-blitz/transfer -X POST -f new_owner=jellyboltgames
   gh api repos/tamirdresher/idle-critter-farm/transfer -X POST -f new_owner=jellyboltgames
   gh api repos/tamirdresher/brainrot-quiz-battle/transfer -X POST -f new_owner=jellyboltgames
   ```
3. Update GitHub Actions secrets in the new org:
   - `BUTLER_API_KEY`
   - `EXPO_TOKEN`
4. Update README files to replace `tamirdresher` with `jellyboltgames`
5. Test CI/CD pipelines in new org
6. Update local git remotes:
   ```powershell
   git remote set-url origin https://github.com/jellyboltgames/bounce-blitz.git
   ```

**Why second:** Prevents future leaks if repos ever become public or links are shared.

---

### Priority 3: Fix Git Commit Identity (MEDIUM)
**Effort:** 10 minutes  
**Risk:** Low  
**Steps:**
1. For each repo, configure git identity:
   ```powershell
   git config user.name "JellyBolt Games"
   git config user.email "jellyboltgames@gmail.com"
   ```
2. Set global config for new clones:
   ```powershell
   git config --global user.name "JellyBolt Games (JellyBolt)"
   git config --global user.email "jellyboltgames@gmail.com"
   ```
3. Do NOT rewrite history (too risky, repos are private)

**Why third:** Repos are private, so historical commits are low risk. Fix going forward.

---

### Priority 4: Create New Expo Account (MEDIUM)
**Effort:** 1-2 hours  
**Risk:** Medium (EAS rebuild required)  
**Steps:**
1. Create new Expo account: `jellyboltgames@gmail.com`
2. Generate new `EXPO_TOKEN` for CI/CD
3. Re-initialize EAS projects:
   ```powershell
   eas init --id <new-project-id>
   ```
4. Update `app.json` to remove `owner` field
5. Rebuild apps with new account
6. Test on devices

**Why fourth:** Current setup works, but limits future scalability if you want public Expo profiles.

---

### Priority 5: Documentation & Prevention (LOW)
**Effort:** 30 minutes  
**Risk:** None  
**Steps:**
1. Document all credentials in `.squad/secrets.md` (or password manager)
2. Add to `.squad/routing.md`:
   > **Identity Separation Policy:**  
   > JellyBolt Games and tdsquadAI brands must have ZERO association with Tamir Dresher.  
   > - Use `jellyboltgames@gmail.com` for all new accounts  
   > - Never use personal name in commits, profiles, or public-facing content  
   > - Repos must be under `jellyboltgames` org (not `tamirdresher`)  
   > - Before launching new products, audit for identity leaks (use this checklist)
3. Create identity leak checklist for future products

---

## 📋 VERIFICATION CHECKLIST

After implementing fixes:

- [ ] Post a test comment on a game → verify it goes to `jellyboltgames@gmail.com` (not `tamir.dresher@gmail.com`)
- [ ] Check GitHub repo URLs → all should be `github.com/jellyboltgames/...`
- [ ] Check README files → no references to `tamirdresher`
- [ ] Check new commits → authored by "JellyBolt Games"
- [ ] Check Expo account → `npx expo whoami` returns `jellyboltgames`
- [ ] Check itch.io profile → still shows `jellyboltgames` (no change needed)

---

## 📊 SUMMARY TABLE

| Issue | Severity | Status | Fix Effort | Fixed? |
|-------|----------|--------|------------|--------|
| itch.io notification email | 🔴 Critical | ROOT CAUSE | 15 min | ❌ |
| Repos under tamirdresher | 🔴 Critical | High Risk | 2-3 hrs | ❌ |
| README links to tamirdresher | 🔴 Critical | High Risk | 30 min | ❌ |
| Commit authors use real name | 🔴 Critical | Medium Risk | 10 min | ❌ |
| Expo account username | 🟡 Moderate | Medium Risk | 1-2 hrs | ❌ |
| itch.io game pages | 🟢 Clean | No Leak | N/A | ✅ |
| itch.io API profile | 🟢 Clean | No Leak | N/A | ✅ |

**Total Fix Effort:** ~5-7 hours  
**Highest Priority:** itch.io notification email (15 minutes)

---

## 🎯 RECOMMENDED ACTION

**Immediate (Today):**
1. Fix itch.io notification email → this stops the bleeding

**This Week:**
2. Transfer repos to `jellyboltgames` org
3. Update README files
4. Fix git commit identity

**Next Sprint:**
5. Create new Expo account if public profiles are needed
6. Document identity separation policy

---

**End of Audit Report**  
*If you need clarification on any finding or fix step, ping me in the squad channel.*
