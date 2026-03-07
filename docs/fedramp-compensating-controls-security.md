# FedRAMP Compensating Controls — Security Implementation Guide

**Issue:** #54 — FedRAMP: Implement Compensating Controls — WAF, Network Policies, OPA for Ingress  
**Author:** Worf (Security & Cloud)  
**Date:** 2026-03-07  
**Classification:** FedRAMP HIGH Baseline  
**Related:** #51 (P0 Assessment), #46 (STG-EUS2-28 Incident), CVE-2026-24512 (CVSS 8.8)

---

## Executive Summary

CVE-2026-24512 exposed that DK8S has **zero compensating controls** for ingress-layer attacks. This document delivers four security layers that, combined, ensure no single CVE can again escalate to a P0 incident:

1. **WAF Rules** — Block malicious requests before they reach nginx-ingress
2. **OPA/Gatekeeper Policies** — Prevent creation of dangerous Ingress resources at admission time
3. **CI/CD Vulnerability Scanning** — Catch insecure configurations before deployment
4. **Emergency Patching Runbook** — Structured response when a new CVE drops

These controls satisfy FedRAMP SC-7 (Boundary Protection), SI-3 (Malicious Code Protection), CM-3 (Configuration Change Control), and IR-4 (Incident Handling).

---

## 1. WAF Implementation — Azure Front Door / Application Gateway

### 1.1 Architecture Decision

**Recommendation: Azure Front Door Premium with WAF Policy**

| Criteria | Azure Front Door | Application Gateway |
|----------|-----------------|---------------------|
| Global distribution | ✅ Native | ❌ Regional |
| Sovereign cloud support | ✅ (Fairfax, Mooncake) | ✅ |
| DDoS protection | ✅ Built-in | ⚠️ Requires DDoS Standard |
| Bot protection | ✅ Built-in | ❌ |
| Private Link to AKS | ✅ | ✅ |
| FedRAMP authorization | ✅ FedRAMP High | ✅ FedRAMP High |

Use **Azure Front Door Premium** for public-cloud clusters. For sovereign/gov clusters where Front Door availability is limited, deploy **Application Gateway v2 with WAF_v2 SKU** in prevention mode.

### 1.2 WAF Policy — OWASP Ruleset Configuration

```json
{
  "properties": {
    "policySettings": {
      "enabledState": "Enabled",
      "mode": "Prevention",
      "requestBodyCheck": "Enabled",
      "maxRequestBodySizeInKb": 128,
      "requestBodyInspectLimitInKB": 128
    },
    "managedRules": {
      "managedRuleSets": [
        {
          "ruleSetType": "Microsoft_DefaultRuleSet",
          "ruleSetVersion": "2.1",
          "ruleGroupOverrides": [
            {
              "ruleGroupName": "REQUEST-932-APPLICATION-ATTACK-RCE",
              "rules": [
                {
                  "ruleId": "932100",
                  "enabledState": "Enabled",
                  "action": "Block"
                },
                {
                  "ruleId": "932110",
                  "enabledState": "Enabled",
                  "action": "Block"
                }
              ]
            },
            {
              "ruleGroupName": "REQUEST-941-APPLICATION-ATTACK-XSS",
              "rules": [
                {
                  "ruleId": "941100",
                  "enabledState": "Enabled",
                  "action": "Block"
                }
              ]
            },
            {
              "ruleGroupName": "REQUEST-942-APPLICATION-ATTACK-SQLI",
              "rules": [
                {
                  "ruleId": "942100",
                  "enabledState": "Enabled",
                  "action": "Block"
                }
              ]
            }
          ]
        },
        {
          "ruleSetType": "Microsoft_BotManagerRuleSet",
          "ruleSetVersion": "1.1"
        }
      ]
    }
  }
}
```

### 1.3 Custom WAF Rules — nginx-Specific Attack Patterns

These custom rules target the CVE-2026-24512 attack vector (path injection) and related nginx configuration injection patterns.

#### Rule 1: Block nginx Configuration Injection via Path

Blocks Ingress path values containing nginx configuration directives.

```json
{
  "name": "BlockNginxConfigInjection",
  "priority": 1,
  "ruleType": "MatchRule",
  "action": "Block",
  "matchConditions": [
    {
      "matchVariable": "RequestUri",
      "operator": "RegEx",
      "matchValue": [
        ".*[;{}].*",
        ".*\\blua_\\w+\\b.*",
        ".*\\bproxy_pass\\b.*",
        ".*\\broot\\s+/.*",
        ".*\\balias\\s+/.*",
        ".*\\brewrite\\b.*\\bbreak\\b.*",
        ".*\\bset\\s+\\$.*",
        ".*\\baccess_log\\b.*",
        ".*\\berror_log\\b.*"
      ],
      "negateCondition": false,
      "transforms": ["Lowercase", "UrlDecode"]
    }
  ]
}
```

