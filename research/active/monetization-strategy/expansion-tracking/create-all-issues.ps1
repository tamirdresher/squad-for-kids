#!/usr/bin/env pwsh
# Run this script when GitHub network is available to create ALL tracking issues
# Usage: .\create-all-issues.ps1
# All issues get "squad" label for Ralph cross-machine pickup

$ErrorActionPreference = "Continue"

Write-Host "🚀 Creating expansion tracking issues..." -ForegroundColor Cyan

# ============================================
# JELLYBOLT-GAMES REPO — Game Distribution
# ============================================
$gameRepo = "tamirdresher/jellybolt-games"

# If repo doesn't exist, create it
$repoExists = gh repo view $gameRepo --json name 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating $gameRepo repo..." -ForegroundColor Yellow
    gh repo create $gameRepo --public --description "JellyBolt Games — Mobile and web games by JellyBolt" 2>&1
}

# Ensure labels exist
gh label create "squad" --repo $gameRepo --color "0E8A16" --description "Squad-tracked work" --force 2>&1
gh label create "distribution" --repo $gameRepo --color "1D76DB" --description "Game distribution" --force 2>&1
gh label create "marketing" --repo $gameRepo --color "D93F0B" --description "Marketing tasks" --force 2>&1

Write-Host "`n📦 Game Distribution Issues:" -ForegroundColor Green

gh issue create --repo $gameRepo --title "Amazon Appstore — Register & Upload Games" `
  --label "squad,distribution" `
  --body @"
## Goal
Register free Amazon Appstore developer account and upload both games.

## Details
- Account email: tdsquadai@gmail.com
- Games: BrainRot Quiz Battle + Code Conquest
- APKs already built via EAS
- Store listing assets ready at: jellybolt-games/store-listings/amazon/
- Free listing, earn via ad revenue from Kindle/Fire users

## Acceptance Criteria
- [ ] Amazon developer account registered
- [ ] BrainRot Quiz Battle APK uploaded with store listing
- [ ] Code Conquest APK uploaded with store listing
- [ ] Both apps submitted for review

## Revenue: Ad revenue from Kindle/Fire tablet users
"@

gh issue create --repo $gameRepo --title "Samsung Galaxy Store — Register & Upload Games" `
  --label "squad,distribution" `
  --body @"
## Goal
Register free Samsung Galaxy Store seller account and upload both games.

## Details
- Account email: tdsquadai@gmail.com
- Games: BrainRot Quiz Battle + Code Conquest
- APKs already built via EAS
- Store listing assets ready at: jellybolt-games/store-listings/samsung/
- Samsung pre-installed on all Samsung phones = massive reach

## Acceptance Criteria
- [ ] Samsung seller account registered
- [ ] BrainRot Quiz Battle uploaded with store listing
- [ ] Code Conquest uploaded with store listing
- [ ] Both apps submitted for review

## Revenue: Ad revenue from Samsung device users (huge market)
"@

gh issue create --repo $gameRepo --title "Upload HTML5 Builds to Web Portals (CrazyGames, GameJolt, Newgrounds)" `
  --label "squad,distribution" `
  --body @"
## Goal
Upload HTML5 web builds to 3 free web game portals.

## Details
- Web builds already exported:
  - BrainRot Quiz: C:\temp\brainrot-quiz-battle\app\dist\ (0.71 MB)
  - Code Conquest: C:\temp\code-conquest\dist\ (0.52 MB)
- Submission info at: jellybolt-games/store-listings/web-portals/
- Platforms:
  1. CrazyGames (crazygames.com/developer) — ad-share revenue
  2. GameJolt (gamejolt.com) — community platform
  3. Newgrounds (newgrounds.com) — classic gaming portal

## Acceptance Criteria
- [ ] CrazyGames developer account created, both games uploaded
- [ ] GameJolt account created, both games uploaded
- [ ] Newgrounds account created, both games uploaded
- [ ] All listings have proper descriptions and tags

## Revenue: CrazyGames pays ad-share; others drive traffic to paid platforms
"@

gh issue create --repo $gameRepo --title "Cross-Platform Linking — All Game Pages" `
  --label "squad,marketing" `
  --body @"
## Goal
Update ALL game listings to cross-link to each other for maximum traffic.

## Details
- Template at: jellybolt-games/store-listings/cross-links.md
- Every listing should have 'Also available on:' section
- Platforms to link: itch.io, Google Play, Amazon, Samsung, CrazyGames, GameJolt, Newgrounds, Gumroad

## Acceptance Criteria
- [ ] itch.io listings updated with cross-links
- [ ] Google Play listings updated (when live)
- [ ] All new platform listings include cross-links from day 1

## Revenue: Multiplier effect — each platform drives traffic to all others
"@

gh issue create --repo $gameRepo --title "App Store Optimization (ASO) — All Listings" `
  --label "squad,marketing" `
  --body @"
## Goal
Optimize all game store listings for maximum organic discovery.

## Details
- Research top keywords: quiz game, brain games, coding game, board game, trivia
- Optimize: titles, descriptions, screenshots, tags
- Keyword research at: content-empire/marketing/aso/

## Acceptance Criteria
- [ ] Keyword research completed for both games
- [ ] All itch.io listings optimized
- [ ] All Google Play listings optimized (when live)
- [ ] Screenshot strategy documented

## Revenue: Better ASO = more organic installs = more ad revenue
"@

# ============================================
# CONTENT-EMPIRE REPO — Content & Marketing
# ============================================
$contentRepo = "tamirdresher/content-empire"

$repoExists2 = gh repo view $contentRepo --json name 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating $contentRepo repo..." -ForegroundColor Yellow
    gh repo create $contentRepo --public --description "Content Empire — Autonomous content production squad" 2>&1
}

