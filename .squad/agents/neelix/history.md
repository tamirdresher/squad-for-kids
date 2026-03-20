# Neelix — History

## Current Quarter (2026-Q2)

*This file tracks work for 2026 Q2 (April-June). Q1 archive: history-2026-Q1.md*

## Active Context

TBD - Q2 work incoming

### 2026-03-11 Completion: Teams Status Update

**Task:** Delivered team status notification via webhook  
**Status:** ✅ Complete

## Learnings

### 2026-03-20 Security Fix: HTML Sanitization

**Context:** Fixed CodeQL alert `js/incomplete-html-attribute-sanitization` in `scripts/tech-news-scanner.js`

**Issue:** The `escHtml()` function was escaping `<`, `>`, and `&` but not double quotes (`"`). When the output was used in HTML attributes like `<a href="${url}">`, an attacker could inject a double quote to break out of the attribute and inject malicious code.

**Fix:** 
- Added `.replace(/"/g, '&quot;')` to `escHtml()` function
- Applied `escHtml()` to URL values used in href attributes (line 1030)

**Key Learning:** When sanitizing HTML for use in attributes, ALWAYS escape double quotes. Standard HTML entity escaping (`< > &`) is insufficient for attribute contexts. CodeQL caught this vulnerability correctly.
*Learnings will accumulate here during Q2.*

### 2026-03-20 Round 2: CodeQL Fix

**Task:** Fix PR #1145 CodeQL failure  
**Action:** New CI runs queued  
**Status:** ⏳ Awaiting CI verification