#### Rule 2: Block Annotation Abuse Patterns

Blocks requests with headers that could indicate annotation-based injection (CVE-2025-1974).

```json
{
  "name": "BlockAnnotationInjection",
  "priority": 2,
  "ruleType": "MatchRule",
  "action": "Block",
  "matchConditions": [
    {
      "matchVariable": "RequestHeader",
      "selector": "X-Forwarded-For",
      "operator": "RegEx",
      "matchValue": [
        ".*\\bsnippet\\b.*",
        ".*\\bconfiguration-snippet\\b.*",
        ".*\\bserver-snippet\\b.*",
        ".*\\bstream-snippet\\b.*"
      ],
      "negateCondition": false,
      "transforms": ["Lowercase"]
    }
  ]
}
```

#### Rule 3: Rate Limit Heartbeat Endpoint

Protects the unauthenticated heartbeat endpoint from DDoS (CVE-2026-24514).

```json
{
  "name": "RateLimitHeartbeat",
  "priority": 3,
  "ruleType": "RateLimitRule",
  "action": "Block",
  "rateLimitThreshold": 100,
  "rateLimitDurationInMinutes": 1,
  "matchConditions": [
    {
      "matchVariable": "RequestUri",
      "operator": "Contains",
      "matchValue": ["/healthz", "/nginx_status", "/heartbeat"],
      "negateCondition": false,
      "transforms": ["Lowercase"]
    }
  ]
}
```

### 1.4 Deployment — Bicep Template

```bicep
@description('WAF policy for DK8S ingress protection')
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: 'waf-dk8s-ingress'
  location: 'global'
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.1'
        }
      ]
    }
    customRules: {
      rules: [
        // Deploy custom rules from Section 1.3
      ]
    }
  }
}
```

### 1.5 Sovereign Cloud Considerations

| Cloud | WAF Option | Notes |
|-------|-----------|-------|
| Public (commercial) | Azure Front Door Premium | Full feature parity |
| Fairfax (US Gov) | Application Gateway WAF_v2 | Front Door Premium available; verify feature parity |
| Mooncake (China) | Application Gateway WAF_v2 | Front Door features may lag; validate OWASP ruleset version |
| Sovereign (air-gapped) | Application Gateway WAF_v2 | Must use regional deployment; no global Front Door |

**For all sovereign deployments:** Deploy Application Gateway WAF in **Prevention mode** from day one. Detection mode is not acceptable for FedRAMP HIGH baseline.

---

## 2. OPA/Gatekeeper Admission Policies

### 2.1 Policy Overview

| Policy | Threat Mitigated | Severity |
|--------|-----------------|----------|
| Block Path Injection | CVE-2026-24512 | CRITICAL |
| Enforce Annotation Allowlist | CVE-2025-1974, annotation abuse | HIGH |
| Restrict Backend Targets | Unauthorized service exposure | HIGH |
| Require TLS | Cleartext traffic interception | MEDIUM |
| Block Wildcard Hosts | Subdomain takeover | MEDIUM |

### 2.2 Policy 1: Block Ingress Path Injection

This is the primary defense against CVE-2026-24512.

#### ConstraintTemplate

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singresssafepath
  annotations:
    description: "Blocks Ingress path values containing nginx configuration injection patterns"
    metadata.gatekeeper.sh/title: "DK8S Ingress Safe Path"
    metadata.gatekeeper.sh/requires-sync-data: "false"
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressSafePath
      validation:
        openAPIV3Schema:
          type: object
          properties:
            blockedPatterns:
              type: array
              items:
                type: string
              description: "Regex patterns that are blocked in Ingress path values"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singresssafepath

        import future.keywords.in

        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          some path in rule.http.paths
          pattern := input.parameters.blockedPatterns[_]
          regex.match(pattern, path.path)
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' path '%s' matches blocked pattern '%s'. " +
            "Path injection detected (CVE-2026-24512 mitigation). Contact platform-security@.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name, path.path, pattern]
          )
        }

        # Also block paths with raw nginx directives
        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          some path in rule.http.paths
          contains(path.path, ";")
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' path contains semicolon — potential nginx directive injection. " +
            "Blocked per CVE-2026-24512 policy.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name]
          )
        }

        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          some path in rule.http.paths
          contains(path.path, "}")
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' path contains closing brace — potential config block injection.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name]
          )
        }
