# KEDA/AKS Implementation Breakdown — Issues #1134, #1136, #1141

Date: 2026-03-20
Author: Picard
Status: Decided

## Decision
Split the three `go:research-done` KEDA/AKS issues into 9 concrete implementation child issues.

## Issue #1134 — KEDA token-aware scaling
Two child issues, sequential:
- **#1154** — Build GitHub rate-limit Prometheus metrics exporter (Go, `prometheus/client_golang`)
- **#1160** — Configure KEDA ScaledObject with `scalingModifiers.formula` composite AND trigger (KEDA v2.12+ required)

Key constraint: #1154 must ship first. Formula: `work_queue > 0 && rate_headroom > 200 ? work_queue : 0`

## Issue #1136 — AKS Automatic vs Standard
Three child issues:
- **#1149** — Bicep IaC for dual-tier cluster provisioning (Standard Free dev / Automatic prod)
- **#1159** — Helm chart `aksMode` param + conditional nodeSelector for Automatic compatibility
- **#1161** — `docs/squad-on-aks.md` dual-path guide with cost comparison

**Architectural decision: Start with AKS Standard Free (~$55-80/mo) for initial deployment.** Migrate to Automatic when Squad reaches production scale. Cost difference: ~$100/mo, and we lose fine-grained node control on Automatic.

## Issue #1141 — KEDA scaler OSS opportunity
Three-tier plan:
- **#1158** (Tier 1) — Config-only: add built-in `github-runner` KEDA trigger to Helm chart
- **#1155** (Tier 2) — Deploy `infinityworks/github-exporter` as Prometheus bridge (interim)
- **#1156** (Tier 3) — Create `keda-github-copilot-scaler` as new OSS repo (Apache 2.0, Go, gRPC external scaler)

**No Copilot-aware KEDA scaler exists anywhere in the open source ecosystem.** Tier 3 is a genuine community contribution. Phase 1 MVP: `github_rate_limit_remaining` + `github_rate_limit_used_pct`. Phase 2 adds `copilot_active_users`.

## Routing
All child issues labeled `squad:belanna` (infrastructure work).
