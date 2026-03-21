# Platform Infrastructure Area

This is an example area demonstrating per-area `.squads/` configuration.

## Overview

The Platform area contains:
- **Helm charts** for Kubernetes deployments
- **Terraform** for Azure infrastructure
- **Go services** for platform APIs

## Squad Assignment

- **B'Elanna**: Infrastructure, K8s, Azure, CI/CD
- **Worf**: Security review for all infrastructure changes
- **Data**: Go services, testing, code quality

## Key Files

- `helm/values.yaml` - Helm configuration
- `terraform/main.tf` - Infrastructure as code
- `services/gateway/main.go` - API gateway service

## Development Conventions

See `.squads/config.json` for:
- Routing rules
- Required capabilities
- Code style guidelines
- Testing requirements
