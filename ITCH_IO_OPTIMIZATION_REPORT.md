# Itch.io Games Optimization Report
**Brand:** JellyBolt Games  
**Report Date:** March 17, 2026  
**Account:** jellyboltgames (tdsquadai@gmail.com)

---

## Executive Summary

Playwright browser automation was used to audit both game listings on itch.io. This report documents current listing states, identifies improvement opportunities, and provides actionable optimization recommendations.

**Games Analyzed:**
- BrainRot Quiz Battle: https://jellyboltgames.itch.io/brainrot-quiz-battle
- Code Conquest: https://jellyboltgames.itch.io/code-conquest

---

## 1. Current Listings Audit

### Screenshots Captured
✅ **BrainRot Quiz Battle** - `brainrot-current.png`
✅ **Code Conquest** - `code-conquest-current.png`

### Page Structure Analysis (from Playwright snapshots)

**Both games display:**
- View all by jellyboltgames link
- Follow developer link
- Add To Collection feature
- Run game button
- "More information" section
- Comment section (requires login)
- Genre tags: Puzzle / Free
- Updated timestamps
- Breadcrumb navigation (Games › Puzzle › Free)

---

## 2. Key Findings

### Current State
1. **Both games are live and publicly accessible**
   - BrainRot Quiz Battle: Active, updated 1 hour ago (from snapshot time)
   - Code Conquest: Active and playable

2. **Genre Classification**
   - Category: Puzzle / Free
   - Both are web-based (playable inline with "Run game" button)

3. **Missing Optimizations**
   - No visible cross-promotion links between games
   - No obvious links to external platforms (YouTube, Gumroad)
   - Limited metadata visible on public pages
   - No prominent call-to-actions for related games

---

## 3. Dashboard Access Challenge

**Status:** ⚠️ **Dashboard Login Blocked**

Attempted to access itch.io dashboard for detailed analytics (views, downloads, ratings, comments). 
- Page protection/CAPTCHA verification prevented automated access
- Windows Credential Manager credentials not accessible via automation
- Manual dashboard access recommended for stat review

---

## 4. Optimization Recommendations

### Immediate Actions (Via Dashboard)

#### A. Cross-Promotion Enhancement
**Priority: HIGH**

1. **Add Related Game Links**
   - In BrainRot Quiz Battle: Add "Also try Code Conquest" link
   - In Code Conquest: Add "Also try BrainRot Quiz Battle" link
   - Use itch.io's built-in relationship/collection features

2. **Create a Game Collection**
   - Bundle both games under "JellyBolt Games Collection"
   - Benefits: Improved discoverability, SEO, player engagement

#### B. Metadata & SEO Improvements
**Priority: HIGH**

1. **Tags Optimization**
   - Current: Puzzle, Free
   - Suggested additions:
     - Brain game, quiz, educational (for BrainRot)
     - Programming, code, educational (for Code Conquest)
     - Web game, casual, multiplayer (if applicable)

2. **Description Enhancement**
   - Include cross-promotion in game descriptions
   - Add "From the creators of [other game]" mention
   - Link to developer profile: jellyboltgames.itch.io

3. **Content Links**
   - YouTube channel (if available)
   - Gumroad store (if available)
   - Developer website
   - Social media (@jellyboltgames if exists)

#### C. Community Engagement
**Priority: MEDIUM**

1. **Comment Monitoring**
   - Review all game comments through dashboard
   - Respond to feedback and bug reports
   - Pin helpful comments or FAQs

2. **Rating Visibility**
   - Encourage ratings through in-game prompts
   - Monitor average rating trends
   - Address negative feedback

#### D. Analytics Review
**Priority: MEDIUM**

Dashboard stats to monitor:
- Views: Track page visit trends
- Downloads/Plays: Monitor engagement conversion
- Playtime: Identify retention issues
- Referral sources: Optimize marketing channels
- Geographic data: Plan localization if needed

---

## 5. Cross-Platform Linking Strategy

### Proposed Structure

**BrainRot Quiz Battle page should include:**
```
[Video] → YouTube link (if game video exists)
[More Games] → Code Conquest
[Creator] → jellyboltgames profile
[Support] → Gumroad/tip jar link
```

**Code Conquest page should include:**
```
[Video] → YouTube link (if game video exists)
[More Games] → BrainRot Quiz Battle
[Creator] → jellyboltgames profile
[Support] → Gumroad/tip jar link
```

### Implementation Method
1. Log into itch.io dashboard: https://itch.io/dashboard
2. Edit each game's project settings
3. Add links to:
   - External resources (YouTube, Gumroad URLs)
   - Related games via description or metadata
   - Creator profile links

---

## 6. Detected Opportunities

### High-Impact Changes
- [ ] Add reciprocal cross-game links (mutual promotion)
- [ ] Create shared collection/series
- [ ] Add developer YouTube/social links
- [ ] Optimize tags for SEO
- [ ] Enhanced game descriptions with cross-promotion text

### Medium-Impact Changes
- [ ] Add rating/review encouragement
- [ ] Create community posts about both games
- [ ] Link to any dev blog or social media
- [ ] Add screenshots/GIFs to game pages

### Low-Impact Maintenance
- [ ] Monitor comments for feedback
- [ ] Update game descriptions with new features
- [ ] Track analytics trends

---

## 7. Technical Automation Notes

### Playwright CLI Results
- ✅ Successfully navigated to both game pages
- ✅ Captured page structure and layout
- ✅ Generated snapshots and screenshots
- ⚠️ Dashboard login blocked by anti-automation measures
- ⚠️ Manual intervention required for:
  - Credential input
  - CAPTCHA/verification
  - Dashboard content updates

### Recommended Manual Setup

For dashboard access, use a browser manually:
1. Visit https://itch.io/login
2. Enter: `tdsquadai@gmail.com`
3. Enter password from Credential Manager
4. Navigate to https://itch.io/dashboard
5. Edit each game project settings
6. Apply recommendations from this report

---

## 8. Next Steps

### Phase 1: Manual Dashboard Review (5-10 minutes)
- [ ] Log into itch.io dashboard
- [ ] Review current stats for both games
- [ ] Document views, downloads, ratings
- [ ] Read any existing comments/feedback

### Phase 2: Apply Optimizations (10-15 minutes)
- [ ] Update game descriptions with cross-promotion
- [ ] Add external links (YouTube, Gumroad)
- [ ] Optimize tags
- [ ] Create game collection (if possible)

### Phase 3: Verification (5 minutes)
- [ ] Take new screenshots of updated pages
- [ ] Verify links work correctly
- [ ] Confirm visibility on profile

---

## 9. Resources

**Files Generated:**
- brainrot-current.png - Screenshot of BrainRot Quiz Battle
- code-conquest-current.png - Screenshot of Code Conquest  
- .playwright-cli/page-*.yml - Page structure snapshots
- .playwright-cli/console-*.log - Navigation logs

**itch.io Resources:**
- Developer Dashboard: https://itch.io/dashboard
- Create Collection: https://itch.io/dashboard/collections
- Game Edit Page: https://itch.io/dashboard/games/[game-id]/edit
- Creator Profile: https://jellyboltgames.itch.io

---

## Conclusion

Both games are live and accessible. Primary optimization opportunity is implementing cross-promotion between the two titles and linking to external platforms. Anti-automation measures on itch.io dashboard prevent full automation of updates, requiring manual completion of recommended changes.

**Estimated manual effort to complete all optimizations: ~20 minutes**

---

*Report Generated via Playwright CLI Automation*  
*For manual dashboard access: jellyboltgames.itch.io*
