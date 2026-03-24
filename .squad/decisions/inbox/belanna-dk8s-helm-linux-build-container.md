# Decision: DK8S linux_build_container Must Include Helm

**Date:** 2026-03-24
**Author:** B'Elanna (Infrastructure Expert)
**Status:** Active
**Issue:** #1397
**PR:** #1455

## Decision

The `linux_build_container` Docker image used in the DK8S CI/CD pipeline **must** have helm pre-installed and mirrored to the legacy DK8S package path.

## Context

Issue #1397: the mps-infra-k8s-ev2-deployment package stopped bundling a helm binary at `Tools/linux/helm`. This broke the "Download shared dk8s charts and scripts (linux_build_container)" pipeline step.

## Constraints

- **Legacy path must remain valid:** `/__w/_temp/Dk8sDeployPackages/mps-infra-k8s-ev2-deployment/Tools/linux/helm`
  Any pipeline step that references this hard-coded path must continue to work. Do not change downstream consumers.
- **Helm version:** Pin to `v3.14.4` (or newer LTS). Update `Dockerfile.linux-build-container` and `dk8s-deploy.yml` together when bumping.
- **Self-healing pattern:** The `dk8s-deploy.yml` workflow symlinks the installed helm binary to the legacy path as a fallback. This pattern must be preserved in any future rewrites of that workflow.

## Files

- `infrastructure/docker/Dockerfile.linux-build-container` — container image definition
- `.github/workflows/dk8s-deploy.yml` — DK8S deployment workflow with helm install + legacy path setup
