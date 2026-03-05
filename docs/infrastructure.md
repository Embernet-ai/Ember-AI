# Ember AI Infrastructure Setup Guide

This document outlines the planned infrastructure deployment for Ember AI.

## Prerequisites

- K3s (Lightweight Kubernetes) cluster operational
- Accessible external Keycloak instance (for SSO configuration)
- Bitwarden Secrets Manager (configured for Kubernetes integration/injection)
- OpenZiti (EmberNet Flux) Ziti Edge Router / Tunnel deployed within the K3s network
- Access to internal DNS for domain configuration

## Secrets Management (Bitwarden)

All sensitive data (API keys, database passwords, OpenZiti identities) must be stored in Bitwarden Secrets Manager. These secrets will be injected into our K3s deployments either via the Bitwarden Kubernetes Operator or external secrets operators. Hardcoding secrets in manifests is strictly prohibited.

## Component Configurations

### 1. OpenZiti Setup

- Deploy a Ziti Edge Tunnel or Router in the K3s cluster where Ember AI will be hosted.
- Define Services in the OpenZiti Controller mapping to internal K3s IPs or hostnames (e.g., `litellm.ember.ziti`, `n8n.ember.ziti`).
- Assign access policies restricting these resources to authorized internal identities.

### 2. LiteLLM Setup

- Deploy via Kubernetes Deployment/Service.
- Required Environment Variables (Injected via Bitwarden):
  - `STORE_MODEL_IN_DB=True`
  - Master Key configuration
  - Keycloak SSO configuration (OIDC client ID, client secret, issuer URL for LiteLLM UI access)
  - Database connection strings for logging/metrics
  - Caching configuration pointing to Valkey (`REDIS_HOST`, `REDIS_PORT` - LiteLLM uses Redis env vars for Valkey compatibility).
- Define `config.yaml` with required model routing and fallbacks.

### 3. n8n Setup

- Deploy via Kubernetes StatefulSet or Deployment with Persistent Volumes.
- Environment Variables (Injected via Bitwarden) setup for:
  - Keycloak SAML or OIDC configuration (for user authentication to n8n UI).
  - Database backend (PostgreSQL recommended for production n8n).
  - Valkey connection for workflow executions/caching.
  - Webhook URL configuration matching the internal OpenZiti service domain.
- Install necessary community nodes for advanced vector stores or specific MCP integrations.

### 4. Valkey Setup

- Deploy standard Valkey container on K3s.
- Configure persistence (AOF/RDB) if used for workflow states, otherwise configure purely as an LRU cache for LiteLLM.

### 5. Vector Database (RAG) Setup

- Deploy PostgreSQL with the `pgvector` extension enabled via K3s StatefulSet.
- This same PostgreSQL instance can be configured with a separate logical database to serve as n8n's backend.
- Ensure embedding models and chunking strategies map cleanly via n8n's pgvector nodes.

## Next Steps

1. Draft Kubernetes (K3s) manifests and Bitwarden secret mappings for the Postgres/pgvector cluster.
2. Create initial n8n boilerplate workflows for basic RAG and MCP server routing.
