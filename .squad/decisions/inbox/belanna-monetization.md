# Decision: Monetization Audit — Full Platform Verification (March 2026)

**Author:** B'Elanna  
**Date:** 2026-03-18 (Updated: Session 2)  
**Requested by:** Tamir Dresher  
**Status:** Partially fixed. Waiting on Tamir for 2FA codes and credentials.

---

## Context

Tamir requested an urgent audit of all revenue streams. He confirmed he added bank details to Gumroad directly (Stripe no longer needed). This audit verifies the actual state of every revenue platform via live browser checks.

## What B'Elanna FIXED

### ✅ SaaS Finder Hub Hosting Separation (PR #27)
- **Problem:** Site was served under `www.tamirdresher.com/saas-finder-hub/` — Tamir wants it as a separate product
- **Fix:** PR #27 created in `tamirdresher/saas-finder-hub`:
  - Updated `config.toml` baseURL to `https://saas.tamirdresher.com/`
  - Added `static/CNAME` with `saas.tamirdresher.com`
- **Tamir must still:** (1) Add DNS CNAME record `saas.tamirdresher.com → tamirdresher.github.io`, (2) Set custom domain in repo Settings → Pages, (3) Enable "Enforce HTTPS"

### ✅ Gumroad Login Initiated
- **Discovery:** Gumroad account is linked to `tamir.dresher@gmail.com` (NOT tdsquadai@gmail.com as previously documented)
- **Progress:** Successfully authenticated via Google OAuth → hit 2FA wall
- **2FA token sent to:** `tamir.dresher@gmail.com`
- **Status:** Waiting for Tamir to provide the 2FA code from his Gmail

## What's BLOCKED (Needs Tamir)

### 1. GUMROAD — 🔴 NO PRODUCTS, 2FA BLOCKED

- **Profile:** `tdsquad.gumroad.com` — EXISTS but has ZERO products
- **Account email:** `tamir.dresher@gmail.com` (via Google OAuth)
- **2FA:** Authentication token sent to Gmail — Tamir must provide code
- **Even after login:** No products exist. Must create and publish products.

**Tamir's Checklist:**
1. ☐ Check Gmail for Gumroad 2FA code → provide to B'Elanna (or enter yourself)
2. ☐ Log into `app.gumroad.com`
3. ☐ Verify payment/bank settings are complete at `/settings/payments`
4. ☐ Create products (cheatsheets, game assets, course bundles)
5. ☐ Set pricing ($4.99-$29.99)
6. ☐ Publish products
7. ☐ Do a test purchase

### 2. ITCH.IO — 🟡 GAMES LIVE BUT 100% FREE

- **Brainrot Quiz Battle:** `jellyboltgames.itch.io/brainrot-quiz-battle` — ✅ LIVE
- **Code Conquest:** `jellyboltgames.itch.io/code-conquest` — ✅ LIVE
- **Pricing:** Both tagged **"Free"** — NO payment option enabled
- **Login:** Cloudflare Turnstile blocks automated access. No credentials found in repo, Credential Manager, or session history.
- **Account:** `jellyboltgames` / `tdsquadai@gmail.com`

**Tamir's Checklist (FASTEST PATH TO REVENUE — 10 min):**
1. ☐ Log into `itch.io` as `jellyboltgames` (or use forgot-password at `tdsquadai@gmail.com`)
2. ☐ Edit Brainrot Quiz Battle → Pricing → set "Pay what you want" (min $0, suggested $2.99)
3. ☐ Edit Code Conquest → Pricing → set "Pay what you want" (min $0, suggested $2.99)
4. ☐ Go to `itch.io/user/settings` → connect PayPal or payout method
5. ☐ Add cross-promotion links between games
6. ☐ Store itch.io credentials in Credential Manager: `cmdkey /generic:itch-io /user:tdsquadai@gmail.com /pass:<PASSWORD>`

### 3. YOUTUBE — 🔴 NO CHANNEL EXISTS

- **Verified:** No YouTube channel for "TechAI Explained" belongs to Tamir
- **The `@VibeAI-w3z` channel is NOT Tamir's** (different creator, "Vibe AI")
- **No owned channel found** for Tamir Dresher or TechAI Content

**Tamir's Checklist:**
1. ☐ Go to `studio.youtube.com` → Create channel
2. ☐ Name: "TechAI Explained" (or brand of choice)
3. ☐ Set channel to public
4. ☐ Upload channel art and description
5. ☐ Note: YouTube Partner Program requires 1,000 subs + 4,000 watch hours (2-3 months)

### 4. SAAS FINDER HUB — ✅ DEPLOYED, NEEDS AFFILIATE SETUP

- **URL:** Currently at `www.tamirdresher.com/saas-finder-hub/` (fix in PR #27 for `saas.tamirdresher.com`)
- **Content:** 30+ articles on SaaS tool comparisons
- **Affiliate disclosure:** ✅ Present and FTC-compliant
- **Problem:** Article links go to vendor sites (dynatrace.com, etc.) with NO affiliate tracking parameters

**Tamir's Checklist:**
1. ☐ Merge PR #27 in `saas-finder-hub` repo
2. ☐ Set up DNS: CNAME `saas.tamirdresher.com → tamirdresher.github.io`
3. ☐ In repo Settings → Pages, set custom domain to `saas.tamirdresher.com`
4. ☐ Sign up for affiliate programs: Impact (Datadog), PartnerStack (Dynatrace), etc.
5. ☐ Replace direct links with affiliate tracking URLs in articles

### 5. BLOG (www.tamirdresher.com) — 🟡 MINIMAL MONETIZATION

- **Has:** Book affiliate links (Manning, Amazon), disclosure page, GA4, Disqus
- **Missing:** Newsletter, Gumroad links, sponsor slots, ads, email capture
- **14 posts** — technical content (.NET, Rx.NET, ASP.NET Core)

**Quick Wins:**
1. Add newsletter signup (ConvertKit free tier)
2. Add Gumroad product links once products exist
3. Add consulting/speaking CTA (MVP + published author)

## Overall Revenue Status

| Platform | Status | Revenue Now | Blocker | Time to Fix |
|----------|--------|-------------|---------|-------------|
| Itch.io games | 🟡 Live/Free | $0 | Enable "pay what you want" | **10 min** |
| Gumroad | 🔴 Empty | $0 | Create products, 2FA | **30 min** |
| SaaS Finder Hub | 🟡 Live | $0 | Affiliate tracking URLs | **2 hours** |
| Blog affiliates | 🟢 Active | ~$0-5/mo | Low traffic | Ongoing |
| YouTube | 🔴 None | $0 | Create channel + content | **Months** |

### Credential Storage Issue
No itch.io or Gumroad credentials found in Windows Credential Manager, repo files, .env, or GitHub issues (API rate-limited). **Tamir must store service credentials** in Credential Manager after login:
```
cmdkey /generic:gumroad /user:tamir.dresher@gmail.com /pass:<PASSWORD>
cmdkey /generic:itch-io /user:tdsquadai@gmail.com /pass:<PASSWORD>
```

---

**Affects:** All squad members working on revenue (Picard, Geordi, JellyBolt Squad)  
**Filed by:** B'Elanna, Infrastructure Expert
