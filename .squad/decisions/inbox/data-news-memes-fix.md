# Decision: Merge News Image Generation to Main (Issue #534)

**Date:** 2026-03-14  
**Decided by:** Data (Code Expert)  
**Context:** Issue #534 — "news reporter with memes didn't work today"

## Problem

Neelix's news broadcasts were supposed to include AI-generated images (banners + memes) but the feature wasn't active. Investigation revealed the implementation existed on branch `squad/526-neelix-images-CPC-tamir-WCBED` but was never merged to main.

## Decision

**Merged image generation scripts from feature branch to main.**

### What Was Merged

1. **`scripts/generate-news-image.ps1`** (new file, 169 lines)
   - Standalone PowerShell script that calls Google Gemini 2.0 Flash API
   - Supports 3 image styles: banner (news header), meme (funny), status (infographic)
   - Returns base64 data URI for inline Adaptive Card embedding
   - Saves images to `~/Documents/nano-banana-images/neelix/`

2. **`scripts/daily-rp-briefing.ps1`** (updated)
   - Added `-SkipImages` parameter for text-only fallback
   - Generates 2 images per broadcast:
     - Header banner based on top story (blockers, merged PRs, activity)
     - Meme if there's good news (3+ merged PRs or 10+ commits)
   - Embeds images inline in Adaptive Card sections

### Technical Details

- **API:** Google Gemini 2.0 Flash Exp with `responseModalities: ["TEXT", "IMAGE"]`
- **Authentication:** Requires `GOOGLE_API_KEY` environment variable
- **Graceful Degradation:** Falls back to text-only if API key not set or API call fails
- **Size Limit:** Warns if image >900KB (Adaptive Card inline limit ~1MB)

### Why This Approach

- **Optional by default:** Broadcasts work without images if `GOOGLE_API_KEY` not configured
- **Standalone script:** Can be used independently or integrated into other workflows
- **Minimal dependencies:** Pure PowerShell + REST API, no Python/Node required
- **Cost-efficient:** Gemini 2.0 Flash is free tier eligible for moderate usage

## Implications

1. **Setup Required:** Users must set `GOOGLE_API_KEY` to enable image generation
2. **Cost Awareness:** Gemini API usage applies (currently free tier, monitor if scaled)
3. **Fallback Tested:** Script tested without API key — gracefully skips images
4. **Ready for Prod:** Merged to main, available in all environments

## Next Steps

1. Document `GOOGLE_API_KEY` setup in `.squad/ONBOARDING.md` or equivalent
2. Consider blob storage for images if inline embedding becomes problematic
3. Monitor Gemini API quota usage if broadcasts scale up

---

**Related:**
- Issue: #534
- Feature branch: `squad/526-neelix-images-CPC-tamir-WCBED`
- Commit: 466ad057 (main)
