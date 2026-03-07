#!/bin/bash
# WAF/OPA False Positive Measurement - OPA Policy Deployment
# Owner: Worf (Security & Cloud)
# Purpose: Deploy OPA/Gatekeeper policies in dryrun mode with telemetry

set -euo pipefail

# Load configuration
if [ ! -f measurement-config.env ]; then
  echo "❌ Error: measurement-config.env not found. Run 01-setup-telemetry.sh first."
  exit 1
fi
source measurement-config.env

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-dk8s-dev-eus2}"
NAMESPACE="gatekeeper-system"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deploying OPA policies to cluster: $CLUSTER_NAME"

# 1. Get AKS credentials
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Getting AKS credentials"
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CLUSTER_NAME" \
  --overwrite-existing

# 2. Ensure Gatekeeper is installed
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Installing Gatekeeper"
  kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.14.0/deploy/gatekeeper.yaml
  kubectl wait --for=condition=Ready pod -l control-plane=controller-manager -n "$NAMESPACE" --timeout=300s
else
  echo "✅ Gatekeeper already installed"
fi

# 3. Configure Gatekeeper for measurement mode
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Configuring Gatekeeper for dryrun mode"
kubectl apply -f - <<EOF
apiVersion: config.gatekeeper.sh/v1alpha1
kind: Config
metadata:
  name: config
  namespace: gatekeeper-system
spec:
  enforcementAction: dryrun
  validationLogLevel: detailed
  auditInterval: 60
  constraintViolationsLimit: 20
  auditFromCache: Automatic
EOF

# 4. Deploy Fluent Bit for OPA log collection
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deploying Fluent Bit for log collection"
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: gatekeeper-system
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush        5
        Log_Level    info
        Daemon       off
    
    [INPUT]
        Name              tail
        Path              /var/log/containers/gatekeeper-*_gatekeeper-system_*.log
        Parser            docker
        Tag               gatekeeper.*
        Refresh_Interval  5
    
    [FILTER]
        Name   grep
        Match  gatekeeper.*
        Regex  log (violation|denied|dryrun)
    
    [OUTPUT]
        Name            azure
        Match           gatekeeper.*
        Customer_ID     ${WORKSPACE_ID}
        Shared_Key      ${WORKSPACE_KEY}
        Log_Type        GatekeeperViolations
        Time_Key        timestamp
        Time_Generated  true
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: gatekeeper-system
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
      - name: fluent-bit
        image: fluent/fluent-bit:2.2
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: config
          mountPath: /fluent-bit/etc/
        env:
        - name: WORKSPACE_ID
          value: "${WORKSPACE_ID}"
        - name: WORKSPACE_KEY
          valueFrom:
            secretKeyRef:
              name: fluent-bit-secret
              key: workspace-key
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: config
        configMap:
          name: fluent-bit-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: gatekeeper-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit
