# Ember AI

Secure, internal-only AI platform for Fireball Industries — LLM gateway, RAG pipelines, and agentic workflows on K3s.

## Stack

| Component | Image | Purpose |
|---|---|---|
| **LiteLLM** | `ghcr.io/berriai/litellm` | OpenAI-compatible API gateway with model routing |
| **n8n** | `docker.n8n.io/n8nio/n8n` | Workflow orchestrator for RAG and automation |
| **pgvector** | `ankane/pgvector` | PostgreSQL + vector embeddings for RAG |
| **Valkey** | `valkey/valkey` | Redis-compatible cache and queue backend |
| **OpenZiti** | `openziti/ziti-edge-tunnel` | Zero-trust overlay network (EmberNet Flux) |
| **ESO** | HelmChart CRD | Syncs secrets from Bitwarden SM into K8s |

## Models

| Name | Provider | Role |
|---|---|---|
| `nemotron-120b` | DeepInfra | Main reasoning engine (Nemotron 3 Super 120B) |
| `nemoclaw` | NVIDIA NIM | Agent model for tool-calling and planning |
| `gpt-4o` / `gpt-4o-mini` | OpenAI | Fallback |
| `claude-3.5-sonnet` / `claude-3-haiku` | Anthropic | Fallback |
| `gemini-2.0-flash` | Google | Fallback |

## Quick Start

```powershell
# Deploy to K3s (WSL Ubuntu)
.\deploy.ps1

# Check pod status
wsl -d Ubuntu k3s kubectl get pods -n ember-ai
```

## Documentation

- [Developer Guide](docs/developer-guide.md) — Full architecture, components, secrets, and usage
- [Architecture](docs/architecture.md) — Design principles
- [Infrastructure](docs/infrastructure.md) — K3s prerequisites and setup
- [Integration](docs/integration.md) — Data flow between components

## Secrets

All secrets managed via Bitwarden Secrets Manager → External Secrets Operator.  
See `k8s/07-bitwarden-eso-clusterstore.yaml` for the full mapping.

## License

Proprietary — Fireball Industries LLC
