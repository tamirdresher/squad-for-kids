# Decision: iOS Publishing Path for JellyBolt Games

**Date:** 2025  
**Source:** Issue #974 research  
**Author:** Seven

## Decision

For publishing JellyBolt HTML5 games to the iOS App Store without Mac hardware, the recommended approach is **Expo EAS Build** (React Native WebView wrapper).

## Rationale

- JellyBolt games are pure HTML5/JS — trivial to wrap in a WebView
- Expo EAS builds iOS .ipa files in Apple's cloud with no local Mac required
- Free tier (15 builds/month) is sufficient for an indie game company
- Only unavoidable cost: Apple Developer Account at $99/year
- Also produces Android APK from the same codebase

## Infrastructure Impact (for Belanna)

- No new infrastructure required for the build pipeline
- Optional: GitHub Actions workflow using `eas build` for automated releases
- Belanna should note: macOS GitHub Actions runners are **not** needed if using Expo EAS
- If CI/CD is preferred: Codemagic free tier (500 min/month) is zero-cost alternative

## Research Artifact

Full report at: `research/ios-publishing-without-mac.md`
