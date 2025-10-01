# k8s-ai-agent (PoC)
AI-driven incident response automation for microservices — AI agent + n8n + Kubernetes (PoC).

## Overview
Workflow:  
`Falco -> webhook -> n8n -> AI Agent (OpenAI) -> decision -> n8n -> Kubernetes API (action) + SIEM/log`

Audience: students, SOC engineers, SMBs wanting low-cost SOAR capabilities.

## Features
- Event ingestion (Falco / kube-audit / Prometheus)  
- AI-based decision making (OpenAI API)  
- Orchestration via n8n (playbooks)  
- Actions: annotate / quarantine / delete pod, alert to SIEM, escalate to human  
- Metrics: MTTA, MTTR, False Positive Rate (FPR)

---

## Quickstart (Kind / local PoC)

### Prerequisites
- Docker (>= 20) and `kubectl`
- `kind` or `minikube` (recommended: `kind`)
- `helm`
- Git
- `OPENAI_API_KEY` (set as env var; **do not commit to repo**)

---

### 1) Create kind cluster
```bash
kind create cluster --name ai-agent-poc
kubectl cluster-info --context kind-ai-agent-poc
```

### 2) Install Prometheus/Grafana & Loki (optional)
Use official Helm charts for Prometheus / Grafana / Loki if you want metrics/logs and dashboards.
This step is optional for the minimal PoC.

### 3) Install Falco (via Helm)
``` bash
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace
```

### 4) Deploy n8n
Option A — Helm in cluster:
```bash
kubectl create ns automation
helm repo add n8n https://n8n-io.github.io/n8n-helm/
helm repo update
helm install n8n n8n/n8n --namespace automation
```
Option B — run n8n locally (docker-compose):
Recommended for faster development. Then use local webhook instead of cluster ingress.

### 5) Build AI-Agent image (locally)
```bash
# from repo root
docker build -t k8s-ai-agent:latest ./agent

# for kind
kind load docker-image k8s-ai-agent:latest --name ai-agent-poc
```

### 6) Deploy AI-Agent
Create namespace:
```bash
kubectl create ns automation
```
Create secret with your OpenAI key:
```bash
kubectl create secret generic openai-secret \
  --from-literal=api-key="$OPENAI_API_KEY" \
  -n automation
```
Apply deployment manifest:
```bash
kubectl apply -f deployment/agent-deployment.yaml
kubectl -n automation get pods
```
Ensure agent-deployment.yaml references the correct image (local or GHCR).

### 7) Configure Falco → n8n webhook
- In n8n create a Webhook node and copy endpoint.
- Configure Falco to send output to this webhook.
- For local dev:
```bash
kubectl -n automation port-forward svc/n8n 5678:5678
```
Then set Falco webhook → http://localhost:5678/webhook/...

### 8) Create n8n workflow
1. Webhook trigger (Falco event)
2. Enrich: fetch pod metadata / Prometheus metrics
3. HTTP → AI-Agent (/analyze)
4. Switch on decision:
    - quarantine → patch NetworkPolicy / annotate pod
    - delete → kubectl delete pod
    - alert → forward to SIEM/logstore
    - escalate → Slack/email → human
5. Log action + store audit record

### 9) Simulate safe attacks
Use manifests from examples/:
```bash
kubectl apply -f examples/cpu-hog.yaml
kubectl apply -f examples/exfil-sim.yaml
kubectl apply -f examples/portscan-job.yaml
```
These are safe — only simulate resource hog / scan patterns.

### 10) Metrics and evaluation
- Measure MTTA, MTTR, FPR by comparing detected vs expected.
- Store logs/CSV for evaluation.

## Security
- Never commit secrets (OPENAI_API_KEY, kubeconfigs).
- Use Kubernetes Secrets / CI secrets.
- Consider Vault / sealed-secrets.
- Add SECURITY.md with disclosure process.

## Repo structure
k8s-ai-agent/
├─ .github/
│  └─ workflows/ci.yml
├─ agent/
│  ├─ Dockerfile
│  ├─ app.py
│  ├─ requirements.txt
│  └─ deployment.yaml
├─ n8n/
│  └─ workflows.json
├─ deployment/
│  ├─ agent-deployment.yaml
│  ├─ n8n-deployment.yaml
│  └─ falco-values.yaml
├─ examples/
│  ├─ cpu-hog.yaml
│  ├─ exfil-sim.yaml
│  └─ portscan-job.yaml
├─ docs/
│  ├─ architecture.png
│  └─ playbooks.md
├─ README.md
├─ LICENSE
├─ SECURITY.md
└─ .gitignore

## Troubleshooting
Check pods:
```bash
kubectl top pods
kubectl describe pod <name>
```
If Falco webhook fails → forward n8n:
```bash
Copy code
kubectl -n automation port-forward svc/n8n 5678:5678
```