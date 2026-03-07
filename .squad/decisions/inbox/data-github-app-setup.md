# GitHub App Creation for Issue #19

**Decision Date:** 2025-01-24
**Author:** Data
**Status:** Requires Manual Completion

## Context
Issue #19: Tamir not receiving GitHub notifications when tagged in squad comments.

**Root Cause:** GitHub's self-mention suppression. Squad uses Tamir's PAT, so all comments are authored by "tamirdresher_microsoft". GitHub doesn't notify users about their own mentions.

**Solution:** Create a GitHub App so comments come from "squad-notification-bot[bot]" identity, enabling proper @mention notifications.

## Attempted Automation
Attempted to use Playwright MCP to automate GitHub App creation at https://github.com/settings/apps/new, but encountered:
- Login requirement (browser not authenticated)
- Playwright MCP tools don't expose Edge browser or profile parameters needed for authenticated session

## Manual Setup Required

### Step 1: Create GitHub App
1. Navigate to: https://github.com/settings/apps/new
2. Fill in the form:
   - **GitHub App name:** `squad-notification-bot` (try variants if taken: squad-notifier, squad-mentions-bot)
   - **Homepage URL:** `https://github.com/tamirdresher_microsoft/tamresearch1`
   - **Description:** "Bot for posting squad comments to enable proper @mention notifications"
   - **Callback URL:** Leave empty
   - **Webhook:** Uncheck "Active" (disable webhook)
   - **Permissions:**
     - Repository permissions:
       - Issues: Read & Write
       - Pull requests: Read & Write
   - **Where can this GitHub App be installed?** Select "Only on this account"
3. Click "Create GitHub App"

### Step 2: Install App on Repository
1. After creation, click "Install App" in left sidebar
2. Select "tamirdresher_microsoft" account
3. Choose "Only select repositories"
4. Select "tamresearch1"
5. Click "Install"

### Step 3: Generate Private Key
1. In app settings, scroll to "Private keys" section
2. Click "Generate a private key"
3. Save the downloaded .pem file securely (e.g., `.squad/secrets/squad-notification-bot.pem`)
4. **DO NOT COMMIT THIS FILE TO GIT**

### Step 4: Get App Credentials
After creation, note these values from the app settings page:
- **App ID:** (numeric ID shown at top)
- **Client ID:** (shown in "About" section)
- **Installation ID:** Go to https://github.com/settings/installations, click app, check URL for installation ID

### Step 5: Configure Squad
Update squad configuration to use GitHub App authentication:
- Store App ID, Installation ID, and private key path
- Update GitHub client to authenticate as app instead of using PAT
- Modify comment posting logic to use app credentials

## Implementation Notes
- GitHub App auth requires JWT generation + installation token exchange
- Libraries available: `@octokit/auth-app` (Node.js) or manual JWT implementation
- Installation tokens expire after 1 hour and must be refreshed
- Comments will show as from "squad-notification-bot[bot]" 
- This identity is different from Tamir's account, so @mentions will trigger notifications

## Next Steps
1. Tamir: Complete manual GitHub App creation (Steps 1-4 above)
2. Data: Implement GitHub App authentication in squad codebase
3. Data: Update comment posting to use app token instead of PAT
4. Test: Post comment with @tamirdresher_microsoft mention, verify notification received
5. Close Issue #19

## References
- GitHub Docs: https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app
- GitHub App Auth: https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app
