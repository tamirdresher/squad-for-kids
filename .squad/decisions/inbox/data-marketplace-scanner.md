# Decision: AI Marketplace Scanner Implementation

**Date:** 2025-01-24  
**Author:** Data  
**Issue:** #283

## Context
Tamir requested weekly monitoring of https://aka.ms/ai/marketplace for new AI tools/offerings. Previous attempt by Seven failed because they didn't visit the actual URL.

## Decision
Implemented a fallback strategy for marketplace monitoring:

1. **Primary:** Try to fetch https://aka.ms/ai/marketplace via curl
2. **Fallback:** If auth required (SSO detected), use GitHub Marketplace API instead
   - Search categories: ai, machine-learning, code-quality, copilot
   - Search GitHub Actions with AI/Copilot keywords
   - Deduplicate and cache results

## Rationale
- The aka.ms/ai/marketplace URL requires Microsoft SSO authentication
- GitHub Actions runner can't authenticate to Microsoft EMU
- GitHub Marketplace API provides public, programmatic access to similar data
- Fallback approach is more resilient than auth-dependent solution

## Implementation
- Script: `scripts/marketplace-scanner.js`
- Workflow: `.github/workflows/marketplace-check.yml`
- Cache: `.squad/marketplace-cache.json`
- Schedule: Weekly Monday 8 AM UTC

## Implications
- Team will get notifications about AI/ML tool updates on GitHub
- Seven triages issues (squad:seven label)
- May not capture Microsoft-internal tools from aka.ms/ai/marketplace
- Can be manually triggered anytime via workflow_dispatch

## Alternatives Considered
- Playwright with auth: Too complex, requires credential management
- Manual checking: Defeats automation purpose
- Different URL: aka.ms likely redirects to GitHub or internal portal

## Status
✅ Implemented and tested
