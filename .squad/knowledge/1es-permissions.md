# 1ES Permissions Service — Elevated Access & PIM Elevation

> **Source:** Shay (team knowledge share)
> **Reference:** [1ES Permissions Service — How to get elevated permissions (PIM)](https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/access-control-permissions/1espermissionsservice#how-to-get-elevated-permissions-pim)

---

## 1. Repository Elevated Permissions

Use this when you need elevated access to a 1ES repository (e.g., write/admin on a specific repo).

| Detail | Value |
|--------|-------|
| **Account required** | CORP account (regular — no sc-alt needed) |
| **Method** | Join the **Service Administrators access package** |

### Steps

1. Sign in with your **CORP account**.
2. Navigate to the 1ES Permissions Service access packages (see reference link above).
3. Request the **Service Administrators** access package for the relevant repository/service.
4. Wait for approval (may be auto-approved depending on your org).
5. Once granted, you will have elevated repository permissions.

---

## 2. Project Admin (PA) PIM Elevation

Use this when you need **Project Administrator** level access (e.g., managing build pipelines, policies, or area paths at the project level).

| Detail | Value |
|--------|-------|
| **Account required** | **sc-alt account** (your security-context alternate admin account) |
| **Method** | PIM (Privileged Identity Management) elevation to Project Administrators |

### Steps

1. Sign in with your **sc-alt account**.
2. Go to the PIM elevation portal for the relevant Azure DevOps project.
3. Request elevation to **Project Administrators**.
4. Complete any required justification/approval steps.
5. Once activated, your sc-alt account will have PA-level access for the elevation window.

---

## 3. Notes

- **Infra teams** are already added to the Project Administrators group — if you're on an infra team, you may already have PA access and only need to PIM-activate it.
- Repository-level elevation (Section 1) does **not** require an sc-alt account — use your regular CORP account.
- PA elevation (Section 2) **does** require the sc-alt account.
- Elevation is time-limited; re-elevate when access expires.

---

## Quick Reference for Tamir

| I need to… | Account | Action |
|------------|---------|--------|
| Get elevated repo permissions | CORP (regular) | Join **Service Administrators** access package |
| Get Project Admin access | **sc-alt** | PIM elevate to **Project Administrators** |
| Check if I already have PA | sc-alt | Check group membership in the Azure DevOps project settings |

📖 **Full docs:** [1ES Permissions Service on eng.ms](https://eng.ms/docs/microsoft-security/microsoft-threat-protection-mtp/onesoc-1soc/infra-and-developer-platform-scip-idp/infra-and-developer-platform-scip-idp/access-control-permissions/1espermissionsservice#how-to-get-elevated-permissions-pim)
