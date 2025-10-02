import os, time, json
from fastapi import FastAPI, Request
from pydantic import BaseModel
import requests
from prometheus_client import Counter, Histogram, start_http_server
from kubernetes import client, config

# Prometheus metrics (экспонируются на :8001)
decisions_total = Counter('ai_agent_decisions_total', 'Decisions count', ['action'])
response_latency = Histogram('ai_agent_response_latency_seconds', 'Response latency seconds')

start_http_server(8001)  # metrics on port 8001

# Try in-cluster config, fallback to kubeconfig
try:
    config.load_incluster_config()
except Exception:
    try:
        config.load_kube_config()
    except Exception:
        pass

k8s_api = client.CoreV1Api()
net_api = client.NetworkingV1Api()

app = FastAPI()

class EnrichedEvent(BaseModel):
    event: dict
    enrichment: dict = {}

def call_openai(prompt: str):
    key = os.getenv("OPENAI_API_KEY")
    if not key:
        return None
    import openai
    openai.api_key = key
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4o-mini",
            messages=[{"role":"system","content":"You are a security analyst."},
                      {"role":"user","content":prompt}],
            temperature=0.0
        )
        return resp.choices[0].message.content
    except Exception as e:
        print("openai error", e)
        return None

def heuristic_decision(payload):
    # simple rule-based heuristics
    r = payload.get("event", {}).get("rule","").lower()
    enrichment = payload.get("enrichment", {})
    cpu = enrichment.get("cpu_1m", 0)
    if "unexpected_network_connection" in r or "curl" in str(payload.get("event",{})):
        return {"action":"quarantine","confidence":0.92,"explanation":"unusual outbound connection or curl detected"}
    if cpu and cpu > 0.8:
        return {"action":"quarantine","confidence":0.9,"explanation":"sustained high CPU"}
    return None

def execute_quarantine(pod, ns):
    # add label quarantined: "true" and create deny-egress NetworkPolicy (minimal)
    body = {"metadata":{"labels":{"quarantined":"true"}}}
    try:
        k8s_api.patch_namespaced_pod(pod, ns, body)
    except Exception as e:
        print("patch pod failed", e)
    np = client.V1NetworkPolicy(
        metadata=client.V1ObjectMeta(name=f"quarantine-{pod}", namespace=ns),
        spec=client.V1NetworkPolicySpec(
            pod_selector=client.V1LabelSelector(match_labels={"quarantined":"true"}),
            policy_types=["Egress"],
            egress=[]
        )
    )
    try:
        net_api.create_namespaced_network_policy(ns, np)
    except Exception as e:
        print("create np failed", e)

@app.post("/analyze")
@response_latency.time()
async def analyze(payload: EnrichedEvent):
    start = time.time()
    p = payload.dict()
    # 1) heuristics
    decision = heuristic_decision(p)
    # 2) if heuristics inconclusive, call OpenAI
    if not decision:
        prompt = f"Event: {json.dumps(p)}\nReturn JSON: {{action, confidence, explanation, details}}"
        ai_text = call_openai(prompt)
        if ai_text:
            try:
                decision = json.loads(ai_text)
            except Exception:
                # best-effort: try to extract JSON
                import re
                m = re.search(r"\{.*\}", ai_text, re.S)
                if m:
                    decision = json.loads(m.group(0))
    # 3) fallback
    if not decision:
        decision = {"action":"alert","confidence":0.4,"explanation":"no strong signals"}
    # instrument metrics
    decisions_total.labels(action=decision.get("action","none")).inc()
    # log structured
    log = {"ts": time.time(), "event": p.get("event",{}), "decision": decision}
    print(json.dumps(log))
    # append to CSV for offline metrics
    try:
        with open("/tmp/decisions.csv","a") as f:
            ev_time = p.get("event",{}).get("time","")
            f.write(f'{ev_time},{time.time()},{decision.get("action")},{decision.get("confidence")}\n')
    except Exception:
        pass
    return decision

@app.post("/execute")
async def execute(body: dict):
    # body must contain action, pod, namespace
    action = body.get("action")
    pod = body.get("pod")
    ns = body.get("namespace","default")
    if action == "quarantine":
        execute_quarantine(pod, ns)
        return {"status":"ok","executed":"quarantine"}
    if action == "delete":
        try:
            k8s_api.delete_namespaced_pod(pod, ns)
            return {"status":"ok","executed":"delete"}
        except Exception as e:
            return {"status":"error", "error": str(e)}
    return {"status":"ok","executed":"none"}
