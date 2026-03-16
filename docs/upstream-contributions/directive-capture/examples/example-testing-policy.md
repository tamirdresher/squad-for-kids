### 2025-06-15T11:45:00Z: Never skip tests for security code

**Captured:** 2025-06-15
**By:** Tamir (via Coordinator)
**Severity:** critical

## Directive

Never skip tests for security-related code. All authentication, authorization, and data validation modules must have unit and integration tests before merging.

## Context

Stated after a security review found untested input validation in the auth middleware.
