#!/bin/bash
set -e

echo "======================================"
echo "🔥 STEP 1: Creating KIND Cluster"
echo "======================================"

kind create cluster --name k8s-ai-agent --config cluster/kind-config.yaml

echo "Cluster created successfully!"
echo ""


echo "======================================"
echo "🔥 STEP 2: Installing Falco"
echo "======================================"

helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  -n falco --create-namespace \
  -f manifests/falco/falco-values.yaml

echo "⏳ Waiting for Falco pods..."
kubectl wait --for=condition=Ready pods -l app=falco -n falco --timeout=300s || true

echo "Patching FalcoSidekick UI to NodePort..."
kubectl patch svc falco-falcosidekick-ui -n falco -p '{
  "spec": {
      "type": "NodePort",
      "ports": [
          {
            "port": 2802,
            "targetPort": 2802,
            "nodePort": 32040
          }
      ]
  }
}'

echo "Falco installed and patched!"
echo ""


echo "======================================"
echo "🔥 STEP 3: Installing N8N"
echo "======================================"

# This will ALWAYS fail — so we silence the error
echo "Adding n8n OCI registry (this will show error but is safe)..."
helm repo add n8n oci://8gears.container-registry.com/library/ || true

helm repo update

echo "Installing n8n chart from OCI..."
helm install n8n oci://8gears.container-registry.com/library/n8n \
  --namespace automation --create-namespace \
  -f manifests/n8n/n8n-values.yaml

echo "⏳ Waiting for N8N pod..."
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=n8n -n automation --timeout=180s || true

echo "Patching N8N to NodePort..."
kubectl patch svc n8n -n automation --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/type",
    "value": "NodePort"
  },
  {
    "op": "replace",
    "path": "/spec/ports",
    "value": [
      {
        "name": "http",
        "port": 5678,
        "targetPort": 5678,
        "nodePort": 30008,
        "protocol": "TCP"
      }
    ]
  }
]'

echo "N8N installed and patched!"
echo ""


echo "======================================"
echo "🔥 STEP 4: ServiceAccount + RBAC + TOKEN"
echo "======================================"

kubectl apply -f manifests/n8n/token/n8n-sa.yaml
kubectl apply -f manifests/n8n/token/n8n-role.yaml
kubectl apply -f manifests/n8n/token/n8n-rolebinding.yaml

echo "Generating TOKEN for N8N Service Account..."
TOKEN=$(kubectl -n automation create token n8n-sa)

echo ""
echo "======================================"
echo "N8N KUBERNETES TOKEN:"
echo "$TOKEN"
echo "======================================"
echo ""


echo "======================================"
echo "🔥 STEP 5: Apply Quarantine NetworkPolicy"
echo "======================================"

kubectl apply -f manifests/playground/playground-ns.yaml
kubectl apply -n playground -f manifests/policy/quarantine-networkpolicy.yaml

echo "NetworkPolicy applied!"
echo ""


echo "======================================"
echo "🔥 STEP 6: Creating Playground Namespace and Test Pods"
echo "======================================"

kubectl apply -f manifests/playground/escalate-test.yaml
kubectl apply -f manifests/playground/pod-delete.yaml
kubectl apply -f manifests/playground/pod-quarantine.yaml
kubectl apply -f manifests/playground/test-busybox.yaml
kubectl apply -f manifests/playground/test-nginx.yaml
kubectl apply -f manifests/playground/test-shell.yaml

echo "Playground test environment created!"
echo ""


echo "======================================"
echo "🎉 INSTALLATION COMPLETE"
echo "======================================"

echo ""
echo "Falco UI: http://localhost:32040"
echo "N8N UI:   http://localhost:30008"
echo ""
echo "Use token below for N8N HTTP Requests:"
echo "$TOKEN"
echo ""
echo "Kubernetes API:"
kubectl config view --minify | grep server
echo ""
echo "======================================"
echo "System Ready."
echo "======================================"
