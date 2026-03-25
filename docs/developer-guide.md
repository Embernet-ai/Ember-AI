# Ember AI — Developer Guide

## What is Ember AI?

Ember AI is Fireball Industries' secure, internal-only AI platform. It provides a unified API for LLM inference, RAG (Retrieval-Augmented Generation), and agentic workflows — all running on K3s behind a zero-trust OpenZiti overlay network.

## Architecture at a Glance

```
Client → OpenZiti Tunnel → K3s Cluster
                              ├── LiteLLM (API Gateway)
                              │     ├── Nemotron 120B @ DeepInfra (main engine)
                              │     ├── NemoClaw @ NVIDIA NIM (agent model)
                              │     ├── GPT-4o / GPT-4o-mini (OpenAI)
                              │     ├── Claude 3.5 Sonnet / Haiku (Anthropic)
                              │     └── Gemini 2.0 Flash (Google)
                              ├── n8n (Workflow Orchestrator)
                              ├── pgvector (RAG Vector DB + n8n backend)
                              ├── Valkey (Cache / Queue)
                              └── External Secrets Operator → Bitwarden SM
```

## Components

### LiteLLM — API Gateway & Model Router
- **Endpoint**: `http://litellm-svc:4000` (cluster-internal)
- **Primary model**: `nemotron-120b` — NVIDIA Nemotron 3 Super 120B (A12B MoE), hosted on DeepInfra. High-accuracy reasoning for general tasks.
- **Agent model**: `nemoclaw` — NVIDIA NemoClaw via NIM. Optimized for tool-calling, multi-step planning, and autonomous agent workflows.
- **Fallback models**: GPT-4o, Claude 3.5 Sonnet, Gemini 2.0 Flash.
- **Caching**: Semantic response caching via Valkey to reduce latency and API spend.
- **Auth**: Keycloak OIDC for UI access; `LITELLM_MASTER_KEY` for programmatic access.
- **Config**: `k8s/08-litellm-config.yaml` (ConfigMap mounted at `/app/config.yaml`).

### n8n — Workflow Orchestrator
- **Endpoint**: `http://n8n-svc:5678` (cluster-internal)
- **RAG Pipelines**: Pre-built workflows in `workflows/`:
  - `rag-ingestion.json` — Webhook → chunk text → embed via LiteLLM → store in pgvector.
  - `rag-retrieval.json` — Webhook → embed query → vector search → LLM completion with context.
- **MCP Routing**: n8n acts as the MCP host, translating tool calls from LLMs to external services.
- **Auth**: Keycloak OIDC SSO.

### pgvector — Vector Database
- PostgreSQL + pgvector extension.
- Serves dual purpose: RAG embedding storage **and** n8n's backend database.
- **50 Gi** persistent volume.

### Valkey — Cache & Queue
- Redis-compatible in-memory store.
- LiteLLM semantic cache + n8n Bull queue backend.
- AOF persistence enabled.

### OpenZiti (EmberNet Flux) — Zero-Trust Networking
- Replaces VPNs. No services exposed to the public internet.
- `ziti-edge-tunnel` runs in the cluster with `NET_ADMIN` privileges.
- Identity JSON sourced from `embernet` org → `emberflux` GitHub Secrets.

### External Secrets Operator + Bitwarden
- ESO installed via K3s HelmChart CRD (`06-external-secrets-operator.yaml`).
- `ClusterSecretStore` connects to Bitwarden Secrets Manager.
- `ExternalSecret` maps Bitwarden UUIDs → `ember-ai-env-secrets` K8s Secret.

### Keycloak (External) — SSO
- OIDC clients for LiteLLM and n8n.
- Centralized identity management; no local user accounts.

## Deployment

```powershell
# Deploy everything to K3s (WSL Ubuntu)
.\deploy.ps1
```

The script applies manifests in dependency order via `wsl -d Ubuntu k3s kubectl apply`.

### Manifest Order
| # | File | What it deploys |
|---|---|---|
| 00 | `00-namespace-and-secrets.yaml` | Namespace + bootstrap secrets |
| 01 | `01-pgvector.yaml` | PostgreSQL + pgvector StatefulSet |
| 02 | `02-valkey.yaml` | Valkey Deployment |
| 06 | `06-external-secrets-operator.yaml` | ESO via HelmChart CRD |
| 07 | `07-bitwarden-eso-clusterstore.yaml` | Bitwarden ClusterSecretStore |
| 08 | `08-litellm-config.yaml` | LiteLLM ConfigMap |
| 03 | `03-litellm.yaml` | LiteLLM Deployment + Service |
| 04 | `04-n8n.yaml` | n8n StatefulSet + Service |
| 05 | `05-openziti.yaml` | OpenZiti Edge Tunnel |

### Required Secrets (Bitwarden SM)
| K8s Secret Key | Source |
|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Bitwarden |
| `LITELLM_MASTER_KEY` | Bitwarden |
| `DATABASE_URL` | Bitwarden |
| `KEYCLOAK_CLIENT_ID` / `KEYCLOAK_CLIENT_SECRET` | Bitwarden |
| `ZITI_IDENTITY_JSON` | embernet/emberflux |
| `DEEPINFRA_API_KEY` | Bitwarden |
| `NVIDIA_API_KEY` | Bitwarden |
| `OPENAI_API_KEY` | Bitwarden |
| `ANTHROPIC_API_KEY` | Bitwarden |
| `GEMINI_API_KEY` | Bitwarden |

### Quick Verification
```bash
# Check pods
wsl -d Ubuntu k3s kubectl get pods -n ember-ai

# Check ESO sync
wsl -d Ubuntu k3s kubectl get externalsecrets -n ember-ai

# Test LiteLLM
curl http://litellm-svc:4000/health
```

## Using the Models

### Main Engine (Nemotron 120B)
```bash
curl http://litellm-svc:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{"model": "nemotron-120b", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Agent Model (NemoClaw)
```bash
curl http://litellm-svc:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{"model": "nemoclaw", "messages": [{"role": "user", "content": "Search for X and summarize"}], "tools": [...]}'
```

All models are accessible through the same OpenAI-compatible endpoint — just change the `model` field.
