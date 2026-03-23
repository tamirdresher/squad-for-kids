# Gateway API Migration — Manifests

This directory contains Kubernetes manifests for the **ingress-nginx → Gateway API migration** (Issue #644).

## Structure

```
gateway-api/
├── README.md                              # This file
├── squad-nginx-ingress-controller.yaml   # PHASE 1: App Routing Add-on CR (deploy NOW)
├── gatewayclass.yaml                     # PHASE 2: Gateway API GatewayClass (Q3 2026)
├── gateway.yaml                          # PHASE 2: Gateway instance (Q3 2026)
└── httproute-squad.yaml                  # PHASE 2: HTTPRoute equivalents + migration guide (Q3 2026)
```

## Phase 1: Deploy Now (AKS Application Routing Add-on)

```bash
# 1. Enable add-on on cluster
az aks approuting enable --resource-group <rg> --name <cluster>

# 2. Apply NginxIngressController CR
kubectl apply -f squad-nginx-ingress-controller.yaml

# 3. Update Ingress resources to use new IngressClass
#    Change: kubernetes.io/ingress.class: nginx
#    To:     ingressClassName: squad-nginx (or webapprouting.kubernetes.azure.com)
```

## Phase 2: Gateway API (Q3 2026)

Apply in order:
```bash
# Install Gateway API CRDs first
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Then apply squad Gateway API resources
kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute-squad.yaml
```

## Migration Guide

See [`httproute-squad.yaml`](httproute-squad.yaml) for a comprehensive Ingress annotation → HTTPRoute
filter mapping table at the bottom of the file.

Full plan: [`../644-ingress-nginx-migration-plan.md`](../644-ingress-nginx-migration-plan.md)