rules:
- apiGroups: [""]
  resources: ["pods", "namespaces"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluent-bit
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluent-bit
subjects:
- kind: ServiceAccount
  name: fluent-bit
  namespace: gatekeeper-system
EOF

# Create secret for workspace key
kubectl create secret generic fluent-bit-secret \
  --from-literal=workspace-key="$WORKSPACE_KEY" \
  --namespace "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Deploy constraint templates
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deploying constraint templates"

# Template 1: DK8SIngressSafePath
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singresssafepath
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressSafePath
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singresssafepath
        
        violation[{"msg": msg}] {
          input.review.object.kind == "Ingress"
          namespace := input.review.object.metadata.namespace
          not exempt_namespace(namespace)
          path := input.review.object.spec.rules[_].http.paths[_].path
          forbidden_chars := [";", "`", "$", "{", "}"]
          char := forbidden_chars[_]
          contains(path, char)
          msg := sprintf("Ingress path contains forbidden character: %v", [char])
        }
        
        exempt_namespace(ns) {
          ns == "dev-sandbox"
        }
        
        exempt_namespace(ns) {
          ns == "test-playground"
        }
EOF

# Template 2: DK8SIngressAnnotationAllowlist
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singressannotationallowlist
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressAnnotationAllowlist
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singressannotationallowlist
        
        allowed_annotations := {
          "kubernetes.io/ingress.class",
          "nginx.ingress.kubernetes.io/ssl-redirect",
          "nginx.ingress.kubernetes.io/auth-url",
          "nginx.ingress.kubernetes.io/auth-signin",
          "nginx.ingress.kubernetes.io/limit-rps",
          "nginx.ingress.kubernetes.io/limit-connections",
          "cert-manager.io/cluster-issuer",
          "prometheus.io/scrape",
          "prometheus.io/port"
        }
        
        violation[{"msg": msg}] {
          input.review.object.kind == "Ingress"
          annotations := input.review.object.metadata.annotations
          annotation := annotations[key]
          not allowed_annotations[key]
          not startswith(key, "field.cattle.io")
          msg := sprintf("Annotation not allowed: %v", [key])
        }
EOF

# Template 3: DK8SIngressBackendRestriction
kubectl apply -f - <<'EOF'
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: dk8singressbackendrestriction
spec:
  crd:
    spec:
      names:
        kind: DK8SIngressBackendRestriction
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package dk8singressbackendrestriction
        
        forbidden_services := {
          "kubernetes",
          "kube-dns",
          "etcd",
          "ingress-nginx-controller"
        }
        
        violation[{"msg": msg}] {
          input.review.object.kind == "Ingress"
          service := input.review.object.spec.rules[_].http.paths[_].backend.service.name
          forbidden_services[service]
          msg := sprintf("Ingress backend to infrastructure service not allowed: %v", [service])
        }
EOF

# Template 4: DK8SIngressTLSRequired
kubectl apply -f - <<'EOF'
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
          input.review.object.kind == "Ingress"
          namespace := input.review.object.metadata.namespace
          not exempt_namespace(namespace)
          not input.review.object.spec.tls
          msg := "Ingress must have TLS configuration (FedRAMP SC-8)"
        }
        
        exempt_namespace(ns) {
          ns == "dev-sandbox"
        }
EOF

# Template 5: DK8SIngressNoWildcardHost
kubectl apply -f - <<'EOF'
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
        
        violation[{"msg": msg}] {
          input.review.object.kind == "Ingress"
          host := input.review.object.spec.rules[_].host
          startswith(host, "*.")
          msg := sprintf("Wildcard host not allowed: %v", [host])
        }
EOF

# 6. Deploy constraints in dryrun mode
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Deploying constraints in dryrun mode"

for constraint in dk8singresssafepath dk8singressannotationallowlist dk8singressbackendrestriction dk8singresstlsrequired dk8singressnowildcardhost; do
  constraint_kind=$(echo "$constraint" | sed 's/dk8s/DK8S/; s/ingress/Ingress/; s/safe/Safe/; s/path/Path/; s/annotation/Annotation/; s/allowlist/Allowlist/; s/backend/Backend/; s/restriction/Restriction/; s/tls/TLS/; s/required/Required/; s/no/No/; s/wildcard/Wildcard/; s/host/Host/')
  kubectl apply -f - <<EOF
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: ${constraint_kind}
metadata:
  name: ${constraint}
spec:
  enforcementAction: dryrun
  match:
    kinds:
      - apiGroups: ["networking.k8s.io"]
        kinds: ["Ingress"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
EOF
done

# 7. Verify deployment
echo ""
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Verifying OPA policy deployment"
kubectl get constrainttemplates
echo ""
kubectl get constraints --all-namespaces

echo ""
echo "✅ OPA policy deployment complete!"
echo ""
echo "Deployed Policies:"
echo "  1. DK8SIngressSafePath - Path injection prevention"
echo "  2. DK8SIngressAnnotationAllowlist - Annotation safety"
echo "  3. DK8SIngressBackendRestriction - Infrastructure protection"
echo "  4. DK8SIngressTLSRequired - TLS enforcement"
echo "  5. DK8SIngressNoWildcardHost - Wildcard prevention"
echo ""
echo "All policies in DRYRUN mode (warn, don't block)"
echo "Logs streaming to Log Analytics workspace: $WORKSPACE_NAME"
echo ""
echo "Next steps:"
echo "  1. Start measurement: ./04-start-measurement.sh"
echo "  2. Daily classification: ./05-classify-requests.sh"
echo ""
