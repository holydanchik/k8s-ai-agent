# k8s-ai-agent (PoC)
AI-driven incident response automation for microservices — AI agent + n8n + Kubernetes (PoC).

## Overview
PoC shows workflow:
`Falco -> webhook -> n8n -> AI Agent (OpenAI) -> decision -> n8n -> Kubernetes API (action) + SIEM/log`.

Intended audience: students, SOC engineers, SMBs wanting low-cost SOAR capabilities.

## Features
- Event ingestion (Falco / kube-audit / Prometheus)  
- AI-based decision making (OpenAI API)  
- Orchestration via n8n (playbooks)  
- Actions: annotate/quarantine/delete pod, alert to SIEM, escalate to human  
- Metrics: MTTA, MTTR, False Positive Rate (FPR)

---

## Quickstart (Kind / local PoC)

### Prerequisites
- Docker (>=20) and `kubectl`
- `kind` or `minikube` (recommended kind)
- `helm`
- Git
- `OPENAI_API_KEY` (set as env var; **do not commit to repo**)

### 1) Create kind cluster
```bash
kind create cluster --name ai-agent-poc
kubectl cluster-info --context kind-ai-agent-poc
```

### 2) Install Prometheus/Grafana & Loki (optional)

Use helm charts or minimal manifests — optional for PoC.

### 3) Install Falco (example via helm)
```bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

### 4) Deploy n8n
```bash
kubectl create ns automation
helm repo add n8n https://n8n-io.github.io/n8n-helm/
helm install n8n n8n/n8n --namespace automation
# alternatively run n8n locally with Docker-compose for development
```

### 5) Build & push AI-Agent image (locally)
```bash
# from repo root
docker build -t k8s-ai-agent:latest ./agent
# for GHCR push or local use: docker tag/push as needed
```

### 6) Deploy AI-Agent (example deployment)

kubectl apply -f deployment/agent-deployment.yaml

Agent expects OPENAI_API_KEY in k8s secret or env (see SECURITY note).

### 7) Configure Falco -> n8n webhook

In n8n create a webhook node to accept Falco events.

Falco: set output to HTTP (webhook) to send events to n8n endpoint.

### 8) Create n8n workflow

Workflow outline:

Webhook trigger (Falco event)

Enrich (fetch pod metadata, Prometheus metrics)

HTTP Request to AI-Agent (send structured event)

Switch on AI-Agent decision:

If action == quarantine => patch NetworkPolicy via Kubernetes node

If action == delete => call Kubernetes API (delete pod)

Always send alert to SIEM/logstore

If escalate => create high-priority ticket / notify human

Log action + store audit record

### 9) Simulate safe attacks

Use included examples/ YAMLs (cpu-hog, exfil-sim, nmap scan) — safe patterns only.

### 10) Metrics and evaluation

Collect MTTA/MTTR/FPR by running multiple test runs and comparing detected events vs expected.

## Security / Secrets

Never commit OPENAI_API_KEY or kubeconfigs.

Use Kubernetes Secrets or CI secrets to store keys.

Use SECURITY.md to explain reporting process.