#!/bin/bash
set -e

echo "[1/6] Creating kind cluster..."
kind create cluster --name ai-sec --config cluster/kind-config.yaml

echo "[2/6] Installing Falco..."
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
kubectl create ns security || true
helm install falco falcosecurity/falco -n security

echo "[3/6] Installing Sidekick..."
helm install sidekick falcosecurity/falcosidekick -n security \
  --values manifests/sidekick/values.yaml

echo "[4/6] Installing n8n..."
kubectl create ns automation || true
kubectl apply -f manifests/n8n/

echo "[5/6] Installing test workloads..."
kubectl create ns tests || true
kubectl apply -f manifests/tests/

echo ">>> Deployment complete!"
echo ">>> n8n accessible at -> http://localhost:30001"