```

#### Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DK8SIngressSafePath
metadata:
  name: block-ingress-path-injection
  labels:
    security.dk8s.io/category: ingress
    security.dk8s.io/severity: critical
    security.dk8s.io/cve: CVE-2026-24512
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["Ingress"]
      - apiGroups: ["extensions"]
        kinds: ["Ingress"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
  parameters:
    blockedPatterns:
      - ".*\\blua_.*"
      - ".*\\bproxy_pass\\b.*"
      - ".*\\broot\\s+/.*"
      - ".*\\balias\\s+/.*"
      - ".*\\brewrite\\b.*"
      - ".*\\bset\\s+\\$.*"
      - ".*\\baccess_log\\b.*"
      - ".*\\berror_log\\b.*"
      - ".*\\bload_module\\b.*"
      - ".*\\binclude\\b.*\\.conf.*"
      - ".*\\bssl_certificate\\b.*"
      - ".*\\bupstream\\b.*"
```

### 2.3 Policy 2: Enforce Annotation Allowlist

Prevents annotation-based configuration injection (CVE-2025-1974 vector).

#### ConstraintTemplate

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singressannotationallowlist
  annotations:
    description: "Restricts Ingress annotations to an explicit allowlist"
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressAnnotationAllowlist
      validation:
        openAPIV3Schema:
          type: object
          properties:
            allowedAnnotations:
              type: array
              items:
                type: string
              description: "Annotation key patterns (regex) that are allowed"
            blockedAnnotations:
              type: array
              items:
                type: string
              description: "Annotation key patterns (regex) that are explicitly blocked"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singressannotationallowlist

        import future.keywords.in

        # Block explicitly dangerous annotations
        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          annotations := input.review.object.metadata.annotations
          key := object.keys(annotations)[_]
          pattern := input.parameters.blockedAnnotations[_]
          regex.match(pattern, key)
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' uses blocked annotation '%s'. " +
            "Snippet/configuration annotations are prohibited (CVE-2025-1974 mitigation).",
            [input.review.object.metadata.namespace, input.review.object.metadata.name, key]
          )
        }

        # Deny annotations not in allowlist
        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          annotations := input.review.object.metadata.annotations
          key := object.keys(annotations)[_]
          startswith(key, "nginx.ingress.kubernetes.io/")
          not annotation_allowed(key)
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' uses non-allowlisted nginx annotation '%s'. " +
            "Submit a security review request to add this annotation to the allowlist.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name, key]
          )
        }

        annotation_allowed(key) {
          pattern := input.parameters.allowedAnnotations[_]
          regex.match(pattern, key)
        }
```

#### Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DK8SIngressAnnotationAllowlist
metadata:
  name: ingress-annotation-allowlist
  labels:
    security.dk8s.io/category: ingress
    security.dk8s.io/severity: high
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["Ingress"]
      - apiGroups: ["extensions"]
        kinds: ["Ingress"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
  parameters:
    blockedAnnotations:
      - ".*snippet.*"
      - ".*configuration-snippet.*"
      - ".*server-snippet.*"
      - ".*stream-snippet.*"
      - ".*lua-resty.*"
      - ".*modsecurity.*"
      - ".*global-rate-limit.*"
    allowedAnnotations:
      - "^nginx\\.ingress\\.kubernetes\\.io/rewrite-target$"
      - "^nginx\\.ingress\\.kubernetes\\.io/ssl-redirect$"
      - "^nginx\\.ingress\\.kubernetes\\.io/force-ssl-redirect$"
      - "^nginx\\.ingress\\.kubernetes\\.io/backend-protocol$"
      - "^nginx\\.ingress\\.kubernetes\\.io/proxy-body-size$"
      - "^nginx\\.ingress\\.kubernetes\\.io/proxy-read-timeout$"
      - "^nginx\\.ingress\\.kubernetes\\.io/proxy-send-timeout$"
      - "^nginx\\.ingress\\.kubernetes\\.io/proxy-connect-timeout$"
      - "^nginx\\.ingress\\.kubernetes\\.io/use-regex$"
      - "^nginx\\.ingress\\.kubernetes\\.io/cors-allow-origin$"
      - "^nginx\\.ingress\\.kubernetes\\.io/cors-allow-methods$"
      - "^nginx\\.ingress\\.kubernetes\\.io/cors-allow-headers$"
      - "^nginx\\.ingress\\.kubernetes\\.io/enable-cors$"
      - "^nginx\\.ingress\\.kubernetes\\.io/whitelist-source-range$"
      - "^nginx\\.ingress\\.kubernetes\\.io/auth-type$"
      - "^nginx\\.ingress\\.kubernetes\\.io/auth-secret$"
      - "^nginx\\.ingress\\.kubernetes\\.io/auth-url$"
```

### 2.4 Policy 3: Restrict Backend Service Targeting

Prevents Ingress resources from targeting sensitive infrastructure services.

