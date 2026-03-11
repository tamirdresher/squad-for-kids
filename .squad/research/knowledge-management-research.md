# Knowledge Management Research for AI Agent Teams

## Executive Summary

After researching how AI agent teams manage growing knowledge bases, I've identified several approaches that could work for this GitHub-based project. The .squad/ directory is currently ~33MB (655 files, mostly markdown), with the primary bloat coming from compiled binaries in tools/squad-monitor (~29.5MB). The markdown knowledge base itself is manageable but will grow as agent interactions accumulate.

## Current State Analysis

**Size Breakdown:**
- Total .squad/ size: ~33MB (655 files)
- Largest component: .squad/tools/squad-monitor/bin/ (29.5MB) - compiled .NET binaries
- Core knowledge files: ~3.5MB markdown across agents/decisions/orchestration
- Largest markdown files: decisions.md (729KB), seven/history.md (287KB)

**The Problem:** As agents work more, markdown files will balloon. GitHub has file size limits (100MB per file, 1GB repository recommended max).

## Solution Approaches (Ranked by Feasibility)

### 1. Structured Markdown + Git-Native Indexing (RECOMMENDED)
Keep everything in markdown but implement smart archival and GitHub's native search.
- Archive by time period: Monthly/quarterly rotation of agent history
- GitHub Wiki for stable reference docs
- GitHub Discussions for Q&A archives
- Leverage GitHub Code Search
- Index file pattern: Create INDEX.md files

Pros: No binary files, no new tooling, git diff/blame work perfectly, gradual implementation.
Cons: Manual archival (scriptable), no semantic search, large files slow.

### 2. Embedded Vector DB (ChromaDB/FAISS) + Markdown Source of Truth
Keep markdown as source, build searchable vector index locally (not committed).
Pros: Semantic search, no binary bloat, handles large corpus.
Cons: Requires Python environment, index rebuild time, complexity.

### 3. Git-Annex for Historical Archives
Recent data in git, historical data in git-annex (pointer-based, no bloat).
Pros: Zero repository bloat, flexible storage backends.
Cons: Learning curve, workflow friction.

### 4. SQLite + Text Exports (Dual Storage)
Agent memory in SQLite (fast queries), periodic export to markdown.
Pros: Fast structured queries, human-readable exports.
Cons: Dual storage complexity, synchronization needed.

### 5. GitHub Pages + Search Index
Render markdown to static site with search.
Pros: Beautiful browseable docs, fast search.
Cons: Doesn't solve repo size, agents need web API access.

## Recommendation

Implement Approach 1 (Structured Markdown + Archival) immediately, with optional Approach 2 (Vector DB) as future enhancement.

Phase 1: Rotate history quarterly, split decisions.md, create INDEX.md files, move compiled binaries out, add search docs.
Phase 2: Add ChromaDB indexing when markdown exceeds 50MB.

Cost: 2-4 hours for Phase 1. Ongoing 15 min/quarter. Repository stays under 5MB.
