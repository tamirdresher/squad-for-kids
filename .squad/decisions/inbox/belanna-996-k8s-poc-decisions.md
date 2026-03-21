# Decision: Squad-on-K8s ralph-dockerfile/ and ralph-deployment.yaml structure

**Date:** 2026-03-20
**Agent:** B'Elanna
**Issue:** #996

## Decision

The infrastructure/k8s/ralph-dockerfile/Dockerfile uses a **subdirectory layout** 
(separate from Dockerfile.ralph at the k8s root) to enable future multi-agent 
dockerfiles to live in sibling directories (scribe-dockerfile/, picard-dockerfile/, etc.)
without polluting the k8s/ root.

The alph-deployment.yaml uses **strategy: Recreate** (not RollingUpdate) because 
Ralph is a singleton monitor — two concurrent instances would cause duplicate polling rounds 
and write conflicts on the lockfile.

## GH_TOKEN injection pattern

Credentials flow: K8s Secret → secretKeyRef in Deployment env → GH_TOKEN env var read 
automatically by gh CLI. No gh auth login needed in the container.

Production path: Workload Identity (AKS managed identity) replaces the PAT. The Helm 
serviceAccount.annotations already has a commented-out example for this.

## Volume mount pattern

.squad/ config (team.md, routing.md, squad.config.ts) is mounted from ConfigMap, 
**not** baked into the image. This allows config changes without rebuilding/redeploying 
the image — just helm upgrade or update the ConfigMap.