gh label create "squad" --repo $contentRepo --color "0E8A16" --description "Squad-tracked work" --force 2>&1
gh label create "content" --repo $contentRepo --color "5319E7" --description "Content creation" --force 2>&1
gh label create "marketing" --repo $contentRepo --color "D93F0B" --description "Marketing tasks" --force 2>&1
gh label create "revenue" --repo $contentRepo --color "FBCA04" --description "Revenue-generating" --force 2>&1

Write-Host "`n📝 Content & Marketing Issues:" -ForegroundColor Green

gh issue create --repo $contentRepo --title "Medium Partner Program — Repost Top 10 SEO Articles" `
  --label "squad,content,revenue" `
  --body @"
## Goal
Create Medium account and repost top articles from SaaS Finder Hub for paid reads.

## Details
- Articles prepared at: content-empire/medium-articles/
- Use canonical URL pointing to original SaaS Finder Hub articles
- Medium pays per member read — passive income
- Include affiliate links (Amazon Associates, Manning)
- Add bio/CTA at bottom linking to YouTube, Gumroad, games

## Acceptance Criteria
- [ ] Medium account created (tdsquadai@gmail.com or GitHub login)
- [ ] Joined Medium Partner Program
- [ ] 10 articles published with canonical URLs
- [ ] All affiliate links intact
- [ ] Bio/CTA links to all other platforms

## Revenue: Medium pays per member read + affiliate link clicks
"@

gh issue create --repo $contentRepo --title "Dev.to Cross-Posting — Articles with Affiliate Links" `
  --label "squad,content,revenue" `
  --body @"
## Goal
Create Dev.to account and cross-post articles for developer audience traffic.

## Details
- Articles prepared at: content-empire/devto-articles/
- Dev.to supports GitHub login
- Strong developer audience = high affiliate conversion
- Canonical URLs point to originals

## Acceptance Criteria
- [ ] Dev.to account created via GitHub login
- [ ] 10 articles cross-posted
- [ ] All affiliate links working
- [ ] Proper canonical_url, tags, series front matter

## Revenue: Traffic → Amazon/Manning affiliate clicks
"@

gh issue create --repo $contentRepo --title "LinkedIn Article Series — Professional Audience" `
  --label "squad,content,revenue" `
  --body @"
## Goal
Publish LinkedIn articles targeting professional developers.

## Details
- 3 articles prepared at: content-empire/linkedin-articles/
- Topics: .NET, AI, software architecture
- Professional tone for LinkedIn audience
- Subtle affiliate links + CTAs to YouTube and newsletter

## Acceptance Criteria
- [ ] 3 LinkedIn articles published
- [ ] Links to YouTube channel and Gumroad store
- [ ] Professional formatting

## Revenue: Consulting leads + affiliate clicks from professional audience
"@

gh issue create --repo $contentRepo --title "Substack Newsletter — Launch Free Tier" `
  --label "squad,content,revenue" `
  --body @"
## Goal
Launch free Substack newsletter for tech/AI content.

## Details
- Content at: content-empire/substack/
- Welcome post + first issue ready
- Repurpose best articles
- Build email list for direct marketing
- Free to start, can add paid tier later

## Acceptance Criteria
- [ ] Substack account created
- [ ] Welcome post published
- [ ] First newsletter issue sent
- [ ] Cross-promoted from all other platforms

## Revenue: Email list = direct marketing channel → product sales
"@

gh issue create --repo $contentRepo --title "Product Hunt Launch — Games + Gumroad Products" `
  --label "squad,marketing,revenue" `
  --body @"
## Goal
Launch products on Product Hunt for massive Day-1 traffic.

## Details
- Launch kit at: content-empire/marketing/product-hunt/
- 3 launches: BrainRot Quiz, Code Conquest, Gumroad Bundle
- Free to list, huge traffic potential

## Acceptance Criteria
- [ ] Product Hunt account created
- [ ] BrainRot Quiz Battle listed
- [ ] Code Conquest listed
- [ ] Gumroad bundle listed
- [ ] Launch strategy executed (timing, cross-promotion)

## Revenue: Day-1 traffic spike → downloads, sales, affiliate clicks
"@

gh issue create --repo $contentRepo --title "Reddit Marketing Campaign" `
  --label "squad,marketing" `
  --body @"
## Goal
Post genuine, value-adding content on relevant subreddits.

## Details
- Posts prepared at: content-empire/marketing/reddit/
- Subreddits: r/indiegames, r/gamedev, r/dotnet, r/learnprogramming, r/programming
- NOT spam — genuine engagement following each sub's rules

## Acceptance Criteria
- [ ] Reddit account created with karma
- [ ] Posts published (staggered, not all at once)
- [ ] Engagement in comments
- [ ] Links to games, articles, products

## Revenue: Targeted community traffic → downloads and affiliate clicks
"@

gh issue create --repo $contentRepo --title "Discord Community Engagement" `
  --label "squad,marketing" `
  --body @"
## Goal
Join and engage in relevant Discord servers.

## Details
- Server list at: content-empire/marketing/discord/servers-to-join.md
- Intro messages at: content-empire/marketing/discord/intro-messages.md
- Build presence over time, share when relevant

## Acceptance Criteria
- [ ] Joined 5+ relevant Discord servers
- [ ] Introduced in each (following server rules)
- [ ] Shared game links when appropriate
- [ ] Ongoing engagement plan

## Revenue: Community traffic + feedback + word-of-mouth
"@

Write-Host "`n✅ All issues created!" -ForegroundColor Green
Write-Host "Run 'gh issue list --repo $gameRepo' and 'gh issue list --repo $contentRepo' to verify" -ForegroundColor Cyan
