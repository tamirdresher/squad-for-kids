# Email List Platform Research

> **Prepared by:** Seven (Research & Docs)
> **Date:** 2026-03-15
> **For:** Tamir Dresher — tamirdresher.com

---

## Platform Comparison

### 1. Substack

| Feature | Details |
|---------|---------|
| **Pricing** | Free (Substack takes 10% of paid subscriptions only) |
| **Free Tier** | Unlimited subscribers, unlimited emails |
| **Paid Tier** | Optional paid subscriptions (you set the price) |
| **Built-in Monetization** | ✅ Yes — paid newsletters, founding members |
| **Custom Domain** | ✅ Yes (with paid plan or custom setup) |
| **Lead Magnets** | ❌ No native file delivery; workaround with welcome email links |
| **Analytics** | Basic (opens, clicks, subscriber growth) |
| **Design** | Limited — Substack's template only |
| **API** | Limited — no full API for automation |
| **Best For** | Writers who want built-in audience + monetization |
| **Downsides** | You're building on Substack's platform (not your domain), limited customization, 10% cut of paid |

**Verdict:** Great for pure newsletter writers, but Tamir already has tamirdresher.com. Substack would fragment his audience between two platforms.

---

### 2. ConvertKit (now "Kit")

| Feature | Details |
|---------|---------|
| **Pricing** | Free up to 10K subscribers (limited features); Creator plan $25/mo |
| **Free Tier** | 10K subscribers, unlimited landing pages, email broadcasts |
| **Paid Tier** | $25/mo: automations, sequences, visual funnels |
| **Built-in Monetization** | ✅ Paid newsletters, digital products, tips |
| **Custom Domain** | ✅ Yes |
| **Lead Magnets** | ✅ Native support — file delivery on signup |
| **Analytics** | Good (opens, clicks, subscriber tags, automations) |
| **Design** | Good templates, inline editor |
| **API** | ✅ Full REST API |
| **Integrations** | Zapier, WordPress, Ghost, Webflow, 100+ tools |
| **Best For** | Creators who want automation + lead magnets + monetization |
| **Downsides** | Free tier has limited automations; $25/mo for full features |

**Verdict:** Best all-around choice for a technical blog with lead magnets. Free tier is generous (10K subscribers!), native lead magnet delivery, and full API for integration with tamirdresher.com.

---

### 3. Buttondown

| Feature | Details |
|---------|---------|
| **Pricing** | Free up to 100 subscribers; $9/mo for Basic (up to 1K) |
| **Free Tier** | 100 subscribers (very limited) |
| **Paid Tier** | $9/mo (1K subs), $29/mo (5K subs), $79/mo (25K subs) |
| **Built-in Monetization** | ✅ Paid subscriptions via Stripe |
| **Custom Domain** | ✅ Yes |
| **Lead Magnets** | ⚠️ Manual — use welcome email with download link |
| **Analytics** | Basic (opens, clicks) |
| **Design** | Minimal — Markdown-first (great for developers) |
| **API** | ✅ Full REST API (well-documented) |
| **Integrations** | Limited but growing; GitHub integration |
| **Best For** | Indie developers who want simplicity and control |
| **Downsides** | Tiny free tier (100 subs), fewer features than ConvertKit |

**Verdict:** Very developer-friendly (Markdown-first, good API, GitHub integration). But the free tier is too small for meaningful growth. Good backup choice if you outgrow ConvertKit's free tier and want something indie.

---

### 4. Additional Options Considered

#### Mailchimp
- Free up to 500 contacts (was 2K, they reduced it)
- Overly complex for a personal blog
- **Skip** — free tier too limited, UI bloated

#### Ghost
- $9/mo (self-hosted is free but needs server)
- Beautiful, built for publishers
- **Consider later** — if Tamir wants to move entire blog to Ghost

#### Beehiiv
- Free up to 2.5K subscribers
- Built for newsletter businesses
- Strong analytics and monetization
- **Honorable mention** — worth considering if newsletter becomes primary

---

## Recommendation

### 🏆 **ConvertKit (Kit) — Free Plan**

**Why ConvertKit wins for Tamir:**

1. **10K free subscribers** — Enough runway for 1-2 years of growth
2. **Native lead magnet delivery** — Upload PDFs, auto-deliver on signup (critical for the 3 lead magnets we're creating)
3. **Embeddable forms** — Drop a signup widget directly into tamirdresher.com
4. **Landing pages** — Create dedicated pages for each lead magnet
5. **Tagging system** — Tag subscribers by interest (MCP, Squad, .NET) for targeted content
6. **API integration** — Full REST API to integrate with any static site
7. **Upgrade path** — When you need automations, $25/mo unlocks sequences + funnels
8. **Creator economy** — Sell digital products (workshop recordings, templates) directly

**Setup Plan:**
1. Sign up at https://convertkit.com (use the Creator plan's free tier)
2. Create 3 forms (one per lead magnet)
3. Upload lead magnet PDFs as "incentive emails" 
4. Embed forms on tamirdresher.com
5. Create a welcome sequence (3 emails introducing the blog)
6. Tag subscribers by lead magnet downloaded

**Alternatives by Scenario:**

| If... | Then Consider... |
|-------|-------------------|
| You want the simplest possible setup | Buttondown ($9/mo) |
| You want newsletter AS the product | Substack (free) |
| You want full publishing platform | Ghost ($9/mo or self-host) |
| You want maximum free analytics | Beehiiv (free to 2.5K) |
| You outgrow 10K subscribers | Stay on ConvertKit, upgrade to $25/mo |

---

## Implementation Timeline

| Week | Action | Platform |
|------|--------|----------|
| 1 | Sign up for ConvertKit free plan | ConvertKit |
| 1 | Create 3 signup forms (one per lead magnet) | ConvertKit |
| 1 | Upload lead magnet PDFs | ConvertKit |
| 2 | Add signup widget to tamirdresher.com | Blog |
| 2 | Create landing pages for each lead magnet | ConvertKit |
| 3 | Write 3-email welcome sequence | ConvertKit |
| 4 | Promote lead magnets in blog posts | Blog |
| Ongoing | Weekly/biweekly newsletter | ConvertKit |
