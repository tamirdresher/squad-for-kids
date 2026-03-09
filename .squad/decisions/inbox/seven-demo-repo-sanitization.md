# Decision: Repository Sanitization Strategy for Public Demos

**Date:** 2026-03-25  
**Author:** Seven (Research & Docs)  
**Issue:** #225  
**PR:** #226  
**Status:** 🟡 Proposed (awaiting team review)  
**Scope:** Open Source Contribution, Documentation

## Context

Creating a public-facing demo repository from an internal working repository (tamresearch1) requires comprehensive sanitization to remove sensitive data while preserving the value of Squad patterns and examples for community contribution to bradygaster/squad.

## Decision

**Multi-Layered Sanitization Strategy for Public Squad Demos:**

1. **Categorize Sensitive Data by Risk Level** (8 categories identified)
2. **Three-Tiered Sanitization Approach:** Automated + Exclusion + Manual Review
3. **PowerShell Automation Script with Safety Features**
4. **Scope Definition:** Include Squad infrastructure, exclude agent histories/Azure code
5. **Public README Strategy:** Value proposition focused with quick start guide

## Implementation

**Phase 1 (Complete):** Planning, script creation, checklist, demo README  
**Phase 2-3 (Next):** Execute script, manual review

**Files Created:**
- SANITIZATION_PLAN.md
- scripts/sanitize-for-demo.ps1
- SANITIZATION_CHECKLIST.md
- DEMO_README.md
