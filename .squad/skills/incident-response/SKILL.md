# Incident Response Skill: Azure Status Check

## Pattern
During any incident or ICM, **FIRST check Azure Status** to determine if it's a broader Azure infrastructure issue.

## Why
Quickly distinguish "our problem" from "Azure-wide outage." During an incident, the Azure Status page reveals if other services are affected, proving that the incident is not isolated to our system. This reduces blame during incident resolution and redirects focus appropriately.

**Real Example:** During an incident, the team discovered multiple Azure services were degraded simultaneously. Checking Azure Status showed others were also affected, proving it wasn't a fault in their deployment or configuration.

## How

1. **Navigate to Azure Status:** https://azure.status.microsoft/en-us/status
2. **Check for Active Incidents:** Look for any ongoing incidents or maintenance in relevant services:
   - Azure Kubernetes Service (AKS)
   - Key Vault
   - Azure Networking (ExpressRoute, Load Balancer, etc.)
   - Azure Storage
   - Azure Container Registry
3. **Verify Timeline:** Check if the incident started around the same time as your ICM
4. **Document Findings:** Note the service(s) affected in your incident post-mortem or incident notes

## Confidence
**Medium** — First documented observation, validated by real incident experience from production incident response.

## Domain
- incident-response
- reliability
- infrastructure

## Related Skills
- Incident triage procedures
- Post-incident reporting
- Root cause analysis

## Last Updated
2026-03-12 — Documented by Belanna based on Joshua's incident discovery pattern