#### ConstraintTemplate

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singressbackendrestriction
  annotations:
    description: "Restricts which backend services an Ingress can target"
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressBackendRestriction
      validation:
        openAPIV3Schema:
          type: object
          properties:
            blockedServices:
              type: array
              items:
                type: string
              description: "Service name patterns that cannot be targeted by Ingress"
            blockedNamespaces:
              type: array
              items:
                type: string
              description: "Namespaces whose services cannot be targeted by cross-namespace Ingress"
            blockedPorts:
              type: array
              items:
                type: integer
              description: "Port numbers that cannot be exposed via Ingress"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singressbackendrestriction

        import future.keywords.in

        # Block targeting of sensitive services
        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          some path in rule.http.paths
          service_name := path.backend.service.name
          pattern := input.parameters.blockedServices[_]
          regex.match(pattern, service_name)
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' targets blocked service '%s'. " +
            "Infrastructure services must not be exposed via tenant Ingress.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name, service_name]
          )
        }

        # Block exposure of sensitive ports
        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          some path in rule.http.paths
          port := path.backend.service.port.number
          blocked_port := input.parameters.blockedPorts[_]
          port == blocked_port
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' exposes blocked port %d. " +
            "Administrative and debug ports must not be exposed via Ingress.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name, port]
          )
        }
```

#### Constraint

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DK8SIngressBackendRestriction
metadata:
  name: ingress-backend-restriction
  labels:
    security.dk8s.io/category: ingress
    security.dk8s.io/severity: high
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["Ingress"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
  parameters:
    blockedServices:
      - "^kubernetes$"
      - "^kube-dns$"
      - "^metrics-server$"
      - "^ingress-nginx-controller$"
      - "^gatekeeper.*"
      - "^istiod$"
      - "^istio-.*"
      - "^prometheus.*"
      - "^grafana.*"
      - "^alertmanager.*"
      - "^etcd.*"
      - "^coredns.*"
    blockedNamespaces:
      - "kube-system"
      - "istio-system"
      - "gatekeeper-system"
      - "monitoring"
      - "cert-manager"
    blockedPorts:
      - 6443   # Kubernetes API server
      - 2379   # etcd client
      - 2380   # etcd peer
      - 10250  # kubelet
      - 10251  # kube-scheduler
      - 10252  # kube-controller-manager
      - 9090   # Prometheus
      - 3000   # Grafana (default)
```

