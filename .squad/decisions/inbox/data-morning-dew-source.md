# Decision: Morning Dew RSS Source for Tech News Scanner

**Author:** Data  
**Date:** 2026-03-13  
**Issue:** #461  
**PR:** #462  

## Context

Tamir requested adding alvinashcraft.com (The Morning Dew) as a news source for the tech news scanner.

## Decision

- **RSS parsing via regex** — no new npm dependencies. The existing `httpsGet()` already returns raw text when JSON parsing fails, so it works for XML feeds out of the box.
- **Base score of 50** for Morning Dew items since RSS has no upvote/score mechanism. This places RSS items below high-scoring HackerNews/Reddit stories but above low-engagement ones.
- **CDATA handling** — WordPress RSS feeds often wrap titles in `<![CDATA[...]]>`. The regex handles both CDATA-wrapped and plain `<title>` tags.

## Impact

The tech news scanner now aggregates from 3 source types: HackerNews API, Reddit JSON, and Morning Dew RSS. The RSS pattern can be reused for other WordPress/RSS feeds in the future.