### 2.5 Policy 4: Require TLS on All Ingress

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singresstlsrequired
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressTLSRequired
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singresstlsrequired

        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          not input.review.object.spec.tls
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' does not configure TLS. " +
            "All Ingress resources must use TLS. FedRAMP SC-8 requires encryption in transit.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name]
          )
        }

        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          tls := input.review.object.spec.tls[_]
          not tls.secretName
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' TLS block missing secretName. " +
            "TLS certificate must be explicitly specified.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name]
          )
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DK8SIngressTLSRequired
metadata:
  name: ingress-require-tls
  labels:
    security.dk8s.io/category: ingress
    security.dk8s.io/severity: medium
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["Ingress"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
```

### 2.6 Policy 5: Block Wildcard Hosts

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singressnowildcardhost
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressNoWildcardHost
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singressnowildcardhost

        import future.keywords.in

        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          startswith(rule.host, "*")
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' uses wildcard host '%s'. " +
            "Wildcard hosts risk subdomain takeover. Use explicit hostnames.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name, rule.host]
          )
        }

        violation[{"msg": msg}] {
          input.review.kind.kind == "Ingress"
          some rule in input.review.object.spec.rules
          not rule.host
          msg := sprintf(
            "SECURITY VIOLATION: Ingress '%s/%s' has a rule without a host specified. " +
            "All Ingress rules must specify an explicit hostname.",
            [input.review.object.metadata.namespace, input.review.object.metadata.name]
          )
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DK8SIngressNoWildcardHost
metadata:
  name: ingress-no-wildcard-host
  labels:
    security.dk8s.io/category: ingress
    security.dk8s.io/severity: medium
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["Ingress"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
```

### 2.7 Gatekeeper Deployment Prerequisites

```bash
# Install Gatekeeper (if not already present)
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper/gatekeeper \
  --name-template=gatekeeper \
  --namespace gatekeeper-system \
  --create-namespace \
  --set replicas=3 \
  --set auditInterval=60 \
  --set constraintViolationsLimit=100 \
  --set auditFromCache=true \
  --set emitAdmissionEvents=true \
  --set emitAuditEvents=true

# Deploy policies in order: ConstraintTemplates first, then Constraints
kubectl apply -f constrainttemplates/
sleep 30  # Wait for CRD registration
kubectl apply -f constraints/
```

**Rollout strategy:** Deploy all policies in `dryrun` enforcementAction first. Review audit results for 48 hours. Switch to `deny` only after confirming zero false positives on existing Ingress resources.

---

## 3. Ingress Vulnerability Scanning — CI/CD Pipeline Integration

### 3.1 Scanning Strategy

Three scanning layers, each catching different vulnerability classes:

| Layer | Tool | What It Catches | Stage |
|-------|------|-----------------|-------|
| **Image scanning** | Trivy | Known CVEs in container images (e.g., CVE-2026-24512) | Build |
| **Config scanning** | Trivy + custom Rego | Insecure Ingress/Helm configurations | Build + PR |
| **Admission validation** | OPA/Conftest | Policy violations before deployment | Pre-deploy |

### 3.2 Tool Selection

| Tool | Purpose | License | FedRAMP Compatible |
|------|---------|---------|-------------------|
| **Trivy** | Image + IaC + K8s scanning | Apache 2.0 | ✅ (runs locally) |
| **Conftest** | OPA policy testing for configs | Apache 2.0 | ✅ (runs locally) |
| **kubeaudit** | K8s manifest security audit | MIT | ✅ (runs locally) |
| **Snyk** | Commercial SCA + container scanning | Commercial | ⚠️ Verify data residency for gov |

**Primary recommendation:** Trivy + Conftest (open source, run locally, no external data transmission — critical for FedRAMP and sovereign cloud compliance).

### 3.3 Azure DevOps Pipeline — Ingress Security Scanning

```yaml
# azure-pipelines-ingress-security.yaml
# Integrates into existing OneBranch pipeline as additional stage

trigger:
  branches:
    include:
      - main
      - release/*
  paths:
    include:
      - 'charts/**'
      - 'manifests/**'
      - '**/ingress*.yaml'
      - '**/ingress*.yml'

pr:
  branches:
    include:
      - main
  paths:
    include:
      - 'charts/**'
      - 'manifests/**'

variables:
  TRIVY_VERSION: '0.58.0'
  CONFTEST_VERSION: '0.56.0'
  SEVERITY_GATE: 'CRITICAL,HIGH'

stages:
  - stage: IngressSecurityScan
    displayName: 'Ingress Security Scanning'
    jobs:
      - job: ImageScan
        displayName: 'Scan ingress-nginx Image for CVEs'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: |
              curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v$(TRIVY_VERSION)
            displayName: 'Install Trivy'

          - script: |
              trivy image \
                --severity $(SEVERITY_GATE) \
                --exit-code 1 \
                --ignore-unfixed \
                --format table \
                --output $(Build.ArtifactStagingDirectory)/trivy-image-report.txt \
                registry.k8s.io/ingress-nginx/controller:v1.13.7
            displayName: 'Scan ingress-nginx image'
            continueOnError: false

          - publish: $(Build.ArtifactStagingDirectory)/trivy-image-report.txt
            artifact: trivy-image-report
            condition: always()

      - job: ConfigScan
        displayName: 'Scan Ingress Configurations'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: |
              curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v$(TRIVY_VERSION)
            displayName: 'Install Trivy'

          - script: |
              trivy config \
                --severity $(SEVERITY_GATE) \
                --exit-code 1 \
                --format table \
                --output $(Build.ArtifactStagingDirectory)/trivy-config-report.txt \
                ./charts/ ./manifests/
            displayName: 'Scan Helm charts and manifests'
            continueOnError: false

          - publish: $(Build.ArtifactStagingDirectory)/trivy-config-report.txt
            artifact: trivy-config-report
            condition: always()

      - job: OPAPolicyValidation
        displayName: 'Validate Against OPA Policies'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: |
              wget -q https://github.com/open-policy-agent/conftest/releases/download/v$(CONFTEST_VERSION)/conftest_$(CONFTEST_VERSION)_Linux_x86_64.tar.gz
              tar xzf conftest_$(CONFTEST_VERSION)_Linux_x86_64.tar.gz
              mv conftest /usr/local/bin/
            displayName: 'Install Conftest'

          - script: |
              # Test all Ingress manifests against OPA policies
              find ./charts ./manifests -name '*.yaml' -o -name '*.yml' | \
                xargs -I {} conftest test {} \
                  --policy ./policies/ingress/ \
                  --output table \
                  --fail-on-warn
            displayName: 'Validate Ingress resources against OPA policies'
            continueOnError: false

      - job: HelmTemplateScan
        displayName: 'Scan Rendered Helm Templates'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: |
              # Render Helm templates and scan the output
              helm template ingress-release ./charts/ingress-nginx/ \
                --values ./charts/ingress-nginx/values-production.yaml \
                > $(Build.ArtifactStagingDirectory)/rendered-manifests.yaml

              # Scan rendered manifests with Trivy
              trivy config \
                --severity $(SEVERITY_GATE) \
                --exit-code 1 \
                $(Build.ArtifactStagingDirectory)/rendered-manifests.yaml

              # Validate rendered manifests with Conftest
              conftest test \
                $(Build.ArtifactStagingDirectory)/rendered-manifests.yaml \
                --policy ./policies/ingress/ \
                --fail-on-warn
            displayName: 'Render and scan Helm templates'
```

### 3.4 Conftest Policy for CI/CD — Ingress Path Validation

```rego
# policies/ingress/path_injection.rego
package main

import future.keywords.in

deny[msg] {
  input.kind == "Ingress"
  some rule in input.spec.rules
  some path in rule.http.paths
  dangerous_pattern(path.path)
  msg := sprintf("BLOCKED: Ingress '%s' path '%s' contains dangerous pattern", [input.metadata.name, path.path])
}

dangerous_pattern(path) {
  patterns := [";", "}", "{", "lua_", "proxy_pass", "alias ", "root /", "rewrite", "set $", "access_log", "error_log"]
  pattern := patterns[_]
  contains(lower(path), pattern)
}

deny[msg] {
  input.kind == "Ingress"
  annotations := input.metadata.annotations
  key := object.keys(annotations)[_]
  contains(lower(key), "snippet")
  msg := sprintf("BLOCKED: Ingress '%s' uses snippet annotation '%s' — configuration injection risk", [input.metadata.name, key])
}

warn[msg] {
  input.kind == "Ingress"
  not input.spec.tls
  msg := sprintf("WARNING: Ingress '%s' does not configure TLS", [input.metadata.name])
}
```

### 3.5 Gate Criteria

| Check | Threshold | Action on Failure |
|-------|-----------|-------------------|
| Image CVE (CRITICAL) | 0 allowed | **Block deployment** |
| Image CVE (HIGH) | 0 allowed | **Block deployment** |
| Config scan (CRITICAL) | 0 allowed | **Block deployment** |
| OPA policy violation | 0 allowed | **Block deployment** |
| Config scan (MEDIUM) | ≤ 5 allowed | Warn, require security sign-off |
| Image CVE (MEDIUM) | ≤ 10 allowed | Warn, log to security dashboard |

**Exception process:** Security team can grant time-limited exceptions (max 30 days) with documented risk acceptance and compensating controls. Exceptions tracked in ADO work items tagged `security-exception`.

---

## 4. Emergency Patching Runbook — Sovereign/Gov Clusters

### 4.1 Activation Criteria

This runbook activates when ANY of the following conditions are met:

- [ ] CVE with CVSS ≥ 7.0 affecting ingress-nginx or any ingress controller
- [ ] Active exploitation observed in the wild
- [ ] FedRAMP POA&M item with < 30 day remediation deadline
- [ ] Security team declares P0/P1 incident involving ingress layer

### 4.2 FedRAMP Timeline Requirements

| Severity | Remediation Deadline | Reporting |
|----------|---------------------|-----------|
| Critical (CVSS ≥ 9.0) | 15 calendar days | Immediate notification to AO |
| High (CVSS 7.0-8.9) | 30 calendar days | Include in monthly POA&M |
| Medium (CVSS 4.0-6.9) | 90 calendar days | Include in quarterly POA&M |
| Low (CVSS < 4.0) | 180 calendar days | Include in annual assessment |

**For CVE-2026-24512 (CVSS 8.8):** 30 calendar day deadline. Given active exploitation risk, treat as < 24 hours internal SLA.

### 4.3 Progressive Rollout Procedure

#### Phase 0: Preparation (T+0 to T+2 hours)

```
INCIDENT COMMANDER: On-call security engineer
COMMUNICATION: #dk8s-security-incident (Teams), Page SRE on-call

Step 0.1: Confirm vulnerability
  - Verify CVE details from NVD/MITRE
  - Check if affected version is deployed: 
    kubectl get deployment -n ingress-nginx ingress-nginx-controller \
      -o jsonpath='{.spec.template.spec.containers[0].image}'
  - Document current version in incident ticket

Step 0.2: Prepare patched artifact
  - Identify patched version from upstream release notes
  - Pull image to internal container registry (ACR):
    az acr import --name <acr-name> \
      --source registry.k8s.io/ingress-nginx/controller:v1.13.7 \
      --image ingress-nginx/controller:v1.13.7
  - For sovereign clouds with air-gapped registries:
    - Export image as OCI tarball
    - Transfer via approved secure channel
    - Import to sovereign ACR

Step 0.3: Update Helm values
  - Branch: hotfix/CVE-XXXX-XXXXX
  - Update image tag in values.yaml:
    controller:
      image:
        tag: "v1.13.7"
        digest: "<sha256:verified-digest>"
  - Run CI pipeline to validate (scan stage must pass)

Step 0.4: Prepare rollback plan
  - Document current controller version and config
  - Snapshot current Helm release:
    helm get values ingress-nginx -n ingress-nginx > rollback-values.yaml
    helm get manifest ingress-nginx -n ingress-nginx > rollback-manifest.yaml
```

#### Phase 1: Test Ring (T+2 to T+4 hours)

```
APPROVAL REQUIRED: Security engineer + SRE lead

Step 1.1: Deploy to Test cluster
  - Target: Test ring clusters (non-production)
  - Method: EV2 deployment with single-cluster stamp
    helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      --values values-test.yaml \
      --set controller.image.tag=v1.13.7 \
      --wait --timeout 10m

Step 1.2: Validate deployment
  - Verify new version running:
    kubectl get pods -n ingress-nginx -o wide
    kubectl exec -n ingress-nginx <pod> -- /nginx-ingress-controller --version
  - Run smoke tests:
    - HTTP/HTTPS routing functional
    - TLS termination working
    - Health endpoints responding (/healthz, /readyz)
    - Existing Ingress resources serving traffic
  - Verify CVE mitigated:
    - Attempt path injection payload → must be rejected
    - Confirm admission webhook functional

Step 1.3: Bake time
  - Monitor for 30 minutes minimum
  - Check error rates, latency, 5xx responses
  - Check ingress controller logs for errors:
    kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=500
  - PROCEED only if all metrics nominal
```

#### Phase 2: PPE Ring (T+4 to T+8 hours)

```
APPROVAL REQUIRED: Security engineer + Service owner

Step 2.1: Deploy to PPE clusters
  - Target: Pre-production environment clusters
  - Method: EV2 deployment with progressive stamp rollout
  - Deploy to 1 PPE cluster first, validate, then remaining PPE clusters

Step 2.2: Extended validation
  - All Step 1.2 checks PLUS:
  - Verify tenant workloads functioning
  - Confirm multi-tenant Ingress isolation
  - Run integration test suite
  - Validate monitoring/alerting pipeline intact

Step 2.3: Bake time
  - Minimum 1 hour bake
  - Monitor dashboards for anomalies
  - PROCEED only with explicit SRE sign-off
```

#### Phase 3: Production Ring (T+8 to T+24 hours)

```
APPROVAL REQUIRED: Security engineer + SRE lead + Service owner + Change Advisory Board (CAB)
(For P0: CAB can be retroactive within 24 hours)

Step 3.1: Canary deployment
  - Deploy to 1 production cluster (lowest-traffic region)
  - Monitor for 2 hours minimum

Step 3.2: Progressive rollout
  - Deploy to remaining production clusters in waves:
    Wave 1: 25% of clusters (2-3 clusters)
    Wave 2: 50% of clusters (after 1 hour bake)
    Wave 3: 100% of clusters (after 1 hour bake)
  - Each wave requires SRE verification before proceeding

Step 3.3: Production validation
  - All Step 2.2 checks PLUS:
  - Verify all 19 tenant workloads functional
  - Confirm Traffic Manager health checks passing
  - Validate FedRAMP audit logging intact
  - Check certificate validity and TLS negotiation
```

#### Phase 4: Sovereign/Gov Clusters (T+24 to T+72 hours)

```
APPROVAL REQUIRED: Security engineer + Gov cloud lead + Compliance officer

⚠️ SPECIAL CONSIDERATIONS FOR SOVEREIGN CLOUDS:
- Fairfax (US Gov): Requires IL5 compliance verification
- Mooncake (China): Requires MLPS 2.0 compliance verification  
- Air-gapped clusters: Manual image transfer required

Step 4.1: Image transfer (air-gapped environments)
  - Export from commercial ACR:
    az acr export --name <commercial-acr> \
      --image ingress-nginx/controller:v1.13.7 \
      --output controller-v1.13.7.tar
  - Verify image integrity:
    sha256sum controller-v1.13.7.tar
    cosign verify --key <signing-key> <image-ref>
  - Transfer via approved secure channel (SFTP/physical media per SOPs)
  - Import to sovereign ACR:
    az acr import --name <sovereign-acr> \
      --source controller-v1.13.7.tar

Step 4.2: Deploy to sovereign Test/PPE
  - Follow Phase 1-2 procedures adapted for sovereign environment
  - Additional checks:
    - dSTS authentication functional (not Entra ID)
    - dSMS secret access functional (not KeyVault)
    - Sovereign-specific network policies intact

Step 4.3: Deploy to sovereign Production
  - Follow Phase 3 procedures
  - Extended bake time: 4 hours minimum (reduced change windows in gov clouds)
  - Compliance officer must verify FedRAMP continuous monitoring data flowing

Step 4.4: Post-deployment compliance
  - Update FedRAMP SSP (System Security Plan) if configuration changed
  - Update POA&M with remediation evidence
  - Submit artifact to AO if P0/P1:
    - CVE details
    - Patch deployment evidence (timestamps, clusters)
    - Validation test results
    - Updated vulnerability scan showing remediation
```

### 4.4 Rollback Procedure

```
⚠️ ROLLBACK TRIGGERS:
- 5xx error rate > 1% increase from baseline
- Pod crash loop (>3 restarts in 5 minutes)
- TLS termination failures
- Health check failures on >10% of endpoints
- Any tenant reports service disruption

ROLLBACK STEPS:
1. Announce rollback in #dk8s-security-incident
2. Execute Helm rollback:
   helm rollback ingress-nginx <previous-revision> -n ingress-nginx --wait
3. Verify previous version restored:
   kubectl get pods -n ingress-nginx -o jsonpath='{.items[*].spec.containers[0].image}'
4. Re-enable compensating controls (if they were modified):
   - Verify OPA policies active
   - Verify WAF rules active
   - Verify Network Policies applied
5. Validate service restoration:
   - Run smoke tests
   - Check error rates returning to baseline
   - Verify all tenant workloads functional
6. Document rollback in incident ticket
7. Schedule root cause analysis within 24 hours

POST-ROLLBACK:
- If rollback due to patch issue: Engage upstream maintainers
- If rollback due to DK8S-specific issue: Deploy compensating controls immediately:
  * OPA policies (Section 2) — blocks exploitation at admission
  * WAF rules (Section 1) — blocks exploitation at network edge
  * Network Policies (B'Elanna's scope) — blocks lateral movement
- Update FedRAMP POA&M with compensating controls documentation
```

### 4.5 Communication Template

```
Subject: [DK8S SECURITY] Emergency Ingress Patch — CVE-XXXX-XXXXX

Severity: P0/P1
Status: [IN PROGRESS | DEPLOYED TO TEST | DEPLOYED TO PPE | DEPLOYED TO PROD | COMPLETE]

CVE: CVE-XXXX-XXXXX (CVSS X.X)
Impact: [Brief description]
Affected: ingress-nginx < vX.X.X
Patched: ingress-nginx vX.X.X

Timeline:
- T+0: Vulnerability confirmed
- T+Xh: Test ring deployed ✅/❌
- T+Xh: PPE ring deployed ✅/❌
- T+Xh: Prod ring deployed ✅/❌
- T+Xh: Sovereign deployed ✅/❌

Compensating Controls Active: WAF ✅/❌ | OPA ✅/❌ | NetPol ✅/❌

Next Steps: [...]
Incident Commander: [Name]
```

---

## Appendix A: Control Mapping to FedRAMP

| Control | FedRAMP ID | Implementation |
|---------|-----------|----------------|
| WAF rules | SC-7, SC-7(8) | Azure Front Door / App Gateway WAF in Prevention mode |
| OPA admission policies | CM-7(5), SI-3 | Gatekeeper constraints blocking dangerous Ingress patterns |
| CI/CD scanning | RA-5, SI-2 | Trivy + Conftest in build pipeline |
| Emergency patching | IR-4, SI-2 | Progressive rollout runbook with sovereign cloud procedures |
| TLS enforcement | SC-8, SC-8(1) | OPA policy requiring TLS on all Ingress resources |
| Audit logging | AU-2, AU-3 | WAF logs + Gatekeeper audit events + pipeline artifacts |

## Appendix B: Implementation Priority

| Priority | Control | Timeline | Owner |
|----------|---------|----------|-------|
| P0 | OPA path injection policy (Policy 1) | Week 1 — deploy in dryrun, Week 2 — enforce | Worf |
| P0 | OPA annotation allowlist (Policy 2) | Week 1 — deploy in dryrun, Week 2 — enforce | Worf |
| P1 | WAF custom rules for nginx patterns | Week 1-2 | Worf + B'Elanna |
| P1 | CI/CD Trivy + Conftest integration | Week 2-3 | Worf + Pipeline team |
| P2 | OPA backend restriction (Policy 3) | Week 3-4 | Worf |
| P2 | OPA TLS + wildcard policies (4, 5) | Week 3-4 | Worf |
| P2 | Emergency patching runbook drill | Week 4 | Worf + SRE |

---

*Document authored by Worf (Security & Cloud). Reviewed against FedRAMP HIGH baseline controls and DK8S platform architecture. All policies tested against CVE-2026-24512 attack vectors.*
